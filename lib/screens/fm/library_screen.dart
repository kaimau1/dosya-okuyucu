import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/home_shortcuts.dart';
import '../../services/fm/library_store.dart';
import '../../services/fm/reading_positions.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/motion.dart' show PressScale;
import '../../widgets/section_header.dart';
import 'pick_file_screen.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_file_image.dart';
import 'browser_screen.dart';
import 'dashboard_screen.dart';
import 'entry_actions.dart';

/// **Kitaplık** — kitaplar rafta, kapaklarıyla (bkz. [LibraryStore]).
///
/// Üstte "Okumaya devam et" (yarım kalan kitaplar, ilerleme çubuğuyla),
/// altta raflar: her satır bir raf tahtasının üstünde duran kapaklar.
/// Kapak: PDF'in ilk sayfası / EPUB'un kendi kapağı; yoksa tür renginde
/// başlıklı bir kapak çizilir.
class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  /// Ana ekran kısayolunun bağlantısı (bkz. `openAppLink`).
  static const link = 'app:library';

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

enum _Sort { added, name, recent }

/// Okuma durumuna göre süzgeç (2026-11-04).
enum _Filter { all, reading, unread, done }

_Filter _statusOf(String path) {
  final v = ReadingPositions.progressOf(path) ?? 0;
  if (v >= 0.98) return _Filter.done;
  if (v > 0) return _Filter.reading;
  return _Filter.unread;
}

class _LibraryScreenState extends State<LibraryScreen> {
  bool _loading = true;
  _Sort _sort = _Sort.added;
  _Filter _filter = _Filter.all;

  /// Raf mı liste mi — süreç boyunca hatırlanır.
  static bool _listView = false;
  final _query = TextEditingController();
  bool _searching = false;

  /// Kitapların boyutu ve diskte olmayanlar — çizimde senkron `stat` yerine
  /// arka planda toplanır (A4.4); kitaplık değişince tazelenir.
  Map<String, int> _sizes = const {};
  Set<String> _gone = const {};
  int _statGen = 0;

  @override
  void initState() {
    super.initState();
    LibraryStore.revision.addListener(_refresh);
    _boot();
  }

  @override
  void dispose() {
    LibraryStore.revision.removeListener(_refresh);
    _query.dispose();
    super.dispose();
  }

  Future<void> _boot() async {
    await Future.wait([
      LibraryStore.ensureLoaded(),
      ReadingPositions.ensureLoaded(),
    ]);
    if (mounted) setState(() => _loading = false);
    unawaited(_statBooks());
  }

  void _refresh() {
    if (mounted) setState(() {});
    unawaited(_statBooks());
  }

  Future<void> _statBooks() async {
    final gen = ++_statGen;
    final sizes = <String, int>{};
    final gone = <String>{};
    for (final path in LibraryStore.paths.toList()) {
      try {
        final st = await File(path).stat();
        if (st.type == FileSystemEntityType.notFound) {
          gone.add(path);
        } else {
          sizes[path] = st.size;
        }
      } catch (_) {
        gone.add(path); // erişilemeyen kitap "eksik" sayılır
      }
    }
    if (!mounted || gen != _statGen) return;
    setState(() {
      _sizes = sizes;
      _gone = gone;
    });
  }

  List<String> get _books {
    final q = _query.text.trim().toLowerCase();
    final list = [
      for (final path in LibraryStore.paths)
        if ((q.isEmpty || p.basename(path).toLowerCase().contains(q)) &&
            (_filter == _Filter.all || _statusOf(path) == _filter))
          path,
    ];
    switch (_sort) {
      case _Sort.added:
        break;
      case _Sort.name:
        list.sort((a, b) =>
            p.basename(a).toLowerCase().compareTo(p.basename(b).toLowerCase()));
      case _Sort.recent:
        // Okunmuşlar (ilerlemesi olan) önce, en ilerlemiş en üstte.
        list.sort((a, b) => (ReadingPositions.progressOf(b) ?? -1)
            .compareTo(ReadingPositions.progressOf(a) ?? -1));
    }
    return list;
  }

  Future<void> _add() async {
    final res = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: LibraryStore.bookExtensions.toList(),
      allowMultiple: true,
      dialogTitle: context.t('lib.add'),
    );
    final paths = [
      for (final f in res?.files ?? const <PickedFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty) return;
    final n = await LibraryStore.add(paths);
    if (!mounted) return;
    showSnack(context,
        n == 0 ? context.t('lib.already') : context.t('lib.added', {'n': n}));
  }

  Future<void> _pinLibrary() async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    if (!await HomeShortcuts.supported()) {
      showSnackOn(messenger, strings.t('ea.shortcut_unsupported'));
      return;
    }
    final ok = await HomeShortcuts.pin(
      path: LibraryScreen.link,
      label: strings.t('lib.title'),
      icon: AppIcons.autoStories,
      color: AppHues.plum,
    );
    showSnackOn(
        messenger,
        ok
            ? strings.t('ea.shortcut_requested', {'name': strings.t('lib.title')})
            : strings.t('ea.shortcut_failed'));
  }

  Future<void> _open(String path) async {
    final there = await File(path).exists();
    if (!mounted) return;
    if (!there) {
      showSnack(context, context.t('lib.missing'));
      return;
    }
    await EntryOpener.open(context, path);
    // Okuma konumu değişmiş olabilir: ilerleme çubukları tazelensin.
    if (mounted) setState(() {});
  }

  Future<void> _bookMenu(String path) async {
    final name = p.basenameWithoutExtension(path);
    final choice = await showAppActionSheet<String>(
      context,
      title: name,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: 'open', icon: AppIcons.menuBook, label: context.t('common.open')),
          AppAction(
              value: 'folder',
              icon: AppIcons.emptyFolder,
              label: context.t('lib.show_folder')),
          AppAction(
              value: 'share',
              icon: AppIcons.share,
              label: context.t('lib.share')),
          if (Platform.isAndroid)
            AppAction(
                value: 'pin',
                icon: AppIcons.homeShortcut,
                label: context.t('ea.shortcut'),
                hint: context.t('ea.shortcut_hint')),
          AppAction(
              value: 'remove',
              icon: AppIcons.close,
              label: context.t('lib.remove'),
              destructive: true),
        ]),
      ],
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'open':
        await _open(path);
      case 'folder':
        await Navigator.of(context).push(browserRoute(BrowserScreen(
            path: p.dirname(path), focusPath: path)));
      case 'share':
        final there = await File(path).exists();
        if (!mounted) return;
        if (!there) {
          showSnack(context, context.t('lib.missing'));
          return;
        }
        await shareEntriesFrom(context, [path]);
      case 'pin':
        final messenger = ScaffoldMessenger.of(context);
        final strings = AppStrings.of(context);
        final ok = await HomeShortcuts.pin(
            path: path,
            label: name,
            icon: AppIcons.menuBook,
            color: _hueFor(path));
        showSnackOn(
            messenger,
            ok
                ? strings.t('ea.shortcut_requested', {'name': name})
                : strings.t('ea.shortcut_failed'));
      case 'remove':
        await LibraryStore.remove([path]);
    }
  }

  @override
  Widget build(BuildContext context) {
    final books = _loading ? const <String>[] : _books;
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.t('lib.search'),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
                onChanged: (_) => setState(() {}),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(context.t('lib.title')),
                  if (LibraryStore.count > 0)
                    Row(
                      children: [
                        Text(context.t('lib.count', {'n': LibraryStore.count}),
                            style: context.type.small
                                .copyWith(color: Paper.faint(context))),
                        Flexible(
                          child: Text(' · ${_statsLine()}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.type.small
                                  .copyWith(color: Paper.faint(context))),
                        ),
                      ],
                    ),
                ],
              ),
        actions: [
          IconButton(
            tooltip: context.t('common.search'),
            icon: Icon(_searching ? AppIcons.close : AppIcons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) _query.clear();
            }),
          ),
          PopupMenuButton<Object>(
            onSelected: (v) {
              if (v is _Sort) {
                setState(() => _sort = v);
              } else if (v == 'pin') {
                _pinLibrary();
              } else if (v == 'view') {
                setState(() => _listView = !_listView);
              } else if (v == 'find') {
                _findBooks();
              } else if (v == 'clean') {
                LibraryStore.remove(_missing());
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                value: 'view',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(_listView ? AppIcons.layoutGrid : AppIcons.listAlt),
                  title: Text(ctx.t(_listView ? 'lib.view_shelf' : 'lib.view_list')),
                ),
              ),
              PopupMenuItem(
                value: 'find',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.search),
                  title: Text(ctx.t('lib.find')),
                ),
              ),
              if (_missing().isNotEmpty)
                PopupMenuItem(
                  value: 'clean',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.folderOff),
                    title: Text(ctx.t('lib.clean_missing', {'n': _missing().length})),
                  ),
                ),
              const PopupMenuDivider(),
              for (final (s, key) in const [
                (_Sort.added, 'lib.sort_added'),
                (_Sort.name, 'lib.sort_name'),
                (_Sort.recent, 'lib.sort_progress'),
              ])
                CheckedPopupMenuItem(
                    value: s, checked: _sort == s, child: Text(ctx.t(key))),
              if (Platform.isAndroid) ...[
                const PopupMenuDivider(),
                PopupMenuItem(
                  value: 'pin',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(AppIcons.homeShortcut),
                    title: Text(ctx.t('lib.pin_home')),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
      floatingActionButton: LibraryStore.count == 0
          ? null
          : FloatingActionButton.extended(
              onPressed: _add,
              icon: const Icon(AppIcons.add),
              label: Text(context.t('lib.add')),
            ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : LibraryStore.count == 0
              ? _empty()
              : _shelves(books),
    );
  }

  Widget _empty() {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(AppIcons.autoStories, size: 72, color: scheme.primary),
            const SizedBox(height: Gap.md),
            Text(context.t('lib.empty_title'),
                style: context.type.heading, textAlign: TextAlign.center),
            const SizedBox(height: Gap.sm),
            Text(context.t('lib.empty_body'),
                style: context.type.body.copyWith(color: Paper.faint(context)),
                textAlign: TextAlign.center),
            const SizedBox(height: Gap.lg),
            FilledButton.icon(
              onPressed: _add,
              icon: const Icon(AppIcons.add),
              label: Text(context.t('lib.add')),
            ),
            const SizedBox(height: Gap.sm),
            OutlinedButton.icon(
              key: const ValueKey('lib-find'),
              onPressed: _findBooks,
              icon: const Icon(AppIcons.search),
              label: Text(context.t('lib.find')),
            ),
          ],
        ),
      ),
    );
  }

  String _statsLine() {
    var r = 0, d = 0, u = 0;
    for (final path in LibraryStore.paths) {
      switch (_statusOf(path)) {
        case _Filter.reading:
          r++;
        case _Filter.done:
          d++;
        case _Filter.unread || _Filter.all:
          u++;
      }
    }
    return context.t('lib.stats', {'r': r, 'd': d, 'u': u});
  }

  /// Kitaplıktaki ama diskte artık olmayan kitaplar.
  List<String> _missing() => [
        for (final path in LibraryStore.paths)
          if (_gone.contains(path)) path,
      ];

  /// **Telefondaki kitapları bul** (2026-11-04): panonun son taramasındaki
  /// dosyalardan kitap uzantılı olup kitaplıkta OLMAYANLAR listelenir, seçilip
  /// tek dokunuşla eklenir. Tarama yoksa liste boş kalır ve bunu söyler —
  /// ayrı bir disk taraması yapılmaz (pano zaten yapıyor).
  Future<void> _findBooks() async {
    final seen = <String>{};
    final found = <FsEntry>[];
    for (final c in FmCategory.values) {
      if (c == FmCategory.folder) continue;
      for (final e in DashboardScreen.cachedFiles(c)) {
        if (e.isDir || !LibraryStore.isBook(e.path)) continue;
        if (LibraryStore.contains(e.path) || !seen.add(e.path)) continue;
        found.add(e);
      }
    }
    found.sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    if (!mounted) return;
    if (found.isEmpty) {
      showSnack(context, context.t('lib.find_none'));
      return;
    }
    final chosen = await showAppSheet<List<String>>(
      context,
      title: context.t('lib.find_title', {'n': found.length}),
      scrollable: false,
      builder: (ctx) => _FindBooksSheet(found: found),
    );
    if (!mounted || chosen == null || chosen.isEmpty) return;
    final n = await LibraryStore.add(chosen);
    if (!mounted) return;
    showSnack(context, context.t('lib.added', {'n': n}));
  }

  Widget _filters() {
    final counts = <_Filter, int>{};
    for (final path in LibraryStore.paths) {
      final f = _statusOf(path);
      counts[f] = (counts[f] ?? 0) + 1;
    }
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        children: [
          for (final (f, key) in const [
            (_Filter.all, 'lib.f_all'),
            (_Filter.reading, 'lib.f_reading'),
            (_Filter.unread, 'lib.f_unread'),
            (_Filter.done, 'lib.f_done'),
          ])
            Padding(
              padding: const EdgeInsetsDirectional.only(end: Gap.sm),
              child: Center(
                child: ChoiceChip(
                  label: Text(f == _Filter.all
                      ? context.t(key)
                      : '${context.t(key)} · ${counts[f] ?? 0}'),
                  selected: _filter == f,
                  onSelected: (_) => setState(() => _filter = f),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Liste görünümü: küçük kapak, ad, tür · boyut, ilerleme.
  Widget _listTile(String path) {
    final theme = Theme.of(context);
    final progress = ReadingPositions.progressOf(path);
    final bytes = _sizes[path];
    final ext = p.extension(path).replaceFirst('.', '').toUpperCase();
    final size = bytes != null ? FsPaths.humanSize(bytes) : '';
    return InkWell(
      onTap: () => _open(path),
      onLongPress: () => _bookMenu(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: Gap.sm),
        child: Row(
          children: [
            SizedBox(width: 44, child: _BookCover(path: path)),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.basenameWithoutExtension(path),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall),
                  const SizedBox(height: 2),
                  Text(
                    [ext, if (size.isNotEmpty) size].join(' · '),
                    style: context.type.small
                        .copyWith(color: Paper.faint(context)),
                  ),
                  if (progress != null && progress > 0) ...[
                    const SizedBox(height: Gap.xs),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: LinearProgressIndicator(
                              value: progress.clamp(0.0, 1.0),
                              minHeight: 3,
                            ),
                          ),
                        ),
                        const SizedBox(width: Gap.sm),
                        Text(
                            context.t('lib.page_of',
                                {'p': (progress * 100).round()}),
                            style: context.type.caption
                                .copyWith(color: Paper.faint(context))),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              tooltip: context.t('common.more'),
              icon: const Icon(AppIcons.more),
              onPressed: () => _bookMenu(path),
            ),
          ],
        ),
      ),
    );
  }

  Widget _shelves(List<String> books) {
    final reading = _query.text.isEmpty && _filter == _Filter.all
        ? [
            for (final path in LibraryStore.paths)
              if ((ReadingPositions.progressOf(path) ?? 0) case final v
                  when v > 0 && v < 0.98)
                path,
          ]
        : const <String>[];
    return LayoutBuilder(builder: (context, box) {
      final perRow = math.max(3, (box.maxWidth / 120).floor());
      final rows = <List<String>>[
        for (var i = 0; i < books.length; i += perRow)
          books.sublist(i, math.min(i + perRow, books.length)),
      ];
      return ListView(
        padding: withNavInset(context, const EdgeInsets.only(bottom: 96)),
        children: [
          if (reading.isNotEmpty) ...[
            SectionHeader(context.t('lib.continue')),
            SizedBox(
              height: 210,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                itemCount: reading.length,
                separatorBuilder: (_, _) => const SizedBox(width: Gap.md),
                itemBuilder: (context, i) => SizedBox(
                  width: 120,
                  child: _BookTile(
                    path: reading[i],
                    onTap: () => _open(reading[i]),
                    onLongPress: () => _bookMenu(reading[i]),
                  ),
                ),
              ),
            ),
          ],
          _filters(),
          SectionHeader(context.t('lib.shelf'), count: '${books.length}'),
          if (books.isEmpty)
            Padding(
              padding: const EdgeInsets.all(Gap.lg),
              child: Text(context.t('lib.no_match'), textAlign: TextAlign.center),
            ),
          if (_listView)
            for (final path in books) _listTile(path)
          else
            for (final row in rows) _shelfRow(row, perRow),
        ],
      );
    });
  }

  /// Bir raf: kapaklar tahtanın üstünde, başlıklar altında.
  Widget _shelfRow(List<String> row, int perRow) {
    final scheme = Theme.of(context).colorScheme;
    Widget cells(Widget Function(String) build) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < perRow; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.xs + 2),
                    child: i < row.length ? build(row[i]) : const SizedBox(),
                  ),
                ),
            ],
          ),
        );
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.lg),
      child: Column(
        children: [
          cells((path) => GestureDetector(
                onTap: () => _open(path),
                onLongPress: () => _bookMenu(path),
                child: PressScale(child: _BookCover(path: path)),
              )),
          // Raf tahtası: üst yüz açık, ön yüz koyu, altında gölge.
          Container(
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: Gap.sm),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.alphaBlend(
                      AppHues.honey.withValues(alpha: 0.35), scheme.surface),
                  Color.alphaBlend(
                      AppHues.honey.withValues(alpha: 0.65), scheme.surfaceContainerHighest),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shade.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
          ),
          const SizedBox(height: Gap.sm),
          cells((path) => GestureDetector(
                onTap: () => _open(path),
                onLongPress: () => _bookMenu(path),
                child: _BookCaption(path: path),
              )),
        ],
      ),
    );
  }
}

/// Kapak + başlık + ilerleme ("Okumaya devam et" şeridi için).
class _BookTile extends StatelessWidget {
  final String path;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _BookTile(
      {required this.path, required this.onTap, required this.onLongPress});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
                child: Center(child: PressScale(child: _BookCover(path: path)))),
            const SizedBox(height: Gap.xs),
            _BookCaption(path: path),
          ],
        ),
      );
}

Color _hueFor(String path) {
  const hues = [
    AppHues.plum, AppHues.indigo, AppHues.teal, AppHues.navy,
    AppHues.tangerine, AppHues.green, AppHues.violet, AppHues.pink,
  ];
  return hues[p.basename(path).hashCode.abs() % hues.length];
}

/// Kitap kapağı: 2:3, sırtı gölgeli, hafif yükseltili.
class _BookCover extends StatefulWidget {
  final String path;
  const _BookCover({required this.path});

  @override
  State<_BookCover> createState() => _BookCoverState();
}

class _BookCoverState extends State<_BookCover> {
  String? _cover;
  bool _exists = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _BookCover old) {
    super.didUpdateWidget(old);
    if (old.path != widget.path) {
      _cover = null;
      _load();
    }
  }

  Future<void> _load() async {
    final path = widget.path;
    final exists = await File(path).exists();
    if (!mounted || path != widget.path) return;
    if (exists != _exists) setState(() => _exists = exists);
    if (!exists) return;
    final cover = await LibraryStore.coverOf(path);
    if (mounted && path == widget.path) setState(() => _cover = cover);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _cover;
    final ext = p.extension(widget.path).replaceFirst('.', '').toUpperCase();
    final hue = _hueFor(widget.path);
    final Widget face = cover != null
        ? Image(
            image: FmFileImage(cover),
            fit: BoxFit.cover,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => _drawnCover(hue, ext))
        : _drawnCover(hue, ext);
    return AspectRatio(
      aspectRatio: 2 / 3,
      child: Opacity(
        opacity: _exists ? 1 : 0.4,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2), right: Radius.circular(5)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shade.withValues(alpha: 0.28),
                blurRadius: 6,
                offset: const Offset(2, 3),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(2), right: Radius.circular(5)),
            child: Stack(fit: StackFit.expand, children: [
              ColoredBox(color: AppColors.onMedia, child: face),
              // Sırt: soldan ince koyu şerit + parlama — kapak "kitap" olsun.
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: FractionallySizedBox(
                  widthFactor: 0.08,
                  heightFactor: 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.shade.withValues(alpha: 0.30),
                        AppColors.onMedia.withValues(alpha: 0.18),
                        AppColors.shade.withValues(alpha: 0.0),
                      ]),
                    ),
                  ),
                ),
              ),
              if (!_exists)
                Center(
                  child: Icon(AppIcons.folderOff,
                      color: AppColors.onMedia.withValues(alpha: 0.9)),
                ),
            ]),
          ),
        ),
      ),
    );
  }

  /// Kapağı olmayan kitap: tür renginde zemin, ortada başlık, altta tür.
  Widget _drawnCover(Color hue, String ext) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [hue, Color.lerp(hue, AppColors.shade, 0.35)!],
          ),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 8, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  p.basenameWithoutExtension(widget.path),
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.compact.copyWith(
                      color: AppColors.onMedia, fontWeight: FontWeight.w700),
                ),
              ),
              Text(ext,
                  style: context.type.small.copyWith(
                      color: AppColors.onMedia.withValues(alpha: 0.8))),
            ],
          ),
        ),
      );
}

/// Kapak altı: başlık (2 satır) + okuma ilerlemesi.
class _BookCaption extends StatelessWidget {
  final String path;
  const _BookCaption({required this.path});

  @override
  Widget build(BuildContext context) {
    final progress = ReadingPositions.progressOf(path);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          p.basenameWithoutExtension(path),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.type.small,
        ),
        if (progress != null && progress > 0) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 3,
            ),
          ),
          Text('%${(progress * 100).round()}',
              style: context.type.caption.copyWith(color: Paper.faint(context))),
        ],
      ],
    );
  }
}

/// "Telefondaki kitapları bul" seçimi: hepsi seçili gelir, işaret kaldırılır.
class _FindBooksSheet extends StatefulWidget {
  final List<FsEntry> found;
  const _FindBooksSheet({required this.found});

  @override
  State<_FindBooksSheet> createState() => _FindBooksSheetState();
}

class _FindBooksSheetState extends State<_FindBooksSheet> {
  late final Set<String> _picked = {for (final e in widget.found) e.path};

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: widget.found.length,
            itemBuilder: (context, i) {
              final e = widget.found[i];
              return CheckboxListTile(
                value: _picked.contains(e.path),
                onChanged: (v) => setState(() {
                  if (v ?? false) {
                    _picked.add(e.path);
                  } else {
                    _picked.remove(e.path);
                  }
                }),
                secondary: const Icon(AppIcons.menuBook),
                title: Text(p.basenameWithoutExtension(e.name),
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                subtitle: Text(
                  '${FsPaths.humanSize(e.sizeBytes)} · '
                  '${p.basename(p.dirname(e.path))}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.md),
          child: FilledButton.icon(
            onPressed: _picked.isEmpty
                ? null
                : () => Navigator.of(context).pop(_picked.toList()),
            icon: const Icon(AppIcons.add),
            label: Text(context.t('lib.add_selected', {'n': _picked.length})),
          ),
        ),
      ],
    );
  }
}

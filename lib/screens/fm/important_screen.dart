import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/custom_cards.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/important_files.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'custom_card_screen.dart';
import 'important_gallery_screen.dart';
import 'photos_screen.dart';
import 'search_screen.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';
import '../../core/user_error.dart';
import '../../widgets/app_dialog.dart';

/// **Önemli Dosyalar** — kullanıcının kendi seçtiği dosyaların toplandığı
/// klasör, ana sayfadaki kategorizasyonun aynısıyla.
///
/// Kullanıcı isteği (2026-07-29): *"önemli dosyalar klasörü ve ona yine ana
/// sayfadaki formatta kategorizasyon ve alt klasörler açma"*.
///
/// Tasarım kararları:
/// - Klasör **gerçek bir klasördür** (`<ana bellek>/Önemli Dosyalar`), gizli
///   bir veritabanı değil: kullanıcı telefonu bilgisayara taktığında da,
///   başka bir dosya yöneticisiyle de aynı dosyaları görür; uygulama
///   silinirse listesi kaybolmaz.
/// - Kategori sayıları klasör ağacı **tek geçişte** gezilerek çıkarılır —
///   burada dosya sayısı yüz binler değil, doğrudan taramak yeterli ve
///   arama dizininden daha tazedir.
/// - Alt klasörler serbesttir; kategori kutuları alt klasörlerin İÇİNİ de
///   kapsar (özyinelemeli), gezgin görünümü ise yalnız üst düzeyi gösterir.
class ImportantScreen extends StatefulWidget {
  const ImportantScreen({super.key});

  /// Klasörün adı — yolu [pathIn] ile kurulur.
  /// DİKKAT: bu bir **klasör adı** (dosya sisteminde gerçek dizin), arayüz
  /// metni değil — çevrilirse var olan klasör bulunamaz ve kullanıcı
  /// dosyalarını kaybetmiş gibi görür. Başlıkta gösterilen çevrilebilir ad
  /// için `important.title` anahtarı var.
  static const folderName = ImportantFiles.folderName;

  static String pathIn(String root) => p.join(root, folderName);

  @override
  State<ImportantScreen> createState() => _ImportantScreenState();
}

class _ImportantScreenState extends State<ImportantScreen> {
  String get _root => ImportantScreen.pathIn(FmEnv.primaryRoot);

  List<FsEntry> _files = const [];
  List<FsEntry> _subFolders = const [];
  bool _loading = true;
  bool _exists = false;

  /// Galeri süzgeci (null = tümü); önizleme ilk [_galleryPreview] dosya.
  FmCategory? _galleryFilter;
  static const _galleryPreview = 12;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_reload);
    CustomCards.instance.addListener(_reload);
    CustomCards.instance.ensureLoaded();
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_reload);
    CustomCards.instance.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    // Senkron bilinçli (A4.4 istisnası): tek `stat`; asenkron sürüm widget
    // testinin sahte saatinde bitmiyor, ekran "yükleniyor"da kalırdı (a11y testi).
    final exists = Directory(_root).existsSync();
    if (!exists) {
      if (!mounted) return;
      setState(() {
        _exists = false;
        _loading = false;
        _files = const [];
        _subFolders = const [];
      });
      return;
    }
    final files = await FsScan.collect([_root]);
    final children = await FsScan.list(_root);
    if (!mounted) return;
    setState(() {
      _exists = true;
      _files = files;
      _subFolders = FsScan.sort(
        children.where((e) => e.isDir).toList(),
        FmSort.name,
      );
      _loading = false;
    });
  }

  Future<void> _createRoot() async {
    final createFailed = context.t('fm.folder_create_failed');
    try {
      await Directory(_root).create(recursive: true);
      FsEvents.changed();
      await _load();
    } catch (e) {
      _snack(createFailed.replaceAll('{error}', userErrorText(e)));
    }
  }

  Future<void> _newSubFolder() async {
    final createFailed = context.t('fm.folder_create_failed');
    final name = await promptForName(
      context,
      title: context.t('important.new_subfolder'),
      label: context.t('fm.folder_name'),
      initial: context.t('fm.new_folder'),
    );
    if (name == null) return;
    try {
      await Directory(_root).create(recursive: true); // varsa dokunmaz
      final path = await FileOps.createFolder(_root, name);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(browserRoute(BrowserScreen(path: path),
      ));
      await _load();
    } catch (e) {
      _snack(createFailed.replaceAll('{error}', userErrorText(e)));
    }
  }

  /// Panodaki (kopyala/kes) dosyaları bu klasöre aktarır — "önemli" işaretinin
  /// pratik yolu: dosyayı herhangi bir listede kopyala, burada yapıştır.
  Future<void> _paste() async {
    final appState = context.read<AppState>();
    final sources = appState.clipboard;
    if (sources.isEmpty) return;
    final cut = appState.clipboardCut;
    await Directory(_root).create(recursive: true); // varsa dokunmaz
    if (!mounted) return;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: cut ? context.t('fm.moving') : context.t('fm.copying'),
      name: context.t(cut ? 'fm.moving_name' : 'fm.copying_name'),
      task: (report, isCancelled) => cut
          ? FileOps.moveAll(sources, _root,
              onProgress: report,
              isCancelled: isCancelled,
              renameTo: ImportantFiles.markedNameFor)
          : FileOps.copyAll(sources, _root,
              onProgress: report,
              isCancelled: isCancelled,
              renameTo: ImportantFiles.markedNameFor),
    );
    appState.clearClipboard();
    if (!mounted) return;
    if (result.hasError) _snack(context.t('fm.transfer_partial', {'error': result.errors.first}));
    await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(browserRoute(screen));
    await _load();
  }

  void _openCategory(FmCategory category) {
    final files = _files.where((f) => f.category == category).toList();
    if (category == FmCategory.image || category == FmCategory.video) {
      // Kapsam kimliği panodan AYRI: ikisi de "Görüntüler" başlığını kullanıyor
      // ama bu ekran yalnız Önemli Dosyalar klasörünü gösterir.
      _push(PhotosScreen(
        title: category.label,
        scopeId: 'onemli-${category.name}',
        files: files,
      ));
      return;
    }
    _push(CategoryScreen(
      title: category.label,
      files: files,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text(ImportantScreen.folderName),
        actions: [
          if (_exists)
            IconButton(
              tooltip: context.t('important.search'),
              icon: const Icon(AppIcons.search),
              onPressed: () => _push(SearchScreen(
                root: _root,
                rootLabel: ImportantScreen.folderName,
              )),
            ),
          IconButton(
            tooltip: context.t('common.refresh'),
            icon: const Icon(AppIcons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_exists)
            IconButton(
              tooltip: context.t('important.open_in_browser'),
              icon: const Icon(AppIcons.emptyFolder),
              onPressed: () => _push(BrowserScreen(
                path: _root,
                title: ImportantScreen.folderName,
              )),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: withNavInset(
              context, const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl)),
          children: [
            if (_loading) const LinearProgressIndicator(minHeight: 3),
            if (!_exists && !_loading) _emptyCard(),
            if (_exists) ...[
              _summaryCard(),
              const SizedBox(height: Gap.md),
              Text(context.t('important.by_type'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Gap.sm),
              FmCategoryGrid(tiles: _categoryTiles()),
              const SizedBox(height: Gap.lg),
              ..._cardsSection(context),
              const SizedBox(height: Gap.lg),
              ..._gallery(context),
              const SizedBox(height: Gap.lg),
              Row(
                children: [
                  Expanded(
                    child: Text(context.t('important.subfolders'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _newSubFolder,
                    icon: const Icon(AppIcons.newFolder),
                    label: Text(context.t('common.new')),
                  ),
                ],
              ),
              if (_plainSubFolders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Text(context.t('important.no_subfolder')),
                ),
              for (final f in _plainSubFolders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(AppIcons.folder, color: context.fmFolderColor ?? FmColors.folder),
                  title: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${context.t('count.files', {'n': _countIn(f.path)})} · '
                    '${FsPaths.humanSize(_bytesIn(f.path))}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (v) => v == 'rename'
                        ? _renameCategory(f)
                        : _deleteCategory(f),
                    itemBuilder: (ctx) => [
                      PopupMenuItem(
                          value: 'rename',
                          child: Text(ctx.t('important.rename_category'))),
                      PopupMenuItem(
                          value: 'delete',
                          child: Text(ctx.t('important.delete_category'))),
                    ],
                  ),
                  onTap: () => _push(BrowserScreen(path: f.path)),
                  onLongPress: () => _renameCategory(f),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: !_exists
          ? null
          // Pano ayrı bildirici (A4.2).
          : ListenableBuilder(
              listenable: appState.clipboardState,
              builder: (context, _) => appState.hasClipboard
              ? FloatingActionButton.extended(
                  onPressed: _paste,
                  icon: const Icon(AppIcons.paste),
                  label: Text(appState.clipboardCut ? context.t('fm.move') : context.t('fm.paste')),
                )
              : FloatingActionButton(
                  onPressed: _newSubFolder,
                  tooltip: context.t('important.new_subfolder'),
                  child: const Icon(AppIcons.newFolder),
                )),
    );
  }

  // ── Kartlar (2026-11-13) ───────────────────────────────────────────────

  /// Karta bağlı olmayan alt klasörler (kartlılar "Kartlarım"da görünür).
  List<FsEntry> get _plainSubFolders => [
        for (final f in _subFolders)
          if (CustomCards.instance.byPath(f.path) == null) f,
      ];

  Future<void> _newCard() async {
    final card = await showCustomCardEditor(context, inImportant: true);
    if (card == null || !mounted) return;
    await _load();
    if (!mounted) return;
    await openCustomCard(context, card);
    await _load();
  }

  List<Widget> _cardsSection(BuildContext context) {
    final cards = CustomCards.instance.within(_root);
    return [
      Row(
        children: [
          Expanded(
            child: Text(context.t('card.section'),
                style: Theme.of(context).textTheme.titleMedium),
          ),
          TextButton.icon(
            key: const ValueKey('important-new-card'),
            onPressed: _newCard,
            icon: const Icon(AppIcons.add),
            label: Text(context.t('card.new')),
          ),
        ],
      ),
      const SizedBox(height: Gap.sm),
      FmCategoryGrid(tiles: [
        for (final c in cards)
          FmTileData(
            id: c.tileId,
            icon: cardIconOf(c),
            color: Color(c.color),
            label: c.name,
            subtitle: _countIn(c.path) == 0
                ? context.t('card.tile_sub_empty')
                : '${FsPaths.humanSize(_bytesIn(c.path))} (${_countIn(c.path)})',
            onTap: () async {
              await openCustomCard(context, c);
              await _load();
            },
          ),
        FmTileData(
          id: 'new_card',
          icon: AppIcons.add,
          color: AppHues.steel,
          label: context.t('card.new'),
          subtitle: context.t('card.new_tile_sub'),
          onTap: _newCard,
        ),
      ]),
    ];
  }

  // ── Kategoriler (alt klasörler) ─────────────────────────────────────────

  Future<void> _renameCategory(FsEntry f) async {
    final failed = context.t('fm.rename_failed');
    final name = await showAppPrompt(
      context,
      title: context.t('important.rename_category'),
      label: context.t('fm.folder_name'),
      initial: f.name,
      confirmLabel: context.t('common.ok'),
    );
    if (name == null || name.trim().isEmpty || name == f.name) return;
    try {
      await FileOps.rename(f.path, name.trim());
      FsEvents.changed();
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
    }
    await _load();
  }

  /// Önemli klasör: onay HİÇBİR ayarla atlanmaz (bkz. [ImportantFiles]).
  Future<void> _deleteCategory(FsEntry f) async {
    final ok = await showAppConfirm(
      context,
      title: context.t('important.delete_category'),
      message: context.t('important.delete_category_msg',
          {'name': f.name, 'n': _countIn(f.path)}),
      confirmLabel: context.t('common.delete'),
      destructive: true,
    );
    if (!ok) return;
    final result = await FileOps.deleteAll([f.path]);
    FsEvents.changed();
    if (result.hasError) _snack(result.errors.first);
    await _load();
  }

  // ── Galeri: tüm önemli dosyalar önizlemeli ızgarada ────────────────────

  static const _galleryKinds = [
    FmCategory.image,
    FmCategory.video,
    FmCategory.document,
    FmCategory.audio,
    FmCategory.other,
  ];

  List<Widget> _gallery(BuildContext context) {
    final all = [..._files]
      ..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    final kinds = {for (final f in all) f.category};
    final filter = _galleryFilter;
    final items = filter == null
        ? all
        : all.where((f) => f.category == filter).toList();
    final shown = items.take(_galleryPreview).toList();
    final paths = [for (final f in items) f.path];
    return [
      Text(context.t('important.gallery'),
          style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: Gap.sm),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              label: Text(context.t('important.gallery_all')),
              selected: filter == null,
              onSelected: (_) => setState(() => _galleryFilter = null),
            ),
            for (final c in _galleryKinds)
              if (kinds.contains(c))
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: Gap.xs),
                  child: ChoiceChip(
                    avatar: Icon(FmColors.iconFor(c), size: 18),
                    label: Text(c.label),
                    selected: filter == c,
                    onSelected: (_) => setState(() => _galleryFilter = c),
                  ),
                ),
          ],
        ),
      ),
      const SizedBox(height: Gap.sm),
      if (items.isEmpty)
        Text(context.t('important.gallery_empty'))
      else
        LayoutBuilder(builder: (context, box) {
          final cols = (box.maxWidth / 120).floor().clamp(3, 8);
          final cell = (box.maxWidth - (cols - 1) * 4) / cols;
          return Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final f in shown)
                ImportantGalleryTile(
                  key: ValueKey(f.path),
                  entry: f,
                  size: cell,
                  onTap: () =>
                      EntryOpener.open(context, f.path, siblings: paths),
                ),
            ],
          );
        }),
      // 2026-11-10: tümü artık ayrı **Önemli Galeri** ekranında (ana ekranda
      // da kendi kartı var) — geniş, kategorize süzgeçlerle.
      if (all.isNotEmpty)
        Align(
          alignment: AlignmentDirectional.centerEnd,
          child: TextButton.icon(
            onPressed: () => _push(const ImportantGalleryScreen()),
            icon: const Icon(AppIcons.importantGallery, size: 18),
            label: Text(context.t('ig.open_gallery', {'n': all.length})),
          ),
        ),
    ];
  }

  int _countIn(String dir) =>
      _files.where((f) => FsPaths.isInside(dir, f.path)).length;

  int _bytesIn(String dir) => _files
      .where((f) => FsPaths.isInside(dir, f.path))
      .fold<int>(0, (sum, f) => sum + f.sizeBytes);

  Widget _summaryCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              const Icon(AppIcons.star, color: FmColors.folder, size: 32),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.t('count.files', {'n': _files.length})} · '
                      '${FsPaths.humanSize(_files.fold<int>(0, (s, f) => s + f.sizeBytes))}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _root,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  Widget _emptyCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.t('important.missing'),
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('important.explain'),
              ),
              const SizedBox(height: Gap.sm),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton.icon(
                  onPressed: _createRoot,
                  icon: const Icon(AppIcons.newFolder),
                  label: Text(context.t('important.create_folder')),
                ),
              ),
            ],
          ),
        ),
      );

  /// Ana sayfadaki kutuların aynısı — yalnız bu klasörün içindekiler sayılır.
  List<FmTileData> _categoryTiles() {
    final counts = <FmCategory, int>{};
    final bytes = <FmCategory, int>{};
    for (final f in _files) {
      counts[f.category] = (counts[f.category] ?? 0) + 1;
      bytes[f.category] = (bytes[f.category] ?? 0) + f.sizeBytes;
    }
    const order = [
      FmCategory.image,
      FmCategory.video,
      FmCategory.document,
      FmCategory.audio,
      FmCategory.archive,
      FmCategory.apk,
      FmCategory.other,
    ];
    return [
      for (final c in order)
        FmTileData(
          icon: FmColors.iconFor(c),
          color: FmColors.forCategory(c),
          label: c.label,
          subtitle: (counts[c] ?? 0) == 0
              ? 'Yok'
              : '${FsPaths.humanSize(bytes[c] ?? 0)} (${counts[c]})',
          onTap: () => _openCategory(c),
        ),
    ];
  }
}

/// Galeri hücresi: kare önizleme (fotoğraf/video/PDF/Office küçük resmi),
/// görsel olmayanlarda altta ad.
class ImportantGalleryTile extends StatelessWidget {
  final FsEntry entry;
  final double size;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  /// Kapalıysa yalnız tür simgesi (kasa: düz kopya hazır olana kadar).
  final bool thumbnails;

  /// Seçim kipinde işaretli mi (çerçeve + onay rozeti).
  final bool selected;

  const ImportantGalleryTile(
      {super.key,
      required this.entry,
      required this.size,
      required this.onTap,
      this.onLongPress,
      this.thumbnails = true,
      this.selected = false});

  @override
  Widget build(BuildContext context) {
    final media = thumbnails &&
        (entry.category == FmCategory.image ||
            entry.category == FmCategory.video);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(Radii.control),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Padding(
                padding: media
                    ? EdgeInsets.zero
                    : EdgeInsets.fromLTRB(8, 8, 8, size * 0.28),
                child: Center(
                  child: FmEntryIcon(
                    entry: entry,
                    thumbnails: thumbnails,
                    size: media ? size : size * 0.62,
                    radius: media ? 0 : Radii.control,
                  ),
                ),
              ),
              if (media && entry.category == FmCategory.video)
                Center(
                  child: Icon(AppIcons.playCircleFill,
                      color: scheme.surface.withValues(alpha: 0.85), size: 36),
                ),
              if (!media)
                PositionedDirectional(
                  start: 4,
                  end: 4,
                  bottom: 4,
                  child: Text(
                    // İkinci ad varsa (elle/AI) adla birlikte görünür.
                    [
                      if (AiIndex.aliasOf(entry.path).isNotEmpty)
                        AiIndex.aliasOf(entry.path),
                      entry.name,
                    ].join('\n'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
                ),
              if (selected)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.18),
                    border: Border.all(color: scheme.primary, width: 3),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                ),
              if (selected)
                PositionedDirectional(
                  top: 6,
                  end: 6,
                  child: CircleAvatar(
                    radius: 11,
                    backgroundColor: scheme.primary,
                    child: Icon(AppIcons.check,
                        size: 16, color: scheme.onPrimary),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ad soran ortak diyalog (yeni klasör / yeni dosya). Gezgin ekranındaki
/// `_askName` ile aynı davranış; birden çok ekran kullandığı için dışarı
/// alındı.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
}) async {
  final dot = initial.lastIndexOf('.');
  return showAppPrompt(
    context,
    title: title,
    label: label,
    initial: initial,
    selectEnd: dot > 0 ? dot : initial.length,
    confirmLabel: context.t('fm.create'),
  );
}

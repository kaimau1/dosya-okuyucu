import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../core/user_error.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/custom_cards.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/important_files.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'browser_screen.dart';
import 'important_screen.dart' show ImportantGalleryTile;
import 'pick_file_screen.dart';

/// Kart simgeleri — anahtar kayıtta durur (IconData değil: simge kodu
/// sürümden sürüme değişebilir).
const Map<String, IconData> cardIcons = {
  'star': AppIcons.star,
  'folder': AppIcons.folder,
  'home': AppIcons.home,
  'health': AppIcons.topicHealth,
  'bank': AppIcons.topicBank,
  'invoice': AppIcons.topicInvoice,
  'contract': AppIcons.topicContract,
  'school': AppIcons.topicEducation,
  'ticket': AppIcons.topicTicket,
  'receipt': AppIcons.receiptLong,
  'photo': AppIcons.photoCamera,
  'image': AppIcons.image,
  'video': AppIcons.video,
  'music': AppIcons.audio,
  'pdf': AppIcons.pdf,
  'book': AppIcons.menuBook,
  'cake': AppIcons.cake,
  'child': AppIcons.childCare,
  'key': AppIcons.key,
  'shield': AppIcons.shield,
  'idea': AppIcons.lightbulbOutline,
  'place': AppIcons.place,
  'smile': AppIcons.emojiEmotions,
  'bookmark': AppIcons.bookmark,
  'lock': AppIcons.lock,
  'work': AppIcons.handyman,
  'chat': AppIcons.chat,
  'android': AppIcons.android,
};

const List<Color> cardColors = [
  AppHues.amber,
  AppHues.orange,
  AppHues.red,
  AppHues.pink,
  AppHues.purple,
  AppHues.indigo,
  AppHues.blue,
  AppHues.cyan,
  AppHues.teal,
  AppHues.green,
  AppHues.olive,
  AppHues.steel,
];

IconData cardIconOf(CustomCard c) => cardIcons[c.icon] ?? AppIcons.star;

/// Kart için seçilebilir türler (klasör hariç).
const _kindOptions = [
  FmCategory.image,
  FmCategory.video,
  FmCategory.document,
  FmCategory.audio,
  FmCategory.archive,
  FmCategory.apk,
  FmCategory.other,
];

/// Yeni kart açar ya da var olanı düzenler. [inImportant] yeni kartın
/// klasörünün varsayılan yeri (Önemli Dosyalar mı, `Kartlarım` mı).
/// Kaydedilen kartı döndürür (vazgeçilirse null).
Future<CustomCard?> showCustomCardEditor(
  BuildContext context, {
  CustomCard? card,
  bool inImportant = true,
  bool onHome = false,
}) async {
  final result = await showAppSheet<_CardDraft>(
    context,
    title: context.t(card == null ? 'card.new' : 'card.edit'),
    builder: (_) => _CardEditor(
      initial: card,
      inImportant: inImportant,
      onHome: onHome,
    ),
  );
  if (result == null || !context.mounted) return null;
  final store = CustomCards.instance;
  try {
    if (card == null) {
      final parent = result.inImportant
          ? ImportantFiles.folderIn(FmEnv.primaryRoot)
          : p.join(FmEnv.primaryRoot, CustomCards.homeFolderName);
      final clean = FileOps.sanitizeName(result.name);
      if (clean.isEmpty) throw const FileSystemException('ad boş olamaz');
      final dir = p.join(parent, clean);
      // Aynı adlı klasör varsa ona bağlanır (içindekiler kaybolmaz).
      await Directory(dir).create(recursive: true);
      FsEvents.changed();
      final made = CustomCard(
        id: CustomCards.newId(),
        name: result.name,
        path: dir,
        icon: result.icon,
        color: result.color,
        view: result.view,
        kinds: result.kinds,
        onHome: result.onHome,
      );
      await store.upsert(made);
      return made;
    }
    var path = card.path;
    // Klasör adı kartın adıyla aynıysa birlikte yeniden adlandırılır.
    if (result.name != card.name &&
        p.basename(card.path) == FileOps.sanitizeName(card.name)) {
      final target = p.join(p.dirname(card.path),
          FileOps.sanitizeName(result.name));
      if (Directory(card.path).existsSync() &&
          !Directory(target).existsSync() &&
          !File(target).existsSync()) {
        path = await FileOps.rename(card.path, result.name);
        FsEvents.changed();
      }
    }
    final updated = card.copyWith(
      name: result.name,
      path: path,
      icon: result.icon,
      color: result.color,
      view: result.view,
      kinds: result.kinds,
      onHome: result.onHome,
    );
    await store.upsert(updated);
    return updated;
  } catch (e) {
    if (context.mounted) {
      showSnack(context,
          context.t('fm.folder_create_failed', {'error': userErrorText(e)}));
    }
    return null;
  }
}

class _CardDraft {
  final String name;
  final String icon;
  final int color;
  final CardView view;
  final Set<FmCategory> kinds;
  final bool onHome;
  final bool inImportant;
  const _CardDraft(this.name, this.icon, this.color, this.view, this.kinds,
      this.onHome, this.inImportant);
}

class _CardEditor extends StatefulWidget {
  final CustomCard? initial;
  final bool inImportant;
  final bool onHome;
  const _CardEditor(
      {required this.initial, required this.inImportant, required this.onHome});

  @override
  State<_CardEditor> createState() => _CardEditorState();
}

class _CardEditorState extends State<_CardEditor> {
  late final _name = TextEditingController(text: widget.initial?.name ?? '');
  late String _icon = widget.initial?.icon ?? 'star';
  late int _color = widget.initial?.color ?? AppHues.amber.toARGB32();
  late CardView _view = widget.initial?.view ?? CardView.gallery;
  late final Set<FmCategory> _kinds = {...?widget.initial?.kinds};
  late bool _onHome = widget.initial?.onHome ?? widget.onHome;
  late bool _inImportant = widget.inImportant;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(
        context,
        _CardDraft(name, _icon, _color, _view, {..._kinds}, _onHome,
            _inImportant));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final isNew = widget.initial == null;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('card-name'),
            controller: _name,
            autofocus: isNew,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              labelText: context.t('card.name'),
              hintText: context.t('card.name_hint'),
              prefixIcon: Icon(cardIcons[_icon], color: Color(_color)),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Gap.md),
          Text(context.t('card.what_goes'), style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: Gap.xs,
            runSpacing: Gap.xs,
            children: [
              ChoiceChip(
                label: Text(context.t('card.kind_all')),
                selected: _kinds.isEmpty,
                onSelected: (_) => setState(_kinds.clear),
              ),
              for (final k in _kindOptions)
                FilterChip(
                  avatar: Icon(FmColors.iconFor(k), size: 18),
                  label: Text(context.t(k.labelKey)),
                  selected: _kinds.contains(k),
                  onSelected: (v) =>
                      setState(() => v ? _kinds.add(k) : _kinds.remove(k)),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(context.t('card.view'), style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          SegmentedButton<CardView>(
            segments: [
              ButtonSegment(
                  value: CardView.gallery,
                  icon: const Icon(AppIcons.layoutGallery),
                  label: Text(context.t('card.view_gallery'))),
              ButtonSegment(
                  value: CardView.folder,
                  icon: const Icon(AppIcons.folder),
                  label: Text(context.t('card.view_folder'))),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: Gap.md),
          Text(context.t('card.icon'), style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final e in cardIcons.entries)
                InkResponse(
                  onTap: () => setState(() => _icon = e.key),
                  radius: 24,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: e.key == _icon
                          ? Color(_color).withValues(alpha: 0.18)
                          : null,
                      border: Border.all(
                          color: e.key == _icon
                              ? Color(_color)
                              : scheme.outlineVariant),
                      borderRadius: BorderRadius.circular(Radii.control),
                    ),
                    child: Icon(e.value,
                        size: 22,
                        color: e.key == _icon ? Color(_color) : null),
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.md),
          Text(context.t('card.color'), style: text.titleSmall),
          const SizedBox(height: Gap.xs),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in cardColors)
                InkResponse(
                  onTap: () => setState(() => _color = c.toARGB32()),
                  radius: 20,
                  child: CircleAvatar(
                    radius: 16,
                    backgroundColor: c,
                    child: c.toARGB32() == _color
                        ? Icon(AppIcons.check,
                            size: 18, color: scheme.onPrimary)
                        : null,
                  ),
                ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('card.on_home')),
            value: _onHome,
            onChanged: (v) => setState(() => _onHome = v),
          ),
          if (isNew)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(context.t('card.in_important')),
              subtitle: Text(context.t('card.in_important_sub')),
              value: _inImportant,
              onChanged: (v) => setState(() => _inImportant = v),
            ),
          const SizedBox(height: Gap.sm),
          FilledButton.icon(
            key: const ValueKey('card-save'),
            onPressed: _name.text.trim().isEmpty ? null : _submit,
            icon: const Icon(AppIcons.check),
            label: Text(context.t(isNew ? 'fm.create' : 'common.save')),
          ),
          const SizedBox(height: Gap.md),
        ],
      ),
    );
  }
}

/// Kartın içi: galeri (önizlemeli ızgara, alt klasörler dahil) ya da klasör
/// (üst düzey liste) görünümü; "Ekle" ile dosya seçilir ya da panodaki
/// yapıştırılır.
class CustomCardScreen extends StatefulWidget {
  final String cardId;
  const CustomCardScreen({super.key, required this.cardId});

  @override
  State<CustomCardScreen> createState() => _CustomCardScreenState();
}

class _CustomCardScreenState extends State<CustomCardScreen> {
  List<FsEntry> _all = const [];
  List<FsEntry> _top = const [];
  bool _loading = true;

  CustomCard? get _card => CustomCards.instance.byId(widget.cardId);

  bool get _important =>
      ImportantFiles.isImportant(_card?.path ?? '', root: FmEnv.primaryRoot);

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_reload);
    CustomCards.instance.addListener(_reload);
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
    final card = _card;
    if (card == null) return;
    setState(() => _loading = true);
    var all = const <FsEntry>[];
    var top = const <FsEntry>[];
    if (Directory(card.path).existsSync()) {
      all = await FsScan.collect([card.path]);
      top = FsScan.sort(await FsScan.list(card.path), FmSort.name);
    }
    if (!mounted) return;
    setState(() {
      _all = [...all]..sort((a, b) => b.modifiedMs.compareTo(a.modifiedMs));
      _top = top;
      _loading = false;
    });
  }

  void _snack(String m) {
    if (mounted) showSnack(context, m);
  }

  Future<void> _copyIn(List<String> sources, {bool cut = false}) async {
    final card = _card;
    if (card == null || sources.isEmpty) return;
    final ok = [
      for (final s in sources)
        if (Directory(s).existsSync() || card.acceptsPath(s)) s,
    ];
    final skipped = sources.length - ok.length;
    if (ok.isEmpty) {
      _snack(context.t('card.none_fit'));
      return;
    }
    await Directory(card.path).create(recursive: true);
    if (!mounted) return;
    final rename = _important ? ImportantFiles.markedNameFor : null;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: cut ? context.t('fm.moving') : context.t('fm.copying'),
      name: context.t(cut ? 'fm.moving_name' : 'fm.copying_name'),
      task: (report, isCancelled) => cut
          ? FileOps.moveAll(ok, card.path,
              onProgress: report, isCancelled: isCancelled, renameTo: rename)
          : FileOps.copyAll(ok, card.path,
              onProgress: report, isCancelled: isCancelled, renameTo: rename),
    );
    if (!mounted) return;
    if (result.hasError) {
      _snack(context.t('fm.transfer_partial', {'error': result.errors.first}));
    } else if (skipped > 0) {
      _snack(context.t('card.skipped', {'n': skipped}));
    }
    FsEvents.changed();
    await _load();
  }

  Future<void> _pick() async {
    final card = _card;
    if (card == null) return;
    final kinds = card.kinds;
    final type = kinds.length == 1 && kinds.contains(FmCategory.image)
        ? FileType.image
        : kinds.length == 1 && kinds.contains(FmCategory.video)
            ? FileType.video
            : kinds.length == 1 && kinds.contains(FmCategory.audio)
                ? FileType.audio
                : kinds.length == 2 &&
                        kinds.containsAll(
                            {FmCategory.image, FmCategory.video})
                    ? FileType.media
                    : FileType.any;
    final res = await AppFilePicker.pickFiles(
      dialogTitle: context.t('card.add_to', {'name': card.name}),
      type: type,
      allowMultiple: true,
    );
    if (res == null || !mounted) return;
    await _copyIn([
      for (final f in res.files)
        if (f.path != null) f.path!,
    ]);
  }

  Future<void> _paste() async {
    final appState = context.read<AppState>();
    final sources = [...appState.clipboard];
    final cut = appState.clipboardCut;
    await _copyIn(sources, cut: cut);
    appState.clearClipboard();
  }

  Future<void> _addMenu() async {
    final appState = context.read<AppState>();
    final pick = await showAppSheet<String>(
      context,
      title: context.t('card.add'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(AppIcons.addFile),
            title: Text(ctx.t('card.add_files')),
            onTap: () => Navigator.pop(ctx, 'pick'),
          ),
          if (appState.hasClipboard)
            ListTile(
              leading: const Icon(AppIcons.paste),
              title: Text(ctx.t(appState.clipboardCut ? 'fm.move' : 'fm.paste')),
              subtitle: Text(ctx.t('count.files',
                  {'n': appState.clipboard.length})),
              onTap: () => Navigator.pop(ctx, 'paste'),
            ),
          ListTile(
            leading: const Icon(AppIcons.newFolder),
            title: Text(ctx.t('fm.new_folder')),
            onTap: () => Navigator.pop(ctx, 'folder'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (pick) {
      case 'pick':
        await _pick();
      case 'paste':
        await _paste();
      case 'folder':
        await _newFolder();
    }
  }

  Future<void> _newFolder() async {
    final card = _card;
    if (card == null) return;
    final failed = context.t('fm.folder_create_failed');
    final name = await showAppPrompt(
      context,
      title: context.t('fm.new_folder'),
      label: context.t('fm.folder_name'),
      initial: context.t('fm.new_folder'),
      confirmLabel: context.t('fm.create'),
    );
    if (name == null || name.trim().isEmpty) return;
    try {
      await Directory(card.path).create(recursive: true);
      await FileOps.createFolder(card.path, name.trim());
    } catch (e) {
      _snack(failed.replaceAll('{error}', userErrorText(e)));
    }
    await _load();
  }

  Future<void> _removeCard() async {
    final card = _card;
    if (card == null) return;
    final ok = await showAppConfirm(
      context,
      title: context.t('card.remove'),
      message: context.t('card.remove_msg', {'name': card.name}),
      confirmLabel: context.t('card.remove'),
    );
    if (!ok || !mounted) return;
    await CustomCards.instance.remove(card.id);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _setView(CardView v) async {
    final card = _card;
    if (card == null) return;
    await CustomCards.instance.upsert(card.copyWith(view: v));
  }

  @override
  Widget build(BuildContext context) {
    final card = _card;
    if (card == null) {
      return Scaffold(appBar: AppBar());
    }
    final color = Color(card.color);
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Icon(cardIconOf(card), color: color),
            const SizedBox(width: Gap.sm),
            Expanded(
              child: Text(card.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t(card.view == CardView.gallery
                ? 'card.view_folder'
                : 'card.view_gallery'),
            icon: Icon(card.view == CardView.gallery
                ? AppIcons.layoutList
                : AppIcons.layoutGallery),
            onPressed: () => _setView(card.view == CardView.gallery
                ? CardView.folder
                : CardView.gallery),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              switch (v) {
                case 'edit':
                  await showCustomCardEditor(context, card: card);
                case 'browser':
                  await Navigator.of(context).push(browserRoute(
                      BrowserScreen(path: card.path, title: card.name)));
                  await _load();
                case 'remove':
                  await _removeCard();
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(value: 'edit', child: Text(ctx.t('card.edit'))),
              PopupMenuItem(
                  value: 'browser',
                  child: Text(ctx.t('important.open_in_browser'))),
              PopupMenuItem(value: 'remove', child: Text(ctx.t('card.remove'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        key: const ValueKey('card-add'),
        onPressed: _addMenu,
        icon: const Icon(AppIcons.add),
        label: Text(context.t('card.add')),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading && _all.isEmpty && _top.isEmpty
            ? ListView(children: const [LinearProgressIndicator(minHeight: 3)])
            : (card.view == CardView.gallery ? _gallery() : _folder()),
      ),
    );
  }

  Widget _empty() => ListView(
        padding: const EdgeInsets.all(Gap.lg),
        children: [
          const SizedBox(height: Gap.xl),
          Icon(cardIconOf(_card!), size: 56, color: Color(_card!.color)),
          const SizedBox(height: Gap.md),
          Text(context.t('card.empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: Gap.xs),
          Text(
            _card!.kinds.isEmpty
                ? context.t('card.empty_sub')
                : context.t('card.empty_kinds', {
                    'kinds': [for (final k in _card!.kinds) context.t(k.labelKey)]
                        .join(', ')
                  }),
            textAlign: TextAlign.center,
          ),
        ],
      );

  Widget _gallery() {
    if (_all.isEmpty) return _empty();
    final paths = [for (final f in _all) f.path];
    return LayoutBuilder(builder: (context, box) {
      final cols = (box.maxWidth / 120).floor().clamp(3, 8);
      return GridView.builder(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(4, 4, 4, 96)),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols, mainAxisSpacing: 4, crossAxisSpacing: 4),
        itemCount: _all.length,
        itemBuilder: (context, i) {
          final f = _all[i];
          final cell = (box.maxWidth - 8 - (cols - 1) * 4) / cols;
          return ImportantGalleryTile(
            key: ValueKey(f.path),
            entry: f,
            size: cell,
            onTap: () => EntryOpener.open(context, f.path, siblings: paths),
          );
        },
      );
    });
  }

  Widget _folder() {
    if (_top.isEmpty) return _empty();
    final files = [
      for (final f in _top)
        if (!f.isDir) f.path,
    ];
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: 96)),
      itemCount: _top.length,
      itemBuilder: (context, i) {
        final e = _top[i];
        return ListTile(
          leading: FmEntryIcon(entry: e),
          title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(e.isDir
              ? context.t('count.files', {
                  'n': _all.where((f) => FsPaths.isInside(e.path, f.path)).length
                })
              : FsPaths.humanSize(e.sizeBytes)),
          onTap: () async {
            if (e.isDir) {
              await Navigator.of(context)
                  .push(browserRoute(BrowserScreen(path: e.path)));
              await _load();
            } else {
              await EntryOpener.open(context, e.path, siblings: files);
            }
          },
        );
      },
    );
  }
}

/// Kartı açar (ekranı iter).
Future<void> openCustomCard(BuildContext context, CustomCard card) =>
    Navigator.of(context)
        .push(browserRoute(CustomCardScreen(cardId: card.id)));

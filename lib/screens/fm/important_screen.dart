import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'photos_screen.dart';
import 'search_screen.dart';

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
  static const folderName = 'Önemli Dosyalar';

  static String pathIn(String root) => p.join(root, folderName);

  /// Klasör varsa yolu, yoksa null (pano alt yazısı için).
  static String? existingPath(String root) {
    final path = pathIn(root);
    return Directory(path).existsSync() ? path : null;
  }

  @override
  State<ImportantScreen> createState() => _ImportantScreenState();
}

class _ImportantScreenState extends State<ImportantScreen> {
  String get _root => ImportantScreen.pathIn(FmEnv.primaryRoot);

  List<FsEntry> _files = const [];
  List<FsEntry> _subFolders = const [];
  bool _loading = true;
  bool _exists = false;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
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
      _snack(createFailed.replaceAll('{error}', '$e'));
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
      if (!Directory(_root).existsSync()) {
        await Directory(_root).create(recursive: true);
      }
      final path = await FileOps.createFolder(_root, name);
      await _load();
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => BrowserScreen(path: path),
      ));
      await _load();
    } catch (e) {
      _snack(createFailed.replaceAll('{error}', '$e'));
    }
  }

  /// Panodaki (kopyala/kes) dosyaları bu klasöre aktarır — "önemli" işaretinin
  /// pratik yolu: dosyayı herhangi bir listede kopyala, burada yapıştır.
  Future<void> _paste() async {
    final appState = context.read<AppState>();
    final sources = appState.clipboard;
    if (sources.isEmpty) return;
    final cut = appState.clipboardCut;
    if (!Directory(_root).existsSync()) {
      await Directory(_root).create(recursive: true);
      if (!mounted) return;
    }
    final result = await showFmProgress<FmOpResult>(
      context,
      title: cut ? context.t('fm.moving') : context.t('fm.copying'),
      task: (report, isCancelled) => cut
          ? FileOps.moveAll(sources, _root,
              onProgress: report, isCancelled: isCancelled)
          : FileOps.copyAll(sources, _root,
              onProgress: report, isCancelled: isCancelled),
    );
    appState.clearClipboard();
    if (!mounted) return;
    if (result.hasError) _snack(context.t('fm.transfer_partial', {'error': result.errors.first}));
    await _load();
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _push(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
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
      showDocKinds: category == FmCategory.document,
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
              icon: const Icon(Icons.search),
              onPressed: () => _push(SearchScreen(
                root: _root,
                rootLabel: ImportantScreen.folderName,
              )),
            ),
          IconButton(
            tooltip: 'Yenile',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _load,
          ),
          if (_exists)
            IconButton(
              tooltip: context.t('important.open_in_browser'),
              icon: const Icon(Icons.folder_open),
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
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xl),
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
              Row(
                children: [
                  Expanded(
                    child: Text(context.t('important.subfolders'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  TextButton.icon(
                    onPressed: _newSubFolder,
                    icon: const Icon(Icons.create_new_folder_outlined),
                    label: const Text('Yeni'),
                  ),
                ],
              ),
              if (_subFolders.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: Gap.sm),
                  child: Text(context.t('important.no_subfolder')),
                ),
              for (final f in _subFolders)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.folder, color: FmColors.folder),
                  title: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text(
                    '${context.t('count.files', {'n': _countIn(f.path)})} · '
                    '${FsPaths.humanSize(_bytesIn(f.path))}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _push(BrowserScreen(path: f.path)),
                ),
            ],
          ],
        ),
      ),
      floatingActionButton: !_exists
          ? null
          : (appState.hasClipboard
              ? FloatingActionButton.extended(
                  onPressed: _paste,
                  icon: const Icon(Icons.content_paste),
                  label: Text(appState.clipboardCut ? context.t('fm.move') : context.t('fm.paste')),
                )
              : FloatingActionButton(
                  onPressed: _newSubFolder,
                  tooltip: context.t('important.new_subfolder'),
                  child: const Icon(Icons.create_new_folder_outlined),
                )),
    );
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
              const Icon(Icons.star, color: FmColors.folder, size: 32),
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
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _createRoot,
                  icon: const Icon(Icons.create_new_folder_outlined),
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

/// Ad soran ortak diyalog (yeni klasör / yeni dosya). Gezgin ekranındaki
/// `_askName` ile aynı davranış; birden çok ekran kullandığı için dışarı
/// alındı.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  required String label,
  required String initial,
}) async {
  final controller = TextEditingController(text: initial);
  final dot = initial.lastIndexOf('.');
  controller.selection = TextSelection(
      baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
  final value = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(labelText: label),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text),
          child: Text(context.t('fm.create')),
        ),
      ],
    ),
  );
  controller.dispose();
  final trimmed = value?.trim();
  return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
}

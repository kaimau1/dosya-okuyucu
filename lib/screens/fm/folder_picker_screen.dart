import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/state/focused_states.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'important_screen.dart';
import '../../core/snack.dart';
import '../../core/user_error.dart';

/// **Hedef klasör seçici** — "şu dosyaları nereye koyayım?" sorusunun tek
/// ekranlık cevabı.
///
/// Kullanıcı isteği (2026-07-29): *"indirilenleri, dosyaları, resimleri,
/// videoları taşıma/kopyalama, önemli klasöre taşıma şu an çok zor"*.
/// Eski akış üç adımdı: kopyala → Dosyalar sekmesine git → hedef klasörü bul →
/// yapıştır. Panoyu ve sekme değiştirmeyi hatırlamak gerekiyordu; kullanıcı
/// haklı olarak "çok zor" dedi.
///
/// Buradaki akış tek adım: uzun bas → **Taşı/Kopyala** → hedefe dokun → bitti.
///
/// Tasarım kararları:
/// - **Kısayollar üstte:** Önemli Dosyalar, İndirilenler, Belgeler, Resimler,
///   Kamera… + favoriler + **son kullanılan hedefler**. İnsanlar dosyayı hep
///   aynı birkaç yere koyar; ağaçta gezinmek istisna olmalı.
/// - Gezinme yine mümkün (klasöre dokun → içine gir), ama **yalnız klasörler**
///   listelenir: dosya göstermek burada gürültü.
/// - **Yeni klasör** buradan açılabilir: hedef henüz yoksa akış kesilmesin.
/// - Kaynağın kendisi ya da kaynağın içi hedef olarak seçilemez (klasörü kendi
///   içine taşıma tuzağı); ilgili satır sönük ve dokunulamaz.
/// - **Ana sayfa kipi** (2026-11-13, kullanıcı: *"düz klasör ekranı yerine
///   bizim ana menümüz gibi olmalı, kartlarda görülmeli"*): başlangıç klasörü
///   verilmezse önce panonun kartları gelir — depolama kartları (dokununca o
///   birimde gezinilir) ve kategori kartları. Kategori kartı (Fotoğraflar,
///   Videolar, Belgeler…) gerçek bir klasör değil: seçilirse öğe
///   **İndirilenler**'e konur (kullanıcı kararı). İndirilenler / Önemli
///   Dosyalar kartları kendi klasörlerine.
class FolderPickerScreen extends StatefulWidget {
  /// Taşınacak/kopyalanacak yollar — kendi içine taşımayı engellemek için.
  final List<String> sources;

  /// Onay düğmesinin metni ("Buraya taşı" / "Buraya kopyala").
  final String actionLabel;

  /// Başlangıç klasörü (yoksa ana bellek).
  final String? startPath;

  /// Önce panodaki gibi kartlar (depolama + kategoriler) gösterilsin mi?
  /// Taşı/Kopyala akışında açık; ayar ekranlarındaki klasör seçimlerinde
  /// kategori → İndirilenler eşlemesi anlamsız olduğu için kapalı.
  final bool homeCards;

  const FolderPickerScreen({
    super.key,
    required this.sources,
    required this.actionLabel,
    this.startPath,
    this.homeCards = false,
  });

  @override
  State<FolderPickerScreen> createState() => _FolderPickerScreenState();
}

class _FolderPickerScreenState extends State<FolderPickerScreen> {
  /// null → ana sayfa (kartlar); dolu → o klasörde gezinme.
  late String? _home =
      widget.homeCards && widget.startPath == null ? '' : null;
  late String _path = widget.startPath ?? FmEnv.primaryRoot;
  List<FsEntry> _dirs = const [];
  bool _loading = true;
  String? _error;

  bool get _atHome => _home != null && _home!.isEmpty;

  @override
  void initState() {
    super.initState();
    if (!_atHome) _load();
  }

  void _goHome() => setState(() => _home = '');

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final entries = await FsScan.list(_path);
      if (!mounted) return;
      setState(() {
        _dirs = FsScan.sort(
          entries.where((e) => e.isDir).toList(),
          FmSort.name,
        );
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _dirs = const [];
        _loading = false;
        _error = context.t('picker.unreadable');
      });
    }
  }

  void _enter(String path) {
    setState(() {
      _path = path;
      if (_home != null) _home = path; // ana sayfadan gelindi: geri → kartlar
    });
    _load();
  }

  /// Hedef geçerli mi? Kaynağın kendisi ya da kaynağın altı olamaz.
  bool _allowed(String dir) {
    for (final src in widget.sources) {
      if (FsPaths.isInside(src, dir)) return false;
    }
    return true;
  }

  Future<void> _newFolder() async {
    final name = await promptForName(
      context,
      title: context.t('fm.new_folder'),
      label: context.t('fm.folder_name'),
      initial: context.t('fm.new_folder'),
    );
    if (name == null) return;
    try {
      final created = await FileOps.createFolder(_path, name);
      _enter(created); // yeni klasörün içine gir: hedef büyük olasılıkla burası
    } catch (e) {
      if (!mounted) return;
      showSnack(context,
          AppStrings.current.t('fp.create_failed', {'error': userErrorText(e)}));
    }
  }

  /// Kısayollar: sabit klasörler + favoriler + son kullanılan hedefler.
  /// Var olmayan yollar gösterilmez (ölü kısayol kullanıcıyı yanıltır);
  /// Önemli Dosyalar istisna — yoksa **oluşturulur**, zaten amacı bu.
  List<({IconData icon, String label, String path, bool create})> _shortcuts(
    AppState appState,
  ) {
    final out = <({IconData icon, String label, String path, bool create})>[
      (
        icon: AppIcons.starOutline,
        label: ImportantScreen.folderName,
        path: ImportantScreen.pathIn(FmEnv.primaryRoot),
        create: true,
      ),
    ];
    for (final f in StorageStats.standardFolders(FmEnv.primaryRoot)) {
      out.add((
        icon: _iconForShortcut(f.icon),
        label: f.label,
        path: f.path,
        create: false,
      ));
    }
    for (final path in appState.fmRecentDestinations) {
      if (out.any((s) => s.path == path)) continue;
      if (!Directory(path).existsSync()) continue;
      out.add((
        icon: AppIcons.history,
        label: p.basename(path),
        path: path,
        create: false,
      ));
    }
    for (final path in appState.bookmarks) {
      if (out.any((s) => s.path == path)) continue;
      if (!Directory(path).existsSync()) continue;
      out.add((
        icon: AppIcons.star,
        label: p.basename(path),
        path: path,
        create: false,
      ));
    }
    return out.where((s) => _allowed(s.path)).toList();
  }

  static IconData _iconForShortcut(String key) => switch (key) {
        'download' => AppIcons.download,
        'document' => AppIcons.newWord,
        'camera' => AppIcons.photoCamera,
        'image' => AppIcons.image,
        'audio' => AppIcons.audio,
        'video' => AppIcons.video,
        'chat' => AppIcons.chat,
        _ => AppIcons.folder,
      };

  /// Kısayola dokunma: klasörü (gerekirse oluşturup) **doğrudan hedef seçer**.
  /// İki dokunuş (gir + onayla) yerine tek dokunuş — kısayolun bütün amacı bu.
  Future<void> _pickShortcut(
      ({IconData icon, String label, String path, bool create}) s) async {
    if (s.create) {
      try {
        final dir = Directory(s.path);
        await dir.create(recursive: true); // varsa dokunmaz
      } catch (e) {
        if (!mounted) return;
        showSnack(context,
            AppStrings.current.t('fp.create_failed', {'error': userErrorText(e)}));
        return;
      }
    }
    if (!mounted) return;
    Navigator.pop(context, s.path);
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watchBrowse();
    final shortcuts = _shortcuts(appState);
    if (_atHome) return _homePage(shortcuts);
    final canPickHere = _allowed(_path);

    return PopScope(
      // Ana sayfadan gelindiyse geri tuşu önce kartlara döner.
      canPop: _home == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goHome();
      },
      child: Scaffold(
      appBar: AppBar(
        leading: _home == null
            ? null
            : IconButton(
                tooltip: context.t('picker.home'),
                icon: const Icon(AppIcons.back),
                onPressed: _goHome,
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('picker.title')),
            Text(
              context.t('picker.summary', {'n': widget.sources.length, 'name': p.basename(_path)}),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: context.t('fm.new_folder'),
            icon: const Icon(AppIcons.newFolder),
            onPressed: _newFolder,
          ),
        ],
      ),
      body: Column(
        children: [
          if (shortcuts.isNotEmpty)
            SizedBox(
              height: 56,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                children: [
                  for (final s in shortcuts)
                    Padding(
                      padding: const EdgeInsetsDirectional.only(end: Gap.sm, top: Gap.sm),
                      child: ActionChip(
                        avatar: Icon(s.icon, size: 18),
                        label: Text(s.label),
                        onPressed: () => _pickShortcut(s),
                      ),
                    ),
                ],
              ),
            ),
          _breadcrumb(),
          const Divider(height: 1),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _body()),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _path,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  FilledButton.icon(
                    onPressed:
                        canPickHere ? () => Navigator.pop(context, _path) : null,
                    icon: const Icon(AppIcons.check),
                    label: Text(widget.actionLabel),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ── Ana sayfa (kartlar) ───────────────────────────────────────────────

  /// Kart seçimi: klasörü (gerekirse oluşturup) doğrudan hedef yapar.
  Future<void> _pickDir(String path) async {
    if (!_allowed(path)) {
      showSnack(context, context.t('picker.source_itself'));
      return;
    }
    try {
      await Directory(path).create(recursive: true); // varsa dokunmaz
    } catch (e) {
      if (!mounted) return;
      showSnack(context,
          AppStrings.current.t('fp.create_failed', {'error': userErrorText(e)}));
      return;
    }
    if (mounted) Navigator.pop(context, path);
  }

  List<FmTileData> _homeTiles() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    final toDownloads = context.t('picker.to_downloads');
    FmTileData cat(FmCategory c, String label, FmTileArt? art) => FmTileData(
          id: c.name,
          icon: FmColors.iconFor(c),
          color: FmColors.forCategory(c),
          art: art,
          label: label,
          subtitle: toDownloads,
          onTap: () => _pickDir(download),
        );
    return [
      FmTileData(
        id: 'downloads',
        icon: AppIcons.download,
        color: AppHues.blue,
        art: FmTileArt.downloads,
        label: context.t('fm.downloads'),
        subtitle: context.t('picker.here_folder'),
        onTap: () => _pickDir(download),
      ),
      FmTileData(
        id: 'important',
        icon: AppIcons.star,
        color: AppHues.amber,
        label: ImportantScreen.folderName,
        subtitle: context.t('picker.here_folder'),
        onTap: () => _pickDir(ImportantScreen.pathIn(FmEnv.primaryRoot)),
      ),
      cat(FmCategory.image, context.t('fm.photos'), FmTileArt.photos),
      cat(FmCategory.video, FmCategory.video.label, FmTileArt.video),
      cat(FmCategory.document, FmCategory.document.label, FmTileArt.document),
      cat(FmCategory.audio, FmCategory.audio.label, FmTileArt.audio),
      FmTileData(
        id: 'apk',
        icon: AppIcons.installMobile,
        color: AppHues.teal,
        label: context.t('fm.apk_archives'),
        subtitle: toDownloads,
        onTap: () => _pickDir(download),
      ),
    ];
  }

  Widget _volumeCard(StorageVolume v) {
    final scheme = Theme.of(context).colorScheme;
    final used = v.totalBytes - v.freeBytes;
    final ratio = v.totalBytes > 0 ? (used / v.totalBytes).clamp(0.0, 1.0) : 0.0;
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.sm),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _enter(v.path),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              SizedBox(
                width: 52,
                height: 52,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: ratio,
                      strokeWidth: 4,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                    Icon(volumeIcon(v), size: 22),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.displayLabel(context.t),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (v.totalBytes > 0)
                      Text(
                        context.t('ana.used_free', {
                          'used': FsPaths.humanSize(used),
                          'free': FsPaths.humanSize(v.freeBytes),
                        }),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              const Icon(AppIcons.chevron),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homePage(
      List<({IconData icon, String label, String path, bool create})>
          shortcuts) {
    final volumes = FmEnv.volumes.isEmpty
        ? [StorageVolume(path: FmEnv.primaryRoot, isPrimary: true,
            labelKey: 'fm.vol_internal')]
        : FmEnv.volumes;
    final quick = shortcuts
        .where((s) => s.path != ImportantScreen.pathIn(FmEnv.primaryRoot))
        .toList();
    final section = Theme.of(context).textTheme.labelLarge;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(context.t('picker.title')),
            Text(
              widget.sources.length == 1
                  ? '${p.basename(widget.sources.first)} · ${widget.actionLabel}'
                  : context.t('picker.summary', {
                      'n': widget.sources.length,
                      'name': widget.actionLabel,
                    }),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.all(Gap.md),
          children: [
            Text(context.t('picker.storage'), style: section),
            const SizedBox(height: Gap.sm),
            for (final v in volumes) _volumeCard(v),
            const SizedBox(height: Gap.sm),
            Text(context.t('picker.places'), style: section),
            const SizedBox(height: Gap.sm),
            FmCategoryGrid(tiles: _homeTiles()),
            if (quick.isNotEmpty) ...[
              const SizedBox(height: Gap.md),
              Text(context.t('fm.quick_folders'), style: section),
              const SizedBox(height: Gap.sm),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final s in quick)
                    ActionChip(
                      avatar: Icon(s.icon, size: 18),
                      label: Text(s.label),
                      onPressed: () => _pickShortcut(s),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _breadcrumb() {
    final parent = p.dirname(_path);
    // Birim kökünün (ana bellek / SD kart) ÜSTÜNE çıkılmaz: `/storage`,
    // `/` gibi klasörlerde kullanıcının yazma izni yok, oraya çıkmak yalnız
    // "boş klasör / izin yok" ekranı gösterirdi.
    final atTop = parent == _path ||
        FmEnv.volumes.any((v) => p.equals(v.path, _path)) ||
        p.equals(_path, FmEnv.primaryRoot);
    return Row(
      children: [
        IconButton(
          tooltip: context.t('picker.parent'),
          icon: const Icon(AppIcons.arrowUp),
          onPressed: atTop ? null : () => _enter(parent),
        ),
        Expanded(
          child: Text(
            p.basename(_path).isEmpty ? _path : p.basename(_path),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final v in FmEnv.volumes)
          IconButton(
            tooltip: v.label,
            icon: Icon(volumeIcon(v)),
            onPressed: () => _enter(v.path),
          ),
      ],
    );
  }

  Widget _body() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    if (_dirs.isEmpty && !_loading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(
            context.t('fp.no_subfolders'),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.builder(
      itemCount: _dirs.length,
      itemBuilder: (context, i) {
        final dir = _dirs[i];
        final allowed = _allowed(dir.path);
        return ListTile(
          enabled: allowed,
          leading: Icon(AppIcons.folder, color: context.fmFolderColor ?? FmColors.folder),
          title: Text(dir.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: allowed ? null : Text(context.t('picker.source_itself')),
          trailing: const Icon(AppIcons.chevron),
          onTap: allowed ? () => _enter(dir.path) : null,
        );
      },
    );
  }
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/download_service.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'analysis_screen.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'cleanup_screen.dart';
import 'download_manager_screen.dart';
import 'downloads_screen.dart';
import 'fm_settings_screen.dart';
import 'important_screen.dart';
import 'installed_apps_screen.dart';
import 'op_history_screen.dart';
import 'organize_screen.dart';
import 'photos_screen.dart';
import 'search_screen.dart';
import 'trash_screen.dart';

/// Dosya yöneticisi panosu: depolama doluluğu, kategoriler, favoriler,
/// hızlı klasörler ve çöp kutusu — tek ekranda.
///
/// Tarama sonucu ([StorageIndex]) süreç boyunca önbelleklenir; sekmeler arası
/// geçişte yeniden taranmaz (aşağı çekerek yenilenir).
class DashboardScreen extends StatefulWidget {
  /// Sekme görünür mü? Görünmezken (IndexedStack'te arka planda) yeniden
  /// tarama yapılmaz; kullanıcı sekmeye dönünce bayat sonuç tazelenir.
  final bool active;

  const DashboardScreen({super.key, this.active = true});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static StorageIndex? _cachedIndex;
  static int _cachedAtMs = 0;

  StorageIndex _index = _cachedIndex ?? StorageIndex.empty;
  bool _scanning = false;
  bool _hasAccess = true;
  int _trashBytes = 0;
  int _trashCount = 0;
  final Map<String, int> _folderSizes = {};

  /// Dosya sistemi değişti mi (sil/kopyala/taşı…) — tarama bayat.
  bool _stale = false;
  int _seenFsVersion = FsEvents.version.value;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_onFsChanged);
    _boot();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_onFsChanged);
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant DashboardScreen old) {
    super.didUpdateWidget(old);
    // Sekmeye geri dönüldü ve arada dosya değişmiş → tazele.
    if (widget.active && !old.active && _stale) _scan();
  }

  /// Silme/taşıma sonrası sayılar eskimesin (kullanıcı hatası 2026-07-25:
  /// silinen dosya panoda sayılmaya devam ediyordu).
  void _onFsChanged() {
    if (!mounted) return;
    if (_seenFsVersion == FsEvents.version.value) return;
    _seenFsVersion = FsEvents.version.value;
    _stale = true;
    // Kullanıcı bu sekmedeyse hemen tazele; değilse dönüşte.
    if (widget.active && !_scanning) _scan();
  }

  Future<void> _boot() async {
    await FmEnv.ensureInit();
    final access = await StoragePermission.hasFullAccess();
    if (!mounted) return;
    setState(() => _hasAccess = access);
    if (_cachedIndex != null) {
      await _loadTrash();
      return;
    }
    // Uygulama yeni açıldı: diskteki arama dizininden panoyu **anında** kur
    // (kullanıcı isteği 2026-07-25: "her açılışta baştan tarıyor"). Ağacı
    // yürümek dakikalar, düz dizin dosyasını okumak saniyenin altı sürer.
    if (await _restoreFromIndex()) {
      await _loadTrash();
      await _loadFolderSizes();
      // Dizin bayatsa (uygulama dışında dosya değişmiş olabilir) sessizce
      // tazele — kullanıcı bu sırada panoyu kullanmaya devam eder.
      if (SearchIndex.isStale || _indexTooOld) unawaited(_scan());
      return;
    }
    await _scan();
  }

  /// Dizin bu süreden eskiyse arka planda tazelenir. Uygulama dışında
  /// (galeri, WhatsApp…) biriken dosyalar sonsuza dek görünmez kalmasın.
  static const _maxIndexAge = Duration(hours: 12);

  bool get _indexTooOld =>
      DateTime.now().millisecondsSinceEpoch - SearchIndex.builtAtMs >
          _maxIndexAge.inMilliseconds;

  /// Arama dizininden pano indeksini kurar; kurulamazsa false (tam tarama).
  Future<bool> _restoreFromIndex() async {
    await SearchIndex.ensureLoaded();
    if (!SearchIndex.isReady) return false;
    final index = await FsScan.indexFromRows(SearchIndex.indexPath);
    if (index == null) return false;
    _cachedIndex = index;
    _cachedAtMs = SearchIndex.builtAtMs;
    if (!mounted) return true;
    setState(() => _index = index);
    return true;
  }

  Future<void> _requestAccess() async {
    final granted = await StoragePermission.request();
    if (!mounted) return;
    setState(() => _hasAccess = granted);
    await FmEnv.ensureInit(force: true);
    await _scan();
    if (!granted && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Tüm dosyalara erişim verilmedi — yalnızca izin verilen '
              'klasörler görünür.'),
          action: SnackBarAction(
            label: 'Ayarlar',
            onPressed: StoragePermission.openSettings,
          ),
        ),
      );
    }
  }

  Future<void> _scan() async {
    if (_scanning) return;
    setState(() => _scanning = true);
    await FmEnv.ensureInit(force: true);
    await SearchIndex.ensureLoaded();
    // Tek yürüyüş hem panoyu hem arama dizinini besler.
    final index = await FsScan.index(
      FmEnv.volumeRoots,
      searchIndexPath:
          FmEnv.appSupportDir.isEmpty ? null : SearchIndex.indexPath,
    );
    await SearchIndex.adoptBuilt(index.searchIndexRows);
    _cachedIndex = index;
    _cachedAtMs = DateTime.now().millisecondsSinceEpoch;
    if (!mounted) return;
    setState(() {
      _index = index;
      _scanning = false;
      _stale = false;
      _seenFsVersion = FsEvents.version.value;
    });
    await _loadTrash();
    await _loadFolderSizes();
    // Depolama takibi: günde bir fotoğraf (tarama zaten yapıldı, ek maliyet yok).
    unawaited(StorageTrend.record(index));
  }

  Future<void> _loadTrash() async {
    // Otomatik temizleme tercihi açıksa süresi geçenleri sil.
    final days = context.read<AppState>().fmTrashAutoDays;
    if (days > 0) await FmEnv.trash.purgeOlderThan(days);
    final items = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _trashCount = items.length;
      _trashBytes = items.fold<int>(0, (sum, i) => sum + i.sizeBytes);
    });
  }

  /// Kısayol kutularının (İndirilenler…) boyutu — indeks klasör bazlı toplam
  /// tutmuyor, bu birkaç klasör ayrıca ölçülür.
  Future<void> _loadFolderSizes() async {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    if (!Directory(download).existsSync()) return;
    final size = await FsScan.folderSize(download);
    if (!mounted) return;
    setState(() => _folderSizes[download] = size);
  }

  Future<void> _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  void _openCategory(FmCategory category, {bool grid = false}) {
    // Pano önbelleği kategori başına en yeni 800 dosyayı tutar (hız için);
    // ekran açılır açılmaz o gösterilir, EKSİKSİZ liste `loadAll` ile arka
    // planda gelir. Kullanıcı hatası 2026-07-29: "videolarda tüm videolar
    // görünmüyor ama dosyaların içinde bulabiliyorum".
    final locked = context.read<AppState>().fmLockedFolders;
    Future<List<FsEntry>> loadAll() =>
        MediaLibrary.categoryFiles(category, lockedFolders: locked);

    // Görsel ve video → Google Fotoğraflar tarzı zaman ekseni (gün/ay/yıl).
    if (category == FmCategory.image || category == FmCategory.video) {
      _push(PhotosScreen(
        title: category.label,
        files: _index.files(category),
        loadAll: loadAll,
      ));
      return;
    }
    _push(CategoryScreen(
      title: category.label,
      files: _index.files(category),
      gridDefault: grid,
      // Belgelerde PDF/Word/Excel/Slayt/Metin süzgeci.
      showDocKinds: category == FmCategory.document,
      loadAll: loadAll,
    ));
  }

  /// Ana sayfadan klasör oluşturma (kullanıcı isteği 2026-07-29).
  /// Konum seçilebilir: ana bellek kökü, standart klasörler ve Önemli
  /// Dosyalar. Oluşan klasör hemen açılır — kullanıcı içine dosya koymak
  /// isteyecektir.
  Future<void> _newFolderFlow() async {
    final locations = <({String label, String path})>[
      (label: 'Ana bellek', path: FmEnv.primaryRoot),
      (
        label: ImportantScreen.folderName,
        path: ImportantScreen.pathIn(FmEnv.primaryRoot)
      ),
      for (final f in StorageStats.standardFolders(FmEnv.primaryRoot))
        (label: f.label, path: f.path),
      for (final v in FmEnv.volumes.where((v) => !v.isPrimary))
        (label: v.label, path: v.path),
    ];
    final result = await showDialog<({String name, String parent})>(
      context: context,
      builder: (ctx) => _NewFolderDialog(locations: locations),
    );
    if (result == null) return;
    try {
      // Hedef (örn. henüz açılmamış "Önemli Dosyalar") yoksa kurulur.
      final parent = Directory(result.parent);
      if (!parent.existsSync()) await parent.create(recursive: true);
      final path = await FileOps.createFolder(result.parent, result.name);
      if (!mounted) return;
      await _push(BrowserScreen(path: path));
      await _scan();
    } catch (e) {
      _snack('Klasör oluşturulamadı: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final volumes = FmEnv.volumes;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dosyalar'),
        actions: [
          IconButton(
            tooltip: 'Ara',
            icon: const Icon(Icons.search),
            onPressed: () => _push(SearchScreen(
              root: FmEnv.primaryRoot,
              rootLabel: 'Tüm dosyalar',
            )),
          ),
          IconButton(
            tooltip: 'Yeniden tara',
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
          IconButton(
            tooltip: 'Dosya yöneticisi ayarları',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await _push(const FmSettingsScreen());
              if (mounted) await _loadTrash();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
          children: [
            if (!_hasAccess) _permissionCard(),
            if (_scanning) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: Gap.sm),
              Text('Depolama taranıyor…',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Gap.sm),
            ],
            for (final v in volumes) ...[
              _VolumeCard(
                volume: v,
                onTap: () => _push(BrowserScreen(path: v.path, title: v.label)),
              ),
              const SizedBox(height: Gap.sm),
            ],
            const SizedBox(height: Gap.sm),
            _categoryGrid(),
            if (appState.bookmarks.isNotEmpty) ...[
              const SizedBox(height: Gap.lg),
              _sectionTitle('Favoriler'),
              for (final path in appState.bookmarks)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.star, color: FmColors.folder),
                  title: Text(p.basename(path)),
                  subtitle:
                      Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => _push(BrowserScreen(path: path)),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => appState.toggleBookmark(path),
                  ),
                ),
            ],
            const SizedBox(height: Gap.lg),
            _sectionTitle('Hızlı klasörler'),
            _quickFolders(),
            if (_cachedAtMs > 0) ...[
              const SizedBox(height: Gap.lg),
              Center(
                child: Text(
                  'Son tarama: ${FsPaths.humanDate(_cachedAtMs)} · '
                  '${_index.totalFiles} dosya',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _newFolderFlow,
        tooltip: 'Yeni klasör',
        child: const Icon(Icons.create_new_folder_outlined),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      );

  Widget _permissionCard() => Card(
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_special_outlined),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text('Tüm dosyalara erişim gerekli',
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              const Text(
                'Telefonundaki tüm klasörleri görebilmek, kopyalayıp '
                'taşıyabilmek için Android’in “Tüm dosyalara erişim” iznini '
                'vermen gerekiyor. İzin yalnızca cihazda kullanılır; hiçbir '
                'veri gönderilmez.',
              ),
              const SizedBox(height: Gap.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _requestAccess,
                  icon: const Icon(Icons.lock_open),
                  label: const Text('İzin ver'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _categoryGrid() {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    final primary = FmEnv.volumes.firstOrNullVolume;
    final importantPath = ImportantScreen.pathIn(FmEnv.primaryRoot);
    final importantStat = _importantStat(importantPath);
    final tiles = <FmTileData>[
      // Kullanıcının kendi seçtiği dosyalar — ilk sırada, çünkü en sık
      // dönülecek yer burası (istek 2026-07-29).
      FmTileData(
        icon: Icons.star_outline,
        color: FmColors.folder,
        label: ImportantScreen.folderName,
        subtitle: importantStat == null
            ? 'Oluştur'
            : (importantStat.count == 0
                ? 'Aç'
                : '${FsPaths.humanSize(importantStat.bytes)} '
                    '(${importantStat.count})'),
        onTap: () async {
          await _push(const ImportantScreen());
          if (mounted) setState(() {});
        },
      ),
      FmTileData(
        icon: Icons.download_outlined,
        color: const Color(0xFF3B6EF6),
        label: 'İndirilenler',
        subtitle: _folderSizes[download] != null
            ? FsPaths.humanSize(_folderSizes[download]!)
            : 'Klasör',
        onTap: () {
          final path = downloadsPathIn(FmEnv.primaryRoot);
          if (path != null) {
            // Yaş odaklı liste: son açılma + "eskileri seç" ile hızlı temizlik.
            _push(DownloadsScreen(path: path));
          } else {
            _snack('İndirilenler klasörü bulunamadı.');
          }
        },
      ),
      FmTileData(
        icon: Icons.pie_chart_outline,
        color: const Color(0xFF546E7A),
        label: 'Bellek Analizi',
        subtitle: primary != null && primary.hasStats
            ? 'Kullanılan %${(primary.usedFraction * 100).round()}'
            : 'Ayrıntılar',
        onTap: () =>
            _push(AnalysisScreen(index: _index, volumes: FmEnv.volumes)),
      ),
      // Bağlantıdan indirme (kullanıcı isteği 2026-07-29): tarayıcı yerine
      // buradan indirilince dosya istenen klasöre iniyor ve kayıp olmuyor.
      FmTileData(
        icon: Icons.download_for_offline_outlined,
        color: const Color(0xFF1565C0),
        label: 'İndir',
        subtitle: DownloadService.instance.hasActive
            ? '${DownloadService.instance.activeTasks.length} sürüyor'
            : 'Bağlantıdan',
        onTap: () async {
          await _push(const DownloadManagerScreen());
          if (mounted) setState(() {});
        },
      ),
      FmTileData(
        icon: Icons.cleaning_services_outlined,
        color: const Color(0xFF00838F),
        label: 'Yer aç',
        subtitle: 'Temizlik önerileri',
        onTap: () => _push(CleanupScreen(index: _index)),
      ),
      FmTileData(
        icon: Icons.auto_awesome_motion,
        color: const Color(0xFF5E35B1),
        label: 'Otomatik düzenle',
        subtitle: 'Klasörlere ayır',
        onTap: () => _push(OrganizeScreen(
          path: downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot,
        )),
      ),
      FmTileData(
        icon: Icons.history_toggle_off,
        color: const Color(0xFF6D4C41),
        label: 'Son işlemler',
        subtitle: 'Geri al',
        onTap: () => _push(const OpHistoryScreen()),
      ),
      FmTileData(
        icon: Icons.delete_outline,
        color: const Color(0xFF78909C),
        label: 'Çöp Kutusu',
        subtitle: _trashCount == 0
            ? 'Boş'
            : '$_trashCount öğe · ${FsPaths.humanSize(_trashBytes)}',
        onTap: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TrashScreen()));
          _loadTrash();
        },
      ),
      _categoryTile(FmCategory.image, grid: true),
      _categoryTile(FmCategory.audio),
      _categoryTile(FmCategory.video, grid: true),
      _categoryTile(FmCategory.document),
      // Telefonda YÜKLÜ uygulamalar (dosya değil) — son açılma tarihiyle.
      FmTileData(
        icon: Icons.android,
        color: FmColors.apk,
        label: 'Uygulamalar',
        subtitle: 'Yüklü · son açılma',
        onTap: () => _push(const InstalledAppsScreen()),
      ),
      // Kurulum dosyaları AYRI kutuda (kullanıcı isteği).
      FmTileData(
        icon: Icons.archive_outlined,
        color: const Color(0xFF00897B),
        label: 'APK dosyaları',
        subtitle: _index.stat(FmCategory.apk).count == 0
            ? (_scanning ? 'Taranıyor…' : 'Yok')
            : '${FsPaths.humanSize(_index.stat(FmCategory.apk).bytes)} '
                '(${_index.stat(FmCategory.apk).count})',
        onTap: () => _push(CategoryScreen(
          title: 'APK dosyaları',
          files: _index.files(FmCategory.apk),
        )),
      ),
      _categoryTile(FmCategory.archive),
      FmTileData(
        icon: Icons.history,
        color: const Color(0xFF8D6E63),
        label: 'Yeni Dosyalar',
        subtitle: '${_index.recent.length} dosya',
        onTap: () => _push(CategoryScreen(
          title: 'Yeni Dosyalar',
          files: _index.recent,
        )),
      ),
    ];

    return FmCategoryGrid(tiles: tiles);
  }

  FmTileData _categoryTile(FmCategory category, {bool grid = false}) {
    final stat = _index.stat(category);
    return FmTileData(
      icon: FmColors.iconFor(category),
      color: FmColors.forCategory(category),
      label: category.label,
      subtitle: stat.count == 0
          ? (_scanning ? 'Taranıyor…' : 'Yok')
          : '${FsPaths.humanSize(stat.bytes)} (${stat.count})',
      onTap: () => _openCategory(category, grid: grid),
    );
  }

  Widget _quickFolders() {
    final folders = StorageStats.standardFolders(FmEnv.primaryRoot);
    if (folders.isEmpty) {
      return const Text('Standart klasörler bulunamadı.');
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        for (final f in folders)
          ActionChip(
            avatar: const Icon(Icons.folder_outlined, size: 18),
            label: Text(f.label),
            onPressed: () => _push(BrowserScreen(path: f.path, title: f.label)),
          ),
      ],
    );
  }

  /// Önemli Dosyalar kutusunun sayıları — pano indeksinden süzülür (ek tarama
  /// yok). Klasör yoksa null → kutuda "Oluştur" yazar.
  CategoryStat? _importantStat(String path) {
    if (!Directory(path).existsSync()) return null;
    var count = 0;
    var bytes = 0;
    for (final entry in _index.recent.followedBy(_index.largest)) {
      if (!FsPaths.isInside(path, entry.path)) continue;
      count++;
      bytes += entry.sizeBytes;
    }
    // İndeks yalnız "en yeni/en büyük" listeleri tutar; klasör bu listelere
    // hiç girmemişse sayı 0 çıkar — o zaman sayı yerine yönlendirme yazılır.
    return count == 0 ? const CategoryStat(0, 0) : CategoryStat(count, bytes);
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

/// Ana sayfadan klasör oluşturma diyaloğu: ad + konum.
class _NewFolderDialog extends StatefulWidget {
  final List<({String label, String path})> locations;
  const _NewFolderDialog({required this.locations});

  @override
  State<_NewFolderDialog> createState() => _NewFolderDialogState();
}

class _NewFolderDialogState extends State<_NewFolderDialog> {
  final _controller = TextEditingController(text: 'Yeni klasör');
  late String _parent = widget.locations.first.path;

  @override
  void initState() {
    super.initState();
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, parent: _parent));
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Yeni klasör'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Klasör adı'),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.md),
            DropdownButtonFormField<String>(
              value: _parent,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Konum'),
              items: [
                for (final l in widget.locations)
                  DropdownMenuItem(
                    value: l.path,
                    child: Text(l.label, overflow: TextOverflow.ellipsis),
                  ),
              ],
              onChanged: (v) => setState(() => _parent = v ?? _parent),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Vazgeç')),
          FilledButton(onPressed: _submit, child: const Text('Oluştur')),
        ],
      );
}

class _VolumeCard extends StatelessWidget {
  final StorageVolume volume;
  final VoidCallback onTap;
  const _VolumeCard({required this.volume, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
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
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: CircularProgressIndicator(
                        value: volume.hasStats ? volume.usedFraction : 0,
                        strokeWidth: 6,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ),
                    Icon(
                      volume.isPrimary ? Icons.smartphone : Icons.sd_card,
                      size: 22,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(volume.label, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      volume.hasStats
                          ? '${FsPaths.humanSize(volume.usedBytes)} / '
                              '${FsPaths.humanSize(volume.totalBytes)}'
                          : volume.path,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// Küçük yardımcı: liste boşsa null döndüren "ilk birim".
extension on List<StorageVolume> {
  StorageVolume? get firstOrNullVolume => isEmpty ? null : first;
}

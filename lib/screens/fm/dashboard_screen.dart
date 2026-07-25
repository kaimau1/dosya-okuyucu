import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import 'analysis_screen.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'downloads_screen.dart';
import 'fm_settings_screen.dart';
import 'installed_apps_screen.dart';
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
    if (_cachedIndex == null) {
      await _scan();
    } else {
      await _loadTrash();
    }
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
    // Görsel ve video → Google Fotoğraflar tarzı zaman ekseni (gün/ay/yıl).
    if (category == FmCategory.image || category == FmCategory.video) {
      _push(PhotosScreen(
        title: category.label,
        files: _index.files(category),
      ));
      return;
    }
    _push(CategoryScreen(
      title: category.label,
      files: _index.files(category),
      gridDefault: grid,
      // Belgelerde PDF/Word/Excel/Slayt/Metin süzgeci.
      showDocKinds: category == FmCategory.document,
    ));
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
    final tiles = <_TileData>[
      _TileData(
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
      _TileData(
        icon: Icons.pie_chart_outline,
        color: const Color(0xFF546E7A),
        label: 'Bellek Analizi',
        subtitle: primary != null && primary.hasStats
            ? 'Kullanılan %${(primary.usedFraction * 100).round()}'
            : 'Ayrıntılar',
        onTap: () =>
            _push(AnalysisScreen(index: _index, volumes: FmEnv.volumes)),
      ),
      _TileData(
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
      _TileData(
        icon: Icons.android,
        color: FmColors.apk,
        label: 'Uygulamalar',
        subtitle: 'Yüklü · son açılma',
        onTap: () => _push(const InstalledAppsScreen()),
      ),
      // Kurulum dosyaları AYRI kutuda (kullanıcı isteği).
      _TileData(
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
      _TileData(
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

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 150,
        childAspectRatio: 0.95,
        mainAxisSpacing: Gap.sm,
        crossAxisSpacing: Gap.sm,
      ),
      itemCount: tiles.length,
      itemBuilder: (context, i) => _CategoryTile(data: tiles[i]),
    );
  }

  _TileData _categoryTile(FmCategory category, {bool grid = false}) {
    final stat = _index.stat(category);
    return _TileData(
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

  void _snack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _TileData {
  final IconData icon;
  final Color color;
  final String label;
  final String subtitle;
  final VoidCallback onTap;
  const _TileData({
    required this.icon,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });
}

class _CategoryTile extends StatelessWidget {
  final _TileData data;
  const _CategoryTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final tint =
        dark ? Color.lerp(data.color, Colors.white, 0.25)! : data.color;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: data.onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: dark ? 0.22 : 0.13),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(data.icon, color: tint),
              ),
              const SizedBox(height: Gap.sm),
              Text(
                data.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text(
                data.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
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

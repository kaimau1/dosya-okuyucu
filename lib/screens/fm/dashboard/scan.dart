part of '../dashboard_screen.dart';

extension _DashboardScreenScanPart on _DashboardScreenState {
  Future<void> _requestAccess() async {
    final granted = await StoragePermission.request();
    if (!mounted) return;
    _partSetState(() => _hasAccess = granted);
    await FmEnv.ensureInit(force: true);
    await _scan();
    if (!granted && mounted) {
      showSnackBarReplacing(ScaffoldMessenger.of(context), SnackBar(
          content: Text(context.t('fm.permission_denied')),
          action: SnackBarAction(
            label: context.t('common.settings'),
            onPressed: StoragePermission.openSettings,
          ),
        ),);
    }
  }

  /// [allowRepeat] false ise, tarama sırasında dosya sistemi değişse bile
  /// tekrar taranmaz — yalnız `_stale` işaretlenir. Zincirin uzunluğu böylece
  /// en çok iki tur: sürekli yazan bir işlem (büyük kopyalama) panoyu sonsuza
  /// dek yeniden taratmasın.
  Future<void> _scan({bool allowRepeat = true}) async {
    if (_scanning) return;
    _scanStartedAtMs = DateTime.now().millisecondsSinceEpoch;
    _partSetState(() => _scanning = true);
    // Sürüm yürüyüşün BAŞINDA alınır. Eskiden bitişte `FsEvents.version`
    // okunuyordu: tarama sürerken (dakikalar sürebilir) yapılan bir silme/
    // taşıma "görülmüş" sayılıp `_stale` bayrağı temizleniyordu → o değişiklik
    // panoya hiç yansımıyor, kullanıcı silinen dosyayı sayılarda görmeye devam
    // ediyordu. Artık arada bir şey olduysa tarama bir kez tekrarlanır.
    final startedAtVersion = FsEvents.version.value;
    await FmEnv.ensureInit(force: true);
    await SearchIndex.ensureLoaded();
    // Tek yürüyüş hem panoyu hem arama dizinini besler.
    final index = await FsScan.index(
      FmEnv.volumeRoots,
      searchIndexPath:
          FmEnv.appSupportDir.isEmpty ? null : SearchIndex.indexPath,
      statFolders: _statFolders,
    );
    await SearchIndex.adoptBuilt(index.searchIndexRows);
    _DashboardScreenState._cachedIndex = index;
    _DashboardScreenState._cachedAtMs = DateTime.now().millisecondsSinceEpoch;
    // Bu taramanın süresi bir sonrakinin "~N sn kaldı" tahmini olur.
    _DashboardScreenState._lastScanDurationMs = _DashboardScreenState._cachedAtMs - _scanStartedAtMs;
    unawaited(_DashboardScreenState._rememberScanDuration(_DashboardScreenState._lastScanDurationMs!));
    if (!mounted) return;
    final changedDuringScan = FsEvents.version.value != startedAtVersion;
    _partSetState(() {
      _index = index;
      _scanning = false;
      _stale = changedDuringScan;
      _seenFsVersion = FsEvents.version.value;
    });
    await _loadTrash();
    await _loadFolderSizes();
    // Depolama takibi: günde bir fotoğraf (tarama zaten yapıldı, ek maliyet yok).
    unawaited(StorageTrend.record(index));
    // Tarama sürerken dosya sistemi değiştiyse sonuç daha doğarken bayattı.
    // Bir kez tekrarlanır; ikinci turda da değişmişse (aktif bir kopyalama
    // sürüyor olabilir) `_stale` bayrağı bırakılır ve kullanıcı sekmeye
    // dönünce / aşağı çekince tazelenir.
    if (changedDuringScan && allowRepeat && mounted && widget.active) {
      _stale = false;
      await _scan(allowRepeat: false);
    }
  }

  Future<void> _loadTrash() async {
    // Otomatik temizleme tercihi açıksa süresi geçenleri sil.
    final days = context.read<AppState>().fmTrashAutoDays;
    if (days > 0) await FmEnv.trash.purgeOlderThan(days);
    final items = await FmEnv.trash.list();
    if (!mounted) return;
    _partSetState(() => _trashCount = items.length);
  }

  /// Kısayol kutularının (İndirilenler…) boyutu — indeks klasör bazlı toplam
  /// tutmuyor, bu birkaç klasör ayrıca ölçülür.
  Future<void> _loadFolderSizes() async {
    final download = p.join(FmEnv.primaryRoot, 'Download');
    if (!Directory(download).existsSync()) return;
    final size = await FsScan.folderSize(download);
    if (!mounted) return;
    _partSetState(() => _folderSizes[download] = size);
  }

  // `browserRoute`: gezgin sayfası yol hapı atlaması için işaretlenir.
  Future<void> _push(Widget screen) =>
      Navigator.of(context).push(browserRoute(screen));

  Widget _categoryScreen(FmCategory category, {bool grid = false}) {
    // Pano önbelleği kategori başına en yeni 800 dosyayı tutar (hız için);
    // ekran açılır açılmaz o gösterilir, EKSİKSİZ liste `loadAll` ile arka
    // planda gelir. Kullanıcı hatası 2026-07-29: "videolarda tüm videolar
    // görünmüyor ama dosyaların içinde bulabiliyorum".
    final locked = context.read<AppState>().fmLockedFolders;
    Future<List<FsEntry>> loadAll() =>
        MediaLibrary.categoryFiles(category, lockedFolders: locked);

    // Görsel ve video → Google Fotoğraflar tarzı zaman ekseni (gün/ay/yıl).
    if (category == FmCategory.image || category == FmCategory.video) {
      return PhotosScreen(
        title: category.label,
        // Kapsam: TÜM depolama. Önemli Dosyalar ekranı aynı başlıkla ("Görüntüler")
        // çok daha küçük bir küme açıyor — benzer tarama sonuçları karışmasın.
        scopeId: 'depolama-${category.name}',
        files: _index.files(category),
        loadAll: loadAll,
      );
    }
    return CategoryScreen(
      title: category.label,
      files: _index.files(category),
      gridDefault: grid,
      // Belgelerde PDF/Word/Excel/Slayt/Metin süzgeci.
      showDocKinds: category == FmCategory.document,
      loadAll: loadAll,
    );
  }

  /// Ana sayfadan klasör oluşturma (kullanıcı isteği 2026-07-29).
  /// Konum seçilebilir: ana bellek kökü, standart klasörler ve Önemli
  /// Dosyalar. Oluşan klasör hemen açılır — kullanıcı içine dosya koymak
  /// isteyecektir.
  Future<void> _newFolderFlow() async {
    // Hata metni await'ten ÖNCE çevrilir (asenkron boşluktan sonra `context`
    // kullanılamaz).
    final createFailed = context.t('fm.folder_create_failed');
    final locations = <({String label, String path})>[
      (label: context.t('fm.internal_storage'), path: FmEnv.primaryRoot),
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
      _snack(createFailed.replaceAll('{error}', userErrorText(e)));
    }
  }
}

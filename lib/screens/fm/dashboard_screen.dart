import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/download_service.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/remote/ftp_service.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/job_queue.dart';
import '../../services/fm/media_library.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../services/fm/tool_usage.dart';
import '../../services/fm/remote/saf_fs.dart';
import '../../services/fm/remote/usb_fs.dart';
import '../../services/fm/usb/usb_host.dart';
import '../../services/fm/volume_watcher.dart';
import 'remote/remote_browser_screen.dart';
import 'usb_diagnostics_screen.dart';
import '../../widgets/crash_notice.dart';
import '../../widgets/fm/fm_category_tile.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/new_document_sheet.dart';
import '../../widgets/scan_flow.dart';
import '../../widgets/section_header.dart';
import 'analysis_screen.dart';
import 'activity_screen.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'chat_cleanup_screen.dart';
import 'cleanup_screen.dart';
import 'download_manager_screen.dart';
import 'downloads_screen.dart';
import 'drive_screen.dart';
import 'remote/ftp_server_screen.dart';
import 'remote/remote_connections_screen.dart';
import '../settings_screen.dart';
import 'important_screen.dart';
import 'installed_apps_screen.dart';
import 'new_files_screen.dart';
import 'jobs_screen.dart';
import 'op_history_screen.dart';
import 'open_history_screen.dart';
import 'organize_screen.dart';
import 'photos_screen.dart';
import 'search_screen.dart';
import 'similar_screen.dart';
import 'trash_screen.dart';
import '../../core/snack.dart';

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

class _DashboardScreenState extends State<DashboardScreen>
    with WidgetsBindingObserver {
  static StorageIndex? _cachedIndex;
  static int _cachedAtMs = 0;

  StorageIndex _index = _cachedIndex ?? StorageIndex.empty;

  /// Takılan/çıkarılan harici bellekleri izler.
  final VolumeWatcher _volumes = VolumeWatcher();
  StreamSubscription<VolumeChange>? _volumeSub;

  /// Klasör izni verilmiş SAF ağaçları (yol yoluyla görünmeyen bellekler).
  /// Kutunun alt yazısı bunu da sayar: izin verilmiş bir USB dururken
  /// "Takılı değil" yazmak yanlış olurdu.
  List<SafRoot> _safRoots = const [];

  /// Android'in bağlamadığı ama uygulamanın sürebileceği USB aygıtları.
  List<UsbDevice> _rawUsbCards = const [];

  bool _scanning = false;
  bool _hasAccess = true;
  int _trashCount = 0;
  final Map<String, int> _folderSizes = {};

  /// Yüklü uygulamaların toplam boyutu — "Uygulamalar" kutusunun alt yazısı.
  /// Ölçüm "Kullanım erişimi" iznine bağlı (bkz. `AppStorageService`); izin
  /// yokken `null` kalır ve kutuda sayı YAZILMAZ — sıfır yazmak "hiç yer
  /// kaplamıyor" demek olurdu.
  int? _appsBytes;

  /// Dosya sistemi değişti mi (sil/kopyala/taşı…) — tarama bayat.
  bool _stale = false;
  int _seenFsVersion = FsEvents.version.value;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    FsEvents.version.addListener(_onFsChanged);
    // AI kartı analiz sayısını gösteriyor; indeks diskten okunmadan sayı 0
    // görünürdü. Okuma bittiğinde `AiIndex.revision` kartı tazeler.
    AiIndex.ensureLoaded();
    // Araç sırası kullanım sayaçlarından geliyor; sayaçlar diskten gelene
    // kadar ızgara yazılış sırasında çizilir, sonra bir kez tazelenir.
    ToolUsage.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    _boot();
    unawaited(_loadAppsSize());
    _startVolumeWatch();
  }

  /// Uygulama boyutları platform kanalından gelir (yüzlerce binder çağrısı),
  /// o yüzden panonun açılışını beklemez: arka planda gelir, gelince kutunun
  /// alt yazısı dolar. Sonuç `InstalledAppsService` içinde 5 dakika saklandığı
  /// için Bellek Analizi ekranı da bundan sonra anında açılır.
  Future<void> _loadAppsSize() async {
    final summary = await InstalledAppsService.summary();
    if (!mounted || !summary.hasData) return;
    setState(() => _appsBytes = summary.totalBytes);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FsEvents.version.removeListener(_onFsChanged);
    AppStorageService.setUsbAttachedHandler(null);
    unawaited(_volumeSub?.cancel());
    unawaited(_volumes.dispose());
    super.dispose();
  }

  /// **Harici bellek izleme** (kullanıcı isteği 2026-09-01: *"harici USB
  /// taktığımda göremiyorum onu uygulamamızda görebilmeliyiz, otomatik
  /// tanımalı"*).
  ///
  /// Pano açıkken takılan bir USB/SD anında listeye giriyor ve kullanıcıya
  /// "Aç" düğmeli bir şerit gösteriliyor — uygulamayı kapatıp açmak gerekmez.
  void _startVolumeWatch() {
    _volumeSub = _volumes.changes.listen((change) {
      if (!mounted) return;
      setState(() {}); // birim listesi tazelendi (FmEnv.volumes)
      final attached =
          change.attached.where((v) => v.isRemovable).toList();
      if (attached.isNotEmpty) {
        final volume = attached.first;
        showSnack(
          context,
          context.t('fm.usb_attached',
              {'volume': volume.displayLabel(context.t)}),
          action: SnackBarAction(
            label: context.t('fm.usb_open'),
            onPressed: () => unawaited(_push(BrowserScreen(path: volume.path))),
          ),
        );
      } else if (change.detached.isNotEmpty) {
        showSnack(context, context.t('fm.usb_detached'));
      }
    });
    _volumes.start();
    unawaited(_loadSafRoots());
    unawaited(_openUsbIfLaunchedByIt());
    // Uygulama ZATEN ön plandayken seçiciden bizi seçmek `resumed` üretmiyor;
    // native taraf olayı itiyor (kullanıcı 2026-09-02: "basıyorum tepki
    // vermiyor").
    AppStorageService.setUsbAttachedHandler(() {
      if (!mounted) return;
      unawaited(_openUsbIfLaunchedByIt(force: true));
    });
  }

  /// Uygulama **USB takılması yüzünden** açıldıysa doğrudan o belleği aç.
  ///
  /// Kullanıcı isteği (2026-09-01): *"diğer bir uygulama açık olmasa bile USB
  /// takıldığında otomatik algılayıp 'açayım mı' diye popup bildirim
  /// gönderdi"*. O pencerede bizi seçen kullanıcı panoyu değil BELLEĞİ görmek
  /// ister; panoda bırakıp "şuraya bak" demek yarım iş olurdu.
  ///
  /// Birim henüz bağlanmamış olabilir (Android takma ile bağlama arasında bir
  /// süre geçiriyor) → kısa aralıklarla birkaç kez bakılır, sonra vazgeçilir.
  Future<void> _openUsbIfLaunchedByIt({bool force = false}) async {
    if (!force && !await AppStorageService.launchedByUsb()) return;
    for (var attempt = 0; attempt < 6; attempt++) {
      await _volumes.rescan();
      // **Tür değil, TAKILABİLİRLİK aranıyor** (kullanıcı ekran görüntüsü
      // 2026-09-02): bellek `/storage/8A07-470A` altında bağlanmıştı ama
      // bağlama tablosundaki aygıt satırı `/dev/fuse` olduğu için türü
      // "SD kart" tahmin edilmişti. `kind == usb` şartı yüzünden akış onu
      // hiç görmedi ve altı denemenin sonunda "takılı ama yol vermiyor"
      // diye YANLIŞ uyarı verdi — bellek gayet açılabilir durumdayken.
      final usb = FmEnv.volumes.where((v) => v.isRemovable).firstOrNull;
      if (usb != null) {
        if (!mounted) return;
        await _push(BrowserScreen(
            path: usb.path, title: usb.displayLabel(context.t)));
        return;
      }
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    // Altı denemede bağlanmadı. **Android bağlamıyorsa uygulama kendi
    // sürsün:** kullanıcı "aç" dedi, ona "olmadı" demeden önce elimizdeki
    // son yolu denemeliyiz (izin penceresi çıkar, verilirse bellek açılır).
    final drivable =
        (await UsbHost.devices()).where((d) => d.isDrivable).toList();
    if (!mounted) return;
    if (drivable.isNotEmpty) {
      await _openRawUsb(drivable.first.name);
      return;
    }
    // Sürülebilir aygıt da yok: sebebi söyle ve çıkış yolunu ver.
    await _reportStuckExternal();
  }

  /// Bellek takılı ama gezilemiyorsa **sebebi + çıkış yolu**.
  ///
  /// Kullanıcı hatası 2026-09-02: mesaj yalnız "Android onu uygulamalara
  /// açmadı" diyordu; kullanıcının elinde yapacak bir şey kalmıyordu ("hata
  /// alıyoruz"). Oysa çıkış yolu var: klasör izni (SAF). Şeridin düğmesi
  /// seçiciyi DOĞRUDAN o birimin üstünde açıyor.
  ///
  /// Hiç birim bilinmiyorsa "takılı değil" der (yalan değil, gerçekten yok).
  Future<void> _reportStuckExternal() async {
    final stuck = await VolumeWatcher.attachedButUnusable();
    if (!mounted) return;
    if (stuck == null) {
      // "Yok" derken bile ölçüme bir kapı bırak: kullanıcı belleğin takılı
      // olduğunu biliyor ve bizim neyi göremediğimizi görmek istiyor.
      showSnack(
        context,
        context.t('fm.external_none'),
        duration: kSnackAction,
        action: SnackBarAction(
          label: context.t('usb.diag_title'),
          onPressed: () => unawaited(_openDiagnostics()),
        ),
      );
      return;
    }
    showSnack(
      context,
      context.t('fm.external_unusable', {'name': stuck.name}),
      duration: kSnackAction,
      action: SnackBarAction(
        label: context.t('saf.pick'),
        onPressed: () => unawaited(_openViaSaf(volume: stuck.key)),
      ),
    );
  }

  /// Uygulama arka plandan dönünce sıcak klasörler yeniden taranır.
  ///
  /// Kullanıcı isteği (2026-08-17): *"uygulama açılır açılmaz arka planda
  /// güncellenmeli, her seferinde ben açtığımda 1 sn önce eklenen bir görsel
  /// belge ses her ne varsa görmeliyim"*. İnsanlar uygulamayı kapatmıyor:
  /// WhatsApp'tan bir belge indirip buraya DÖNÜYOR. `initState` o dönüşte
  /// çalışmadığı için tazeleme yaşam döngüsüne de bağlandı.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_catchUp());
      // Uygulama arka plandayken takılan bellek de görülsün; izleme arka
      // planda durduruluyor (boşuna pil harcamasın).
      _volumes.start();
      unawaited(_volumes.rescan());
      unawaited(_loadSafRoots());
      // Uygulama AÇIKKEN USB takılıp "Dosya Okuyucu ile aç" seçilirse
      // Android yeni bir intent gönderir (singleTask) ve `initState`
      // çalışmaz — eylemi burada da soruyoruz. Eylem okununca native
      // tarafta temizlendiği için iki kez tetiklenmez.
      unawaited(_openUsbIfLaunchedByIt());
    } else if (state == AppLifecycleState.paused) {
      _volumes.stop();
    }
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
      // Süreç ayakta ama kullanıcı arada dosya eklemiş olabilir.
      unawaited(_catchUp());
      return;
    }
    // Uygulama yeni açıldı: diskteki arama dizininden panoyu **anında** kur
    // (kullanıcı isteği 2026-07-25: "her açılışta baştan tarıyor"). Ağacı
    // yürümek dakikalar, düz dizin dosyasını okumak saniyenin altı sürer.
    if (await _restoreFromIndex()) {
      await _loadTrash();
      await _loadFolderSizes();
      // Dizin diskten geldi: en son taramadan BU YANA eklenenler eksik.
      // Sıcak klasör yakalaması onları hemen getirir — tam tarama (aşağıda,
      // koşullu) dakikalar sürebilir, kullanıcı o kadar bekleyemez.
      unawaited(_catchUp());
      // Dizin bayatsa (uygulama dışında dosya değişmiş olabilir) sessizce
      // tazele — kullanıcı bu sırada panoyu kullanmaya devam eder.
      // `isStale` = BİZİM yaptığımız bir dosya işlemi sonucu bayat: kullanıcı
      // silmiş/taşımışsa sayıların yanlış kalması kabul edilemez, tercihten
      // bağımsız tazelenir. `_indexTooOld` ise "uygulama dışında bir şey
      // değişmiş olabilir" varsayımıyla yapılan **tahmini** tam tarama —
      // pahalı olan bu, ve kapatılabilen de bu (Ayarlar > Pil ve başarım).
      if (SearchIndex.isStale ||
          (_indexTooOld && mounted && context.read<AppState>().autoRescan)) {
        unawaited(_scan());
      }
      return;
    }
    await _scan();
  }

  /// **Sıcak klasör yakalaması** — pano her açıldığında/öne geldiğinde koşar.
  ///
  /// Tam tarama dakikalar sürdüğü için 12 saatte bir koşuyor; arada eklenen
  /// dosyalar o zamana kadar panoda görünmüyordu (kullanıcı 2026-08-17:
  /// *"kaçmamalı hiçbir şey"*). Bu tarama yalnız kameranın/indirmelerin/
  /// mesajlaşmanın yazdığı birkaç ağacı gezer — saniyenin altında biter, her
  /// açılışta koşabilir. Bulunanlar indekse katılır (bkz.
  /// [StorageIndex.mergeFresh]) ve arama dizini bayat işaretlenir.
  bool _catchingUp = false;

  /// En son ne zaman yakalama yapıldı — **kısıtlama** için.
  ///
  /// `AppLifecycleState.resumed` sanılandan çok daha sık geliyor: izin
  /// penceresi, paylaşım sayfası, ekranın kapanıp açılması, bildirim
  /// panelinin çekilmesi… Her birinde sıcak klasörleri baştan yürümek
  /// (DCIM + WhatsApp = on binlerce `stat`) kullanıcının *"performans sorunu
  /// yaşamadan yapmalısın"* şartını çiğnerdi. Aşağı çekerek yenileme ve tam
  /// tarama bu kısıtlamadan **etkilenmez** — onlar kullanıcının açık isteği.
  static const _catchUpEvery = Duration(seconds: 20);
  int _lastCatchUpMs = 0;

  Future<void> _catchUp() async {
    if (_catchingUp || _scanning || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCatchUpMs < _catchUpEvery.inMilliseconds) return;
    _lastCatchUpMs = now;
    _catchingUp = true;
    try {
      await FmEnv.ensureInit();
      // Bütün birimler: kamerası SD karta çeken telefonda yeni fotoğraflar
      // oraya düşüyor ve eskiden yakalama taramasına hiç girmiyordu.
      final roots = StorageStats.hotFoldersForAll(FmEnv.volumeRoots);
      if (roots.isEmpty) return;
      final fresh = await FsScan.freshFiles(roots);
      if (!mounted || fresh.isEmpty) return;
      final merged = _index.mergeFresh(fresh);
      if (identical(merged, _index)) return;
      _cachedIndex = merged;
      setState(() => _index = merged);
    } finally {
      _catchingUp = false;
    }
  }

  /// Taramada eksiksiz sayılması istenen klasörler. Şimdilik tek üye:
  /// Önemli Dosyalar kutusu gerçek sayıyı buradan okur (bkz. `_importantStat`).
  List<String> get _statFolders => [
        ImportantScreen.pathIn(FmEnv.primaryRoot),
      ];

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
    final index = await FsScan.indexFromRows(
      SearchIndex.indexPath,
      statFolders: _statFolders,
    );
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
    setState(() => _scanning = true);
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
    _cachedIndex = index;
    _cachedAtMs = DateTime.now().millisecondsSinceEpoch;
    if (!mounted) return;
    final changedDuringScan = FsEvents.version.value != startedAtVersion;
    setState(() {
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
    setState(() => _trashCount = items.length);
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
        // Kapsam: TÜM depolama. Önemli Dosyalar ekranı aynı başlıkla ("Görüntüler")
        // çok daha küçük bir küme açıyor — benzer tarama sonuçları karışmasın.
        scopeId: 'depolama-${category.name}',
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
      _snack(createFailed.replaceAll('{error}', '\$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final volumes = FmEnv.volumes;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('fm.files')),
        // **Arama kalıcı** (2026-08-04 tasarım turu): dosya yöneticisine gelme
        // sebebi çoğu zaman arama; simgenin arkasında bir dokunuş kaybediyordu.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.control),
              // Kök YOK = tüm depolama (SD kart ve USB dahil). Eskiden
              // `FmEnv.primaryRoot` geçiliyordu; kutuda "Tüm dosyalarda ara"
              // yazmasına rağmen SD karttaki dosyalar hiç bulunmuyordu.
              onTap: () => _push(SearchScreen(
                rootLabel: context.t('fm.all_files'),
              )),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(Radii.control),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(Icons.search,
                        size: 20, color: scheme.onSurfaceVariant),
                    const SizedBox(width: Gap.sm),
                    Text(
                      context.t('fm.search_all'),
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Paper.faint(context)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          IconButton(
            tooltip: context.t('common.rescan'),
            icon: const Icon(Icons.refresh),
            onPressed: _scanning ? null : _scan,
          ),
          IconButton(
            // Ayrı bir "dosya yöneticisi ayarları" ekranı KALMADI (2026-08-09):
            // ayarlar tek ekranda, sekiz kategoride toplandı.
            tooltip: context.t('common.settings'),
            icon: const Icon(Icons.settings_outlined),
            onPressed: () async {
              await _push(const SettingsScreen());
              if (mounted) await _loadTrash();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _scan,
        child: ListView(
          // Alt boşluk FAB yığınını (küçük düğme sırası + "Belge Tara") aşar:
          // 2026-08-06'da Gap.xl (32) yetmiyordu ve son satırdaki "Google
          // Drive" kartının yazısı düğmelerin altında kalıyordu.
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 136),
          children: [
            // Çökme uyarısı EN ÜSTTE ve yalnız çökme olduysa (kendini gizler):
            // hata kaydını Ayarlar'da bırakmak kimsenin bakmayacağı bir yere
            // koymak olurdu — geri bildirim döngüsü ancak kullanıcı olayı
            // gördüğünde kuruluyor (bkz. widgets/crash_notice.dart).
            const CrashNoticeBanner(),
            // **Paylaşım açıkken panonun en üstünde bir şerit** (kullanıcı
            // isteği 2026-08-29: *"çalışırken uygulama içinde … görülmeli"*).
            // Bildirim paneli telefonun dışı; bu şerit uygulamanın içi. Telefonu
            // ağa açık bırakmak bir daha "unutulacak" bir şey olmasın.
            _networkShareBanner(),
            if (!_hasAccess) _permissionCard(),
            if (_scanning) ...[
              const LinearProgressIndicator(minHeight: 3),
              const SizedBox(height: Gap.sm),
              Text(context.t('fm.scanning_storage'),
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: Gap.sm),
            ],
            for (final v in volumes) ...[
              // Birincil bellek kartının YANINDA "Bellek Analizi" (kullanıcı
              // isteği 2026-08-05: "orası 2 buton olsun"). Takılabilir
              // birimlerde analiz kutusu tekrarlanmaz — tek bir analiz ekranı
              // var, iki kez göstermek yer kaybı olurdu.
              if (v.isPrimary)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _VolumeCard(
                          volume: v,
                          index: _index,
                          onTap: () => _push(BrowserScreen(
                              path: v.path,
                              title: v.displayLabel(context.t))),
                        ),
                      ),
                      const SizedBox(width: Gap.sm),
                      SizedBox(width: 126, child: _analysisCard(v)),
                    ],
                  ),
                )
              else
                _VolumeCard(
                  volume: v,
                  index: _index,
                  // `label` UUID adlı bir birimde BOŞTUR (ad çeviriden gelir)
                  // — tarayıcı başlığı boş açılıyordu.
                  onTap: () => _push(BrowserScreen(
                      path: v.path, title: v.displayLabel(context.t))),
                ),
              const SizedBox(height: Gap.sm),
            ],
            // **Klasör izniyle eklenen bellekler de KART olarak** (kullanıcı
            // 2026-09-02, ekran görüntüsüyle: başka bir dosya yöneticisi
            // takılı USB'yi "bu şekilde ekliyor" ve ana ekranda gösteriyor).
            // Yol yoluyla görünen bir birim varsa aynı bellek iki kez
            // çizilmez (bkz. `SafRoot.volumeId`).
            for (final r in _safCards()) ...[
              _SafCard(root: r, onTap: () => unawaited(_openSafRoot(r))),
              const SizedBox(height: Gap.sm),
            ],
            // **Android'in bağlamadığı bellek de KART olarak** (kullanıcı
            // 2026-09-02: bellek ana ekranda görünmeli). Yol yoluyla ya da
            // klasör izniyle zaten görünen bir bellek varsa kart çizilmez —
            // aynı aygıtı iki kez göstermek kafa karıştırır.
            for (final d in _rawUsbCards) ...[
              _RawUsbCard(
                device: d,
                onTap: () => unawaited(_openRawUsb(d.name)),
              ),
              const SizedBox(height: Gap.sm),
            ],
            // (AI Asistan kartı 2026-08-17'de KALKTI: kullanıcı *"ai asistan
            // yazısı sağ alttaki ai düğmesi alanına entegre et, ana ekran
            // temizlensin"* dedi. Analiz sayısı ve bekleyen öneri sayısı artık
            // alt gezinme çubuğundaki AI sekmesinin rozetinde — bkz.
            // `home_screen.dart`. Kart, panonun en üstünde tam genişlik
            // kaplıyordu ve dosya aramaya gelen kullanıcının önüne giriyordu.)
            const SizedBox(height: Gap.sm),
            _categoryGrid(),
            // Kuyruk değişince (iş başladı/bitti) yalnız araç ızgarası yeniden
            // çizilir: "İşlemler" kutusunun alt yazısı canlı sayaç
            // ("1 sürüyor" / "3 biten") — kullanıcı ana ekrandan bakınca
            // işleminin durduğunu ya da bittiğini görebilsin.
            AnimatedBuilder(
              // "Ağdan erişim" kutusunun alt yazısı da canlı: paylaşım
              // açılınca/kapanınca ızgara yeniden çizilir.
              animation: Listenable.merge(
                  [JobQueue.instance, FtpService.instance]),
              builder: (context, _) {
                final tools = _rankedTools();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionHeader(context.t('fm.tools'),
                        count: '${tools.length}',
                        padding: const EdgeInsets.only(
                            top: Gap.lg, bottom: Gap.sm)),
                    _toolFrame(FmToolGrid(tools: tools)),
                  ],
                );
              },
            ),
            if (appState.bookmarks.isNotEmpty) ...[
              SectionHeader('Favoriler',
                  count: '${appState.bookmarks.length}',
                  padding:
                      const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
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
            SectionHeader(context.t('fm.quick_folders'),
                padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
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
      // **Belge Tara ana ekranda sabit yüzen düğme** (kullanıcı isteği
      // 2026-07-29: "dosya tara ana ekranda olmalı yüzen fix buton olarak").
      // Daha önce yalnız "Son belgeler" sekmesindeydi — uygulamanın vitrin
      // özelliği, açılış ekranında görünmüyordu. Kaydırırken kaybolmaz
      // (FAB gövdenin üstünde durur, listenin içinde değil).
      //
      // Sıra bilinçli: taramanın etiketli/geniş düğmesi ALTTA (başparmağa en
      // yakın), yeni klasör küçük düğme olarak üstte — ikisi de kalsın diye.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Çöp kutusu ile klasör ekleme YAN YANA: ikisi de küçük, ikisi de
          // "bir şey yap" düğmesi; alt alta dizilseler taramanın geniş
          // düğmesini ekranın yarısına kadar iterlerdi.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _trashFab(),
              const SizedBox(width: Gap.sm),
              FloatingActionButton.small(
                heroTag: 'fm_new_folder',
                onPressed: _newFolderFlow,
                tooltip: context.t('fm.new_folder'),
                child: const Icon(Icons.create_new_folder_outlined),
              ),
            ],
          ),
          const SizedBox(height: Gap.sm),
          FloatingActionButton.extended(
            heroTag: 'fm_scan_doc',
            onPressed: () => ScanFlow.run(context),
            icon: const Icon(Icons.document_scanner_outlined),
            label: Text(context.t('fm.scan_document')),
          ),
        ],
      ),
    );
  }

  /// Araç ızgarasının hafif çerçevesi: kartsız simgeler kağıt zeminde
  /// yüzüyordu, dokunma alanının nerede bittiği belirsizdi. Çerçeve kategori
  /// kutularından DAHA HAFİF (bir ton açık zemin + ince kenarlık) — ağırlık
  /// hiyerarşisi korunuyor, araçlar içerik kutularının önüne geçmiyor.
  Widget _toolFrame(Widget child) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(Gap.sm),
      decoration: BoxDecoration(
        // Kağıt tokenlarından (elle hex yazılmıyor — 2026-08-17'de kağıt
        // beyazlatılınca bu iki hex geride kalıp kutuyu sararmış gösterdi).
        color: isDark ? scheme.surfaceContainerLow : Paper.card,
        borderRadius: BorderRadius.circular(Radii.card),
        border: Border.all(
          color: isDark ? scheme.outlineVariant : Paper.rule,
        ),
      ),
      child: child,
    );
  }

  Widget _permissionCard() => Card(
        child: Padding(
          // Dikeyde 16 → 12: kart zaten çember + iki satır + çubuk taşıyor,
          // fazlası yan kutuyla arasındaki boşluğu büyütüyordu (2026-08-29).
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.md, vertical: Gap.sm + 4),
          child: Column(
            // Yan kutu daha uzunsa artan yer ALTA yığılmasın, iki yana
            // eşit dağılsın — kullanıcının işaretlediği boşluğun kaynağı buydu.
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.folder_special_outlined),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(context.t('fm.permission_title'),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                context.t('fm.permission_body'),
              ),
              const SizedBox(height: Gap.sm),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _requestAccess,
                  icon: const Icon(Icons.lock_open),
                  label: Text(context.t('fm.permission_grant')),
                ),
              ),
            ],
          ),
        ),
      );

  /// **İçerik kutuları** — insanların dosya aramaya geldiği yer.
  ///
  /// Araçlar (Yer aç, Otomatik düzenle, İndir…) buraya KARIŞMAZ; onlar
  /// aşağıda daha hafif bir satırda ([_toolGrid]). Kullanıcı geri bildirimi
  /// 2026-07-29: "ana ekranda çok fazla buton olmuş, karışıklık var" — sorun
  /// sayı değil, 16 kutunun hepsinin aynı ağırlıkta bağırmasıydı.
  Widget _categoryGrid() {
    final importantPath = ImportantScreen.pathIn(FmEnv.primaryRoot);
    final importantStat = _importantStat(importantPath);
    final download = p.join(FmEnv.primaryRoot, 'Download');
    final tiles = <FmTileData>[
      // **İndirilenler — EN BAŞTA, büyük kutu** (kullanıcı isteği 2026-08-17:
      // *"indirilenler çok kolay erişilebilmeli"*, *"indirilenleri kolay
      // erişilebilir grid kart yap ve en başa koy"*). Araç satırındaki küçük
      // simgeler arasındaydı; oysa telefona inen her şey (APK, fatura, ekran
      // görüntüsü, belge) önce oraya düşüyor — panoya gelme sebeplerinin
      // birincisi. Boyut ölçülmüşse alt satırda yazar.
      FmTileData(
        icon: Icons.download_rounded,
        color: const Color(0xFF1565C0),
        label: context.t('fm.downloads'),
        subtitle: _folderSizes[download] != null
            ? FsPaths.humanSize(_folderSizes[download]!)
            : '',
        onTap: () {
          final path = downloadsPathIn(FmEnv.primaryRoot);
          if (path != null) {
            _push(DownloadsScreen(path: path));
          } else {
            _snack(context.t('fm.downloads_missing'));
          }
        },
      ),
      // Kullanıcının kendi seçtiği dosyalar — en sık dönülecek ikinci yer.
      FmTileData(
        icon: Icons.star_outline,
        color: FmColors.folder,
        label: ImportantScreen.folderName,
        subtitle: importantStat == null
            ? context.t('fm.create')
            : (importantStat.count == 0
                ? context.t('common.open')
                : '${FsPaths.humanSize(importantStat.bytes)} '
                    '(${importantStat.count})'),
        onTap: () async {
          await _push(const ImportantScreen());
          if (mounted) setState(() {});
        },
      ),
      _categoryTile(FmCategory.image, grid: true),
      _categoryTile(FmCategory.video, grid: true),
      _categoryTile(FmCategory.document),
      _categoryTile(FmCategory.audio),
      _categoryTile(FmCategory.archive),
      // Kurulum dosyaları ayrı kutuda (kullanıcı isteği 2026-07-25).
      FmTileData(
        icon: Icons.archive_outlined,
        color: const Color(0xFF00897B),
        label: context.t('fm.apk_files'),
        subtitle: _index.stat(FmCategory.apk).count == 0
            ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
            : '${FsPaths.humanSize(_index.stat(FmCategory.apk).bytes)} '
                '(${_index.stat(FmCategory.apk).count})',
        onTap: () => _push(CategoryScreen(
          title: context.t('fm.apk_files'),
          files: _index.files(FmCategory.apk),
        )),
      ),
      // **Yeni dosyalar** — bkz. `NewFilesScreen`. Simge `fiber_new` idi:
      // Material o glifi "NEW" YAZISI olarak çiziyor, dört sütunlu ızgarada
      // tek harf yığını gibi duruyordu (kullanıcı 2026-08-17: *"yeni dosyalar
      // klasörünün simgesini değiştir"*). Gelen kutusu oku, "az önce buraya
      // düştü" fikrini glifle anlatıyor.
      FmTileData(
        icon: Icons.move_to_inbox_rounded,
        color: const Color(0xFF8D6E63),
        label: context.t('fm.new_files'),
        subtitle: context.t('fm.new_files_note'),
        onTap: () => _push(const NewFilesScreen()),
      ),
      // **Son açılanlar — büyük kutu.** Araçlar satırındaki 12 küçük simgenin
      // arasındaydı ve kaydırmadan görünmüyordu; oysa "dün baktığım dosya"
      // insanların panoya dönme sebeplerinden biri (istek 2026-08-09:
      // *"... kolay erişilebilir olmalı"*). Çöp kutusu ve Drive ile aynı
      // terfi hikâyesi.
      FmTileData(
        icon: Icons.history,
        color: const Color(0xFF3949AB),
        label: context.t('fm.recent_opened'),
        subtitle: context.t('fm.recent_opened_note'),
        onTap: () => _push(const OpenHistoryScreen()),
      ),
      // **Google Drive — büyük kutulardan biri** (kullanıcı isteği 2026-08-05:
      // *"Drive daha kolay erişilebilmeli, şu an zor bulunuyor"*). Çöp
      // kutusuyla aynı terfi hikâyesi: araçlar ızgarasındaki 12 küçük simge
      // arasında kayboluyordu; buluttaki dosyaların tek kapısı büyük kart
      // olmayı hak ediyor. Ağ depolama (NAS) araçlarda kalıyor — o, kuran
      // birinin bildiği bir yer; Drive ise herkesin aradığı.
      FmTileData(
        icon: Icons.cloud_outlined,
        color: const Color(0xFF0F9D58),
        label: 'Google Drive',
        subtitle: context.t('fm.drive_subtitle'),
        onTap: () => _push(const DriveScreen()),
      ),
      // **Uygulamalar — büyük kutuların SONUNCUSU** (kullanıcı isteği
      // 2026-08-27: araç ızgarasındaki simge işaretlenip kart ızgarasının boş
      // kalan hücresi gösterildi). Yeri rastgele değil: ızgara dört sütunlu ve
      // bu kutudan önce 11 kutu vardı — son satır üç doluydu, dördüncü hücre
      // boş bakıyordu. Kutu sayısı 12'ye çıkınca ızgara tam kapanıyor.
      // Alt yazı ölçülmüş toplamı gösterir (Bellek Analizi'ndeki sayının
      // aynısı); ölçüm "Kullanım erişimi" iznine bağlı olduğu için izin yokken
      // sayı UYDURULMAZ, alt satır boş bırakılır.
      FmTileData(
        icon: Icons.android,
        color: FmColors.apk,
        label: context.t('fm.apps'),
        subtitle: _appsBytes == null
            ? ''
            : FsPaths.humanSize(_appsBytes!),
        onTap: () => _push(const InstalledAppsScreen()),
      ),
    ];
    return FmCategoryGrid(tiles: tiles);
  }

  /// Ağ paylaşımı açıkken panonun en üstünde duran şerit. Kapalıyken hiç
  /// çizilmez (boş bir "kapalı" satırı yer israfı olurdu).
  Widget _networkShareBanner() {
    return AnimatedBuilder(
      animation: FtpService.instance,
      builder: (context, _) {
        final service = FtpService.instance;
        if (!service.running) return const SizedBox.shrink();
        final scheme = Theme.of(context).colorScheme;
        final address =
            service.addresses.isEmpty ? '' : service.addresses.first;
        return Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Material(
            color: scheme.primaryContainer,
            borderRadius: BorderRadius.circular(context.fmCardRadius),
            child: InkWell(
              borderRadius: BorderRadius.circular(context.fmCardRadius),
              onTap: () => _push(const FtpServerScreen()),
              child: Padding(
                padding: const EdgeInsets.all(Gap.sm),
                child: Row(
                  children: [
                    Icon(Icons.wifi_tethering,
                        color: scheme.onPrimaryContainer),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            context.t('ftpd.open_action'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(color: scheme.onPrimaryContainer),
                          ),
                          if (address.isNotEmpty)
                            Text(
                              address,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(color: scheme.onPrimaryContainer),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => service.stop(),
                      child: Text(context.t('common.close')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// **Çöp kutusu — yüzen düğme** (kullanıcı isteği 2026-08-06: *"çöp kutusu
  /// da grid kart yerine klasör eklenin yanında yüzen buton olsun"*).
  ///
  /// Yolculuğu: araç ızgarası (12 simge arasında kayboluyordu) → büyük kart
  /// (ızgarada yer kaplıyordu) → klasör ekleme düğmesinin yanındaki küçük
  /// yüzen düğme. Kaydırınca kaybolmaz. Doluyken turuncu ve dolu simgeli —
  /// kutuyu açmadan durum görünsün diye.
  Widget _trashFab() {
    final full = _trashCount > 0;
    return FloatingActionButton.small(
      heroTag: 'fm_trash',
      onPressed: () async {
        await Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const TrashScreen()));
        _loadTrash();
      },
      tooltip: full
          ? context.t('fm.trash_count', {'n': _trashCount})
          : context.t('fm.trash_empty'),
      backgroundColor: full ? const Color(0xFFE65100) : null,
      foregroundColor: full ? Colors.white : null,
      child: Icon(full ? Icons.delete : Icons.delete_outline),
    );
  }

  /// **Araçlar** — küçük, kartsız simgeler. Alt yazı yalnız gerçek bilgi
  /// taşıdığında yazılır ("3 sürüyor"), dolgu metin konmaz.
  ///
  /// Buradaki sıra **yazılış sırası**; ekrandaki sıra kullanımdan gelir
  /// (bkz. [_rankedTools]). Yeni bir araç listenin neresine yazılırsa, hiç
  /// dokunulmadığı sürece orada durur.
  List<FmTileData> _tools() {
    final downloading = DownloadService.instance.activeTasks.length;
    final queue = JobQueue.instance;
    final runningJobs = queue.activeJobs.length;
    final finishedJobs = queue.finishedJobs.length;
    final tools = <FmTileData>[
      // **İşlemler — ilk sırada, bilinçli.** Kullanıcı isteği 2026-07-30:
      // "video boyutu düşürme gibi işlemlerin sonucunu, işleyişini takip
      // edebileceğim ana ekranda bir yer, kart, buton gibi bir şey lazım".
      // Alt yazı gerçek sayaç: sürüyor mu, bitmiş iş var mı.
      FmTileData(
        icon: runningJobs > 0
            ? Icons.autorenew
            : Icons.playlist_add_check_circle_outlined,
        color: const Color(0xFF2E7D32),
        id: 'jobs',
        label: context.t('fm.jobs'),
        subtitle: runningJobs > 0
            ? context.t('fm.jobs_running', {'n': runningJobs})
            : (finishedJobs > 0
                ? context.t('fm.jobs_finished', {'n': finishedJobs})
                : ''),
        onTap: () async {
          await openJobsScreen(context);
          if (mounted) setState(() {});
        },
      ),
      // **Yaptıklarım** — İşlemler'in hemen yanında, bilinçli (istek
      // 2026-08-07: *"benim yaptıklarım kartı lazım … her şey kategorize
      // olmalı"*). İşlemler "şu an ne oluyor"u, bu kutu "ne ürettim"i
      // gösterir: küçültülen video, düzenlenen PDF, taranan belge.
      FmTileData(
        icon: Icons.history_edu_outlined,
        color: const Color(0xFF6A4C93),
        id: 'activity',
        label: context.t('act.title'),
        // Alt yazı KALKTI (2026-08-29): "Ürettiğiniz dosyalar" bir sayaç
        // değil, dört sütunda "Üretiğiniz dosyal…" diye kırpılan bir dolgu
        // metindi. Araç ızgarasının kuralı: alt satır yalnız CANLI bilgi.
        subtitle: '',
        onTap: () => _push(const ActivityScreen()),
      ),
      // Ağ depolama (NAS): Drive'ın yanında — ikisi de "telefonun dışındaki
      // dosyalar". FTP/FTPS/SFTP/SMB/WebDAV bağlantıları burada.
      FmTileData(
        icon: Icons.dns_outlined,
        color: const Color(0xFF5E35B1),
        id: 'network_storage',
        label: context.t('fm.network_storage'),
        subtitle: '',
        onTap: () => _push(const RemoteConnectionsScreen()),
      ),
      // **Ağdan erişim — panoda kendi kutusu** (kullanıcı isteği 2026-08-29:
      // *"kolay erişilebilir, pratik olmalı"*). Eskiden Ağ depolama ekranının
      // SAĞ ÜST KÖŞESİNDEKİ bir simgenin arkasındaydı: panodan üç dokunuş ve
      // hiçbir yerde adı geçmiyordu. Ters yön de önemli: paylaşım açıkken alt
      // yazı bunu söylüyor, kullanıcı telefonunun ağa açık olduğunu panoya
      // bakınca görüyor.
      FmTileData(
        icon: FtpService.instance.running
            ? Icons.wifi_tethering
            : Icons.phonelink_outlined,
        color: FtpService.instance.running
            ? const Color(0xFF00796B)
            : const Color(0xFF00897B),
        id: 'ftp_server',
        label: context.t('ftpd.title'),
        subtitle: FtpService.instance.running
            ? context.t('ftpd.running')
            : '',
        onTap: () async {
          await _push(const FtpServerScreen());
          if (mounted) setState(() {});
        },
      ),
      // (Google Drive 2026-08-05'te buradan yukarıdaki BÜYÜK kart ızgarasına
      // terfi etti — çöp kutusuyla aynı gerekçe: küçük simge kalabalığında
      // bulunamıyordu.)
      FmTileData(
        icon: Icons.download_for_offline_outlined,
        color: const Color(0xFF1565C0),
        id: 'download',
        label: context.t('fm.download'),
        subtitle: downloading > 0
            ? context.t('fm.jobs_running', {'n': downloading})
            : '',
        onTap: () async {
          await _push(const DownloadManagerScreen());
          if (mounted) setState(() {});
        },
      ),
      // **Yeni belge** — boş Word/Excel/metin oluşturur. 2026-08-17'ye kadar
      // "Son belgeler" sekmesinin içindeydi; o sekme kullanıcı isteğiyle alt
      // gezinme çubuğundan kalkınca akış buraya alındı. Kaldırılan şey
      // belgelerin LİSTESİYDİ, oluşturma değil.
      FmTileData(
        icon: Icons.note_add_outlined,
        color: OfficeColors.word,
        id: 'new_document',
        label: context.t('home.new_document_title'),
        subtitle: '',
        onTap: () => showNewDocumentSheet(context),
      ),
      // (İndirilenler klasörü 2026-08-17'de buradan yukarıdaki BÜYÜK kutu
      // ızgarasına, ilk sıraya taşındı. Buradaki "İndir" kutusu farklı bir
      // şey: indirme YÖNETİCİSİ — süren indirmeler ve kuyruk.)
      FmTileData(
        icon: Icons.cleaning_services_outlined,
        color: const Color(0xFF00838F),
        id: 'free_space',
        label: context.t('fm.free_space'),
        subtitle: '',
        onTap: () => _push(CleanupScreen(index: _index)),
      ),
      // Sohbet yığını ayrı bir kutu: telefonu dolduran şey çoğu kullanıcıda
      // WhatsApp klasörü oluyor ve orada "gereksiz" ölçütü genel yer açmadan
      // farklı (çıkartma, iletilmiş mem, gönderilenin kopyası…).
      FmTileData(
        icon: Icons.forum_outlined,
        color: const Color(0xFF2E7D32),
        id: 'chat_cleanup',
        label: context.t('cj.title'),
        subtitle: '',
        onTap: () => openChatCleanupScreen(context),
      ),
      // Benzer görüntüler: "yer aç"ın yanında duruyor çünkü aynı işi yapıyor
      // (yer kazandırıyor) ama farklı bir ölçütle — birebir değil, GÖRSEL
      // olarak aynı olanlar (WhatsApp'ın yeniden sıkıştırdığı kopyalar).
      FmTileData(
        icon: Icons.auto_awesome_motion_outlined,
        color: const Color(0xFF00897B),
        id: 'similar_images',
        label: context.t('fm.similar_images'),
        subtitle: '',
        onTap: () {
          final locked = context.read<AppState>().fmLockedFolders;
          _push(SimilarScreen(
            // Pano kutucuğu tüm medyayı tarar; kategori ekranlarından açılan
            // tarama kendi kapsamında durur (bkz. SimilarFinder.jobIdFor).
            scopeId: 'tum-medya',
            files: [
              ..._index.files(FmCategory.image),
              ..._index.files(FmCategory.video),
            ],
            loadAll: () async => [
              ...await MediaLibrary.categoryFiles(FmCategory.image,
                  lockedFolders: locked),
              ...await MediaLibrary.categoryFiles(FmCategory.video,
                  lockedFolders: locked),
            ],
          ));
        },
      ),
      FmTileData(
        icon: Icons.auto_awesome_motion,
        color: const Color(0xFF5E35B1),
        id: 'organize',
        label: context.t('fm.organize'),
        subtitle: '',
        onTap: () => _push(OrganizeScreen(
          path: downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot,
        )),
      ),
      // (Uygulamalar 2026-08-27'de buradan yukarıdaki BÜYÜK kutu ızgarasına
      // taşındı — kullanıcı isteği, ekran görüntüsünde araç ızgarasındaki
      // simge işaretlenip kart ızgarasının boş kalan dördüncü hücresi
      // gösterildi. Gerekçe Drive/Çöp kutusu/Son açılanlarla aynı: yüklü
      // uygulamalar hem yer analizinin hem de "neyi kaldırsam" sorusunun
      // kapısı, 12 küçük simgenin arasında kayboluyordu.)
      FmTileData(
        icon: Icons.history_toggle_off,
        color: const Color(0xFF6D4C41),
        id: 'recent_ops',
        label: context.t('fm.recent_ops'),
        subtitle: '',
        onTap: () => _push(const OpHistoryScreen()),
      ),
      // NOT: "Son açılanlar" buradan YUKARI, büyük kutulara taşındı (bkz.
      // `_categoryGrid`). "Son işlemler" taşı/kopyala/sil gibi İŞLEMLERİ
      // tutar; o, hangi DOSYALARIN ne zaman AÇILDIĞINI — ikisi ayrı veri,
      // ayrı ekran, ikisi birden araç satırında olunca karışıyordu.
      // Çöp kutusu buradan YUKARI taşındı (bkz. `_trashTile`): kullanıcı
      // 2026-07-31'de "çöp kutusunu bulmak çok zor" dedi. Araçlar ızgarası
      // küçük ve kartsız; 12 küçük simgenin arasında geri alma kapısının
      // kaybolması, silinen dosyayı kurtaramamak demekti.
    ];
    return tools;
  }

  /// **Araçlar kullanıma göre sıralı** (kullanıcı isteği 2026-08-29: *"araçlar
  /// alanı kullanıma göre sıralanmalı"*).
  ///
  /// Sıra [rankByUsage] ile hesaplanır: çok açılan önce, eşitlikte
  /// [_tools]'taki yazılış sırası korunur — hiç dokunulmamış araçlar birbirine
  /// göre yer değiştirmez, kullanıcı ızgarayı her açtığında aynı yerde bulur.
  /// Hiç kayıt yokken liste bire bir yazıldığı gibi kalır.
  ///
  /// Sayaç, aracın KENDİ `onTap`ı sarılarak artıyor; diske yazmayı beklemeden
  /// ekran açılır (`unawaited`) — araç ekranının açılması bir dosya yazmasına
  /// takılmamalı.
  /// **Harici Bellek kutusu — HER ZAMAN görünür** (kullanıcı isteği
  /// 2026-09-02: *"araçlardaki kalıcı olsun hep görülsün"*).
  ///
  /// İlk yazımda kutu yalnız takılı bellek varken çiziliyordu; gerekçem "boş
  /// bir kutu yer kaplar" idi. Kullanıcı aksini istedi ve haklı bir sebebi
  /// var: kutu ancak HEP orada durursa kullanıcı nereye bakacağını öğrenir —
  /// yalnız takılıyken beliren bir kutu, aranacak yeri de takılma anına
  /// bağlıyor. Takılı bellek yokken kutu "Takılı değil" diyor ve dokununca
  /// ne yapılacağını anlatıyor.
  ///
  /// Birden çok birim (USB + SD kart aynı anda) desteklenir: alt yazı hepsini
  /// sayar, dokununca listeleyip seçtirir.
  FmTileData _externalTile() {
    final externals = [
      for (final v in FmEnv.volumes)
        if (v.isRemovable) v,
    ];
    final usb = externals.where((v) => v.kind == StorageKind.usb).length;
    final cards = externals.length - usb;
    // Yol yoluyla görünmeyen ama klasör izni verilmiş bellekler de "takılı"
    // sayılır — izinli bir USB dururken "Takılı değil" yazmak yanlış olurdu.
    final granted = _safRoots.length;
    final anything = externals.isNotEmpty || granted > 0;
    return FmTileData(
      icon: !anything
          ? Icons.sd_card_outlined
          : (usb > 0 || externals.isEmpty ? Icons.usb : Icons.sd_card),
      color: !anything
          ? const Color(0xFF9E9E9E)
          : const Color(0xFFEF6C00),
      id: 'external_storage',
      label: context.t('fm.external_storage'),
      // Alt yazı CANLI bilgi (ızgaranın kuralı): tek birimde adı ve boş alanı,
      // birden çoksa türe göre sayısı, hiç yoksa "Takılı değil".
      subtitle: switch (externals.length) {
        0 => granted == 0
            ? context.t('fm.external_none_short')
            : (granted == 1
                ? _safRoots.single.name
                : context.t('fm.external_count', {'n': granted})),
        1 => externals.single.hasStats
            ? '${externals.single.displayLabel(context.t)} · '
                '${FsPaths.humanSize(externals.single.freeBytes)} boş'
            : externals.single.displayLabel(context.t),
        _ => [
            if (usb > 0) context.t('fm.external_usb_count', {'n': usb}),
            if (cards > 0) context.t('fm.external_card_count', {'n': cards}),
          ].join(' · '),
      },
      onTap: () => _openExternal(externals),
    );
  }

  /// Panoda kart olarak çizilecek SAF ağaçları: yol yoluyla ZATEN görünen
  /// birimler elenir (aynı bellek iki kart olmasın).
  List<SafRoot> _safCards() {
    final byPath = {
      for (final v in FmEnv.volumes) p.basename(v.path).toLowerCase(),
    };
    return [
      for (final r in _safRoots)
        if (!byPath.contains(r.volumeId.toLowerCase())) r,
    ];
  }

  Future<void> _loadSafRoots() async {
    final roots = await AppStorageService.safRoots();
    if (!mounted) return;
    setState(() => _safRoots = roots);
    await _loadRawUsb();
  }

  /// Sürülebilir USB aygıtlarını tazeler.
  ///
  /// Yol yoluyla görünen takılabilir bir birim ya da klasör izni VARSA kart
  /// çizilmiyor: Android belleği zaten bağlamış demektir ve ham sürücü hem
  /// gereksiz hem de o durumda çalışmaz (aygıtı çekirdek tutuyor).
  Future<void> _loadRawUsb() async {
    final devices = await UsbHost.devices();
    if (!mounted) return;
    final covered = FmEnv.volumes.any((v) => v.isRemovable) ||
        _safRoots.isNotEmpty;
    setState(() {
      _rawUsbCards = covered
          ? const []
          : [
              for (final d in devices)
                if (d.isDrivable) d,
            ];
    });
  }

  /// **SAF yolu** — klasör izniyle harici belleğe erişim.
  ///
  /// Android bazı cihazlarda (özellikle USB OTG'de) belleği dosya YOLU olarak
  /// vermiyor; `/storage` altında hiçbir şey görünmüyor. Android 11+ üzerinde
  /// herkese açık çözüm SAF: kullanıcı bir kez klasörü seçer, uygulama kalıcı
  /// izin alır ve o ağacı gezer.
  ///
  /// Daha önce izin verilmiş bir ağaç varsa SORULMADAN açılır — izin bir kez
  /// alınır, her seferinde seçtirmek eziyet olurdu. Yoksa ne olduğu ve ne
  /// yapılacağı anlatılıp teklif edilir.
  ///
  /// Bir şey açıldıysa true döner (çağıran "takılı değil" demesin).
  ///
  /// [volume] verilirse (birimin UUID'si ya da yolu) seçici doğrudan o birimin
  /// köküne konumlanır — kullanıcı hatası 2026-09-02: seçicide takılı USB'yi
  /// bulamıyordu.
  Future<bool> _openViaSaf({String? volume}) async {
    var roots = await AppStorageService.safRoots();
    if (roots.isEmpty) {
      if (!mounted) return false;
      final accept = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('saf.title')),
          content: SingleChildScrollView(child: Text(ctx.t('saf.body'))),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('saf.pick'))),
          ],
        ),
      );
      if (accept != true) return false;
      final picked = await AppStorageService.safPickTree(volume: volume);
      if (picked == null) return false;
      roots = await AppStorageService.safRoots();
      if (roots.isEmpty) return false;
    }

    var root = roots.first;
    if (roots.length > 1) {
      if (!mounted) return false;
      final chosen = await showModalBottomSheet<SafRoot>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final r in roots)
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined),
                  title: Text(r.name),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(ctx.t('saf.pick')),
                onTap: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ),
      );
      if (chosen == null) {
        final picked = await AppStorageService.safPickTree(volume: volume);
        if (picked == null) return false;
        final fresh = await AppStorageService.safRoots();
        if (fresh.isEmpty) return false;
        root = fresh.firstWhere((r) => r.uri == picked,
            orElse: () => fresh.first);
      } else {
        root = chosen;
      }
    }

    if (!mounted) return false;
    unawaited(_loadSafRoots()); // kutunun alt yazısı hemen doğrulansın
    final fs = SafFs(rootUri: root.uri, rootName: root.name);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: fs.connection, fs: fs),
    ));
    return true;
  }

  /// Harici belleği açar: tek birimde doğrudan, birden çoksa seçtirerek.
  /// Hiç takılı değilse ne yapılacağını anlatır (kutu artık hep görünür).
  Future<void> _openExternal(List<StorageVolume> volumes) async {
    if (volumes.isEmpty) {
      // Kullanıcı belleği tam o an takmış olabilir — söylemeden önce BİR KEZ
      // taze bak. "Takılı değil" demek, aslında takılıyken en can sıkıcı yanıt.
      await _volumes.rescan();
      final fresh = [
        for (final v in FmEnv.volumes)
          if (v.isRemovable) v,
      ];
      if (fresh.isNotEmpty) {
        if (!mounted) return;
        setState(() {});
        return _openExternal(fresh);
      }
      if (!mounted) return;
      // **Android'in bağlamadığı ama SÜRÜLEBİLİR bir bellek** varsa akış
      // burada bitmez: aşağıdaki sayfa onu da (ham USB olarak) sunuyor.
      // Doğrudan SAF penceresine atlamak, o belleği hiç göstermeden
      // kullanıcıyı seçiciyle baş başa bırakırdı.
      final raw = (await UsbHost.devices()).where((d) => d.isDrivable);
      if (!mounted) return;
      if (raw.isEmpty) {
        // Yol yoluyla bulunamadı. **SAF'a düş:** kullanıcı daha önce klasör
        // izni verdiyse doğrudan aç, vermediyse teklif et. Android 11+
        // üzerinde takılabilir belleğe erişmenin herkese açık yolu bu.
        // Seçici, Android'in bildiği birimin üstünde açılsın.
        final stuck = await VolumeWatcher.attachedButUnusable();
        if (!mounted) return;
        if (await _openViaSaf(volume: stuck?.key)) return;
        if (!mounted) return;
        // Android bir birim BİLİYOR ama bağlamamışsa bunu söyle — "yok"
        // demek yanlış olur ve kullanıcı uygulamayı bozuk sanır.
        await _reportStuckExternal();
        return;
      }
    }
    // **Klasör izniyle eklenen bellekler de listede** (kullanıcı 2026-09-02:
    // başka bir dosya yöneticisi USB'yi böyle ekleyip gösteriyor). Yol yoluyla
    // görünen bir SD kart dururken izinli USB'yi gizlemek, kullanıcıyı onu
    // yeniden eklemeye zorlardı.
    final saf = _safRoots;
    // **Android'in bağlamadığı bir bellek varsa onu da sun** — sürülebilir
    // (Bulk-Only SCSI) bir aygıt duruyorsa uygulama onu kendi sürebiliyor.
    final drivable =
        (await UsbHost.devices()).where((d) => d.isDrivable).toList();
    if (!mounted) return;
    if (volumes.length == 1 && saf.isEmpty && drivable.isEmpty) {
      final only = volumes.single;
      return _push(
          BrowserScreen(path: only.path, title: only.displayLabel(context.t)));
    }

    // `'pick'` = "Klasör seç"; `StorageVolume` = yol birimi; `SafRoot` =
    // izinli ağaç. Sayfanın kaydırılarak kapatılması `null` verir ve HİÇBİR
    // şey açmaz — dizeyle ayrılmasının sebebi bu.
    final picked = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final v in volumes)
                ListTile(
                  leading: Icon(volumeIcon(v)),
                  title: Text(v.displayLabel(ctx.t)),
                  subtitle: Text(v.hasStats
                      ? '${FsPaths.humanSize(v.freeBytes)} boş · ${v.path}'
                      : v.path),
                  onTap: () => Navigator.pop(ctx, v),
                ),
              for (final r in saf)
                ListTile(
                  leading: const Icon(Icons.folder_special_outlined),
                  title: Text(r.name),
                  subtitle: Text(ctx.t('saf.granted')),
                  onTap: () => Navigator.pop(ctx, r),
                ),
              ListTile(
                leading: const Icon(Icons.add),
                title: Text(ctx.t('saf.pick')),
                onTap: () => Navigator.pop(ctx, 'pick'),
              ),
              // Android bağlamadıysa: belleği doğrudan sür (salt okunur).
              for (final d in drivable)
                ListTile(
                  leading: const Icon(Icons.usb),
                  title: Text(d.displayName),
                  subtitle: Text(ctx.t('usb.open_raw')),
                  onTap: () => Navigator.pop(ctx, 'raw:${d.name}'),
                ),
              // Bellek görünmüyorsa tahmin yürütmek yerine ÖLÇ.
              ListTile(
                leading: const Icon(Icons.troubleshoot),
                title: Text(ctx.t('usb.diag_title')),
                onTap: () => Navigator.pop(ctx, 'diag'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || picked == null) return;
    if (picked is StorageVolume) {
      return _push(BrowserScreen(
          path: picked.path, title: picked.displayLabel(context.t)));
    }
    if (picked is SafRoot) return _openSafRoot(picked);
    if (picked == 'diag') return _openDiagnostics();
    if (picked is String && picked.startsWith('raw:')) {
      return _openRawUsb(picked.substring(4));
    }
    final stuck = await VolumeWatcher.attachedButUnusable();
    if (!mounted) return;
    await _openViaSaf(volume: stuck?.key);
  }

  /// **Ham USB:** Android belleği bağlamadıysa uygulama onu kendi sürer.
  ///
  /// Salt okunur (bkz. `UsbFs`): dosyalar açılır ve kopyalanır, belleğe
  /// yazılmaz. Açılamazsa sebebi söylenir — sessizce boş ekran açmak yerine.
  Future<void> _openRawUsb(String deviceName) async {
    final outcome = await UsbFs.open(deviceName: deviceName);
    if (!mounted) return;
    final fs = outcome.fs;
    if (fs == null) {
      // Sebep + adım günlüğü teşhis ekranında; şerit oraya yönlendiriyor.
      showSnack(
        context,
        outcome.error.isEmpty
            ? context.t('usb.open_raw_failed')
            : outcome.error,
        duration: kSnackAction,
        action: SnackBarAction(
          label: context.t('usb.diag_title'),
          onPressed: () => unawaited(_openDiagnostics()),
        ),
      );
      return;
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: fs.connection, fs: fs),
    ));
    await fs.close();
  }

  /// USB teşhis ekranı — hangi kanalın ne dediğini ham hâliyle gösterir.
  Future<void> _openDiagnostics() =>
      _push(const UsbDiagnosticsScreen());

  /// İzin verilmiş bir SAF ağacını gezgin ekranında açar.
  Future<void> _openSafRoot(SafRoot root) async {
    final fs = SafFs(rootUri: root.uri, rootName: root.name);
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: fs.connection, fs: fs),
    ));
  }

  List<FmTileData> _rankedTools() {
    final tools = _tools();
    final order =
        rankByUsage([for (final t in tools) t.id], ToolUsage.counts);
    final ranked = [
      for (final i in order)
        tools[i].withTap(() {
          unawaited(ToolUsage.record(tools[i].id));
          tools[i].onTap();
        }),
    ];
    // Harici bellek kutusu SIRALAMAYA GİRMEZ, hep başa sabitlenir: kullanım
    // sayacına girseydi sık kullanılan araçlar onu aşağı iterdi ve kullanıcı
    // belleği tam takmışken yine arayacaktı. Kutu zaten yalnız bellek
    // takılıyken var — geçici ve o an ilgili olan şey en görünür yerde durur.
    return [_externalTile(), ...ranked];
  }

  FmTileData _categoryTile(FmCategory category, {bool grid = false}) {
    final stat = _index.stat(category);
    return FmTileData(
      icon: FmColors.iconFor(category, outlined: context.fmOutlinedIcons),
      color: FmColors.forCategory(category),
      label: category.label,
      subtitle: stat.count == 0
          ? (_scanning ? context.t('fm.scanning') : context.t('fm.none'))
          : '${FsPaths.humanSize(stat.bytes)} (${stat.count})',
      onTap: () => _openCategory(category, grid: grid),
    );
  }

  /// **Bellek Analizi** — ana bellek kartının yanındaki ikinci düğme
  /// (kullanıcı isteği 2026-08-05). Önce araç satırındaydı, kaydırmadan
  /// görünmüyordu; sonra büyük kutulara alındı, orada da ana bellekten
  /// uzaktaydı. Yeri artık aradığı bilgiyle yan yana.
  Widget _analysisCard(StorageVolume volume) {
    final scheme = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    // **Büyük simge, ortalanmış, tek kelime** (kullanıcı isteği 2026-08-25:
    // *"bellek analizi simgesini büyük simge yap ve yazıları düzenle"*).
    //
    // Eski hâlde 26 dp'lik soluk bir çizgi glif sola yaslanmış, altında iki
    // satır yazı vardı: kutu bir DÜĞME olduğu hâlde bir bilgi kartı gibi
    // duruyordu ve göz onu ana bellek kartının küçük eki sanıyordu. Artık
    // ağırlık simgede: 42 dp, vurgu renginde, ortada. "Kullanılan %60" alt
    // satırı KALKTI — aynı sayı soldaki kartta zaten hem çemberde hem
    // yazıyla var, burada üçüncü kez tekrarlanıyordu.
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _push(AnalysisScreen(index: _index, volumes: FmEnv.volumes)),
        child: Padding(
          // **YÜKSEKLİK 2026-08-29'da KISALDI** (kullanıcı: *"ana bellek ve
          // bellek analizi kısmında gereksiz alt boşluk var"*). İki kutu
          // `IntrinsicHeight` ile aynı yüksekliğe zorlanıyor; analiz kutusu
          // (42 dp simge + 16 dp dikey iç boşluk) soldaki karttan uzun
          // kaldığı için ana bellek kartının ALTINDA kocaman bir boşluk
          // oluşuyordu. Simge 34 dp'ye, dikey boşluk 8'e indi — kutu hâlâ
          // rahat okunuyor, boşluk kapandı.
          padding: const EdgeInsets.symmetric(
              horizontal: Gap.sm, vertical: Gap.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.donut_large,
                  size: 34 * context.fmIconScale, color: scheme.primary),
              const SizedBox(height: Gap.xs),
              Text(
                context.t('fm.storage_analysis'),
                textAlign: TextAlign.center,
                maxLines: 2,
                style: theme.textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickFolders() {
    final folders = [
      for (final f in StorageStats.standardFolders(FmEnv.primaryRoot))
        (label: f.label, path: f.path, volume: ''),
      // **Takılabilir birimlerin standart klasörleri de burada** (kullanıcı
      // 2026-09-02: *"SD kartı kullananlar ne yapacak"*). Kamerası SD karta
      // çeken bir telefonda DCIM ana bellekte DEĞİL kartta; hızlı klasörler
      // yalnız ana belleğe bakınca kullanıcının en çok girdiği klasör listede
      // hiç yoktu. Çip birimin adıyla etiketleniyor — aynı adlı iki "Kamera"
      // birbirine karışmasın.
      for (final v in FmEnv.volumes)
        if (v.isRemovable)
          for (final f in StorageStats.standardFolders(v.path))
            (
              label: f.label,
              path: f.path,
              volume: v.displayLabel(context.t),
            ),
    ];
    if (folders.isEmpty) {
      return Text(context.t('fm.no_standard_folders'));
    }
    return Wrap(
      spacing: Gap.sm,
      runSpacing: Gap.sm,
      children: [
        // Boyut yalnız ÖLÇÜLMÜŞ klasörde yazılır (bugün: İndirilenler).
        // Hepsini ölçmek her klasör için ayrı bir ağaç yürüyüşü demek —
        // panonun açılışını saniyelerce geciktirirdi, bilinçli olarak yapılmadı.
        for (final f in folders)
          ActionChip(
            avatar: Icon(
                f.volume.isEmpty ? Icons.folder_outlined : Icons.sd_storage,
                size: 18),
            label: Text(
              [
                f.label,
                if (f.volume.isNotEmpty) f.volume,
                if (_folderSizes[f.path] != null)
                  FsPaths.humanSize(_folderSizes[f.path]!),
              ].join(' · '),
            ),
            onPressed: () => _push(BrowserScreen(
                path: f.path,
                title: f.volume.isEmpty ? f.label : '${f.label} · ${f.volume}')),
          ),
      ],
    );
  }

  /// Önemli Dosyalar kutusunun sayıları — pano indeksinden (ek tarama yok).
  /// Klasör yoksa null → kutuda "Oluştur" yazar.
  ///
  /// **Sayım taramanın kendisinden gelir** ([StorageIndex.folderStat]).
  /// Eskiden "en yeni 300" + "en büyük 200" listeleri süzülüyordu: o listeler
  /// TÜM depolamanın en yenisi/en büyüğü olduğu için klasörden içlerine ancak
  /// bir avuç dosya düşüyor, 99 öğelik 7 GB'lık klasör kutuda "5,1 MB (15)"
  /// görünüyordu (kullanıcı ekran görüntüsü 2026-08-17).
  CategoryStat? _importantStat(String path) {
    if (!Directory(path).existsSync()) return null;
    return _index.folderStat(path) ?? const CategoryStat(0, 0);
  }

  void _snack(String message) {
    showSnack(context, message);
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
  final _controller = TextEditingController();
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
        title: Text(context.t('fm.new_folder')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration:
                  InputDecoration(labelText: context.t('fm.folder_name')),
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: Gap.md),
            DropdownButtonFormField<String>(
              value: _parent,
              isExpanded: true,
              decoration:
                  InputDecoration(labelText: context.t('common.location')),
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
              child: Text(context.t('common.cancel'))),
          FilledButton(
              onPressed: _submit, child: Text(context.t('fm.create'))),
        ],
      );
}

/// **Klasör izniyle eklenen bellek kartı.**
///
/// Yol yoluyla görünen birimlerin kartında doluluk halkası var; burada YOK ve
/// olamaz: SAF bir ağaç verir, aygıtın kapasitesini vermez. Uydurma bir halka
/// çizmektense hiç çizmemek dürüst olan.
class _SafCard extends StatelessWidget {
  final SafRoot root;
  final VoidCallback onTap;

  const _SafCard({required this.root, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.surfaceContainerHighest,
          child: Icon(Icons.usb, color: scheme.onSurfaceVariant),
        ),
        title: Text(root.name,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.t('saf.granted')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

/// **Ham USB kartı** — Android'in bağlamadığı ama sürebildiğimiz bellek.
///
/// Doluluk halkası YOK ve olamaz: kapasiteyi ancak aygıtı açtıktan sonra
/// öğreniyoruz. Uydurma bir halka çizmektense hiç çizmemek dürüst olan.
class _RawUsbCard extends StatelessWidget {
  final UsbDevice device;
  final VoidCallback onTap;

  const _RawUsbCard({required this.device, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: scheme.tertiaryContainer,
          child: Icon(Icons.usb, color: scheme.onTertiaryContainer),
        ),
        title: Text(device.displayName,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(context.t('usb.open_raw')),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _VolumeCard extends StatelessWidget {
  final StorageVolume volume;

  /// Kırılım çubuğunun verisi. Tarama zaten yapıldı — ek maliyet yok.
  final StorageIndex index;
  final VoidCallback onTap;
  const _VolumeCard({
    required this.volume,
    required this.index,
    required this.onTap,
  });

  /// Kategori paylı yığın çubuğu: "98,4/128 GB" tek başına NEYİN yer
  /// kapladığını söylemiyordu. Kalan (ölçülemeyen sistem/uygulama verisi)
  /// "diğer" payına yazılır — çubuk her zaman doluluğu kadar dolar.
  ///
  /// **Yalnız ANA bellekte kırılım var (2026-09-02).** [index] telefonun
  /// taramasıdır; takılan bir USB'nin kartında o sayıları göstermek, USB'de
  /// olmayan fotoğrafları USB'de varmış gibi çizerdi. Harici bellekte tek
  /// pay: "kullanılan" — doluluk doğru, uydurma kırılım yok.
  List<({Color color, String label, int bytes})> _breakdown(
      BuildContext context) {
    if (!volume.isPrimary) {
      return [
        (
          color: FmColors.other,
          label: context.t('fm.used'),
          bytes: volume.usedBytes,
        ),
      ];
    }
    final image = index.stat(FmCategory.image).bytes;
    final video = index.stat(FmCategory.video).bytes;
    final document = index.stat(FmCategory.document).bytes;
    final audio = index.stat(FmCategory.audio).bytes;
    final rest = volume.usedBytes - image - video - document - audio;
    return [
      (
        color: FmColors.image,
        label: FmCategory.image.label,
        bytes: image,
      ),
      (
        color: FmColors.video,
        label: FmCategory.video.label,
        bytes: video,
      ),
      (
        color: OfficeColors.neutral,
        label: FmCategory.document.label,
        bytes: document,
      ),
      (
        color: FmColors.audio,
        label: FmCategory.audio.label,
        bytes: audio,
      ),
      (
        color: FmColors.other,
        label: FmCategory.other.label,
        bytes: rest < 0 ? 0 : rest,
      ),
    ];
  }

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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                      volumeIcon(volume),
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
                    Text(volume.displayLabel(context.t),
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    // **İKİ SATIR** (kullanıcı 2026-08-25: *"yazıları
                    // düzenle"*). Tek satırda "307 GB / 512 GB · 205 GB boş"
                    // yazıyordu ve yanındaki analiz kutusu daralttığı için
                    // cihazda "307 GB / 512 GB · 20…" diye KIRPILIYORDU —
                    // yani kullanıcının asıl aradığı sayı (kaç GB boş) tam da
                    // görünmeyen yarıya düşüyordu.
                    //
                    // Birim ilk sayıdan atıldı: "307 / 512 GB" aynı şeyi
                    // söylüyor, iki kez "GB" yazmak yer harcıyordu.
                    volume.hasStats
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              MonoText(
                                // Kapasite ONDALIK (telefonun üstünde yazan
                                // sayı).
                                '${FsPaths.humanCapacity(volume.usedBytes)}'
                                ' / '
                                '${FsPaths.humanCapacity(volume.capacityBytes)}',
                                size: 12,
                              ),
                              MonoText(
                                context.t('fm.free_bytes', {
                                  'v':
                                      FsPaths.humanCapacity(volume.freeBytes),
                                }),
                                size: 12,
                              ),
                            ],
                          )
                        : MonoText(volume.path, size: 12),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ),
              if (volume.hasStats) ...[
                const SizedBox(height: Gap.sm + 2),
                _breakdownBar(context),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Yığın çubuğu + renk açıklaması. Çubuğun boş kalan kısmı kağıdın kendisi
  /// (dolgu yok) — "boş yer" görsel olarak da boşluk.
  Widget _breakdownBar(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final parts = _breakdown(context).where((p) => p.bytes > 0).toList();
    final free = volume.freeBytes;
    final total = volume.capacityBytes <= 0 ? 1 : volume.capacityBytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 6,
            child: Row(
              children: [
                for (final part in parts)
                  Expanded(
                    flex: part.bytes,
                    child: ColoredBox(color: part.color),
                  ),
                if (free > 0)
                  Expanded(
                    flex: free,
                    child: ColoredBox(color: scheme.outlineVariant),
                  ),
                // Sıfır genişlikli satır olmasın (tüm paylar 0 ise).
                if (parts.isEmpty && free <= 0)
                  Expanded(
                    flex: total,
                    child: ColoredBox(color: scheme.outlineVariant),
                  ),
              ],
            ),
          ),
        ),
        // **Renk açıklaması KALKTI** (kullanıcı isteği 2026-08-25: *"işaretlediğim
        // yerdeki 'Diğer, Videolar, Görüntüler' gibi alt yazıları kaldır"*).
        //
        // Üç turda küçüldü ama sorun boyutu değil VARLIĞIYDI: kartın altındaki
        // yazı sırası, üstteki "Ana bellek / 307 GB / 512 GB" bilgisinden daha
        // çok yer kaplıyor ve göze ondan önce çarpıyordu — oysa hangi rengin
        // ne olduğu panoda sorulan bir soru değil. Çubuğun kendisi oranı zaten
        // gösteriyor; hangi kategorinin ne kadar tuttuğu **Bellek Analizi**
        // ekranının işi ve o düğme hemen yanında duruyor.
      ],
    );
  }

}

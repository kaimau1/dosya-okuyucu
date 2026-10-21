import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/app_state.dart';
import '../../core/device_profile.dart';
import '../../core/startup_queue.dart';
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
import '../../services/fm/smart_folders.dart';
import '../../services/fm/storage_permission.dart';
import '../../services/fm/storage_stats.dart';
import '../../services/fm/storage_trend.dart';
import '../../services/fm/tool_usage.dart';
import '../../services/fm/remote/saf_fs.dart';
import '../../services/fm/remote/usb_fs.dart';
import '../../services/fm/usb/usb_host.dart';
import '../../services/fm/video_playback.dart';
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
import 'history_screen.dart';
import 'remote/ftp_server_screen.dart';
import 'transfer_screen.dart';
import 'browser_screen.dart';
import 'category_screen.dart';
import 'cleanup_screen.dart';
import 'downloads_screen.dart';
import 'drive_screen.dart';
import '../settings_screen.dart';
import 'important_screen.dart';
import 'installed_apps_screen.dart';
import 'memories_screen.dart';
import 'new_files_screen.dart';
import 'swipe_pager.dart';
import '../../services/fm/dashboard_layout.dart';
import '../../widgets/fm/dashboard_layout_sheet.dart';
import 'ai_hub_screen.dart';
import '../../widgets/fm/ai_status_icon.dart';
import 'organize_screen.dart';
import 'photos_screen.dart';
import 'search_screen.dart';
import 'tools_screen.dart';
import 'trash_screen.dart';
import 'vault_screen.dart';
import '../../core/snack.dart';
import '../../core/safe_insets.dart';

part 'dashboard/volume_watch.dart';
part 'dashboard/scan.dart';
part 'dashboard/sections.dart';
part 'dashboard/tools.dart';
part 'dashboard/external_open.dart';
part 'dashboard/tiles.dart';
part 'dashboard/hero.dart';
part 'dashboard/cards.dart';

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

  /// Panonun son taramasındaki bir kategorinin dosyaları (alt çubuğa konan
  /// kategori sekmeleri ANINDA dolsun diye; tarama yoksa boş).
  static List<FsEntry> cachedFiles(FmCategory category) =>
      _DashboardScreenState._cachedIndex?.files(category) ?? const [];

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
  List<UsbDevice> _rawUsbDevices = const [];

  /// Ham aygıt ilk ne zaman görüldü? (İlk saniyelerde kart gösterilmiyor —
  /// Android'in bağlaması bitsin.)
  DateTime? _rawUsbSeenAt;

  /// Küçük yüzen düğmeler görünür mü? (Aşağı kaydırırken çekiliyorlar.)
  bool _fabsVisible = true;

  /// Takılma yayını üstüne yayın gelmesin (aynı anda tek tazeleme turu).
  bool _usbBroadcastBusy = false;

  /// Ham USB kartının bekleme süresi dolunca ekranı tazeleyen zamanlayıcı.
  Timer? _rawUsbGraceTimer;

  /// USB otomatik açma: sürüyor mu ve en son ne zaman açıldı?
  bool _usbOpening = false;
  DateTime? _lastUsbOpen;

  bool _scanning = false;

  /// Süren taramanın başlangıcı ve bir önceki taramanın süresi (tahmin için;
  /// süreç boyunca bellekte, uygulama açılışında diskten).
  int _scanStartedAtMs = 0;
  static int? _lastScanDurationMs;
  static const _scanDurationKey = 'fm_last_scan_duration_ms';

  static Future<void> _rememberScanDuration(int ms) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_scanDurationKey, ms);
    } catch (_) {}
  }

  static Future<void> _recallScanDuration() async {
    if (_lastScanDurationMs != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      _lastScanDurationMs = prefs.getInt(_scanDurationKey);
    } catch (_) {}
  }
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
    unawaited(_recallScanDuration());
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
    // Kullanıcının pano düzeni (sıra + göster/gizle).
    DashboardLayout.instance.addListener(_onLayoutChanged);
    unawaited(DashboardLayout.instance.ensureLoaded());
    unawaited(SmartFolders.instance.ensureLoaded());
    _boot();
    unawaited(_loadAppsSize());
    _startVolumeWatch();
  }

  @override
  void dispose() {
    DashboardLayout.instance.removeListener(_onLayoutChanged);
    WidgetsBinding.instance.removeObserver(this);
    FsEvents.version.removeListener(_onFsChanged);
    AppStorageService.setUsbAttachedHandler(null);
    _rawUsbGraceTimer?.cancel();
    unawaited(_volumeSub?.cancel());
    unawaited(_volumes.dispose());
    super.dispose();
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
      // **Birim taraması kısıtlı** (2026-09-23 pil denetimi): `resumed`
      // yalnız arkadan dönüşte değil, bildirim perdesi çekilip bırakılınca,
      // izin ya da paylaşım penceresi kapanınca da geliyor. Her birinde
      // birim başına `df` süreci + SAF/USB kanal çağrıları yapılıyordu.
      // Uygulama gerçekten arkaya gittiyse her zaman; yoksa en çok
      // [_resumeRescanEvery]'de bir. (Takılma/çıkarma zaten canlı yayınla
      // ve 5 sn'lik yoklamayla ayrıca yakalanıyor.)
      final now = DateTime.now().millisecondsSinceEpoch;
      if (_wentBackground ||
          now - _lastResumeRescanMs >= _resumeRescanEvery.inMilliseconds) {
        _lastResumeRescanMs = now;
        unawaited(_volumes.rescan());
        unawaited(_loadSafRoots());
      }
      _wentBackground = false;
      // Uygulama AÇIKKEN USB takılıp "Dosya Okuyucu ile aç" seçilirse
      // Android yeni bir intent gönderir (singleTask) ve `initState`
      // çalışmaz — eylemi burada da soruyoruz. Eylem okununca native
      // tarafta temizlendiği için iki kez tetiklenmez.
      unawaited(_openUsbIfLaunchedByIt());
      // Yüzen video penceresi uygulama kapalıyken kapatılmış olabilir:
      // konumu al ki uygulama içi oynatıcı kaldığı yerden sürsün.
      unawaited(VideoPlayback.instance.syncFloating());
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _wentBackground = true;
      _volumes.stop();
    }
  }

  /// Uygulama `hidden`/`paused`a düştü mü (yalnız `inactive` değil)?
  bool _wentBackground = false;
  int _lastResumeRescanMs = 0;
  static const _resumeRescanEvery = Duration(seconds: 15);

  @override
  void didUpdateWidget(covariant DashboardScreen old) {
    super.didUpdateWidget(old);
    // Sekmeye geri dönüldü ve arada dosya değişmiş → tazele.
    if (widget.active && !old.active && _stale) _scan();
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

  /// Dizin bu süreden eskiyse arka planda tazelenir. Uygulama dışında
  /// (galeri, WhatsApp…) biriken dosyalar sonsuza dek görünmez kalmasın.
  static const _maxIndexAge = Duration(hours: 12);

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
          // AI Merkezi (2026-09-27: alt çubuktaki AI sekmesi kalktı, kapısı
          // burada — analiz halkası ve öneri rozetiyle).
          IconButton(
            tooltip: context.t('aih.title'),
            icon: const AiStatusIcon(),
            onPressed: () => _push(const AiHubScreen()),
          ),
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
        child: NotificationListener<ScrollNotification>(
          // **Kaydırırken küçük düğmeler ÇEKİLİYOR** (kullanıcı ekran
          // görüntüsü 2026-09-02: çöp kutusu ve yeni klasör düğmeleri
          // "Uygulamalar" karesinin üstünde duruyordu). Yüzen düğmeler
          // tanım gereği içeriğin üstünde; çare onları kalıcı olarak
          // kaldırmak değil, kullanıcı LİSTEYE bakarken çekilmeleri.
          // Parmak yukarı kaydırınca (geri gelirken) yeniden beliriyorlar.
          onNotification: (n) {
            if (n is UserScrollNotification) {
              final show = n.direction != ScrollDirection.reverse;
              if (show != _fabsVisible) setState(() => _fabsVisible = show);
            }
            return false;
          },
          child: ListView(
          // Alt boşluk FAB yığınını (küçük düğme sırası + "Belge Tara") aşar:
          // 2026-08-06'da Gap.xl (32) yetmiyordu ve son satırdaki "Google
          // Drive" kartının yazısı düğmelerin altında kalıyordu.
          padding: withNavInset(
              context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 136)),
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
            if (_scanning)
              _ScanProgress(
                startedAtMs: _scanStartedAtMs,
                expectedMs: _lastScanDurationMs,
              ),
            // **Bölümler kullanıcının sırasıyla** (2026-09-27, bkz.
            // DashboardLayout): bellek kartları, kutular, araçlar, favoriler,
            // hızlı klasörler — her biri gizlenebilir.
            for (final id in DashboardLayout.instance.sectionOrder)
              if (DashboardLayout.instance.sectionVisible(id))
                ..._dashSection(id, volumes, appState),
            const SizedBox(height: Gap.lg),
            Center(
              child: TextButton.icon(
                onPressed: _editLayout,
                icon: const Icon(Icons.dashboard_customize_outlined, size: 18),
                label: Text(context.t('dash.title')),
              ),
            ),
            if (_cachedAtMs > 0) ...[
              const SizedBox(height: Gap.lg),
              Center(
                // Çeviri tablosundan (eskiden İngilizce/Arapça arayüzde de
                // Türkçe "Son tarama: … dosya" yazıyordu).
                child: Text(
                  context.t('fm.last_scan', {
                    'date': FsPaths.humanDate(_cachedAtMs),
                    'n': _index.totalFiles,
                  }),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Paper.faint(context)),
                ),
              ),
            ],
          ],
        ),
        ),
      ),
      // **Tek yüzen çubuk** (2026-10-18, kullanıcı ekran görüntüleriyle:
      // *"ana ekran biraz daha toparlanmalı ve daha premium hâle gelmeli"*).
      // Eskiden üç ayrı yüzen düğme vardı — iki küçük kare (çöp kutusu, yeni
      // klasör) bir sıra, "Belge Tara" altında ikinci sıra: sağ alt köşede
      // ~120 dp yükseklik kaplayıp "Araçlar" başlığının ve ızgaranın üstüne
      // biniyordu; dolu çöp kutusu da tam turuncu bir kare olarak bağırıyordu.
      // Artık üçü TEK bir kapsülde, tek sırada: çöp kutusu · yeni klasör |
      // Belge Tara. Kaydırırken kapsül yalnız tarama simgesine katlanır.
      floatingActionButton: _QuickDock(
        expanded: _fabsVisible,
        trashCount: _trashCount,
        onTrash: () async {
          await Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TrashScreen()));
          _loadTrash();
        },
        onNewFolder: _newFolderFlow,
        onScan: () => ScanFlow.run(context),
      ),
    );
  }

  /// Ham kartı göstermeden önce Android'in bağlamasına tanınan süre.
  ///
  /// Altı saniyeydi (2026-09-02) ve kullanıcı 2026-09-03'te *"çok geç
  /// düşüyor"* dedi. Üç saniye hâlâ çift kartı önlüyor (Android bağlayacaksa
  /// bunu ilk saniyelerde yapıyor) ama bekleme gözle "takıldı, tanındı"
  /// hissini bozmuyor.
  static const _rawUsbGrace = Duration(seconds: 3);


  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}
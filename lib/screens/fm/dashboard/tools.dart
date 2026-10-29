part of '../dashboard_screen.dart';

extension _DashboardScreenToolsPart on _DashboardScreenState {
  /// Akıllı bildirim alanının **olayları** — yalnız gerçekten yapılacak bir
  /// şey varsa (bellek ≥ %90, çöpte ≥ 300 öğe, ağdan erişim açık). Kimlikler
  /// eşik basamağını taşır: kapatılan uyarı durum kötüleşince yeniden gelir.
  List<InboxEvent> _inboxEvents(List<StorageVolume> volumes) {
    final out = <InboxEvent>[];
    final ftp = FtpService.instance;
    if (ftp.running) {
      out.add(InboxEvent(
        id: 'ftp',
        icon: AppIcons.hotspot,
        title: context.t('ftpd.open_action'),
        subtitle: ftp.addresses.isEmpty ? '' : ftp.addresses.first,
        actionLabel: context.t('common.close'),
        dismissible: false,
        onTap: () => _push(const FtpServerScreen()),
        onAction: () => ftp.stop(),
      ));
    }
    for (final v in volumes) {
      if (!v.isPrimary || !v.hasStats || v.capacityBytes <= 0) continue;
      final pct = (v.usedBytes * 100 / v.capacityBytes).round();
      if (pct < 90) continue;
      out.add(InboxEvent(
        id: 'storage_${pct >= 95 ? 95 : 90}',
        icon: AppIcons.warning,
        warning: true,
        title: context.t('inbox.storage_full', {'n': pct}),
        subtitle: context.t('fm.free_bytes',
            {'v': FsPaths.humanCapacity(v.freeBytes)}),
        actionLabel: context.t('fm.free_space'),
        onTap: () {
          unawaited(ToolUsage.record('free_space'));
          _push(CleanupScreen(index: _index));
        },
      ));
    }
    if (_trashCount >= 300) {
      out.add(InboxEvent(
        id: 'trash_${_trashCount ~/ 500}',
        icon: AppIcons.deleteSweep,
        title: context.t('inbox.trash_full', {'n': _trashCount}),
        subtitle: context.t('inbox.trash_hint'),
        actionLabel: context.t('inbox.open'),
        onTap: () async {
          await _push(const TrashScreen());
          if (mounted) await _loadTrash();
        },
      ));
    }
    return out;
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
            ? AppIcons.autorenew
            : AppIcons.playlistAddCheckCircle,
        color: AppHues.green,
        id: 'jobs',
        label: context.t('fm.jobs'),
        subtitle: runningJobs > 0
            ? context.t('fm.jobs_running', {'n': runningJobs})
            : (finishedJobs > 0
                ? context.t('fm.jobs_finished', {'n': finishedJobs})
                : ''),
        onTap: () async {
          await HistoryScreen.open(context, HistorySection.jobs);
          if (mounted) _partSetState(() {});
        },
      ),
      // (Yaptıklarım ve Son işlemler 2026-10-21'de Geçmiş'e katıldı: İşlemler
      // kutusu Geçmiş'in İşlemler bölümünü açar.)
      // (Gizli dosyalar 2026-10-21'de Kasa'ya katıldı: gizlemek = şifreli
      // kasaya taşımak; eski gizliler Kasa ekranından taşınır.)
      // **Aktar** (2026-10-21, Faz 2): Ağdan erişim, Yakındaki cihaz, Ağ
      // depolama ve İndir dört ayrı kutuydu; tek kapı oldu. Alt yazı canlı:
      // paylaşım açıksa ya da indirme sürüyorsa yazar.
      FmTileData(
        icon: FtpService.instance.running
            ? AppIcons.hotspot
            : AppIcons.swapHoriz,
        color: AppHues.jade,
        id: 'transfer',
        label: context.t('xfer.title'),
        subtitle: FtpService.instance.running
            ? context.t('ftpd.running')
            : (downloading > 0
                ? context.t('fm.jobs_running', {'n': downloading})
                : ''),
        onTap: () async {
          await _push(const TransferScreen());
          if (mounted) _partSetState(() {});
        },
      ),
      // **Yeni belge** — boş Word/Excel/metin oluşturur. 2026-08-17'ye kadar
      // "Son belgeler" sekmesinin içindeydi; o sekme kullanıcı isteğiyle alt
      // gezinme çubuğundan kalkınca akış buraya alındı. Kaldırılan şey
      // belgelerin LİSTESİYDİ, oluşturma değil.
      FmTileData(
        icon: AppIcons.noteAdd,
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
        icon: AppIcons.cleanEmpty,
        color: AppHues.cyan,
        id: 'free_space',
        label: context.t('fm.free_space'),
        // CANLI bilgi (2026-09-26): bu oturumda çözümleme yapıldıysa bulduğu
        // toplam ("2,1 GB"). Yapılmadıysa boş — tahmin yazılmaz.
        subtitle: switch (lastCleanupRecoverable()) {
          final int bytes when bytes > 0 => FsPaths.humanSize(bytes),
          _ => '',
        },
        onTap: () => _push(CleanupScreen(index: _index)),
      ),
      // Anılar 2026-10-29'da kaldırıldı (kullanıcı isteği: "anıları kaldır").
      // Sesli kitaplar (2026-10-22): belgeden üretilmiş, kayıtlı ses dosyaları.
      FmTileData(
        icon: AppIcons.audiobook,
        color: AppHues.sea,
        id: 'audiobooks',
        label: context.t('ab.library'),
        subtitle: '',
        onTap: () => _push(const AudiobookLibraryScreen()),
      ),
      // Şifreli kasa (2026-10-18): PIN/parmak iziyle açılan, içeriği
      // şifreli klasör — kimlik, tapu, sözleşme taramaları için.
      FmTileData(
        icon: AppIcons.vault,
        color: AppHues.slate,
        id: 'vault',
        label: context.t('vault.title'),
        subtitle: '',
        onTap: () => _push(const VaultScreen()),
      ),
      // (Faturalar ve Akıllı klasörler 2026-10-21'de AI Merkezi'ne indi —
      // K8: "ayrı pano kutusu değil, AI Merkezi'nin alt bölümü".)
      // (Sohbet medyası ve Benzer görseller 2026-10-21'de Depolama
      // analizine — "Depolama merkezi" — taşındı.)
      FmTileData(
        icon: AppIcons.autoAwesomeMotion,
        color: AppHues.violet,
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
      // NOT: "Son açılanlar" buradan YUKARI, büyük kutulara taşındı (bkz.
      // `_categoryGrid`). "Son işlemler" taşı/kopyala/sil gibi İŞLEMLERİ
      // tutar; o, hangi DOSYALARIN ne zaman AÇILDIĞINI — ikisi ayrı veri,
      // ayrı ekran, ikisi birden araç satırında olunca karışıyordu.
      // Çöp kutusu buradan YUKARI taşındı (bkz. `_trashTile`): kullanıcı
      // 2026-07-31'de "çöp kutusunu bulmak çok zor" dedi. Araçlar ızgarası
      // küçük ve kartsız; 12 küçük simgenin arasında geri alma kapısının
      // kaybolması, silinen dosyayı kurtaramamak demekti.
      // **Sohbet temizliği** araçlarda da (2026-10-23, kullanıcı: *"araçlar
      // alanı en güçlü olduğumuz ve en sık kullanılacak şeylerle dolu
      // başlamalı"*). WhatsApp yığını en çok yer açan tek iş; Yer aç'ın
      // içinde iki dokunuş derindeydi. Alt yazı süren/biten taramanın özeti.
      FmTileData(
        icon: AppIcons.forum,
        color: AppHues.green,
        id: 'chat_cleanup',
        label: context.t('cj.title'),
        subtitle: switch (queue.find(ChatJunkLive.jobId)) {
          final job? when job.status.isActive =>
            context.t('fm.jobs_running', {'n': 1}),
          final job? when job.result is ChatJunkReport =>
            (job.result as ChatJunkReport).junkFiles == 0
                ? ''
                : FsPaths.humanSize((job.result as ChatJunkReport).junkBytes),
          _ => '',
        },
        onTap: () => openChatCleanupScreen(context),
      ),
    ];
    // **Varsayılan sıra = güç sırası** (2026-10-23): hiç dokunulmamış bir
    // kurulumda ızgara en çok işe yarayanla başlar; kullanım sayacı yine
    // üstüne biner ([_rankedTools]). İşlemler sona yakın: süren/biten işler
    // artık panonun en üstündeki bildirim alanında.
    const order = [
      'free_space',
      'chat_cleanup',
      'transfer',
      'vault',
      'organize',
      'new_document',
      'jobs',
      'audiobooks',
    ];
    int rank(FmTileData t) {
      final i = order.indexOf(t.id);
      return i < 0 ? order.length : i;
    }

    return [...tools]..sort((a, b) => rank(a).compareTo(rank(b)));
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
          ? AppIcons.sdCard
          : (usb > 0 || externals.isEmpty ? AppIcons.external : AppIcons.sdCard),
      color: !anything
          ? AppHues.silver
          : AppHues.orange,
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
                '${context.t('fm.free_bytes', {'v': FsPaths.humanSize(externals.single.freeBytes)})}'
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
    _partSetState(() => _safRoots = roots);
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
    final drivable = [
      for (final d in devices)
        if (d.isDrivable) d,
    ];
    _partSetState(() {
      if (drivable.isEmpty) {
        _rawUsbSeenAt = null;
        _rawUsbGraceTimer?.cancel();
        _rawUsbGraceTimer = null;
      } else {
        _rawUsbSeenAt ??= DateTime.now();
      }
      _rawUsbDevices = drivable;
    });
    // **Bekleme süresi dolunca kimse ekranı tazelemiyordu** (kullanıcı
    // 2026-09-03: *"çok geç düşüyor"*): kart ancak bir sonraki tam tarama
    // ya da başka bir `setState` ile beliriyordu — pratikte kullanıcı
    // ekrana dokunana kadar hiç. Süre dolunca bir kez çiziyoruz.
    final seen = _rawUsbSeenAt;
    if (seen != null && _rawUsbGraceTimer == null) {
      final left = _DashboardScreenState._rawUsbGrace - DateTime.now().difference(seen);
      _rawUsbGraceTimer = Timer(left.isNegative ? Duration.zero : left, () {
        _rawUsbGraceTimer = null;
        if (mounted) _partSetState(() {});
      });
    }
  }

  /// Panoda çizilecek ham USB kartları.
  ///
  /// **TUZAK (kullanıcı ekran görüntüsü 2026-09-02):** aynı bellek panoda İKİ
  /// KEZ çıkıyordu — "VendorCo USB sürücüsü" (bağlanmış birim) ve "USB Disk
  /// 2.0" (ham aygıt). Sebep: karar aygıt listesi okunduğu ANDA veriliyor ve
  /// saklanıyordu; Android belleği saniyeler sonra bağlayınca karar
  /// eskiyordu ama kart öylece kalıyordu. Karar artık ÇİZİM anında
  /// veriliyor: bağlanmış bir takılabilir birim ya da klasör izni varsa ham
  /// kart hiç çizilmiyor.
  ///
  /// Ayrıca ilk saniyelerde ham kartı hiç göstermiyoruz: Android bağlamayı
  /// bitirmeden aygıtın ham adını ("USB Disk 2.0") göstermek, iki saniye
  /// sonra gerçek adıyla ("VendorCo USB sürücüsü") beliren aynı belleğin
  /// yanında kafa karıştırıyor.
  List<UsbDevice> get _rawUsbCards {
    if (FmEnv.volumes.any((v) => v.isRemovable)) return const [];
    if (_safRoots.isNotEmpty) return const [];
    final seen = _rawUsbSeenAt;
    if (seen != null && DateTime.now().difference(seen) < _DashboardScreenState._rawUsbGrace) {
      return const [];
    }
    return _rawUsbDevices;
  }
}

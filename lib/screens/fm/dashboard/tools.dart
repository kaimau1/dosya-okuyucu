part of '../dashboard_screen.dart';

extension _DashboardScreenToolsPart on _DashboardScreenState {
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
            ? Icons.wifi_tethering
            : Icons.swap_horiz_rounded,
        color: const Color(0xFF00897B),
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
        // CANLI bilgi (2026-09-26): bu oturumda çözümleme yapıldıysa bulduğu
        // toplam ("2,1 GB"). Yapılmadıysa boş — tahmin yazılmaz.
        subtitle: switch (lastCleanupRecoverable()) {
          final int bytes when bytes > 0 => FsPaths.humanSize(bytes),
          _ => '',
        },
        onTap: () => _push(CleanupScreen(index: _index)),
      ),
      // Anılar (2026-10-18): bu gün, yerler, insanlar — cihazda.
      FmTileData(
        icon: Icons.auto_awesome_mosaic_rounded,
        color: const Color(0xFFE0668F),
        id: 'memories',
        label: context.t('mem.title'),
        subtitle: '',
        onTap: () => _push(const MemoriesScreen()),
      ),
      // Şifreli kasa (2026-10-18): PIN/parmak iziyle açılan, içeriği
      // şifreli klasör — kimlik, tapu, sözleşme taramaları için.
      FmTileData(
        icon: Icons.enhanced_encryption_rounded,
        color: const Color(0xFF37474F),
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

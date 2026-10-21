part of '../dashboard_screen.dart';

extension _DashboardScreenVolumeWatchPart on _DashboardScreenState {
  /// Uygulama boyutları platform kanalından gelir (yüzlerce binder çağrısı),
  /// o yüzden panonun açılışını beklemez: arka planda gelir, gelince kutunun
  /// alt yazısı dolar. Sonuç `InstalledAppsService` içinde 5 dakika saklandığı
  /// için Bellek Analizi ekranı da bundan sonra anında açılır.
  ///
  /// **Faz 4 (P5):** sonuç prefs'te 6 saat saklanır — soğuk açılışta önce
  /// kayıtlı değer anında gösterilir; bayatsa yeniden hesap açılış
  /// kuyruğuna (StartupQueue) girer. Hafif profilde yalnız kayıtlı değer
  /// gösterilir; hesap, kullanıcı Uygulamalar ekranını açınca yapılır.
  Future<void> _loadAppsSize() async {
    const kBytes = 'dash_apps_bytes';
    const kAt = 'dash_apps_at';
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getInt(kBytes);
    final at = prefs.getInt(kAt) ?? 0;
    if (saved != null && mounted) _partSetState(() => _appsBytes = saved);
    final age = DateTime.now().millisecondsSinceEpoch - at;
    final fresh = saved != null && age >= 0 && age < 6 * 3600 * 1000;
    if (fresh || DeviceProfile.budget.isLight) return;
    StartupQueue.instance.add('apps-size', () async {
      final summary = await InstalledAppsService.summary();
      if (!summary.hasData) return;
      await prefs.setInt(kBytes, summary.totalBytes);
      await prefs.setInt(kAt, DateTime.now().millisecondsSinceEpoch);
      if (mounted) _partSetState(() => _appsBytes = summary.totalBytes);
    });
  }

  void _onLayoutChanged() {
    if (mounted) _partSetState(() {});
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
      _partSetState(() {}); // birim listesi tazelendi (FmEnv.volumes)
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
    AppStorageService.setUsbAttachedHandler(
      () {
        if (!mounted) return;
        unawaited(_openUsbIfLaunchedByIt(force: true));
      },
      // **Canlı yayın** (kullanıcı 2026-09-03: *"usb takıldığında ana menüde
      // hızlı biçimde sayfa güncellenip eklenmeli, çok geç düşüyor"*).
      // Çekirdek yayını takılmanın İLK anında geliyor — 5 saniyelik
      // `/storage` yoklamasını beklemiyoruz.
      onChanged: (attached) => unawaited(_onUsbBroadcast(attached)),
    );
  }

  /// **Takılma/çıkarılma yayını geldi** — listeyi hemen tazele.
  ///
  /// Android takmayı (`USB_DEVICE_ATTACHED`) ve bağlamayı (`MEDIA_MOUNTED`)
  /// ayrı anlarda haber veriyor; ilki hemen, ikincisi saniyeler sonra gelir.
  /// Bu yüzden ilk yayında bir kez değil, kısa aralıklarla birkaç kez
  /// bakılıyor: bellek bağlanır bağlanmaz kart yerine geçsin. Bağlanmışsa
  /// erken çıkılıyor (boşuna tarama yok).
  Future<void> _onUsbBroadcast(bool attached) async {
    if (_usbBroadcastBusy) return;
    _usbBroadcastBusy = true;
    try {
      for (var attempt = 0; attempt < 5; attempt++) {
        await _volumes.rescan();
        await _loadRawUsb();
        if (!mounted) return;
        _partSetState(() {});
        if (!attached) return;
        if (FmEnv.volumes.any((v) => v.isRemovable)) return;
        await Future<void>.delayed(const Duration(milliseconds: 900));
        if (!mounted) return;
      }
    } finally {
      _usbBroadcastBusy = false;
    }
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
    // **TEK AÇILIŞ** (kullanıcı 2026-09-02: *"üst üste 2 kez otomatik
    // açılıyor"*). İki yol aynı takılmayı haber veriyor: native itme
    // (`usbAttached`) ve uygulama öne gelince okunan `launchAction`. İkisi de
    // ekranı açınca bellek üst üste iki kez açılıyordu.
    if (_usbOpening) return;
    final last = _lastUsbOpen;
    if (last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 20)) {
      return;
    }
    if (force) {
      // Native itme geldiyse bekleyen eylemi TÜKET: yoksa uygulama öne
      // gelince ikinci kez tetiklenirdi.
      unawaited(AppStorageService.launchAction());
    } else if (!await AppStorageService.launchedByUsb()) {
      return;
    }
    _usbOpening = true;
    try {
      await _usbOpenFlow();
    } finally {
      _usbOpening = false;
    }
  }

  Future<void> _usbOpenFlow() async {
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
        _lastUsbOpen = DateTime.now();
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
      _lastUsbOpen = DateTime.now();
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
    // **Kısa şerit + "Ayrıntı"** (dışarıdan bakış 2026-09-02): eski mesaj
    // dört satırlık bir paragraftı ve şerit altı saniyede kayboluyordu —
    // kimse okuyamıyordu. Şerit artık tek cümle; açıklamanın tamamı, isteyen
    // için, kapanmayan bir pencerede.
    showSnack(
      context,
      context.t('fm.external_unusable_short', {'name': stuck.name}),
      duration: kSnackAction,
      action: SnackBarAction(
        label: context.t('common.details'),
        onPressed: () => unawaited(_showStuckDetail(stuck)),
      ),
    );
  }

  /// Takılı ama açılamayan bellek: ne olduğu ve iki çıkış yolu.
  Future<void> _showStuckDetail(UnusableVolume stuck) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('fm.external_unusable_title', {'name': stuck.name})),
        content: SingleChildScrollView(
          child: Text(ctx.t('fm.external_unusable', {'name': stuck.name})),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.close'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'diag'),
              child: Text(ctx.t('usb.diag_title'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'saf'),
              child: Text(ctx.t('saf.pick'))),
        ],
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'diag') return _openDiagnostics();
    await _openViaSaf(volume: stuck.key);
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
    _partSetState(() => _hasAccess = access);
    if (_DashboardScreenState._cachedIndex != null) {
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

  Future<void> _catchUp() async {
    if (_catchingUp || _scanning || !mounted) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastCatchUpMs < _DashboardScreenState._catchUpEvery.inMilliseconds) return;
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
      _DashboardScreenState._cachedIndex = merged;
      _partSetState(() => _index = merged);
    } finally {
      _catchingUp = false;
    }
  }

  /// Taramada eksiksiz sayılması istenen klasörler. Şimdilik tek üye:
  /// Önemli Dosyalar kutusu gerçek sayıyı buradan okur (bkz. `_importantStat`).
  List<String> get _statFolders => [
        ImportantScreen.pathIn(FmEnv.primaryRoot),
      ];

  bool get _indexTooOld =>
      DateTime.now().millisecondsSinceEpoch - SearchIndex.builtAtMs >
          _DashboardScreenState._maxIndexAge.inMilliseconds;

  /// Arama dizininden pano indeksini kurar; kurulamazsa false (tam tarama).
  Future<bool> _restoreFromIndex() async {
    await SearchIndex.ensureLoaded();
    if (!SearchIndex.isReady) return false;
    final index = await FsScan.indexFromRows(
      SearchIndex.indexPath,
      statFolders: _statFolders,
    );
    if (index == null) return false;
    _DashboardScreenState._cachedIndex = index;
    _DashboardScreenState._cachedAtMs = SearchIndex.builtAtMs;
    if (!mounted) return true;
    _partSetState(() => _index = index);
    return true;
  }
}

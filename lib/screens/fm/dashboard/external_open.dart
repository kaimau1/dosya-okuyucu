part of '../dashboard_screen.dart';

extension _DashboardScreenExternalOpenPart on _DashboardScreenState {
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
        _partSetState(() {});
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

  /// Birim kartına UZUN BASINCA açılan menü.
  ///
  /// Kullanıcı 2026-09-02: *"güvenle çıkarı bulamadım; hem ana ekranda
  /// üzerine basılı tutunca çıkmalı hem de içerideki üç noktada olmalı"* ve
  /// *"USB ve SD kartlarda da bellek analizi yapabilelim"*. İkisi de burada.
  Future<void> _volumeMenu(StorageVolume volume) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(volumeIcon(volume)),
              title: Text(volume.displayLabel(ctx.t)),
              subtitle: Text(volume.hasStats
                  ? '${ctx.t('fm.free_bytes', {'v': FsPaths.humanSize(volume.freeBytes)})} · ${volume.path}'
                  : volume.path),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: Text(ctx.t('common.open')),
              onTap: () => Navigator.pop(ctx, 'open'),
            ),
            ListTile(
              leading: const Icon(Icons.donut_small),
              title: Text(ctx.t('fm.memory_analysis')),
              onTap: () => Navigator.pop(ctx, 'analysis'),
            ),
            // SD kartla birleşik depolama (2026-10-17): kartın kendi
            // menüsünde — kullanıcı "kartı nasıl kullanırım" diye burada arar.
            if (volume.isRemovable)
              ListTile(
                leading: const Icon(Icons.eject),
                title: Text(ctx.t('usb.eject')),
                onTap: () => Navigator.pop(ctx, 'eject'),
              ),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'open':
        await _push(BrowserScreen(
            path: volume.path, title: volume.displayLabel(context.t)));
      case 'analysis':
        // **Analiz artık her birimde** — eskiden yalnız ana bellekteydi.
        await _push(AnalysisScreen(index: _index, volumes: [volume]));
      case 'eject':
        await _ejectVolume(volume);
    }
  }

  /// **Güvenle çıkar.**
  ///
  /// Android'in bağladığı bir birimi uygulama SÖKEMEZ (herkese açık API yok);
  /// orada dürüst olan, ne yapılacağını söylemek. Ham USB'de (uygulamanın
  /// kendi sürdüğü bellek) gerçekten bırakabiliyoruz.
  Future<void> _ejectVolume(StorageVolume volume) async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('usb.eject')),
        content: Text(ctx.t('usb.eject_mounted_hint')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.close'))),
        ],
      ),
    );
  }

  /// **Ham USB:** Android belleği bağlamadıysa uygulama onu kendi sürer.
  ///
  /// Salt okunur (bkz. `UsbFs`): dosyalar açılır ve kopyalanır, belleğe
  /// yazılmaz. Açılamazsa sebebi söylenir — sessizce boş ekran açmak yerine.
  Future<void> _openRawUsb(String deviceName, {int? partitionIndex}) async {
    final outcome =
        await UsbFs.open(deviceName: deviceName, partitionIndex: partitionIndex);
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
    // **Çok bölümlü bellek** (2026-09-04): eskiden yalnız İLK tanınan bölüm
    // açılıyordu ve ötekilerin varlığı hiçbir yerde yazmıyordu — kullanıcı
    // "dosyalarım kayboldu" görüyordu. Şerit hem haber veriyor hem geçiş
    // yolu bırakıyor.
    if (outcome.hasOtherVolumes) {
      showSnack(
        context,
        context.t('usb.multi_volume', {'n': '${outcome.volumes.length}'}),
        duration: kSnackAction,
        action: SnackBarAction(
          label: context.t('usb.pick_volume'),
          onPressed: () => unawaited(_pickUsbVolume(deviceName, outcome)),
        ),
      );
    }
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => RemoteBrowserScreen(connection: fs.connection, fs: fs),
    ));
    await fs.close();
  }

  /// Tanınan bölümler arasından seçtirir ve seçileni açar.
  Future<void> _pickUsbVolume(String deviceName, UsbOpenOutcome outcome) async {
    final choice = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(ctx.t('usb.pick_volume')),
        children: [
          for (final v in outcome.volumes)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, v.index),
              child: ListTile(
                leading: const Icon(Icons.usb),
                title: Text(v.label),
                subtitle: Text('${v.format} · @${v.firstLba}'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
    );
    if (choice == null || !mounted) return;
    await _openRawUsb(deviceName, partitionIndex: choice);
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
}

part of '../nearby_screen.dart';

/// Yakındakiler'in ağ yolları: QR/web sunucusu, geçici ağ (hotspot),
/// Bluetooth daveti ve arka planda görünürlük (kişisel derleme).
extension _NearbyLinks on _NearbyScreenState {
  // ── Arka planda görünürlük (kişisel derleme) ───────────────────────────

  Future<void> _loadBg() async {
    final state = await BleNearby.bgState();
    if (!mounted) return;
    _update(() {
      _bgAvailable = state.available;
      _bgOn = state.on;
    });
  }

  Future<bool> _enableBg() {
    final strings = AppStrings.of(context);
    return BleNearby.bgEnable(id: _id, name: _deviceName, texts: {
      'bg_title': strings.t('near.bg_note_title'),
      'bg_text': strings.t('near.bg_note_text'),
      // {name}/{n} yer tutucuları bildirimi kuran Kotlin tarafında doldurulur.
      'ask_title': strings.t('near.bg_ask_title'),
      'ask_body': strings.t('near.bg_ask_body'),
      'accept': strings.t('near.accept'),
      'reject': strings.t('near.decline'),
      'ch_quiet': strings.t('near.bg_ch_quiet'),
      'ch_ask': strings.t('near.bg_ch_ask'),
    });
  }

  Future<void> _toggleBg() async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    if (_bgOn) {
      await BleNearby.bgDisable();
      if (!mounted) return;
      _update(() => _bgOn = false);
      showSnackOn(messenger, strings.t('near.bg_off'));
      return;
    }
    final ok = await _enableBg();
    if (!mounted) return;
    _update(() => _bgOn = ok);
    showSnackOn(messenger, strings.t(ok ? 'near.bg_on' : 'near.bg_failed'),
        duration: const Duration(seconds: 6));
  }

  // ── QR / web sunucusu ──────────────────────────────────────────────────

  /// Seçim değişince sunucu yeni listeyle (kısa bir beklemeden sonra) kurulur.
  void _scheduleWeb() {
    if (!widget.services) return;
    _webDebounce?.cancel();
    _webDebounce = Timer(Motion.long, () {
      unawaited(_restartWeb());
    });
  }

  Future<void> _restartWeb() async {
    final old = _web;
    _web = null;
    // Seçim değişti diye süren indirme kesilmez.
    if (old != null) await TransferKeeper.instance.handOff(old);
    if (_selection.isEmpty) {
      if (mounted) _update(() {});
      return;
    }
    try {
      final server = QrShareServer([..._selection],
          senderName: _deviceName,
          ttl: _linkTtl,
          maxDownloads: _linkOnce ? _selection.length : null,
          onExpired: () {
            if (mounted) {
              _update(() {
                _web = null;
                _linkExpired = true;
              });
            }
          },
          onActivity: TransferKeeper.instance.onActivity,
          thumbnail: TransferThumbs.of,
          onServed: (name) {
            unawaited(TransferHistory.instance.add([
              TransferRecord(
                incoming: false,
                path: _selection.firstWhere((s) => name.startsWith(p.basename(s)),
                    orElse: () => name),
                name: name,
                size: 0,
                peer: AppStrings.current.t('near.via_web'),
                at: DateTime.now(),
              ),
            ]));
            if (mounted) _update(() => _served++);
          });
      await server.start();
      final host = await _NearbyScreenState._wifiAddress();
      if (!mounted) {
        await server.stop();
        return;
      }
      _update(() {
        _web = server;
        _webHost = host;
        _webError = null;
        _linkExpired = false;
      });
      // Ortak Wi-Fi yoksa hotspot tek yol — sormadan kurulur.
      if (host == null && _hotspot == null) await _startHotspot();
    } catch (e) {
      if (mounted) _update(() => _webError = userErrorText(e));
    }
  }

  Future<bool> _startHotspot() async {
    if (_hotspot != null) return true;
    if (_hotspotBusy) return false;
    TransferKeeper.instance.detachClosers();
    _update(() => _hotspotBusy = true);
    final before = <String>{if (_webHost != null) _webHost!};
    try {
      final h = await QrNative.startHotspot();
      String? host;
      for (var i = 0; i < 20 && host == null; i++) {
        await Future<void>.delayed(Motion.medium);
        host = await _NearbyScreenState._wifiAddress(except: before);
      }
      if (!mounted) return false;
      _update(() {
        _hotspot = h;
        _hotspotHost = host;
        _hotspotStep = 0;
        if (host == null) _webError = context.t('qrf.no_address');
      });
      return host != null;
    } on PlatformException catch (e) {
      if (mounted) {
        _update(() => _webError = context.t(switch (e.code) {
              'perm' => 'qrf.err_perm',
              'location_off' => 'qrf.err_location',
              'unsupported' => 'qrf.err_unsupported',
              _ => 'qrf.err_hotspot',
            }));
      }
      return false;
    } finally {
      if (mounted) _update(() => _hotspotBusy = false);
    }
  }

  // ── Bluetooth daveti ───────────────────────────────────────────────────

  /// Yalnız Bluetooth'tan görünen cihaz: gönderen geçici ağ kurar, adresi
  /// davet olarak yollar; alıcı onaylayınca dosyalar Wi-Fi'den çekilir.
  Future<void> _sendBle(_Near near) async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    if (_web == null) await _restartWeb();
    final web = _web;
    if (web == null || !mounted) return;
    // Aynı Wi-Fi'de olmadığımızı varsayıyoruz (öyle olsaydı Wi-Fi'den de
    // görünürdü): geçici ağ kurulur. Kurulamazsa Wi-Fi adresi denenir.
    final hotspotOk = await _startHotspot();
    if (!mounted) return;
    final hs = _hotspot;
    String? url;
    if (hotspotOk && hs != null && _hotspotHost != null) {
      url = QrPayload.encode(web.urlFor(_hotspotHost!),
          ssid: hs.ssid, pass: hs.pass, sec: hs.sec);
    } else if (_webHost != null) {
      url = web.urlFor(_webHost!).toString();
    }
    if (url == null) {
      showSnackOn(messenger, strings.t('near.no_network'));
      return;
    }
    final total = _selection.fold<int>(0, (a, s) => a + _NearbyScreenState._sizeOf(s));
    showSnackOn(messenger, strings.t('near.inviting', {'name': near.name}));
    final ok = await BleNearby.invite(
      near.ble!.address,
      BleInvite(
        from: _deviceName,
        fromId: _id,
        url: url,
        count: _selection.length,
        totalBytes: total,
        names: [for (final s in _selection) p.basename(s)],
      ),
    );
    showSnackOn(
      messenger,
      ok
          ? strings.t('near.invited', {'name': near.name})
          : strings.t('near.invite_failed', {'name': near.name}),
      duration: const Duration(seconds: 6),
    );
  }
}

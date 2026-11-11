part of '../slideshow_screen.dart';

/// Kayıtlı anlatım parçası: destedeki slayt sırası, ses dosyası, süre (ms).
typedef NarrationClip = ({int slide, String path, int ms});

/// **Faz 38 / madde 9 — kumanda, anlatım kaydı, ikinci ekran.**
///
/// * **Ses tuşları:** aşağı = ileri, yukarı = geri (`ci/Slayt.kt`); kapalıyken
///   ses tuşları sesi ayarlar.
/// * **Yerel ağ:** aynı Wi-Fi'deki tarayıcıdan ileri/geri. Rastgele anahtarlı
///   adres; sunucu yalnız sunum açıkken ve kumanda açıkken dinler.
/// * **Anlatım:** her slayt ayrı M4A; slayt değişince kayıt bölünür, sunum
///   bitince editöre döner (editör desteye gömer).
/// * **İkinci ekran (HDMI/Cast):** slayt orada (PNG), telefonda sunucu görünümü.
extension _SlideshowRemote on _SlideshowScreenState {
  // ── Ses tuşları ───────────────────────────────────────────────────────────

  void _wireNative() {
    _nativeSub ??= SlidesNative.events.listen((e) {
      if (!mounted) return;
      switch (e) {
        case ('volume', 'next'):
          _forward();
        case ('volume', 'prev'):
          _backward();
        case ('screens', final int n):
          _partSetState(() => _screens = n);
          if (n == 0 && _second) _partSetState(() => _second = false);
      }
    });
  }

  Future<void> _toggleVolumeKeys() async {
    _wireNative();
    final on = !_volumeKeys;
    await SlidesNative.volumeKeys(on);
    _partSetState(() => _volumeKeys = on);
  }

  // ── Yerel ağ ──────────────────────────────────────────────────────────────

  Future<void> _toggleWebRemote() async {
    if (_server != null) {
      await _server!.close(force: true);
      _partSetState(() {
        _server = null;
        _remoteUrl = null;
      });
      return;
    }
    try {
      final server = await HttpServer.bind(InternetAddress.anyIPv4, 0);
      final token = List.generate(
          8, (_) => 'abcdefghjkmnpqrstuvwxyz23456789'[Random.secure().nextInt(31)]).join();
      server.listen((req) => _serve(req, token), onError: (_) {});
      String? ip;
      for (final ni in await NetworkInterface.list(type: InternetAddressType.IPv4)) {
        for (final a in ni.addresses) {
          if (!a.isLoopback) ip ??= a.address;
          if (!a.isLoopback && ni.name.startsWith('wlan')) ip = a.address;
        }
      }
      _partSetState(() {
        _server = server;
        _remoteUrl = 'http://${ip ?? '127.0.0.1'}:${server.port}/$token';
      });
    } catch (_) {
      _partSetState(() => _remoteUrl = null);
    }
  }

  Future<void> _serve(HttpRequest req, String token) async {
    // G4.1/G4.9: yalnız yerel ağdan; jeton (8 karakter, Random.secure ≈ 40
    // bit) sabit zamanlı karşılaştırılır. Kumanda yalnız ileri/geri ve sıra
    // numarası verir (not metni gönderilmez).
    if (!await LanGuard.admit(req)) return;
    final res = req.response;
    if (!mounted) {
      res.statusCode = HttpStatus.gone;
      await res.close();
      return;
    }
    final seg = req.uri.pathSegments;
    if (seg.isEmpty || !LanGuard.safeEquals(seg.first, token)) {
      res.statusCode = HttpStatus.notFound;
      await res.close();
      return;
    }
    final cmd = seg.length > 1 ? seg[1] : '';
    if (mounted) {
      switch (cmd) {
        case 'next':
          _forward();
        case 'prev':
          _backward();
      }
    }
    LanGuard.secureHeaders(res, script: true);
    if (cmd.isEmpty) {
      res.headers.contentType = ContentType.html;
      res.write(_remotePage(context.t('ss.prev'), context.t('ss.next')));
    } else {
      res.headers.contentType = ContentType.json;
      res.write('{"n":${_index + 1},"total":${widget.slides.length}}');
    }
    await res.close();
  }

  /// Kumanda sayfası (tek HTML, dış kaynak yok). Not METNİ gönderilmez
  /// (ağdaki başkası görmesin) — yalnız sıra numarası.
  static String _remotePage(String prev, String next) => '''<!doctype html>
<html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Slayt</title><style>
body{margin:0;font-family:sans-serif;background:#111;color:#eee;display:flex;flex-direction:column;height:100vh}
#n{text-align:center;font-size:28px;padding:16px}
.r{flex:1;display:flex;gap:12px;padding:12px}
button{flex:1;font-size:32px;border:0;border-radius:16px;background:#2f6fe0;color:#fff}
button.p{background:#444}
</style></head><body><div id="n">…</div><div class="r">
<button class="p" onclick="go('prev')">&#9664; $prev</button>
<button onclick="go('next')">$next &#9654;</button></div>
<script>
function show(j){document.getElementById('n').textContent=j.n+' / '+j.total}
function go(c){fetch(location.pathname.replace(/\\/\$/,'')+'/'+c).then(r=>r.json()).then(show)}
go('state');setInterval(()=>go('state'),3000);
</script></body></html>''';

  // ── Anlatım kaydı ─────────────────────────────────────────────────────────

  Future<void> _recStart() async {
    if (!widget.record) return;
    final deckI = _index < widget.deckIndex.length ? widget.deckIndex[_index] : _index;
    final path = '${Directory.systemTemp.path}/anlatim_${DateTime.now().millisecondsSinceEpoch}_$deckI.m4a';
    final ok = await SlidesNative.recordStart(path);
    if (!mounted) return;
    if (ok) {
      _recSlide = deckI;
      _recClock
        ..reset()
        ..start();
    }
    _partSetState(() => _recording = ok);
  }

  Future<void> _recCut() async {
    if (!_recording) return;
    final slide = _recSlide;
    final ms = _recClock.elapsedMilliseconds;
    _recClock.stop();
    final path = await SlidesNative.recordStop();
    _recording = false;
    if (path != null && slide != null && ms >= 500) {
      _clips.removeWhere((c) => c.slide == slide); // yeniden kayıt öncekini ezer
      _clips.add((slide: slide, path: path, ms: ms));
    }
  }

  /// Slayt değişince: kayıt bölünür, yenisi başlar.
  Future<void> _recOnPage() async {
    if (!widget.record) return;
    await _recCut();
    if (mounted) await _recStart();
  }

  /// Çıkış: kaydı bitirir, parçaları döndürür.
  Future<void> _exit() async {
    if (widget.record) {
      await _recCut();
      if (!mounted) return;
      Navigator.of(context).pop(List<NarrationClip>.of(_clips));
      return;
    }
    Navigator.of(context).pop();
  }

  // ── İkinci ekran ──────────────────────────────────────────────────────────

  Future<void> _toggleSecond() async {
    _wireNative();
    if (_second) {
      await SlidesNative.screenHide();
      _partSetState(() => _second = false);
      return;
    }
    _partSetState(() {
      _second = true;
      _presenter = true; // telefonda notlar
    });
    _syncTick();
    await _pushSecond();
  }

  /// Geçerli slaytı ikinci ekrana basar (slayt değişince).
  Future<void> _pushSecond() async {
    if (!_second) return;
    final slide = widget.slides[_index];
    // Full HD genişlik: TV/projektörde net, bellekte tek kare.
    final png = await SlideSnapshot.toPng(context, slide,
        pixelRatio: 1920 / slide.widthPt);
    if (png == null || !mounted || !_second) return;
    final ok = await SlidesNative.screenShow(png);
    if (!ok && mounted) _partSetState(() => _second = false);
  }

  Future<void> _remoteDispose() async {
    await _nativeSub?.cancel();
    if (_volumeKeys) await SlidesNative.volumeKeys(false);
    if (_second) await SlidesNative.screenHide();
    await _server?.close(force: true);
    if (_recording) await SlidesNative.recordStop();
  }
}

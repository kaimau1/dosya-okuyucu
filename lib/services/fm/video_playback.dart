import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/screen_awake.dart';
import 'floating_video.dart';
import 'media_session.dart';
import 'playback_positions.dart';
import 'thumbnail_cache.dart';

/// **Video oynatma servisi** — oynatıcı artık ekranın değil, uygulamanın.
///
/// Kullanıcı isteği 2026-09-03: *"aynı şeyi videoları oynatırken de yapalım
/// hem bildirim hem ekran altı."*
///
/// ## Niye servis oldu
/// `VideoPlayerController` ekranın `State`inde duruyordu ve `dispose`ta
/// kapatılıyordu: ekrandan çıkan kullanıcı videoyu da kapatmış oluyordu.
/// Ekran altındaki mini çubuğun (ve bildirimin) çalışması için oynatıcının
/// ekrandan UZUN yaşaması gerekiyor — sesin 2026-09-02'de yaşadığı taşınmanın
/// aynısı ([AudioPlayback]).
///
/// ## Pil kararı korunuyor
/// Uygulama arkaya alınınca video **duraklar** (ExoPlayer ekran kapalıyken de
/// kareleri çözer; bir filmde bu telefonun en pahalı pil kaçağıydı). Tek
/// istisna kullanıcının AÇIK isteğidir: bildirimden "Çal"a basmak arka planda
/// dinlemek istediğini söyler ([backgroundAllowed]) ve o oturumda duraklatma
/// devreye girmez.
class VideoPlayback extends ChangeNotifier with WidgetsBindingObserver {
  VideoPlayback._();

  static final VideoPlayback instance = VideoPlayback._();

  /// Test kancası: bildirim/oturum kurulmasın.
  @visibleForTesting
  static bool notificationsEnabled = true;

  VideoPlayerController? _controller;
  VideoPlayerController? get controller => _controller;

  List<String> playlist = const [];
  int index = 0;
  bool loading = false;
  String? error;
  double speed = 1.0;

  /// Bildirimden "Çal"a basıldı: arka planda da çalsın.
  bool backgroundAllowed = false;

  /// Uygulama arkaya alındığı için mi duraklattık? (Kullanıcı duraklattıysa
  /// dönüşte kendiliğinden başlamamalı.)
  bool _pausedByLifecycle = false;

  /// Bu dosya kayıtlı bir konumdan mı başladı? (Ekran "23:10'dan devam
  /// ediliyor" diye kısa bir bilgi gösteriyor; kullanıcı baştan başlamak
  /// isterse tek dokunuşla dönebilsin.)
  Duration? resumedFrom;

  /// Yüzen pencere açıkken uygulama içi oynatıcı susar; kapanınca konum
  /// buradan geri geliyor.
  bool floatingActive = false;

  /// **A-B tekrar** — işaretlenen iki nokta arası sürekli döner.
  ///
  /// Niye (2026-09-04, premium oynatıcı turu): bir dersin/hareketin aynı
  /// yerini defalarca izlemek (dil çalışması, gitar, spor) elle geri sarmakla
  /// yapılıyordu. [loopStart] doluyken [loopEnd] boşsa "A işaretlendi"
  /// demektir; ikisi de doluyken döngü çalışır.
  Duration? loopStart;
  Duration? loopEnd;

  /// Sıradaki A-B dokunuşunun ne yapacağı (arayüz metni için).
  ///
  /// 0 = A işaretle, 1 = B işaretle, 2 = döngüyü kaldır.
  int get loopStage =>
      loopStart == null ? 0 : (loopEnd == null ? 1 : 2);

  /// A → B → kapat sırasıyla ilerler.
  void markLoopPoint() {
    switch (loopStage) {
      case 0:
        loopStart = position;
        loopEnd = null;
      case 1:
        final start = loopStart ?? Duration.zero;
        final here = position;
        // B, A'dan önceyse ikisi yer değiştirir: kullanıcı geri sarıp
        // işaretlemiş olabilir ve "ters aralık" hiçbir şey çalmazdı.
        loopStart = here < start ? here : start;
        loopEnd = here < start ? start : here;
      default:
        loopStart = null;
        loopEnd = null;
    }
    notifyListeners();
  }

  bool _observing = false;
  VoidCallback? _awake;
  Timer? _tick;
  bool _wasPlaying = false;
  String? _cover;

  bool get hasVideo => playlist.isNotEmpty && _controller != null;

  /// Açık dosyanın yolu; hiç yoksa boş.
  String get current => playlist.isEmpty ? '' : playlist[index];

  String get title =>
      current.isEmpty ? '' : p.basenameWithoutExtension(current);

  bool get playing => _controller?.value.isPlaying ?? false;

  Duration get position => _controller?.value.position ?? Duration.zero;

  Duration get duration => _controller?.value.duration ?? Duration.zero;

  /// Bir dosyayı (ve varsa listesini) açar.
  Future<void> open(String path, {List<String> list = const []}) async {
    final next = list.isEmpty ? [path] : [...list];
    var at = next.indexOf(path);
    if (at < 0) {
      next.insert(0, path);
      at = 0;
    }
    playlist = next;
    index = at;
    // Döngü İŞARETLERİ dosyaya aittir: yeni dosyada eski aralık anlamsız
    // (ve çoğu zaman dosyanın süresinden uzun) olurdu.
    loopStart = null;
    loopEnd = null;
    await _load();
  }

  Future<void> _load() async {
    loading = true;
    error = null;
    _cover = null;
    notifyListeners();
    final old = _controller;
    old?.removeListener(_onTick);
    final path = current;
    final controller = VideoPlayerController.file(File(path));
    try {
      await controller.initialize();
      await controller.setPlaybackSpeed(speed);
      // **Kaldığı yerden devam** (kullanıcı isteği 2026-09-03): yarım
      // bırakılan bir filmi baştan açmak oynatıcıların en çok konuşulan
      // eksiği. Kural `PlaybackPositions`ta: ilk 30 sn ve son %5 kaydedilmez.
      final resume = PlaybackPositions.positionOf(path);
      if (resume != null && resume < controller.value.duration) {
        await controller.seekTo(resume);
        resumedFrom = resume;
      } else {
        resumedFrom = null;
      }
      await controller.play();
    } catch (e) {
      await controller.dispose();
      await old?.dispose();
      _controller = null;
      loading = false;
      error = AppStrings.current.t('mp.video_failed', {'error': e});
      notifyListeners();
      return;
    }
    await old?.dispose();
    // Kullanıcı yükleme sürerken başka dosyaya geçtiyse bu sonucu at.
    if (path != current) {
      await controller.dispose();
      return;
    }
    controller.addListener(_onTick);
    _controller = controller;
    loading = false;
    _wasPlaying = true;
    _pausedByLifecycle = false;
    _observe();
    _syncAwake(true);
    _startTicker();
    notifyListeners();
    unawaited(_loadCover(path));
    unawaited(_refreshSession());
  }

  /// Bildirimdeki kapak: videonun ilk karesi (küçük resim önbelleğinden).
  Future<void> _loadCover(String path) async {
    if (!notificationsEnabled) return;
    final thumb = await ThumbnailCache.forVideo(path, size: 512);
    if (path != current) return;
    _cover = thumb;
    unawaited(_refreshSession());
  }

  void _observe() {
    if (_observing) return;
    _observing = true;
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final c = _controller;
    if (c == null) return;
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        // Kullanıcı bildirimden "Çal" dediyse arka planda çalmayı SEÇMİŞTİR.
        if (backgroundAllowed) return;
        if (c.value.isPlaying) {
          _pausedByLifecycle = true;
          unawaited(c.pause());
        }
        _syncAwake(false);
      case AppLifecycleState.resumed:
        if (_pausedByLifecycle) {
          _pausedByLifecycle = false;
          unawaited(c.play());
        }
      case AppLifecycleState.inactive:
        break;
    }
  }

  /// Ekranı açık tutan kilit — yalnız GERÇEKTEN oynarken.
  void _syncAwake(bool wanted) {
    if (wanted == (_awake != null)) return;
    if (wanted) {
      _awake = ScreenAwake.request();
    } else {
      _awake?.call();
      _awake = null;
    }
  }

  void _onTick() {
    final c = _controller;
    if (c == null) return;
    final v = c.value;
    if (v.isPlaying) {
      PlaybackPositions.record(current, v.position, v.duration);
    }
    // A-B tekrar: B'ye gelince A'ya dön. Konum dinleyicisi saniyede birkaç
    // kez geldiği için sıçrama gözle "kesintisiz" görünüyor.
    final end = loopEnd;
    final start = loopStart;
    if (end != null && start != null && v.position >= end) {
      unawaited(seek(start));
      return;
    }
    if (v.position >= v.duration &&
        v.duration > Duration.zero &&
        !v.isPlaying) {
      if (index < playlist.length - 1) {
        unawaited(skip(1));
        return;
      }
    }
    if (v.isPlaying != _wasPlaying) {
      _wasPlaying = v.isPlaying;
      _syncAwake(v.isPlaying);
      if (v.isPlaying) {
        _startTicker();
      } else {
        _stopTicker();
      }
      unawaited(_refreshSession());
      notifyListeners();
    }
  }

  Future<void> skip(int delta) async {
    final next = index + delta;
    if (next < 0 || next >= playlist.length) return;
    index = next;
    notifyListeners();
    await _load();
  }

  Future<void> toggle() async {
    final c = _controller;
    if (c == null) return;
    if (c.value.isPlaying) {
      await c.pause();
    } else {
      await c.play();
    }
    notifyListeners();
  }

  Future<void> seek(Duration target) async {
    final c = _controller;
    if (c == null) return;
    final total = c.value.duration;
    var value = target;
    if (value < Duration.zero) value = Duration.zero;
    if (total > Duration.zero && value > total) value = total;
    await c.seekTo(value);
    await _refreshSession();
  }

  Future<void> seekBy(int seconds) =>
      seek(position + Duration(seconds: seconds));

  Future<void> setSpeed(double value) async {
    speed = value;
    await _controller?.setPlaybackSpeed(value);
    notifyListeners();
  }

  /// Oynatmayı bitirir: oynatıcı kapanır, bildirim kalkar, mini çubuk gider.
  Future<void> close() async {
    _stopTicker();
    _syncAwake(false);
    final c = _controller;
    if (c != null && current.isNotEmpty) {
      PlaybackPositions.record(current, c.value.position, c.value.duration);
      unawaited(PlaybackPositions.save());
    }
    if (floatingActive) {
      floatingActive = false;
      unawaited(FloatingVideo.close());
    }
    _controller = null;
    playlist = const [];
    index = 0;
    loading = false;
    error = null;
    backgroundAllowed = false;
    _cover = null;
    c?.removeListener(_onTick);
    unawaited(c?.dispose());
    await _clearSession();
    notifyListeners();
  }

  /// Bildirimden/kilit ekranından gelen eylem.
  Future<void> handleAction(String action, [int value = 0]) async {
    switch (action) {
      case 'play':
        // Arka plandan gelen açık istek: duraklatma kuralı bu oturumda kalkar.
        backgroundAllowed = true;
        await toggle();
      case 'pause':
        await toggle();
      case 'next':
        await skip(1);
      case 'previous':
        if (position.inSeconds > 3) {
          await seek(Duration.zero);
        } else {
          await skip(-1);
        }
      case 'seek':
        await seek(Duration(milliseconds: value));
      case 'stop':
        await close();
    }
  }

  // ── Ekran üstünde yüzen pencere ────────────────────────────────────────

  /// **Videoyu ekran üstüne al** (kullanıcı isteği 2026-09-03).
  ///
  /// Uygulama içi oynatıcı duraklatılır ve video, başka uygulamaların
  /// üstünde duran küçük bir pencerede AYNI KONUMDAN sürer. İki oynatıcının
  /// aynı anda ses vermesi kullanıcının duyacağı ilk hata olurdu.
  ///
  /// İzin yoksa false döner — çağıran ekranı kullanıcıyı izin ayarına
  /// yönlendiriyor.
  Future<bool> popOut() async {
    if (!hasVideo) return false;
    final path = current;
    final at = position;
    final ok = await FloatingVideo.open(
      path: path,
      position: at,
      title: title,
      subtitle: AppStrings.current.t('mp.float_window'),
    );
    if (!ok) return false;
    floatingActive = true;
    _listenFloating();
    await _controller?.pause();
    // Bildirim/oturum da susmalı: çalan şey artık pencere.
    await _clearSession();
    notifyListeners();
    return true;
  }

  /// Pencere olaylarını bir kez bağlar.
  void _listenFloating() {
    FloatingVideo.setHandler((event, at) {
      floatingActive = false;
      // Pencere kapandı ya da "uygulamaya dön" denildi: konumu al, kaydet
      // ve uygulama içi oynatıcıyı oraya taşı.
      PlaybackPositions.record(current, at, duration);
      unawaited(seek(at));
      if (event == 'expand') unawaited(_controller?.play());
      // Bildirim/oturum geri gelsin: pencereye geçerken susturulmuştu.
      unawaited(_refreshSession());
      notifyListeners();
    });
  }

  /// Uygulama açılırken: pencere biz kapalıyken kapandıysa konumu al.
  Future<void> syncFloating() async {
    _listenFloating();
    final pending = await FloatingVideo.takePending();
    if (pending == null) return;
    floatingActive = false;
    final (_, at) = pending;
    if (current.isNotEmpty) {
      PlaybackPositions.record(current, at, duration);
      await seek(at);
    }
    notifyListeners();
  }

  // ── Medya oturumu ───────────────────────────────────────────────────────

  void _startTicker() {
    _tick?.cancel();
    if (!notificationsEnabled) return;
    _tick = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!playing) return;
      unawaited(_refreshSession());
    });
  }

  void _stopTicker() {
    _tick?.cancel();
    _tick = null;
  }

  Future<void> _refreshSession() async {
    if (!notificationsEnabled) return;
    if (!hasVideo) return _clearSession();
    if (!MediaSession.supported) return;
    final str = AppStrings.current;
    await MediaSession.update(
      title: title,
      subtitle: p.basename(p.dirname(current)),
      position: position,
      duration: duration,
      playing: playing,
      speed: speed,
      hasNext: playlist.length > 1,
      hasPrevious: playlist.length > 1,
      cover: _cover,
      payload: 'video:$current',
      video: true,
      owner: 'video',
      labels: {
        'play': str.t('mp.play'),
        'pause': str.t('mp.pause'),
        'next': str.t('mp.next'),
        'previous': str.t('mp.previous'),
        'stop': str.t('common.close'),
      },
    );
  }

  Future<void> _clearSession() async {
    if (!notificationsEnabled) return;
    await MediaSession.clear(owner: 'video');
  }

  /// Yalnız test: oynatıcıyı ve durumu sıfırlar (tekil nesne testler arasında
  /// yaşıyor; kalan bir denetleyici bir sonraki testin sahte platformuyla
  /// çakışırdı).
  ///
  /// **`await` YOK — bilinçli.** `VideoPlayerController.dispose()` birden çok
  /// asenkron adım içeriyor ve `flutter_test`in sahte saatinde onu beklemek
  /// testi askıda bırakıyor (aynı sınıf tuzak: HAFIZA 2026-07-25 §F). Konum
  /// zamanlayıcısını asıl kapatan `pause()` ve o eşzamanlı iş görüyor;
  /// kapatmanın kalanı arkadan tamamlanır.
  @visibleForTesting
  void debugReset() {
    _stopTicker();
    _syncAwake(false);
    final c = _controller;
    _controller = null;
    playlist = const [];
    index = 0;
    loading = false;
    error = null;
    speed = 1.0;
    backgroundAllowed = false;
    _cover = null;
    _wasPlaying = false;
    resumedFrom = null;
    floatingActive = false;
    loopStart = null;
    loopEnd = null;
    c?.removeListener(_onTick);
    unawaited(c?.pause());
    unawaited(c?.dispose());
  }
}

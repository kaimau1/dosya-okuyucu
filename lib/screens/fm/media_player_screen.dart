import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../models/photo_group.dart';
import '../../core/user_error.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/opensubtitles.dart';
import '../../services/fm/native_extras.dart';
import '../../services/fm/pip.dart';
import '../../services/fm/player_engine.dart';
import '../../services/fm/playback_positions.dart';
import '../../services/fm/subtitles.dart';
import '../../services/fm/thumbnail_cache.dart';
import '../../services/fm/subtitle_delays.dart';
import '../../services/fm/video_playback.dart';
import '../../services/fm/video_transcode.dart';
import '../../services/side_menu.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart' show fmMediaHeroTag;
import '../../widgets/fm/fm_file_image.dart';
import '../../widgets/fm/speed_sheet.dart';
import '../../widgets/mini_player_bar.dart';
import 'entry_actions.dart';
import '../../core/snack.dart';
import 'pick_file_screen.dart';

part 'media_player/actions.dart';
part 'media_player/views.dart';

/// Uygulama içi **video ve ses** oynatıcı.
///
/// Tek ekran ikisini de oynatır: ses dosyasında görüntü katmanı yoktur
/// (`size` boş gelir), onun yerine kapak alanı + dosya adı gösterilir.
/// Oynatma motoru ExoPlayer/Media3 (`video_player`), yani cihazın kendi
/// codec'leri kullanılır — mp4/mkv/webm/mp3/m4a/flac… hepsi sistemin
/// desteklediği ölçüde çalar.
///
/// **Çalma listesi:** aynı klasördeki diğer medya dosyaları verilir; sağa/sola
/// kaydırma ve ileri/geri düğmeleri arasında gezinir, dosya bitince sıradakine
/// geçer.
class MediaPlayerScreen extends StatefulWidget {
  final String path;

  /// Aynı klasördeki medya dosyaları (bu dosya da içinde). Boşsa tek dosya.
  final List<String> playlist;

  /// Rota geçişi siyah arka plan perdesini kendi çiziyorsa (Hero uçuşunda
  /// `saveLayer` olmaması için) `Scaffold` zemini saydam bırakılır.
  final bool externalBackdrop;

  const MediaPlayerScreen({
    super.key,
    required this.path,
    this.playlist = const [],
    this.externalBackdrop = false,
  });

  /// Bu dosyanın oynatıcısı ekrandan çıkınca kapanır mı? (saf, testli)
  /// Video: evet. Ses: hayır — arka planda dinlemek ses için olağan.
  @visibleForTesting
  static bool closesOnExit(String path) =>
      path.isNotEmpty &&
      FsEntry.categoryForExtension(
              p.extension(path).replaceFirst('.', '').toLowerCase()) !=
          FmCategory.audio;

  @override
  State<MediaPlayerScreen> createState() => _MediaPlayerScreenState();
}

class _MediaPlayerScreenState extends State<MediaPlayerScreen> {
  /// **Oynatıcı artık ekranda DEĞİL** (kullanıcı isteği 2026-09-03: *"hem
  /// bildirim hem ekran altı"*). Ekran yalnız servisi izliyor; çıkınca video
  /// (mini çubukta) devam ediyor — sesin 2026-09-02'de yaşadığı taşınmanın
  /// aynısı.
  VideoPlayback get _p => VideoPlayback.instance;

  VideoPlayerController? get _controller => _p.controller;
  List<String> get _playlist => _p.playlist;
  int get _index => _p.index;
  bool get _loading => _pending || _p.loading;
  String? get _error => _pending ? null : _p.error;

  /// Açılış geçişi bitene dek video motoru BAŞLATILMAZ (2026-11-15, kullanıcı:
  /// "videolar animasyonsuz, donarak açılıyor"). Motor kurulumu (özellikle
  /// ExoPlayer → mpv geçişi) ana iş parçacığını kısa süre kilitliyor; geçişin
  /// içinde olunca Hero büyümesi hiç görünmüyordu. Bu sürede ekran kapak
  /// resmini gösterir, yükleme geçişten sonra başlar.
  bool _pending = false;
  double get _speed => _p.speed;

  /// **Videoda çimdik yakınlaştırma** (2026-11-20, kullanıcı: "videolarda da
  /// zoom yapılabilmeli"). İki parmak inince sarma/ses/parlaklık sürüklemeleri
  /// kapanır (yoksa çimdik onlara kaptırılır — galerideki dersin aynısı).
  int _pointers = 0;
  final Map<int, Offset> _pts = {};
  bool get _pinching => _pointers >= 2;
  double _vZoom = 1;
  double _vZoomBase = 1;
  Offset _vPan = Offset.zero;
  final ValueNotifier<Matrix4> _vTransform =
      ValueNotifier<Matrix4>(Matrix4.identity());

  /// Tam oynatıcı açıkken ekran altı mini çubuk gizlenir.
  VoidCallback? _unhideBar;

  VoidCallback? _unhideMenuHandle;
  bool _controlsVisible = true;

  /// Kendiliğinden gizlenirken solma sürüyor (dokunuş almaz).
  bool _controlsFading = false;
  bool _landscape = false;
  Timer? _hideTimer;

  /// **Ekranı doldur** (kırparak) — 20:9 telefonda 16:9 filmin siyah
  /// şeritlerini kaldırır. Varsayılan kapalı: kırpma bir tercihtir, kimsenin
  /// görüntüsü habersiz kesilmemeli.
  bool _zoomFill = false;

  /// **Görüntüyü döndürme** (kullanıcı isteği 2026-11-04: *"videolarda sağa
  /// sola çevir butonu oynatma panelinde"*): yan çekilmiş videolar için
  /// çeyrek tur sayısı (0-3). Yalnız görüntüyü döndürür, dosyaya dokunmaz;
  /// başka dosyaya geçince sıfırlanır.
  int _quarterTurns = 0;

  /// Son dokunuşun zamanı — ikinci dokunuşu (sarma) elle ölçmek için.
  DateTime? _lastTapAt;

  /// Dikey kaydırmayla ayarlanan ses/parlaklık/sarma/boost göstergeleri:
  /// yalnız HUD hapı yeniden kurulur, oynatıcı yüzeyi kurulmaz.
  final ValueNotifier<double?> _volumeHintN = ValueNotifier<double?>(null);
  Timer? _volumeTimer;

  /// Oynatıcının o anki sesi (0-1). `VideoPlayerValue.volume` başlangıçta 1.
  double _volume = 1;

  // ── Faz 18 / G18 jestleri ─────────────────────────────────────────────
  /// Dikey kaydırma ekranın SOL yarısında başladıysa parlaklık, sağda ses.
  bool _dragBrightness = false;

  /// Pencere parlaklığı (0-1); ilk kaydırmada sistemden okunur. Ekrandan
  /// çıkınca sistemin ayarına dönülür (`setBrightness(-1)`).
  double? _brightness;
  final ValueNotifier<double?> _brightnessHintN = ValueNotifier<double?>(null);
  bool _brightnessTouched = false;

  /// Uzun basışta geçici 2× — bırakınca [_speedBeforeBoost]'a döner.
  double? _speedBeforeBoost;
  final ValueNotifier<bool> _boostN = ValueNotifier<bool>(false);

  /// **Kontrol kilidi**: cepte/yatarken yanlış dokunuş videoyu
  /// sarmasın/kapatmasın. Kilitliyken yalnız kilit düğmesi görünür.
  bool _locked = false;
  bool _lockHintVisible = false;
  Timer? _lockTimer;

  /// Yatay kaydırmayla sarma: başlangıç konumu + biriken fark.
  Duration? _scrubFrom;
  double _scrubDx = 0;
  final ValueNotifier<Duration?> _scrubTargetN =
      ValueNotifier<Duration?>(null);

  Animation<double>? _routeAnim;
  AnimationStatusListener? _routeListener;
  Future<bool>? _hdrFuture;

  /// Servis her durum değişiminde haber veriyor; ekran o an yeniden çizilir.
  void _onService() {
    if (!mounted) return;
    setState(() {});
    _p.armAutoPip(true);
    if (_p.playing) _scheduleHide();
    _maybeShowResumeNote();
    // Yeni dosyaya geçildiyse altyazılar da yenilenmeli.
    if (_subtitlesFor != _p.current) {
      _subtitlesFor = _p.current;
      _quarterTurns = 0;
      unawaited(_loadSubtitles());
    }
  }

  /// "Kaldığın yerden devam" bildirimini hangi dosya için gösterdiğimiz.
  String? _resumeNoticeFor;

  /// **Devam bildirimi** (kullanıcı isteği 2026-09-03, premium oynatıcı).
  ///
  /// Sessizce ortadan başlamak kullanıcıyı şaşırtır ("video bozuk mu?");
  /// bir cümle + tek dokunuşluk "baştan başlat" hem haber veriyor hem geri
  /// dönüş yolu bırakıyor.
  void _maybeShowResumeNote() {
    final at = _p.resumedFrom;
    final path = _p.current;
    if (at == null || path.isEmpty || _resumeNoticeFor == path) return;
    _resumeNoticeFor = path;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      showSnack(
        context,
        context.t('mp.resumed_at', {'time': _fmt(at)}),
        action: SnackBarAction(
          label: context.t('mp.restart'),
          onPressed: () {
            PlaybackPositions.clear(path);
            unawaited(_p.seek(Duration.zero));
          },
        ),
      );
    });
  }

  /// Altyazıları en son hangi dosya için yüklediğimiz.
  String? _subtitlesFor;

  /// Şu anki dosyanın yanında bulunan altyazı dosyaları.
  List<SubtitleTrack> _subtitles = const [];

  /// Seçili altyazı yolu; null = kapalı.
  String? _subtitlePath;

  /// Çözülmüş satırlar (seçili altyazınınki).
  List<SubtitleCue> _cues = const [];

  /// Altyazı gecikmesi (ms). Kaynağı farklı bir sürümden indirilmiş altyazı
  /// sesle tutmayabiliyor; kullanıcı ileri/geri kaydırabilsin.
  int _subtitleOffsetMs = 0;

  /// Altyazı punto çarpanı. ponytail: oturum boyu (statik); kalıcı tercih
  /// istenirse `SubtitleDelays` desenine taşınır.
  static double _subtitleScale = 1.0;


  /// Ekranı açık tutan kilit ve uygulama yaşam döngüsü (arkaya alınınca
  /// duraklat) artık **serviste**: oynatma ekrandan uzun yaşadığı için
  /// kararları da onun vermesi gerekiyor (bkz. [VideoPlayback]).

  String get _current => _pending ? widget.path : _p.current;
  bool get _isAudio =>
      FsEntry.categoryForExtension(p.extension(_current).replaceFirst('.', ''))
          == FmCategory.audio;

  @override
  void initState() {
    super.initState();
    _unhideBar = MiniPlayerBar.hide();
    // Video/fotoda yan menü tutamacı çizilmez; kenardan çekme sürer.
    _unhideMenuHandle = SideMenu.instance.hideHandle();
    unawaited(VideoPlayback.loadAutoNext().then((_) {
      if (mounted) setState(() {});
    }));
    _p.addListener(_onService);
    Pip.active.addListener(_onPip);
    _subtitlesFor = widget.path;
    // Aynı dosya zaten açıksa baştan başlatma: kullanıcı mini çubuktan ya da
    // bildirimden ekrana döndüğünde video sıfırlanmamalı.
    if (_p.current != widget.path || _p.controller == null) {
      final isVideo = FsEntry.categoryForExtension(
              p.extension(widget.path).replaceFirst('.', '').toLowerCase()) !=
          FmCategory.audio;
      if (isVideo &&
          Platform.isAndroid &&
          !p.basename(widget.path).toUpperCase().contains('HDR')) {
        // HDR kontrolü initState'te hemen başlar.
        _hdrFuture = VideoTranscoder.isHdr(widget.path);
      }
      if (isVideo) {
        // Video motorunu (ExoPlayer/mpv) açılış geçişi bitince başlat:
        // geçiş sürerken kapak karesi akıcı büyür, native doku kurulumu
        // animasyonu kesmez. Animasyonsuz rotada ya da testte bekleme 0 ms'dir.
        _pending = true;
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _openAfterTransition());
      } else {
        _pending = false;
        unawaited(_p.open(widget.path, list: widget.playlist));
        unawaited(_loadSubtitles());
      }
    } else {
      unawaited(_loadSubtitles());
    }
  }

  void _openAfterTransition() {
    if (!mounted) return;
    final animation = ModalRoute.of(context)?.animation;
    void start() {
      if (!mounted || !_pending) return;
      unawaited(_p.open(widget.path,
          list: widget.playlist, hdrFuture: _hdrFuture));
      setState(() => _pending = false);
      // Altyazı araması da geçişten SONRA: klasör taraması açılış karelerine
      // karışmasın (bkz. [Subtitles.findForAsync]).
      unawaited(_loadSubtitles());
    }

    if (animation == null ||
        animation.isCompleted ||
        Motion.reduced(context)) {
      start();
      return;
    }
    _routeAnim = animation;
    late final AnimationStatusListener listener;
    listener = (status) {
      if (status == AnimationStatus.completed) {
        _stopRouteListener();
        start();
      }
    };
    _routeListener = listener;
    animation.addStatusListener(listener);
  }

  void _stopRouteListener() {
    final l = _routeListener;
    if (l != null) _routeAnim?.removeStatusListener(l);
    _routeListener = null;
    _routeAnim = null;
  }

  @override
  void dispose() {
    _stopRouteListener();
    _unhideBar?.call();
    _unhideMenuHandle?.call();
    _p.removeListener(_onService);
    Pip.active.removeListener(_onPip);
    _p.armAutoPip(false);
    _hideTimer?.cancel();
    _volumeTimer?.cancel();
    _lockTimer?.cancel();
    _vTransform.dispose();
    _volumeHintN.dispose();
    _brightnessHintN.dispose();
    _scrubTargetN.dispose();
    _boostN.dispose();
    if (_brightnessTouched) unawaited(NativeExtras.setBrightness(-1));
    // **Video kapanınca DURUR** (kullanıcı isteği 2026-11-04: *"videolar
    // kapatınca arka planda oynamasın"*). Eskiden ekrandan çıkınca video mini
    // çubukta sesiyle sürüyordu. Ses dosyası (müzik, sesli kitap) bilinçli
    // olarak SÜRER — mini çubuk/bildirim onun için var. Küçük pencerede
    // (PiP) ekran zaten kapanmaz, bu dal oraya uğramaz.
    if (MediaPlayerScreen.closesOnExit(_current) && !Pip.active.value) unawaited(_p.close());
    // Ekranı serbest bırak (tam ekranda yatay kilitlemiş olabiliriz).
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  // ── Altyazı ────────────────────────────────────────────────────────────
  //
  // Video motorunun (`setClosedCaptionFile`) yerine kendi katmanımızı
  // çiziyoruz. Sebep: gecikme ayarı (`_subtitleOffsetMs`) ve punto denetimi
  // motorun API'sinde yok, oysa indirilen altyazının sesle tutmaması en sık
  // karşılaşılan sorun. Zamanlama işini zaten biz yapıyorsak, çizimi de
  // yapmak ek maliyet değil.

  static String _fmt(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }

  void _onPip() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = _controller;
    final value = c?.value;
    // Küçük pencerede (PiP) yalnız görüntü: düğmeler orada okunmaz,
    // dokunuşları sistem kendi denetimleriyle karşılıyor.
    if (Pip.active.value && c != null && value!.isInitialized) {
      return ColoredBox(
        color: AppColors.mediaSurface,
        child: Center(
          child: AspectRatio(
              aspectRatio: value.aspectRatio, child: VideoPlayer(c)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: widget.externalBackdrop && !Motion.reduced(context)
          ? Colors.transparent
          : AppColors.mediaSurface,
      // ÖNEMLİ: üst bar Scaffold'un `appBar` slotuna verilmez. Verilseydi
      // kontroller açılıp kapandıkça body'nin yüksekliği değişir, ortalanmış
      // video her dokunuşta küçülüp kayardı. Bar da alt kontroller gibi
      // Stack'te videonun üstünde yüzer → görüntü hiç oynamaz.
      // Çimdik elle hesaplanır: aynı GestureDetector'da yatay + dikey
      // sürükleme varken ölçek tanıyıcısı YASAK (Flutter onaylamaz).
      body: Listener(
        onPointerDown: _pinchDown,
        onPointerMove: _pinchMove,
        onPointerUp: (e) => _pinchUp(e.pointer),
        onPointerCancel: (e) => _pinchUp(e.pointer),
        child: GestureDetector(
        // Videonun yanındaki siyah boşluklarda da dokunma çalışsın diye
        // opaque: varsayılan `deferToChild` ile yalnız görüntünün kendisi
        // dokunmayı yakalıyordu.
        behavior: HitTestBehavior.opaque,
        // **Çift dokunuş = sarma** (kullanıcı isteği 2026-09-03, premium
        // oynatıcı): solda 10 sn geri, sağda 10 sn ileri, ortada dokunuş
        // yine kontrolleri açıp kapatıyor.
        //
        // **`onDoubleTap` KULLANILMIYOR — bilinçli.** Aynı ağaçta bir çift
        // dokunuş tanıyıcısı varken TEK dokunuş, çift dokunuş süresi
        // (~300 ms) dolana kadar BEKLETİLİR: kontroller geç açılıyor ve
        // altındaki oynat/duraklat düğmesi bile gecikiyordu (iki widget
        // testi bunu yakaladı). Onun yerine ikinci dokunuş elle ölçülüyor —
        // her dokunuş anında iş görüyor. İki dokunuş kontrolleri iki kez
        // çevirdiği için görüntü de yerinde kalıyor (aç-kapa = değişmedi).
        onTapUp: _locked ? (_) => _showLockHint() : _handleTap,
        // **Yatay kaydırma** (Faz 18): yavaş sürükleme SARAR (zaman balonu),
        // hızlı fiske çalma listesinde önceki/sonraki dosyaya geçer.
        onHorizontalDragStart: _locked || _pinching || _isAudio ? null : _scrubStart,
        onHorizontalDragUpdate: _locked || _pinching || _isAudio ? null : _scrubUpdate,
        onHorizontalDragEnd: _locked || _pinching
            ? null
            : (details) {
                final v = details.primaryVelocity ?? 0;
                if (_scrubFrom != null && _scrubDx.abs() >= 40) {
                  _scrubCommit();
                  return;
                }
                _scrubCancel();
                if (v < -250) _skip(1);
                if (v > 250) _skip(-1);
              },
        // **Dikey kaydırma**: sağ yarıda ses (oynatıcının kendi sesi), sol
        // yarıda pencere parlaklığı (Faz 18). Gösterge kaydırma boyunca.
        onVerticalDragStart: _locked || _pinching || _isAudio
            ? null
            : (d) => _dragBrightness = d.localPosition.dx <
                MediaQuery.sizeOf(context).width / 2,
        onVerticalDragUpdate: _locked || _pinching || _isAudio
            ? null
            : (d) => _dragBrightness
                ? _handleBrightnessDrag(d)
                : _handleVolumeDrag(d),
        onVerticalDragEnd: (_) => _hideVolumeSoon(),
        // **Uzun basış = 2× hız** (bırakınca eski hız).
        onLongPressStart: _locked || _pinching || _isAudio ? null : (_) => _boostStart(),
        onLongPressEnd: _locked || _pinching || _isAudio ? null : (_) => _boostEnd(),
        child: Stack(
          children: [
            Positioned.fill(
              child: ClipRect(
                child: ValueListenableBuilder<Matrix4>(
                  valueListenable: _vTransform,
                  builder: (_, m, child) => Transform(
                    transform: m,
                    alignment: Alignment.center,
                    child: child,
                  ),
                  child: _surface(c, value),
                ),
              ),
            ),
            // Altyazı katmanı: konum saniyede iki kez değişiyor, yeniden
            // çizilen alan BURAYA hapsediliyor (bkz. [_onTick] notu).
            // Kontroller açıkken yukarı kaçar ki alttaki çubuk metni örtmesin.
            if (c != null && _cues.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                bottom: _controlsVisible ? 140 : 32,
                child: ValueListenableBuilder<VideoPlayerValue>(
                  valueListenable: c,
                  builder: (_, live, _) => _captionLayer(live.position),
                ),
              ),
            Positioned(
              left: 0,
              right: 0,
              top: 80,
              child: IgnorePointer(
                child: ListenableBuilder(
                  listenable: Listenable.merge([
                    _volumeHintN,
                    _brightnessHintN,
                    _scrubTargetN,
                    _boostN,
                  ]),
                  builder: (_, _) {
                    final vol = _volumeHintN.value;
                    if (vol != null) return _volumeBadge(vol);
                    final bri = _brightnessHintN.value;
                    if (bri != null) return _brightnessBadge(bri);
                    final scrub = _scrubTargetN.value;
                    if (scrub != null || _boostN.value) {
                      return _gestureBubble(scrub);
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            if (!_isAudio && _locked && _lockHintVisible)
              PositionedDirectional(
                start: Gap.md,
                top: 0,
                bottom: 0,
                child: Center(child: _lockButton()),
              ),
            if (_controlsVisible && !_locked)
              Positioned.fill(
                child: _fade(
                  Stack(
                    children: [
                      if (!_isAudio)
                        PositionedDirectional(
                          start: Gap.md,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _lockButton()),
                        ),
                      if (!_isAudio)
                        PositionedDirectional(
                          end: Gap.md,
                          top: 0,
                          bottom: 0,
                          child: Center(child: _rotateButtons()),
                        ),
                      if (!_isAudio)
                        PositionedDirectional(
                          end: Gap.md,
                          bottom: MediaQuery.paddingOf(context).bottom + 136,
                          child: _autoNextButton(),
                        ),
                      Positioned(left: 0, right: 0, top: 0, child: _topBar()),
                      if (c != null && value != null)
                        Positioned(
                          left: 0,
                          right: 0,
                          bottom: 0,
                          // Konum çubuğu saniyede iki kez değişir; yeniden çizilen
                          // alanı BURAYA hapsediyoruz (bkz. [_onTick]).
                          child: ValueListenableBuilder<VideoPlayerValue>(
                            valueListenable: c,
                            builder: (_, live, _) => _controls(c, live),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }

  void _pinchDown(PointerDownEvent e) {
    final before = _pinching;
    _pts[e.pointer] = e.localPosition;
    _pointers = _pts.length;
    if (_pinching) _pinchStart();
    if (before != _pinching) setState(() {});
  }

  /// İlk iki parmağın aralığı ve orta noktası.
  (double, Offset) _span() {
    final v = _pts.values.take(2).toList();
    return ((v[0] - v[1]).distance, (v[0] + v[1]) / 2);
  }

  double _spanStart = 1;
  Offset _focalLast = Offset.zero;

  void _pinchStart() {
    final (span, focal) = _span();
    _spanStart = span <= 0 ? 1 : span;
    _focalLast = focal;
    _vZoomBase = _vZoom;
  }

  void _updateVideoTransform() {
    _vTransform.value = Matrix4.identity()
      ..translateByDouble(_vPan.dx, _vPan.dy, 0, 1)
      ..scaleByDouble(_vZoom, _vZoom, 1, 1);
  }

  void _pinchMove(PointerMoveEvent e) {
    if (!_pts.containsKey(e.pointer)) return;
    _pts[e.pointer] = e.localPosition;
    if (!_pinching || _locked || _isAudio) return;
    final (span, focal) = _span();
    _vZoom = (_vZoomBase * span / _spanStart).clamp(1.0, 5.0);
    final size = MediaQuery.sizeOf(context);
    final mx = size.width * (_vZoom - 1) / 2;
    final my = size.height * (_vZoom - 1) / 2;
    final next = _vZoom <= 1.0 ? Offset.zero : _vPan + (focal - _focalLast);
    _vPan = Offset(next.dx.clamp(-mx, mx), next.dy.clamp(-my, my));
    _updateVideoTransform();
    _focalLast = focal;
  }

  void _pinchUp(int pointer) {
    final before = _pinching;
    _pts.remove(pointer);
    _pointers = _pts.length;
    if (_pinching) _pinchStart();
    if (_vZoom < 1.05) {
      _vZoom = 1;
      _vPan = Offset.zero;
      _updateVideoTransform();
    }
    if (before != _pinching) setState(() {});
  }


  static final _controlsRouteCurve =
      CurveTween(curve: const Interval(0.32, 1.0, curve: Curves.easeOut));

  /// Kontrol katmanı: solarken saydamlaşır ve dokunuş almaz. Görünürken
  /// opaklık 1 → katman açılmaz; yalnız solma ve açılış geçişi süresince.
  Widget _fade(Widget child) {
    Widget body = IgnorePointer(
      ignoring: _controlsFading,
      child: AnimatedOpacity(
        opacity: _controlsFading ? 0 : 1,
        duration: Motion.of(context, Motion.long),
        curve: Motion.exit,
        child: child,
      ),
    );
    final routeAnim = ModalRoute.of(context)?.animation;
    if (routeAnim != null && !Motion.reduced(context)) {
      body = FadeTransition(
        opacity: routeAnim.drive(_controlsRouteCurve),
        child: body,
      );
    }
    return body;
  }

  /// Izgaranın çözdüğü küçük resim (önbellekte ise) — açılış kapağı.
  /// Yalnız [_current] için; yol değişince yeniden bakılır.
  String? _posterPath;
  FmFileImage? _poster;
  double? _aspect;

  void _syncPoster() {
    final path = _current;
    if (_posterPath == path) return;
    _posterPath = path;
    _poster = null;
    _aspect = null;
    if (path.isEmpty) return;
    // Izgaranın çözdüğü boy, son üretilenden farklı olabilir: bilinen bütün
    // boylara bakılır, en-boy oranı hazır olan ilk kapak alınır (yoksa
    // büyüme geçişi kurulamıyor, video "donup" geçişsiz açılıyordu).
    for (final thumb in ThumbnailCache.allKnownVideo(path)) {
      final cached = fmCachedThumb(thumb);
      if (cached == null) continue;
      final aspect = fmCachedAspect(cached);
      _poster ??= cached;
      if (aspect != null) {
        _poster = cached;
        _aspect = aspect;
        return;
      }
    }
  }

  FmFileImage? get _posterImage {
    _syncPoster();
    return _poster;
  }

  double? get _posterAspect {
    _syncPoster();
    return _aspect;
  }

  /// Başlık altı tarih — dosya başına bir kez (eşzamansız) `stat`.
  String? _momentPath;
  String? _moment;

  String? _momentOf(String path) {
    if (path.isEmpty) return null;
    if (_momentPath != path) {
      _momentPath = path;
      _moment = null;
      File(path).lastModified().then((d) {
        final ms = d.millisecondsSinceEpoch;
        if (!mounted || _momentPath != path || ms <= 0) return;
        setState(() => _moment = photoMomentTitle(ms));
      }, onError: (Object _) {});
    }
    return _moment;
  }

  /// Parça dosyalarındaki uzantılar `setState`i (korumalı) buradan çağırır.
  void _partSetState(VoidCallback fn) => setState(fn);
}

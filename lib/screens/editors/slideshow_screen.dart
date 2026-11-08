import 'dart:async';
import 'dart:io';
import 'dart:math' show Random;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../services/pptx/pro/pptx_package.dart';
import '../../services/pptx/pro/pptx_show_info.dart';
import '../../services/pptx/pro/slides_native.dart';
import '../../services/pptx_render.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/slide_canvas.dart';
import '../../widgets/slide_snapshot.dart';
import '../../core/theme.dart';

part 'slideshow/actions.dart';
part 'slideshow/ink.dart';
part 'slideshow/media.dart';
part 'slideshow/presenter.dart';
part 'slideshow/remote.dart';

/// Tam ekran sunum modu — PowerPoint'in "Slayt Gösterisi"nin karşılığı.
/// Yatay + tam ekran, kaydırarak veya sağ/sol yarıya dokunarak geçiş,
/// parmakla veya çift dokunarak yakınlaştırma. İleri giderken slaydın
/// geçişi (`p:transition`: Soldur / İt / Sil) oynar (Faz 29b); parmakla
/// kaydırmada sayfa kaydırmanın kendisi geçiştir.
///
/// Faz 38: araç çubuğu (lazer işaretçi, kalem, zamanlayıcı), ses/video
/// oynatma, klavye/sunum kumandası (ok, PageUp/PageDown, boşluk).
class SlideshowScreen extends StatefulWidget {
  final List<SlideVM> slides;
  final int initialIndex;

  /// Her slaytın konuşmacı notu (aynı sıra; boş = not yok). Verilirse sunum
  /// sırasında "Notlar" düğmesi alt panelde gösterir (sunucu görünümü).
  final List<String> notes;

  /// Faz 38: destenin kaydedilmiş baytı + gösterilen her slaytın destedeki
  /// sırası (medya, bağlantı, sayaç için; izolatta okunur). null → eski yol.
  final Uint8List? deck;
  final List<int> deckIndex;

  const SlideshowScreen({
    super.key,
    required this.slides,
    this.initialIndex = 0,
    this.notes = const [],
    this.deck,
    this.deckIndex = const [],
    this.presenter = false,
    this.record = false,
  });

  /// Anlatım kaydı (madde 9): her slayt ayrı kaydedilir; çıkışta
  /// `List<NarrationClip>` döner.
  final bool record;

  /// Sunucu görünümünde başla (madde 5).
  final bool presenter;

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

/// Dokunma kipi: normal (ileri/geri), lazer işaretçi, kalem.
enum _Tool { none, laser, pen }

class _SlideshowScreenState extends State<SlideshowScreen>
    with SingleTickerProviderStateMixin {
  /// Giriş geçişinin ilerleyişi (1 = bitti; açılışta da 1).
  late final AnimationController _enter;

  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  final TransformationController _zoom = TransformationController();
  late int _index = widget.initialIndex;
  bool _zoomed = false;

  /// Konuşmacı notu paneli açık mı?
  bool _showNotes = false;

  // ── Faz 38 ────────────────────────────────────────────────────────────────
  final FocusNode _focus = FocusNode(debugLabel: 'slideshow');
  bool _toolsOpen = false;
  _Tool _tool = _Tool.none;
  int _penColor = 0;
  final Map<int, List<_Stroke>> _ink = {};
  final ValueNotifier<int> _inkRev = ValueNotifier(0);
  final ValueNotifier<Offset?> _laser = ValueNotifier(null);

  /// Sunum süresi: kronometre hep sayar; ekrandaki saat yalnız görünürken
  /// saniyede bir güncellenir (boşta kare yok — anayasa k.6).
  final Stopwatch _clock = Stopwatch();
  bool _showTimer = false;

  /// Siyah/beyaz ekran (PowerPoint B/W): slayt gizlenir, dokunuş ya da tuş
  /// sunuma döner. null = kapalı.
  Color? _blank;
  Timer? _tick;
  final ValueNotifier<int> _seconds = ValueNotifier(0);

  /// Destenin sunum bilgisi (medya …), izolatta okunur; gelene dek boş.
  List<SlideShowInfo> _info = const [];
  _MediaPlay? _media;

  /// Sunucu görünümü (madde 5): slayt solda; not + sonraki slayt + süre sağda.
  late bool _presenter = widget.presenter;

  /// Slayt sahnesinin ölçüsü (sunucu görünümünde ekrandan dar).
  Size _stageSize = Size.zero;

  /// Canlı sayaçlar (geçerli slayt): kalan saniye, duraklatıldı mı.
  final Map<int, int> _counterLeft = {};
  final Map<int, bool> _counterPaused = {};
  final ValueNotifier<int> _counterRev = ValueNotifier(0);
  Timer? _counterTick;

  // ── Madde 9: kumanda, anlatım, ikinci ekran ───────────────────────────────
  StreamSubscription<(String, Object?)>? _nativeSub;
  bool _volumeKeys = false;
  HttpServer? _server;
  String? _remoteUrl;
  int _screens = 0;
  bool _second = false;
  bool _recording = false;
  int? _recSlide;
  final Stopwatch _recClock = Stopwatch();
  final List<NarrationClip> _clips = [];

  /// Otomatik ilerleme (`advTm`, ör. kayıtlı anlatım) — tek seferlik zamanlayıcı.
  Timer? _auto;

  String get _note =>
      _index < widget.notes.length ? widget.notes[_index].trim() : '';

  /// Geçerli slaytta kaçıncı animasyon adımındayız (0 = sadece sabit içerik).
  int _step = 0;

  int get _maxStep => widget.slides[_index].steps.length;

  SlideShowInfo? get _curInfo {
    final i = _index < widget.deckIndex.length ? widget.deckIndex[_index] : -1;
    return i >= 0 && i < _info.length ? _info[i] : null;
  }

  /// İleri: önce slaydın animasyon adımları biter, sonra sonraki slayda geçilir.
  void _forward() {
    if (_step < _maxStep) {
      setState(() => _step++);
    } else {
      _go(1);
    }
  }

  void _backward() {
    if (_step > 0) {
      setState(() => _step--);
    } else {
      _go(-1);
    }
  }

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
        vsync: this, duration: Motion.long, value: 1);
    _clock.start();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    if (_presenter) _syncTick();
    unawaited(SlidesNative.screens().then((n) {
      if (mounted && n > 0) setState(() => _screens = n);
    }));
    if (widget.record) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _recStart());
    }
    final deck = widget.deck;
    if (deck != null) {
      // Açılışı beklemez; bilgi gelince medya/bağlantı etkinleşir.
      unawaited(PptxPro.query(deck, PptxShowInfo.read).then((v) {
        if (!mounted) return;
        setState(() => _info = v);
        _scheduleAdvance();
        _startCounters();
        _autoPlayMedia();
      }, onError: (_) {}));
    }
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _tick?.cancel();
    _auto?.cancel();
    _counterTick?.cancel();
    _counterRev.dispose();
    unawaited(_remoteDispose());
    _media?.dispose();
    _pages.dispose();
    _zoom.dispose();
    _enter.dispose();
    _focus.dispose();
    _inkRev.dispose();
    _laser.dispose();
    _seconds.dispose();
    super.dispose();
  }

  void _go(int delta) => _goTo(_index + delta);

  void _goTo(int next) {
    final delta = next - _index;
    if (next < 0 || next >= widget.slides.length || delta == 0) return;
    if (delta > 0 &&
        widget.slides[next].transition != null &&
        !Motion.reduced(context)) {
      // Geçişli slayt: sayfa kaydırması yerine yerinde giriş efekti.
      _pages.jumpToPage(next);
      _enter.forward(from: 0);
      return;
    }
    if (delta.abs() > 1) {
      _pages.jumpToPage(next);
      return;
    }
    Motion.toPage(context, _pages, next);
  }

  void _onPage(int i) {
    _resetZoom();
    _stopMedia();
    _laser.value = null;
    setState(() {
      _index = i;
      _step = 0;
    });
    _scheduleAdvance();
    _startCounters();
    _autoPlayMedia();
    unawaited(_recOnPage());
    unawaited(_pushSecond());
  }

  void _scheduleAdvance() {
    _auto?.cancel();
    _auto = null;
    final ms = _curInfo?.advanceMs;
    if (ms == null || ms <= 0) return;
    _auto = Timer(Duration(milliseconds: ms), () {
      if (!mounted || _tool != _Tool.none) return;
      // Animasyon adımları da tek tek ilerler (PowerPoint'in otomatik akışı).
      if (_step < _maxStep) {
        setState(() => _step = _maxStep);
      }
      if (_index < widget.slides.length - 1) _go(1);
    });
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final k = e.logicalKey;
    if (_blank != null) {
      setState(() => _blank = null);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyB || k == LogicalKeyboardKey.period) {
      setState(() => _blank = AppColors.mediaSurface);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyW || k == LogicalKeyboardKey.comma) {
      setState(() => _blank = AppColors.page);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.keyG) {
      unawaited(_showAllSlides());
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowRight ||
        k == LogicalKeyboardKey.arrowDown ||
        k == LogicalKeyboardKey.pageDown ||
        k == LogicalKeyboardKey.space ||
        k == LogicalKeyboardKey.enter ||
        k == LogicalKeyboardKey.mediaTrackNext) {
      _forward();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.arrowLeft ||
        k == LogicalKeyboardKey.arrowUp ||
        k == LogicalKeyboardKey.pageUp ||
        k == LogicalKeyboardKey.backspace ||
        k == LogicalKeyboardKey.mediaTrackPrevious) {
      _backward();
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home) {
      _goTo(0);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.end) {
      _goTo(widget.slides.length - 1);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _toggleTimer() {
    setState(() => _showTimer = !_showTimer);
    _syncTick();
  }

  /// Saniye vuruşu yalnız saat görünürken (çip ya da sunucu görünümü).
  void _syncTick() {
    _tick?.cancel();
    _tick = null;
    if (_showTimer || _presenter) {
      _seconds.value = _clock.elapsed.inSeconds;
      _tick = Timer.periodic(const Duration(seconds: 1), (_) {
        _seconds.value = _clock.elapsed.inSeconds;
      });
    }
  }

  void _toggleClockRun() {
    setState(() => _clock.isRunning ? _clock.stop() : _clock.start());
  }

  void _resetClock() {
    _clock.reset();
    _seconds.value = 0;
  }

  static String clock(int s) {
    final h = s ~/ 3600, m = (s ~/ 60) % 60, ss = s % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '$h:${two(m)}:${two(ss)}' : '${two(m)}:${two(ss)}';
  }

  /// Slaytın ekrandaki dikdörtgeni (FittedBox.contain, ortalı).
  static Rect slideRect(Size screen, SlideVM s) {
    final k = (screen.width / s.widthPt) < (screen.height / s.heightPt)
        ? screen.width / s.widthPt
        : screen.height / s.heightPt;
    final w = s.widthPt * k, h = s.heightPt * k;
    return Rect.fromLTWH(
        (screen.width - w) / 2, (screen.height - h) / 2, w, h);
  }

  /// Ekran noktası → slayt punto koordinatı (slayt dışında null).
  Offset? _toSlide(Offset p) {
    final size = _stageSize;
    if (size.isEmpty) return null;
    final s = widget.slides[_index];
    final r = slideRect(size, s);
    if (!r.contains(p)) return null;
    return Offset((p.dx - r.left) / r.width * s.widthPt,
        (p.dy - r.top) / r.height * s.heightPt);
  }

  void _resetZoom() {
    _zoom.value = Matrix4.identity();
    if (_zoomed) setState(() => _zoomed = false);
  }

  void _toggleZoom(Offset pos) {
    if (_zoomed) {
      _resetZoom();
      return;
    }
    const scale = 2.5;
    _zoom.value = Matrix4.identity()
      ..translateByDouble(-pos.dx * (scale - 1), -pos.dy * (scale - 1), 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
    setState(() => _zoomed = true);
  }

  void _onTapUp(TapUpDetails d) {
    if (_zoomed) return;
    final at = _toSlide(d.localPosition);
    final info = _curInfo;
    if (at != null && _hitLink(at)) return;
    if (at != null && info != null) {
      for (final m in info.media) {
        if (Rect.fromLTWH(m.x, m.y, m.w, m.h).contains(at)) {
          unawaited(_playMedia(m));
          return;
        }
      }
    }
    final w = _stageSize.width;
    if (d.localPosition.dx > w * 0.6) {
      _forward();
    } else if (d.localPosition.dx < w * 0.4) {
      _backward();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stage = LayoutBuilder(builder: (context, box) {
      _stageSize = box.biggest;
      return _stage();
    });
    return PopScope(
      canPop: !widget.record,
      onPopInvokedWithResult: (did, _) {
        if (!did) unawaited(_exit());
      },
      child: Focus(
      focusNode: _focus,
      autofocus: true,
      onKeyEvent: _onKey,
      child: Scaffold(
        backgroundColor: AppColors.mediaSurface,
        body: _presenter
            ? Row(children: [
                Expanded(child: stage),
                SizedBox(
                  width: MediaQuery.sizeOf(context).width * 0.36,
                  child: _presenterPanel(),
                ),
              ])
            : stage,
      ),
    ));
  }

  Widget _stage() {
    final drawing = _tool != _Tool.none;
    return Stack(
        children: [
          PageView.builder(
            controller: _pages,
            // Komşu slaytlar önceden kurulup çizilir (sonraki slayt hazır).
            allowImplicitScrolling: true,
            itemCount: widget.slides.length,
            // Yakınlaştırılmışken (ya da kalem/lazer açıkken) sayfa kaydırma
            // kapanır, parmak çizer/gezdirir.
            physics: _zoomed || drawing
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: _onPage,
            itemBuilder: (_, i) => _page(widget.slides[i], i),
          ),
          // Kalem mürekkebi + lazer: slaytın üstünde tek boyacı.
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _InkPainter(
                    strokes: _ink[_index] ?? const [],
                    rev: _inkRev,
                    laser: _laser,
                    area: (size) => slideRect(size, widget.slides[_index]),
                  ),
                ),
              ),
            ),
          ),
          // Dokunma katmanı PageView'ın üstünde: tek dokunuş ileri/geri,
          // çift dokunuş yakınlaştırır. Parmakla kaydırma/pinch alta geçer.
          // Kalem/lazer kipinde parmak hareketi yakalanır.
          Positioned.fill(
            child: drawing
                ? GestureDetector(
                    key: const ValueKey('ss-ink-layer'),
                    behavior: HitTestBehavior.opaque,
                    onPanStart: (d) => _inkStart(d.localPosition),
                    onPanUpdate: (d) => _inkMove(d.localPosition),
                    onPanEnd: (_) => _inkEnd(),
                    onTapUp: (d) {
                      if (_tool == _Tool.laser) _laser.value = null;
                    },
                  )
                : GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onDoubleTapDown: (d) => _toggleZoom(d.localPosition),
                    onDoubleTap: () {}, // onDoubleTapDown'ın çalışması için gerekli
                    onTapUp: _onTapUp,
                  ),
          ),
          ..._counterOverlays(),
          if (_media != null) _mediaOverlay(_media!),
          if (_blank != null)
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('ss-blank'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _blank = null),
                child: ColoredBox(color: _blank!),
              ),
            ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(AppIcons.close, color: AppColors.onMediaSoft),
                tooltip: context.t('ss.exit'),
                onPressed: _exit,
              ),
            ),
          ),
          PositionedDirectional(
            top: 8,
            start: 8,
            child: SafeArea(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                if (widget.notes.any((n) => n.trim().isNotEmpty))
                  IconButton(
                    key: const ValueKey('ss-notes'),
                    isSelected: _showNotes,
                    icon: Icon(AppIcons.notes,
                        color: _showNotes
                            ? AppColors.onMedia
                            : AppColors.onMediaSoft),
                    tooltip: context.t('sl.notes_toggle'),
                    onPressed: () => setState(() => _showNotes = !_showNotes),
                  ),
                IconButton(
                  key: const ValueKey('ss-tools'),
                  isSelected: _toolsOpen,
                  icon: Icon(AppIcons.draw,
                      color: _toolsOpen
                          ? AppColors.onMedia
                          : AppColors.onMediaSoft),
                  tooltip: context.t('ss.tools'),
                  onPressed: () => setState(() {
                    _toolsOpen = !_toolsOpen;
                    if (!_toolsOpen) _tool = _Tool.none;
                  }),
                ),
                IconButton(
                  key: const ValueKey('ss-presenter'),
                  isSelected: _presenter,
                  icon: Icon(AppIcons.chromeReaderMode,
                      color: _presenter
                          ? AppColors.onMedia
                          : AppColors.onMediaSoft),
                  tooltip: context.t('ss.presenter'),
                  onPressed: () {
                    setState(() => _presenter = !_presenter);
                    _syncTick();
                  },
                ),
                if (_showTimer && !_presenter) _timerChip(),
                if (_recording)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: Icon(AppIcons.micNone,
                        key: ValueKey('ss-rec'), color: AppHues.red),
                  ),
              ]),
            ),
          ),
          if (_remoteUrl != null)
            Positioned(
              top: 8,
              left: 0,
              right: 0,
              child: SafeArea(
                child: Center(
                  child: Container(
                    key: const ValueKey('ss-web-url'),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.mediaChrome,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: SelectableText(_remoteUrl!,
                        style: context.type.small.copyWith(color: AppColors.onMedia)),
                  ),
                ),
              ),
            ),
          if (_toolsOpen)
            Positioned(
              left: 0,
              right: 0,
              bottom: 44,
              child: SafeArea(top: false, child: Center(child: _toolbar())),
            ),
          if (_showNotes && _note.isNotEmpty && !_presenter)
            Positioned(
              left: 0,
              right: 0,
              bottom: _toolsOpen ? 100 : 40,
              child: SafeArea(
                top: false,
                child: Container(
                  key: const ValueKey('ss-notes-panel'),
                  constraints: BoxConstraints(
                      maxHeight: MediaQuery.sizeOf(context).height * 0.35),
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.mediaChrome,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _note,
                      style: Theme.of(context)
                          .textTheme
                          .bodyLarge
                          ?.copyWith(color: AppColors.onMedia, height: 1.4),
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.mediaScrim,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: GestureDetector(
                  key: const ValueKey('ss-counter'),
                  onTap: () => unawaited(_showAllSlides()),
                  child: Text(
                  _maxStep == 0
                      ? '${_index + 1} / ${widget.slides.length}'
                      : context.t('ss.step', {
                          'n': _index + 1,
                          'total': widget.slides.length,
                          'step': _step,
                          'max': _maxStep,
                        }),
                  style: context.type.small.copyWith(color: AppColors.onMediaSoft),
                ),
                ),
              ),
            ),
          ),
        ],
      );
  }

  Widget _timerChip() => GestureDetector(
        key: const ValueKey('ss-timer'),
        onTap: _toggleClockRun,
        onLongPress: _resetClock,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.mediaScrim,
            borderRadius: BorderRadius.circular(12),
          ),
          child: ValueListenableBuilder<int>(
            valueListenable: _seconds,
            builder: (_, s, _) => Text(
              clock(s),
              style: context.type.body.copyWith(
                  color: _clock.isRunning
                      ? AppColors.onMedia
                      : AppColors.onMediaFaint,
                  fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
        ),
      );

  Widget _toolButton(IconData icon, String tip, bool on, VoidCallback onTap,
          {Key? key, Color? color}) =>
      IconButton(
        key: key,
        tooltip: tip,
        isSelected: on,
        onPressed: onTap,
        icon: Icon(icon,
            color: color ?? (on ? AppColors.onMedia : AppColors.onMediaSoft)),
        style: IconButton.styleFrom(
            backgroundColor: on ? AppColors.onMediaWell : null),
      );

  Widget _toolbar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.mediaChrome,
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _toolButton(AppIcons.chevronLeft, context.t('ss.prev'), false, _backward),
          _toolButton(AppIcons.pointer, context.t('ss.laser'), _tool == _Tool.laser,
              () => setState(() {
                    _tool = _tool == _Tool.laser ? _Tool.none : _Tool.laser;
                    _laser.value = null;
                  }),
              key: const ValueKey('ss-laser')),
          _toolButton(AppIcons.draw, context.t('ss.pen'), _tool == _Tool.pen,
              () => setState(() => _tool = _tool == _Tool.pen ? _Tool.none : _Tool.pen),
              key: const ValueKey('ss-pen')),
          if (_tool == _Tool.pen) ...[
            for (var i = 0; i < _penColors.length; i++)
              _toolButton(AppIcons.circle, context.t('ss.pen_color'), _penColor == i,
                  () => setState(() => _penColor = i),
                  color: _penColors[i]),
            _toolButton(AppIcons.eraser, context.t('ss.clear_ink'), false, _clearInk,
                key: const ValueKey('ss-clear-ink')),
          ],
          _toolButton(AppIcons.slidesGrid, context.t('ss.all_slides'), false,
              () => unawaited(_showAllSlides()),
              key: const ValueKey('ss-grid')),
          _toolButton(AppIcons.blankScreen, context.t('ss.blank_black'), false,
              () => setState(() => _blank = AppColors.mediaSurface),
              key: const ValueKey('ss-black')),
          _toolButton(AppIcons.brightness, context.t('ss.blank_white'), false,
              () => setState(() => _blank = AppColors.page),
              key: const ValueKey('ss-white')),
          _toolButton(AppIcons.schedule, context.t('ss.timer'), _showTimer, _toggleTimer,
              key: const ValueKey('ss-timer-toggle')),
          _toolButton(AppIcons.volumeUp, context.t('ss.volume_keys'), _volumeKeys,
              () => unawaited(_toggleVolumeKeys()),
              key: const ValueKey('ss-volume')),
          _toolButton(AppIcons.wifi, context.t('ss.web_remote'), _server != null,
              () => unawaited(_toggleWebRemote()),
              key: const ValueKey('ss-web')),
          if (_screens > 0)
            _toolButton(AppIcons.phonelink, context.t('ss.second_screen'), _second,
                () => unawaited(_toggleSecond()),
                key: const ValueKey('ss-second')),
          _toolButton(AppIcons.chevron, context.t('ss.next'), false, _forward),
        ]),
      ),
    );
  }

  Widget _page(SlideVM slide, int i) {
    return InteractiveViewer(
      transformationController: i == _index ? _zoom : null,
      minScale: 1,
      maxScale: 6,
      panEnabled: _tool == _Tool.none,
      scaleEnabled: _tool == _Tool.none,
      onInteractionEnd: (_) {
        final scale = _zoom.value.getMaxScaleOnAxis();
        if ((scale > 1.02) != _zoomed) setState(() => _zoomed = scale > 1.02);
      },
      child: Center(
        child: RepaintBoundary(
          child: i != _index || slide.transition == null
              ? SlideCanvas(slide: slide, step: i == _index ? _step : 0)
              : AnimatedBuilder(
                  animation: _enter,
                  child: SlideCanvas(slide: slide, step: _step),
                  builder: (_, child) => _enter.value >= 1
                      ? child!
                      : KeyedSubtree(
                          key: const ValueKey('ss-transition'),
                          child: _transition(slide, _enter.value, child!),
                        ),
                ),
        ),
      ),
    );
  }

  /// Slaytın giriş efekti ([t] 0→1).
  static Widget _transition(SlideVM slide, double t, Widget child) {
    final rest = 1 - Curves.easeOutCubic.transform(t);
    final dir = slide.transitionDir;
    switch (slide.transition) {
      case 'push':
        return FractionalTranslation(
          translation: switch (dir) {
            'r' => Offset(-rest, 0),
            'u' => Offset(0, rest),
            'd' => Offset(0, -rest),
            _ => Offset(rest, 0),
          },
          child: child,
        );
      case 'wipe':
        final f = (1 - rest).clamp(0.001, 1.0);
        final vertical = dir == 'u' || dir == 'd';
        // Silme yönü SLAYTIN kendi yönüdür (`p:wipe@dir`), arayüz dilinin
        // değil: Arapça arayüzde de aynalanmaz — bu yüzden fiziksel hiza.
        return ClipRect(
          child: Align(
            alignment: switch (dir) {
              'r' => const Alignment(-1, 0),
              'u' => Alignment.bottomCenter,
              'd' => Alignment.topCenter,
              _ => const Alignment(1, 0),
            },
            widthFactor: vertical ? 1 : f,
            heightFactor: vertical ? f : 1,
            child: child,
          ),
        );
      default:
        return Opacity(opacity: (1 - rest).clamp(0.0, 1.0), child: child);
    }
  }

  void _partSetState(VoidCallback f) {
    if (mounted) setState(f);
  }
}

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../services/pptx_render.dart';
import '../../widgets/slide_canvas.dart';
import '../../core/theme.dart';

/// Tam ekran sunum modu — PowerPoint'in "Slayt Gösterisi"nin karşılığı.
/// Yatay + tam ekran, kaydırarak veya sağ/sol yarıya dokunarak geçiş,
/// parmakla veya çift dokunarak yakınlaştırma. İleri giderken slaydın
/// geçişi (`p:transition`: Soldur / İt / Sil) oynar (Faz 29b); parmakla
/// kaydırmada sayfa kaydırmanın kendisi geçiştir.
class SlideshowScreen extends StatefulWidget {
  final List<SlideVM> slides;
  final int initialIndex;

  /// Her slaytın konuşmacı notu (aynı sıra; boş = not yok). Verilirse sunum
  /// sırasında "Notlar" düğmesi alt panelde gösterir (sunucu görünümü).
  final List<String> notes;

  const SlideshowScreen({
    super.key,
    required this.slides,
    this.initialIndex = 0,
    this.notes = const [],
  });

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

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

  String get _note =>
      _index < widget.notes.length ? widget.notes[_index].trim() : '';

  /// Geçerli slaytta kaçıncı animasyon adımındayız (0 = sadece sabit içerik).
  int _step = 0;

  int get _maxStep => widget.slides[_index].steps.length;

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
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }

  @override
  void dispose() {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    _pages.dispose();
    _zoom.dispose();
    _enter.dispose();
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.slides.length) return;
    if (delta > 0 &&
        widget.slides[next].transition != null &&
        !Motion.reduced(context)) {
      // Geçişli slayt: sayfa kaydırması yerine yerinde giriş efekti.
      _pages.jumpToPage(next);
      _enter.forward(from: 0);
      return;
    }
    Motion.toPage(context, _pages, next);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.mediaSurface,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pages,
            itemCount: widget.slides.length,
            // Yakınlaştırılmışken sayfa kaydırma kapanır, parmak kaydırma
            // görüntüyü gezdirir.
            physics: _zoomed
                ? const NeverScrollableScrollPhysics()
                : const PageScrollPhysics(),
            onPageChanged: (i) {
              _resetZoom();
              setState(() {
                _index = i;
                _step = 0;
              });
            },
            itemBuilder: (_, i) => _page(widget.slides[i], i),
          ),
          // Dokunma katmanı PageView'ın üstünde: tek dokunuş ileri/geri,
          // çift dokunuş yakınlaştırır. Parmakla kaydırma/pinch alta geçer.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onDoubleTapDown: (d) => _toggleZoom(d.localPosition),
              onDoubleTap: () {}, // onDoubleTapDown'ın çalışması için gerekli
              onTapUp: (d) {
                if (_zoomed) return;
                final w = context.size?.width ?? 0;
                if (d.localPosition.dx > w * 0.6) {
                  _forward();
                } else if (d.localPosition.dx < w * 0.4) {
                  _backward();
                }
              },
            ),
          ),
          PositionedDirectional(
            top: 8,
            end: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(AppIcons.close, color: AppColors.onMediaSoft),
                tooltip: context.t('ss.exit'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          if (widget.notes.any((n) => n.trim().isNotEmpty))
            PositionedDirectional(
              top: 8,
              start: 8,
              child: SafeArea(
                child: IconButton(
                  key: const ValueKey('ss-notes'),
                  isSelected: _showNotes,
                  icon: Icon(AppIcons.notes,
                      color: _showNotes
                          ? AppColors.onMedia
                          : AppColors.onMediaSoft),
                  tooltip: context.t('sl.notes_toggle'),
                  onPressed: () => setState(() => _showNotes = !_showNotes),
                ),
              ),
            ),
          if (_showNotes && _note.isNotEmpty)
            Positioned(
              left: 0,
              right: 0,
              bottom: 40,
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
        ],
      ),
    );
  }

  Widget _page(SlideVM slide, int i) {
    return InteractiveViewer(
      transformationController: i == _index ? _zoom : null,
      minScale: 1,
      maxScale: 6,
      onInteractionEnd: (_) {
        final scale = _zoom.value.getMaxScaleOnAxis();
        if ((scale > 1.02) != _zoomed) setState(() => _zoomed = scale > 1.02);
      },
      child: Center(
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
    );
  }
}

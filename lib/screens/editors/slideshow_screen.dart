import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/pptx_render.dart';
import '../../widgets/slide_canvas.dart';

/// Tam ekran sunum modu — PowerPoint'in "Slayt Gösterisi"nin karşılığı.
/// Yatay + tam ekran, kaydırarak veya sağ/sol yarıya dokunarak geçiş,
/// parmakla veya çift dokunarak yakınlaştırma.
class SlideshowScreen extends StatefulWidget {
  final List<SlideVM> slides;
  final int initialIndex;
  const SlideshowScreen({
    super.key,
    required this.slides,
    this.initialIndex = 0,
  });

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> {
  late final PageController _pages =
      PageController(initialPage: widget.initialIndex);
  final TransformationController _zoom = TransformationController();
  late int _index = widget.initialIndex;
  bool _zoomed = false;

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
    super.dispose();
  }

  void _go(int delta) {
    final next = _index + delta;
    if (next < 0 || next >= widget.slides.length) return;
    _pages.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
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
      ..translate(-pos.dx * (scale - 1), -pos.dy * (scale - 1))
      ..scale(scale);
    setState(() => _zoomed = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
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
          Positioned(
            top: 8,
            right: 8,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white70),
                tooltip: 'Çık',
                onPressed: () => Navigator.of(context).pop(),
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
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _maxStep == 0
                      ? '${_index + 1} / ${widget.slides.length}'
                      : '${_index + 1} / ${widget.slides.length}  ·  adım $_step/$_maxStep',
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
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
        child: SlideCanvas(slide: slide, step: i == _index ? _step : 0),
      ),
    );
  }
}

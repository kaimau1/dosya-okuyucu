part of '../slideshow_screen.dart';

/// Kalem renkleri (sunumda mürekkep — içerik rengi).
const _penColors = <Color>[
  AppHues.red,
  AppHues.amber,
  AppHues.blue,
  AppHues.green,
  AppColors.onMedia,
];

/// Bir kalem çizgisi: noktalar SLAYT oranında (0..1) — döndürme/boyut
/// değişince de slaytın aynı yerinde kalır.
class _Stroke {
  final Color color;
  final List<Offset> points = [];
  _Stroke(this.color);
}

/// **Faz 38 / madde 4 — lazer işaretçi + kalem.** Mürekkep slayt başına
/// bellekte tutulur (dosyaya yazılmaz); tek [CustomPainter], yalnız
/// [_inkRev]/[_laser] değişince yeniden çizer.
extension _SlideshowInk on _SlideshowScreenState {
  Offset? _norm(Offset p) {
    final size = _stageSize;
    if (size.isEmpty) return null;
    final r = _SlideshowScreenState.slideRect(size, widget.slides[_index]);
    return Offset(((p.dx - r.left) / r.width).clamp(0.0, 1.0),
        ((p.dy - r.top) / r.height).clamp(0.0, 1.0));
  }

  void _inkStart(Offset p) {
    if (_tool == _Tool.laser) {
      _laser.value = _norm(p);
      return;
    }
    final n = _norm(p);
    if (n == null) return;
    final stroke = _Stroke(_penColors[_penColor])..points.add(n);
    final list = _ink[_index];
    if (list == null) {
      // Yeni liste boyacıya ancak yeniden kurulumla ulaşır.
      _partSetState(() => _ink[_index] = [stroke]);
    } else {
      list.add(stroke);
      _inkRev.value++;
    }
  }

  void _inkMove(Offset p) {
    if (_tool == _Tool.laser) {
      _laser.value = _norm(p);
      return;
    }
    final list = _ink[_index];
    final n = _norm(p);
    if (list == null || list.isEmpty || n == null) return;
    list.last.points.add(n);
    _inkRev.value++;
  }

  void _inkEnd() {
    if (_tool == _Tool.laser) _laser.value = null;
  }

  void _clearInk() {
    _ink.remove(_index);
    _inkRev.value++;
    _partSetState(() {});
  }
}

class _InkPainter extends CustomPainter {
  final List<_Stroke> strokes;
  final ValueNotifier<Offset?> laser;
  final Rect Function(Size) area;
  _InkPainter({
    required this.strokes,
    required ValueNotifier<int> rev,
    required this.laser,
    required this.area,
  }) : super(repaint: Listenable.merge([rev, laser]));

  @override
  void paint(Canvas canvas, Size size) {
    final r = area(size);
    Offset at(Offset n) => Offset(r.left + n.dx * r.width, r.top + n.dy * r.height);
    final w = r.width / 240; // ~4 dp telefonda
    for (final s in strokes) {
      final paint = Paint()
        ..color = s.color
        ..strokeWidth = w.clamp(2.0, 8.0)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (s.points.length == 1) {
        canvas.drawCircle(at(s.points.first), paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(at(s.points.first).dx, at(s.points.first).dy);
      for (final p in s.points.skip(1)) {
        final q = at(p);
        path.lineTo(q.dx, q.dy);
      }
      canvas.drawPath(path, paint);
    }
    final l = laser.value;
    if (l != null) {
      final c = at(l);
      canvas.drawCircle(
          c,
          14,
          Paint()
            ..color = AppHues.red.withValues(alpha: 0.35)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
      canvas.drawCircle(c, 6, Paint()..color = AppHues.red);
    }
  }

  @override
  bool shouldRepaint(_InkPainter old) => old.strokes != strokes;
}

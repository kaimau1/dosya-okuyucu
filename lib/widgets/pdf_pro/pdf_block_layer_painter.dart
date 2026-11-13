part of 'pdf_block_layer.dart';

/// Düzenleme katmanının boyayıcısı: blok kılavuzları, seçim çerçevesi,
/// tutamaçlar, işaretleme önizlemesi ve yazma kipinin imleci/seçimi.
class _LayerPainter extends CustomPainter {
  _LayerPainter({
    required this.rects,
    required this.locked,
    required this.selected,
    required this.accent,
    required this.pending,
    required this.px,
    required this.drag,
    required this.widthDrag,
    required this.itemRect,
    required this.itemScale,
    required this.itemGrip,
    required this.onAccent,
    required this.movable,
    required this.annotRect,
    required this.live,
    required this.toWidget,
    required this.caretOn,
    required this.stroke,
    required this.strokeColor,
    required this.strokeWidth,
    required this.markFrom,
    required this.markTo,
    required this.markRects,
    required this.shape,
  }) : super(repaint: caretOn);

  final List<Rect> rects;
  final List<bool> locked;
  final int? selected;
  final Color accent, pending, strokeColor, onAccent;
  final Offset? itemGrip;
  final bool movable;
  final double px, widthDrag, itemScale, strokeWidth;
  final Offset drag;
  final Rect? itemRect, annotRect;
  final PdfLiveEdit? live;
  final Offset Function(double x, double y) toWidget;
  final ValueNotifier<bool> caretOn;
  final List<Offset> stroke;
  final Offset? markFrom, markTo;
  final List<Rect> markRects;
  final PdfMarkupKind? shape;

  void _dashed(Canvas canvas, Rect r, Paint paint) {
    final dash = 5 * px, gap = 3 * px;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      if (len <= 0) return;
      final dir = (b - a) / len;
      for (var d = 0.0; d < len; d += dash + gap) {
        canvas.drawLine(a + dir * d, a + dir * math.min(len, d + dash), paint);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  /// Taşıma tutamacı: dolu daire + dört yön oku.
  void _moveGrip(Canvas canvas, Offset at) {
    final rad = PdfEditTokens.grip / 2 * px;
    canvas.drawCircle(at, rad, Paint()..color = accent);
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * px
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = onAccent;
    final arm = rad * 0.58, head = rad * 0.24;
    for (final d in const [
      Offset(1, 0),
      Offset(-1, 0),
      Offset(0, 1),
      Offset(0, -1)
    ]) {
      final tip = at + d * arm;
      final side = Offset(d.dy, d.dx) * head;
      canvas
        ..drawLine(at, tip, p)
        ..drawLine(tip, tip - d * head + side, p)
        ..drawLine(tip, tip - d * head - side, p);
    }
  }

  /// **Bu boyayıcı dokunuşu YUTMAZ** (sınıf açıklamasındaki kök neden;
  /// `CustomPainter.hitTest` null dönerse `CustomPaint` her dokunuşu yutar).
  @override
  bool hitTest(Offset position) => false;

  void _selection(Canvas canvas, Rect r) {
    canvas.drawRect(
        r, Paint()..color = accent.withValues(alpha: PdfEditTokens.frameFillAlpha));
    canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = PdfEditTokens.frameActiveWidth * px
          ..color = accent);
    final handle = Paint()..color = accent;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(c, PdfEditTokens.handle / 2 * px, handle);
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final idle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PdfEditTokens.frameIdleWidth * px
      ..color = accent.withValues(alpha: PdfEditTokens.frameIdleAlpha);
    final lockPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PdfEditTokens.frameIdleWidth * px
      ..color = pending;
    for (var i = 0; i < rects.length; i++) {
      if (i == selected) continue;
      final r = rects[i].inflate(2 * px);
      if (i < locked.length && locked[i]) {
        _dashed(canvas, r, lockPaint);
      } else {
        canvas.drawRect(r, idle);
      }
    }
    final s = selected;
    if (s != null && s < rects.length) {
      final base = rects[s].inflate(2 * px).shift(drag);
      final r = Rect.fromLTRB(
          base.left, base.top, base.right + widthDrag, base.bottom);
      _selection(canvas, r);
      // Genişlik tutamacı (sağ kenarın ortası).
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(
                  center: r.centerRight, width: 6 * px, height: 22 * px),
              Radius.circular(3 * px)),
          Paint()..color = accent);
      if (movable) _moveGrip(canvas, r.topCenter);
    }
    final ir = itemRect;
    if (ir != null) {
      final r = Rect.fromLTWH(ir.left + drag.dx, ir.top + drag.dy,
          ir.width * itemScale, ir.height * itemScale);
      _selection(canvas, r);
      final g = itemGrip;
      if (g != null && itemScale == 1) _moveGrip(canvas, g + drag);
    }
    final ar = annotRect;
    if (ar != null) {
      _dashed(
          canvas,
          ar.inflate(3 * px),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameActiveWidth * px
            ..color = accent);
    }

    // İşaretleme önizlemesi.
    if (markRects.isNotEmpty) {
      final p = Paint()..color = strokeColor.withValues(alpha: 0.35);
      for (final r in markRects) {
        canvas.drawRect(r, p);
      }
    }
    if (stroke.length > 1) {
      final path = Path()..moveTo(stroke.first.dx, stroke.first.dy);
      for (final o in stroke.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = strokeWidth
            ..color = strokeColor);
    }
    final a = markFrom, b = markTo;
    if (shape != null && a != null && b != null) {
      final p = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..color = strokeColor;
      switch (shape!) {
        case PdfMarkupKind.ellipse:
          canvas.drawOval(Rect.fromPoints(a, b), p);
        case PdfMarkupKind.line || PdfMarkupKind.arrow:
          canvas.drawLine(a, b, p);
        case PdfMarkupKind.redact:
          canvas.drawRect(Rect.fromPoints(a, b),
              Paint()..color = strokeColor.withValues(alpha: 0.6));
        default:
          canvas.drawRect(Rect.fromPoints(a, b), p);
      }
    }

    // Yazma kipi: seçim, bileşim alt çizgisi, imleç.
    final l = live;
    if (l == null) return;
    final map = l.map;
    final lo = math.min(l.selStart, l.selEnd), hi = math.max(l.selStart, l.selEnd);
    if (hi > lo) {
      final p = Paint()
        ..color = accent.withValues(alpha: PdfEditTokens.textSelectionAlpha);
      for (final q in map.selection(lo, hi)) {
        canvas.drawPath(
            Path()
              ..addPolygon([
                toWidget(q[0], q[1]),
                toWidget(q[2], q[3]),
                toWidget(q[4], q[5]),
                toWidget(q[6], q[7]),
              ], true),
            p);
      }
    }
    if (l.composeStart >= 0 && l.composeEnd > l.composeStart) {
      final p = Paint()
        ..strokeWidth = 1.5 * px
        ..color = accent;
      for (final q in map.selection(l.composeStart, l.composeEnd)) {
        canvas.drawLine(toWidget(q[0], q[1]), toWidget(q[2], q[3]), p);
      }
    }
    if (hi == lo && caretOn.value) {
      final (x0, y0, x1, y1) = map.caret(lo);
      canvas.drawLine(
          toWidget(x0, y0),
          toWidget(x1, y1),
          Paint()
            ..strokeWidth = 2 * px
            ..strokeCap = StrokeCap.round
            ..color = l.error == null ? accent : pending);
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) => true;
}

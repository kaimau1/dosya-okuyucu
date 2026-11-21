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
    required this.itemRect,
    required this.itemGrip,
    required this.groupRects,
    required this.onAccent,
    required this.movable,
    required this.annotRect,
    required this.live,
    required this.toWidget,
    required this.caretOn,
  }) : super(repaint: caretOn);

  final List<Rect> rects;
  final List<bool> locked;
  final int? selected;
  final Color accent, pending, onAccent;
  final Offset? itemGrip;
  final bool movable;
  final double px;
  final Rect? itemRect, annotRect;

  /// Çoklu seçimin üyeleri (Faz 59 m.5); boşsa tekli seçim.
  final List<Rect> groupRects;
  final PdfLiveEdit? live;
  final Offset Function(double x, double y) toWidget;
  final ValueNotifier<bool> caretOn;

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

  void _moveGrip(Canvas canvas, Offset at) =>
      _paintMoveGrip(canvas, at, accent, onAccent, px);

  /// **Bu boyayıcı dokunuşu YUTMAZ** (sınıf açıklamasındaki kök neden;
  /// `CustomPainter.hitTest` null dönerse `CustomPaint` her dokunuşu yutar).
  @override
  bool hitTest(Offset position) => false;

  void _selection(Canvas canvas, Rect r) =>
      _paintSelection(canvas, r, accent, px);

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
      final r = rects[s].inflate(2 * px);
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
    if (ir != null) _selection(canvas, ir);
    for (final r in groupRects) {
      _dashed(
          canvas,
          r.inflate(2 * px),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameActiveWidth * px
            ..color = accent);
    }
    // Tekli nesnenin ya da grubun taşıma tutamacı.
    final g = itemGrip;
    if (g != null) _moveGrip(canvas, g);
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

/// Seçim çerçevesi: hafif dolgu, kontur, dört köşe tutamacı.
void _paintSelection(Canvas canvas, Rect r, Color accent, double px) {
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

/// Taşıma tutamacı: dolu daire + dört yön oku.
void _paintMoveGrip(
    Canvas canvas, Offset at, Color accent, Color onAccent, double px) {
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

/// Sürükleme önizlemesi (taşı / genişlet / ölçekle). **Kasma kuralı:**
/// sürükleme sırasında yalnız bu boyayıcı yeniden çizilir — katman yeniden
/// kurulmaz, öteki blok kılavuzları boyanmaz ([_DragPainter] `repaint`).
class _DragPreview extends ChangeNotifier {
  /// Sürüklenen çerçeve (katman pikseli); null = sürükleme yok.
  Rect? frame;
  List<Rect> members = const [];
  /// Taşıma tutamacının çerçevenin üst ortasına göre yeri; null = çizilmez.
  Offset? grip;
  PdfSnapTargets? targets;

  Offset _raw = Offset.zero;
  Offset drag = Offset.zero;
  double width = 0, scale = 1;
  PdfSnap snap = PdfSnap.none;

  void begin(Rect frame,
      {List<Rect> members = const [], Offset? grip, PdfSnapTargets? targets}) {
    this.frame = frame;
    this.members = members;
    this.grip = grip;
    this.targets = targets;
    _raw = Offset.zero;
    drag = Offset.zero;
    width = 0;
    scale = 1;
    snap = PdfSnap.none;
    notifyListeners();
  }

  /// Taşıma: ham kayma + tutunma. Kılavuz yeni belirdiyse true (titreşim).
  bool move(Offset delta) {
    _raw += delta;
    final f = frame, t = targets;
    final hadGuide = snap.xs.isNotEmpty || snap.ys.isNotEmpty;
    snap = f == null || t == null ? PdfSnap(_raw, const [], const []) : t.snap(f, _raw);
    drag = snap.offset;
    notifyListeners();
    return !hadGuide && (snap.xs.isNotEmpty || snap.ys.isNotEmpty);
  }

  void widen(double dx) {
    width += dx;
    notifyListeners();
  }

  void resize(double s) {
    scale = s;
    notifyListeners();
  }

  void end() {
    frame = null;
    members = const [];
    grip = null;
    targets = null;
    snap = PdfSnap.none;
    notifyListeners();
  }
}

class _DragPainter extends CustomPainter {
  _DragPainter(this.preview,
      {required this.accent, required this.onAccent, required this.px})
      : super(repaint: preview);

  final _DragPreview preview;
  final Color accent, onAccent;
  final double px;

  @override
  bool hitTest(Offset position) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final f = preview.frame;
    if (f == null) return;
    final d = preview.drag, s = preview.scale;
    final guide = Paint()
      ..strokeWidth = 1 * px
      ..color = accent;
    for (final x in preview.snap.xs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
    }
    for (final y in preview.snap.ys) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    final member = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PdfEditTokens.frameActiveWidth * px
      ..color = accent;
    for (final m in preview.members) {
      canvas.drawRect(m.inflate(2 * px).shift(d), member);
    }
    final r = Rect.fromLTWH(f.left + d.dx, f.top + d.dy,
        f.width * s + preview.width, f.height * s);
    _paintSelection(canvas, r, accent, px);
    final g = preview.grip;
    if (g != null && s == 1) {
      _paintMoveGrip(canvas, r.topCenter + g, accent, onAccent, px);
    }
  }

  @override
  bool shouldRepaint(_DragPainter old) =>
      old.preview != preview || old.accent != accent || old.px != px;
}

/// Çizim önizlemesi (vurgu sürüklemesi, kalem, şekil, kement). **Kasma
/// kuralı:** çizerken yalnız [_MarkPainter] yeniden boyanır — katman
/// kurulmaz, sayfanın öteki kılavuzları boyanmaz.
class _MarkPreview extends ChangeNotifier {
  Offset? from, to;

  /// Serbest çizimin noktaları (katman pikseli).
  final List<Offset> points = [];

  /// Noktaların kalem basıncı ([pdfPressureOf]; -1 = bilgi yok).
  final List<double> pressures = [];
  double get factor => pdfPressureFactor(pressures);

  void begin(Offset at, double pressure) {
    from = at;
    to = at;
    points
      ..clear()
      ..add(at);
    pressures
      ..clear()
      ..add(pressure);
    notifyListeners();
  }

  void extend(Offset at, double pressure, {required bool keep}) {
    to = at;
    if (keep) {
      points.add(at);
      pressures.add(pressure);
    }
    notifyListeners();
  }

  void clear() {
    if (from == null && points.isEmpty) return;
    from = null;
    to = null;
    points.clear();
    pressures.clear();
    notifyListeners();
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter(this.preview,
      {required this.color,
      required this.width,
      required this.shape,
      required this.textRects})
      : super(repaint: preview);

  final _MarkPreview preview;
  final Color color;
  final double width;
  final PdfMarkupKind? shape;

  /// Metin üstü işaretlemede sürüklenen aralığın satır kutuları.
  final List<Rect> Function(Offset from, Offset to)? textRects;

  @override
  bool hitTest(Offset position) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final a = preview.from, b = preview.to;
    if (a == null || b == null) return;
    final rects = textRects;
    if (rects != null) {
      final p = Paint()..color = color.withValues(alpha: 0.35);
      for (final r in rects(a, b)) {
        canvas.drawRect(r, p);
      }
    }
    final pts = preview.points;
    if (pts.length > 1) {
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final o in pts.skip(1)) {
        path.lineTo(o.dx, o.dy);
      }
      canvas.drawPath(
          path,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = width * preview.factor
            ..color = color);
    }
    final s = shape;
    if (s == null) return;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..color = color;
    switch (s) {
      case PdfMarkupKind.ellipse:
        canvas.drawOval(Rect.fromPoints(a, b), p);
      case PdfMarkupKind.line || PdfMarkupKind.arrow:
        canvas.drawLine(a, b, p);
      case PdfMarkupKind.redact:
        canvas.drawRect(
            Rect.fromPoints(a, b), Paint()..color = color.withValues(alpha: 0.6));
      default:
        canvas.drawRect(Rect.fromPoints(a, b), p);
    }
  }

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.preview != preview ||
      old.color != color ||
      old.width != width ||
      old.shape != shape ||
      (old.textRects == null) != (textRects == null);
}
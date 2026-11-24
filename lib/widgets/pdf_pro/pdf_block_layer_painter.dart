part of 'pdf_block_layer.dart';

/// Görsel/nesne ölçeklemede tutulan köşe.
enum _ScaleCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Düzenleme katmanının boyayıcısı: blok kılavuzları, seçilebilir görsel/şekil
/// çerçeveleri, seçim tutamaçları ve yazma kipinin imleci/seçimi.
class _LayerPainter extends CustomPainter {
  _LayerPainter({
    required this.rects,
    required this.locked,
    required this.selected,
    required this.itemRects,
    required this.itemIsImage,
    required this.selectedItemPos,
    required this.selectedItemIsImage,
    required this.imageAccent,
    required this.shapeAccent,
    required this.badgeImageLabel,
    required this.badgeShapeLabel,
    required this.accent,
    required this.pending,
    required this.px,
    required this.pageSize,
    required this.itemRect,
    required this.itemGrip,
    required this.groupRects,
    required this.onAccent,
    required this.movable,
    required this.annotRect,
    required PdfLiveEdit? live,
    required this.toWidget,
    required this.caretOn,
  })  : liveMap = live?.map,
        liveSelStart = live?.selStart ?? 0,
        liveSelEnd = live?.selEnd ?? 0,
        liveComposeStart = live?.composeStart ?? -1,
        liveComposeEnd = live?.composeEnd ?? -1,
        liveHasError = live?.error != null,
        super(repaint: caretOn);

  final List<Rect> rects;
  final List<bool> locked;
  final int? selected;

  /// Görsel kipinde sayfadaki TÜM seçilebilir görsel/şekiller (sıfır tahmin).
  final List<Rect> itemRects;
  final List<bool> itemIsImage;
  final int? selectedItemPos;
  final bool? selectedItemIsImage;
  final Color imageAccent, shapeAccent;
  final String badgeImageLabel, badgeShapeLabel;

  final Color accent, pending, onAccent;
  final Offset? itemGrip;
  final bool movable;
  final double px;
  final Size pageSize;
  final Rect? itemRect, annotRect;

  /// Çoklu seçimin üyeleri (Faz 59 m.5); boşsa tekli seçim.
  final List<Rect> groupRects;
  final PdfBlockTextMap? liveMap;
  final int liveSelStart, liveSelEnd, liveComposeStart, liveComposeEnd;
  final bool liveHasError;
  final Offset Function(double x, double y) toWidget;
  final ValueNotifier<bool> caretOn;

  void _addDashedRect(Path path, Rect r, {double dash = 5, double gap = 3}) {
    final dLen = dash * px, gLen = gap * px;
    void line(Offset a, Offset b) {
      final len = (b - a).distance;
      if (len <= 0) return;
      final inv = 1 / len;
      final ux = (b.dx - a.dx) * inv, uy = (b.dy - a.dy) * inv;
      for (var d = 0.0; d < len; d += dLen + gLen) {
        final e = math.min(len, d + dLen);
        path
          ..moveTo(a.dx + ux * d, a.dy + uy * d)
          ..lineTo(a.dx + ux * e, a.dy + uy * e);
      }
    }

    line(r.topLeft, r.topRight);
    line(r.topRight, r.bottomRight);
    line(r.bottomRight, r.bottomLeft);
    line(r.bottomLeft, r.topLeft);
  }

  /// Köşe L-braketleri: seçilebilir görsel/şekli metinden anında ayırır.
  void _addCornerBrackets(Path path, Rect r) {
    final arm = math.min(11 * px, math.min(r.width, r.height) * 0.28);
    if (arm < 3 * px) return;
    path
      ..moveTo(r.left, r.top + arm)
      ..lineTo(r.left, r.top)
      ..lineTo(r.left + arm, r.top)
      ..moveTo(r.right - arm, r.top)
      ..lineTo(r.right, r.top)
      ..lineTo(r.right, r.top + arm)
      ..moveTo(r.right, r.bottom - arm)
      ..lineTo(r.right, r.bottom)
      ..lineTo(r.right - arm, r.bottom)
      ..moveTo(r.left + arm, r.bottom)
      ..lineTo(r.left, r.bottom)
      ..lineTo(r.left, r.bottom - arm);
  }

  void _moveGrip(Canvas canvas, Offset at, {Color? color}) =>
      _paintMoveGrip(canvas, at, color ?? accent, onAccent, px);

  /// **Bu boyayıcı dokunuşu YUTMAZ** (sınıf açıklamasındaki kök neden;
  /// `CustomPainter.hitTest` null dönerse `CustomPaint` her dokunuşu yutar).
  @override
  bool hitTest(Offset position) => false;

  void _selection(Canvas canvas, Rect r,
          {bool corners = true, Color? color}) =>
      _paintSelection(canvas, r, color ?? accent, onAccent, px,
          corners: corners);

  @override
  void paint(Canvas canvas, Size size) {
    assert(() {
      PdfProBlockLayer.debugPaints++;
      return true;
    }());
    // ── 1 · Metin blokları (düzenlenebilir vs kilitli) ──
    if (rects.isNotEmpty) {
      Path? idlePath;
      Path? idleFill;
      Path? lockPath;
      Path? lockFill;
      final radius = Radius.circular(3.5 * px);
      for (var i = 0; i < rects.length; i++) {
        if (i == selected) continue;
        final r = rects[i].inflate(2 * px);
        final rr = RRect.fromRectAndRadius(r, radius);
        if (i < locked.length && locked[i]) {
          (lockFill ??= Path()).addRRect(rr);
          _addDashedRect(lockPath ??= Path(), r);
        } else {
          (idleFill ??= Path()).addRRect(rr);
          (idlePath ??= Path()).addRRect(rr);
        }
      }
      if (idleFill != null) {
        canvas.drawPath(
          idleFill,
          Paint()
            ..color =
                accent.withValues(alpha: PdfEditTokens.frameIdleFillAlpha),
        );
      }
      if (idlePath != null) {
        canvas.drawPath(
          idlePath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameIdleWidth * px
            ..color = accent.withValues(alpha: PdfEditTokens.frameIdleAlpha),
        );
      }
      if (lockFill != null) {
        canvas.drawPath(
          lockFill,
          Paint()
            ..color =
                pending.withValues(alpha: PdfEditTokens.frameLockedFillAlpha),
        );
      }
      if (lockPath != null) {
        canvas.drawPath(
          lockPath,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameIdleWidth * px
            ..color = pending.withValues(alpha: 0.78),
        );
      }
    }

    // ── 2 · Seçilebilir görsel & şekil keşif çerçeveleri (Görsel kipi) ──
    if (itemRects.isNotEmpty) {
      Path? imgFill, imgDash, imgCorners;
      Path? shpFill, shpDash, shpCorners;
      final radius = Radius.circular(4 * px);
      for (var i = 0; i < itemRects.length; i++) {
        if (i == selectedItemPos) continue;
        final r = itemRects[i].inflate(1.5 * px);
        final isImg = i < itemIsImage.length && itemIsImage[i];
        final rr = RRect.fromRectAndRadius(r, radius);
        if (isImg) {
          (imgFill ??= Path()).addRRect(rr);
          _addDashedRect(imgDash ??= Path(), r, dash: 6, gap: 4);
          _addCornerBrackets(imgCorners ??= Path(), r);
        } else {
          (shpFill ??= Path()).addRRect(rr);
          _addDashedRect(shpDash ??= Path(), r, dash: 5, gap: 4);
          _addCornerBrackets(shpCorners ??= Path(), r);
        }
      }
      if (imgFill != null) {
        canvas.drawPath(
          imgFill,
          Paint()
            ..color = imageAccent
                .withValues(alpha: PdfEditTokens.objectIdleFillAlpha),
        );
      }
      if (imgDash != null) {
        canvas.drawPath(
          imgDash,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4 * px
            ..color =
                imageAccent.withValues(alpha: PdfEditTokens.objectIdleAlpha),
        );
      }
      if (imgCorners != null) {
        canvas.drawPath(
          imgCorners,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 2.4 * px
            ..color = imageAccent,
        );
      }
      if (shpFill != null) {
        canvas.drawPath(
          shpFill,
          Paint()
            ..color = shapeAccent
                .withValues(alpha: PdfEditTokens.objectIdleFillAlpha),
        );
      }
      if (shpDash != null) {
        canvas.drawPath(
          shpDash,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.3 * px
            ..color =
                shapeAccent.withValues(alpha: PdfEditTokens.objectIdleAlpha),
        );
      }
      if (shpCorners != null) {
        canvas.drawPath(
          shpCorners,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round
            ..strokeWidth = 2.2 * px
            ..color = shapeAccent,
        );
      }
      // Yeterince büyük görsellerin/şekillerin sol-üstüne mini tür rozeti.
      for (var i = 0; i < itemRects.length; i++) {
        if (i == selectedItemPos) continue;
        final r = itemRects[i];
        if (r.width < 52 * px || r.height < 28 * px) continue;
        final isImg = i < itemIsImage.length && itemIsImage[i];
        _paintCanvasPill(
          canvas,
          isImg ? badgeImageLabel : badgeShapeLabel,
          Offset(r.left + 6 * px, r.top + 6 * px),
          bg: (isImg ? imageAccent : shapeAccent).withValues(alpha: 0.90),
          fg: PdfEditTokens.onBadge,
          px: px,
          alignTopLeft: true,
        );
      }
    }

    // ── 3 · Seçili metin bloğu ──
    final s = selected;
    if (s != null && s < rects.length) {
      final r = rects[s].inflate(2 * px);
      _selection(canvas, r, corners: false);
      final widthAt = PdfProBlockLayer.blockWidthAnchor(r, size);
      if (widthAt.dx > r.right + 2 * px) {
        canvas.drawLine(
          r.centerRight,
          widthAt,
          Paint()
            ..color = accent.withValues(alpha: 0.5)
            ..strokeWidth = 1.5 * px,
        );
      }
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: widthAt, width: 10 * px, height: 24 * px),
              Radius.circular(5 * px)),
          Paint()..color = onAccent);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: widthAt, width: 7.5 * px, height: 21 * px),
              Radius.circular(3.8 * px)),
          Paint()..color = accent);
      if (movable) {
        final moveAt = PdfProBlockLayer.blockMoveAnchor(r, size);
        final stemX = moveAt.dx.clamp(r.left, r.right).toDouble();
        final stemStart =
            moveAt.dy < r.top ? Offset(stemX, r.top) : Offset(stemX, r.bottom);
        canvas.drawLine(
          stemStart,
          moveAt,
          Paint()
            ..color = accent.withValues(alpha: 0.55)
            ..strokeWidth = 1.5 * px,
        );
        _moveGrip(canvas, moveAt);
      }
    }

    // ── 4 · Seçili görsel/şekil + 4 köşe tutamacı ──
    final ir = itemRect;
    final itemColor = selectedItemIsImage == null
        ? accent
        : (selectedItemIsImage! ? imageAccent : shapeAccent);
    if (ir != null) {
      _selection(canvas, ir, color: itemColor);
    }
    if (groupRects.isNotEmpty) {
      final gp = Path();
      for (final r in groupRects) {
        _addDashedRect(gp, r.inflate(2 * px));
      }
      canvas.drawPath(
          gp,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameActiveWidth * px
            ..color = accent);
    }
    final g = itemGrip;
    if (g != null) {
      _moveGrip(canvas, g, color: ir != null ? itemColor : accent);
    }
    final ar = annotRect;
    if (ar != null) {
      final ap = Path();
      _addDashedRect(ap, ar.inflate(3 * px));
      canvas.drawPath(
          ap,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = PdfEditTokens.frameActiveWidth * px
            ..color = accent);
    }

    // ── 5 · Yazma kipi: seçim, bileşim alt çizgisi, imleç ──
    final map = liveMap;
    if (map == null) return;
    final lo = math.min(liveSelStart, liveSelEnd),
        hi = math.max(liveSelStart, liveSelEnd);
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
    if (liveComposeStart >= 0 && liveComposeEnd > liveComposeStart) {
      final p = Paint()
        ..strokeWidth = 1.5 * px
        ..color = accent;
      for (final q in map.selection(liveComposeStart, liveComposeEnd)) {
        canvas.drawLine(toWidget(q[0], q[1]), toWidget(q[2], q[3]), p);
      }
    }
    if (hi == lo && caretOn.value) {
      final (x0, y0, x1, y1) = map.caret(lo);
      canvas.drawLine(
          toWidget(x0, y0),
          toWidget(x1, y1),
          Paint()
            ..strokeWidth = 2.2 * px
            ..strokeCap = StrokeCap.round
            ..color = !liveHasError ? accent : pending);
    }
  }

  @override
  bool shouldRepaint(_LayerPainter old) =>
      !identical(old.rects, rects) ||
      !identical(old.locked, locked) ||
      !identical(old.itemRects, itemRects) ||
      !identical(old.itemIsImage, itemIsImage) ||
      old.selectedItemPos != selectedItemPos ||
      old.selectedItemIsImage != selectedItemIsImage ||
      old.imageAccent != imageAccent ||
      old.shapeAccent != shapeAccent ||
      old.badgeImageLabel != badgeImageLabel ||
      old.badgeShapeLabel != badgeShapeLabel ||
      old.selected != selected ||
      old.accent != accent ||
      old.pending != pending ||
      old.onAccent != onAccent ||
      old.px != px ||
      old.pageSize != pageSize ||
      old.movable != movable ||
      old.itemRect != itemRect ||
      old.itemGrip != itemGrip ||
      old.annotRect != annotRect ||
      !listEquals(old.groupRects, groupRects) ||
      !identical(old.liveMap, liveMap) ||
      old.liveSelStart != liveSelStart ||
      old.liveSelEnd != liveSelEnd ||
      old.liveComposeStart != liveComposeStart ||
      old.liveComposeEnd != liveComposeEnd ||
      old.liveHasError != liveHasError ||
      old.caretOn != caretOn;
}

/// Tuval üstü kompakt hap rozet (tür etiketi veya canlı ölçek/ölçü göstergesi).
void _paintCanvasPill(
  Canvas canvas,
  String text,
  Offset anchor, {
  required Color bg,
  required Color fg,
  required double px,
  bool alignTopLeft = false,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: PdfEditTokens.canvasBadgeStyle(fg, px),
    ),
    textDirection: TextDirection.ltr,
    maxLines: 1,
  )..layout();
  final padX = 7 * px, padY = 3.5 * px;
  final w = tp.width + padX * 2;
  final h = tp.height + padY * 2;
  final rect = alignTopLeft
      ? Rect.fromLTWH(anchor.dx, anchor.dy, w, h)
      : Rect.fromCenter(center: anchor, width: w, height: h);
  final rr = RRect.fromRectAndRadius(rect, Radius.circular(h / 2));
  canvas.drawRRect(
    rr.shift(Offset(0, 1.5 * px)),
    Paint()..color = AppColors.shadow,
  );
  canvas.drawRRect(rr, Paint()..color = bg);
  tp.paint(canvas, Offset(rect.left + padX, rect.top + padY));
  tp.dispose();
}

/// Seçim çerçevesi: hafif dolgu, belirgin kontur ve dört beyaz-halkalı köşe tutamacı.
void _paintSelection(
    Canvas canvas, Rect r, Color accent, Color onAccent, double px,
    {bool corners = true}) {
  final rr = RRect.fromRectAndRadius(r, Radius.circular(4 * px));
  canvas.drawRRect(
      rr, Paint()..color = accent.withValues(alpha: PdfEditTokens.frameFillAlpha));
  canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = PdfEditTokens.frameActiveWidth * px
        ..color = accent);
  if (!corners) return;
  final rad = PdfEditTokens.handle / 2 * px;
  final shadow = Paint()..color = AppColors.shadow;
  final ring = Paint()..color = onAccent;
  final core = Paint()..color = accent;
  for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
    canvas.drawCircle(c + Offset(0, 1 * px), rad + 2.2 * px, shadow);
    canvas.drawCircle(c, rad + 2.0 * px, ring);
    canvas.drawCircle(c, rad, core);
  }
}

/// Taşıma tutamacı: ince gölge, beyaz halka, vurgulu daire ve dört yön oku.
void _paintMoveGrip(
    Canvas canvas, Offset at, Color accent, Color onAccent, double px) {
  final rad = 11.5 * px;
  canvas.drawCircle(
      at + Offset(0, 1.5 * px),
      rad + 2.0 * px,
      Paint()..color = AppColors.shadow);
  canvas.drawCircle(at, rad + 1.8 * px, Paint()..color = onAccent);
  canvas.drawCircle(at, rad, Paint()..color = accent);
  final p = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.65 * px
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..color = onAccent;
  final arm = rad * 0.56, head = rad * 0.24;
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

/// Sürükleme önizlemesi (taşı / genişlet / 4 köşeden ölçekle). **Kasma kuralı:**
/// sürükleme sırasında yalnız bu boyayıcı yeniden çizilir — katman yeniden
/// kurulmaz, öteki blok kılavuzları boyanmaz ([_DragPainter] `repaint`).
class _DragPreview extends ChangeNotifier {
  /// Sürüklenen çerçeve (katman pikseli); null = sürükleme yok.
  Rect? frame;
  List<Rect> members = const [];

  /// Taşıma tutamacının çerçevenin üst ortasına göre yeri; null = çizilmez.
  Offset? grip;
  PdfSnapTargets? targets;
  _ScaleCorner corner = _ScaleCorner.bottomRight;

  /// Özgün PDF boyutu (pt): ölçekleme sırasında canlı "%125 · 240×180 pt" rozeti için.
  Size? pdfSize;
  Color? colorOverride;

  Offset _raw = Offset.zero;
  Offset drag = Offset.zero;
  double width = 0, scale = 1;
  PdfSnap snap = PdfSnap.none;

  void begin(
    Rect frame, {
    List<Rect> members = const [],
    Offset? grip,
    PdfSnapTargets? targets,
    _ScaleCorner corner = _ScaleCorner.bottomRight,
    Size? pdfSize,
    Color? colorOverride,
  }) {
    this.frame = frame;
    this.members = members;
    this.grip = grip;
    this.targets = targets;
    this.corner = corner;
    this.pdfSize = pdfSize;
    this.colorOverride = colorOverride;
    _raw = Offset.zero;
    drag = Offset.zero;
    width = 0;
    scale = 1;
    snap = PdfSnap.none;
    notifyListeners();
  }

  /// Ölçeklemede sabit kalan karşı köşe (katman pikseli).
  Offset anchorPoint(Rect f) => switch (corner) {
        _ScaleCorner.bottomRight => f.topLeft,
        _ScaleCorner.bottomLeft => f.topRight,
        _ScaleCorner.topRight => f.bottomLeft,
        _ScaleCorner.topLeft => f.bottomRight,
      };

  /// Geçerli önizleme dikdörtgeni (taşıma, genişletme veya 4 köşe ölçekleme).
  Rect currentRect(Rect f) {
    if ((scale - 1).abs() >= 0.0001) {
      final a = anchorPoint(f);
      final w = f.width * scale;
      final h = f.height * scale;
      return switch (corner) {
        _ScaleCorner.bottomRight => Rect.fromLTWH(a.dx, a.dy, w, h),
        _ScaleCorner.bottomLeft => Rect.fromLTWH(a.dx - w, a.dy, w, h),
        _ScaleCorner.topRight => Rect.fromLTWH(a.dx, a.dy - h, w, h),
        _ScaleCorner.topLeft => Rect.fromLTWH(a.dx - w, a.dy - h, w, h),
      };
    }
    return Rect.fromLTWH(
        f.left + drag.dx, f.top + drag.dy, f.width + width, f.height);
  }

  /// Taşıma: ham kayma + tutunma. Kılavuz yeni belirdiyse true (titreşim).
  bool move(Offset delta) {
    _raw += delta;
    final f = frame, t = targets;
    final hadGuide = snap.xs.isNotEmpty || snap.ys.isNotEmpty;
    snap = f == null || t == null
        ? PdfSnap(_raw, const [], const [])
        : t.snap(f, _raw);
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
    pdfSize = null;
    colorOverride = null;
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
    final activeAccent = preview.colorOverride ?? accent;
    final d = preview.drag, s = preview.scale;
    final guide = Paint()
      ..strokeWidth = 1.2 * px
      ..color = activeAccent.withValues(alpha: 0.78);
    for (final x in preview.snap.xs) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
    }
    for (final y in preview.snap.ys) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    final member = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PdfEditTokens.frameActiveWidth * px
      ..color = activeAccent;
    for (final m in preview.members) {
      canvas.drawRect(m.inflate(2 * px).shift(d), member);
    }
    final r = preview.currentRect(f);
    _paintSelection(canvas, r, activeAccent, onAccent, px);
    final g = preview.grip;
    if (g != null && s == 1) {
      _paintMoveGrip(canvas, r.topCenter + g, activeAccent, onAccent, px);
    }
    // Canlı boyut / ölçek rozeti (sürükleme boyunca anında geri bildirim).
    if ((s - 1).abs() >= 0.005) {
      final pct = (s * 100).round();
      final ps = preview.pdfSize;
      final label = ps == null
          ? '%$pct'
          : '%$pct · ${(ps.width * s).round()}×${(ps.height * s).round()} pt';
      final badgeY = r.top >= 26 * px ? r.top - 16 * px : r.bottom + 16 * px;
      _paintCanvasPill(
        canvas,
        label,
        Offset(r.center.dx.clamp(56 * px, math.max(56 * px, size.width - 56 * px)),
            badgeY),
        bg: PdfEditTokens.badgeBg,
        fg: PdfEditTokens.onBadge,
        px: px,
      );
    }
  }

  @override
  bool shouldRepaint(_DragPainter old) =>
      old.preview != preview ||
      old.accent != accent ||
      old.onAccent != onAccent ||
      old.px != px;
}

/// Aktif çizim / işaretleme vuruşu durumu. Sürükleme boyunca `ValueNotifier`
/// üzerinden güncellenir ve yalnız [_StrokePainter] boyanır.
class _ActiveStroke {
  final Offset? from, to;
  final List<Offset> points;
  final List<Rect> markRects;

  const _ActiveStroke({
    this.from,
    this.to,
    this.points = const [],
    this.markRects = const [],
  });

  static const empty = _ActiveStroke();
}

class _StrokePainter extends CustomPainter {
  _StrokePainter(
    this.active, {
    required this.strokeColor,
    required this.strokeWidth,
    required this.shape,
  }) : super(repaint: active);

  final ValueNotifier<_ActiveStroke> active;
  final Color strokeColor;
  final double strokeWidth;
  final PdfMarkupKind? shape;

  @override
  bool hitTest(Offset position) => false;

  @override
  void paint(Canvas canvas, Size size) {
    final s = active.value;
    if (s.markRects.isNotEmpty) {
      final p = Paint()..color = strokeColor.withValues(alpha: 0.35);
      for (final r in s.markRects) {
        canvas.drawRect(r, p);
      }
    }
    if (s.points.length > 1) {
      final path = Path()..moveTo(s.points.first.dx, s.points.first.dy);
      for (final o in s.points.skip(1)) {
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
    final a = s.from, b = s.to;
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
  }

  @override
  bool shouldRepaint(_StrokePainter old) =>
      old.active != active ||
      old.strokeColor != strokeColor ||
      old.strokeWidth != strokeWidth ||
      old.shape != shape;
}

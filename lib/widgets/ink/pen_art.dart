import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart' show PenArtColors;
import '../../core/motion.dart';

/// Kalem tepsisindeki araç resimleri.
enum PenArt { pen, fountain, marker, highlighter, eraser, shapes, lasso }

/// **Kalem resimleri** — Notlar uygulamasının tepsisindeki çizimler
/// (kullanıcı 2026-11-28: "kalem tepsisi Notlar projemizdeki gibi olmalı";
/// kaynak `not` deposu `pen_icons.dart`, birebir). Yumuşak silindir gölgeli,
/// ince hatlı vektör çizimler: 44 × 96'lık kutuda, ucu yukarıda; gövde alt
/// kenardan taşar. Bulanıklık yok (GLES raster bütçesi); `shouldRepaint`
/// yalnız araç/renk/tema/kalkma değişince.
///
/// Ölçü sabitleri: [penArtSize].
const Size penArtSize = Size(44, 96);

/// Kalem resmini çizer (bkz. [PenArt]).
class PenArtPainter extends CustomPainter {
  const PenArtPainter({
    required this.tool,
    required this.ink,
    required this.dark,
    required this.lifted,
  });

  final PenArt tool;
  final Color ink;
  final bool dark;
  final bool lifted;

  // Gövde tonları: açık temada kırık beyaz, koyuda grafit.
  Color get _base => dark ? PenArtColors.kFF4B4B52 : PenArtColors.kFFF6F3EE;
  Color get _shade => dark ? PenArtColors.kFF28282D : PenArtColors.kFFCBC5BB;
  Color get _line => dark
      ? PenArtColors.white.withValues(alpha: 0.16)
      : PenArtColors.black.withValues(alpha: 0.24);
  Color get _opaque => ink.withAlpha(255);

  /// Çok açık (açık temada) ya da çok koyu (koyu temada) renkler zeminle
  /// karışır; o zaman uca zıt renkli ince hat çekilir.
  bool get _needsRim {
    final l = _opaque.computeLuminance();
    return dark ? l < 0.06 : l > 0.8;
  }

  Color get _inkLine {
    if (_needsRim) {
      return (dark ? PenArtColors.white : PenArtColors.black).withValues(alpha: 0.45);
    }
    return Color.lerp(_opaque, PenArtColors.black, 0.32)!;
  }

  Paint _grad(Rect r, Color base, [Color? shade, Color? hi]) =>
      Paint()
        ..shader = LinearGradient(
          colors: [
            hi ?? Color.lerp(base, PenArtColors.white, dark ? 0.14 : 0.5)!,
            base,
            base,
            shade ?? Color.lerp(base, PenArtColors.black, dark ? 0.45 : 0.2)!,
          ],
          stops: const [0, 0.3, 0.62, 1],
        ).createShader(r);

  Paint get _stroke => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 0.7
    ..strokeJoin = StrokeJoin.round
    ..color = _line;

  /// Silindir gövde: degrade + ince hat + sol kenarda parlak çizgi.
  void _barrel(Canvas c, Rect r, {double top = 3, Color? base, Color? shade}) {
    final rr = RRect.fromRectAndCorners(
      r,
      topLeft: Radius.circular(top),
      topRight: Radius.circular(top),
    );
    c.drawRRect(rr, _grad(r, base ?? _base, base == null ? _shade : shade));
    c.drawRRect(rr, _stroke);
    _spec(c, r.left + r.width * 0.2, r.top + top + 2, r.bottom);
  }

  void _spec(Canvas c, double x, double y0, double y1) => c.drawLine(
    Offset(x, y0),
    Offset(x, y1),
    Paint()
      ..color = PenArtColors.white.withValues(alpha: dark ? 0.22 : 0.7)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round,
  );

  /// Gövdeyi saran renkli bant (yatay çizgilerle silindir hissi).
  void _band(Canvas c, Rect r, {double alpha = 1}) {
    final col = _opaque.withValues(alpha: alpha);
    c.drawRect(r, _grad(r, col));
    final edge = Paint()
      ..color = _inkLine.withValues(alpha: 0.5)
      ..strokeWidth = 0.6;
    c.drawLine(r.topLeft, r.topRight, edge);
    c.drawLine(r.bottomLeft, r.bottomRight, edge);
    _spec(c, r.left + r.width * 0.2, r.top + 1, r.bottom - 1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    // Kalkmış aracın gölgesi tepsiye düşer (bulanıksız — GLES raster bütçesi).
    if (lifted) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - 12, 32, 24, size.height),
          const Radius.circular(8.0),
        ),
        Paint()
          ..color = PenArtColors.black.withValues(alpha: dark ? 0.22 : 0.08),
      );
    }
    switch (tool) {
      case PenArt.pen:
        _ballpoint(canvas, size, cx);
      case PenArt.fountain:
        _fountain(canvas, size, cx);
      case PenArt.marker:
        _marker(canvas, size, cx);
      case PenArt.highlighter:
        _highlighter(canvas, size, cx);
      case PenArt.eraser:
        _eraser(canvas, size, cx);
      case PenArt.shapes:
        _setSquare(canvas, size, cx);
      case PenArt.lasso:
        _lasso(canvas, size, cx);
    }
  }

  void _ballpoint(Canvas c, Size s, double cx) {
    const half = 8.0;
    final body = Rect.fromLTRB(cx - half, 38, cx + half, s.height + 4);
    _barrel(c, body, top: 2);
    // Metal koni: hafif içbükey yan çizgiler.
    final cone = Path()
      ..moveTo(cx - half, 39)
      ..quadraticBezierTo(cx - 5.5, 28, cx - 2.8, 16)
      ..lineTo(cx + 2.8, 16)
      ..quadraticBezierTo(cx + 5.5, 28, cx + half, 39)
      ..close();
    final metal = Rect.fromLTRB(cx - half, 16, cx + half, 39);
    c.drawPath(
      cone,
      _grad(
        metal,
        dark ? PenArtColors.kFF9A9AA3 : PenArtColors.kFFC9CBD2,
        dark ? PenArtColors.kFF55555C : PenArtColors.kFF858891,
        PenArtColors.white,
      ),
    );
    c.drawPath(cone, _stroke);
    // Renkli uç.
    final nib = Path()
      ..moveTo(cx - 2.8, 16.5)
      ..lineTo(cx - 1.1, 7)
      ..quadraticBezierTo(cx, 4.2, cx + 1.1, 7)
      ..lineTo(cx + 2.8, 16.5)
      ..close();
    c.drawPath(nib, _grad(Rect.fromLTRB(cx - 3, 4, cx + 3, 17), _opaque));
    c.drawPath(
      nib,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeJoin = StrokeJoin.round
        ..color = _inkLine,
    );
    // Renkli bant + ince halka.
    _band(c, Rect.fromLTRB(cx - half, 46, cx + half, 52));
    c.drawLine(
      Offset(cx - half, 41.5),
      Offset(cx + half, 41.5),
      Paint()
        ..color = _line
        ..strokeWidth = 0.6,
    );
    // Küçük klips.
    final clip = RRect.fromRectAndRadius(
      Rect.fromLTRB(cx + 3.2, 55, cx + 5.8, s.height + 4),
      const Radius.circular(1.3),
    );
    c.drawRRect(
      clip,
      Paint()..color = dark ? PenArtColors.kFF8A8A93 : PenArtColors.kFFB6B8BF,
    );
    c.drawRRect(clip, _stroke);
  }

  /// Dolma kalem: koyu gövde, metal uç (ortasında yarık), renkli bant.
  void _fountain(Canvas c, Size s, double cx) {
    const half = 8.5;
    final body = Rect.fromLTRB(cx - half, 40, cx + half, s.height + 4);
    final barrel = dark ? PenArtColors.kFF2E2E34 : PenArtColors.kFF3B3F4A;
    _barrel(c, body, base: barrel);
    // Kesik koni bölüm.
    final grip = Path()
      ..moveTo(cx - half, 41)
      ..lineTo(cx - 6, 30)
      ..lineTo(cx + 6, 30)
      ..lineTo(cx + half, 41)
      ..close();
    c.drawPath(
      grip,
      _grad(Rect.fromLTRB(cx - half, 30, cx + half, 41), barrel),
    );
    c.drawPath(grip, _stroke);
    // Metal uç: sivri badem, ortada yarık ve nefes deliği.
    final nibBox = Rect.fromLTRB(cx - 6, 5, cx + 6, 31);
    final nib = Path()
      ..moveTo(cx - 6, 31)
      ..quadraticBezierTo(cx - 6, 16, cx, 5)
      ..quadraticBezierTo(cx + 6, 16, cx + 6, 31)
      ..close();
    c.drawPath(
      nib,
      _grad(
        nibBox,
        dark ? PenArtColors.kFFB8A46A : PenArtColors.kFFD9C27E,
        dark ? PenArtColors.kFF6E6038 : PenArtColors.kFF9C8546,
        PenArtColors.white,
      ),
    );
    c.drawPath(nib, _stroke);
    final slit = Paint()
      ..color = _opaque
      ..strokeWidth = 1.1
      ..strokeCap = StrokeCap.round;
    c.drawLine(Offset(cx, 7), Offset(cx, 21), slit);
    c.drawCircle(Offset(cx, 22.5), 1.6, Paint()..color = _opaque);
    _band(c, Rect.fromLTRB(cx - half, 48, cx + half, 53));
  }

  void _marker(Canvas c, Size s, double cx) {
    const half = 11.0;
    final body = Rect.fromLTRB(cx - half, 40, cx + half, s.height + 4);
    _barrel(c, body, top: 4);
    // Boyun.
    final neck = Path()
      ..moveTo(cx - half + 0.5, 41)
      ..quadraticBezierTo(cx - 9, 31, cx - 6, 24)
      ..lineTo(cx + 6, 24)
      ..quadraticBezierTo(cx + 9, 31, cx + half - 0.5, 41)
      ..close();
    final neckBox = Rect.fromLTRB(cx - half, 24, cx + half, 41);
    final neckBase = Color.lerp(_base, _shade, 0.45)!;
    c.drawPath(neck, _grad(neckBox, neckBase));
    c.drawPath(neck, _stroke);
    // Yuvarlak keçe uç.
    final tip = RRect.fromRectAndCorners(
      Rect.fromLTRB(cx - 4.6, 7, cx + 4.6, 26),
      topLeft: const Radius.circular(4.6),
      topRight: const Radius.circular(4.6),
      bottomLeft: const Radius.circular(1),
      bottomRight: const Radius.circular(1),
    );
    c.drawRRect(tip, _grad(tip.outerRect, _opaque));
    c.drawRRect(
      tip,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..color = _inkLine,
    );
    _spec(c, cx - 2.2, 11, 22);
    // Kapak bandı.
    _band(c, Rect.fromLTRB(cx - half, 50, cx + half, 60));
  }

  void _highlighter(Canvas c, Size s, double cx) {
    const half = 13.0;
    final body = Rect.fromLTRB(cx - half, 42, cx + half, s.height + 4);
    final tone = Color.lerp(_base, _opaque, dark ? 0.3 : 0.22)!;
    _barrel(
      c,
      body,
      top: 5,
      base: tone,
      shade: Color.lerp(tone, PenArtColors.black, dark ? 0.45 : 0.2),
    );
    final neck = Path()
      ..moveTo(cx - half + 0.5, 43)
      ..lineTo(cx - 9, 28)
      ..lineTo(cx + 9, 28)
      ..lineTo(cx + half - 0.5, 43)
      ..close();
    final neckBox = Rect.fromLTRB(cx - half, 28, cx + half, 43);
    c.drawPath(neck, _grad(neckBox, Color.lerp(_base, _shade, 0.5)!));
    c.drawPath(neck, _stroke);
    // Eğik kesik (keski) uç, yarı saydam.
    final chisel = Path()
      ..moveTo(cx - 8, 29)
      ..lineTo(cx - 8, 17)
      ..lineTo(cx + 7.5, 8)
      ..quadraticBezierTo(cx + 8.6, 7.4, cx + 8.6, 9)
      ..lineTo(cx + 8, 29)
      ..close();
    c.drawPath(
      chisel,
      _grad(Rect.fromLTRB(cx - 8, 8, cx + 9, 29), ink.withAlpha(215)),
    );
    c.drawPath(
      chisel,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7
        ..strokeJoin = StrokeJoin.round
        ..color = _inkLine.withValues(alpha: 0.7),
    );
    // Gövdede etiket şeridi.
    _band(c, Rect.fromLTRB(cx - half, 54, cx + half, 64), alpha: 0.55);
  }

  void _eraser(Canvas c, Size s, double cx) {
    const half = 12.0;
    final rubber = dark ? PenArtColors.kFFC98A98 : PenArtColors.kFFF4A9B8;
    final top = Rect.fromLTRB(cx - half, 12, cx + half, 46);
    final rr = RRect.fromRectAndCorners(
      top,
      topLeft: const Radius.circular(8.0),
      topRight: const Radius.circular(8.0),
      bottomLeft: const Radius.circular(2.0),
      bottomRight: const Radius.circular(2.0),
    );
    c.drawRRect(rr, _grad(top, rubber));
    c.drawRRect(rr, _stroke);
    _spec(c, cx - half + 4.5, 19, 42);
    // Kılıf: nötr, ince çizgili.
    final sleeve = Rect.fromLTRB(
      cx - half - 1,
      44,
      cx + half + 1,
      s.height + 4,
    );
    final sleeveBase = dark ? PenArtColors.kFF5C5C64 : PenArtColors.kFFE4E0D8;
    final sr = RRect.fromRectAndCorners(
      sleeve,
      topLeft: const Radius.circular(2.0),
      topRight: const Radius.circular(2.0),
    );
    c.drawRRect(sr, _grad(sleeve, sleeveBase));
    c.drawRRect(sr, _stroke);
    _spec(c, sleeve.left + 5, 48, s.height + 2);
    final groove = Paint()
      ..color = _line
      ..strokeWidth = 0.7;
    c.drawLine(Offset(sleeve.left, 53), Offset(sleeve.right, 53), groove);
    c.drawLine(Offset(sleeve.left, 56), Offset(sleeve.right, 56), groove);
  }

  void _setSquare(Canvas c, Size s, double cx) {
    // Gönye: yarı saydam üçgen cetvel, kenarında ölçü çizgileri.
    final tint = dark ? PenArtColors.k6688B8E8 : PenArtColors.k80A9D2F5;
    final edge = dark ? PenArtColors.kFF9CC6EE : PenArtColors.kFF5E9BD6;
    final tri = Path()
      ..moveTo(cx - 14, 8)
      ..lineTo(cx - 14, s.height + 4)
      ..lineTo(cx + 16, s.height + 4)
      ..close();
    final box = Rect.fromLTRB(cx - 14, 8, cx + 16, s.height + 4);
    c.drawPath(
      tri,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color.lerp(tint, PenArtColors.white, 0.35)!, tint],
        ).createShader(box),
    );
    final outline = Paint()
      ..color = edge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..strokeJoin = StrokeJoin.round;
    c.drawPath(tri, outline);
    // İç pencere.
    final hole = Path()
      ..moveTo(cx - 7, 46)
      ..lineTo(cx - 7, s.height - 6)
      ..lineTo(cx + 5, s.height - 6)
      ..close();
    c.drawPath(
      hole,
      Paint()
        ..color = edge.withValues(alpha: 0.60)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeJoin = StrokeJoin.round,
    );
    final tick = Paint()
      ..color = edge
      ..strokeWidth = 0.9;
    for (var y = 18.0; y < s.height; y += 5) {
      final long = ((y - 18) / 5).round() % 2 == 0;
      c.drawLine(Offset(cx - 14, y), Offset(cx - (long ? 8.5 : 11), y), tick);
    }
    // Seçili renk: beyaz halkalı nokta.
    c.drawCircle(
      Offset(cx - 5, 22),
      4.2,
      Paint()..color = PenArtColors.white.withValues(alpha: 0.85),
    );
    c.drawCircle(Offset(cx - 5, 22), 3, Paint()..color = _opaque);
    c.drawCircle(
      Offset(cx - 5, 22),
      3,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6
        ..color = _inkLine,
    );
  }

  /// Kement: kesik çizgili ilmek ve sapı.
  void _lasso(Canvas c, Size s, double cx) {
    final handle = Rect.fromLTRB(cx - 5.5, 48, cx + 5.5, s.height + 4);
    _barrel(c, handle, top: 4);
    // Sap ucunda renkli halka.
    _band(c, Rect.fromLTRB(cx - 5.5, 54, cx + 5.5, 58));
    final rect = Rect.fromCenter(center: Offset(cx, 25), width: 32, height: 24);
    const dashes = 12;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    final rim = _inkLine;
    for (var pass = _needsRim ? 0 : 1; pass < 2; pass++) {
      dash
        ..color = pass == 0 ? rim : _opaque
        ..strokeWidth = pass == 0 ? 3.6 : 2.4;
      for (var i = 0; i < dashes; i++) {
        final start = 2 * math.pi * i / dashes;
        c.drawArc(rect, start, math.pi / dashes, false, dash);
      }
      c.drawLine(Offset(cx, 37), Offset(cx, 48), dash);
    }
  }

  @override
  bool shouldRepaint(PenArtPainter old) =>
      old.tool != tool ||
      old.ink != ink ||
      old.dark != dark ||
      old.lifted != lifted;
}


/// **Tepsideki tek kalem** (Notlar'daki kapsül/dok aracı): dik durur, yalnız
/// üst kısmı görünür; seçili kalem yumuşak tonlu yuvada yukarı kalkar, altında
/// renk çizgisi belirir. 44 × [height] kırpma kutusu, içinde 31 × 68 kalem.
class PenArtSlot extends StatelessWidget {
  const PenArtSlot({
    super.key,
    required this.art,
    required this.label,
    required this.selected,
    required this.ink,
    required this.onTap,
    this.onLongPress,
    this.height = 56,
    this.width = 44,
  });

  final PenArt art;
  final String label;
  final bool selected;
  final Color ink;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final double height, width;

  static const double _penW = 31, _penH = 68;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    // Dururken kalemin üstü 17, seçiliyken 4 dp aşağıda (Notlar ölçüsü);
    // kutu kısaysa oranla.
    final k = height / 56;
    final rest = 17 * k / _penH, lifted = 4 * k / _penH;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          onLongPress: onLongPress,
          child: SizedBox(
            width: width,
            height: height,
            child: ClipRect(
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  if (selected)
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 2, vertical: 4),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer
                                .withValues(alpha: 0.24),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    top: 0,
                    child: AnimatedSlide(
                      duration: Motion.of(context, Motion.short),
                      curve: Motion.standard,
                      offset: Offset(0, selected ? lifted : rest),
                      child: SizedBox(
                        width: _penW * k,
                        height: _penH * k,
                        child: FittedBox(
                          child: SizedBox(
                            width: penArtSize.width,
                            height: penArtSize.height,
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: PenArtPainter(
                                  tool: art,
                                  ink: ink,
                                  dark: dark,
                                  lifted: selected,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (selected)
                    Positioned(
                      bottom: 4,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: art == PenArt.eraser ? scheme.primary : ink,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const SizedBox(width: 16, height: 3),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

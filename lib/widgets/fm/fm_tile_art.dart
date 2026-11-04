/// **Pano kutularının yeni simgeleri** (2026-11-04 tasarım turu).
///
/// Kullanıcı: *"fotoğraflar, videolar, arşivler başta olmak üzere daha yeni
/// simgeler üretilecek"* ve örnek görseldeki fikir: *"yumuşak köşeli, hafif
/// renkli (squircle) zemin üzerine oturtulmuş, modern 2.5D ve gölgeli"*.
///
/// - **Zemin:** iOS tarzı sürekli eğrili kare ([ContinuousRectangleBorder]),
///   kutunun renginin çok açık bir tonu; üstten alta hafif koyulaşır, altında
///   renkli yumuşak gölge, üst yarıda ince bir parlama.
/// - **Çizim:** Fotoğraflar, Videolar, Arşivler, Ses, Belgeler ve İndirilenler
///   için kendi çizimimiz ([FmTileArt]) — arkada bir katman, önde degradeli
///   asıl nesne (2.5D derinlik). Diğer kutular Material glifini aynı zeminde
///   degradeyle çizer.
///
/// Hepsi tek bir [CustomPainter]: katman (`saveLayer`) açılmaz, panodaki
/// ~15 kutu kaydırılırken ek maliyet yok. Ölçüler birim kareye göre; aynı
/// kod her boyutta keskin.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/skin.dart';
import 'fm_category_tile.dart';

/// Kendi çizimi olan kutular.
enum FmTileArt { photos, video, archive, audio, document, downloads }

/// Zemin + simge. [art] null ise [icon] glifi çizilir.
class FmSquircleIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;
  final FmTileArt? art;

  const FmSquircleIcon({
    super.key,
    required this.icon,
    required this.color,
    required this.size,
    this.art,
  });

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final painter = _SquirclePainter(color: color, dark: dark, art: art);
    final glyphColor =
        dark ? Color.lerp(color, AppColors.mixLight, 0.25)! : color;
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: painter,
        child: Center(
          // Çizimli kutuda da `Icon` ağaçta kalır (erişilebilirlik, testlerde
          // `find.byIcon`) ama görünmez — çizimi boyayıcı yapar.
          child: art != null
              ? ExcludeSemantics(
                  child: Opacity(
                    opacity: 0,
                    child: Icon(icon, size: size * 0.5),
                  ),
                )
              : FmTintedIcon(
                  icon: icon,
                  color: glyphColor,
                  size: size * 0.56,
                  style: SkinIconStyle.gradient,
                ),
        ),
      ),
    );
  }
}

class _SquirclePainter extends CustomPainter {
  final Color color;
  final bool dark;
  final FmTileArt? art;

  _SquirclePainter({
    required this.color,
    required this.dark,
    required this.art,
  });

  Color get _light => Color.lerp(color, AppColors.mixLight, 0.38)!;
  Color get _deep => Color.lerp(color, AppColors.mixDark, 0.22)!;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = Offset.zero & size;
    final shape = ContinuousRectangleBorder(
        borderRadius: BorderRadius.circular(s * 0.62));
    final path = shape.getOuterPath(rect);

    // Gölge: renkli, yumuşak, biraz aşağıda.
    canvas.drawPath(
      path.shift(Offset(0, s * 0.07)),
      Paint()
        ..color = color.withValues(alpha: dark ? 0.30 : 0.24)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, s * 0.08),
    );

    // Zemin: kutunun renginin çok açık tonu, üstten alta koyulaşan.
    final top = dark
        ? Color.lerp(color, AppColors.mixDark, 0.55)!
        : Color.lerp(color, AppColors.mixLight, 0.86)!;
    final bottom = dark
        ? Color.lerp(color, AppColors.mixDark, 0.68)!
        : Color.lerp(color, AppColors.mixLight, 0.72)!;
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [top, bottom],
        ).createShader(rect),
    );
    // Üst parlama + ince kenar.
    canvas.save();
    canvas.clipPath(path);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, s, s * 0.5),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.mixLight.withValues(alpha: dark ? 0.08 : 0.45),
            AppColors.mixLight.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, s, s * 0.5)),
    );
    canvas.restore();
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(0.8, s * 0.018)
        ..color = color.withValues(alpha: dark ? 0.35 : 0.18),
    );

    final a = art;
    if (a != null) {
      canvas.save();
      canvas.scale(s);
      switch (a) {
        case FmTileArt.photos:
          _photos(canvas);
        case FmTileArt.video:
          _video(canvas);
        case FmTileArt.archive:
          _archive(canvas);
        case FmTileArt.audio:
          _audio(canvas);
        case FmTileArt.document:
          _document(canvas);
        case FmTileArt.downloads:
          _downloads(canvas);
      }
      canvas.restore();
    }
  }

  // ── yardımcılar (birim kare koordinatı) ──────────────────────────────────

  Paint _fill(Rect r, [Color? from, Color? to]) => Paint()
    ..isAntiAlias = true
    ..shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [from ?? _light, to ?? _deep],
    ).createShader(r);

  Paint get _white => Paint()..color = AppColors.mixLight;

  void _softShadow(Canvas c, RRect r) => c.drawRRect(
        r.shift(const Offset(0, 0.035)),
        Paint()
          ..color = AppColors.shade.withValues(alpha: 0.18)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.025),
      );

  /// İki fotoğraf: arkada yatık açık kart, önde gökyüzü + dağ + güneş.
  void _photos(Canvas c) {
    final back = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.27, 0.22, 0.48, 0.42), const Radius.circular(0.07));
    c.save();
    c.translate(0.51, 0.43);
    c.rotate(-0.22);
    c.translate(-0.51, -0.43);
    c.drawRRect(back, Paint()..color = _light.withValues(alpha: 0.75));
    c.restore();

    final front = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.22, 0.32, 0.56, 0.44), const Radius.circular(0.08));
    _softShadow(c, front);
    c.drawRRect(front, _white);
    final inner = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.26, 0.36, 0.48, 0.36), const Radius.circular(0.05));
    c.save();
    c.clipRRect(inner);
    c.drawRect(inner.outerRect,
        _fill(inner.outerRect, Color.lerp(color, AppColors.mixLight, 0.55), _light));
    // Güneş
    c.drawCircle(const Offset(0.63, 0.45), 0.045,
        Paint()..color = AppHues.amber);
    // Dağlar: arkadaki açık, öndeki koyu.
    c.drawPath(
      Path()
        ..moveTo(0.40, 0.74)
        ..lineTo(0.58, 0.52)
        ..lineTo(0.78, 0.74)
        ..close(),
      Paint()..color = color.withValues(alpha: 0.75),
    );
    c.drawPath(
      Path()
        ..moveTo(0.24, 0.74)
        ..lineTo(0.40, 0.55)
        ..lineTo(0.58, 0.74)
        ..close(),
      _fill(const Rect.fromLTWH(0.24, 0.55, 0.34, 0.2), color, _deep),
    );
    c.restore();
  }

  /// Klaket: degradeli gövde, üstte yatık çizgili kapak, ortada oynat.
  void _video(Canvas c) {
    final body = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.22, 0.40, 0.56, 0.38), const Radius.circular(0.07));
    _softShadow(c, body);
    c.drawRRect(body, _fill(body.outerRect));
    // Kapak (hafif açık, eğik).
    c.save();
    c.translate(0.22, 0.37);
    c.rotate(-0.20);
    final lid = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, -0.11, 0.56, 0.11), const Radius.circular(0.03));
    c.drawRRect(lid, Paint()..color = _deep);
    c.clipRRect(lid);
    final stripe = Paint()..color = AppColors.mixLight.withValues(alpha: 0.92);
    for (var i = 0; i < 4; i++) {
      final x = 0.04 + i * 0.14;
      c.drawPath(
        Path()
          ..moveTo(x, 0)
          ..lineTo(x + 0.06, -0.11)
          ..lineTo(x + 0.12, -0.11)
          ..lineTo(x + 0.06, 0)
          ..close(),
        stripe,
      );
    }
    c.restore();
    // Oynat üçgeni.
    c.drawPath(
      Path()
        ..moveTo(0.45, 0.50)
        ..lineTo(0.45, 0.68)
        ..lineTo(0.60, 0.59)
        ..close(),
      _white,
    );
  }

  /// Arşiv kutusu: izometrik kapak + ön yüz, ortadan inen fermuar.
  void _archive(Canvas c) {
    final front = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.24, 0.40, 0.52, 0.38), const Radius.circular(0.05));
    _softShadow(c, front);
    c.drawRRect(front, _fill(front.outerRect, color, _deep));
    // Kapak: önden biraz geniş, açık ton.
    final lid = RRect.fromRectAndRadius(
        const Rect.fromLTWH(0.20, 0.27, 0.60, 0.15), const Radius.circular(0.05));
    c.drawRRect(lid, _fill(lid.outerRect, _light, color));
    // Fermuar şeridi.
    const zx = 0.50;
    c.drawRect(const Rect.fromLTWH(zx - 0.035, 0.27, 0.07, 0.36),
        Paint()..color = AppColors.mixLight.withValues(alpha: 0.30));
    final tooth = Paint()..color = AppColors.mixLight;
    for (var i = 0; i < 5; i++) {
      final y = 0.29 + i * 0.065;
      c.drawRect(
          Rect.fromLTWH(i.isEven ? zx - 0.035 : zx, y, 0.035, 0.03), tooth);
    }
    // Çekme tutamağı.
    final tab = RRect.fromRectAndRadius(
        const Rect.fromLTWH(zx - 0.05, 0.60, 0.10, 0.11), const Radius.circular(0.03));
    c.drawRRect(tab, tooth);
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(zx - 0.02, 0.63, 0.04, 0.05),
            const Radius.circular(0.02)),
        Paint()..color = _deep);
  }

  /// Çift nota: degradeli kafalar + kiriş.
  void _audio(Canvas c) {
    final p = _fill(const Rect.fromLTWH(0.25, 0.25, 0.5, 0.52));
    // Kiriş
    c.drawPath(
      Path()
        ..moveTo(0.40, 0.30)
        ..lineTo(0.72, 0.24)
        ..lineTo(0.72, 0.33)
        ..lineTo(0.40, 0.39)
        ..close(),
      p,
    );
    c.drawRect(const Rect.fromLTWH(0.40, 0.33, 0.05, 0.36), p);
    c.drawRect(const Rect.fromLTWH(0.67, 0.27, 0.05, 0.36), p);
    for (final o in const [Offset(0.355, 0.70), Offset(0.625, 0.64)]) {
      c.drawOval(
        Rect.fromCenter(center: o.translate(0, 0.03), width: 0.17, height: 0.12),
        Paint()
          ..color = AppColors.shade.withValues(alpha: 0.15)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.02),
      );
      c.drawOval(Rect.fromCenter(center: o, width: 0.17, height: 0.13), p);
    }
  }

  /// Belge: arkada ikinci sayfa, önde köşesi kıvrık sayfa + renkli satırlar.
  void _document(Canvas c) {
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0.33, 0.20, 0.42, 0.52),
            const Radius.circular(0.05)),
        Paint()..color = _light.withValues(alpha: 0.7));
    const fold = 0.12;
    final page = Path()
      ..moveTo(0.25, 0.30)
      ..lineTo(0.67 - fold, 0.30)
      ..lineTo(0.67, 0.30 + fold)
      ..lineTo(0.67, 0.80)
      ..lineTo(0.25, 0.80)
      ..close();
    c.drawPath(
      page.shift(const Offset(0, 0.03)),
      Paint()
        ..color = AppColors.shade.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.025),
    );
    c.drawPath(page, _white);
    c.drawPath(
      Path()
        ..moveTo(0.67 - fold, 0.30)
        ..lineTo(0.67 - fold, 0.30 + fold)
        ..lineTo(0.67, 0.30 + fold)
        ..close(),
      Paint()..color = _light,
    );
    // Başlık bandı + satırlar.
    c.drawRRect(
        RRect.fromRectAndRadius(const Rect.fromLTWH(0.31, 0.40, 0.22, 0.06),
            const Radius.circular(0.03)),
        _fill(const Rect.fromLTWH(0.31, 0.40, 0.22, 0.06), color, _deep));
    final line = Paint()..color = color.withValues(alpha: 0.35);
    for (var i = 0; i < 3; i++) {
      c.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromLTWH(0.31, 0.52 + i * 0.075, i == 2 ? 0.20 : 0.30, 0.035),
              const Radius.circular(0.02)),
          line);
    }
  }

  /// İndirilenler: tepside duran aşağı ok.
  void _downloads(Canvas c) {
    // Tepsi
    final tray = Path()
      ..moveTo(0.22, 0.58)
      ..lineTo(0.22, 0.74)
      ..quadraticBezierTo(0.22, 0.79, 0.27, 0.79)
      ..lineTo(0.73, 0.79)
      ..quadraticBezierTo(0.78, 0.79, 0.78, 0.74)
      ..lineTo(0.78, 0.58);
    c.drawPath(
      tray,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.075
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = _deep,
    );
    // Ok (gölgeli, degradeli)
    final arrow = Path()
      ..moveTo(0.44, 0.20)
      ..lineTo(0.56, 0.20)
      ..lineTo(0.56, 0.45)
      ..lineTo(0.66, 0.45)
      ..lineTo(0.50, 0.65)
      ..lineTo(0.34, 0.45)
      ..lineTo(0.44, 0.45)
      ..close();
    c.drawPath(
      arrow.shift(const Offset(0, 0.03)),
      Paint()
        ..color = AppColors.shade.withValues(alpha: 0.18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.025),
    );
    c.drawPath(arrow, _fill(const Rect.fromLTWH(0.34, 0.2, 0.32, 0.45)));
  }

  @override
  bool shouldRepaint(_SquirclePainter old) =>
      old.color != color ||
      old.dark != dark ||
      old.art != art;
}

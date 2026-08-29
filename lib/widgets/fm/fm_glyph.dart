/// **Uygulamanın kendi dosya/klasör simgeleri** — Material glifi değil,
/// `CustomPainter` ile çizilen gerçek klasör ve kağıt biçimleri.
///
/// Kullanıcı bulgusu (2026-08-29, ekran görüntüsüyle): *"dosya ve klasör
/// simgeleri çok daha iyi olmalı, şu an çok yapmacık."* Haklıydı: her satırda
/// kutunun %92'sini kaplayan TEK RENK, DÜZ bir Material glifi vardı
/// (`Icons.folder_rounded` vb.). Yan yana on satırda ekran aynı okra lekesinin
/// tekrarına dönüyordu; klasörün klasör, dosyanın dosya olduğu ancak dikkatle
/// bakınca anlaşılıyordu ve hiçbir derinlik/malzeme hissi yoktu.
///
/// ## Neden çizim, neden hazır ikon seti değil
/// - Hazır set (Font Awesome, ikon paketleri) = yeni bağımlılık + APK şişmesi
///   ve hâlâ "başkasının dili". Proje ilkesi: sade, hafif, **bize özgü**.
///   (Başka bir dosya yöneticisinin çizimleri KOPYALANMADI; aşağıdaki biçimler
///   uygulamanın kendi paletinden — [FmColors] — türetildi.)
/// - Çizim, ölçekten bağımsız keskin kalır: aynı kod 24 px liste satırında da
///   96 px ızgara hücresinde de aynı oranlarla çalışır (her şey birim kareye
///   göre, sabit piksel yok).
///
/// ## Tasarım
/// - **Klasör:** arkada sekme (tab), önde gövde; ikisinin arasından kağıt
///   ucu görünür. Gövdede üstten alta doğru koyulaşan degrade ve üst kenarda
///   ince bir ışık çizgisi → düz lekeden gerçek bir nesneye dönüyor.
///   Bilinen klasörlerin (İndirilenler, DCIM, WhatsApp…) glifi **klasörün
///   yerine geçmez**, gövdesinin üstüne beyaz olarak biner: klasör klasör
///   olarak kalır, glif yalnız hangisi olduğunu söyler.
/// - **Dosya:** köşesi kıvrık kağıt sayfa, üstünde metin satırlarını temsil
///   eden ince çizgiler ve altta **uzantıyı yazan renkli şerit** (PDF, DOCX,
///   ZIP, APK…). Uzantının okunabilir yazılması, "ne kadar görünebilirse o
///   kadar iyi" isteğinin (2026-08-17) doğrudan karşılığı: tür artık glif
///   tahmininden değil yazıdan anlaşılıyor.
///
/// ## Çizgi (outlined) tema aileleri
/// "İş programı" / "Gece" ailelerinde dolgu yerine **ince kontur** çizilir
/// (bkz. `SkinContext.fmOutlinedIcons`): aynı biçim, daha sakin ağırlık.
library;

import 'package:flutter/material.dart';

/// Bir dosya/klasör simgesinin çizim reçetesi. Widget'lar bunu [FmGlyph]'e
/// verir; boyayıcı burada tanımlı alanların dışına çıkmaz.
@immutable
class FmGlyphSpec {
  /// Klasör mü kağıt mı çizilecek.
  final bool folder;

  /// Ana renk: klasörün gövdesi ya da kağıdın şeridi/kenarlığı.
  final Color color;

  /// Klasörün gövdesine binen ya da uzantısı olmayan dosyada kağıdın ortasına
  /// çizilen glif (yoksa null).
  final IconData? overlay;

  /// Kağıt şeridine yazılacak uzantı (`PDF`, `DOCX`…). Boşsa şerit çizilmez,
  /// yerine metin satırları uzatılır.
  final String label;

  /// Dolgu yerine kontur çiz (çizgi glifli tema aileleri).
  final bool outlined;

  /// Koyu tema: kağıt beyazı yerine koyu yüzey kullanılır.
  final bool dark;

  const FmGlyphSpec({
    required this.folder,
    required this.color,
    this.overlay,
    this.label = '',
    this.outlined = false,
    this.dark = false,
  });

  @override
  bool operator ==(Object other) =>
      other is FmGlyphSpec &&
      other.folder == folder &&
      other.color == color &&
      other.overlay == overlay &&
      other.label == label &&
      other.outlined == outlined &&
      other.dark == dark;

  @override
  int get hashCode => Object.hash(folder, color, overlay, label, outlined, dark);
}

/// [FmGlyphSpec]'i çizen widget. Kare kutuya sığar, kutunun tamamını kullanır.
class FmGlyph extends StatelessWidget {
  final FmGlyphSpec spec;
  final double size;

  const FmGlyph({super.key, required this.spec, required this.size});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          // `isComplex` YOK: biçimler birkaç yoldan ibaret; raster önbelleği
          // binlerce hücreli ızgarada fayda değil bellek yükü olurdu.
          painter: _FmGlyphPainter(spec),
        ),
      );
}

/// Ölçeklenebilir çizim. Tüm ölçüler **birim karede** (0..1) tanımlı ve
/// [Canvas.scale] ile boyuta taşınır — 24 px ile 96 px arasında oranlar
/// bozulmaz.
class _FmGlyphPainter extends CustomPainter {
  final FmGlyphSpec spec;

  const _FmGlyphPainter(this.spec);

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    canvas.save();
    // Kare olmayan kutuda ortala (ızgara hücresi kareye yakın ama tam değil).
    canvas.translate((size.width - side) / 2, (size.height - side) / 2);
    canvas.scale(side);
    if (spec.folder) {
      _paintFolder(canvas, side);
    } else {
      _paintSheet(canvas, side);
    }
    canvas.restore();
  }

  // ── klasör ────────────────────────────────────────────────────────────────

  static const _l = 0.045;
  static const _r = 0.955;
  static const _tabTop = 0.135;
  static const _bodyTop = 0.315;
  static const _bottom = 0.855;

  void _paintFolder(Canvas canvas, double side) {
    final body = RRect.fromLTRBR(
        _l, _bodyTop, _r, _bottom, const Radius.circular(0.075));
    // Sekme: gövdenin arkasından, SOL ÜSTTE görünür. Sağ üst köşesi eğik —
    // dik köşe klasörü "iki üst üste kutu" gibi gösteriyordu.
    final tab = Path()
      ..moveTo(_l + 0.055, _tabTop)
      ..lineTo(0.40, _tabTop)
      ..lineTo(0.50, _bodyTop + 0.05)
      ..lineTo(_l, _bodyTop + 0.05)
      ..lineTo(_l, _tabTop + 0.055)
      ..quadraticBezierTo(_l, _tabTop, _l + 0.055, _tabTop)
      ..close();

    if (spec.outlined) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.062
        ..strokeJoin = StrokeJoin.round
        ..color = spec.color;
      canvas.drawPath(tab, stroke);
      canvas.drawRRect(body, stroke);
      _paintOverlay(canvas, side, spec.color, const Offset(0.5, 0.565), 0.34);
      return;
    }

    // 1) Sekme — gövdeden bir kademe koyu: arkada durduğu anlaşılsın.
    canvas.drawPath(
      tab,
      Paint()..color = Color.lerp(spec.color, Colors.black, 0.22)!,
    );

    // 2) Kağıt ucu: sekme ile gövde arasından görünen açık şerit. Klasörün
    //    "dolu" olduğunu tek bir çizgiyle anlatıyor.
    canvas.drawRRect(
      RRect.fromLTRBR(_l + 0.135, _bodyTop - 0.075, _r - 0.135, _bodyTop + 0.05,
          const Radius.circular(0.024)),
      // Saf beyaz DEĞİL: kağıt tonu. Beyaz, okra gövdenin üstünde bir
      // "etiket" gibi bağırıyor ve klasörün kendisinden çok göze çarpıyordu.
      Paint()..color = spec.dark
          ? const Color(0xFFD8D2C6)
          : const Color(0xFFF6F1E6),
    );

    // 3) Gövde — üstten alta koyulaşan degrade.
    const rect = Rect.fromLTRB(_l, _bodyTop, _r, _bottom);
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(spec.color, Colors.white, 0.24)!,
            spec.color,
            Color.lerp(spec.color, Colors.black, 0.12)!,
          ],
          stops: const [0, 0.55, 1],
        ).createShader(rect),
    );

    // 4) Üst kenarda ince ışık çizgisi — malzeme hissinin tamamı bu satırda.
    canvas.drawRRect(
      RRect.fromLTRBR(_l + 0.045, _bodyTop + 0.028, _r - 0.045,
          _bodyTop + 0.052, const Radius.circular(0.012)),
      Paint()..color = Colors.white.withValues(alpha: 0.32),
    );

    _paintOverlay(canvas, side, Colors.white.withValues(alpha: 0.94),
        const Offset(0.5, 0.575), 0.34);
  }

  // ── kağıt (dosya) ─────────────────────────────────────────────────────────

  static const _pl = 0.135;
  static const _pr = 0.865;
  static const _pt = 0.055;
  static const _pb = 0.945;

  /// Kıvrık köşenin kenar uzunluğu.
  static const _fold = 0.26;

  void _paintSheet(Canvas canvas, double side) {
    const rr = 0.055;
    // Sayfa: sağ ÜST köşesi kesik (kıvrık köşe oraya oturur).
    final page = Path()
      ..moveTo(_pl + rr, _pt)
      ..lineTo(_pr - _fold, _pt)
      ..lineTo(_pr, _pt + _fold)
      ..lineTo(_pr, _pb - rr)
      ..quadraticBezierTo(_pr, _pb, _pr - rr, _pb)
      ..lineTo(_pl + rr, _pb)
      ..quadraticBezierTo(_pl, _pb, _pl, _pb - rr)
      ..lineTo(_pl, _pt + rr)
      ..quadraticBezierTo(_pl, _pt, _pl + rr, _pt)
      ..close();
    // Kıvrık köşe (dog-ear).
    final earPath = Path()
      ..moveTo(_pr - _fold, _pt)
      ..lineTo(_pr, _pt + _fold)
      ..lineTo(_pr - _fold, _pt + _fold)
      ..close();

    if (spec.outlined) {
      final stroke = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.062
        ..strokeJoin = StrokeJoin.round
        ..color = spec.color;
      canvas.drawPath(page, stroke);
      canvas.drawPath(earPath, stroke);
      _paintLabelOrOverlay(canvas, side, outlinedTint: spec.color);
      return;
    }

    // Sayfa gövdesi: kağıt. Koyu temada beyaz kağıt ekranı deliyordu →
    // rengin çok koyu bir karışımı kullanılıyor (ton yine türü söylüyor).
    canvas.drawPath(
      page,
      Paint()
        ..color = spec.dark
            ? Color.lerp(spec.color, const Color(0xFF14120E), 0.80)!
            : Color.lerp(spec.color, Colors.white, 0.92)!,
    );
    canvas.drawPath(
      page,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.028
        ..color = spec.color.withValues(alpha: spec.dark ? 0.75 : 0.55),
    );
    canvas.drawPath(
      earPath,
      Paint()..color = spec.color.withValues(alpha: spec.dark ? 0.65 : 0.42),
    );

    _paintLabelOrOverlay(canvas, side);
  }

  /// Kağıdın içi: uzantı varsa **renkli şerit + yazı**, yoksa glif/çizgiler.
  void _paintLabelOrOverlay(Canvas canvas, double side, {Color? outlinedTint}) {
    // Metin satırları — şeridin üstünde, "bu bir belge" fikri.
    final line = Paint()
      ..color = spec.color.withValues(alpha: outlinedTint != null ? 0.55 : 0.38)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 0.038;
    for (var i = 0; i < 2; i++) {
      final y = 0.30 + i * 0.115;
      canvas.drawLine(
          Offset(_pl + 0.085, y), Offset(_pr - (i == 0 ? 0.20 : 0.085), y), line);
    }

    final label = spec.label;
    if (label.isEmpty) {
      _paintOverlay(canvas, side, spec.color.withValues(alpha: 0.65),
          const Offset(0.5, 0.635), 0.30);
      return;
    }

    // **Şerit + uzantı yazısı.** Çok küçük kutuda (liste seçim rozeti, 24 px)
    // yazı okunmaz bir lekeye döner → eşiğin altında yalnız şerit çizilir.
    final band = RRect.fromLTRBR(
        _pl - 0.045, 0.530, _pl + 0.545, 0.790, const Radius.circular(0.038));
    canvas.drawRRect(band, Paint()..color = spec.color);
    if (side < 28) return;

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w800,
          // Uzantı uzadıkça küçülür (3 harf: 0.20 · 4 harf: 0.155).
          fontSize: label.length <= 3 ? 0.20 : 0.155,
          height: 1.0,
          letterSpacing: label.length <= 3 ? 0.004 : 0.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    // Yazı şeride sığmıyorsa (uzun uzantı) yatayda sıkıştırılır — taşıp
    // şeridin dışına çıkmasındansa bir tık dar yazılması yeğdir.
    final available = band.width - 0.06;
    canvas.save();
    canvas.translate(band.left + band.width / 2, band.top + band.height / 2);
    if (painter.width > available) canvas.scale(available / painter.width, 1);
    painter.paint(canvas, Offset(-painter.width / 2, -painter.height / 2));
    canvas.restore();
  }

  /// Material glifini birim karede çizer (ikon fontu → [TextPainter]).
  void _paintOverlay(
      Canvas canvas, double side, Color color, Offset center, double glyphSize) {
    final icon = spec.overlay;
    if (icon == null) return;
    // Çok küçük kutuda glif okunmaz; klasörün kendi biçimi zaten bilgi veriyor.
    if (side < 22) return;
    final painter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          color: color,
          fontSize: glyphSize,
          fontFamily: icon.fontFamily,
          package: icon.fontPackage,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(canvas,
        center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(_FmGlyphPainter old) => old.spec != spec;
}

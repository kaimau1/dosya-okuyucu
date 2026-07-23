import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../services/pptx_render.dart';

/// Bir slaytı orijinal tasarımıyla (arka plan, şekiller, görseller, biçimli
/// metin) çizer. Ölçü birimi punto; [FittedBox] ile kullanılabilir genişliğe
/// orantılı olarak ölçeklenir — yani her ekranda PowerPoint'teki yerleşimin
/// aynısı görünür.
class SlideCanvas extends StatelessWidget {
  final SlideVM slide;

  /// Metin kutusuna dokunulduğunda çağrılır (düzenleme için). null ise salt okunur.
  final void Function(ShapeVM shape)? onEditShape;

  /// Şu an **canlı düzenlenen** şekil. O kutunun paragrafları statik metin
  /// yerine yerinde `TextField` olarak çizilir. Kimlikle (identical) eşlenir —
  /// düzenleme sırasında slayt yeniden çizilmediği için nesne kararlıdır.
  final ShapeVM? editingShape;

  /// Düzenlenen şeklin paragraflarıyla hizalı denetleyiciler (indeks = paragraf
  /// sırası; düzenlenemeyen paragraf için null). Yalnız [editingShapeId] kutusu için.
  final List<TextEditingController?>? editControllers;

  /// Kaçıncı animasyon adımına kadar görünsün. null = her şey görünür
  /// (düzenleme görünümü). Sunum modunda 0'dan başlar, her tıklamada artar.
  final int? step;

  const SlideCanvas({
    super.key,
    required this.slide,
    this.onEditShape,
    this.editingShape,
    this.editControllers,
    this.step,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: slide.widthPt,
        height: slide.heightPt,
        child: ClipRect(
          child: Stack(
            children: [
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    color: slide.backgroundGradient == null
                        ? (slide.background ?? Colors.white)
                        : null,
                    gradient: slide.backgroundGradient,
                  ),
                  child: slide.backgroundImage == null
                      ? null
                      : Image.memory(
                          slide.backgroundImage!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const SizedBox(),
                        ),
                ),
              ),
              for (final shape in slide.shapes) _positioned(shape),
            ],
          ),
        ),
      ),
    );
  }

  Widget _positioned(ShapeVM s) {
    // Animasyonlu içerik: adımı gelmemiş şekil/paragraf saydamdır (yer tutar,
    // böylece belirdiğinde yerleşim oynamaz — PowerPoint de böyle yapar).
    final animated = step != null && slide.steps.isNotEmpty;
    List<bool>? paraVisible;
    var shapeVisible = true;
    if (animated) {
      final shapeStep = slide.stepFor(s.id, -1);
      shapeVisible = shapeStep == 0 || step! >= shapeStep;
      paraVisible = [
        for (var i = 0; i < s.paragraphs.length; i++)
          slide.stepFor(s.id, i) == 0 || step! >= slide.stepFor(s.id, i),
      ];
    }

    final editing = editingShape != null && identical(s, editingShape);
    Widget child = _ShapeBody(
      shape: s,
      paraVisible: paraVisible,
      editControllers: editing ? editControllers : null,
    );
    if (animated) child = _Reveal(visible: shapeVisible, child: child);
    if (s.rotationDeg != 0) {
      child = Transform.rotate(angle: s.rotationDeg * math.pi / 180, child: child);
    }
    if (editing) {
      // Aktif kutuyu çerçeveyle belirt; dokunuşlar içteki TextField'lara gitsin
      // (onTap sarmalamayı atla, yoksa düzenlemeyi yeniden tetikler).
      child = DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFF2962FF), width: 1.2),
        ),
        child: child,
      );
    } else if (onEditShape != null && s.hasText) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onEditShape!(s),
        child: child,
      );
    }
    // Yatay/dikey çizginin tek boyutu 0 olabilir → çizim için stroke kadar taban ver.
    final floor = math.max(s.strokeWidth, 1.0);
    return Positioned(
      left: s.x,
      top: s.y,
      width: s.isLine ? math.max(s.w, floor) : s.w,
      height: s.isLine ? math.max(s.h, floor) : s.h,
      child: child,
    );
  }
}

/// Adımı gelen içeriği hafifçe yukarı kayarak belirtir — jenerik ama
/// PowerPoint'teki "beliriş" hissini verir.
class _Reveal extends StatelessWidget {
  final bool visible;
  final Widget child;
  const _Reveal({required this.visible, required this.child});

  @override
  Widget build(BuildContext context) {
    // Yapı iki durumda da aynı kalmalı, yoksa geçiş animasyonu oynamaz.
    return AnimatedOpacity(
      opacity: visible ? 1 : 0,
      duration: const Duration(milliseconds: 260),
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 0.06),
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class _ShapeBody extends StatelessWidget {
  final ShapeVM shape;

  /// Paragraf bazlı görünürlük (animasyon adımları). null = hepsi görünür.
  final List<bool>? paraVisible;

  /// Canlı düzenleme denetleyicileri (paragraf indeksiyle hizalı). null = statik.
  final List<TextEditingController?>? editControllers;

  const _ShapeBody({required this.shape, this.paraVisible, this.editControllers});

  @override
  Widget build(BuildContext context) {
    // Bağlayıcı/çizgi: kutu değil, köşe-köşe stroke (ok/kesik dahil).
    if (shape.isLine) {
      return CustomPaint(painter: _LinePainter(shape), size: Size.infinite);
    }

    final decoration = BoxDecoration(
      color: shape.gradient == null ? shape.fill : null,
      gradient: shape.gradient,
      shape: shape.isEllipse ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: shape.isEllipse || shape.cornerRadius == 0
          ? null
          : BorderRadius.circular(shape.cornerRadius),
      border: shape.stroke == null
          ? null
          : Border.all(color: shape.stroke!, width: shape.strokeWidth),
      boxShadow: shape.shadow == null ? null : [shape.shadow!],
    );

    if (shape.image != null) {
      return ClipRect(
        child: Container(
          decoration: decoration,
          child: Image.memory(
            shape.image!,
            fit: BoxFit.fill,
            errorBuilder: (_, __, ___) => const SizedBox(),
          ),
        ),
      );
    }

    return Container(
      decoration: decoration,
      child: shape.hasText ? _text(shape) : null,
    );
  }

  /// Metin kutusu: PowerPoint'te olduğu gibi sığmayan yazı kutunun dışına taşar
  /// (kırpılmaz). [OverflowBox] hem taşmayı serbest bırakır hem de dikey
  /// hizalamayı (üst/orta/alt) uygular. Fontlar artık metrik-uyumlu (Carlito/
  /// Arimo/Tinos) gömülü olduğu için ölçüm PowerPoint'le hemen hemen aynı;
  /// `_fitScale` çoğu kutuda 1 döner, yalnız gerçek taşmada devreye girer.
  Widget _text(ShapeVM s) {
    Alignment alignment;
    switch (s.vAnchor) {
      case 'ctr':
        alignment = Alignment.center;
        break;
      case 'b':
        alignment = Alignment.bottomCenter;
        break;
      default:
        alignment = Alignment.topCenter;
    }

    // Sığdırma TÜM metin kutularına güvenlik ağı olarak uygulanır: metrik-uyumlu
    // fontlarla ölçüm artık doğru (gerçekten sığan kutuda 1 döner), ama bir kutu
    // yine de taşarsa (yazar taşırmış ya da kenar durumu) komşu kutuların üstüne
    // binmesin diye küçültülür — okunurluk > birebir sadakat (kök neden #3).
    var scale = s.fontScale * _fitScale(s, s.fontScale);

    return OverflowBox(
      alignment: alignment,
      minHeight: 0,
      maxHeight: double.infinity,
      child: Padding(
        padding: s.inset,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < s.paragraphs.length; i++)
              if (_editCtrl(i) != null)
                // Canlı düzenleme: kutunun yerinde, aynı ölçekte TextField.
                _paragraph(s.paragraphs[i], scale, s.lnSpcReduction,
                    edit: _editCtrl(i))
              else if (s.paragraphs[i].plainText.isNotEmpty)
                paraVisible == null
                    ? _paragraph(s.paragraphs[i], scale, s.lnSpcReduction)
                    : _Reveal(
                        visible: paraVisible![i],
                        child:
                            _paragraph(s.paragraphs[i], scale, s.lnSpcReduction),
                      ),
          ],
        ),
      ),
    );
  }

  /// Kutuya sığması için gereken ek ölçek (1 = küçültme gerekmez).
  double _fitScale(ShapeVM s, double baseScale) {
    final availW = s.w - s.inset.horizontal;
    final availH = s.h - s.inset.vertical;
    if (availW <= 0 || availH <= 0) return 1;

    double measure(double sc) {
      var total = 0.0;
      for (final p in s.paragraphs) {
        if (p.plainText.isEmpty) continue;
        final tp = TextPainter(
          text: _span(p, sc, s.lnSpcReduction),
          textAlign: p.align,
          textDirection: TextDirection.ltr,
        )..layout(
            maxWidth: math.max(
                1, availW - p.indentPt - (p.bullet.isEmpty ? 0 : 14)));
        total += tp.height + p.spaceBeforePt;
        tp.dispose();
      }
      return total;
    }

    final total = measure(baseScale);
    if (total <= 0 || total <= availH) return 1;
    // Tek geçişli oran güvenli üst sınır sanılıyordu ama sarma yüzünden
    // yetmeyebiliyor: font küçülünce satır sayısı her zaman aynı oranda
    // azalmaz (uzun kelimeler yeniden sarar). İkinci ölçüm turu gerçek
    // yüksekliği doğrular, hâlâ taşıyorsa oranı bir kez daha sıkar.
    var fit = availH / total;
    final second = measure(baseScale * math.max(0.35, fit));
    if (second > availH) fit *= availH / second;
    return math.max(0.35, fit);
  }

  TextSpan _span(ParaVM p, double fontScale, double lnSpcReduction) {
    return TextSpan(
      children: [
        for (final r in p.runs)
          TextSpan(
            text: r.text,
            style: TextStyle(
              fontFamily: r.fontFamily,
              fontSize: r.sizePt * fontScale,
              fontWeight: r.bold ? FontWeight.bold : FontWeight.normal,
              fontStyle: r.italic ? FontStyle.italic : FontStyle.normal,
              decoration:
                  r.underline ? TextDecoration.underline : TextDecoration.none,
              color: r.color,
              height: p.lineHeight * (1 - lnSpcReduction),
            ),
          ),
      ],
    );
  }

  TextEditingController? _editCtrl(int i) =>
      editControllers != null && i < editControllers!.length
          ? editControllers![i]
          : null;

  Widget _paragraph(ParaVM p, double fontScale, double lnSpcReduction,
      {TextEditingController? edit}) {
    final first = p.runs.isEmpty ? null : p.runs.first;
    final Widget body = edit == null
        ? Text.rich(_span(p, fontScale, lnSpcReduction), textAlign: p.align)
        // Yerinde düzenleme kutusu: paragrafın ilk çalıştırma biçiminde, çerçevesiz.
        : TextField(
            controller: edit,
            maxLines: null,
            textAlign: p.align,
            cursorColor: const Color(0xFF2962FF),
            style: TextStyle(
              fontFamily: first?.fontFamily,
              fontSize: (first?.sizePt ?? 18) * fontScale,
              fontWeight: first?.bold == true ? FontWeight.bold : FontWeight.normal,
              fontStyle: first?.italic == true ? FontStyle.italic : FontStyle.normal,
              decoration: first?.underline == true
                  ? TextDecoration.underline
                  : TextDecoration.none,
              color: first?.color,
              height: p.lineHeight * (1 - lnSpcReduction),
            ),
            decoration: const InputDecoration(
              isCollapsed: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          );

    return Padding(
      padding: EdgeInsets.only(top: p.spaceBeforePt, left: p.indentPt),
      child: p.bullet.isEmpty
          ? body
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Text(
                    p.bullet,
                    style: TextStyle(
                      fontFamily: first?.fontFamily,
                      fontSize: (first?.sizePt ?? 18) * fontScale,
                      color: first?.color,
                      height: p.lineHeight * (1 - lnSpcReduction),
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }
}

/// Bağlayıcı/çizgi çizer: kutunun köşesinden karşı köşesine (flip'e göre) bir
/// stroke; kesikliyse kesik, uçlarda ok başı. Eğik/kavisli bağlayıcı düz
/// çizgiyle yaklaşıklanır (uç noktalar aynı kalır).
class _LinePainter extends CustomPainter {
  final ShapeVM s;
  const _LinePainter(this.s);

  @override
  void paint(Canvas canvas, Size size) {
    final color = s.stroke ?? const Color(0xFF000000);
    final sw = s.strokeWidth <= 0 ? 1.0 : s.strokeWidth;
    final start = Offset(s.flipH ? size.width : 0, s.flipV ? size.height : 0);
    final end = Offset(s.flipH ? 0 : size.width, s.flipV ? 0 : size.height);

    final paint = Paint()
      ..color = color
      ..strokeWidth = sw
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    if (s.dashed) {
      _dash(canvas, start, end, paint, sw);
    } else {
      canvas.drawLine(start, end, paint);
    }

    if (s.arrowEnd) _arrow(canvas, start, end, color, sw);
    if (s.arrowStart) _arrow(canvas, end, start, color, sw);
  }

  /// [to] ucunda, [from]→[to] yönünde dolu üçgen ok başı.
  void _arrow(Canvas canvas, Offset from, Offset to, Color color, double sw) {
    final dir = to - from;
    final len = dir.distance;
    if (len < 0.01) return;
    final u = dir / len;
    final head = math.max(sw * 3.5, 6.0); // ok boyu çizgi kalınlığıyla ölçekli
    final perp = Offset(-u.dy, u.dx);
    final base = to - u * head;
    final path = Path()
      ..moveTo(to.dx, to.dy)
      ..lineTo(base.dx + perp.dx * head * 0.5, base.dy + perp.dy * head * 0.5)
      ..lineTo(base.dx - perp.dx * head * 0.5, base.dy - perp.dy * head * 0.5)
      ..close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.fill);
  }

  void _dash(Canvas canvas, Offset a, Offset b, Paint paint, double sw) {
    final total = (b - a).distance;
    if (total < 0.01) return;
    final u = (b - a) / total;
    final dash = sw * 4, gap = sw * 3;
    var d = 0.0;
    while (d < total) {
      canvas.drawLine(
          a + u * d, a + u * math.min(d + dash, total), paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(_LinePainter old) => old.s != s;
}

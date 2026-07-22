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

  /// Kaçıncı animasyon adımına kadar görünsün. null = her şey görünür
  /// (düzenleme görünümü). Sunum modunda 0'dan başlar, her tıklamada artar.
  final int? step;

  const SlideCanvas({
    super.key,
    required this.slide,
    this.onEditShape,
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

    Widget child = _ShapeBody(shape: s, paraVisible: paraVisible);
    if (animated) child = _Reveal(visible: shapeVisible, child: child);
    if (s.rotationDeg != 0) {
      child = Transform.rotate(angle: s.rotationDeg * math.pi / 180, child: child);
    }
    if (onEditShape != null && s.hasText) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onEditShape!(s),
        child: child,
      );
    }
    return Positioned(
      left: s.x,
      top: s.y,
      width: s.w,
      height: s.h,
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

  const _ShapeBody({required this.shape, this.paraVisible});

  @override
  Widget build(BuildContext context) {
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
  /// hizalamayı (üst/orta/alt) uygular. `normAutofit` olan kutularda PowerPoint
  /// yazıyı SIĞDIRDIĞI için biz de ölçüp gereken ek küçültmeyi uygularız —
  /// font metriği farkından (Calibri ≠ Roboto) doğan taşmayı da bu kapatır.
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

    // Yer tutucular da sığdırılır: PowerPoint autofit'i çoğu dosyada şablonda
    // saklar, şeklin kendi bodyPr'inde görünmez (yazı-taşması kök nedeni #2).
    var scale = s.fontScale;
    if (s.autofit || s.isPlaceholder) scale *= _fitScale(s, scale);

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
              if (s.paragraphs[i].plainText.isNotEmpty)
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
  /// Font küçülünce satır sayısı da azalacağı için oran güvenli üst sınırdır.
  double _fitScale(ShapeVM s, double baseScale) {
    final availW = s.w - s.inset.horizontal;
    final availH = s.h - s.inset.vertical;
    if (availW <= 0 || availH <= 0) return 1;

    var total = 0.0;
    for (final p in s.paragraphs) {
      if (p.plainText.isEmpty) continue;
      final tp = TextPainter(
        text: _span(p, baseScale, s.lnSpcReduction),
        textAlign: p.align,
        textDirection: TextDirection.ltr,
      )..layout(
          maxWidth: math.max(
              1, availW - p.indentPt - (p.bullet.isEmpty ? 0 : 14)));
      total += tp.height + p.spaceBeforePt;
      tp.dispose();
    }
    if (total <= 0 || total <= availH) return 1;
    // ponytail: tek geçişli oran; yetmediği görülürse ikinci ölçüm turu eklenir
    return math.max(0.4, availH / total);
  }

  TextSpan _span(ParaVM p, double fontScale, double lnSpcReduction) {
    return TextSpan(
      children: [
        for (final r in p.runs)
          TextSpan(
            text: r.text,
            style: TextStyle(
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

  Widget _paragraph(ParaVM p, double fontScale, double lnSpcReduction) {
    final body = Text.rich(_span(p, fontScale, lnSpcReduction), textAlign: p.align);
    final first = p.runs.isEmpty ? null : p.runs.first;

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

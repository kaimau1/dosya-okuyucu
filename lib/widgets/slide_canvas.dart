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

  const SlideCanvas({super.key, required this.slide, this.onEditShape});

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
                  color: slide.background ?? Colors.white,
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
    Widget child = _ShapeBody(shape: s);
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

class _ShapeBody extends StatelessWidget {
  final ShapeVM shape;
  const _ShapeBody({required this.shape});

  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      color: shape.fill,
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
  /// hizalamayı (üst/orta/alt) uygular.
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
            for (final p in s.paragraphs)
              if (p.plainText.isNotEmpty) _paragraph(p, s.fontScale),
          ],
        ),
      ),
    );
  }

  Widget _paragraph(ParaVM p, double fontScale) {
    final span = TextSpan(
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
              height: p.lineHeight,
            ),
          ),
      ],
    );

    final body = Text.rich(span, textAlign: p.align);
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
                      height: p.lineHeight,
                    ),
                  ),
                ),
                Expanded(child: body),
              ],
            ),
    );
  }
}

part of 'docx_editor_view.dart';

/// İmleç, seçim ve yazım hatası çizgisi.
class _ParaPainter extends CustomPainter {
  final DocxEditController c;
  final int i;
  final GlobalKey key;
  final List<SuggestionSpan>? spell;
  final ValueNotifier<bool>? caretOn;
  _ParaPainter(this.c, this.i, this.key, this.spell, this.caretOn)
      : super(repaint: caretOn);

  @override
  void paint(Canvas canvas, Size size) {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    if (i >= c.paras.length) return;
    final len = c.paras[i].length;
    final sp = spell;
    if (sp != null) {
      final red = Paint()
        ..color = AppHues.red
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (final s in sp) {
        if (s.range.end > len) continue;
        for (final b in ro.getBoxesForSelection(
            TextSelection(baseOffset: s.range.start, extentOffset: s.range.end))) {
          final r = b.toRect();
          final path = Path()..moveTo(r.left, r.bottom);
          for (var x = r.left; x < r.right; x += 4) {
            path.lineTo(x + 2, r.bottom + ((x - r.left) ~/ 2 % 2 == 0 ? 2 : -0.5));
          }
          canvas.drawPath(path, red);
        }
      }
    }
    final s = c.start, e = c.end;
    if (c.collapsed) {
      if (i != c.extent.para || !c.attached) return;
      if (caretOn != null && !caretOn!.value) return;
      final off = c.extent.offset.clamp(0, len);
      final at = ro.getOffsetForCaret(TextPosition(offset: off), Rect.zero);
      final h = ro.getFullHeightForCaret(TextPosition(offset: off));
      canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, 2, h),
          Paint()..color = AppColors.slideSelection);
      return;
    }
    if (i < s.para || i > e.para) return;
    final from = i == s.para ? s.offset : 0;
    final to = i == e.para ? e.offset : len;
    final paint = Paint()
      ..color = AppColors.slideSelection.withValues(alpha: 0.22);
    for (final b in ro.getBoxesForSelection(
        TextSelection(baseOffset: from, extentOffset: to))) {
      canvas.drawRect(b.toRect(), paint);
    }
    // Boş paragraf seçimdeyse küçük bir işaret.
    if (from == to && len == 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, 6, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_ParaPainter old) => true;
}


/// Resim atomu: seçiliyken çerçeve + sağ alt köşede oran kilitli
/// boyutlandırma tutamağı (sürüklerken canlı önizleme, bırakınca yazılır).
class _ImageAtom extends StatefulWidget {
  final DocxAtom atom;
  final double scale, maxW;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<double> onResize;
  const _ImageAtom({
    super.key,
    required this.atom,
    required this.scale,
    required this.maxW,
    required this.selected,
    required this.onTap,
    required this.onResize,
  });

  @override
  State<_ImageAtom> createState() => _ImageAtomState();
}

class _ImageAtomState extends State<_ImageAtom> {
  double? _dragW; // sürüklenirken ekran genişliği

  @override
  Widget build(BuildContext context) {
    final a = widget.atom;
    final natural = a.widthPt <= 0 ? widget.maxW : a.widthPt * widget.scale;
    final w = math.min(widget.maxW, _dragW ?? natural);
    final ratio = a.widthPt <= 0 ? null : a.heightPt / math.max(1, a.widthPt);
    final h = ratio == null ? null : w * ratio;
    Widget img = a.image == null
        ? SizedBox(width: w, height: h ?? 40, child: const Placeholder())
        : Image.memory(a.image!,
            width: w,
            height: h,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SizedBox(width: w, height: h ?? 40));
    img = GestureDetector(onTap: widget.onTap, child: img);
    if (!widget.selected) return img;
    const hs = 22.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.slideSelection, width: 2)),
          child: img,
        ),
        // Tutamak resmin İÇİNDE (köşede): dışarı taşan parça WidgetSpan'in
        // vuruş alanı dışında kalır, dokunuş ulaşmaz.
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: GestureDetector(
            key: const ValueKey('docx-img-handle'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _dragW = w),
            onPanUpdate: (d) => setState(() => _dragW =
                ((_dragW ?? w) + d.delta.dx).clamp(24.0, widget.maxW)),
            onPanEnd: (_) {
              final px = _dragW;
              setState(() => _dragW = null);
              if (px != null) widget.onResize(px / widget.scale);
            },
            child: Container(
              width: hs,
              height: hs,
              decoration: BoxDecoration(
                color: AppColors.page,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.slideSelection, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

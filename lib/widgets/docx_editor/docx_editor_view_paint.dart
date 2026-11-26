part of 'docx_editor_view.dart';

/// İmleç, seçim ve yazım hatası çizgisi.
class _ParaPainter extends CustomPainter {
  final DocxEditController c;
  final int i;
  final GlobalKey key;
  final List<SuggestionSpan>? spell;
  final ValueNotifier<bool>? caretOn;
  final int _len;
  final bool _collapsed;
  final bool _attached;
  final DocPos _start;
  final DocPos _end;
  final bool _inSelection;

  _ParaPainter(this.c, this.i, this.key, this.spell, this.caretOn)
      : _len = i < c.paras.length ? c.paras[i].length : -1,
        _collapsed = c.collapsed,
        _attached = c.attached,
        _start = c.start,
        _end = c.end,
        _inSelection = c.collapsed
            ? (i == c.extent.para && c.attached)
            : (i >= c.start.para && i <= c.end.para),
        super(repaint: caretOn);

  @override
  void paint(Canvas canvas, Size size) {
    final s = c.start, e = c.end;
    final hasWork = (spell != null && spell!.isNotEmpty) ||
        (c.collapsed
            ? (i == c.extent.para &&
                c.attached &&
                (caretOn == null || caretOn!.value))
            : (i >= s.para && i <= e.para));
    if (!hasWork) return;
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
  bool shouldRepaint(_ParaPainter old) =>
      old.i != i ||
      old.key != key ||
      old.caretOn != caretOn ||
      !identical(old.spell, spell) ||
      old._len != _len ||
      old._collapsed != _collapsed ||
      old._attached != _attached ||
      old._inSelection != _inSelection ||
      (_inSelection && (old._start != _start || old._end != _end));
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
            // B12 m.4: belgeye gömülü fotoğraf tam çözünürlükte açılmasın.
            // Genişlik sayfa genişliğinden (sürüklemede sabit; kademeli —
            // her boyutlandırma karesinde yeniden çözme olmasın).
            cacheWidth: ImageBudget.decodeWidth(
                logicalWidth: widget.maxW,
                devicePixelRatio: MediaQuery.devicePixelRatioOf(context)),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, _, _) => SizedBox(width: w, height: h ?? 40));
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scheme = Theme.of(context).colorScheme;
    final accent = PdfEditTokens.imageAccent(dark);
    img = GestureDetector(onTap: widget.onTap, child: img);
    if (!widget.selected) {
      return DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(Radii.xs),
          border: Border.all(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
            width: 1,
          ),
        ),
        child: img,
      );
    }
    const hs = 28.0;
    const dot = 10.0;
    final pct = widget.maxW <= 0
        ? 100
        : ((w / widget.maxW) * 100).round().clamp(1, 100);
    final ptW = (w / math.max(0.1, widget.scale)).round();

    Widget cornerDot() => IgnorePointer(
          child: Container(
            width: dot,
            height: dot,
            decoration: BoxDecoration(
              color: AppColors.page,
              shape: BoxShape.circle,
              border: Border.all(color: accent, width: 2),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shade.withValues(alpha: 0.25),
                  blurRadius: 3,
                ),
              ],
            ),
          ),
        );

    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: PdfEditTokens.objectSelectedFillAlpha),
            border: Border.all(color: accent, width: 2.2),
            borderRadius: BorderRadius.circular(Radii.xs),
          ),
          child: img,
        ),
        PositionedDirectional(start: 3, top: 3, child: cornerDot()),
        PositionedDirectional(end: 3, top: 3, child: cornerDot()),
        PositionedDirectional(start: 3, bottom: 3, child: cornerDot()),
        // Tutamak resmin İÇİNDE (köşede): dışarı taşan parça WidgetSpan'in
        // vuruş alanı dışında kalır, dokunuş ulaşmaz.
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: GestureDetector(
            key: const ValueKey('docx-img-handle'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) {
              AppHaptics.selection();
              setState(() => _dragW = w);
            },
            onPanUpdate: (d) => setState(() => _dragW =
                ((_dragW ?? w) + d.delta.dx).clamp(24.0, widget.maxW)),
            onPanEnd: (_) {
              final px = _dragW;
              setState(() => _dragW = null);
              if (px != null) widget.onResize(px / widget.scale);
            },
            child: SizedBox(
              width: hs,
              height: hs,
              child: Center(
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: accent,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.page, width: 2.2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shade.withValues(alpha: 0.30),
                        blurRadius: 5,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: const Icon(
                    AppIcons.sizeScale,
                    size: 12,
                    color: AppColors.page,
                  ),
                ),
              ),
            ),
          ),
        ),
        if (_dragW != null)
          PositionedDirectional(
            start: 6,
            top: 6,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm, vertical: 3),
                decoration: BoxDecoration(
                  color: PdfEditTokens.badgeBg,
                  borderRadius: BorderRadius.circular(Radii.pill),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.shade.withValues(alpha: 0.28),
                      blurRadius: 6,
                    ),
                  ],
                ),
                child: Text(
                  '%$pct · $ptW pt',
                  style: PdfEditTokens.canvasBadgeStyle(
                      PdfEditTokens.onBadge, 1.0),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../services/pptx_editor.dart';

/// **Slayt tasarım levhalarının önizlemeleri** (2026-11-24, kullanıcı:
/// *"slide tasarım alanlarında kuru simgeler değil, ne olacağı önizlemelerle
/// gözükmeli"*).
///
/// * [SlideLayoutThumb]: düzenin yer tutucularını (başlık, alt başlık,
///   içerik, resim, tablo, grafik) gerçek konumlarıyla küçük bir slaytta
///   çizer.
/// * [SlideTransitionThumb]: geçişi iki küçük slayt arasında oynatır (birkaç
///   tur, sonra B'de durur — sonsuz döngü yok: pil ve testlerde
///   `pumpAndSettle`).
/// * [SlidePreviewTile]: önizleme + ad, seçili hâl çerçevesiyle.

/// Önizleme + ad kutusu (düzen ve geçiş galerileri).
class SlidePreviewTile extends StatelessWidget {
  const SlidePreviewTile({
    super.key,
    required this.preview,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.width = 108,
  });

  final Widget preview;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(Radii.card);
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        excludeSemantics: true,
        child: Material(
          color: selected ? scheme.primaryContainer : scheme.surfaceContainerLow,
          shape: RoundedRectangleBorder(
            borderRadius: radius,
            side: BorderSide(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.8 : 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(6, 6, 6, Gap.sm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  preview,
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w600,
                          color: selected
                              ? scheme.onPrimaryContainer
                              : scheme.onSurface,
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

/// Düzenin küçük slayt çizimi.
class SlideLayoutThumb extends StatelessWidget {
  const SlideLayoutThumb(
      {super.key, required this.boxes, this.aspect = 16 / 9});

  final List<PptxLayoutBox> boxes;
  final double aspect;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: aspect.clamp(0.5, 3.0),
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _LayoutPainter(
            boxes,
            paper: scheme.surface,
            frame: scheme.outlineVariant,
            accent: scheme.primary,
            ink: scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _LayoutPainter extends CustomPainter {
  _LayoutPainter(this.boxes,
      {required this.paper,
      required this.frame,
      required this.accent,
      required this.ink});

  final List<PptxLayoutBox> boxes;
  final Color paper, frame, accent, ink;

  @override
  void paint(Canvas canvas, Size size) {
    final r = RRect.fromRectAndRadius(
        Offset.zero & size, const Radius.circular(Radii.xs));
    canvas.drawRRect(r, Paint()..color = paper);
    canvas.drawRRect(
        r,
        Paint()
          ..color = frame
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1);
    final outline = Paint()
      ..color = frame.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8;
    for (final b in boxes) {
      final rect = Rect.fromLTWH(b.x * size.width, b.y * size.height,
          b.w * size.width, b.h * size.height);
      if (rect.width < 2 || rect.height < 2) continue;
      canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)), outline);
      _content(canvas, size, b.type, rect.deflate(2));
    }
  }

  void _content(Canvas canvas, Size size, String type, Rect rect) {
    final unit = size.height / 18;
    switch (type) {
      case 'title' || 'ctrTitle':
        final h = (rect.height * 0.42).clamp(2.0, unit * 1.8);
        final w = rect.width * 0.72;
        final left =
            type == 'ctrTitle' ? rect.center.dx - w / 2 : rect.left + 1;
        _bar(canvas, Rect.fromLTWH(left, rect.center.dy - h / 2, w, h),
            accent);
      case 'subTitle':
        final h = (rect.height * 0.3).clamp(1.5, unit * 1.1);
        final w = rect.width * 0.5;
        _bar(
            canvas,
            Rect.fromLTWH(rect.center.dx - w / 2, rect.center.dy - h / 2, w, h),
            accent.withValues(alpha: 0.45));
      case 'pic' || 'clipArt' || 'media':
        canvas.drawRect(rect, Paint()..color = accent.withValues(alpha: 0.12));
        final s = rect.shortestSide;
        final path = Path()
          ..moveTo(rect.center.dx - s * 0.35, rect.center.dy + s * 0.25)
          ..lineTo(rect.center.dx - s * 0.05, rect.center.dy - s * 0.12)
          ..lineTo(rect.center.dx + s * 0.12, rect.center.dy + s * 0.08)
          ..lineTo(rect.center.dx + s * 0.22, rect.center.dy - s * 0.02)
          ..lineTo(rect.center.dx + s * 0.38, rect.center.dy + s * 0.25)
          ..close();
        canvas.drawPath(path, Paint()..color = accent.withValues(alpha: 0.55));
        canvas.drawCircle(
            Offset(rect.center.dx + s * 0.18, rect.center.dy - s * 0.2),
            s * 0.07,
            Paint()..color = accent.withValues(alpha: 0.55));
      case 'tbl':
        final p = Paint()
          ..color = ink.withValues(alpha: 0.45)
          ..strokeWidth = 0.8;
        for (var i = 0; i <= 3; i++) {
          final y = rect.top + rect.height * i / 3;
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), p);
          final x = rect.left + rect.width * i / 3;
          canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), p);
        }
      case 'chart' || 'dgm':
        const heights = [0.45, 0.8, 0.6];
        final bw = rect.width / 7;
        for (var i = 0; i < 3; i++) {
          final h = rect.height * heights[i];
          _bar(
              canvas,
              Rect.fromLTWH(rect.left + bw * (1 + i * 2), rect.bottom - h,
                  bw, h),
              accent.withValues(alpha: 0.6),
              radius: 1);
        }
      default:
        // Gövde / içerik: madde imli satırlar.
        final gap = (unit * 1.5).clamp(3.0, 14.0);
        final n = (rect.height / gap).floor().clamp(1, 4);
        const widths = [0.86, 0.7, 0.78, 0.6];
        final dot = Paint()..color = ink.withValues(alpha: 0.6);
        for (var i = 0; i < n; i++) {
          final y = rect.top + gap * (i + 0.6);
          final h = (gap * 0.32).clamp(1.0, 4.0);
          canvas.drawCircle(Offset(rect.left + h, y), h * 0.6, dot);
          _bar(
              canvas,
              Rect.fromLTWH(rect.left + h * 3, y - h / 2,
                  (rect.width - h * 3) * widths[i], h),
              ink.withValues(alpha: 0.4));
        }
    }
  }

  void _bar(Canvas c, Rect r, Color color, {double? radius}) =>
      c.drawRRect(
          RRect.fromRectAndRadius(
              r, Radius.circular(radius ?? r.height / 2)),
          Paint()..color = color);

  @override
  bool shouldRepaint(_LayoutPainter old) =>
      !identical(old.boxes, boxes) ||
      old.paper != paper ||
      old.frame != frame ||
      old.accent != accent ||
      old.ink != ink;
}

/// Geçişin canlandırmalı küçük önizlemesi: A slaytından B slaytına.
class SlideTransitionThumb extends StatefulWidget {
  const SlideTransitionThumb({super.key, required this.kind, this.rounds = 3});

  final PptxTransition kind;

  /// Kaç tur oynasın (sonra B'de durur; anahtar değişince yeniden).
  final int rounds;

  @override
  State<SlideTransitionThumb> createState() => _SlideTransitionThumbState();
}

class _SlideTransitionThumbState extends State<SlideTransitionThumb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: Motion.long * 5);
  int _left = 0;

  @override
  void initState() {
    super.initState();
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed && _left > 1 && mounted) {
        _left--;
        _c.forward(from: 0);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_left == 0 && !_c.isAnimating) _play();
  }

  void _play() {
    if (widget.kind == PptxTransition.none || Motion.reduced(context)) {
      _c.value = 1;
      return;
    }
    _left = widget.rounds;
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final a = _MiniSlide(
        background: scheme.surfaceContainerHighest, ink: scheme.outline);
    final b = _MiniSlide(
        background: scheme.primaryContainer, ink: scheme.primary);
    return AspectRatio(
        aspectRatio: 16 / 9,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(Radii.xs),
          child: RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (_, _) {
                // 0–0,2 A durur · 0,2–0,75 geçiş · 0,75–1 B durur.
                final p = Curves.easeInOutCubic
                    .transform(((_c.value - 0.2) / 0.55).clamp(0.0, 1.0));
                return _frame(a, b, p, scheme.primary);
              },
            ),
          ),
        ),
    );
  }

  Widget _frame(Widget a, Widget b, double p, Color accent) {
    switch (widget.kind) {
      case PptxTransition.none:
        return b;
      case PptxTransition.fade:
        return Stack(fit: StackFit.expand, children: [
          a,
          Opacity(opacity: p, child: b),
        ]);
      case PptxTransition.push:
        return Stack(fit: StackFit.expand, children: [
          FractionalTranslation(translation: Offset(-p, 0), child: a),
          FractionalTranslation(translation: Offset(1 - p, 0), child: b),
        ]);
      case PptxTransition.wipe:
        return Stack(fit: StackFit.expand, children: [
          a,
          ClipRect(
            child: Align(
              // Silme yönü slaytın kendisinin (fiziksel): arayüz diliyle
              // aynalanmaz — bkz. slideTransitionFx.
              alignment: const Alignment(-1, 0),
              widthFactor: p.clamp(0.001, 1.0),
              child: b,
            ),
          ),
        ]);
      case PptxTransition.zoom:
        return Stack(fit: StackFit.expand, children: [
          a,
          Opacity(
            opacity: p,
            child: Transform.scale(scale: 0.55 + 0.45 * p, child: b),
          ),
        ]);
      case PptxTransition.morph:
        return CustomPaint(painter: _MorphPainter(p, accent));
    }
  }
}

/// İki çubuklu basit slayt (başlık + gövde).
class _MiniSlide extends StatelessWidget {
  const _MiniSlide({required this.background, required this.ink});
  final Color background, ink;

  @override
  Widget build(BuildContext context) => CustomPaint(
      painter: _MiniSlidePainter(background, ink), size: Size.infinite);
}

class _MiniSlidePainter extends CustomPainter {
  _MiniSlidePainter(this.background, this.ink);
  final Color background, ink;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = background);
    final u = size.height / 9;
    void bar(double y, double w, double h, double a) => canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.12, y, size.width * w, h),
            Radius.circular(h / 2)),
        Paint()..color = ink.withValues(alpha: a));
    bar(u * 1.6, 0.6, u * 1.2, 0.9);
    bar(u * 4, 0.7, u * 0.55, 0.5);
    bar(u * 5.2, 0.55, u * 0.55, 0.5);
    bar(u * 6.4, 0.62, u * 0.55, 0.5);
  }

  @override
  bool shouldRepaint(_MiniSlidePainter old) =>
      old.background != background || old.ink != ink;
}

/// "Biçim değiştir": aynı şekil yerinden/boyundan yenisine kayar.
class _MorphPainter extends CustomPainter {
  _MorphPainter(this.p, this.accent);
  final double p;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size,
        Paint()..color = accent.withValues(alpha: 0.08));
    final from = Rect.fromLTWH(size.width * 0.1, size.height * 0.15,
        size.width * 0.22, size.height * 0.3);
    final to = Rect.fromLTWH(size.width * 0.45, size.height * 0.3,
        size.width * 0.45, size.height * 0.55);
    final r = Rect.lerp(from, to, p)!;
    canvas.drawRRect(
        RRect.fromRectAndRadius(r, Radius.circular(r.shortestSide * (0.5 - 0.35 * p))),
        Paint()..color = accent.withValues(alpha: 0.75));
  }

  @override
  bool shouldRepaint(_MorphPainter old) => old.p != p || old.accent != accent;
}

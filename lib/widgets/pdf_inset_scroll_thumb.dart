import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/app_haptics.dart';
import '../core/motion.dart';
import '../core/theme.dart';

/// Sağ kenarda sürüklenebilir PDF kaydırma tutamacı — yolu [insets] kadar
/// daralır (üst/alt çubukların altına girmez) ve sürüklenirken parmağın
/// yanında canlı sayfa/yüzde balonu gösterir.
///
/// `viewerOverlayBuilder`'ın döndürdüğü `Stack`in doğrudan çocuğu olmalı.
class PdfInsetScrollThumb extends StatefulWidget {
  final PdfViewerController controller;
  final Size thumbSize;
  final EdgeInsets insets;
  final double margin;
  final int? pageCount;
  final Widget Function(BuildContext context, int? pageNumber)? builder;
  final Widget Function(BuildContext context, int? pageNumber, bool dragging)?
      dragBuilder;

  const PdfInsetScrollThumb({
    super.key,
    required this.controller,
    this.builder,
    this.dragBuilder,
    this.pageCount,
    this.thumbSize = const Size(28, 52),
    this.insets = EdgeInsets.zero,
    this.margin = 0,
  }) : assert(builder != null || dragBuilder != null);

  @override
  State<PdfInsetScrollThumb> createState() => _PdfInsetScrollThumbState();
}

class _PdfInsetScrollThumbState extends State<PdfInsetScrollThumb> {
  double _panStartOffset = 0;
  bool _dragging = false;
  int? _lastTickPage;

  @override
  Widget build(BuildContext context) {
    final ctl = widget.controller;
    if (!ctl.isReady) return const SizedBox();
    final thumb = widget.thumbSize;
    final view = ctl.visibleRect;
    final all = ctl.documentSize;
    final bm = ctl.params.boundaryMargin;
    final noMargin = bm == null || bm.vertical.isInfinite;
    final docH = noMargin ? all.height : all.height + bm.vertical;
    if (docH <= view.height) return const SizedBox();

    final scrollRange = docH - view.height;
    final minScrollY = noMargin ? 0.0 : -bm.top;
    final frac =
        ((-ctl.value.y - minScrollY) / scrollRange).clamp(0.0, 1.0).toDouble();
    final track = view.height * ctl.currentZoom -
        widget.insets.vertical -
        thumb.height;
    if (track <= 0) return const SizedBox();
    final top = widget.insets.top + frac * track;
    final page = ctl.pageNumber;
    final total = widget.pageCount ?? ctl.pageCount;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final thumbChild = widget.dragBuilder != null
        ? widget.dragBuilder!(context, page, _dragging)
        : widget.builder!(context, page);

    // Genişletilmiş kap: sürüklerken tutamacın yanında canlı sayfa balonu açılır.
    const bubbleGap = 10.0;
    return PositionedDirectional(
      end: widget.margin,
      top: top,
      height: thumb.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IgnorePointer(
            child: AnimatedOpacity(
              opacity: _dragging && page != null ? 1.0 : 0.0,
              duration: Motion.of(context, Motion.short),
              child: AnimatedScale(
                scale: _dragging ? 1.0 : 0.86,
                duration: Motion.of(context, Motion.short),
                curve: Motion.standard,
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(end: bubbleGap),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: scheme.inverseSurface.withValues(alpha: 0.94),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: scheme.onInverseSurface.withValues(alpha: 0.14),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.studioShadow(dark),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            total > 0 ? '${page ?? 1} / $total' : '${page ?? 1}',
                            style: context.type.compact.copyWith(
                              color: scheme.onInverseSurface,
                              fontWeight: FontWeight.w800,
                              fontFeatures: const [
                                FontFeature.tabularFigures()
                              ],
                            ),
                          ),
                          if (total > 1) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1.5),
                              decoration: ShapeDecoration(
                                color: scheme.primary.withValues(alpha: 0.85),
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                '%${(frac * 100).round()}',
                                style: context.type.micro.copyWith(
                                  color: scheme.onPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures()
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: thumb.width,
            height: thumb.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                _panStartOffset = top - d.localPosition.dy;
                _lastTickPage = ctl.pageNumber;
                setState(() => _dragging = true);
              },
              onPanUpdate: (d) {
                final pos =
                    _panStartOffset + d.localPosition.dy - widget.insets.top;
                final y = (pos / track).clamp(0.0, 1.0);
                final m = ctl.value.clone();
                m.y = -(y * scrollRange + minScrollY);
                ctl.value = m;
                final cur = ctl.pageNumber;
                if (cur != null && cur != _lastTickPage) {
                  _lastTickPage = cur;
                  AppHaptics.step();
                }
              },
              onPanEnd: (_) => setState(() => _dragging = false),
              onPanCancel: () => setState(() => _dragging = false),
              child: RepaintBoundary(child: thumbChild),
            ),
          ),
        ],
      ),
    );
  }
}

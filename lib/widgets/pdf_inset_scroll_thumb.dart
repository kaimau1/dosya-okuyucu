import 'dart:async';
import 'dart:ui' as ui;

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
///
/// **P22b:** sürüklerken balonun yanında küçük sayfa önizlemesi. Yalnız
/// sürüklerken ve parmak [Motion.short] durunca çizilir (hızlı sürüklemede
/// iş yok); küçük (≈ 96 dp boy) ve son [_previewCap] sayfa önbellekte.
/// Kapatma: `--dart-define=P22B_KAPALI=true`.
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
  bool _bubbleLinger = false;
  Timer? _bubbleLingerTimer;
  int? _lastTickPage;

  static const _previewOn = !bool.fromEnvironment('P22B_KAPALI');
  static const _previewH = 96.0;
  static const _previewCap = 24;
  // ponytail: ekleme sırası = LRU (isabette yeniden eklenir).
  final _previews = <int, ui.Image>{};
  PdfDocument? _previewDoc;
  int? _previewWant;
  Timer? _previewTimer;
  PdfPageRenderCancellationToken? _previewToken;

  @override
  void dispose() {
    _bubbleLingerTimer?.cancel();
    _previewTimer?.cancel();
    _previewToken?.cancel();
    _clearPreviews();
    super.dispose();
  }

  void _clearPreviews() {
    for (final img in _previews.values) {
      img.dispose();
    }
    _previews.clear();
    _previewWant = null;
  }

  ui.Image? _previewFor(int page) {
    final img = _previews.remove(page);
    if (img != null) {
      _previews[page] = img;
    } else if (_previewWant != page) {
      _previewWant = page;
      _previewTimer?.cancel();
      _previewTimer = Timer(Motion.short, () => _renderPreview(page));
    }
    return img;
  }

  Future<void> _renderPreview(int page) async {
    final doc = _previewDoc;
    if (!mounted || !_dragging || doc == null) return;
    if (page < 1 || page > doc.pages.length) return;
    final p = doc.pages[page - 1];
    if (p.height <= 0) return;
    final scale = _previewH * MediaQuery.devicePixelRatioOf(context) / p.height;
    _previewToken?.cancel();
    final token = _previewToken = p.createCancellationToken();
    try {
      final img = await p.renderForDisplay(
        fullWidth: p.width * scale,
        fullHeight: p.height * scale,
        cancellationToken: token,
      );
      if (img == null) return;
      if (!mounted || !identical(doc, _previewDoc)) {
        img.dispose();
        return;
      }
      _previews.remove(page)?.dispose();
      _previews[page] = img;
      while (_previews.length > _previewCap) {
        _previews.remove(_previews.keys.first)?.dispose();
      }
      if (_dragging) setState(() {});
    } catch (_) {
      // Bilinçli: iptal/çizilemeyen sayfa — önizleme yok, balon yine çalışır.
    }
  }

  void _endDrag() {
    _previewTimer?.cancel();
    _previewToken?.cancel();
    _previewWant = null;
    _bubbleLingerTimer?.cancel();
    _bubbleLingerTimer = Timer(Motion.short, () {
      if (mounted && !_dragging) setState(() => _bubbleLinger = false);
    });
    setState(() => _dragging = false);
  }

  Widget _preview(BuildContext context, int page, bool below) {
    if (!_previewOn || !_dragging) return const SizedBox.shrink();
    final ctl = widget.controller;
    final doc = ctl.document;
    if (!identical(doc, _previewDoc)) {
      _clearPreviews();
      _previewDoc = doc;
    }
    final img = _previewFor(page);
    if (img == null) return const SizedBox.shrink();
    final w = _previewH * img.width / img.height;
    final scheme = Theme.of(context).colorScheme;
    return PositionedDirectional(
      end: 10,
      top: below ? null : -(_previewH + 8),
      bottom: below ? -(_previewH + 8) : null,
      width: w,
      height: _previewH,
      child: DecoratedBox(
        key: const ValueKey('pdf-thumb-preview'),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: scheme.outlineVariant),
          boxShadow: [
            BoxShadow(
              color: AppColors.studioShadow(
                  Theme.of(context).brightness == Brightness.dark),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: RawImage(image: img, fit: BoxFit.fill),
        ),
      ),
    );
  }

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
    final thumbChild = widget.dragBuilder != null
        ? widget.dragBuilder!(context, page, _dragging)
        : widget.builder!(context, page);

    Widget bubbleWidget() {
      if (!_dragging && !_bubbleLinger) return const SizedBox.shrink();
      final scheme = Theme.of(context).colorScheme;
      final dark = Theme.of(context).brightness == Brightness.dark;
      const bubbleGap = 10.0;
      final Widget bubble = Padding(
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  total > 0 ? '${page ?? 1} / $total' : '${page ?? 1}',
                  style: context.type.compact.copyWith(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
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
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      return IgnorePointer(
        child: AnimatedOpacity(
          opacity: _dragging && page != null ? 1.0 : 0.0,
          duration: Motion.of(context, Motion.short),
          child: AnimatedScale(
            scale: _dragging ? 1.0 : 0.86,
            duration: Motion.of(context, Motion.short),
            curve: Motion.standard,
            // Önizleme Stack'i yalnız sürüklerken: açılış/kaydırmada ağaç
            // P22b öncesiyle aynı (önizleme hiç kurulmaz).
            child: _previewOn && _dragging && page != null
                ? Stack(
                    clipBehavior: Clip.none,
                    children: [
                      bubble,
                      _preview(context, page, frac < 0.5),
                    ],
                  )
                : bubble,
          ),
        ),
      );
    }

    return PositionedDirectional(
      end: widget.margin,
      top: top,
      height: thumb.height,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          bubbleWidget(),
          SizedBox(
            width: thumb.width,
            height: thumb.height,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onPanStart: (d) {
                _bubbleLingerTimer?.cancel();
                _panStartOffset = top - d.localPosition.dy;
                _lastTickPage = ctl.pageNumber;
                setState(() {
                  _dragging = true;
                  _bubbleLinger = true;
                });
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
              onPanEnd: (_) => _endDrag(),
              onPanCancel: _endDrag,
              child: RepaintBoundary(child: thumbChild),
            ),
          ),
        ],
      ),
    );
  }
}

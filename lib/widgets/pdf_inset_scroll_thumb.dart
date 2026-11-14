import 'package:flutter/widgets.dart';
import 'package:pdfrx/pdfrx.dart';

/// Sağ kenarda sürüklenebilir PDF kaydırma tutamacı — pdfrx'in
/// `PdfViewerScrollThumb`'ıyla aynı hesap, ama yolu [insets] kadar daralır.
///
/// Neden (kullanıcı 2026-11-14): görüntüleyici okuma kipinde üst/alt
/// çubukların ALTINA uzanıyor; pdfrx tutamacı bütün yüksekliği kullandığı için
/// belgenin başında tutamaç üst panelin altına giriyordu. Burada yol üstte
/// [insets.top]'tan başlar, altta [insets.bottom]'da biter.
///
/// `viewerOverlayBuilder`'ın döndürdüğü `Stack`in doğrudan çocuğu olmalı.
class PdfInsetScrollThumb extends StatefulWidget {
  final PdfViewerController controller;
  final Size thumbSize;
  final EdgeInsets insets;
  final double margin;
  final Widget Function(BuildContext context, int? pageNumber) builder;

  const PdfInsetScrollThumb({
    super.key,
    required this.controller,
    required this.builder,
    this.thumbSize = const Size(34, 46),
    this.insets = EdgeInsets.zero,
    this.margin = 2,
  });

  @override
  State<PdfInsetScrollThumb> createState() => _PdfInsetScrollThumbState();
}

class _PdfInsetScrollThumbState extends State<PdfInsetScrollThumb> {
  double _panStartOffset = 0;

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
    // Tutamacın gidebileceği yol: görünen yükseklik − çubuk payları − boyu.
    final track = view.height * ctl.currentZoom -
        widget.insets.vertical -
        thumb.height;
    if (track <= 0) return const SizedBox();
    final top = widget.insets.top + frac * track;

    // Arapça arayüzde sol kenara geçer (sayfa rozetiyle birlikte).
    return PositionedDirectional(
      end: widget.margin,
      top: top,
      width: thumb.width,
      height: thumb.height,
      child: GestureDetector(
        onPanStart: (d) => _panStartOffset = top - d.localPosition.dy,
        onPanUpdate: (d) {
          final pos =
              _panStartOffset + d.localPosition.dy - widget.insets.top;
          final y = (pos / track).clamp(0.0, 1.0);
          final m = ctl.value.clone();
          m.y = -(y * scrollRange + minScrollY);
          ctl.value = m;
        },
        child: widget.builder(context, ctl.pageNumber),
      ),
    );
  }
}

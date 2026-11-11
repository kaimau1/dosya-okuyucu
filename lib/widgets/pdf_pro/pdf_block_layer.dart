import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../services/pdf/pro/pdf_text_blocks.dart';
import 'pdf_pro_edit_controller.dart';

/// [point]'e düşen blok: kutusu ([slop] kadar genişletilmiş) noktayı içeren
/// bloklardan merkezi en yakın olan; yoksa null. Komşu bloklar çakışırsa
/// dokunulan noktaya en yakın kutu kazanır (etkileşim sözleşmesi §2).
int? hitPdfBlock(List<Rect> rects, Offset point, {double slop = 6}) {
  int? best;
  var bestD = double.infinity;
  for (var i = 0; i < rects.length; i++) {
    if (!rects[i].inflate(slop).contains(point)) continue;
    final d = (rects[i].center - point).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// **Düzenleme kipinin sayfa katmanı** (PDF Pro Faz 54 / 2): sayfanın metin
/// bloklarını ince bir kılavuzla gösterir; dokunuş bloğu seçer, seçili bloğa
/// ikinci dokunuş (ya da uzun basış) düzenlemeyi açar.
///
/// Katman kaydırmayı/yakınlaştırmayı yutmaz: yalnız dokunma ve uzun basma
/// dinler, sürükleme görüntüleyiciye geçer. Sayfa koordinatında çizer — dil
/// değişince aynalanmaz.
class PdfProBlockLayer extends StatelessWidget {
  const PdfProBlockLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.controller,
    required this.onEdit,
  });

  final PdfPage page;
  final Size pageSize;
  final PdfProEditController controller;
  final void Function(int pageIndex, PdfTextBlock block) onEdit;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final pageIndex = page.pageNumber - 1;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final blocks = controller.blocksOf(pageIndex) ?? const <PdfTextBlock>[];
        final rects = [
          for (final b in blocks)
            PdfRect(b.left, b.top, b.right, b.bottom)
                .toRect(page: page, scaledPageSize: pageSize),
        ];
        final selected =
            controller.selectedPage == pageIndex ? controller.selectedBlock : null;
        void edit(int i) {
          if (!controller.busy) onEdit(pageIndex, blocks[i]);
        }

        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTapUp: (d) {
            final hit = hitPdfBlock(rects, d.localPosition);
            if (hit == null) {
              controller.clearSelection();
            } else if (hit == selected) {
              edit(hit);
            } else {
              AppHaptics.selection();
              controller.select(pageIndex, hit);
            }
          },
          onLongPressStart: (d) {
            final hit = hitPdfBlock(rects, d.localPosition);
            if (hit == null) return;
            AppHaptics.selection();
            controller.select(pageIndex, hit);
            edit(hit);
          },
          child: CustomPaint(
            size: pageSize,
            painter: _BlockFramePainter(rects, selected, accent),
          ),
        );
      },
    );
  }
}

class _BlockFramePainter extends CustomPainter {
  _BlockFramePainter(this.rects, this.selected, this.accent);

  final List<Rect> rects;
  final int? selected;
  final Color accent;

  @override
  void paint(Canvas canvas, Size size) {
    final idle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = PdfEditTokens.frameIdleWidth
      ..color = accent.withValues(alpha: PdfEditTokens.frameIdleAlpha);
    for (var i = 0; i < rects.length; i++) {
      if (i == selected) continue;
      canvas.drawRect(rects[i].inflate(2), idle);
    }
    final s = selected;
    if (s == null || s >= rects.length) return;
    final r = rects[s].inflate(2);
    canvas.drawRect(
        r,
        Paint()
          ..color = accent.withValues(alpha: PdfEditTokens.frameFillAlpha));
    canvas.drawRect(
        r,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = PdfEditTokens.frameActiveWidth
          ..color = accent);
    final handle = Paint()..color = accent;
    for (final c in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
      canvas.drawCircle(c, PdfEditTokens.handle / 2, handle);
    }
  }

  @override
  bool shouldRepaint(_BlockFramePainter old) =>
      old.selected != selected ||
      old.accent != accent ||
      !_same(old.rects, rects);

  static bool _same(List<Rect> a, List<Rect> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

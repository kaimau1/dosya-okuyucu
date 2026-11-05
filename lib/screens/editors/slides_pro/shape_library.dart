import 'package:flutter/material.dart';

import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/pptx_geometry.dart';
import '../../../services/pptx_editor.dart' show kSlideShapeLibrary;
import '../../../widgets/app_dialog.dart';

/// **Faz 38 / madde 8 — şekil kitaplığı.** Kategorili ızgara; önizleme
/// slayttaki çizicinin aynısı (`PptxPresetShape.build`), tek boyacı/hücre.
Future<String?> showShapeLibrary(BuildContext context) {
  return showAppSheet<String>(
    context,
    title: context.t('sp.shape_library'),
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      return SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.6,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
          children: [
            for (final MapEntry(key: cat, value: list) in kSlideShapeLibrary.entries) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
                child: Text(ctx.t('sp.cat_$cat'),
                    style: ctx.type.small.copyWith(color: scheme.primary)),
              ),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final prst in list)
                  Tooltip(
                    message: prst,
                    child: InkWell(
                      key: ValueKey('sp-shape-$prst'),
                      borderRadius: BorderRadius.circular(8),
                      onTap: () => Navigator.pop(ctx, prst),
                      child: Container(
                        width: 52,
                        height: 52,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.all(color: scheme.outlineVariant),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: RepaintBoundary(
                          child: CustomPaint(
                              painter: _PresetPainter(prst, scheme.primary, scheme.onSurface)),
                        ),
                      ),
                    ),
                  ),
              ]),
            ],
          ],
        ),
      );
    },
  );
}

class _PresetPainter extends CustomPainter {
  final String prst;
  final Color fill, line;
  _PresetPainter(this.prst, this.fill, this.line);

  @override
  void paint(Canvas canvas, Size size) {
    final path = PptxPresetShape.build(prst, size) ?? (Path()..addRect(Offset.zero & size));
    canvas.drawPath(path, Paint()..color = fill.withValues(alpha: 0.35));
    canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = line);
  }

  @override
  bool shouldRepaint(_PresetPainter old) => old.prst != prst || old.fill != fill;
}

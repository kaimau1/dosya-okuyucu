import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/app_colors.dart';
import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/pptx/pro/pptx_package.dart';
import '../../../widgets/app_dialog.dart';

/// Pro sayfalarının editöre geri çağrısı: işlemi uygular (izolatta), destenin
/// yeni baytını döndürür (başarısızsa null). Editör geri al yığınını tutar.
typedef SlidesProApply = Future<Uint8List?> Function(PptxOp op);

/// `RRGGBB` → renk.
const _opaque = 0xFF000000;

Color hexColor(String hex) =>
    Color(_opaque | (int.tryParse(hex.replaceAll('#', ''), radix: 16) ?? 0));

/// Renk → `RRGGBB`.
String colorHex(Color c) =>
    (c.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase();

/// Sade renk paleti (içerik rengi — tasarım tokenı değil).
const kProPalette = <int>[
  0xFF000000, 0xFF404040, 0xFF7F7F7F, 0xFFBFBFBF, 0xFFFFFFFF, //
  0xFFC00000, 0xFFFF0000, 0xFFFFC000, 0xFFFFFF00, 0xFF92D050,
  0xFF00B050, 0xFF00B0F0, 0xFF0070C0, 0xFF002060, 0xFF7030A0,
  0xFF1F5AA6, 0xFF2A9D8F, 0xFFE76F51, 0xFFF4A261, 0xFF264653,
];

/// Palet + "hex yaz" levhası. Vazgeçilirse null.
Future<String?> pickHexColor(BuildContext context, {String? current}) {
  return showAppSheet<String>(
    context,
    title: context.t('sp.pick_color'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final v in kProPalette)
                Semantics(
                  button: true,
                  label: colorHex(Color(v)),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(ctx, colorHex(Color(v))),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(v),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: current == colorHex(Color(v))
                              ? Theme.of(ctx).colorScheme.primary
                              : Theme.of(ctx).colorScheme.outlineVariant,
                          width: current == colorHex(Color(v)) ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(AppIcons.edit),
            label: Text(ctx.t('sp.hex_input')),
            onPressed: () async {
              final v = await showAppPrompt(ctx,
                  title: ctx.t('sp.hex_input'),
                  initial: current ?? '',
                  maxLength: 7);
              final hex = v?.replaceAll('#', '').toUpperCase();
              if (hex != null &&
                  RegExp(r'^[0-9A-F]{6}$').hasMatch(hex) &&
                  ctx.mounted) {
                Navigator.pop(ctx, hex);
              }
            },
          ),
        ],
      ),
    ),
  );
}

/// Sayı sorusu (punto, saniye …). Geçersiz/vazgeçme → null.
Future<double?> promptNumber(BuildContext context, String title,
    {double? initial, double min = 0, double max = 100000}) async {
  final v = await showAppPrompt(context,
      title: title,
      initial: initial == null
          ? ''
          : (initial == initial.roundToDouble()
              ? initial.toInt().toString()
              : initial.toString()));
  final n = double.tryParse((v ?? '').replaceAll(',', '.'));
  if (n == null || n < min || n > max) return null;
  return n;
}

/// Bir slayt/yerleşimin şematik önizlemesi: yer tutucu dikdörtgenleri.
/// Çizim tek [CustomPainter] (anayasa k.5) — gerçek çizim maliyeti yok.
class SlideSchematic extends StatelessWidget {
  final int widthEmu, heightEmu;
  final List<(Rect, String)> boxes;
  final int? selected;
  final Color? background;
  const SlideSchematic({
    super.key,
    required this.widthEmu,
    required this.heightEmu,
    required this.boxes,
    this.selected,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AspectRatio(
      aspectRatio: widthEmu / heightEmu,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SchematicPainter(
            widthEmu.toDouble(),
            boxes,
            selected,
            background ?? AppColors.page,
            scheme.outline,
            scheme.primary,
            context.type.caption.copyWith(color: scheme.outline),
          ),
        ),
      ),
    );
  }
}

class _SchematicPainter extends CustomPainter {
  final double wEmu;
  final List<(Rect, String)> boxes;
  final int? selected;
  final Color bg, line, accent;
  final TextStyle label;
  _SchematicPainter(this.wEmu, this.boxes, this.selected, this.bg, this.line,
      this.accent, this.label);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / wEmu;
    canvas.drawRect(Offset.zero & size, Paint()..color = bg);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..style = PaintingStyle.stroke
          ..color = line);
    for (var i = 0; i < boxes.length; i++) {
      final (r, name) = boxes[i];
      final rr = Rect.fromLTWH(r.left * k, r.top * k, r.width * k, r.height * k);
      final sel = i == selected;
      canvas.drawRect(
          rr,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = sel ? 2.5 : 1
            ..color = sel ? accent : line);
      final tp = TextPainter(
        text: TextSpan(text: name, style: label),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: (rr.width - 4).clamp(0, double.infinity));
      tp.paint(canvas, rr.topLeft + const Offset(2, 2));
    }
  }

  @override
  bool shouldRepaint(_SchematicPainter old) =>
      old.boxes != boxes || old.selected != selected || old.bg != bg;
}

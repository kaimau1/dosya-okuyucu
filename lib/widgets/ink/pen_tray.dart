import 'package:flutter/material.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/edit/ink_logic.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart' show Gap, Radii;
import '../app_dialog.dart' show showAppSheet;

/// **KALEM TEPSİSİ** — Notlar uygulamasındaki tepsinin mantığı (B20,
/// 2026-11-27, kullanıcı: "kalemle silgi yan yana olmalı; Notlar'daki kalem
/// mantığı birebir alınsın, PDF vs. içinde uygulansın").
///
/// * Kalem · fosforlu · silgi YAN YANA, tek kapsülde; seçili olan yukarı
///   kalkar, kalemlerin ucu çizilen renktedir.
/// * Seçili araca YENİDEN dokunmak ayarları açar ([onSettings]).
/// * ⇄ düğmesi: kalem ⇄ silgi ANLIK geçiş — son kalem hatırlanır
///   ([PenTrayMemory.swap]).
/// * Silgiye uzun basmak sayfadakilerin hepsini siler ([onClear], geri
///   alınabilir).
/// * Kalemin yan düğmesi / ters ucu araç değiştirmeden siler — o kısım
///   çizim katmanında ([isStylusEraser]).
///
/// Ekranın kendi araç sırası (yazı, şekil, kaydır…) tepsinin yanında kalır;
/// tepsi dışı araçtayken [selected] null.
class PenTray extends StatelessWidget {
  const PenTray({
    super.key,
    required this.selected,
    required this.onSelect,
    required this.penColor,
    required this.highlighterColor,
    this.onSettings,
    this.onClear,
  });

  final PenTrayTool? selected;
  final ValueChanged<PenTrayTool> onSelect;
  final Color penColor;
  final Color highlighterColor;
  final ValueChanged<PenTrayTool>? onSettings;
  final VoidCallback? onClear;

  void _tap(PenTrayTool tool) {
    AppHaptics.selection();
    if (tool == selected) {
      onSettings?.call(tool);
      return;
    }
    PenTrayMemory.note(tool);
    onSelect(tool);
  }

  void _swap() {
    AppHaptics.selection();
    final next = PenTrayMemory.swap(selected);
    PenTrayMemory.note(next);
    onSelect(next);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(Radii.pill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Gap.xs),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          _slot(context, PenTrayTool.pen, AppIcons.edit, 'ink.pen', penColor),
          _slot(context, PenTrayTool.highlighter, AppIcons.highlighter,
              'ink.highlighter', highlighterColor),
          _slot(context, PenTrayTool.eraser, AppIcons.eraser, 'ink.eraser',
              null),
          IconButton(
            key: const ValueKey('pen-tray-swap'),
            tooltip: context.t('ink.swap'),
            visualDensity: VisualDensity.compact,
            icon: const Icon(AppIcons.swapHoriz, size: 20),
            onPressed: _swap,
          ),
        ]),
      ),
    );
  }

  Widget _slot(BuildContext context, PenTrayTool tool, IconData icon,
      String label, Color? tip) {
    final scheme = Theme.of(context).colorScheme;
    final on = tool == selected;
    final duration = Motion.of(context, Motion.short);
    return Tooltip(
      message: context.t(label),
      child: Semantics(
        button: true,
        selected: on,
        label: context.t(label),
        child: InkResponse(
          key: ValueKey('pen-tray-${tool.name}'),
          radius: 24,
          onTap: () => _tap(tool),
          onLongPress: tool == PenTrayTool.eraser ? onClear : null,
          child: SizedBox(
            width: 44,
            height: 48,
            child: AnimatedSlide(
              // Seçili kalem tepsiden yukarı kalkar (Notlar'daki gibi).
              offset: on ? const Offset(0, -0.08) : Offset.zero,
              duration: duration,
              curve: Motion.standard,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: on ? scheme.primaryContainer : null,
                      shape: BoxShape.circle,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(icon,
                          size: 22,
                          color: on
                              ? scheme.onPrimaryContainer
                              : scheme.onSurfaceVariant),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Kalemin ucu çizilen renkte; silginin ucu yok.
                  Container(
                    width: 16,
                    height: 3,
                    decoration: BoxDecoration(
                      color: tip ?? Colors.transparent,
                      borderRadius: BorderRadius.circular(Radii.pill),
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

/// Kalem/silgi ayarları (tepsideki seçili araca yeniden dokununca). Kalemde
/// renk + kalınlık (canlı önizlemeli), silgide kip (çizgi / değdiği yer) ve
/// "hepsini sil". Değerler açıkken de çağırana anında gider.
Future<void> showPenSettings(
  BuildContext context, {
  required PenTrayTool tool,
  List<Color> colors = const [],
  Color? color,
  ValueChanged<Color>? onColor,
  double width = 0,
  double minWidth = 0,
  double maxWidth = 1,
  int? divisions,
  double Function(double width)? previewPixels,
  ValueChanged<double>? onWidth,
  VoidCallback? onClear,
}) {
  final eraser = tool == PenTrayTool.eraser;
  var c = color;
  var w = width;
  return showAppSheet<void>(
    context,
    title: context.t(eraser
        ? 'ink.eraser'
        : tool == PenTrayTool.pen
            ? 'ink.pen'
            : 'ink.highlighter'),
    builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
      final scheme = Theme.of(ctx).colorScheme;
      if (eraser) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SegmentedButton<EraserMode>(
                key: const ValueKey('pen-eraser-mode'),
                segments: [
                  ButtonSegment(
                      value: EraserMode.stroke,
                      label: Text(ctx.t('ink.eraser_stroke'))),
                  ButtonSegment(
                      value: EraserMode.area,
                      label: Text(ctx.t('ink.eraser_area'))),
                ],
                selected: {PenTrayMemory.eraserMode},
                onSelectionChanged: (s) =>
                    setLocal(() => PenTrayMemory.eraserMode = s.first),
              ),
              if (onClear != null) ...[
                const SizedBox(height: Gap.md),
                OutlinedButton.icon(
                  icon: const Icon(AppIcons.deleteSweep),
                  label: Text(ctx.t('ink.clear_all')),
                  onPressed: () {
                    Navigator.pop(ctx);
                    onClear();
                  },
                ),
              ],
            ],
          ),
        );
      }
      final px = previewPixels?.call(w) ?? w;
      return Padding(
        padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: CustomPaint(
                painter: _StrokePreview(
                  color: c ?? scheme.onSurface,
                  width: px.clamp(1.0, 40.0),
                  highlighter: tool == PenTrayTool.highlighter,
                ),
              ),
            ),
            if (colors.isNotEmpty) ...[
              const SizedBox(height: Gap.sm),
              Wrap(
                alignment: WrapAlignment.center,
                children: [
                  for (final option in colors)
                    InkResponse(
                      onTap: () {
                        setLocal(() => c = option);
                        onColor?.call(option);
                      },
                      radius: 22,
                      child: Container(
                        width: 30,
                        height: 30,
                        margin: const EdgeInsets.all(Gap.xs + 2),
                        decoration: BoxDecoration(
                          color: option,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: option == c
                                ? scheme.primary
                                : scheme.outlineVariant,
                            width: option == c ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
            if (onWidth != null)
              Row(children: [
                Tooltip(
                  message: ctx.t('ink.width'),
                  child: Icon(AppIcons.lineWeight,
                      size: 18, color: scheme.onSurfaceVariant),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('pen-width'),
                    value: w.clamp(minWidth, maxWidth),
                    min: minWidth,
                    max: maxWidth,
                    divisions: divisions,
                    onChanged: (v) {
                      setLocal(() => w = v);
                      onWidth(v);
                    },
                  ),
                ),
              ]),
            Text(ctx.t('ink.tray_hint'),
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall),
          ],
        ),
      );
    }),
  );
}

/// Kalınlık önizlemesi: seçili renk ve kalınlıkta yumuşak bir dalga.
class _StrokePreview extends CustomPainter {
  _StrokePreview({
    required this.color,
    required this.width,
    required this.highlighter,
  });

  final Color color;
  final double width;
  final bool highlighter;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    final path = Path()..moveTo(size.width * 0.15, y);
    path.cubicTo(size.width * 0.35, y - 16, size.width * 0.55, y + 16,
        size.width * 0.85, y);
    canvas.drawPath(
      path,
      Paint()
        ..color = highlighter ? color.withValues(alpha: 0.45) : color
        ..strokeWidth = width
        ..style = PaintingStyle.stroke
        ..strokeCap = highlighter ? StrokeCap.square : StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_StrokePreview old) =>
      old.color != color ||
      old.width != width ||
      old.highlighter != highlighter;
}

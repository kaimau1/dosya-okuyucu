import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../app_dialog.dart';

/// Renk seçimi sonucu: [index] null = rengi kaldır.
class LabelColorChoice {
  final int? index;
  const LabelColorChoice(this.index);
}

/// Etiket / klasör rengi seçici (Faz 41 / 6). Vazgeçilirse null.
Future<LabelColorChoice?> showLabelColorSheet(
  BuildContext context, {
  required String title,
  int? current,
}) {
  return showAppSheet<LabelColorChoice>(
    context,
    title: title,
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(Gap.lg, 0, Gap.lg, Gap.md),
      child: Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.sm,
        children: [
          for (var i = 0; i < AppHues.labels.length; i++)
            Semantics(
              button: true,
              selected: current == i,
              label: '${ctx.t('lcol.color')} ${i + 1}',
              excludeSemantics: true,
              child: InkWell(
                key: ValueKey('label-color-$i'),
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(ctx, LabelColorChoice(i)),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppHues.labels[i],
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: current == i
                          ? Theme.of(ctx).colorScheme.onSurface
                          : Theme.of(ctx).colorScheme.outlineVariant,
                      width: current == i ? 3 : 1,
                    ),
                  ),
                  child: current == i
                      ? const Icon(AppIcons.check, color: AppColors.onBrand)
                      : null,
                ),
              ),
            ),
          ActionChip(
            key: const ValueKey('label-color-none'),
            avatar: const Icon(AppIcons.close, size: 18),
            label: Text(ctx.t('lcol.none')),
            onPressed: () => Navigator.pop(ctx, const LabelColorChoice(null)),
          ),
        ],
      ),
    ),
  );
}

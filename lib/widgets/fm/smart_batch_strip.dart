import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../screens/fm/smart_sort_screen.dart';
import '../../services/fm/smart_sort.dart';
import 'smart_cat_style.dart';

/// **"3 yeni dosya düzenlendi: 2 fatura, 1 dekont"** (Akıllı düzen,
/// 2026-11-18): son otomatik turun sonucu ana ekranda ince bir şerit;
/// dokununca Akıllı düzen, ✕ kapatır. Sonuç yokken HİÇ yer kaplamaz (ağaç
/// şekli sabit: dinleyici hep durur, içerik `SizedBox.shrink`).
class SmartBatchStrip extends StatelessWidget {
  const SmartBatchStrip({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SmartBatch?>(
      valueListenable: SmartSort.lastBatch,
      builder: (context, batch, _) {
        if (batch == null) return const SizedBox.shrink();
        final theme = Theme.of(context);
        final parts = (batch.byCategory.entries.toList()
              ..sort((a, b) => b.value.compareTo(a.value)))
            .take(3)
            .map((e) => '${e.value} ${SmartCatStyle.label(context, e.key)}')
            .join(', ');
        return Padding(
          padding: const EdgeInsets.only(top: Gap.sm),
          child: Material(
            color: theme.colorScheme.secondaryContainer,
            borderRadius: BorderRadius.circular(Radii.card),
            child: InkWell(
              key: const ValueKey('smart-batch'),
              borderRadius: BorderRadius.circular(Radii.card),
              onTap: () {
                SmartSort.lastBatch.value = null;
                unawaited(SmartSortScreen.open(context));
              },
              child: Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(
                    Gap.md, Gap.sm, Gap.xs, Gap.sm),
                child: Row(children: [
                  Icon(AppIcons.ai, color: theme.colorScheme.onSecondaryContainer),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: Text(
                      context.t('sm.batch',
                          {'n': batch.paths.length, 'parts': parts}),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer),
                    ),
                  ),
                  IconButton(
                    tooltip: context.t('common.close'),
                    icon: const Icon(AppIcons.close, size: AppIcons.small),
                    onPressed: () => SmartSort.lastBatch.value = null,
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

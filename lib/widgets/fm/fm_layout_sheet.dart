import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../app_dialog.dart';

/// Yerleşim seçici: dosya listelerinde liste / büyük liste / ızgara
/// ([FmLayoutInfo.fileListChoices]); Fotoğraflar'da 2-3-4-5 sütun.
///
/// Tek yerde tanımlı olması bilinçli — gözatıcı, kategori ve Fotoğraflar
/// ekranları aynı sayfayı açar, seçenekler birbirinden ayrışmaz.
Future<FmLayout?> showFmLayoutSheet(
  BuildContext context, {
  required FmLayout current,
  String? title,

  /// Fotoğraf ızgarasında liste düzenleri anlamsız (her şey kare önizleme).
  bool allowLists = true,
}) {
  final options = allowLists
      ? FmLayoutInfo.fileListChoices
      : FmLayout.values.where((l) => l.isGrid).toList(growable: false);

  return showAppSheet<FmLayout>(
    context,
    title: title ?? context.t('uix.view'),
    builder: (ctx) {
      final theme = Theme.of(ctx);
      final scheme = theme.colorScheme;
      final skin = AppSkinData.of(ctx);
      final pal = skin.palette;
      final radius = BorderRadius.circular(skin.metrics.radiusCard);
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < options.length; i++) ...[
              if (i > 0) const SizedBox(height: Gap.sm),
              () {
                final l = options[i];
                final selected = l == current;
                return Semantics(
                  button: true,
                  selected: selected,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: selected ? scheme.primaryContainer : pal.card,
                      borderRadius: radius,
                      border: Border.all(
                        color: selected ? scheme.primary : pal.rule,
                        width: selected ? 1.5 : 1,
                      ),
                    ),
                    child: InkWell(
                      borderRadius: radius,
                      onTap: () => Navigator.pop(ctx, l),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: Gap.md, vertical: Gap.sm + 4),
                        child: Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: selected
                                    ? scheme.primary
                                    : pal.well,
                                borderRadius:
                                    BorderRadius.circular(Radii.control),
                              ),
                              child: Icon(
                                fmLayoutIcon(l),
                                size: 22,
                                color: selected
                                    ? scheme.onPrimary
                                    : scheme.primary,
                              ),
                            ),
                            const SizedBox(width: Gap.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ctx.t(l.labelKey),
                                    style: theme.textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                                  Text(
                                    ctx.t(l.descriptionKey),
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: selected
                                          ? scheme.onPrimaryContainer
                                              .withValues(alpha: 0.85)
                                          : scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (selected)
                              Icon(AppIcons.checkCircle,
                                  size: 22, color: scheme.primary),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }(),
            ],
          ],
        ),
      );
    },
  );
}

/// Yerleşimin simgesi (AppBar düğmesi ve seçim listesi aynı simgeyi kullanır).
IconData fmLayoutIcon(FmLayout layout) => switch (layout) {
      FmLayout.list => AppIcons.layoutList,
      FmLayout.detail => AppIcons.layoutDetail,
      FmLayout.grid2 ||
      FmLayout.grid3 ||
      FmLayout.grid4 ||
      FmLayout.grid5 =>
        AppIcons.layoutGrid,
    };

/// Yerleşimin ızgara delegesi. Sütun sayısı SABİTTİR (maxCrossAxisExtent
/// değil): kullanıcı "3 sütun" dediğinde ekran genişliği ne olursa olsun 3
/// sütun görmeli — eski `maxCrossAxisExtent: 120` telefonda 3, tablette 5
/// sütun üretiyordu.
SliverGridDelegate fmGridDelegate(FmLayout layout, double width) {
  // Telefonda sütun sayısı yerleşimin kendisi; GENİŞ ekranda (≥ 600 dp,
  // tablet/katlanabilir — Faz 6 / U11) hücre ~150 dp'yi aşmasın diye sütun
  // genişlikten türer: 3 sütun tablette 140 dp yerine 300 dp'lik kareler
  // çiziyordu.
  final columns = width >= 600
      ? (width / 150).floor().clamp(layout.columns, 12)
      : layout.columns;
  final spacing = columns >= 4 ? Gap.xs : Gap.sm;
  final cell = (width - spacing * (columns - 1)) / columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: columns,
    childAspectRatio: layout.aspectFor(cell),
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
  );
}

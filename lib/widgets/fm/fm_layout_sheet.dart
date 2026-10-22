import 'package:flutter/material.dart';

import '../../core/app_icons.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';

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

  return showModalBottomSheet<FmLayout>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: Text(title ?? ctx.t('uix.view'), style: Theme.of(ctx).textTheme.titleMedium),
          ),
          RadioGroup<FmLayout>(
            groupValue: current,
            onChanged: (v) => Navigator.pop(ctx, v),
            child: Column(children: [
              for (final l in options)
                RadioListTile<FmLayout>(
                  value: l,
                  secondary: Icon(fmLayoutIcon(l)),
                  title: Text(l.label),
                  subtitle: Text(l.description),
                ),
            ]),
          ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    ),
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

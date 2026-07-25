import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/fm_layout.dart';

/// Yerleşim seçici: liste / büyük liste / 2-3-4-5 sütun.
///
/// Tek yerde tanımlı olması bilinçli — gözatıcı, kategori ve Fotoğraflar
/// ekranları aynı sayfayı açar, seçenekler birbirinden ayrışmaz.
Future<FmLayout?> showFmLayoutSheet(
  BuildContext context, {
  required FmLayout current,
  String title = 'Görünüm',

  /// Fotoğraf ızgarasında liste düzenleri anlamsız (her şey kare önizleme).
  bool allowLists = true,
}) {
  final options = FmLayout.values
      .where((l) => allowLists || l.isGrid)
      .toList(growable: false);

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
            child: Text(title, style: Theme.of(ctx).textTheme.titleMedium),
          ),
          for (final l in options)
            RadioListTile<FmLayout>(
              value: l,
              groupValue: current,
              onChanged: (v) => Navigator.pop(ctx, v),
              secondary: Icon(fmLayoutIcon(l)),
              title: Text(l.label),
              subtitle: Text(l.description),
            ),
          const SizedBox(height: Gap.sm),
        ],
      ),
    ),
  );
}

/// Yerleşimin simgesi (AppBar düğmesi ve seçim listesi aynı simgeyi kullanır).
IconData fmLayoutIcon(FmLayout layout) => switch (layout) {
      FmLayout.list => Icons.view_list,
      FmLayout.detail => Icons.view_agenda_outlined,
      FmLayout.grid2 => Icons.grid_view,
      FmLayout.grid3 => Icons.grid_on,
      FmLayout.grid4 => Icons.apps,
      FmLayout.grid5 => Icons.blur_on,
    };

/// Yerleşimin ızgara delegesi. Sütun sayısı SABİTTİR (maxCrossAxisExtent
/// değil): kullanıcı "3 sütun" dediğinde ekran genişliği ne olursa olsun 3
/// sütun görmeli — eski `maxCrossAxisExtent: 120` telefonda 3, tablette 5
/// sütun üretiyordu.
SliverGridDelegate fmGridDelegate(FmLayout layout, double width) {
  final spacing = layout.columns >= 4 ? Gap.xs : Gap.sm;
  final cell = (width - spacing * (layout.columns - 1)) / layout.columns;
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: layout.columns,
    childAspectRatio: layout.aspectFor(cell),
    mainAxisSpacing: spacing,
    crossAxisSpacing: spacing,
  );
}

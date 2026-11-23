import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/fm_colors_store.dart';
import '../app_dialog.dart';
import 'fm_filter_widgets.dart';
import 'fm_quick_filters.dart';

/// Süzgeç şeridinin üçüncü kartı **"Analiz ve diğer"**in levhası
/// (kullanıcı 2026-10-28: *"tüm filtre türleri tek kart sistemi altında;
/// yukarıda en fazla 3 simge: Tür · Kaynak ve zaman · Analiz ve diğer"*).
///
/// 2026-11-23 yenilemesi: her bölüm kendi sakin kartında ([FmFilterSectionCard]),
/// seçenekler tek satırda çok daha fazlasını sığdıran kompakt haplarda
/// ([FmFilterOptionChip]); başlık ve "Tamam" düğmesi sabit.

/// Levhadaki tek seçenek.
class FmMoreTile {
  final Key? key;
  final IconData icon;
  final String label;
  final Color? color;
  final bool selected;

  /// Küçük sayı rozeti (yoksa gizli).
  final int? count;

  /// true: dokununca levha AÇIK kalır (seçim kutuları); false: levha
  /// kapanır, sonra çalışır (başka levha/ekran açan eylemler).
  final bool keepOpen;
  final VoidCallback onTap;

  const FmMoreTile({
    this.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
    this.selected = false,
    this.count,
    this.keepOpen = true,
  });
}

class FmMoreSection {
  final String title;
  final List<FmMoreTile> tiles;
  const FmMoreSection(this.title, this.tiles);
}

/// Şeridin üçüncü hapı.
class FmMoreChip extends StatelessWidget {
  /// Levha her açılışta/yenilemede bunu çağırır (güncel durumu okur).
  final List<FmMoreSection> Function(BuildContext context) sections;

  /// Etkin ölçüt sayısı (hap vurgulanır).
  final int active;

  const FmMoreChip({super.key, required this.sections, this.active = 0});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: context.t('fb.more'),
        child: Semantics(
          button: true,
          child: InkWell(
            key: const ValueKey('more-pill'),
            borderRadius: BorderRadius.circular(12),
            onTap: () => showFmMoreSheet(context, sections),
            child: FmPill(
              icon: AppIcons.insights,
              label: context.t('fb.more'),
              count: active > 0 ? active : null,
              highlighted: active > 0,
              dropdown: true,
            ),
          ),
        ),
      );
}

Future<void> showFmMoreSheet(BuildContext context,
    List<FmMoreSection> Function(BuildContext) sections) {
  return showAppSheet<void>(
    context,
    scrollable: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        final list = sections(context).where((s) => s.tiles.isNotEmpty).toList();
        final cards = <Widget>[];
        for (var i = 0; i < list.length; i++) {
          final s = list[i];
          if (i > 0) cards.add(const SizedBox(height: Gap.sm + 2));
          final selectedTiles = s.tiles.where((t) => t.selected).toList();
          final badge =
              selectedTiles.length > 1 ? '${selectedTiles.length}' : null;
          cards.add(
            FmFilterSectionCard(
              icon: s.tiles.first.icon,
              title: s.title,
              badgeText: badge,
              badgeActive: selectedTiles.isNotEmpty,
              child: Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final t in s.tiles)
                    FmFilterOptionChip(
                      key: t.key,
                      icon: t.icon,
                      accentColor: t.color ?? scheme.primary,
                      label: t.label,
                      count: t.count,
                      selected: t.selected,
                      filledSelected: t.color == null && t.count == null,
                      onTap: () {
                        if (t.keepOpen) {
                          t.onTap();
                          setSheet(() {});
                        } else {
                          Navigator.of(ctx).pop();
                          t.onTap();
                        }
                      },
                    ),
                ],
              ),
            ),
          );
        }

        return FmFilterSheetScaffold(
          title: ctx.t('fb.more'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: cards,
          ),
          footer: FilledButton.icon(
            key: const ValueKey('more-done'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
            ),
            onPressed: () => Navigator.of(ctx).pop(),
            icon: const Icon(AppIcons.check, size: 20),
            label: Text(ctx.t('common.ok')),
          ),
        );
      },
    ),
  );
}

// ── hazır bölümler ─────────────────────────────────────────────────────────

/// Sırala: ölçüt kutuları (aynısına yeniden dokunmak yönü çevirir) + yön.
FmMoreSection fmSortSection(
  BuildContext context, {
  required FmSort sort,
  required bool descending,
  required void Function(FmSort sort, bool descending) onSort,
  List<FmSort> options = FmSort.values,
}) =>
    FmMoreSection(context.t('list.sort'), [
      for (final s in options)
        FmMoreTile(
          icon: switch (s) {
            FmSort.name => AppIcons.sort,
            FmSort.date => AppIcons.calendarMonth,
            FmSort.size => AppIcons.storage,
            FmSort.type => AppIcons.tune,
          },
          label: context.t(s.labelKey),
          selected: s == sort,
          onTap: () => onSort(
              s, s == sort ? !descending : (s == FmSort.date || s == FmSort.size)),
        ),
      FmMoreTile(
        icon: AppIcons.arrowUp,
        label: context.t('more.asc'),
        selected: !descending,
        onTap: () => onSort(sort, false),
      ),
      FmMoreTile(
        icon: AppIcons.arrowDown,
        label: context.t('more.desc'),
        selected: descending,
        onTap: () => onSort(sort, true),
      ),
    ]);

/// Tarih ve boyut aralıkları (tek seçim).
List<FmMoreSection> fmDateSizeSections(BuildContext context,
        {required FmFilter filter, required ValueChanged<FmFilter> onChanged}) =>
    [
      FmMoreSection(context.t('list.date'), [
        for (final r in FmDateRange.values)
          if (r != FmDateRange.custom || filter.dateRange == FmDateRange.custom)
            FmMoreTile(
              icon: AppIcons.calendarMonth,
              label: context.t(r.labelKey),
              selected: filter.dateRange == r,
              onTap: () => onChanged(filter.withDateRange(r)),
            ),
      ]),
      FmMoreSection(context.t('list.size'), [
        for (final r in FmSizeRange.values)
          FmMoreTile(
            icon: AppIcons.storage,
            label: context.t(r.labelKey),
            selected: filter.sizeRange == r,
            onTap: () => onChanged(filter.withSizeRange(r)),
          ),
      ]),
    ];

/// Etiket kutuları (çoklu seçim); en sık [limit] etiket (renkli).
FmMoreSection fmTagsSection(BuildContext context,
    {required Map<String, int> counts,
    required FmFilter filter,
    required ValueChanged<FmFilter> onChanged,
    int limit = 6}) {
  final top = (counts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(limit);
  return FmMoreSection(context.t('more.tags'), [
    for (final e in top)
      FmMoreTile(
        icon: AppIcons.tag,
        color: FmColorsStore.tagColor(e.key),
        label: '#${e.key}',
        count: e.value,
        selected: filter.tags.contains(e.key),
        onTap: () => onChanged(filter.toggleTag(e.key)),
      ),
  ]);
}

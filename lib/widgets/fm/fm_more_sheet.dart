import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../app_dialog.dart';
import 'fm_quick_filters.dart';
import 'fm_type_chips.dart' show FmChoiceTile;

/// Süzgeç şeridinin üçüncü kartı **"Analiz ve diğer"**in levhası
/// (kullanıcı 2026-10-28: *"tüm filtre türleri tek kart sistemi altında;
/// yukarıda en fazla 3 simge: Tür · Kaynak ve zaman · Analiz ve diğer"*).
///
/// Sırala · Süzgeç (tarih/boyut) · Analiz · Etiketler · ekrana özel işler
/// (galeri ölçeği, kopyalar, arama kapsamı …) HEPSİ burada, tür ve kaynak
/// levhalarıyla aynı büyük kutu dilinde. Sayfa listesi her yeniden çizimde
/// yeniden üretilir ([FmMoreChip.sections]) — seçili durum hep güncel.

/// Levhadaki tek kutu.
class FmMoreTile {
  final Key? key;
  final IconData icon;
  final String label;
  final Color? color;
  final bool selected;

  /// Kutunun altındaki küçük sayı (yoksa gizli).
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
            customBorder: const StadiumBorder(),
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
    title: context.t('fb.more'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final scheme = Theme.of(ctx).colorScheme;
        final list = sections(context);
        return SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final s in list)
                  if (s.tiles.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: Gap.sm, top: Gap.sm, bottom: Gap.sm),
                      child: Text(s.title,
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ),
                    LayoutBuilder(builder: (ctx, box) {
                      final cols = box.maxWidth < 300 ? 2 : 3;
                      final w = (box.maxWidth - Gap.sm * (cols - 1)) / cols;
                      return Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [
                          for (final t in s.tiles)
                            FmChoiceTile(
                              key: t.key,
                              width: w,
                              icon: t.icon,
                              color: t.color ?? scheme.primary,
                              label: t.label,
                              count: t.count ?? -1,
                              selected: t.selected,
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
                      );
                    }),
                  ],
                const SizedBox(height: Gap.md),
                FilledButton(
                  key: const ValueKey('more-done'),
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.t('common.ok')),
                ),
              ],
            ),
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

/// Etiket kutuları (çoklu seçim); en sık [limit] etiket.
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
        icon: AppIcons.labelOutline,
        label: '#${e.key}',
        count: e.value,
        selected: filter.tags.contains(e.key),
        onTap: () => onChanged(filter.toggleTag(e.key)),
      ),
  ]);
}

import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../app_dialog.dart';
import 'fm_entry_icon.dart';
import 'fm_quick_filters.dart';

/// **Ortak tür süzgeci** (Faz 13, 2026-10-22): `Tümü · PDF 12 · Word 3 ·
/// Görsel 40 · …` — her dosya listesinde aynı yerde, aynı görünüşte, aynı
/// mantıkla.
///
/// KÖK NEDEN: bkz. `models/fm_type.dart`. Ders (HAFIZA 2026-10-22 (2)): alt
/// tür çiplerinin görünmesi bir ekran **bayrağına** (`showDocKinds`)
/// bağlıydı; aynı ekranı yeniden kullanan *Yeni gelenler* bayrağı vermediği
/// için PDF çipini sessizce kaybetmişti. Artık davranış **veriden** türer:
/// listede iki ya da daha çok tür varsa çipler kendiliğinden çıkar.
///
/// Kurallar:
/// * yalnız listede **bulunan** türler çizilir (sayısı 0 olan çip yok — ama
///   seçiliyse kalır, yoksa kullanıcı seçtiği çipi kaybedip boş liste görürdü);
/// * sayılar **öteki ölçütlere bağlı** (`FmQuickFilters` ilkesi): tarih/kaynak
///   süzgeci açıkken "PDF · 12" o süzgeçten geçen PDF sayısıdır — hiçbir tür
///   seçili değilken çipe dokununca listede tam o kadar dosya kalır;
/// * **çoklu seçim** (PDF + Word birlikte); "Tümü" seçimi temizler;
/// * belge alt türleri DÜZ çip: "Belgeler" diye bir ara düzey yok — kullanıcının
///   aradığı "yalnız PDF" tek dokunuş olsun.
///
/// Çiplerin kendisi bir `List<Widget>`: `FmQuickFilters.leading`'e ya da
/// [FmFilterBar]'a verilir — tek satır kuralı (`kFmFilterBarHeight`) korunur.
abstract final class FmTypeChips {
  /// Tür süzgecini üretir: **tek açılır hap** ([FmTypePill]) — dokununca
  /// tür levhası açılır. [counts] seçili türlerden bağımsız (öteki
  /// ölçütlerle süzülmüş) tür sayıları.
  ///
  /// 2026-10-28 (kullanıcı, ekran görüntüsüyle: *"üst filtre alanını baştan
  /// tasarla — dropdown mı olur, daha güzel bir şey mi, sen karar ver"*):
  /// eskiden her tür ayrı bir çipti ("Tümü · 142 · PDF · 59 · Word · 11 ·
  /// Excel · 38 · Sla…") ve satırın tamamını yiyordu; Sırala/Süzgeç/Analiz
  /// bu yüzden İKİNCİ bir satıra iniyordu. Şimdi türler tek hapta
  /// toplanır, aynı satıra öteki denetimler sığar — listeden 46 dp geri
  /// gelir. Levhada her tür simgesi, rengi ve sayısıyla büyük bir kutu
  /// (çoklu seçim, liste hemen süzülür).
  static List<Widget> build(
    BuildContext context, {
    required Map<FmType, int> counts,
    required Set<FmType> selected,
    required ValueChanged<Set<FmType>> onChanged,
  }) {
    final present = [
      for (final t in FmType.values)
        if ((counts[t] ?? 0) > 0 || selected.contains(t)) t,
    ];
    // Tek türlü listede tür seçici bilgi taşımaz (hepsi PDF'se "PDF"
    // hiçbir şey süzmez, yalnız satırda yer kaplar).
    if (present.length < 2 && selected.isEmpty) return const [];
    return [
      FmTypePill(
        key: const ValueKey('type-pill'),
        counts: counts,
        present: present,
        selected: selected,
        onChanged: onChanged,
      ),
    ];
  }

  /// `FsEntry` listesi için çipler: sayılar [filter]'ın **tür dışı**
  /// ölçütlerinden geçen girdilerden çıkar; dokunuş `filter.withTypes`.
  static List<Widget> forEntries(
    BuildContext context, {
    required List<FsEntry> source,
    required FmFilter filter,
    required ValueChanged<FmFilter> onChanged,
    String query = '',
    Set<String> Function(String path)? tagsOf,
    int? Function(String path)? openedAtOf,
    String cacheSalt = '',
  }) =>
      build(
        context,
        counts: countsFor(source, filter,
            query: query,
            tagsOf: tagsOf,
            openedAtOf: openedAtOf,
            cacheSalt: cacheSalt),
        selected: filter.types,
        onChanged: (types) => onChanged(filter.withTypes(types)),
      );

  static final _cache = Expando<(String, Map<FmType, int>)>('fmTypeCounts');

  /// Tür sayıları — seçili türler hariç bütün ölçütler uygulanmış hâliyle.
  ///
  /// Liste (kimlik + uzunluk) ve süzgeç imzası değişmedikçe yeniden sayılmaz:
  /// 20 bin dosyalı bir kategoride her karede saymak ekranı kastırırdı (aynı
  /// ders: `category_screen._sorted`). [cacheSalt] dış durumu (ör.
  /// `OpenHistory.revision`) anahtara katar.
  static Map<FmType, int> countsFor(
    List<FsEntry> source,
    FmFilter filter, {
    String query = '',
    Set<String> Function(String path)? tagsOf,
    int? Function(String path)? openedAtOf,
    String cacheSalt = '',
  }) {
    final base = filter.withTypes(const {});
    final key = '${source.length}|${base.signature}|$query|$cacheSalt';
    final hit = _cache[source];
    if (hit != null && hit.$1 == key) return hit.$2;
    final now = DateTime.now();
    final counts = fmTypeCounts([
      for (final e in source)
        if (base.matches(e,
            query: query, now: now, tagsOf: tagsOf, openedAtOf: openedAtOf))
          FmType.of(e),
    ]);
    _cache[source] = (key, counts);
    return counts;
  }
}

/// Tarih ▾ ve Boyut ▾ açılır pilleri (gezginin süzgeç satırı) — [FmFilter]'ın
/// kendi aralıkları, kategori ekranlarıyla aynı mantık.
List<Widget> fmDateSizePills(
  BuildContext context, {
  required FmFilter filter,
  required ValueChanged<FmFilter> onChanged,
}) =>
    [
      PopupMenuButton<FmDateRange>(
        tooltip: context.t('list.date'),
        onSelected: (v) => onChanged(filter.withDateRange(v)),
        itemBuilder: (_) => [
          for (final r
              in FmDateRange.values.where((r) => r != FmDateRange.custom))
            CheckedPopupMenuItem(
              value: r,
              checked: filter.dateRange == r,
              child: Text(context.t(r.labelKey)),
            ),
        ],
        child: FmPill(
          label: filter.dateRange == FmDateRange.any
              ? context.t('list.date')
              : context.t(filter.dateRange.labelKey),
          dropdown: true,
          highlighted: filter.dateRange != FmDateRange.any,
        ),
      ),
      PopupMenuButton<FmSizeRange>(
        tooltip: context.t('list.size'),
        onSelected: (v) => onChanged(filter.withSizeRange(v)),
        itemBuilder: (_) => [
          for (final r in FmSizeRange.values)
            CheckedPopupMenuItem(
              value: r,
              checked: filter.sizeRange == r,
              child: Text(context.t(r.labelKey)),
            ),
        ],
        child: FmPill(
          label: filter.sizeRange == FmSizeRange.any
              ? context.t('list.size')
              : context.t(filter.sizeRange.labelKey),
          dropdown: true,
          highlighted: filter.sizeRange != FmSizeRange.any,
        ),
      ),
    ];

/// Türün levhadaki simgesi ve rengi (belge alt türleri Office renklerinde).
(IconData, Color) fmTypeStyle(FmType t) => switch (t) {
      FmType.pdf => (AppIcons.pdf, OfficeColors.pdf),
      FmType.word => (AppIcons.newWord, OfficeColors.word),
      FmType.excel => (AppIcons.gridOn, OfficeColors.excel),
      FmType.slides => (AppIcons.slideshow, OfficeColors.slides),
      FmType.text => (AppIcons.textSnippet, FmColors.other),
      FmType.ebook => (AppIcons.menuBook, FmColors.archive),
      FmType.docOther => (AppIcons.insertDriveFile, FmColors.other),
      _ => (FmColors.iconFor(t.category), FmColors.forCategory(t.category)),
    };

/// Tür süzgecinin **açılır hapı**: "Tüm türler · 142 ▾", tek tür seçiliyse
/// "PDF · 59 ▾" (vurgulu, türün simgesiyle), çoğulsa "PDF +1 · 70 ▾".
class FmTypePill extends StatelessWidget {
  final Map<FmType, int> counts;
  final List<FmType> present;
  final Set<FmType> selected;
  final ValueChanged<Set<FmType>> onChanged;

  const FmTypePill({
    super.key,
    required this.counts,
    required this.present,
    required this.selected,
    required this.onChanged,
  });

  int get _shown => selected.isEmpty
      ? counts.values.fold<int>(0, (a, b) => a + b)
      : selected.fold<int>(0, (a, t) => a + (counts[t] ?? 0));

  @override
  Widget build(BuildContext context) {
    final ordered = [
      for (final t in FmType.values)
        if (selected.contains(t)) t,
    ];
    final String label;
    final IconData icon;
    if (ordered.isEmpty) {
      label = context.t('typ.all_types');
      icon = AppIcons.typeAll;
    } else {
      final first = context.t(ordered.first.labelKey);
      label = ordered.length == 1
          ? first
          : context.t('typ.more_n', {'name': first, 'n': ordered.length - 1});
      icon = fmTypeStyle(ordered.first).$1;
    }
    return Tooltip(
      message: context.t('typ.title'),
      child: Semantics(
        button: true,
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: () => showFmTypeSheet(
            context,
            counts: counts,
            present: present,
            selected: selected,
            onChanged: onChanged,
          ),
          child: FmPill(
            icon: icon,
            label: label,
            count: _shown,
            dropdown: true,
            highlighted: ordered.isNotEmpty,
          ),
        ),
      ),
    );
  }
}

/// **Tür levhası**: her tür büyük bir kutu (simge · ad · sayı). Dokunuş türü
/// ekler/çıkarır ve liste ARKADA hemen süzülür; "Tüm türler" seçimi
/// temizler; alttaki düğme "N dosyayı göster" diyerek kapatır.
Future<void> showFmTypeSheet(
  BuildContext context, {
  required Map<FmType, int> counts,
  required List<FmType> present,
  required Set<FmType> selected,
  required ValueChanged<Set<FmType>> onChanged,
}) {
  var current = {...selected};
  return showAppSheet<void>(
    context,
    title: context.t('typ.title'),
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        void set(Set<FmType> next) {
          setSheet(() => current = next);
          onChanged(next);
        }

        final total = counts.values.fold<int>(0, (a, b) => a + b);
        final shown = current.isEmpty
            ? total
            : current.fold<int>(0, (a, t) => a + (counts[t] ?? 0));
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsetsDirectional.only(
                    start: Gap.sm, bottom: Gap.md),
                child: Text(
                  ctx.t('typ.hint'),
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant),
                ),
              ),
              LayoutBuilder(builder: (ctx, c) {
                // 3 sütun (dar ekranda/büyük yazıda 2): kutular eşit genişlikte.
                final cols = c.maxWidth < 300 ? 2 : 3;
                final w = (c.maxWidth - Gap.sm * (cols - 1)) / cols;
                return Wrap(
                  spacing: Gap.sm,
                  runSpacing: Gap.sm,
                  children: [
                    FmChoiceTile(
                      key: const ValueKey('type-all'),
                      width: w,
                      icon: AppIcons.typeAll,
                      color: Theme.of(ctx).colorScheme.primary,
                      label: ctx.t('typ.all_types'),
                      count: total,
                      selected: current.isEmpty,
                      onTap: () => set(const {}),
                    ),
                    for (final t in present)
                      FmChoiceTile(
                        key: ValueKey('type-${t.name}'),
                        width: w,
                        icon: fmTypeStyle(t).$1,
                        color: fmTypeStyle(t).$2,
                        label: ctx.t(t.labelKey),
                        count: counts[t] ?? 0,
                        selected: current.contains(t),
                        onTap: () {
                          final next = {...current};
                          if (!next.remove(t)) next.add(t);
                          set(next);
                        },
                      ),
                  ],
                );
              }),
              const SizedBox(height: Gap.md),
              FilledButton(
                key: const ValueKey('type-done'),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(ctx.t('typ.show_n', {'n': shown})),
              ),
            ],
          ),
        );
      },
    ),
  );
}

/// Levhalardaki kart kutusu (tür, kaynak, zaman, boyut için ortak).
class FmChoiceTile extends StatelessWidget {
  final double width;
  final IconData icon;
  final Color color;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const FmChoiceTile({
    super.key,
    required this.width,
    required this.icon,
    required this.color,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        selected: selected,
        child: AnimatedContainer(
          duration: Motion.of(context, Motion.short),
          curve: Motion.standard,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? scheme.primary : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    Gap.sm, Gap.md, Gap.sm, Gap.sm),
                child: Stack(
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(icon, color: color, size: 22),
                        ),
                        const SizedBox(height: Gap.xs),
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight:
                                selected ? FontWeight.w700 : FontWeight.w600,
                            color: selected
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                        Text(
                          '$count',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontFeatures: const [
                              FontFeature.tabularFigures()
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (selected)
                      PositionedDirectional(
                        top: 0,
                        end: 0,
                        child: Icon(AppIcons.checkCircle,
                            size: 18, color: scheme.primary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

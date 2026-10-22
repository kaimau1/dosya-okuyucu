import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
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
  /// Çip listesini üretir. [counts] seçili türlerden bağımsız (öteki
  /// ölçütlerle süzülmüş) tür sayıları, [total] onların toplamı.
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
    // Tek türlü listede tür çipi bilgi taşımaz (hepsi PDF'se "PDF" çipi hiçbir
    // şey süzmez, yalnız satırda yer kaplar).
    if (present.length < 2 && selected.isEmpty) return const [];
    final total = counts.values.fold<int>(0, (a, b) => a + b);
    return [
      FmChip(
        key: const ValueKey('type-all'),
        label: context.t('flt.all'),
        count: total,
        selected: selected.isEmpty,
        onTap: () => onChanged(const {}),
      ),
      for (final t in present)
        FmChip(
          key: ValueKey('type-${t.name}'),
          label: context.t(t.labelKey),
          count: counts[t],
          selected: selected.contains(t),
          onTap: () {
            final next = {...selected};
            if (!next.remove(t)) next.add(t);
            onChanged(next);
          },
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

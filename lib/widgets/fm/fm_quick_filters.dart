import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';

/// Liste ekranlarının üstündeki **tek dokunuşluk süzgeç çipleri**.
///
/// Süzgeç sayfası (`showFmFilterSheet`) her şeyi yapabiliyordu ama üç dokunuş
/// uzaktaydı; kullanıcının en sık istediği üç-beş süzme (WhatsApp'tan gelenler,
/// büyük dosyalar, uzun zamandır açılmayanlar) burada bir dokunuşa indi.
///
/// **Kaynak çipleri veriden türetilir, sabit değildir:** listede WhatsApp
/// dosyası yoksa WhatsApp çipi hiç çizilmez ve her çipin üstünde kaç dosyaya
/// denk geldiği yazar. Sabit bir kaynak listesi, boş çiplere dokunup "hiçbir
/// şey yok" görmeye yol açardı.
class FmQuickFilters extends StatelessWidget {
  /// Çiplerin sayıları ve hangi kaynakların görüneceği bu listeden çıkar.
  /// Süzülmemiş (ham) liste verilmelidir.
  final List<FsEntry> source;

  final FmFilter filter;
  final ValueChanged<FmFilter> onChanged;

  /// "Şu kadar gündür açılmamış" çipinin eşiği (varsayılan 6 ay).
  final int untouchedDays;

  /// Kaynak çipleri çizilsin mi? Kendi kaynak satırı olan ekranlar (galeri)
  /// bunu kapatır — aynı çip iki kez görünmesin.
  final bool showBuckets;

  const FmQuickFilters({
    super.key,
    required this.source,
    required this.filter,
    required this.onChanged,
    this.untouchedDays = 180,
    this.showBuckets = true,
  });

  /// Kaynak → dosya sayısı (yalnız gerçekten bulunanlar, çok olandan aza).
  List<(MediaBucket, int)> _buckets() {
    final counts = <MediaBucket, int>{};
    for (final e in source) {
      if (e.isDir) continue;
      final b = bucketForPath(e.path);
      if (b == MediaBucket.other) continue; // "Diğer" çipinin bilgi değeri yok
      counts[b] = (counts[b] ?? 0) + 1;
    }
    final list = counts.entries.map((e) => (e.key, e.value)).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    return list;
  }

  int _untouchedCount() {
    final cutoff = DateTime.now()
        .subtract(Duration(days: untouchedDays))
        .millisecondsSinceEpoch;
    var n = 0;
    for (final e in source) {
      if (!e.isDir && e.lastTouchedMs <= cutoff) n++;
    }
    return n;
  }

  int _largeCount() {
    var n = 0;
    for (final e in source) {
      if (!e.isDir && e.sizeBytes >= FmSizeRange.large.minBytes) n++;
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    final buckets = showBuckets ? _buckets() : const <(MediaBucket, int)>[];
    final untouched = _untouchedCount();
    final large = _largeCount();
    if (buckets.isEmpty && untouched == 0 && large == 0) {
      return const SizedBox.shrink();
    }

    Widget chip(String label, int count, bool selected, VoidCallback onTap) =>
        Padding(
          padding: const EdgeInsets.only(right: Gap.sm),
          child: FilterChip(
            selected: selected,
            visualDensity: VisualDensity.compact,
            label: Text(count > 0 ? '$label · $count' : label),
            onSelected: (_) => onTap(),
          ),
        );

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Gap.md),
        children: [
          if (untouched > 0)
            chip(
              context.t('fm.quick_untouched', {'n': untouchedDays ~/ 30}),
              untouched,
              filter.untouchedDays != null,
              () => onChanged(filter.withUntouchedDays(
                  filter.untouchedDays == null ? untouchedDays : null)),
            ),
          if (large > 0)
            chip(
              FmSizeRange.large.label,
              large,
              filter.sizeRange == FmSizeRange.large,
              () => onChanged(filter.withSizeRange(
                  filter.sizeRange == FmSizeRange.large
                      ? FmSizeRange.any
                      : FmSizeRange.large)),
            ),
          for (final (bucket, count) in buckets)
            chip(
              bucket.label,
              count,
              filter.buckets.contains(bucket),
              () => onChanged(filter.toggleBucket(bucket)),
            ),
        ],
      ),
    );
  }
}

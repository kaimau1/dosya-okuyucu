import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/open_history.dart';

/// Liste ekranlarının üstündeki **tek dokunuşluk süzgeç çipleri**.
///
/// Süzgeç sayfası (`showFmFilterSheet`) her şeyi yapabiliyordu ama üç dokunuş
/// uzaktaydı; kullanıcının en sık istediği süzmeler (WhatsApp'tan gelenler,
/// büyük dosyalar, uzun zamandır açılmayanlar, son altı ayda açılanlar) burada
/// bir dokunuşa indi.
///
/// **Kaynak çipleri veriden türetilir, sabit değildir:** listede WhatsApp
/// dosyası yoksa WhatsApp çipi hiç çizilmez ve her çipin üstünde kaç dosyaya
/// denk geldiği yazar. Sabit bir kaynak listesi, boş çiplere dokunup "hiçbir
/// şey yok" görmeye yol açardı.
///
/// **Sayılar ÖTEKİ ölçütlere bağlıdır (2026-08-09).** Eskiden her çip ham
/// listeyi sayıyordu: "Büyük dosyalar · 312" yazan çipe, WhatsApp çipi zaten
/// seçiliyken dokununca 4 dosya çıkıyordu. Kullanıcının "filtreler doğru
/// çalışmıyor" demesinin bir sebebi buydu — çipin sayısı verdiği sonucu değil,
/// başka bir soruyu yanıtlıyordu. Artık her sayı **"dokunursam kaç dosya
/// kalır"**ın karşılığı.
class FmQuickFilters extends StatefulWidget {
  /// Çiplerin sayıları ve hangi kaynakların görüneceği bu listeden çıkar.
  /// Süzülmemiş (ham) liste verilmelidir.
  final List<FsEntry> source;

  final FmFilter filter;
  final ValueChanged<FmFilter> onChanged;

  /// "Şu kadar gündür açılmamış" / "son şu kadar günde açılmış" eşiği.
  final int untouchedDays;

  /// Kaynak çipleri çizilsin mi? Kendi kaynak satırı olan ekranlar (galeri)
  /// bunu kapatır — aynı çip iki kez görünmesin.
  final bool showBuckets;

  /// Satırın sonuna eklenecek ekrana özel çipler (ör. belge türleri).
  ///
  /// **Niye burada:** kategori ekranında bu satırın ALTINDA ikinci bir çip
  /// satırı daha vardı; ikisi birlikte 92 dp yer kaplıyor, telefon ekranında
  /// listeye kalan yeri gözle görülür daraltıyordu (kullanıcı 2026-08-09:
  /// *"üst filtre alanları çok yer kaplıyor, sayfa daralıyor"*). Tek satır,
  /// yatay kaydırmalı.
  final List<Widget> extraChips;

  const FmQuickFilters({
    super.key,
    required this.source,
    required this.filter,
    required this.onChanged,
    this.untouchedDays = 180,
    this.showBuckets = true,
    this.extraChips = const [],
  });

  @override
  State<FmQuickFilters> createState() => _FmQuickFiltersState();
}

/// Bir çizim için hesaplanmış çip sayıları.
class _Counts {
  final List<(MediaBucket, int)> buckets;
  final int untouched;
  final int openedWithin;
  final int large;
  const _Counts(this.buckets, this.untouched, this.openedWithin, this.large);
}

class _FmQuickFiltersState extends State<FmQuickFilters> {
  _Counts? _cache;
  String? _cacheKey;

  /// Sayım anahtarı: liste ya da süzgeç değişmedikçe yeniden sayılmaz.
  ///
  /// Sayılar artık öteki ölçütlere bağlı olduğu için her çip listeyi bir kez
  /// geziyor; 20 bin dosyalı bir kategoride bunu HER karede yapmak ekranı
  /// kastırırdı (aynı ders: `category_screen._sorted` önbelleği).
  String get _key => '${identityHashCode(widget.source)}|'
      '${widget.source.length}|${widget.filter.signature}|'
      '${widget.untouchedDays}|${widget.showBuckets}|'
      '${OpenHistory.revision}';

  _Counts get _counts {
    final key = _key;
    final cached = _cache;
    if (cached != null && _cacheKey == key) return cached;
    final computed = _compute();
    _cache = computed;
    _cacheKey = key;
    return computed;
  }

  /// [probe] ölçütü eklenmiş süzgeçten kaç dosya geçer?
  int _countWith(FmFilter probe) {
    var n = 0;
    for (final e in widget.source) {
      if (e.isDir) continue;
      if (probe.matches(e, openedAtOf: OpenHistory.forPath)) n++;
    }
    return n;
  }

  _Counts _compute() {
    final f = widget.filter;
    // Kaynak çipleri: hangi kaynaklar VAR (ham listeden) — çipin çizilip
    // çizilmeyeceği listenin içeriğine bakar, sayısı ise süzgece.
    final present = <MediaBucket>{};
    if (widget.showBuckets) {
      for (final e in widget.source) {
        if (e.isDir) continue;
        final b = bucketForPath(e.path);
        if (b == MediaBucket.other) continue; // "Diğer" çipinin bilgi değeri yok
        present.add(b);
      }
    }
    final buckets = <(MediaBucket, int)>[];
    for (final b in present) {
      // Seçili çipin sayısı "şu an kaç tane görünüyor"; seçili değilse
      // "dokunursam kaç tane kalır". İkisi de aynı hesap.
      final probe = f.buckets.contains(b) ? f : f.toggleBucket(b);
      buckets.add((b, _countWith(probe)));
    }
    buckets.sort((a, b) => b.$2.compareTo(a.$2));

    return _Counts(
      buckets,
      _countWith(f.untouchedDays == null
          ? f.withUntouchedDays(widget.untouchedDays)
          : f),
      _countWith(f.openedWithinDays == null
          ? f.withOpenedWithinDays(widget.untouchedDays)
          : f),
      _countWith(f.sizeRange == FmSizeRange.large
          ? f
          : f.withSizeRange(FmSizeRange.large)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final counts = _counts;
    final f = widget.filter;
    final months = widget.untouchedDays ~/ 30;
    if (counts.buckets.isEmpty &&
        counts.untouched == 0 &&
        counts.openedWithin == 0 &&
        counts.large == 0 &&
        widget.extraChips.isEmpty) {
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
          ...widget.extraChips,
          // "Son 6 ayda açılanlar" ÖNCE: kullanıcının aradığı dosya çoğunlukla
          // yakında dokunduğu dosyadır; "açılmamışlar" yer açma işidir.
          if (counts.openedWithin > 0 || f.openedWithinDays != null)
            chip(
              context.t('fm.quick_opened_within', {'n': months}),
              counts.openedWithin,
              f.openedWithinDays != null,
              () => widget.onChanged(widget.filter.withOpenedWithinDays(
                  f.openedWithinDays == null ? widget.untouchedDays : null)),
            ),
          if (counts.untouched > 0 || f.untouchedDays != null)
            chip(
              context.t('fm.quick_untouched', {'n': months}),
              counts.untouched,
              f.untouchedDays != null,
              () => widget.onChanged(widget.filter.withUntouchedDays(
                  f.untouchedDays == null ? widget.untouchedDays : null)),
            ),
          if (counts.large > 0 || f.sizeRange == FmSizeRange.large)
            chip(
              context.t(FmSizeRange.large.labelKey),
              counts.large,
              f.sizeRange == FmSizeRange.large,
              () => widget.onChanged(widget.filter.withSizeRange(
                  f.sizeRange == FmSizeRange.large
                      ? FmSizeRange.any
                      : FmSizeRange.large)),
            ),
          for (final (bucket, count) in counts.buckets)
            chip(
              // Çeviri anahtarı: `bucket.label` Türkçe SABİT ("Kamera",
              // "İndirilenler"), ekranda gösterilen ad ondan bağımsız olmalı.
              context.t(bucket.labelKey),
              count,
              f.buckets.contains(bucket),
              () => widget.onChanged(widget.filter.toggleBucket(bucket)),
            ),
        ],
      ),
    );
  }
}

import '../../models/fm_type.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import 'smart_analysis.dart';

/// Bir tür/kaynak/ay diliminin sayısı ve boyutu.
class InsightSlice<K> {
  final K key;
  final int count;
  final int bytes;
  const InsightSlice(this.key, this.count, this.bytes);
}

/// **Bir listenin (kategori / hızlı klasör) yerel özeti** — "bu 161 belgede
/// ne var, neyi temizleyebilirim?" sorusunun cevabı.
///
/// Kullanıcı isteği (2026-10-23): *"bu tür hızlı klasörlerde bir ayar menüsü
/// ile özet analiz, genel analiz, AI analiz vb. işlevler yapılabilmeli"*.
///
/// Tamamen **cihazda** ve bellekteki listeden hesaplanır (disk okunmaz, ağ
/// yok) — 20 bin girdide bile milisaniyeler. AI analizi bunun üstüne kurulur:
/// buluta ham liste değil bu özet + örnek adlar gider (bkz.
/// `category_tools_sheet.dart`).
class CollectionInsights {
  final int count;
  final int bytes;

  /// Tür dilimleri, boyutça büyükten küçüğe.
  final List<InsightSlice<FmType>> byType;

  /// Kaynak dilimleri (WhatsApp, İndirilenler…), sayıca büyükten küçüğe.
  final List<InsightSlice<MediaBucket>> bySource;

  /// Son 12 ayın sayıları (eskiden yeniye; ilk öğe 11 ay önce).
  final List<InsightSlice<DateTime>> byMonth;

  /// En büyük dosyalar (en çok 5).
  final List<FsEntry> largest;

  /// [staleDays]'den uzun süredir açılmamış/değişmemiş dosyalar.
  final List<FsEntry> stale;

  /// Aynı klasörde aslıyla aynı boyutta duran "(1)" / "kopya" adlı dosyalar.
  final List<FsEntry> copies;

  /// Etiketli dosya sayısı ve en sık etiketler.
  final int tagged;
  final List<MapEntry<String, int>> topTags;

  const CollectionInsights({
    required this.count,
    required this.bytes,
    required this.byType,
    required this.bySource,
    required this.byMonth,
    required this.largest,
    required this.stale,
    required this.copies,
    required this.tagged,
    required this.topTags,
  });

  static const staleDays = 180;

  int get staleBytes => stale.fold<int>(0, (s, e) => s + e.sizeBytes);
  int get copyBytes => copies.fold<int>(0, (s, e) => s + e.sizeBytes);

  /// Son 30 günde gelen dosya sayısı.
  int get lastMonthCount => byMonth.isEmpty ? 0 : byMonth.last.count;

  static CollectionInsights of(
    List<FsEntry> entries, {
    int? nowMs,
    int? Function(String path)? openedAtOf,
    Set<String> Function(String path)? tagsOf,
  }) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final files = [for (final e in entries) if (!e.isDir) e];
    var bytes = 0;
    final typeCount = <FmType, int>{};
    final typeBytes = <FmType, int>{};
    final srcCount = <MediaBucket, int>{};
    final srcBytes = <MediaBucket, int>{};
    final nowDate = DateTime.fromMillisecondsSinceEpoch(now);
    final months = [
      for (var i = 11; i >= 0; i--) DateTime(nowDate.year, nowDate.month - i),
    ];
    final monthCount = List<int>.filled(12, 0);
    final monthBytes = List<int>.filled(12, 0);
    final staleBefore = now - staleDays * Duration.millisecondsPerDay;
    final stale = <FsEntry>[];
    final tagCounts = <String, int>{};
    var tagged = 0;
    for (final e in files) {
      bytes += e.sizeBytes;
      final t = FmType.of(e);
      typeCount[t] = (typeCount[t] ?? 0) + 1;
      typeBytes[t] = (typeBytes[t] ?? 0) + e.sizeBytes;
      final b = bucketForPath(e.path);
      srcCount[b] = (srcCount[b] ?? 0) + 1;
      srcBytes[b] = (srcBytes[b] ?? 0) + e.sizeBytes;
      final d = DateTime.fromMillisecondsSinceEpoch(e.modifiedMs);
      final idx = 11 -
          ((nowDate.year - d.year) * 12 + (nowDate.month - d.month));
      if (idx >= 0 && idx < 12) {
        monthCount[idx]++;
        monthBytes[idx] += e.sizeBytes;
      }
      final seen = [e.lastTouchedMs, openedAtOf?.call(e.path) ?? 0]
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (seen > 0 && seen < staleBefore) stale.add(e);
      final tags = tagsOf?.call(e.path) ?? const <String>{};
      if (tags.isNotEmpty) {
        tagged++;
        for (final tag in tags) {
          tagCounts[tag] = (tagCounts[tag] ?? 0) + 1;
        }
      }
    }
    final largest = [...files]
      ..sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    stale.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    return CollectionInsights(
      count: files.length,
      bytes: bytes,
      byType: [
        for (final t in typeCount.keys)
          InsightSlice(t, typeCount[t]!, typeBytes[t]!),
      ]..sort((a, b) => b.bytes.compareTo(a.bytes)),
      bySource: [
        for (final s in srcCount.keys)
          InsightSlice(s, srcCount[s]!, srcBytes[s]!),
      ]..sort((a, b) => b.count.compareTo(a.count)),
      byMonth: [
        for (var i = 0; i < 12; i++)
          InsightSlice(months[i], monthCount[i], monthBytes[i]),
      ],
      largest: largest.take(5).toList(),
      stale: stale,
      copies: SmartAnalysis.copyNamed(files),
      tagged: tagged,
      topTags: (tagCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(8)
          .toList(),
    );
  }

  /// AI analizine giden **özet metin** (ad listesi değil, sayılar).
  String describe(String Function(String key) t) {
    final b = StringBuffer()
      ..writeln('Toplam: $count dosya, ${(bytes / 1048576).toStringAsFixed(1)} MB')
      ..writeln('Türler: ${[
        for (final s in byType.take(8)) '${t(s.key.labelKey)} ${s.count}'
      ].join(', ')}')
      ..writeln('Kaynaklar: ${[
        for (final s in bySource.take(6)) '${t(s.key.labelKey)} ${s.count}'
      ].join(', ')}')
      ..writeln('Son 12 ay (eskiden yeniye): ${[
        for (final m in byMonth) m.count
      ].join(' ')}')
      ..writeln('$staleDays günden uzun süredir açılmamış: ${stale.length} '
          '(${(staleBytes / 1048576).toStringAsFixed(1)} MB)')
      ..writeln('Kopya adlı dosya: ${copies.length}')
      ..writeln('Etiketli: $tagged');
    return b.toString();
  }
}

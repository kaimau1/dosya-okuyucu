/// **Cihaz raporu** — analiz sonucunun tek ekranlık özeti.
///
/// Tamamen yerel hesaplanır: rapor için ayrıca token harcamak gereksiz, çünkü
/// bütün bilgi zaten indekste. AI'nın katkısı kayıtların içinde (tür, önem);
/// rapor onları sayar.
library;

import '../../models/fs_entry.dart';
import 'ai_index.dart';

/// Önem eşikleri — arayüz ve rapor aynı sınırları kullansın diye tek yerde.
abstract final class AiImportance {
  /// "Önemli evrak" sayılan alt sınır.
  static const important = 70;

  /// "Silinebilir aday" üst sınırı.
  static const junk = 20;
}

class AiReport {
  /// Analiz edilmiş dosya sayısı.
  final int analyzed;

  /// Bu dosyaların kapladığı toplam alan.
  final int totalBytes;

  /// Önemli evrak (önem ≥ [AiImportance.important]).
  final List<AiRecord> important;

  /// Düşük önemli, yer kaplayan adaylar (önem ≤ [AiImportance.junk]).
  final List<AiRecord> junk;

  /// Bekleyen ad/klasör önerileri.
  final List<AiRecord> suggestions;

  /// Tür → adet (en çoktan aza).
  final List<MapEntry<String, int>> byType;

  /// Kategori → adet.
  final Map<FmCategory, int> byCategory;

  const AiReport({
    required this.analyzed,
    required this.totalBytes,
    required this.important,
    required this.junk,
    required this.suggestions,
    required this.byType,
    required this.byCategory,
  });

  static const empty = AiReport(
    analyzed: 0,
    totalBytes: 0,
    important: [],
    junk: [],
    suggestions: [],
    byType: [],
    byCategory: {},
  );

  /// Çöp adaylarının toplam boyutu — "şu kadar yer boşaltılabilir".
  int get junkBytes {
    var sum = 0;
    for (final r in junk) {
      sum += r.sizeBytes;
    }
    return sum;
  }

  /// Kayıtlardan raporu kurar. Saf fonksiyon — birim testiyle doğrulanır.
  static AiReport build(List<AiRecord> records) {
    if (records.isEmpty) return empty;
    final important = <AiRecord>[];
    final junk = <AiRecord>[];
    final suggestions = <AiRecord>[];
    final types = <String, int>{};
    final categories = <FmCategory, int>{};
    var bytes = 0;
    var analyzed = 0;

    for (final r in records) {
      if (r.analyzedMs == 0) continue;
      analyzed++;
      bytes += r.sizeBytes;
      if (r.importance >= AiImportance.important) important.add(r);
      // Önem 0 = "değerlendirilmedi"; çöp adayı saymak yanlış olurdu.
      if (r.importance > 0 && r.importance <= AiImportance.junk) junk.add(r);
      if (r.hasSuggestion) suggestions.add(r);
      if (r.docType.isNotEmpty) {
        types[r.docType] = (types[r.docType] ?? 0) + 1;
      }
      categories[r.category] = (categories[r.category] ?? 0) + 1;
    }

    important.sort((a, b) => b.importance.compareTo(a.importance));
    junk.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
    final byType = types.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return AiReport(
      analyzed: analyzed,
      totalBytes: bytes,
      important: important,
      junk: junk,
      suggestions: suggestions,
      byType: byType,
      byCategory: categories,
    );
  }
}

/// **Analiz sonucunu KOVALARA ayırmak** — "ne işe yarıyor, ne yapacağım"
/// sorusunun cevabı.
///
/// KÖK NEDEN (2026-08-11 kullanıcı, cihaz denemesi): *"AI analiz ediyor ama ne
/// işe yarıyor, kullanıcı ne yapacak belli değil; yaptıklarının yansıması
/// nerede belli değil."* Rapor sayı gösteriyordu ama sayıya dokunulamıyordu ve
/// sayının arkasındaki dosyalara ulaşılamıyordu. Kova, sayının **tıklanabilir**
/// karşılığıdır: her kova bir liste + o listeye uygun toplu işlem demek.
///
/// Ayrıca iki dürüstlük düzeltmesi burada:
/// 1. **"Silinebilir aday" dar tanımlı.** Eski kural "önem ≤ 20" idi ve
///    kullanıcının 3419 fotoğrafı + 919 ekran görüntüsü bu kovaya düşüyordu:
///    ekran "8,3 GB silinebilir" diyordu. Fotoğrafa "sil" demek, dosya
///    yöneticisinin verebileceği en tehlikeli tavsiye. Artık silme önerisi
///    yalnız **gerçekten harcanabilir** türlere veriliyor; kalan düşük önemli
///    yığın ayrı bir kovada, "gözden geçir" diliyle duruyor.
/// 2. **Tür adları tekilleştiriliyor.** Model bir dosyaya "fotoğraf", ötekine
///    "fotograf" diyor; rapor ikisini ayrı satır sayıyordu (3419 + 413).
///    [canonicalDocType] Türkçe katlama + eşanlam tablosuyla tek ada indiriyor.
library;

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import 'ai_index.dart';
import 'ai_report.dart';

/// Analiz sonucunun tıklanabilir grupları.
enum AiBucket {
  /// Önem ≥ 70 — resmî evrak, sözleşme, kimlik, fatura.
  important,

  /// Gerçekten harcanabilir dosyalar (bkz. [_disposableTypes]).
  disposable,

  /// Düşük önemli ama silme önerisi verilmeyen yığın (fotoğraf, video…).
  lowValue,

  /// Ad/klasör önerisi bekleyen dosyalar.
  suggestions,

  /// Tek bir tür (rapordaki "Türlere göre" satırına dokununca).
  docType,

  /// Analiz edilmiş her şey.
  all,
}

abstract final class AiBuckets {
  /// Silme önerisi verilebilecek türler.
  ///
  /// Liste bilinçli olarak **kısa**: buraya bir tür eklemek, kullanıcıya o
  /// dosyaları toplu silmeyi önermek demektir. Fotoğraf ve video burada YOK —
  /// düşük önemli olabilirler ama silinmeleri kullanıcının anısını siler.
  static const _disposableTypes = {
    'ekran goruntusu',
    'gecici dosya',
    'onbellek',
    'kurulum dosyasi',
    'reklam',
    'meme',
    'log',
    'yedek parca',
  };

  /// Model çıktısındaki tür adını **tek biçime** indirger.
  ///
  /// Türkçe katlama (`fotoğraf` → `fotograf`) + eşanlam tablosu. Boş/anlamsız
  /// değerler `diğer`e düşer; rapor "" başlıklı bir satır göstermemeli.
  static String canonicalDocType(String raw) {
    final folded = asciiFold(raw).trim();
    if (folded.isEmpty) return 'diger';
    // Çoğul/ek kırpma: "faturalar" → "fatura", "sözleşmesi" → "sozlesme".
    final base = _synonyms[folded] ?? folded;
    return _synonyms[base] ?? base;
  }

  /// Katlanmış ad → kanonik ad.
  static const _synonyms = {
    'fotograflar': 'fotograf',
    'resim': 'fotograf',
    'resimler': 'fotograf',
    'gorsel': 'fotograf',
    'goruntu': 'fotograf',
    'ekran goruntuleri': 'ekran goruntusu',
    'screenshot': 'ekran goruntusu',
    'faturalar': 'fatura',
    'fis': 'makbuz',
    'makbuzlar': 'makbuz',
    'sozlesmesi': 'sozlesme',
    'sozlesmeler': 'sozlesme',
    'kontrat': 'sozlesme',
    'kimlik belgesi': 'kimlik',
    'resmi evrak': 'kimlik',
    'saglik belgesi': 'saglik',
    'tibbi': 'saglik',
    'muzik': 'muzik',
    'ses': 'muzik',
    'sarki': 'muzik',
    'videolar': 'video',
    'film': 'video',
    'egitim materyali': 'egitim',
    'ders notu': 'egitim',
    'yazismalar': 'yazisma',
    'mesaj': 'yazisma',
    'kod': 'kod',
    'arsiv': 'arsiv',
    'zip': 'arsiv',
    'bilinmiyor': 'diger',
    '': 'diger',
  };

  /// Tür adının **gösterilecek** hâli (ilk harf büyük, Türkçe kalır).
  ///
  /// Katlanmış ad depolama/karşılaştırma içindir; kullanıcıya `fotograf`
  /// yazmak özensiz görünür. Tablo yalnız sık türleri düzeltir, kalanı olduğu
  /// gibi büyütür — modelin ürettiği yeni bir tür de okunur çıksın.
  static String label(String canonical) =>
      _labels[canonical] ??
      (canonical.isEmpty
          ? 'Diğer'
          : canonical[0].toUpperCase() + canonical.substring(1));

  static const _labels = {
    'fotograf': 'Fotoğraf',
    'ekran goruntusu': 'Ekran görüntüsü',
    'fatura': 'Fatura',
    'makbuz': 'Makbuz',
    'sozlesme': 'Sözleşme',
    'kimlik': 'Kimlik ve resmî evrak',
    'saglik': 'Sağlık',
    'banka': 'Banka',
    'egitim': 'Eğitim',
    'bilet': 'Bilet',
    'yazisma': 'Yazışma',
    'muzik': 'Müzik',
    'video': 'Video',
    'arsiv': 'Arşiv',
    'kod': 'Kod',
    'sigorta': 'Sigorta',
    'diger': 'Diğer',
  };

  /// Bu kayıt silme önerisine uygun mu?
  ///
  /// İki koşul birlikte: AI düşük önem vermiş **ve** tür gerçekten harcanabilir.
  /// Tek başına düşük önem yetmez — kullanıcının tatil fotoğrafı da düşük önem
  /// alır.
  static bool isDisposable(AiRecord record) {
    if (record.importance <= 0 || record.importance > AiImportance.junk) {
      return false;
    }
    return _disposableTypes.contains(canonicalDocType(record.docType));
  }

  /// Düşük önemli ama silinmesi önerilmeyen yığın (gözden geçirme kovası).
  static bool isLowValue(AiRecord record) =>
      record.importance > 0 &&
      record.importance <= AiImportance.junk &&
      !isDisposable(record);

  /// Kovaya giren kayıtlar. [docType] yalnız [AiBucket.docType] için gerekli.
  static List<AiRecord> of(
    AiBucket bucket, {
    String? docType,
    Iterable<AiRecord>? source,
  }) {
    final records = source ?? AiIndex.all();
    final wanted = docType == null ? null : canonicalDocType(docType);
    final out = <AiRecord>[
      for (final record in records)
        if (record.analyzedMs > 0 &&
            switch (bucket) {
              AiBucket.important =>
                record.importance >= AiImportance.important,
              AiBucket.disposable => isDisposable(record),
              AiBucket.lowValue => isLowValue(record),
              AiBucket.suggestions => record.hasSuggestion,
              AiBucket.docType =>
                canonicalDocType(record.docType) == wanted,
              AiBucket.all => true,
            })
          record
    ];
    // Sıra kovaya göre en yararlı olan: silme/gözden geçirme kovalarında en
    // BÜYÜK dosya önce (yer kazancı), diğerlerinde en önemli/yeni önce.
    switch (bucket) {
      case AiBucket.disposable:
      case AiBucket.lowValue:
        out.sort((a, b) => b.sizeBytes.compareTo(a.sizeBytes));
      case AiBucket.suggestions:
        out.sort((a, b) => b.importance.compareTo(a.importance));
      default:
        out.sort((a, b) {
          final byImportance = b.importance.compareTo(a.importance);
          return byImportance != 0
              ? byImportance
              : b.modifiedMs.compareTo(a.modifiedMs);
        });
    }
    return out;
  }

  /// Toplam boyut (kova başlığında "8,3 GB" yazmak için).
  static int totalBytes(Iterable<AiRecord> records) {
    var sum = 0;
    for (final record in records) {
      sum += record.sizeBytes;
    }
    return sum;
  }

  /// Kanonik tür → adet (rapordaki "Türlere göre").
  static List<MapEntry<String, int>> typeCounts([Iterable<AiRecord>? source]) {
    final counts = <String, int>{};
    for (final record in source ?? AiIndex.all()) {
      if (record.analyzedMs == 0 || record.docType.isEmpty) continue;
      final key = canonicalDocType(record.docType);
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final list = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return list;
  }

  /// Kaydı diskteki girdiye çevirir — **diske dokunmadan** (liste kaydırırken
  /// satır başına `statSync` ana izlekte G/Ç demekti).
  static FsEntry entryOf(AiRecord record) => FsEntry(
        path: record.path,
        name: record.name,
        isDir: false,
        sizeBytes: record.sizeBytes,
        modifiedMs: record.modifiedMs,
      );
}

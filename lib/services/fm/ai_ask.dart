/// **Dizinde yerel arama** — "geçen ay indirdiğim faturalar" gibi bir
/// ifadeye en uygun AI dizini kayıtlarını CİHAZDA seçer (ağ yok, ücretsiz).
/// Akıllı klasörler kullanır. 2026-11-19 (B15): modele soru soran sohbet
/// yolu AI Sohbet ile birlikte budandı; yalnız yerel eleme kaldı.
///
/// Türkçe-duyarlı katlama (`turkishFold`) sayesinde "fatura" ile "FATURA",
/// "sözleşme" ile "sozlesme" eşleşir. Tarih ipucu ("bugün", "geçen ay",
/// "2025") varsa zaman süzgeci uygulanır.
library;

import '../../core/text_search.dart';
import 'ai_index.dart';
import 'ai_scope.dart';

abstract final class AiAsk {
  /// Varsayılan en fazla kayıt.
  static const _maxContext = 30;

  /// Soruya en uygun kayıtları **cihazda** seçer (ağ yok, ücretsiz).
  ///
  /// Puanlama basit ve açıklanabilir tutuldu: ad/başlık eşleşmesi en değerli,
  /// etiket ve tür sonra, özet en son. Gömme (embedding) tabanlı arama daha
  /// isabetli olurdu ama her dosya için ayrı bir API çağrısı ve saklanacak
  /// vektör demek — ücretsizlik hedefiyle çelişir.
  static List<AiRecord> rank(
    String question, {
    required AiScope scope,
    int limit = _maxContext,
  }) {
    final terms = _terms(question);
    final after = _sinceFromQuestion(question);
    final scored = <({AiRecord record, int score})>[];

    for (final record in AiIndex.all()) {
      // Kapsam dışına alınmış klasörlerin eski kayıtları cevaba girmez.
      if (!scope.allowsDir(_dirOf(record.path))) continue;
      if (after != null && record.modifiedMs < after) continue;

      var score = 0;
      final name = asciiFold(record.name);
      final title = asciiFold(record.title);
      final type = asciiFold(record.docType);
      final tags = asciiFold(record.tags.join(' '));
      final summary = asciiFold(record.summary);

      for (final term in terms) {
        final stem = _stem(term);
        if (name.contains(stem)) score += 6;
        if (title.contains(stem)) score += 5;
        if (type.contains(stem)) score += 4;
        if (tags.contains(stem)) score += 3;
        if (summary.contains(stem)) score += 2;
      }
      // Terimsiz soru ("neler var", "özetle") → tarih/önem sıralaması kalsın.
      if (terms.isEmpty) score = 1;
      if (score == 0) continue;
      // Önemli evrak eşit puanda öne gelsin.
      score += record.importance ~/ 25;
      scored.add((record: record, score: score));
    }

    scored.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.record.modifiedMs.compareTo(a.record.modifiedMs);
    });
    return [for (final s in scored.take(limit)) s.record];
  }

  /// Türkçe ekleri kabaca kırpar: **eşleşme sözcüğün ilk beş harfiyle** yapılır.
  ///
  /// Neden gerekli: kullanıcı "faturalarım nerede" diye sorar, dosyanın adı
  /// "elektrik-faturasi.pdf"dir. Tam sözcük eşleşmesi arayan bir süzgeç hiçbir
  /// şey bulamaz — Türkçe eklemeli bir dil ve soru cümlesinde sözcükler
  /// neredeyse hep çekimlidir. Beş harf, "fatur" ile "faturalarım"ı
  /// buluşturacak kadar kısa, "fotoğraf" ile "form"u karıştırmayacak kadar
  /// uzun. Yanlış pozitif zaten zararsız: bu yalnız ADAY seçimi, son kararı
  /// model veriyor.
  static String _stem(String term) =>
      term.length > 5 ? term.substring(0, 5) : term;

  /// Sorudaki anlamlı sözcükler (katlanmış, kısa/dolgu sözcükler atılmış).
  static List<String> _terms(String question) {
    const stop = {
      've', 'ile', 'icin', 'bir', 'bu', 'su', 'o', 'ne', 'nerede', 'nerde',
      'hangi', 'var', 'mi', 'mu', 'mı', 'nedir', 'kac', 'kadar', 'benim',
      'bana', 'dosya', 'dosyalar', 'dosyam', 'dosyalarim',
    };
    return [
      for (final word in asciiFold(question).split(RegExp(r'[^a-z0-9]+')))
        if (word.length > 2 && !stop.contains(word)) word
    ];
  }

  /// "bugün / dün / bu hafta / geçen ay / 2025" gibi zaman ipuçları.
  ///
  /// Kaba ama işe yarar: kullanıcı "geçen ay indirdiklerim" derken 30 günü
  /// kasteder; takvim ayı hassasiyeti aramada fark yaratmaz.
  static int? _sinceFromQuestion(String question) {
    final q = asciiFold(question);
    final now = DateTime.now();
    int daysAgo(int d) =>
        now.subtract(Duration(days: d)).millisecondsSinceEpoch;
    if (q.contains('bugun')) return daysAgo(1);
    if (q.contains('dun')) return daysAgo(2);
    if (q.contains('bu hafta') || q.contains('son hafta')) return daysAgo(7);
    if (q.contains('gecen hafta')) return daysAgo(14);
    if (q.contains('bu ay')) return daysAgo(30);
    if (q.contains('gecen ay')) return daysAgo(60);
    if (q.contains('bu yil') || q.contains('son yil')) return daysAgo(365);
    final year = RegExp(r'\b(20\d{2})\b').firstMatch(q);
    if (year != null) {
      return DateTime(int.parse(year.group(1)!)).millisecondsSinceEpoch;
    }
    return null;
  }

  static String _dirOf(String path) {
    final i = path.lastIndexOf('/');
    return i <= 0 ? path : path.substring(0, i);
  }
}

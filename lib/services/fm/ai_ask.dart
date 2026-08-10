/// **Dosyalarına soru sor** — "geçen ay indirdiğim faturalar nerede",
/// "kira sözleşmemde depozito ne kadardı" gibi soruların cevabı.
///
/// ## Neden tüm dosyalar buluta gitmiyor
/// Naif çözüm her soruda tüm indeksi modele yollamak olurdu: 5.000 dosyalık
/// bir telefonda soru başına yüz binlerce token — ücretsiz kotayı tek soruda
/// bitirir. Bunun yerine iki aşama:
///
/// 1. **Yerel eleme (ücretsiz):** soru sözcükleri indekste aranır (ad, başlık,
///    etiket, tür, özet). Türkçe-duyarlı katlama (`turkishFold`) sayesinde
///    "fatura" ile "FATURA", "sözleşme" ile "sozlesme" eşleşir. Tarih ipucu
///    ("bugün", "geçen ay", "2025") varsa zaman süzgeci uygulanır.
/// 2. **Modele yalnız en iyi [_maxContext] kayıt** gider — o da tek satırlık
///    özetleriyle. Soru başına maliyet **sabit** kalır: telefonda 500 dosya da
///    olsa 50.000 dosya da.
///
/// Cevapla birlikte **hangi dosyalara dayandığı** döner: kullanıcı dosyayı
/// listeden açıp kendi gözüyle doğrulayabilsin. Kaynak göstermeyen bir "AI
/// cevabı" dosya yöneticisinde işe yaramaz — yanlışsa fark edilmez.
library;

import 'dart:convert';

import '../../core/text_search.dart';
import '../gemini_service.dart';
import 'ai_index.dart';
import 'ai_scope.dart';

/// Sorunun cevabı + dayandığı dosyalar.
class AiAnswer {
  final String text;
  final List<AiRecord> sources;

  /// Yerel elemede hiç aday çıkmadıysa (indeks boş ya da alakasız soru).
  final bool empty;

  const AiAnswer({this.text = '', this.sources = const [], this.empty = false});
}

abstract final class AiAsk {
  /// Modele gönderilen en fazla kayıt.
  static const _maxContext = 30;

  /// Soruyu yanıtlar. [scope] son bir kez uygulanır: kullanıcı bir klasörü
  /// analizden SONRA dışlamışsa, eski kayıtlar cevaba karışmamalı.
  static Future<AiAnswer> ask({
    required String question,
    required String apiKey,
    required String model,
    required AiScope scope,
    List<ChatTurn> history = const [],
  }) async {
    await AiIndex.ensureLoaded();
    final candidates = rank(question, scope: scope);
    if (candidates.isEmpty) {
      return const AiAnswer(empty: true);
    }

    final context = StringBuffer();
    for (var i = 0; i < candidates.length; i++) {
      final r = candidates[i];
      context.writeln('[$i] ${r.name}'
          '${r.docType.isEmpty ? '' : ' · tür: ${r.docType}'}'
          '${r.title.isEmpty ? '' : ' · ${r.title}'}'
          ' · ${_date(r.modifiedMs)}'
          '${r.summary.isEmpty ? '' : '\n     özet: ${r.summary}'}');
    }

    final gemini = GeminiService(apiKey: apiKey, model: model);
    final raw = await gemini.generateJson(
      systemInstruction:
          'Kullanıcının telefonundaki dosyaların listesi aşağıdadır. Yalnız bu '
          'listeye dayanarak TÜRKÇE, kısa ve net cevap ver. Listede olmayan bir '
          'şeyi UYDURMA — bilgi yoksa "bu bilgi analiz edilen dosyalarda yok" '
          'de. Cevabında kullandığın dosyaların köşeli parantezli numaralarını '
          '"kaynaklar" alanına yaz.\n\nDosyalar:\n$context',
      prompt: question,
      schema: const {
        'type': 'object',
        'properties': {
          'cevap': {'type': 'string'},
          'kaynaklar': {
            'type': 'array',
            'items': {'type': 'integer'}
          },
        },
        'required': ['cevap'],
      },
    );

    return _parseAnswer(raw, candidates);
  }

  static AiAnswer _parseAnswer(String raw, List<AiRecord> candidates) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final text = (decoded['cevap'] as String? ?? '').trim();
        final sources = <AiRecord>[];
        for (final idx in (decoded['kaynaklar'] as List? ?? const [])) {
          final i = (idx as num?)?.toInt();
          if (i != null && i >= 0 && i < candidates.length) {
            sources.add(candidates[i]);
          }
        }
        return AiAnswer(text: text, sources: sources);
      }
    } catch (_) {}
    // Şema dışı yanıt: ham metni göstermek boş ekran göstermekten iyi.
    return AiAnswer(text: raw.trim());
  }

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
      final name = turkishFold(record.name);
      final title = turkishFold(record.title);
      final type = turkishFold(record.docType);
      final tags = turkishFold(record.tags.join(' '));
      final summary = turkishFold(record.summary);

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
      for (final word in turkishFold(question).split(RegExp(r'[^a-z0-9]+')))
        if (word.length > 2 && !stop.contains(word)) word
    ];
  }

  /// "bugün / dün / bu hafta / geçen ay / 2025" gibi zaman ipuçları.
  ///
  /// Kaba ama işe yarar: kullanıcı "geçen ay indirdiklerim" derken 30 günü
  /// kasteder; takvim ayı hassasiyeti aramada fark yaratmaz.
  static int? _sinceFromQuestion(String question) {
    final q = turkishFold(question);
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

  static String _date(int ms) {
    if (ms <= 0) return 'tarihsiz';
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${d.year}-${two(d.month)}-${two(d.day)}';
  }
}

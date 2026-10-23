import 'dart:convert';

import '../../core/text_search.dart';
import '../../models/fs_entry.dart';
import '../gemini_service.dart';
import 'ai_index.dart';
import 'ai_scope.dart';
import 'search_index.dart';

/// AI'nın sorgudan çıkardığı arama planı.
class MeaningPlan {
  /// Aranacak sözcükler (eş anlamlılar, ilgili kavramlar, iki dilde) — ilk
  /// sıradakiler daha ağırlıklı.
  final List<String> terms;

  /// Muhtemel uzantılar ("pdf", "xlsx"…) — eşleşen dosyaya küçük bir artı.
  final List<String> extensions;

  const MeaningPlan({required this.terms, this.extensions = const []});
}

/// Anlamla aramanın tek sonucu.
class MeaningHit {
  final FsEntry entry;
  final double score;

  /// Hangi sözcük(ler) eşleşti — satırda "fatura · makbuz" diye yazılır.
  final List<String> matched;

  const MeaningHit(this.entry, this.score, this.matched);
}

/// **Anlamla ara** (2026-10-23, kullanıcı: *"tüm dosyalarda ara seçeneğine
/// 'anlam ile ara' AI düğmesi gelmeli, notlar uygulamasındaki gibi"*).
///
/// Ad araması harf eşler: "elektrik faturası" yazan kullanıcı
/// `CK_Bogazici_Ekim.pdf` dosyasını bulamaz. Anlamla arama:
/// 1. **Yalnız SORGU** Gemini'ye gider (dosya adı/içerik gitmez): model onu
///    eş anlamlılar, ilgili kavramlar, kurum adları ve İngilizce
///    karşılıklarıyla genişletir ([MeaningPlan]).
/// 2. Genişletilmiş sözcükler **cihazda** aranır: arama dizininde (dosya
///    adları) ve AI dizininde (toplu analizden geçen dosyaların başlık/özet/
///    etiket/türü — bkz. [AiIndex]).
/// 3. Puan: erken sözcük daha değerli, AI dizinindeki özet/etiket eşleşmesi
///    ad eşleşmesinden değerli (anlam taşıyor), birden çok sözcük eşleşen
///    dosya öne çıkar.
///
/// Gömme (embedding) vektörü yok: her dosya için ayrı istek ve saklanacak
/// vektör demek — ücretsizlik hedefiyle çelişir. Soru başına TEK istek.
abstract final class AiMeaningSearch {
  static const maxTerms = 14;

  static const schema = {
    'type': 'object',
    'properties': {
      'terms': {
        'type': 'array',
        'items': {'type': 'string'}
      },
      'extensions': {
        'type': 'array',
        'items': {'type': 'string'}
      },
    },
    'required': ['terms'],
  };

  static String promptFor(String query) =>
      'Kullanıcı telefonundaki dosyalar arasında şunu arıyor: "$query".\n'
      'Dosya ADLARINDA ve dosya özetlerinde geçebilecek arama sözcüklerini '
      'üret: önce sorgunun kendi anahtar sözcükleri, sonra eş anlamlılar, '
      'ilgili kavramlar, ilgili kurum/marka adları, kısaltmalar ve İngilizce '
      'karşılıklar. Her biri 1-2 sözcük, en çok $maxTerms tane, en ilgili '
      'önce. "dosya", "belge" gibi genel sözcükleri yazma. Uygunsa muhtemel '
      'dosya uzantılarını da ver (noktasız, ör. pdf, xlsx, jpg).';

  /// Yanıtı plana çevirir; bozuksa sorgunun kendi sözcüklerine düşer.
  static MeaningPlan parse(String raw, String query) {
    final fallback = [
      for (final w in query.split(RegExp(r'\s+')))
        if (w.trim().length >= 2) w.trim(),
    ];
    try {
      final m = jsonDecode(raw);
      if (m is Map) {
        final seen = <String>{};
        final terms = <String>[];
        for (final t in [...fallback, ...(m['terms'] as List? ?? const [])]) {
          final clean = '$t'.trim();
          if (clean.length < 2) continue;
          if (seen.add(turkishFold(clean))) terms.add(clean);
          if (terms.length >= maxTerms) break;
        }
        final exts = [
          for (final e in (m['extensions'] as List? ?? const []))
            if ('$e'.trim().isNotEmpty)
              '$e'.trim().toLowerCase().replaceFirst('.', ''),
        ];
        return MeaningPlan(terms: terms, extensions: exts.take(6).toList());
      }
    } catch (_) {
      // Bilinçli: şema dışı yanıt — aşağıdaki yedek yol kullanılır.
    }
    return MeaningPlan(terms: fallback);
  }

  /// Planı cihazda uygular (ağ yok). [root] verilirse yalnız o ağacın altı.
  static Future<List<MeaningHit>> rank(
    MeaningPlan plan, {
    String? root,
    AiScope? scope,
    int limit = 300,
  }) async {
    final scores = <String, double>{};
    final matched = <String, List<String>>{};
    final entries = <String, FsEntry>{};
    void hit(FsEntry e, String term, double w) {
      scores[e.path] = (scores[e.path] ?? 0) + w;
      final m = matched[e.path] ??= [];
      if (!m.contains(term) && m.length < 3) m.add(term);
      entries[e.path] = e;
    }

    final n = plan.terms.length;
    for (var i = 0; i < n; i++) {
      final term = plan.terms[i];
      // Erken sözcük daha ağırlıklı: 1.0 → ~0.4.
      final w = 1.0 - 0.6 * (i / (n == 1 ? 1 : n - 1));
      final byName = await SearchIndex.query(term, root: root, limit: 400);
      for (final e in byName) {
        if (!e.isDir) hit(e, term, w);
      }
    }

    // AI dizini: anlamı taşıyan alanlar (başlık/özet/etiket/tür).
    await AiIndex.ensureLoaded();
    final folded = [for (final t in plan.terms) turkishFold(t)];
    final prefix = root == null
        ? null
        : (root.endsWith('/') ? root : '$root/');
    for (final r in AiIndex.all()) {
      if (prefix != null && !r.path.startsWith(prefix)) continue;
      final hay = turkishFold(
          '${r.title} ${r.summary} ${r.tags.join(' ')} ${r.docType}');
      for (var i = 0; i < folded.length; i++) {
        if (folded[i].isEmpty || !hay.contains(folded[i])) continue;
        final w = 1.4 - 0.6 * (i / (n <= 1 ? 1 : n - 1));
        final e = entries[r.path] ??
            FsEntry(
              path: r.path,
              name: r.name,
              isDir: false,
              sizeBytes: r.sizeBytes,
              modifiedMs: r.modifiedMs,
            );
        hit(e, plan.terms[i], w);
      }
    }

    final exts = plan.extensions.toSet();
    final out = <MeaningHit>[];
    for (final path in scores.keys) {
      final e = entries[path]!;
      if (scope != null && !scope.allowsFile(e)) continue;
      var s = scores[path]!;
      // Birden çok sözcük eşleşen dosya öne (yalnız bir genel sözcük
      // eşleşmesi gürültüdür).
      s *= 1 + 0.25 * ((matched[path]?.length ?? 1) - 1);
      if (exts.contains(e.extension)) s += 0.3;
      out.add(MeaningHit(e, s, matched[path] ?? const []));
    }
    out.sort((a, b) {
      final c = b.score.compareTo(a.score);
      return c != 0 ? c : b.entry.modifiedMs.compareTo(a.entry.modifiedMs);
    });
    return out.take(limit).toList();
  }

  /// Uçtan uca: sorgu → plan (tek istek) → yerel sıralama.
  static Future<(MeaningPlan, List<MeaningHit>)> search(
    String query, {
    required GeminiService gemini,
    String? root,
    AiScope? scope,
  }) async {
    final raw =
        await gemini.generateJson(prompt: promptFor(query), schema: schema);
    final plan = parse(raw, query);
    return (plan, await rank(plan, root: root, scope: scope));
  }
}

/// **Faz 37 madde 6 + 10 — satır içi AI (Gemini) yardımcıları.**
///
/// Saf işlevler: istem kurma ve yanıt ayrıştırma (ağ çağrısı ekranda,
/// iptal edilebilir). AI çıktısı belgeye ASLA kendiliğinden yazılmaz:
/// kullanıcı önizlemeyi görüp "Değiştir / Altına ekle" ya da öneri başına
/// "Uygula" der (madde 10 — kullanıcı onaylı).
library;

import 'dart:convert';

/// Satır içi AI görevleri.
const kWordAiTasks = ['rewrite', 'summarize', 'translate', 'continue', 'bullets', 'formal'];

/// Yazım/dilbilgisi önerisi: [wrong] paragrafta geçen parça, [right] önerilen.
class ProofSuggestion {
  final String wrong, right, reason;
  const ProofSuggestion(this.wrong, this.right, this.reason);
}

abstract final class DocxAi {
  /// Görev istemi. [instruction] arayüz dilinde görev cümlesi (çeviri
  /// tablosundan), [target] çeviri dili adı.
  static String prompt(String instruction, String text) =>
      '$instruction\n\n'
      'Yalnız sonucu yaz; açıklama, tırnak, başlık ya da Markdown ekleme.\n\n'
      '---\n$text\n---';

  /// Yazım denetimi istemi: JSON dizi ister.
  static String proofPrompt(String text, String language) =>
      'Aşağıdaki metindeki yazım, noktalama ve dilbilgisi hatalarını bul '
      '(metnin dili: $language). Anlamı değiştirme, üslubu yeniden yazma. '
      'Yalnız JSON dizi döndür: '
      '[{"wrong":"metinde AYNEN geçen hatalı parça","right":"düzeltilmiş hali","reason":"kısa gerekçe"}]. '
      'Hata yoksa [] döndür.\n\n---\n$text\n---';

  /// Modelin yanıtından öneriler: kod çiti, baştaki/sondaki metin tolere
  /// edilir; metinde geçmeyen ya da değişmeyen öneri atılır.
  static List<ProofSuggestion> parseProof(String answer, String text) {
    var s = answer.trim();
    final fence = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    final a = s.indexOf('['), b = s.lastIndexOf(']');
    if (a < 0 || b <= a) return const [];
    Object? data;
    try {
      data = jsonDecode(s.substring(a, b + 1));
    } on FormatException {
      return const [];
    }
    if (data is! List) return const [];
    final out = <ProofSuggestion>[];
    final seen = <String>{};
    for (final e in data) {
      if (e is! Map) continue;
      final wrong = '${e['wrong'] ?? ''}';
      final right = '${e['right'] ?? ''}';
      if (wrong.isEmpty || wrong == right || !text.contains(wrong)) continue;
      if (!seen.add('$wrong→$right')) continue;
      out.add(ProofSuggestion(wrong, right, '${e['reason'] ?? ''}'));
    }
    return out;
  }

  /// AI yanıtındaki gereksiz sarmalayıcıları temizler (```, tırnak).
  static String clean(String answer) {
    var s = answer.trim();
    final fence = RegExp(r'^```[a-z]*\s*([\s\S]*?)```$').firstMatch(s);
    if (fence != null) s = fence.group(1)!.trim();
    if (s.length > 1 &&
        ((s.startsWith('"') && s.endsWith('"')) ||
            (s.startsWith('“') && s.endsWith('”')))) {
      s = s.substring(1, s.length - 1).trim();
    }
    return s;
  }
}

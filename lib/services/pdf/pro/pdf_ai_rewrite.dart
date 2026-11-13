/// **AI ile yerinde yeniden yazım** (PDF Pro Faz 65): seçili paragraf yeniden
/// yazılır / kısaltılır / resmileştirilir / dilbilgisi düzeltilir / çevrilir.
/// Sonuç ÖNERİDİR — kullanıcı kabul ederse tek geri alınabilir adım olur.
///
/// Gönderim `AiPool` üzerinden: onay (`AiPool.consent`), çevrimdışı kip ve
/// anahtar kapısı orada denetlenir; buradan onaysız hiçbir şey gitmez.
library;

import '../../gemini_service.dart';

enum PdfAiMode { rewrite, shorten, formal, grammar, translate }

abstract final class PdfAiRewrite {
  /// Modele gidecek istem. Saf → testli.
  static String buildPrompt(String text, PdfAiMode mode, {String? language}) {
    final task = switch (mode) {
      PdfAiMode.rewrite =>
        'Metni aynı dilde, anlamını değiştirmeden daha akıcı ve açık biçimde yeniden yaz.',
      PdfAiMode.shorten =>
        'Metni aynı dilde, anlamını koruyarak belirgin biçimde kısalt.',
      PdfAiMode.formal =>
        'Metni aynı dilde, resmî ve kurumsal bir üslupla yeniden yaz.',
      PdfAiMode.grammar =>
        'Metindeki yazım, noktalama ve dilbilgisi hatalarını düzelt; başka '
            'hiçbir şeyi değiştirme.',
      PdfAiMode.translate =>
        'Metni şu dile çevir: ${language ?? 'English'}. Yalnız çeviriyi ver.',
    };
    return '''
$task

Kurallar:
- Yalnız sonuç metnini döndür: açıklama, başlık, tırnak ya da biçim işareti YOK.
- Tek paragraf; satır sonu ekleme.
- Sayıları, tarihleri ve özel adları değiştirme.

Metin:
$text''';
  }

  /// Yanıtı temizler: çevreleyen tırnak/kod çiti, satır sonları. Boşsa null.
  static String? clean(String answer) {
    var t = answer.trim();
    if (t.startsWith('```')) {
      t = t.replaceAll(RegExp(r'^```[a-zA-Z]*\s*|\s*```$'), '').trim();
    }
    for (final pair in const [('"', '"'), ('“', '”'), ('«', '»')]) {
      if (t.length > 1 && t.startsWith(pair.$1) && t.endsWith(pair.$2)) {
        t = t.substring(1, t.length - 1).trim();
      }
    }
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    return t.isEmpty ? null : t;
  }

  static Future<String?> run(GeminiService gemini, String text, PdfAiMode mode,
      {String? language}) async {
    final answer = await gemini.chat(history: [
      ChatTurn(
          fromUser: true,
          text: buildPrompt(text, mode, language: language)),
    ]);
    return clean(answer);
  }
}

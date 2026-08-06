import 'gemini_service.dart';

/// **"AI ile oku"** — sesli okumadan önce metni AI'a toparlatma (2026-08-06
/// kullanıcı isteği: *"ayrıca AI ile oku seçeneği de olsun"*).
///
/// Taranmış bir kitap sayfasının OCR metni sesli okumaya olduğu gibi uygun
/// değil: satır sonu tireleri heceyi ikiye böler, sayfa numarası cümlenin
/// ortasına düşer, tanıma hataları anlamsız kelimeler üretir. [cleanForSpeech]
/// bunların kural yazılabilenlerini hâlleder; burası kalanını bağlama bakarak
/// düzeltir.
///
/// **Güvenlik kilidi — özetlemeye izin yok.** İstem açıkça yasaklıyor ama
/// modeller bazen yine kısaltır; dönen metin özgününün %60'ından kısaysa
/// sonuç ATILIR ve özgün metin okunur ([tidyOrOriginal]). Kullanıcı "oku"
/// dedi, "özetle" demedi — sessizce yarısını okumak kabul edilemez.
abstract final class ReadAloudAi {
  /// Kısalma eşiği: bunun altına düşen yanıt özet sayılır ve reddedilir.
  static const minLengthRatio = 0.6;

  /// [text]'i sesli okumaya uygun hâle getirir; iş görmezse özgün metin döner.
  static Future<String> tidyOrOriginal(
    GeminiService gemini,
    String text,
  ) async {
    final source = text.trim();
    if (source.length < 40) return source; // kısa metinde kazanç yok
    try {
      final answer = await gemini.chat(
        history: [ChatTurn(fromUser: true, text: buildPrompt(source))],
      );
      return accept(answer, source);
    } catch (_) {
      // AI'ya ulaşılamadı (anahtar, ağ, kota): okuma DURMAZ, özgün metin okunur.
      return source;
    }
  }

  /// Modele gidecek istem. Saf → testli.
  static String buildPrompt(String text) => '''
Aşağıdaki metin bir kitabın/belgenin taranmış sayfasından metin tanıma (OCR)
ile çıkarılmıştır ve şimdi SESLİ OKUNACAK. Metni sesli okumaya uygun hâle
getir:

- Tanıma hatalarını düzelt (eksik Türkçe harfler: İ, ı, ğ, ş, ç, ö, ü).
- Satır sonundaki tirelerle bölünmüş kelimeleri birleştir.
- Sayfa numarası, üstbilgi/altbilgi ve dipnot numaralarını çıkar.
- Noktalamayı düzelt ki cümleler doğru tonlansın.

YASAK: özetleme, kısaltma, çeviri, yorum, başlık ekleme, üslup değiştirme.
Cümleleri olduğu gibi bırak; yalnız yukarıdaki düzeltmeleri yap.
Yanıt olarak SADECE düzeltilmiş metni yaz.

"""
$text
"""''';

  /// Yanıtı kabul eder ya da özgün metne döner. Saf → testli.
  static String accept(String answer, String original) {
    var out = answer.trim();
    // Model üç tırnak/kod bloğu içinde döndürürse soy.
    out = out.replaceAll(RegExp(r'^```[a-zA-Z]*\s*'), '');
    out = out.replaceAll(RegExp(r'```$'), '');
    out = out.replaceAll(RegExp(r'^"""\s*'), '');
    out = out.replaceAll(RegExp(r'\s*"""$'), '');
    out = out.trim();
    if (out.isEmpty) return original;
    if (out.length < original.length * minLengthRatio) return original;
    return out;
  }
}

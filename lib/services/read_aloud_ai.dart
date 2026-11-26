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

  /// Tek istekte gönderilen en uzun parça (karakter).
  ///
  /// KÖK (2026-11-25 fatura denetimi): Sesli Kitap bir BÖLÜMÜN tamamını (on
  /// binlerce karakter) tek istekte gönderiyordu. Yanıt modelin çıktı
  /// sınırına takılınca kesik geliyor, %60 kilidi onu reddediyor → hem girdi
  /// hem çıktı belirteci ÖDENİYOR, sonuç çöpe gidiyordu. Paragraf sınırında
  /// ≤ 8000 karakterlik parçalar hem sınırın çok altında kalır hem de
  /// reddedilen bir parça yalnız kendi ücretini boşa harcar.
  static const maxChunkChars = 8000;

  /// [text]'i sesli okumaya uygun hâle getirir; iş görmezse özgün metin döner.
  ///
  /// Uzun metin parçalara bölünür; bir parçada AI'ya ulaşılamazsa (anahtar,
  /// ağ, kota) KALAN parçalar için istek atılmaz (boşuna istek/ücret yok).
  static Future<String> tidyOrOriginal(
    GeminiService gemini,
    String text,
  ) async {
    final source = text.trim();
    if (source.length < 40) return source; // kısa metinde kazanç yok
    final parts = splitForTidy(source);
    final out = <String>[];
    var aiDown = false;
    for (final part in parts) {
      if (aiDown || part.trim().length < 40) {
        out.add(part);
        continue;
      }
      try {
        final answer = await gemini.chat(
          history: [ChatTurn(fromUser: true, text: buildPrompt(part))],
        );
        out.add(accept(answer, part));
      } catch (_) {
        // AI'ya ulaşılamadı: okuma DURMAZ, özgün metin okunur.
        aiDown = true;
        out.add(part);
      }
    }
    return out.join('\n\n');
  }

  /// Metni paragraf (boş satır), yoksa satır, o da yoksa sözcük sınırında
  /// ≤ [maxChunkChars] parçalara böler. Saf → testli.
  static List<String> splitForTidy(String text, {int max = maxChunkChars}) {
    if (text.length <= max) return [text];
    final out = <String>[];
    var buf = StringBuffer();
    void flush() {
      final t = buf.toString().trim();
      if (t.isNotEmpty) out.add(t);
      buf = StringBuffer();
    }

    for (final para in text.split(RegExp(r'\n\s*\n'))) {
      final p = para.trim();
      if (p.isEmpty) continue;
      if (buf.length + p.length + 2 > max) flush();
      if (p.length <= max) {
        if (buf.isNotEmpty) buf.write('\n\n');
        buf.write(p);
        continue;
      }
      // Tek paragraf sınırı aşıyor: sözcük sınırında böl.
      var rest = p;
      while (rest.length > max) {
        var cut = rest.lastIndexOf(RegExp(r'\s'), max);
        if (cut <= max ~/ 2) cut = max;
        out.add(rest.substring(0, cut).trim());
        rest = rest.substring(cut).trim();
      }
      buf.write(rest);
    }
    flush();
    return out;
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

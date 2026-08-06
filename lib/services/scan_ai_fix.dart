import 'gemini_service.dart';

/// **Taranmış sayfayı AI ile mükemmelleştirme** (2026-08-06 kullanıcı isteği:
/// *"editöre düzenle ve AI ile düzenle butonu koyalım, taranan sayfaları
/// ikisi de mükemmelleştirmeye çalışsın"*).
///
/// [ScanTextFix] kural tabanlıdır ve yalnız kesin bildiği hatayı düzeltir;
/// burası ikinci ve daha cesur yol: satırlar Gemini'ye verilir, model OCR
/// hatalarını (eksik Türkçe işaretler, karışan harfler, bölünmüş heceler)
/// bağlama bakarak onarır.
///
/// ## Sözleşme — satır SAYISI değişemez
/// Düzeltilen metin PDF'te OCR satır kutularının yerine yazılıyor; kutular
/// sabit. Model bir satırı ikiye bölerse ya da yeni cümle eklerse metin
/// yanlış kutuya düşer ve sayfa bozulur. Bu yüzden:
/// * istem satırları NUMARALI verir ve aynı numaralarla geri ister,
/// * yanıt satır satır ayrıştırılır ve **tüm numaralar birebir** gelmezse
///   sonuç TÜMÜYLE reddedilir ([ScanAiFixRefused]).
///
/// Yarım uygulanan bir düzeltme, hiç düzeltmemekten kötüdür.
abstract final class ScanAiFix {
  /// Tek istekte gönderilecek en fazla satır. Uzun sayfa parçalara bölünür:
  /// tek dev istem hem kesiliyor hem de modelin satır numaralarını kaçırma
  /// olasılığını artırıyor.
  static const chunkSize = 40;

  /// [lines]'ı düzeltilmiş hâliyle döndürür (aynı uzunlukta).
  static Future<List<String>> polish(
    GeminiService gemini,
    List<String> lines,
  ) async {
    if (lines.isEmpty) return const [];
    final out = <String>[];
    for (var start = 0; start < lines.length; start += chunkSize) {
      final end = (start + chunkSize).clamp(0, lines.length);
      final chunk = lines.sublist(start, end);
      final answer = await gemini.chat(
        history: [ChatTurn(fromUser: true, text: buildPrompt(chunk))],
      );
      out.addAll(parseAnswer(answer, chunk));
    }
    return out;
  }

  /// Modele gidecek istem. Saf → testli.
  static String buildPrompt(List<String> lines) {
    final numbered = [
      for (var i = 0; i < lines.length; i++) '${i + 1}| ${lines[i]}',
    ].join('\n');
    return '''
Aşağıdaki satırlar bir kitap/belge sayfasının OCR (metin tanıma) çıktısıdır ve
tanıma hataları içerir. Görevin bu satırları DÜZELTMEK.

Kurallar:
- Her satırı "numara| metin" biçiminde, AYNI numarayla ve AYNI SIRADA döndür.
- Satır ekleme, satır silme, satırları birleştirme veya bölme YOK. Tam
  ${lines.length} satır döndür.
- Yalnız tanıma hatalarını düzelt: eksik Türkçe harfler (İ, ı, ğ, ş, ç, ö, ü),
  birbirine karışan harf/rakamlar (0-O, 1-l, 5-S), bozuk noktalama, yapışık
  veya kopuk kelimeler.
- Metnin anlamını, üslubunu ve kelime seçimini DEĞİŞTİRME. Özetleme, çevirme,
  sadeleştirme, yorum ekleme YOK.
- Emin olamadığın satırı olduğu gibi bırak.
- Başka hiçbir şey yazma: ne açıklama, ne başlık, ne kod bloğu.

$numbered''';
  }

  /// Modelin yanıtını çözer. Saf → testli.
  ///
  /// [original] satır sayısını ve eksik satırların yedeğini verir; bir numara
  /// hiç gelmezse istek reddedilir (sessizce eskisini bırakmak, kullanıcıya
  /// "düzeltildi" deyip yarısını düzeltmemek olurdu).
  static List<String> parseAnswer(String answer, List<String> original) {
    final byIndex = <int, String>{};
    for (final raw in answer.split('\n')) {
      final m = RegExp(r'^\s*(\d{1,3})\s*[|.):\-]\s?(.*)$').firstMatch(raw);
      if (m == null) continue;
      final index = int.parse(m.group(1)!);
      if (index < 1 || index > original.length) continue;
      byIndex.putIfAbsent(index, () => m.group(2)!.trim());
    }
    if (byIndex.length != original.length) {
      throw ScanAiFixRefused(
        'AI yanıtı ${byIndex.length}/${original.length} satır getirdi. '
        'Eksik yanıtı sayfaya uygulamak metni yanlış satırlara taşırdı, '
        'bu yüzden hiçbir değişiklik yapılmadı.',
      );
    }
    return [
      for (var i = 1; i <= original.length; i++)
        byIndex[i]!.isEmpty ? original[i - 1] : byIndex[i]!,
    ];
  }
}

/// AI düzeltmesi uygulanmadı — mesaj doğrudan kullanıcıya gösterilebilir.
class ScanAiFixRefused implements Exception {
  final String message;
  const ScanAiFixRefused(this.message);
  @override
  String toString() => message;
}

import 'dart:convert';

import 'gemini_service.dart';
import 'pptx_writer.dart';

/// AI'nin kurduğu sunum planı: slaytlar + destenin başlığı.
class SlidePlan {
  final String title;
  final List<SlideDraft> slides;
  const SlidePlan(this.title, this.slides);
}

/// Belgeden **gerçekten sunulabilir** bir slayt destesi kurar.
///
/// **Neden AI, neden sezgi yetmiyor:** `TextToSlides` metni satır/boşluk
/// biçimine bakarak böler — kaynak zaten slayt gibi yazılmışsa iyi çalışır.
/// Ama tipik bir PDF (rapor, makale, sözleşme) düzyazıdır: orada "başlık" ve
/// "madde" diye bir şey YOKTUR, sezgi ne yaparsa yapsın çıktı paragrafların
/// slayta kopyalanmış hâli olur — teknik olarak slayt, sunum olarak işe
/// yaramaz. Kaynağı okuyup ÖZETLEYEREK madde çıkarmak anlama dayalı bir iş;
/// bunu ancak model yapabilir.
///
/// Sezgi yolu silinmedi: API anahtarı olmayan ya da harcamak istemeyen
/// kullanıcı için ücretsiz ve çevrimdışı seçenek olarak duruyor.
class AiSlides {
  /// Modele gönderilen üst sınır (`AiSummaryFlow.maxChars` ile aynı gerekçe:
  /// uzun belgenin tamamını yollamak hem pahalı hem gereksiz).
  static const int maxChars = 24000;

  /// Gemini'ye dayatılan çıktı şeması. Alan adları İngilizce: model bunlara
  /// daha güvenilir uyuyor ve adlar kullanıcıya hiç görünmüyor.
  static const Map<String, Object?> schema = {
    'type': 'object',
    'properties': {
      'title': {'type': 'string'},
      'slides': {
        'type': 'array',
        'items': {
          'type': 'object',
          'properties': {
            'title': {'type': 'string'},
            'bullets': {
              'type': 'array',
              'items': {'type': 'string'},
            },
            'notes': {'type': 'string'},
          },
          'required': ['title', 'bullets'],
        },
      },
    },
    'required': ['title', 'slides'],
  };

  static String prompt({required int maxSlides, required String language}) =>
      'Bu belgeden sunulabilir bir slayt destesi hazırla.\n'
      'Kurallar:\n'
      '- En çok $maxSlides slayt. Belge kısaysa daha az slayt yap; '
      'sayıyı doldurmak için içerik UYDURMA.\n'
      '- Her slaytta en çok 5 madde, her madde tek satır (en fazla ~90 karakter).\n'
      '- Maddeler cümle değil, konuşulacak noktalar olsun; belgedeki '
      'paragrafları olduğu gibi kopyalama, ÖZETLE.\n'
      '- Slayt başlıkları kısa ve bilgilendirici olsun ("Giriş" gibi boş '
      'başlıklar yerine konuyu söyleyen başlıklar).\n'
      '- "notes" alanına o slaytta ne anlatılacağına dair 1-2 cümlelik '
      'konuşmacı notu yaz.\n'
      '- Yalnız belgede GEÇEN bilgiyi kullan.\n'
      '- Çıktının dili: $language.';

  /// Belgeden plan üretir. Ağ/anahtar hatalarında [GeminiException] fırlatır;
  /// modelin bozuk yanıtı ise [FormatException] olur — çağıran ikisini de
  /// kullanıcıya gösterebilir.
  static Future<SlidePlan> generate({
    required GeminiService gemini,
    required String text,
    required String language,
    int maxSlides = 12,
  }) async {
    final source = text.trim();
    if (source.isEmpty) throw const FormatException('boş belge');

    final raw = await gemini.generateJson(
      prompt: prompt(maxSlides: maxSlides, language: language),
      schema: schema,
      fileContext:
          source.length > maxChars ? source.substring(0, maxChars) : source,
      systemInstruction:
          'Sen bir sunum hazırlama yardımcısısın. Kaynağa sadık kal, '
          'bilgi uydurma.',
    );
    return parse(raw);
  }

  /// Ham gövdeyi plana çevirir.
  ///
  /// **Savunmacı, çünkü şema garantisi mutlak değil:** `responseSchema` çıktıyı
  /// büyük ölçüde bağlıyor ama yanıt uzunluk sınırında KESİLEBİLİR ve yarım
  /// JSON gelebilir; bazı modeller gövdeyi ```json çitiyle sarar. Burada
  /// kurtarılabilecek her şey kurtarılıyor: tek bir bozuk slayt yüzünden
  /// kullanıcının bütün işi çöpe gitmesin.
  static SlidePlan parse(String raw) {
    final decoded = jsonDecode(_unfence(raw));
    if (decoded is! Map) throw const FormatException('beklenmeyen JSON kökü');

    final slides = <SlideDraft>[];
    for (final item in (decoded['slides'] as List?) ?? const []) {
      if (item is! Map) continue;
      final title = _string(item['title']);
      final bullets = [
        for (final b in (item['bullets'] as List?) ?? const [])
          if (_string(b).isNotEmpty) _string(b),
      ];
      final notes = _string(item['notes']);
      // Hem başlığı hem maddesi boş olan slayt bir şey anlatmaz.
      if (title.isEmpty && bullets.isEmpty) continue;
      slides.add(SlideDraft(title, bullets, notes: notes));
    }
    if (slides.isEmpty) {
      throw const FormatException('modelden kullanılabilir slayt gelmedi');
    }
    return SlidePlan(_string(decoded['title']), slides);
  }

  /// ```json … ``` çitini ve baştaki/sondaki açıklama metnini atar.
  static String _unfence(String raw) {
    var s = raw.trim();
    if (s.startsWith('```')) {
      final firstBreak = s.indexOf('\n');
      if (firstBreak > 0) s = s.substring(firstBreak + 1);
      final fence = s.lastIndexOf('```');
      if (fence >= 0) s = s.substring(0, fence);
      s = s.trim();
    }
    // Model gövdeden önce/sonra cümle yazdıysa ilk `{` ile son `}` arasını al.
    final start = s.indexOf('{');
    final end = s.lastIndexOf('}');
    if (start > 0 && end > start) s = s.substring(start, end + 1);
    return s;
  }

  static String _string(Object? v) => v == null ? '' : '$v'.trim();
}

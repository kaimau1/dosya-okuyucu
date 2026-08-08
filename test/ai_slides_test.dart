import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/ai_slides.dart';

void main() {
  group('AI slayt planı ayrıştırma', () {
    test('düz JSON okunur', () {
      final plan = AiSlides.parse('''
{"title":"Rapor","slides":[
  {"title":"Giriş","bullets":["bir","iki"],"notes":"Kısaca tanıt."},
  {"title":"Sonuç","bullets":["üç"]}
]}''');
      expect(plan.title, 'Rapor');
      expect(plan.slides.length, 2);
      expect(plan.slides[0].bullets, ['bir', 'iki']);
      expect(plan.slides[0].notes, 'Kısaca tanıt.');
      expect(plan.slides[1].notes, '');
    });

    test('```json ÇİTİ sarılmış gövde okunur', () {
      // Bazı modeller `responseMimeType` verilse de gövdeyi çitle sarar.
      final plan = AiSlides.parse(
          '```json\n{"title":"T","slides":[{"title":"A","bullets":["x"]}]}\n```');
      expect(plan.slides.single.title, 'A');
    });

    test('gövdeden ÖNCE/SONRA açıklama cümlesi varsa da okunur', () {
      final plan = AiSlides.parse(
          'İşte sunum:\n{"title":"T","slides":[{"title":"A","bullets":["x"]}]}\nUmarım işine yarar.');
      expect(plan.slides.single.title, 'A');
    });

    test('BOZUK slayt atlanır, sağlamlar kurtarılır', () {
      // Tek bir bozuk öğe yüzünden kullanıcının bütün işi çöpe gitmemeli.
      final plan = AiSlides.parse('''
{"title":"T","slides":[
  {"title":"Sağlam","bullets":["x"]},
  "bu bir nesne değil",
  {"title":"","bullets":[]},
  {"title":"İkinci sağlam","bullets":["y",""," "]}
]}''');
      expect(plan.slides.length, 2);
      expect(plan.slides[0].title, 'Sağlam');
      // Boş maddeler süzülür.
      expect(plan.slides[1].bullets, ['y']);
    });

    test('maddesi olmayan ama BAŞLIĞI olan slayt korunur', () {
      // Bölüm ayracı slaytı geçerlidir.
      final plan = AiSlides.parse(
          '{"title":"T","slides":[{"title":"Bölüm 2","bullets":[]}]}');
      expect(plan.slides.single.title, 'Bölüm 2');
    });

    test('hiç kullanılabilir slayt yoksa HATA verir (sessizce boş dönmez)', () {
      expect(() => AiSlides.parse('{"title":"T","slides":[]}'),
          throwsA(isA<FormatException>()));
      expect(() => AiSlides.parse('{"title":"T","slides":[{"bullets":[]}]}'),
          throwsA(isA<FormatException>()));
    });

    test('JSON kökü nesne değilse HATA verir', () {
      expect(() => AiSlides.parse('[1,2,3]'), throwsA(isA<FormatException>()));
    });

    test('istem sınırları içeriyor', () {
      final p = AiSlides.prompt(maxSlides: 8, language: 'Türkçe');
      expect(p, contains('8'));
      expect(p, contains('Türkçe'));
      // Uydurmaya karşı açık talimat, istemin taşıması gereken asıl kural.
      expect(p.toLowerCase(), contains('uydurma'));
    });

    test('şema zorunlu alanları bildiriyor', () {
      final slides = (AiSlides.schema['properties']
          as Map<String, Object?>)['slides'] as Map<String, Object?>;
      final item = slides['items'] as Map<String, Object?>;
      expect(item['required'], contains('title'));
      expect(item['required'], contains('bullets'));
    });
  });
}

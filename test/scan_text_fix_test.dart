import 'package:dosya_okuyucu/services/scan_text_fix.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Cihaz-içi OCR metin düzeltme** (2026-08-06: "düzenle ve AI ile düzenle
/// butonu koyalım, taranan sayfaları ikisi de mükemmelleştirmeye çalışsın").
///
/// Ölçüt: düzelttiği şeyi kesin düzeltmeli, emin olmadığına DOKUNMAMALI.
void main() {
  group('kelime başındaki I', () {
    test('ince ünlülü kelimede İ olur', () {
      expect(ScanTextFix.line('Iki metre boyunda'), 'İki metre boyunda');
      expect(ScanTextFix.line('Ismini bilmiyorum'), 'İsmini bilmiyorum');
    });

    test('kalın ünlülü kelimeye dokunulmaz', () {
      expect(ScanTextFix.line('Işık yandı'), 'Işık yandı');
      expect(ScanTextFix.line('Irak sınırı'), 'Irak sınırı');
    });

    test('uyuma uymayan sık özel adlar listeden düzelir', () {
      expect(ScanTextFix.line('Istanbul’a gitti'), 'İstanbul’a gitti');
      expect(ScanTextFix.line('Izmir'), 'İzmir');
    });

    test('tamamı büyük harf yazıda karar verilmez', () {
      expect(ScanTextFix.line('IKI KELIME'), 'IKI KELIME');
    });
  });

  group('harf arasındaki rakam', () {
    test('iki harf arasındaki 0/1/5 harfe çevrilir', () {
      expect(ScanTextFix.line('ÇOCUK ve Ç0CUK'), 'ÇOCUK ve ÇOCUK');
      expect(ScanTextFix.line('ka5a'), 'kasa');
    });

    test('ucundaki rakama ve sayılara dokunulmaz', () {
      expect(ScanTextFix.line('A4 kağıdı 2026 yılı'), 'A4 kağıdı 2026 yılı');
      expect(ScanTextFix.line('35'), '35');
    });
  });

  group('noktalama boşlukları', () {
    test('noktalamadan önceki boşluk atılır, sonrasına konur', () {
      expect(ScanTextFix.line('Merhaba , dünya'), 'Merhaba, dünya');
      expect(ScanTextFix.line('bitti .'), 'bitti.');
      expect(ScanTextFix.line('bir,iki'), 'bir, iki');
    });

    test('ondalık/tarih bozulmaz', () {
      expect(ScanTextFix.line('12.05.2026 saat 3.5'), '12.05.2026 saat 3.5');
    });
  });

  group('satır sonu tiresi', () {
    test('küçük harfle süren hece birleşir, satır sayısı değişmez', () {
      final out = ScanTextFix.lines([
        'Bunu elde etmek için sadece çok büyük miktarda ener-',
        'jiye ihtiyacınız var.',
      ]);
      expect(out.length, 2);
      expect(out[0], endsWith('enerjiye'));
      expect(out[1], 'ihtiyacınız var.');
    });

    test('büyük harfle süren satırdaki tire GERÇEK tiredir', () {
      final out = ScanTextFix.lines(['Türk-', 'İslam sentezi']);
      expect(out[0], 'Türk-');
      expect(out[1], 'İslam sentezi');
    });
  });

  group('sayfa numarası tanıma', () {
    test('yalın numara ve süslü biçimler', () {
      expect(ScanTextFix.looksLikePageNumber('35'), isTrue);
      expect(ScanTextFix.looksLikePageNumber('- 35 -'), isTrue);
      expect(ScanTextFix.looksLikePageNumber('Sayfa 12'), isTrue);
      expect(ScanTextFix.looksLikePageNumber('xiv'), isTrue);
    });

    test('gerçek metin sayfa numarası sayılmaz', () {
      expect(ScanTextFix.looksLikePageNumber('35 kişi geldi'), isFalse);
      expect(ScanTextFix.looksLikePageNumber('Bölüm başlığı'), isFalse);
      expect(ScanTextFix.looksLikePageNumber(''), isFalse);
    });

    test('roma rakamı harflerinden oluşan GERÇEK kelime elenmez', () {
      // "civil" yalnız c/i/v/i/l harflerinden oluşur; harf kümesine bakan
      // naif kural bunu sayfa numarası sanıp sesli okumadan silerdi.
      expect(ScanTextFix.looksLikePageNumber('civil'), isFalse);
      expect(ScanTextFix.looksLikePageNumber('mix'), isFalse);
    });
  });
}

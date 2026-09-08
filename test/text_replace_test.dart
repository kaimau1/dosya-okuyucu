import 'package:dosya_okuyucu/core/line_endings.dart';
import 'package:dosya_okuyucu/core/natural_sort.dart';
import 'package:dosya_okuyucu/core/text_replace.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-06 denetim turu: metin belgelerinin eksik yarısı (değiştirme),
/// listelerin yanlış sırası (doğal sıralama) ve kaydederken bozulan satır
/// sonları.
void main() {
  group('Bul ve Değiştir', () {
    test('büyük/küçük harf duyarsız arama TÜRKÇE doğru', () {
      // Dart'ın kendi katlaması burada yanılır: 'IŞIK'.toLowerCase() → 'ışık'
      // DEĞİL 'ışik' verir. Uygulamanın katlaması Türkçe'ye göre.
      expect(TextReplace.matches('ışık yandı', 'IŞIK'), [0]);
      expect(TextReplace.matches('İstanbul', 'istanbul'), [0]);
    });

    test('harf duyarlı arama seçildiğinde tam eşleşme ister', () {
      expect(TextReplace.matches('Ev ev EV', 'ev', matchCase: true), [3]);
    });

    test('tam sözcük seçeneği parçaları elemez', () {
      const text = 'ev evet evler ev';
      expect(TextReplace.matches(text, 'ev'), [0, 3, 8, 14]);
      expect(TextReplace.matches(text, 'ev', wholeWord: true), [0, 14]);
    });

    test('tam sözcük sınırı TÜRKÇE harfleri de sayar', () {
      // RegExp'in `\b`si için 'ı' sözcük karakteri değildir; kendi sınırımız
      // Unicode harflerine bakıyor, yoksa "evı" bir sözcük sanılırdı.
      expect(TextReplace.matches('evı', 'ev', wholeWord: true), isEmpty);
      expect(TextReplace.matches('şey ev şey', 'ev', wholeWord: true), [4]);
    });

    test('tümünü değiştir sayıyı da döner', () {
      final r = TextReplace.replaceAll('bir iki bir üç bir', 'bir', 'BİR');
      expect(r.count, 3);
      expect(r.text, 'BİR iki BİR üç BİR');
    });

    test('uzunluğu DEĞİŞEN metin indeksleri kaydırmaz', () {
      // Sondan başa değiştirilmezse ikinci eşleşme yanlış yere düşerdi.
      final r = TextReplace.replaceAll('a-a-a', 'a', 'uzunmetin');
      expect(r.text, 'uzunmetin-uzunmetin-uzunmetin');
      expect(r.count, 3);
    });

    test('eşleşme yoksa metin AYNEN döner', () {
      final r = TextReplace.replaceAll('merhaba', 'yok', 'x');
      expect(r.count, 0);
      expect(r.text, 'merhaba');
    });

    test('tek eşleşmeyi değiştirmek ötekilere dokunmaz', () {
      final out = TextReplace.replaceAt('bir bir bir', 4, 3, 'İKİ');
      expect(out, 'bir İKİ bir');
    });

    test('boş arama hiçbir şeyi eşleştirmez (sonsuz döngü tuzağı)', () {
      expect(TextReplace.matches('metin', ''), isEmpty);
      expect(TextReplace.replaceAll('metin', '', 'x').count, 0);
    });
  });

  group('Doğal sıralama', () {
    test('sayı blokları SAYI olarak karşılaştırılır', () {
      final names = ['Bölüm 10', 'Bölüm 9', 'Bölüm 1']..sort(naturalCompare);
      expect(names, ['Bölüm 1', 'Bölüm 9', 'Bölüm 10']);
    });

    test('fotoğraf adları doğru sırada', () {
      final names = ['IMG_10.jpg', 'IMG_2.jpg', 'IMG_1.jpg']
        ..sort(naturalCompare);
      expect(names, ['IMG_1.jpg', 'IMG_2.jpg', 'IMG_10.jpg']);
    });

    test('baştaki sıfırlar sayıyı değiştirmez', () {
      expect(naturalCompare('img007', 'img7'), isNot(0));
      expect(naturalCompare('img007', 'img8'), lessThan(0));
    });

    test('ön ek aynıyken kısa olan önce', () {
      expect(naturalCompare('Ders 2', 'Ders 2 ek'), lessThan(0));
    });

    test('çok uzun sayı ÇÖKMEZ (int taşması)', () {
      final huge = '9' * 30;
      expect(() => naturalCompare('a$huge', 'a${'8' * 30}'), returnsNormally);
    });

    test('sayısız adlar normal sırada', () {
      final names = ['ceviz', 'armut', 'badem']..sort(naturalCompare);
      expect(names, ['armut', 'badem', 'ceviz']);
    });
  });

  group('Satır sonları', () {
    test('CRLF baskınsa CRLF bulunur', () {
      expect(LineEndings.detect('a\r\nb\r\nc'), LineEnding.crlf);
    });

    test('LF baskınsa LF bulunur', () {
      expect(LineEndings.detect('a\nb\nc'), LineEnding.lf);
    });

    test('karışık dosyada ÇOĞUNLUK kazanır', () {
      expect(LineEndings.detect('a\r\nb\r\nc\nd'), LineEnding.crlf);
    });

    test('satır sonu yoksa LF varsayılır', () {
      expect(LineEndings.detect('tek satır'), LineEnding.lf);
    });

    test('eski Mac (yalnız CR) tanınır', () {
      expect(LineEndings.detect('a\rb\rc'), LineEnding.cr);
    });

    test('gidiş-dönüş: CRLF dosya düzenlenip aynı biçimde geri yazılır', () {
      const original = 'satır1\r\nsatır2\r\n';
      final ending = LineEndings.detect(original);
      final editing = LineEndings.toLf(original); // düzenleyicinin gördüğü
      expect(editing, 'satır1\nsatır2\n');
      expect(LineEndings.apply(editing, ending), original);
    });
  });
}

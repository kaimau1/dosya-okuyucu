import 'package:dosya_okuyucu/core/text_search.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('turkishFold', () {
    test('İ → i, I → ı (Türkçe kuralı)', () {
      expect(turkishFold('İSTANBUL'), 'istanbul');
      expect(turkishFold('IRMAK'), 'ırmak');
    });

    test('uzunluk korunur (indeks hizası)', () {
      const s = 'İIışÖĞ';
      expect(turkishFold(s).length, s.length);
    });
  });

  group('searchSections', () {
    const slides = ['Giriş\nBütçe 2026', 'Ara başlık', 'Bütçe onayı · Bütçe'];

    test('sonuçlar BELGE sırasında gelir (slayt slayt)', () {
      final r = searchSections(slides, 'bütçe');
      expect(r.hits.map((h) => h.section), [0, 2, 2]);
      expect(r.hitLimit, isFalse);
    });

    test('büyük/küçük harf duyarsız, Türkçe katlamalı', () {
      expect(searchSections(const ['IRMAK kenarı'], 'ırmak').hits.length, 1);
      expect(searchSections(const ['İSTANBUL'], 'istanbul').hits.length, 1);
    });

    test('bağlam parçası eşleşmeyi içerir ve satır sonu taşımaz', () {
      final hit = searchSections(slides, 'Bütçe 2026').hits.single;
      expect(hit.section, 0);
      expect(hit.snippet, contains('Bütçe 2026'));
      expect(hit.snippet.contains('\n'), isFalse);
    });

    test('boş sorgu hiçbir şey döndürmez', () {
      expect(searchSections(slides, '   ').hits, isEmpty);
    });

    test('sınıra dayanınca hitLimit bildirilir (sessiz kırpma yok)', () {
      final r = searchSections(const ['aaaaa'], 'a', limit: 3);
      expect(r.hits.length, 3);
      expect(r.hitLimit, isTrue);
    });
  });

  group('findAll', () {
    test('tüm eşleşme indeksleri', () {
      expect(findAll('ab ab ab', 'ab'), [0, 3, 6]);
    });

    test('Türkçe büyük/küçük harf duyarsız', () {
      // "İstanbul" ararken "İSTANBUL" ve "istanbul" bulunur.
      final t = 'İSTANBUL ve istanbul';
      expect(findAll(t, 'istanbul').length, 2);
    });

    test('dotsuz I ile noktalı i karışmaz (Türkçe)', () {
      // "ırmak" (dotsuz) ararken "irmak" (noktalı) EŞLEŞMEZ.
      expect(findAll('irmak', 'ırmak'), isEmpty);
      expect(findAll('IRMAK', 'ırmak'), [0]);
    });

    test('indeks kaynak metne göre doğru', () {
      final t = 'aXbXc';
      expect(findAll(t, 'x'), [1, 3]);
    });

    test('boş sorgu boş liste', () {
      expect(findAll('metin', '  '), isEmpty);
    });

    test('çakışmasız ilerler', () {
      expect(findAll('aaaa', 'aa'), [0, 2]);
    });
  });

  group('TextStats', () {
    test('sözcük ve karakter sayısı', () {
      final s = TextStats.of('bir iki üç');
      expect(s.words, 3);
      expect(s.characters, 10); // "bir iki üç" = 10 karakter
      expect(s.charactersNoSpaces, 8);
    });

    test('satır ve paragraf', () {
      final s = TextStats.of('birinci satır\nikinci satır\n\nyeni paragraf');
      expect(s.lines, 4);
      expect(s.paragraphs, 2);
    });

    test('boş metin sıfır', () {
      final s = TextStats.of('   ');
      expect(s.words, 0);
      expect(s.paragraphs, 0);
    });

    test('çoklu boşluk tek sözcük ayırıcı sayılır', () {
      expect(TextStats.of('a    b\t\tc').words, 3);
    });
  });

  group('turkishSearchPattern', () {
    test('İ/ı ayrımı: aranan sözcük her iki yazımda da bulunur', () {
      // Dart'ın (ve pdfrx'in) yerel-duyarsız katlaması bunları kaçırıyordu.
      expect(turkishSearchPattern('istanbul').hasMatch('İSTANBUL'), isTrue);
      expect(turkishSearchPattern('İSTANBUL').hasMatch('istanbul'), isTrue);
      expect(turkishSearchPattern('ışık').hasMatch('IŞIK'), isTrue);
      expect(turkishSearchPattern('IŞIK').hasMatch('ışık'), isTrue);
    });

    test('noktalı ve noktasız i BİRBİRİNE karışmaz', () {
      // "ısı" ile "isi" farklı sözcükler; katlama ikisini eşitlerse arama
      // yanlış sonuç verir.
      expect(turkishSearchPattern('ısı').hasMatch('isi'), isFalse);
      expect(turkishSearchPattern('isi').hasMatch('ısı'), isFalse);
    });

    test('Türkçe\'ye özgü harfler her iki biçimde eşleşir', () {
      expect(turkishSearchPattern('şçğöü').hasMatch('ŞÇĞÖÜ'), isTrue);
      expect(turkishSearchPattern('ŞÇĞÖÜ').hasMatch('şçğöü'), isTrue);
    });

    test('düzenli ifade karakterleri KAÇIRILIR (desen olarak yorumlanmaz)', () {
      expect(turkishSearchPattern('a.b').hasMatch('axb'), isFalse);
      expect(turkishSearchPattern('a.b').hasMatch('a.b'), isTrue);
      expect(turkishSearchPattern('(1)').hasMatch('(1)'), isTrue);
      expect(turkishSearchPattern(r'a[b]').hasMatch('a[b]'), isTrue);
    });
  });
}

import 'package:dosya_okuyucu/core/settings_search.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Ayar araması — 2026-08-29.** Kullanıcı: *"ayar arama iyi çalışmalı"*.
void main() {
  group('fold (Türkçe duyarsızlaştırma)', () {
    test('Türkçe harfler temel karşılığına iner', () {
      expect(SettingsSearch.fold('Şifre'), 'sifre');
      expect(SettingsSearch.fold('GİZLİLİK'), 'gizlilik');
      expect(SettingsSearch.fold('Işık'), 'isik');
      expect(SettingsSearch.fold('Çöp Kutusu'), 'cop kutusu');
      expect(SettingsSearch.fold('Yüksek tazeleme'), 'yuksek tazeleme');
    });

    test('büyük İ tek karaktere iner (toLowerCase burada bozuluyordu)', () {
      expect(SettingsSearch.fold('İ').length, 1);
      expect(SettingsSearch.fold('İNDİRME'), 'indirme');
    });

    test('noktalama atılır, boşluk tekilleşir', () {
      expect(SettingsSearch.fold('API   anahtarı  (Gemini)'),
          'api anahtari gemini');
      expect(SettingsSearch.fold('3 / 12 · biçim'), '3 12 bicim');
    });

    test('Arapça korunur', () {
      expect(SettingsSearch.fold('السمة').isNotEmpty, isTrue);
    });
  });

  group('eşleşme', () {
    final fields = ['Küçük resimler', 'Listede önizleme göster', 'thumbnails'];

    test('Türkçe harf yazmadan da bulunur', () {
      expect(SettingsSearch.matches(fields, 'kucuk resim'), isTrue);
      expect(SettingsSearch.matches(['Şifre'], 'sifre'), isTrue);
    });

    test('BAŞKA DİLDEKİ adıyla da bulunur', () {
      expect(SettingsSearch.matches(fields, 'thumbnail'), isTrue);
    });

    test('açıklamada geçen sözcük de bulur', () {
      expect(SettingsSearch.matches(fields, 'önizleme'), isTrue);
    });

    test('sorgudaki TÜM kelimeler geçmeli', () {
      expect(SettingsSearch.matches(fields, 'küçük resim'), isTrue);
      expect(SettingsSearch.matches(fields, 'küçük dosya'), isFalse);
    });

    test('alakasız sorgu eşleşmez', () {
      expect(SettingsSearch.matches(fields, 'firebase'), isFalse);
    });

    test('boş sorgu her şeyi geçirir', () {
      expect(SettingsSearch.matches(fields, '   '), isTrue);
    });
  });

  group('sıralama', () {
    test('başlıkta geçen, açıklamada geçenden önce gelir', () {
      final title = SettingsSearch.score(['Tema ailesi', 'Kağıt, gece'], 'tema');
      final body = SettingsSearch.score(['Arka plan', 'tema rengiyle uyumlu'], 'tema');
      expect(title, greaterThan(body));
    });

    test('başlığın BAŞINDA geçen daha yüksek puan alır', () {
      final prefix = SettingsSearch.score(['Dil seçimi'], 'dil');
      final middle = SettingsSearch.score(['Arayüz dili'], 'dil');
      expect(prefix, greaterThan(middle));
    });

    test('eşleşme yoksa 0', () {
      expect(SettingsSearch.score(['Tema'], 'zzz'), 0);
    });
  });
}

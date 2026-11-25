import 'package:dosya_okuyucu/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesli okumanın tek riskli parçası metni bölmek: parça çok uzunsa motor
/// ortadan keser, hiç bölünmezse durdurma gecikir, kelime ortasından bölünürse
/// telaffuz bozulur. Konuşma motoru cihaz gerektirir; bölme saf metin işi.
void main() {
  _cleanForSpeechTests();
  test('hız: flutter_tts Android ×2 yapar → normal 1.0 motora 0.5 gider', () {
    // KÖK 2026-11-25: "hız 1'de ama 1.5–2 katı okuyor".
    expect(TtsService.platformRate(1.0), 0.5);
    expect(TtsService.platformRate(1.3), closeTo(0.65, 1e-9));
    expect(TtsService.platformRate(2.0), 1.0);
    expect(TtsService.platformRate(0.5), 0.25);
    expect(TtsService.platformRate(9), 1.0);
  });

  test('boş metin parça üretmez', () {
    expect(splitForSpeech(''), isEmpty);
    expect(splitForSpeech('   \n  '), isEmpty);
  });

  test('cümle sonlarından bölünür', () {
    final parts = splitForSpeech(
        'Hasta bugün geldi. Ateşi yüksekti! Tahlil istendi?  Sonuç bekleniyor.');

    expect(parts.length, 4);
    expect(parts.first, 'Hasta bugün geldi.');
    expect(parts.last, 'Sonuç bekleniyor.');
  });

  test('satır sonları da böler ve boşluklar sadeleşir', () {
    final parts = splitForSpeech('Birinci satır\n\nİkinci    satır');

    expect(parts, ['Birinci satır', 'İkinci satır']);
  });

  test('uzun cümle kelime sınırından kesilir, sınırı aşmaz', () {
    final long = List.filled(200, 'kelime').join(' ');

    final parts = splitForSpeech(long, maxLength: 100);

    expect(parts.length, greaterThan(1));
    for (final p in parts) {
      expect(p.length, lessThanOrEqualTo(100));
      expect(p.trim(), p); // kenarda boşluk kalmasın
    }
    // Hiçbir kelime ortadan bölünmemeli.
    expect(parts.join(' ').split(' ').toSet(), {'kelime'});
  });

  test('boşluksuz dev kelime yine de kesilir (sonsuz döngü olmaz)', () {
    final parts = splitForSpeech('a' * 500, maxLength: 100);

    expect(parts.length, 5);
    expect(parts.first.length, 100);
  });

  test('metnin tamamı korunur (kelime kaybı yok)', () {
    const text = 'Birinci cümle. İkinci cümle! Üçüncü cümle?';

    final joined = splitForSpeech(text).join(' ');

    expect(joined.replaceAll(RegExp(r'\s+'), ' '),
        text.replaceAll(RegExp(r'\s+'), ' '));
  });
}

/// **Sayfa numarası okunmasın** (2026-08-06 kullanıcı isteği: *"sayfadaki
/// sayfa numaralarının okunmaması lazım"*). Taranmış kitapta numara metnin
/// ortasında kendi satırı olarak durur ve motor onu "otuz beş" diye okuyup
/// cümleyi böler.
void _cleanForSpeechTests() {
  group('cleanForSpeech', () {
    test('tek başına duran sayfa numarası atılır', () {
      final out = cleanForSpeech('Son cümle burada.\n35\nYeni sayfa başlıyor.');
      expect(out, isNot(contains('35')));
      expect(out, contains('Son cümle burada.'));
      expect(out, contains('Yeni sayfa başlıyor.'));
    });

    test('cümlenin İÇİNDEKİ sayı korunur', () {
      expect(cleanForSpeech('Toplantıya 35 kişi geldi.'),
          'Toplantıya 35 kişi geldi.');
    });

    test('satır sonu tiresi birleşir (hece ikiye bölünmez)', () {
      expect(cleanForSpeech('miktarda ener-\njiye ihtiyaç var.'),
          'miktarda enerjiye ihtiyaç var.');
    });

    // 2026-11-25 (kullanıcı: "noktalama, cümle geçişi denetlenmeli,
    // gereksiz şeyler okunmamalı").
    test('PDF başlığı sonraki cümleye yapışmaz (kendi cümlesi olur)', () {
      const pdf = 'METEOROLOJİK UYARI\n'
          "Ankara'da yerel kuvvetli yağış bekleniyor ve akşam saatlerinden "
          'itibaren etkisini artırması bekleniyor.\n'
          'Beklenen Hadise\n'
          'Gökgürültülü sağanak yağış ve yer yer dolu bekleniyor, dikkatli '
          'olunmalı.';
      final out = cleanForSpeech(pdf);
      expect(out, contains('METEOROLOJİK UYARI.'));
      expect(out, contains('Beklenen Hadise.'));
      final parts = splitForSpeech(out);
      expect(parts.first, 'METEOROLOJİK UYARI.');
    });

    test('evrak no, e-posta, emoji ve içindekiler nokta dizisi okunmaz', () {
      final out = cleanForSpeech(
          'Sayı: E-69668904-903.05-337146229 için bilgi@ornek.com yazın 🙂.\n'
          'Giriş ............ 5');
      expect(out, isNot(contains('69668904')));
      expect(out, isNot(contains('@')));
      expect(out, isNot(contains('🙂')));
      expect(out, isNot(contains('....')));
      expect(out, contains('Giriş'));
      expect(cleanForSpeech('16.10.2026 tarihli yazı'), '16.10.2026 tarihli yazı');
    });

    test('boşluklu tire duraklamaya, ve/veya boşluğa döner; aralık korunur', () {
      expect(cleanForSpeech('Ankara – İstanbul hattı'), 'Ankara, İstanbul hattı');
      expect(cleanForSpeech('ve/veya seçilir'), 've veya seçilir');
      expect(cleanForSpeech('10 - 15 kişi'), '10 - 15 kişi');
    });

    test('sıra sayısı ve baş harf noktasında bölünmez', () {
      expect(splitForSpeech('9. Bölge Müdürlüğü yazdı. A. Yılmaz imzaladı.'),
          ['9. Bölge Müdürlüğü yazdı.', 'A. Yılmaz imzaladı.']);
      expect(cleanForSpeech('örn. bir dosya'), 'örneğin bir dosya');
    });
  });
}

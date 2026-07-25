import 'package:dosya_okuyucu/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sesli okumanın tek riskli parçası metni bölmek: parça çok uzunsa motor
/// ortadan keser, hiç bölünmezse durdurma gecikir, kelime ortasından bölünürse
/// telaffuz bozulur. Konuşma motoru cihaz gerektirir; bölme saf metin işi.
void main() {
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

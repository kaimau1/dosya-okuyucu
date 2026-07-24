import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_okuyucu/services/translate_service.dart';

/// ML Kit'e gitmeyen saf bölme mantığı: uzun satır çeviri parçalarına ayrılırken
/// hiçbir karakter kaybolmamalı (kullanıcı "veri kaçmasın" diyor).
void main() {
  test('kısa satır tek parça kalır', () {
    expect(TranslateService.splitLong('Merhaba dünya'), ['Merhaba dünya']);
  });

  test('cümle sonundan böler ve metni kaybetmez', () {
    final line = '${'Bu bir cümledir. ' * 40}Son cümle.';
    final parts = TranslateService.splitLong(line, 100);

    expect(parts.length, greaterThan(1));
    for (final p in parts) {
      expect(p.length, lessThanOrEqualTo(100));
    }
    // Boşluk farkları dışında tüm içerik korunmalı.
    expect(
      parts.join(' ').replaceAll(RegExp(r'\s+'), ' ').trim(),
      line.replaceAll(RegExp(r'\s+'), ' ').trim(),
    );
  });

  test('boşluksuz dev sözcükte sonsuz döngüye girmez', () {
    final line = 'a' * 250;
    final parts = TranslateService.splitLong(line, 100);

    expect(parts.join(), line);
    expect(parts.length, 3);
  });
}

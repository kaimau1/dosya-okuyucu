import 'package:dosya_okuyucu/services/fm/media_duration.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Video süresi rozeti — 2026-08-28.**
/// Kullanıcı: *"videolarda dk ve sn'si önizlemedeyken sağ alt köşesinde
/// yazmalı"*. Biçimleme ve önbellek anahtarı saf fonksiyon olduğu için
/// burada kilitleniyor (native ölçüm cihazda).
void main() {
  setUp(MediaDuration.resetForTest);

  group('biçim', () {
    test('bir saatin altı: dakika:saniye', () {
      expect(MediaDuration.format(const Duration(seconds: 9)), '0:09');
      expect(MediaDuration.format(const Duration(seconds: 75)), '1:15');
      expect(MediaDuration.format(const Duration(minutes: 12, seconds: 34)),
          '12:34');
      expect(MediaDuration.format(const Duration(minutes: 59, seconds: 59)),
          '59:59');
    });

    test('bir saat ve üstü: saat:dakika:saniye (dakika iki hane)', () {
      expect(MediaDuration.format(const Duration(hours: 1, seconds: 3)),
          '1:00:03');
      expect(
          MediaDuration.format(
              const Duration(hours: 1, minutes: 2, seconds: 3)),
          '1:02:03');
      expect(MediaDuration.format(const Duration(hours: 13, minutes: 5)),
          '13:05:00');
    });

    test('saniye HER ZAMAN iki hane (0:9 değil 0:09)', () {
      for (var i = 0; i < 60; i++) {
        final text = MediaDuration.format(Duration(seconds: i));
        expect(text.split(':').last.length, 2, reason: '$i saniye → $text');
      }
    });
  });

  group('önbellek anahtarı', () {
    test('yol + değişiklik zamanı → dosya değişince tazelenir', () {
      const path = '/videolar/tatil.mp4';
      expect(MediaDuration.keyFor(path, 100),
          isNot(MediaDuration.keyFor(path, 200)));
      expect(MediaDuration.keyFor(path, 100), MediaDuration.keyFor(path, 100));
    });

    test('farklı dosyalar çakışmaz', () {
      expect(MediaDuration.keyFor('/a.mp4', 1),
          isNot(MediaDuration.keyFor('/b.mp4', 1)));
    });
  });

  test('okunamayan dosya null döner (0:00 UYDURULMAZ)', () async {
    expect(await MediaDuration.forVideo('/olmayan/dosya.mp4'), isNull);
  });

  /// Ölçüm eşzamanlılığı sınırlı olmalı: 100 videolu bir ızgarada 40 native
  /// çağrıyı birden salmak platform izleğini tıkıyor, kaydırma takılıyordu.
  test('eşzamanlı ölçüm sınırı kilitlenmeye yol açmaz', () async {
    // Hepsi okunamayan yol → ölçüm hızlıca null döner; buradaki asıl soru
    // semaforun her yolda (hata dahil) serbest bırakılıp bırakılmadığı.
    final results = await Future.wait([
      for (var i = 0; i < 12; i++) MediaDuration.forVideo('/yok/$i.mp4'),
    ]);
    expect(results, everyElement(isNull));
    // Sınır sızdırmışsa bu çağrı sonsuza kadar beklerdi.
    expect(await MediaDuration.forVideo('/yok/son.mp4'), isNull);
  });
}

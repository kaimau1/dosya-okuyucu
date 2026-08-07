import 'package:dosya_okuyucu/core/image_budget.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ImageBudget.decodeWidth', () {
    test('ekran genişliği × piksel yoğunluğu kadar piksel ister', () {
      // 1080p telefon: 360 mantıksal genişlik × 3 = 1080 fiziksel piksel.
      // 512'lik kademelere YUKARI yuvarlanır → 1536.
      expect(
        ImageBudget.decodeWidth(logicalWidth: 360, devicePixelRatio: 3),
        1536,
      );
    });

    test('sonuç daima kademe katı (yeniden çözmeyi seyrekleştirir)', () {
      for (final width in [200.0, 320.0, 411.0, 600.0, 1000.0]) {
        for (final ratio in [1.0, 1.5, 2.0, 2.625, 3.0, 4.0]) {
          final got = ImageBudget.decodeWidth(
            logicalWidth: width,
            devicePixelRatio: ratio,
          );
          expect(got % ImageBudget.step, 0,
              reason: '$width × $ratio → $got kademe katı değil');
        }
      }
    });

    test('istenen çözünürlüğün ALTINA düşmez (yukarı yuvarlama)', () {
      // 1100 piksel isteniyorsa 1024 vermek bir kademe bulanık olurdu.
      final got =
          ImageBudget.decodeWidth(logicalWidth: 550, devicePixelRatio: 2);
      expect(got, greaterThanOrEqualTo(1100));
    });

    test('küçük ekranda bile en az minWidth çözülür', () {
      expect(
        ImageBudget.decodeWidth(logicalWidth: 80, devicePixelRatio: 1),
        ImageBudget.minWidth,
      );
    });

    test('yakınlaştırma daha çok piksel getirir ama TAVANI aşamaz', () {
      const width = 400.0;
      const ratio = 3.0;
      final base = ImageBudget.decodeWidth(
          logicalWidth: width, devicePixelRatio: ratio);
      final zoomed = ImageBudget.decodeWidth(
          logicalWidth: width, devicePixelRatio: ratio, zoom: 2);
      expect(zoomed, greaterThan(base));
      // Tavan olmasaydı 6 kat yakınlaştırma 7200 piksel = ~200 MB bitmap
      // isterdi; sorun tam olarak buydu.
      final far = ImageBudget.decodeWidth(
          logicalWidth: width, devicePixelRatio: ratio, zoom: 6);
      expect(far, ImageBudget.maxWidth);
    });

    test('uzaklaştırma (zoom < 1) çözünürlüğü DÜŞÜRMEZ', () {
      const width = 400.0;
      const ratio = 3.0;
      final base = ImageBudget.decodeWidth(
          logicalWidth: width, devicePixelRatio: ratio);
      expect(
        ImageBudget.decodeWidth(
            logicalWidth: width, devicePixelRatio: ratio, zoom: 0.4),
        base,
      );
      // forViewport de aynı: ölçek 1'in altındaysa 1 sayılır.
      expect(
        ImageBudget.forViewport(
            logicalWidth: width, devicePixelRatio: ratio, scale: 0.4),
        base,
      );
    });

    test('bozuk ölçüler (0, NaN, sonsuz) çökmez, güvenli değere düşer', () {
      for (final bad in [0.0, -5.0, double.nan, double.infinity]) {
        expect(
          ImageBudget.decodeWidth(logicalWidth: bad, devicePixelRatio: bad),
          inInclusiveRange(ImageBudget.minWidth, ImageBudget.maxWidth),
        );
        expect(
          ImageBudget.forViewport(
              logicalWidth: 400, devicePixelRatio: 3, scale: bad),
          inInclusiveRange(ImageBudget.minWidth, ImageBudget.maxWidth),
        );
      }
    });

    test('tavan tam çözünürlüğün altında kalır (bütün mesele bu)', () {
      // 12 MP fotoğraf = 4000 piksel geniş. Tavanımız daha düşük olmalı,
      // yoksa "bütçe" hiçbir şey sınırlamaz.
      expect(ImageBudget.maxWidth, lessThan(4000));
      expect(ImageBudget.minWidth, lessThanOrEqualTo(ImageBudget.maxWidth));
    });
  });
}

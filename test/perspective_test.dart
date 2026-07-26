import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:dosya_okuyucu/services/perspective.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perspektif düzeltmenin MATEMATİĞİ (belge tarayıcı köşe ayarı).
///
/// Çizim tarafı GPU gerektirdiği için burada test edilmiyor; hatanın gerçekten
/// olabileceği yer zaten homografi çözümü — yanlışsa sayfa yamuk/ters çıkar.
void main() {
  const eps = 1e-6;

  void expectClose(Offset a, Offset b, {double tol = 1e-6}) {
    expect((a.dx - b.dx).abs(), lessThan(tol), reason: '$a ≠ $b (x)');
    expect((a.dy - b.dy).abs(), lessThan(tol), reason: '$a ≠ $b (y)');
  }

  group('solveHomography', () {
    test('köşeleri birebir eşler (dejenere olmayan dörtgen)', () {
      const unit = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      const quad = [
        Offset(30, 50),
        Offset(400, 20),
        Offset(430, 500),
        Offset(10, 460),
      ];
      final h = solveHomography(unit, quad);
      for (var i = 0; i < 4; i++) {
        expectClose(applyHomography(h, unit[i]), quad[i], tol: 1e-4);
      }
    });

    test('kimlik dönüşümü noktaları değiştirmez', () {
      const unit = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      final h = solveHomography(unit, unit);
      expectClose(applyHomography(h, const Offset(0.25, 0.75)),
          const Offset(0.25, 0.75));
    });

    test('afin (ölçek+kayma) dörtgende ara nokta doğrusal kalır', () {
      const unit = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      // Yalnız ölçek ve öteleme → perspektif terimleri (g,h) sıfır olmalı.
      const scaled = [
        Offset(10, 20),
        Offset(210, 20),
        Offset(210, 120),
        Offset(10, 120),
      ];
      final h = solveHomography(unit, scaled);
      expect(h[6].abs(), lessThan(eps));
      expect(h[7].abs(), lessThan(eps));
      expectClose(applyHomography(h, const Offset(0.5, 0.5)),
          const Offset(110, 70),
          tol: 1e-4);
    });

    test('dejenere dörtgen (tüm köşeler aynı doğruda) hata verir', () {
      const unit = [
        Offset(0, 0),
        Offset(1, 0),
        Offset(1, 1),
        Offset(0, 1),
      ];
      const line = [
        Offset(0, 0),
        Offset(10, 0),
        Offset(20, 0),
        Offset(30, 0),
      ];
      expect(() => solveHomography(unit, line), throwsStateError);
    });

    test('4 noktadan az verilirse reddeder', () {
      expect(
        () => solveHomography(
            const [Offset(0, 0), Offset(1, 0)], const [Offset(0, 0)]),
        throwsArgumentError,
      );
    });
  });

  group('targetSize', () {
    test('düz dikdörtgende kenar uzunluklarını verir', () {
      final size = Perspective.targetSize(const [
        Offset(0, 0),
        Offset(200, 0),
        Offset(200, 100),
        Offset(0, 100),
      ]);
      expect(size.width, closeTo(200, eps));
      expect(size.height, closeTo(100, eps));
    });

    test('eğik dörtgende karşılıklı kenarların ortalamasını alır', () {
      // Üst kenar 100, alt kenar 200 → genişlik 150.
      final size = Perspective.targetSize(const [
        Offset(50, 0),
        Offset(150, 0),
        Offset(200, 100),
        Offset(0, 100),
      ]);
      expect(size.width, closeTo(150, eps));
      // Yan kenarlar: sqrt(50²+100²) her iki tarafta da aynı.
      expect(size.height, closeTo(math.sqrt(50 * 50 + 100 * 100), 1e-6));
    });

    test('sıfır boyuta düşmez (en az 16 px)', () {
      final size = Perspective.targetSize(const [
        Offset(5, 5),
        Offset(5, 5),
        Offset(5, 6),
        Offset(5, 6),
      ]);
      expect(size.width, greaterThanOrEqualTo(16));
      expect(size.height, greaterThanOrEqualTo(16));
    });
  });
}

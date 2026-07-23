import 'package:dosya_okuyucu/core/list_prefix.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('madde işareti', () {
    test('ekler ve algılar', () {
      final t = toggleBullet('elma');
      expect(t, '• elma');
      expect(hasBullet(t), isTrue);
    });

    test('ikinci kez kaldırır', () {
      expect(toggleBullet('• elma'), 'elma');
    });

    test('numaralıdan madde işaretine geçer (çift önek olmaz)', () {
      expect(toggleBullet('3. elma'), '• elma');
    });
  });

  group('numaralı liste', () {
    test('numara ekler', () {
      expect(toggleNumber('elma', 1), '1. elma');
      expect(toggleNumber('armut', 2), '2. armut');
    });

    test('ikinci kez kaldırır', () {
      expect(toggleNumber('1. elma', 1), 'elma');
      expect(hasNumber('1. elma'), isTrue);
    });

    test('maddeden numaraya geçer', () {
      expect(toggleNumber('• elma', 5), '5. elma');
    });
  });

  group('stripListPrefix', () {
    test('madde önekini kaldırır', () {
      expect(stripListPrefix('• metin'), 'metin');
    });

    test('numara önekini kaldırır', () {
      expect(stripListPrefix('12. metin'), 'metin');
    });

    test('önek yoksa değişmez', () {
      expect(stripListPrefix('metin'), 'metin');
    });
  });
}

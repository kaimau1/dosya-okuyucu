import 'dart:math' as math;

import 'package:dosya_okuyucu/services/scan_quality.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Faz 35 / madde 5 — kalite metrikleri: bulanıklık, düşük ışık, eğiklik.
void main() {
  /// Beyaz sayfada [angleDeg] eğimli yatay "metin" çizgileri.
  img.Image page({double angleDeg = 0, int paper = 245, int ink = 20}) {
    const w = 480, h = 600;
    final i = img.Image(width: w, height: h, numChannels: 3);
    img.fill(i, color: img.ColorRgb8(paper, paper, paper));
    final t = math.tan(angleDeg * math.pi / 180);
    for (var row = 60; row < h - 60; row += 24) {
      for (var x = 40; x < w - 40; x++) {
        final y = (row + x * t).round();
        for (var d = 0; d < 4; d++) {
          if (y + d >= 0 && y + d < h) i.setPixelRgb(x, y + d, ink, ink, ink);
        }
      }
    }
    return i;
  }

  test('net sayfa: öneri yok', () {
    final r = ScanQualityCheck.measureImage(page());
    expect(r.blurry, isFalse);
    expect(r.dark, isFalse);
    expect(r.skew.abs(), lessThan(ScanQualityReport.skewLimit));
    expect(r.hint, isNull);
  });

  test('bulanık sayfa: keskinlik düşer → "blurry"', () {
    final sharp = ScanQualityCheck.measureImage(page());
    final blurred =
        ScanQualityCheck.measureImage(img.gaussianBlur(page(), radius: 8));
    expect(blurred.sharpness, lessThan(sharp.sharpness / 4));
    expect(blurred.hint, 'blurry');
  });

  test('karanlık çekim → "dark"', () {
    final r = ScanQualityCheck.measureImage(page(paper: 60, ink: 5));
    expect(r.dark, isTrue);
    expect(r.hint, anyOf('dark', 'blurry'));
  });

  test('eğiklik açıyı yakalar (±0,5°)', () {
    for (final a in [4.0, -3.0]) {
      final r = ScanQualityCheck.measureImage(page(angleDeg: a));
      expect(r.skew, closeTo(a, 0.6), reason: '$a°');
      expect(r.skewed, isTrue);
    }
  });

  test('boş sayfada eğiklik 0', () {
    final blank = img.Image(width: 200, height: 300, numChannels: 3);
    img.fill(blank, color: img.ColorRgb8(250, 250, 250));
    expect(ScanQualityCheck.measureImage(blank).skew, 0);
  });
}

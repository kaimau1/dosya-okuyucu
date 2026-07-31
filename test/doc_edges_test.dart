import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dosya_okuyucu/services/doc_edges.dart';

/// Köşeleri verilen dörtgeni [paper] rengiyle dolduran sahte "fotoğraf".
img.Image _sheetOn(
  int width,
  int height,
  List<({double x, double y})> corners, {
  int table = 40,
  int paper = 235,
}) {
  final image = img.Image(width: width, height: height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final inside = _inPolygon(x + 0.5, y + 0.5, corners);
      final v = inside ? paper : table;
      image.setPixelRgb(x, y, v, v, v);
    }
  }
  return image;
}

bool _inPolygon(double px, double py, List<({double x, double y})> poly) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final a = poly[i], b = poly[j];
    if ((a.y > py) != (b.y > py) &&
        px < (b.x - a.x) * (py - a.y) / (b.y - a.y) + a.x) {
      inside = !inside;
    }
  }
  return inside;
}

/// Bulunan köşe kümesi beklenene ne kadar yakın? (Sıra aynı varsayılır.)
double _maxCornerError(
    List<({double x, double y})> found, List<({double x, double y})> want) {
  var worst = 0.0;
  for (var i = 0; i < 4; i++) {
    final d = math.sqrt(math.pow(found[i].x - want[i].x, 2) +
        math.pow(found[i].y - want[i].y, 2));
    if (d > worst) worst = d;
  }
  return worst;
}

void main() {
  group('DocEdges yardımcıları', () {
    test('boxBlur düz alanı değiştirmez', () {
      final flat = Uint8List.fromList(List.filled(64, 120));
      final blurred = DocEdges.boxBlur(flat, 8, 8, 2);
      expect(blurred.every((v) => v == 120), isTrue);
    });

    test('boxBlur keskin geçişi yumuşatır', () {
      // Sol yarısı 0, sağ yarısı 255 olan 16x4.
      final src = Uint8List(64);
      for (var y = 0; y < 4; y++) {
        for (var x = 8; x < 16; x++) {
          src[y * 16 + x] = 255;
        }
      }
      final blurred = DocEdges.boxBlur(src, 16, 4, 2);
      // Sınırdaki piksel artık ara bir değer.
      expect(blurred[8], greaterThan(0));
      expect(blurred[8], lessThan(255));
      // Uzaktaki pikseller uçlarda kalır.
      expect(blurred[0], 0);
      expect(blurred[15], 255);
    });

    test('sobelMagnitude düz alanda sıfır, kenarda büyük', () {
      final src = Uint8List(64);
      for (var y = 0; y < 8; y++) {
        for (var x = 4; x < 8; x++) {
          src[y * 8 + x] = 255;
        }
      }
      final mag = DocEdges.sobelMagnitude(src, 8, 8);
      expect(mag[3 * 8 + 1], 0, reason: 'düz alanda eğim yok');
      expect(mag[3 * 8 + 3], greaterThan(50), reason: 'kenarda eğim var');
    });

    test('otsuThreshold iki kümeyi ayırır', () {
      // %99 sıfır (düz alan) + %1 yüksek (kenar): eşik ikisinin arasında.
      final values = Uint8List.fromList([
        for (var i = 0; i < 9900; i++) 30,
        for (var i = 0; i < 100; i++) 200,
      ]);
      // Eşik "bunun ÜSTÜ kenardır" anlamında: iki kümenin arasına düşmeli.
      final t = DocEdges.otsuThreshold(values);
      expect(t, greaterThanOrEqualTo(30));
      expect(t, lessThan(200));
    });

    test('quantile histogramdan doğru değeri bulur', () {
      final values = Uint8List.fromList([
        for (var i = 0; i < 90; i++) 10,
        for (var i = 0; i < 10; i++) 200,
      ]);
      expect(DocEdges.quantile(values, 0.5), 10);
      expect(DocEdges.quantile(values, 0.95), 200);
    });

    test('intersect paralel doğrularda null döner', () {
      // İkisi de yatay (θ = 90°): cos 0, sin 1.
      expect(DocEdges.intersect(0, 1, 10, 0, 1, 40), isNull);
    });

    test('intersect dik doğruların kesişimini verir', () {
      // x = 30 (θ=0) ve y = 50 (θ=90).
      final point = DocEdges.intersect(1, 0, 30, 0, 1, 50);
      expect(point!.x, closeTo(30, 1e-6));
      expect(point.y, closeTo(50, 1e-6));
    });

    test('polygonArea dikdörtgenin alanını verir', () {
      final area = DocEdges.polygonArea(const [
        (x: 0.0, y: 0.0),
        (x: 10.0, y: 0.0),
        (x: 10.0, y: 4.0),
        (x: 0.0, y: 4.0),
      ]);
      expect(area, closeTo(40, 1e-9));
    });
  });

  group('DocEdges.detect', () {
    test('eksene paralel kâğıdın köşelerini bulur', () {
      const want = [
        (x: 60.0, y: 80.0),
        (x: 340.0, y: 80.0),
        (x: 340.0, y: 420.0),
        (x: 60.0, y: 420.0),
      ];
      final found = DocEdges.detectInImage(_sheetOn(400, 500, want));
      expect(found, isNotNull);
      // Çözümleme 420 piksele küçültüldüğü için birkaç piksel sapma normal.
      expect(_maxCornerError(found!, want), lessThan(6));
    });

    test('eğik çekilmiş kâğıdı da bulur (perspektif)', () {
      // Üst kenarı hafif eğik, alt kenarı daha geniş: masaya eğik bakan telefon.
      const want = [
        (x: 70.0, y: 90.0),
        (x: 330.0, y: 60.0),
        (x: 350.0, y: 430.0),
        (x: 50.0, y: 400.0),
      ];
      final found = DocEdges.detectInImage(_sheetOn(400, 500, want));
      expect(found, isNotNull);
      expect(_maxCornerError(found!, want), lessThan(20));
    });

    test('düz (kâğıtsız) görselde null döner — uydurma dörtgen yok', () {
      final flat = img.Image(width: 300, height: 300);
      for (var y = 0; y < 300; y++) {
        for (var x = 0; x < 300; x++) {
          flat.setPixelRgb(x, y, 128, 128, 128);
        }
      }
      expect(DocEdges.detectInImage(flat), isNull);
    });

    test('kadrajın küçük bir köşesindeki kâğıt kabul edilmez', () {
      // Görselin yalnız %6'sını kaplıyor: bu kâğıt değil, masadaki bir kart.
      const tiny = [
        (x: 10.0, y: 10.0),
        (x: 90.0, y: 10.0),
        (x: 90.0, y: 80.0),
        (x: 10.0, y: 80.0),
      ];
      expect(DocEdges.detectInImage(_sheetOn(400, 500, tiny)), isNull);
    });

    test('kodlanmış baytlardan da çalışır', () {
      const want = [
        (x: 50.0, y: 60.0),
        (x: 350.0, y: 60.0),
        (x: 350.0, y: 440.0),
        (x: 50.0, y: 440.0),
      ];
      final bytes = img.encodePng(_sheetOn(400, 500, want));
      expect(DocEdges.detect(bytes), isNotNull);
    });
  });
}

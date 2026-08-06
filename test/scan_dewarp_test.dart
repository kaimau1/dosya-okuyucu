import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/scan_dewarp.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// **Metne bakarak düzleştirme** (2026-08-06 kullanıcı bulgusu: kendi çektiği
/// kitap sayfasında satırlar eğik çıkıyor ve OCR zorlanıyor; kâğıt kenarı
/// görünmediği için kenar tabanlı düzeltme hiç devreye girmiyordu).
///
/// Sentetik "sayfa"lar üretilip ölçüm doğrulanıyor: eğim açısı geri
/// bulunabiliyor mu, düzeltme sonrası eğim sıfıra iniyor mu, kıvrım
/// yokken sayfaya dokunuluyor mu.
void main() {
  /// Yatay metin satırlarından oluşan sahte sayfa (beyaz zemin, siyah bantlar).
  img.Image page({
    int width = 600,
    int height = 800,
    int lineHeight = 8,
    int spacing = 24,
    double Function(int x)? bend,
  }) {
    final image = img.Image(width: width, height: height, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    for (var top = 60; top < height - 60; top += spacing) {
      for (var x = 40; x < width - 40; x++) {
        final offset = (bend?.call(x) ?? 0).round();
        for (var y = top; y < top + lineHeight; y++) {
          final yy = y + offset;
          if (yy < 0 || yy >= height) continue;
          image.setPixelRgb(x, yy, 20, 20, 20);
        }
      }
    }
    return image;
  }

  Uint8List inkOf(img.Image image) {
    final w = image.width, h = image.height;
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final ink = Uint8List(w * h);
    for (var i = 0, j = 0; i < ink.length; i++, j += 3) {
      ink[i] = rgb[j] < 128 ? 0 : 255;
    }
    return ink;
  }

  group('eğim kestirimi', () {
    test('düz sayfada eğim yok', () {
      final image = page();
      expect(
        ScanDewarp.estimateSkewDegrees(
            inkOf(image), image.width, image.height),
        closeTo(0, 0.2),
      );
    });

    double skewOf(img.Image i) =>
        ScanDewarp.estimateSkewDegrees(inkOf(i), i.width, i.height);

    test('eğik sayfada açı geri bulunur', () {
      final tilted = ScanDewarp.rotateWhite(page(), 4.0);
      expect(skewOf(tilted), closeTo(4.0, 0.4));
      expect(skewOf(ScanDewarp.rotateWhite(page(), -4.0)), closeTo(-4.0, 0.4));
    });

    /// **İşaret sözleşmesi.** Bu test bir kez GERÇEK bir hatayı yakaladı:
    /// düzeltme `+eğim` ile döndürülüyordu (yani eğimi ikiye katlıyordu) ama
    /// arkasından gelen kıvrım adımı kaymayı kesme ile örttüğü için uçtan uca
    /// test yeşil kalıyordu.
    test('düzeltme −eğim ile döner; +eğim eğimi İKİYE KATLAR', () {
      final tilted = ScanDewarp.rotateWhite(page(), 5.0);
      expect(skewOf(ScanDewarp.rotateWhite(tilted, -5.0)), closeTo(0, 0.4));
      expect(skewOf(ScanDewarp.rotateWhite(tilted, 5.0)), closeTo(10.0, 0.6));
    });

    test('düzeltme sonrası eğim sıfıra iner', () {
      final tilted = ScanDewarp.rotateWhite(page(), 5.0);
      final fixed = ScanDewarp.straighten(tilted);
      expect(fixed, isNotNull);
      expect(
        ScanDewarp.estimateSkewDegrees(
            inkOf(fixed!), fixed.width, fixed.height),
        closeTo(0, 0.4),
      );
    });

    test('mürekkepsiz (boş) sayfaya dokunulmaz', () {
      final blank = img.Image(width: 400, height: 500, numChannels: 3);
      img.fill(blank, color: img.ColorRgb8(255, 255, 255));
      expect(ScanDewarp.straighten(blank), isNull);
    });
  });

  group('bombe (kıvrım)', () {
    test('düz sayfada kıvrım bildirilmez', () {
      final image = page();
      expect(
        ScanDewarp.columnShifts(inkOf(image), image.width, image.height),
        isNull,
      );
    });

    test('kavisli satırlarda şerit kaymaları ölçülür', () {
      // Sayfanın sağ yarısı aşağı kıvrılıyor (kitap sırtı etkisi).
      final image = page(
        bend: (x) => 14 * math.sin(math.pi * x / 600),
      );
      final shifts =
          ScanDewarp.columnShifts(inkOf(image), image.width, image.height);
      expect(shifts, isNotNull);
      // Orta şeritler kenarlara göre AŞAĞIDA olmalı (kayma daha büyük).
      final middle = shifts![shifts.length ~/ 2];
      expect(middle, greaterThan(shifts.first));
      expect(middle, greaterThan(shifts.last));
      // Ortalaması sıfırlanmış olmalı.
      expect(shifts.reduce((a, b) => a + b) / shifts.length, closeTo(0, 0.001));
    });

    test('kıvrım düzeltilince kalan kıvrım kayda değmez', () {
      final image = page(bend: (x) => 14 * math.sin(math.pi * x / 600));
      final fixed = ScanDewarp.straighten(image);
      expect(fixed, isNotNull);
      expect(
        ScanDewarp.columnShifts(inkOf(fixed!), fixed.width, fixed.height),
        isNull,
      );
    });
  });
}

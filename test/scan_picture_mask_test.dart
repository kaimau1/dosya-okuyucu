import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dosya_okuyucu/services/scan_dewarp.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';

/// Kullanıcı 2026-10-18: *"belge tarandıktan ve onaylandıktan sonra arka
/// planda yapılan iyileştirmeler resmin patlamasına ve bozulmasına sebep
/// oluyor"* + *"resimli sayfalarda yanlış kesiyor"*. Aydınlatma düzeltmesi
/// fotoğrafı kendi ortalamasına bölüp beyaza yakın düz bir lekeye
/// çeviriyordu; renkli modda oran ×4'e çıkıp kanallar patlıyordu.
///
/// Kurgu: üst yarısı gölgeli yazılı kâğıt, alt yarısında renkli, dokulu bir
/// "fotoğraf" ve içinde DÜZ bir gökyüzü şeridi olan sayfa.
img.Image _pageWithPhoto({int w = 480, int h = 640}) {
  final image = img.Image(width: w, height: h, numChannels: 3);
  final random = math.Random(7);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Soldan sağa hafif gölge.
      final paper = 236 - (50 * x / (w - 1)).round();
      var r = paper, g = paper, b = paper - 6;
      final isLine = y < 280 && (y % 18) < 5 && x > 30 && x < w - 30;
      if (isLine && (x ~/ 9) % 4 != 3) {
        r = g = b = (paper * 0.25).round();
      }
      // Fotoğraf: (60..420) × (330..600).
      if (x >= 60 && x < 420 && y >= 330 && y < 600) {
        if (y < 390) {
          // Düz gök şeridi — ara ton ölçüsü bunu yakalamaz.
          r = 120;
          g = 165;
          b = 215;
        } else {
          final t = (x - 60) / 360;
          r = (90 + 120 * t + random.nextInt(60)).round().clamp(0, 255);
          g = (60 + 80 * (1 - t) + random.nextInt(60)).round().clamp(0, 255);
          b = (40 + random.nextInt(70)).clamp(0, 255);
        }
      }
      image.setPixelRgb(x, y, r, g, b);
    }
  }
  return image;
}

Uint8List _gray(img.Image image) {
  final rgb = image.getBytes(order: img.ChannelOrder.rgb);
  final out = Uint8List(image.width * image.height);
  for (var i = 0, j = 0; i < out.length; i++, j += 3) {
    out[i] = (rgb[j] * 0.299 + rgb[j + 1] * 0.587 + rgb[j + 2] * 0.114)
        .round()
        .clamp(0, 255);
  }
  return out;
}

void main() {
  test('maske fotoğrafı (düz gök şeridi dahil) işaretler, yazıyı işaretlemez',
      () {
    final page = _pageWithPhoto();
    final rgb = page.getBytes(order: img.ChannelOrder.rgb);
    final mask = ScanEnhance.pictureMask(_gray(page), page.width, page.height,
        rgb: rgb);
    int at(int x, int y) => mask[y * page.width + x];

    // Fotoğrafın dokulu kısmı ve düz gök şeridi.
    expect(at(240, 500), 255);
    expect(at(240, 350), 255, reason: 'düz gök şeridi de fotoğrafın parçası');
    expect(at(80, 580), 255);
    // Yazılı kâğıt.
    expect(at(240, 100), 0);
    expect(at(60, 40), 0);
    expect(at(440, 200), 0);
  });

  test('otomatik filtre fotoğrafa DOKUNMAZ, kâğıdı yine beyazlatır', () {
    final page = _pageWithPhoto();
    final out = ScanEnhance.applyToImage(page, ScanFilter.auto);
    expect(out.width, page.width);

    // Fotoğrafın içi: ortalama kanal farkı küçük (eskiden 100+ idi).
    var diff = 0, n = 0;
    for (var y = 340; y < 590; y += 3) {
      for (var x = 75; x < 405; x += 3) {
        final a = page.getPixel(x, y), b = out.getPixel(x, y);
        diff += (a.r - b.r).abs().round() +
            (a.g - b.g).abs().round() +
            (a.b - b.b).abs().round();
        n += 3;
      }
    }
    expect(diff / n, lessThan(6), reason: 'fotoğraf bozulmamalı');

    // Gölgeli kâğıt (sağ üst, satır arası) belirgin açıldı.
    final before = page.getPixel(440, 10).r;
    final after = out.getPixel(440, 10).r;
    expect(after - before, greaterThan(20));
  });

  test('siyah-beyaz filtrede fotoğraf eşiklenmez (gri kalır)', () {
    final page = _pageWithPhoto();
    final out = ScanEnhance.applyToImage(page, ScanFilter.blackWhite);
    final values = <int>{};
    for (var x = 80; x < 400; x += 7) {
      values.add(out.getPixel(x, 500).r.round());
    }
    expect(values.length, greaterThan(8), reason: 'ara tonlar korunmalı');
  });

  test('kâğıt olmayan koyu sayfaya (koyu fotoğraf) hiç dokunulmaz', () {
    final image = img.Image(width: 120, height: 120, numChannels: 3);
    img.fill(image, color: img.ColorRgb8(70, 40, 30));
    final out = ScanEnhance.applyToImage(image, ScanFilter.auto);
    final p = out.getPixel(60, 60);
    expect(p.r, 70);
    expect(p.g, 40);
    expect(p.b, 30);
  });

  test('gölgedeki renkli kâğıtta renk patlamaz (sapma sınırlı büyür)', () {
    // Sol yarı aydınlık beyaz kâğıt, sağ yarı derin gölgede hafif sarımsı
    // kâğıt; satırlar her iki yanda.
    final image = img.Image(width: 240, height: 160, numChannels: 3);
    for (var y = 0; y < 160; y++) {
      for (var x = 0; x < 240; x++) {
        final shade = x < 120 ? 1.0 : 0.45;
        var r = (240 * shade).round(), g = (236 * shade).round();
        var b = (214 * shade).round();
        if ((y % 16) < 4 && x % 12 < 9) {
          r = g = b = (40 * shade).round();
        }
        image.setPixelRgb(x, y, r, g, b);
      }
    }
    final out = ScanEnhance.applyToImage(image, ScanFilter.auto);
    final p = out.getPixel(200, 10);
    // Kâğıt açıldı ama sarı kanal ayrımı uçmadı (r−b farkı makul).
    expect(p.r, greaterThan(200));
    expect((p.r - p.b).abs(), lessThan(60));
  });

  test('yazısız yalnız fotoğraf sayfası düzleştirilmez', () {
    final image = img.Image(width: 400, height: 520, numChannels: 3);
    final random = math.Random(3);
    for (var y = 0; y < image.height; y++) {
      for (var x = 0; x < image.width; x++) {
        final v = (80 + (x + y) % 90 + random.nextInt(40)).clamp(0, 255);
        image.setPixelRgb(x, y, v, (v * 0.8).round(), (v * 0.6).round());
      }
    }
    expect(ScanDewarp.straighten(image), isNull);
  });
}

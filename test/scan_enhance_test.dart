import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dosya_okuyucu/services/scan_enhance.dart';

/// Soldan sağa kararan bir "gölge" altında, üstüne koyu yazı konmuş sayfa.
///
/// Gerçek sorunun taklidi: aynı yazı sayfanın sol yarısında 180, sağ yarısında
/// 60 parlaklıkta görünüyor. Tek bir genel eşik bunları asla birlikte doğru
/// sınıflandıramaz — düzeltmenin işe yarayıp yaramadığı buradan anlaşılır.
({Uint8List gray, int w, int h, List<int> ink, List<int> paper}) _shadowedPage(
    {int w = 120, int h = 80}) {
  final gray = Uint8List(w * h);
  final ink = <int>[];
  final paper = <int>[];
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Zemin: solda parlak (235), sağda karanlık (75).
      final background = 235 - (160 * x / (w - 1)).round();
      // "Yazı": her 10 satırda bir 3 piksellik koyu şerit.
      final isInk = (y % 10) < 3 && x > 4 && x < w - 5;
      final value = isInk ? (background * 0.45).round() : background;
      final i = y * w + x;
      gray[i] = value.clamp(0, 255);
      (isInk ? ink : paper).add(i);
    }
  }
  return (gray: gray, w: w, h: h, ink: ink, paper: paper);
}

void main() {
  group('aydınlatma düzeltme', () {
    test('gölgeli sayfada zemini eşitler', () {
      final page = _shadowedPage();
      final flat = ScanEnhance.flattenIllumination(
          page.gray, page.w, page.h, (page.w * 0.06).round().clamp(4, 99));

      // ÖNCE: aynı zeminin iki ucu arasında uçurum var.
      final beforeLeft = page.gray[5 * page.w + 5];
      final beforeRight = page.gray[5 * page.w + page.w - 6];
      expect((beforeLeft - beforeRight).abs(), greaterThan(100),
          reason: 'kurgu gerçekten gölgeli olmalı');

      // SONRA: kâğıt her yerde kâğıt gibi (parlak) görünüyor.
      var darkestPaper = 255;
      for (final i in page.paper) {
        if (flat[i] < darkestPaper) darkestPaper = flat[i];
      }
      expect(darkestPaper, greaterThan(180),
          reason: 'düzeltmeden sonra zeminin en karanlık yeri bile kâğıt');
    });

    test('yazıyı zeminden ayrık bırakır (yazıyı silmez)', () {
      final page = _shadowedPage();
      final flat = ScanEnhance.flattenIllumination(
          page.gray, page.w, page.h, (page.w * 0.06).round().clamp(4, 99));
      var brightestInk = 0;
      for (final i in page.ink) {
        if (flat[i] > brightestInk) brightestInk = flat[i];
      }
      var darkestPaper = 255;
      for (final i in page.paper) {
        if (flat[i] < darkestPaper) darkestPaper = flat[i];
      }
      expect(brightestInk, lessThan(darkestPaper),
          reason: 'en açık yazı bile en koyu kâğıttan koyu kalmalı');
    });

    test('zemin sıfıra yakınken taşmaz', () {
      final black = Uint8List.fromList(List.filled(64, 0));
      final flat = ScanEnhance.flattenIllumination(black, 8, 8, 2);
      expect(flat.every((v) => v >= 0 && v <= 255), isTrue);
    });
  });

  group('kontrast gerdirme', () {
    test('dar aralığı 0-255\'e yayar', () {
      final narrow = Uint8List.fromList([
        for (var i = 0; i < 100; i++) 100,
        for (var i = 0; i < 100; i++) 160,
      ]);
      final out = ScanEnhance.stretchContrast(narrow);
      expect(out.reduce((a, b) => a < b ? a : b), 0);
      expect(out.reduce((a, b) => a > b ? a : b), 255);
    });

    test('neredeyse tek renk görsele DOKUNMAZ (gürültüyü şişirmez)', () {
      final flat = Uint8List.fromList(List.filled(100, 128));
      final out = ScanEnhance.stretchContrast(flat);
      expect(out, same(flat));
    });
  });

  test('keskinleştirme kenar karşıtlığını artırır', () {
    // 16x4: soldan sağa yumuşak geçiş.
    const w = 16, h = 4;
    final src = Uint8List(w * h);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        src[y * w + x] = (x * 255 / (w - 1)).round();
      }
    }
    final soft = ScanEnhance.sharpen(src, w, h, 0.0);
    final sharp = ScanEnhance.sharpen(src, w, h, 1.5);
    // Keskinleştirme rampanın uçlarını daha da uca iter.
    expect(sharp[0], lessThanOrEqualTo(soft[0]));
    expect(sharp[w - 1], greaterThanOrEqualTo(soft[w - 1]));
  });

  group('uyarlamalı eşikleme', () {
    test('gölgeli sayfada yazıyı DOĞRU ayırır', () {
      final page = _shadowedPage();
      final bw = ScanEnhance.adaptiveThreshold(page.gray, page.w, page.h,
          radius: 6, bias: 10);
      var inkBlack = 0;
      for (final i in page.ink) {
        if (bw[i] == 0) inkBlack++;
      }
      var paperWhite = 0;
      for (final i in page.paper) {
        if (bw[i] == 255) paperWhite++;
      }
      expect(inkBlack / page.ink.length, greaterThan(0.85),
          reason: 'yazının neredeyse tamamı siyah olmalı');
      expect(paperWhite / page.paper.length, greaterThan(0.9),
          reason: 'kâğıdın neredeyse tamamı beyaz kalmalı');
    });

    test('düz beyaz alanı lekelemez', () {
      final white = Uint8List.fromList(List.filled(400, 240));
      final bw =
          ScanEnhance.adaptiveThreshold(white, 20, 20, radius: 3, bias: 10);
      expect(bw.every((v) => v == 255), isTrue);
    });
  });

  group('applyToImage', () {
    img.Image build() {
      final page = _shadowedPage(w: 60, h: 40);
      final rgb = Uint8List(page.gray.length * 3);
      for (var i = 0, j = 0; i < page.gray.length; i++, j += 3) {
        rgb[j] = rgb[j + 1] = rgb[j + 2] = page.gray[i];
      }
      return img.Image.fromBytes(
          width: page.w, height: page.h, bytes: rgb.buffer, numChannels: 3);
    }

    test('ölçüyü korur', () {
      for (final filter in ScanFilter.values) {
        if (filter == ScanFilter.original) continue;
        final out = ScanEnhance.applyToImage(build(), filter);
        expect(out.width, 60);
        expect(out.height, 40);
      }
    });

    test('siyah-beyaz filtresi yalnız iki değer üretir', () {
      final out = ScanEnhance.applyToImage(build(), ScanFilter.blackWhite);
      final bytes = out.getBytes(order: img.ChannelOrder.rgb);
      expect(bytes.every((v) => v == 0 || v == 255), isTrue);
    });

    test('otomatik filtre gölgeyi belirgin biçimde azaltır', () {
      final before = build();
      final after = ScanEnhance.applyToImage(before, ScanFilter.auto);
      int spread(img.Image image) {
        // Zemin satırlarından birinde sol-sağ farkı (yazı olmayan satır: y=5).
        final left = image.getPixel(3, 5).r.round();
        final right = image.getPixel(image.width - 4, 5).r.round();
        return (left - right).abs();
      }

      expect(spread(before), greaterThan(100));
      expect(spread(after), lessThan(40));
    });

    test('özgün filtre baytları hiç değiştirmez', () {
      final bytes = img.encodeJpg(build());
      expect(ScanEnhance.applyToBytes(bytes, ScanFilter.original), same(bytes));
    });
  });
}

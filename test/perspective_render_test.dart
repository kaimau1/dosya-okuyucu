import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/services/perspective.dart';
import 'package:flutter_test/flutter_test.dart';

/// Perspektif düzeltme ve döndürmenin **gerçekten piksel ürettiği** kontrolü.
///
/// [perspective_test.dart] matematiği doğruluyor; burada çizim yolu (drawVertices
/// + ImageShader) koşuyor. Sessiz bir "boş görüntü" hatası matematik testlerine
/// yakalanmazdı — kullanıcı düzeltmeye basınca bembeyaz sayfa alırdı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sol yarısı kırmızı, sağ yarısı mavi [w]×[h] görsel.
  Future<ui.Image> twoTone(int w, int h) {
    final pixels = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final i = (y * w + x) * 4;
        final left = x < w / 2;
        pixels[i] = left ? 255 : 0; // R
        pixels[i + 1] = 0; // G
        pixels[i + 2] = left ? 0 : 255; // B
        pixels[i + 3] = 255; // A
      }
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(pixels, w, h, ui.PixelFormat.rgba8888, done.complete);
    return done.future;
  }

  Future<ui.Image> decodePng(Uint8List png) async {
    final codec = await ui.instantiateImageCodec(png);
    return (await codec.getNextFrame()).image;
  }

  Future<(int, int, int)> pixelAt(ui.Image image, int x, int y) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final i = (y * image.width + x) * 4;
    final b = data!.buffer.asUint8List();
    return (b[i], b[i + 1], b[i + 2]);
  }

  test('warpToPng tam kareyi seçince görüntüyü korur', () async {
    final src = await twoTone(80, 40);
    try {
      final png = await Perspective.warpToPng(src, const [
        ui.Offset(0, 0),
        ui.Offset(80, 0),
        ui.Offset(80, 40),
        ui.Offset(0, 40),
      ]);
      final out = await decodePng(png);
      try {
        expect(out.width, 80);
        expect(out.height, 40);
        // Sol kırmızı, sağ mavi kalmalı (boş/siyah çıkarsa çizim kopmuş demektir).
        final (lr, lg, lb) = await pixelAt(out, 8, 20);
        final (rr, rg, rb) = await pixelAt(out, 71, 20);
        expect(lr, greaterThan(200), reason: 'sol yarı kırmızı değil');
        expect(lb, lessThan(60));
        expect(rb, greaterThan(200), reason: 'sağ yarı mavi değil');
        expect(rr, lessThan(60));
        expect(lg + rg, lessThan(60));
      } finally {
        out.dispose();
      }
    } finally {
      src.dispose();
    }
  });

  test('warpToPng dörtgenin yarısını seçince o yarıyı açar', () async {
    final src = await twoTone(80, 40);
    try {
      // Yalnız SAĞ yarı (mavi) seçilirse çıktının tamamı mavi olmalı.
      final png = await Perspective.warpToPng(src, const [
        ui.Offset(40, 0),
        ui.Offset(80, 0),
        ui.Offset(80, 40),
        ui.Offset(40, 40),
      ]);
      final out = await decodePng(png);
      try {
        expect(out.width, 40);
        final (r, g, b) = await pixelAt(out, out.width ~/ 2, out.height ~/ 2);
        expect(b, greaterThan(200));
        expect(r, lessThan(60));
        expect(g, lessThan(60));
      } finally {
        out.dispose();
      }
    } finally {
      src.dispose();
    }
  });

  test('rotateToPng 90° en/boyu takas eder ve içeriği çevirir', () async {
    final src = await twoTone(80, 40);
    try {
      final out = await decodePng(await Perspective.rotateToPng(src, 1));
      try {
        expect(out.width, 40);
        expect(out.height, 80);
        // Saat yönünde 90°: soldaki kırmızı ÜSTE gelir.
        final (tr, _, tb) = await pixelAt(out, 20, 8);
        final (br, _, bb) = await pixelAt(out, 20, 71);
        expect(tr, greaterThan(200), reason: 'kırmızı üste gelmemiş');
        expect(tb, lessThan(60));
        expect(bb, greaterThan(200), reason: 'mavi alta gelmemiş');
        expect(br, lessThan(60));
      } finally {
        out.dispose();
      }
    } finally {
      src.dispose();
    }
  });

  test('rotateToPng 4 çeyrek tur özgün boyuta döner', () async {
    final src = await twoTone(80, 40);
    try {
      final out = await decodePng(await Perspective.rotateToPng(src, 4));
      try {
        expect(out.width, 80);
        expect(out.height, 40);
      } finally {
        out.dispose();
      }
    } finally {
      src.dispose();
    }
  });

  test('4 köşeden az verilirse reddedilir', () async {
    final src = await twoTone(10, 10);
    try {
      expect(
        () => Perspective.warpToPng(src, const [ui.Offset.zero]),
        throwsArgumentError,
      );
    } finally {
      src.dispose();
    }
  });
}

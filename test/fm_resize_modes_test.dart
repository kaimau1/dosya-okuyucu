import 'dart:io';

import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/image_resize.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// **Faz 14 — görsel boyutlandırma 2.0.** Kullanıcı (2026-10-22): *"kolay
/// biçimde ve istediğim oranda görüntü boyutlarını değiştiremiyorum"*.
/// Kipler: yüzde (%1–400), piksel (oran kilidi + sığdır/doldur/boşluk/esnet),
/// uzun kenar, en-boy oranı, dosya boyutu hedefi.
({int width, int height}) photo(int w, int h, MediaResizeOptions o) =>
    targetSize(sourceWidth: w, sourceHeight: h, options: o, video: false);

void main() {
  group('hedef ölçü (fotoğraf)', () {
    test('uzun kenar: yatay, dikey, kare; büyütme yok', () {
      const o = MediaResizeOptions(
          resolution: ResolutionChoice.longEdge, longEdgePx: 1600);
      expect(photo(4000, 3000, o), (width: 1600, height: 1200));
      expect(photo(3000, 4000, o), (width: 1200, height: 1600));
      expect(photo(2000, 2000, o), (width: 1600, height: 1600));
      expect(photo(1000, 750, o), (width: 1000, height: 750));
    });

    test('fotoğrafta tek sayı serbest (G4k) — videoda çift', () {
      const o = MediaResizeOptions(
          resolution: ResolutionChoice.custom, customWidth: 1081);
      expect(photo(4000, 3000, o).width, 1081);
      expect(
          targetSize(sourceWidth: 4000, sourceHeight: 3000, options: o).width,
          1080);
    });

    test('yüzde %150 fotoğrafı büyütür (K14), videoda %100\'e kırpılır', () {
      const o =
          MediaResizeOptions(resolution: ResolutionChoice.percent, percent: 150);
      expect(photo(1000, 800, o), (width: 1500, height: 1200));
      expect(targetSize(sourceWidth: 1000, sourceHeight: 800, options: o),
          (width: 1000, height: 800));
      expect(o.upscales(), isTrue);
      expect(const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 1)
          .upscales(), isFalse);
    });

    test('serbest ölçü kaynaktan büyük → fotoğrafta UYGULANIR ve uyarılır', () {
      const o = MediaResizeOptions(
          resolution: ResolutionChoice.custom, customWidth: 2000);
      expect(photo(1000, 750, o), (width: 2000, height: 1500));
      expect(o.upscales(sourceWidth: 1000, sourceHeight: 750), isTrue);
    });

    test('kilit kapalı + 1080×1080 → dört yerleşim', () {
      MediaResizeOptions box(ResizeFit f) => MediaResizeOptions(
          resolution: ResolutionChoice.custom,
          customWidth: 1080,
          customHeight: 1080,
          lockAspect: false,
          fit: f);
      expect(photo(4000, 3000, box(ResizeFit.contain)),
          (width: 1080, height: 810));
      for (final f in [ResizeFit.cover, ResizeFit.pad, ResizeFit.stretch]) {
        expect(photo(4000, 3000, box(f)), (width: 1080, height: 1080),
            reason: f.name);
      }
    });

    test('en-boy oranı: kırp içeride, boşluk dışarıda', () {
      MediaResizeOptions ratio(double w, double h, ResizeFit f) =>
          MediaResizeOptions(
              resolution: ResolutionChoice.aspect,
              aspectW: w,
              aspectH: h,
              fit: f);
      // Yatay 4000×3000 → 1:1
      expect(photo(4000, 3000, ratio(1, 1, ResizeFit.cover)),
          (width: 3000, height: 3000));
      expect(photo(4000, 3000, ratio(1, 1, ResizeFit.pad)),
          (width: 4000, height: 4000));
      // Dikey 3000×4000 → 16:9
      expect(photo(3000, 4000, ratio(16, 9, ResizeFit.cover)),
          (width: 3000, height: 1688));
      expect(photo(3000, 4000, ratio(16, 9, ResizeFit.pad)),
          (width: 7111, height: 4000));
      // A4 (1:√2) dikey sayfa
      expect(photo(2100, 2100, ratio(210, 297, ResizeFit.cover)),
          (width: 1485, height: 2100));
    });
  });

  group('çizim (piksel)', () {
    // 40×20: sol yarı KIRMIZI, sağ yarı MAVİ.
    img.Image source() {
      final im = img.Image(width: 40, height: 20);
      for (var y = 0; y < 20; y++) {
        for (var x = 0; x < 40; x++) {
          im.setPixelRgb(x, y, x < 20 ? 255 : 0, 0, x < 20 ? 0 : 255);
        }
      }
      return im;
    }

    MediaResizeOptions box(ResizeFit f, [PadColor c = PadColor.white]) =>
        MediaResizeOptions(
            resolution: ResolutionChoice.custom,
            customWidth: 20,
            customHeight: 20,
            lockAspect: false,
            fit: f,
            padColor: c);

    test('Sığdır: oran korunur, kutunun içinde', () {
      final out = ImageResizer.render(source(), box(ResizeFit.contain));
      expect((out.width, out.height), (20, 10));
    });

    test('Doldur ve kırp: tam kutu, ortadan kırpılır (iki renk de var)', () {
      final out = ImageResizer.render(source(), box(ResizeFit.cover));
      expect((out.width, out.height), (20, 20));
      expect(out.getPixel(2, 10).r, greaterThan(200)); // sol kırmızı
      expect(out.getPixel(17, 10).b, greaterThan(200)); // sağ mavi
    });

    test('Kenar boşluğu: beyaz şeritler üstte/altta, görüntü ortada', () {
      final out = ImageResizer.render(source(), box(ResizeFit.pad));
      expect((out.width, out.height), (20, 20));
      final top = out.getPixel(10, 1);
      expect((top.r, top.g, top.b), (255, 255, 255));
      expect(out.getPixel(2, 10).r, greaterThan(200));
    });

    test('Kenar boşluğu siyah ve saydam (PNG)', () {
      final black =
          ImageResizer.render(source(), box(ResizeFit.pad, PadColor.black));
      expect(black.getPixel(10, 1).r, 0);
      final clear = ImageResizer.render(
          source(), box(ResizeFit.pad, PadColor.transparent),
          alpha: true);
      expect(clear.getPixel(10, 1).a, 0);
      // JPEG'e giden saydam istek beyaza düşer.
      final jpeg = ImageResizer.render(
          source(), box(ResizeFit.pad, PadColor.transparent));
      expect(jpeg.getPixel(10, 1).r, 255);
    });

    test('Kenar boşluğu bulanık: zemin görüntünün renklerinden', () {
      final out =
          ImageResizer.render(source(), box(ResizeFit.pad, PadColor.blur));
      expect((out.width, out.height), (20, 20));
      final p = out.getPixel(10, 1);
      expect((p.r, p.g, p.b), isNot((255, 255, 255)));
    });

    test('Esnet: tam kutu', () {
      final out = ImageResizer.render(source(), box(ResizeFit.stretch));
      expect((out.width, out.height), (20, 20));
    });

    test('Oran kipi 1:1 kırp → kare, ortadan', () {
      final out = ImageResizer.render(
          source(),
          const MediaResizeOptions(
              resolution: ResolutionChoice.aspect, fit: ResizeFit.cover));
      expect((out.width, out.height), (20, 20));
    });
  });

  group('dosya boyutu hedefi', () {
    /// Sıkıştırılması güç (gürültülü) görüntü.
    img.Image noisy(int w, int h) {
      final im = img.Image(width: w, height: h);
      var seed = 7;
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          seed = (seed * 1103515245 + 12345) & 0x7fffffff;
          im.setPixelRgb(x, y, seed & 255, (seed >> 8) & 255, (seed >> 16) & 255);
        }
      }
      return im;
    }

    test('hedefin altına iner (kalite + gerekirse ölçek)', () {
      final src = noisy(400, 300);
      final full = img.encodeJpg(src, quality: 95).length;
      final target = full ~/ 6;
      final r = ImageResizer.fitToBytes(src, target);
      expect(r.bytes.length, lessThanOrEqualTo(target));
      expect(img.decodeJpg(r.bytes as dynamic), isNotNull);
    });

    test('zaten küçükse en yüksek kaliteyle tek kodlama', () {
      final src = img.Image(width: 50, height: 50);
      final r = ImageResizer.fitToBytes(src, 1 << 20);
      expect(r.quality, 95);
      expect(r.image.width, 50);
    });

    test('ulaşılamazsa en küçük sonuç döner (çağıran gerçek boyutu yazar)', () {
      final r = ImageResizer.fitToBytes(noisy(200, 200), 10, maxEncodes: 4);
      expect(r.bytes.length, greaterThan(10));
      expect(r.image.width, lessThan(200));
    });

    test('kabul: ~2 MB fotoğraf "≤ 200 KB" ile ≤ 200 KB çıkar (uçtan uca)',
        () async {
      final dir = Directory.systemTemp.createTempSync('fit_bytes');
      addTearDown(() => dir.deleteSync(recursive: true));
      final path = '${dir.path}/buyuk.jpg';
      File(path).writeAsBytesSync(img.encodeJpg(noisy(1000, 750), quality: 95));
      expect(File(path).lengthSync(), greaterThan(1000 * 1024));
      final r = await ImageResizer.run(
          path,
          const MediaResizeOptions(
              resolution: ResolutionChoice.fileSize, targetKb: 200));
      expect(r.afterBytes, lessThanOrEqualTo(200 * 1024));
      expect(r.outputPath, endsWith('_200kb.jpg'));
      expect(File(path).existsSync(), isTrue, reason: 'özgün korunur');
    });

    test('dosya boyutu kipi her zaman JPEG yazar', () {
      expect(
          ImageResizer.outputExtension('/a/foto.png',
              const MediaResizeOptions(resolution: ResolutionChoice.fileSize)),
          'jpg');
      expect(
          ImageResizer.outputExtension('/a/foto.png',
              const MediaResizeOptions(resolution: ResolutionChoice.percent)),
          'png');
    });
  });

  group('kayıt / ad', () {
    test('ESKİ iş tarifi (iki ölçü, kilit alanı yok) esnetmeye göç eder', () {
      final o = MediaResizeOptions.fromJson({
        'resolution': 'custom',
        'customWidth': 800,
        'customHeight': 800,
      });
      expect(o.lockAspect, isFalse);
      expect(o.fit, ResizeFit.stretch);
      expect(photo(1920, 1080, o), (width: 800, height: 800));
    });

    test('yeni alanlar gidip gelir', () {
      const o = MediaResizeOptions(
        resolution: ResolutionChoice.aspect,
        aspectW: 4,
        aspectH: 5,
        fit: ResizeFit.pad,
        padColor: PadColor.blur,
        longEdgePx: 2048,
        targetKb: 500,
        lockAspect: false,
      );
      final back = MediaResizeOptions.fromJson(o.toJson());
      expect(back.signature, o.signature);
      expect(back.aspectLabel, '4:5');
    });

    test('dosya adı ekleri', () {
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.longEdge, longEdgePx: 1600)
              .suffix,
          '1600px');
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.fileSize, targetKb: 200)
              .suffix,
          '200kb');
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.fileSize, targetKb: 1024)
              .suffix,
          '1mb');
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.aspect, aspectW: 16, aspectH: 9)
              .suffix,
          '16-9');
    });

    test('tahmin: dosya boyutu kipi hedefin kendisi', () {
      const info = MediaSourceInfo(
          name: 'a.jpg', sizeBytes: 3000000, isVideo: false,
          width: 4000, height: 3000);
      expect(
          info.estimatedBytes(const MediaResizeOptions(
              resolution: ResolutionChoice.fileSize, targetKb: 200)),
          200 * 1024);
    });
  });
}

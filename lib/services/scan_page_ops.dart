import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/image_decode.dart';
import 'perspective.dart' show solveHomography;
import 'scan_enhance.dart' show ScanEnhance;

/// İzolata geçen istek (tek argüman kuralı). Köşeler düz sayı listesi:
/// `[x0, y0, x1, y1, x2, y2, x3, y3]` (sol-üst, sağ-üst, sağ-alt, sol-alt).
class ScanPageOpRequest {
  final String sourcePath;
  final String targetPath;
  final int quarterTurns;
  final List<double>? quad;

  const ScanPageOpRequest({
    required this.sourcePath,
    required this.targetPath,
    this.quarterTurns = 0,
    this.quad,
  });
}

/// Tarama sayfasının **geometri** işleri: döndürme ve köşe kırpma
/// (perspektif açma). Saf Dart, izolatta koşar, çıktı **JPEG**.
///
/// ## Niye ayrı (2026-10-18, tarama akışı baştan)
/// Eski köşe ekranı ve döndürme GPU'da çizip **PNG** yazıyordu. PNG kayıpsız
/// ama PDF'e sıkıştırılmadan (ham RGB + Flate) giriyor: kırpılmış ya da
/// döndürülmüş tek bir sayfa PDF'i 10-20 MB şişiriyordu. Burada görsel bir
/// kez çözülür, bir kez [ScanEnhance.jpegQuality] ile kodlanır; PDF'e JPEG
/// olduğu gibi (DCT) girer. Saf Dart olduğu için birim testlenir de.
abstract final class ScanPageOps {
  /// İşlenecek kaynağın uzun kenar sınırı (piksel).
  static const maxSourceEdge = 4096;

  /// Görseli 90°'nin katları kadar SAAT YÖNÜNDE döndürür (kayıpsız eşleme;
  /// yalnız JPEG yeniden kodlanır).
  static Future<String> rotate(String path, int quarterTurns) async {
    final target = await _target(path, 'donduruldu');
    return compute(
      runRequest,
      ScanPageOpRequest(
          sourcePath: path, targetPath: target, quarterTurns: quarterTurns),
    );
  }

  /// [corners] dörtgenini (görsel pikseli, sol-üst/sağ-üst/sağ-alt/sol-alt)
  /// düz dikdörtgene açar.
  static Future<String> warp(String path, List<Offset> corners) async {
    final target = await _target(path, 'kirpildi');
    return compute(
      runRequest,
      ScanPageOpRequest(
        sourcePath: path,
        targetPath: target,
        quad: [for (final c in corners) ...[c.dx, c.dy]],
      ),
    );
  }

  /// Galeriden içe aktarılan görseli normalize eder: EXIF yönünü piksellere
  /// pişirir, `maxSourceEdge` üstündeyse küçültür ve JPEG olmayan biçimleri
  /// (HEIC/WebP/PNG) JPEG'e çevirir. Böylece yan dönmüş veya PDF paketinin
  /// çözemediği (HEIC) kırık sayfa oluşmaz.
  static Future<String> normalize(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) return path;
      final target = await _target(path, 'duzeltildi');
      final res = await compute(_normalizeSync, (source: path, target: target));
      if (res != null) return res;
      // Saf Dart `image` paketi çözemediyse (ör. HEIC/HEIF), platformun
      // yerel çözücüsüyle açıp JPEG'e çevir.
      return await _normalizeViaPlatformCodec(path, target) ?? path;
    } catch (_) {
      return path;
    }
  }

  /// Birden çok görseli sırayla normalize eder (aynı anda tek büyük görsel).
  static Future<List<String>> normalizeAll(List<String> paths) async {
    final out = <String>[];
    for (final path in paths) {
      out.add(await normalize(path));
    }
    return out;
  }

  static String? _normalizeSync(({String source, String target}) req) {
    final bytes = File(req.source).readAsBytesSync();
    img.Image? raw;
    try {
      raw = decodeCommonImage(bytes);
    } catch (_) {
      raw = null;
    }
    if (raw == null) return null;
    final hasExifTurn = raw.exif.imageIfd.hasOrientation &&
        raw.exif.imageIfd.orientation != null &&
        raw.exif.imageIfd.orientation != 1;
    final ext = p.extension(req.source).toLowerCase();
    final isJpeg = ext == '.jpg' || ext == '.jpeg';
    final long = math.max(raw.width, raw.height);
    if (isJpeg && !hasExifTurn && long <= maxSourceEdge) {
      return req.source;
    }
    var image = hasExifTurn ? img.bakeOrientation(raw) : raw;
    final bakedLong = math.max(image.width, image.height);
    if (bakedLong > maxSourceEdge) {
      final ratio = maxSourceEdge / bakedLong;
      image = img.copyResize(
        image,
        width: (image.width * ratio).round(),
        height: (image.height * ratio).round(),
        interpolation: img.Interpolation.average,
      );
    }
    File(req.target).writeAsBytesSync(
        img.encodeJpg(image, quality: ScanEnhance.jpegQuality),
        flush: true);
    return req.target;
  }

  static Future<String?> _normalizeViaPlatformCodec(
      String source, String target) async {
    ui.ImmutableBuffer? buffer;
    ui.ImageDescriptor? descriptor;
    ui.Codec? codec;
    ui.Image? uiImage;
    try {
      buffer = await ui.ImmutableBuffer.fromFilePath(source);
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final w = descriptor.width;
      final h = descriptor.height;
      final long = math.max(w, h);
      final ratio = long > maxSourceEdge ? maxSourceEdge / long : 1.0;
      codec = await descriptor.instantiateCodec(
        targetWidth: (w * ratio).round(),
        targetHeight: (h * ratio).round(),
      );
      uiImage = (await codec.getNextFrame()).image;
      final rgba =
          await uiImage.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (rgba == null) return null;
      final outW = uiImage.width, outH = uiImage.height;
      final transferable =
          TransferableTypedData.fromList([rgba.buffer.asUint8List()]);
      await Isolate.run(() {
        final raw = transferable.materialize().asUint8List();
        final image = img.Image.fromBytes(
          width: outW,
          height: outH,
          bytes: raw.buffer,
          bytesOffset: raw.offsetInBytes,
          numChannels: 4,
          order: img.ChannelOrder.rgba,
        );
        File(target).writeAsBytesSync(
            img.encodeJpg(image, quality: ScanEnhance.jpegQuality),
            flush: true);
      });
      return target;
    } catch (_) {
      return null;
    } finally {
      uiImage?.dispose();
      codec?.dispose();
      descriptor?.dispose();
      buffer?.dispose();
    }
  }

  /// İzolat girişi: isteği uygular, hedef yolu döner.
  static String runRequest(ScanPageOpRequest request) {
    final decoded = decode(File(request.sourcePath).readAsBytesSync());
    if (decoded == null) {
      throw const FormatException('Görsel çözülemedi');
    }
    var image = decoded;
    var quad = request.quad;
    // Dev kaynak (50 MP telefon fotoğrafı) önce küçültülür: tam çözünürlükte
    // çözülmüş görsel + çıktı izolatın belleğini taşırabiliyordu. Sınır A4'ün
    // 300 dpi'ının çok üstünde — belgede hiçbir ayrıntı kaybolmaz.
    final long = math.max(image.width, image.height);
    if (long > maxSourceEdge) {
      final ratio = maxSourceEdge / long;
      image = img.copyResize(image,
          width: (image.width * ratio).round(),
          height: (image.height * ratio).round(),
          interpolation: img.Interpolation.average);
      if (quad != null) quad = [for (final v in quad) v * ratio];
    }
    if (quad != null && quad.length == 8) {
      image = warpImage(image, [
        for (var i = 0; i < 8; i += 2) Offset(quad[i], quad[i + 1]),
      ]);
    }
    final turns = request.quarterTurns % 4;
    if (turns != 0) image = img.copyRotate(image, angle: turns * 90);
    File(request.targetPath).writeAsBytesSync(
        img.encodeJpg(image, quality: ScanEnhance.jpegQuality),
        flush: true);
    return request.targetPath;
  }

  /// Çözer ve EXIF yönünü piksele işler — ekrandaki köşeler (Flutter yönü
  /// uygulanmış görseli gösterir) bu koordinatlarla örtüşsün diye.
  static img.Image? decode(Uint8List bytes) {
    img.Image? image;
    try {
      image = decodeCommonImage(bytes);
    } catch (_) {
      return null;
    }
    if (image == null) return null;
    if (image.exif.imageIfd.hasOrientation &&
        image.exif.imageIfd.orientation != 1) {
      image = img.bakeOrientation(image);
    }
    return image;
  }

  /// Perspektif açma: hedefin her pikseli için kaynaktaki yer homografiyle
  /// bulunur, çift doğrusal örneklenir. Hedef boyut karşılıklı kenarların
  /// ortalaması (belge ne uzar ne sıkışır).
  ///
  /// Satır içi artımlı projektif adımlama (`nx += dnx`, `ny += dny`,
  /// `nw += dnw`): iç döngüde milyonlarca `Offset` nesnesi ayırmaz.
  static img.Image warpImage(img.Image source, List<Offset> corners) {
    double len(Offset a, Offset b) => (a - b).distance;
    final width =
        ((len(corners[0], corners[1]) + len(corners[3], corners[2])) / 2)
            .round()
            .clamp(16, 8000);
    final height =
        ((len(corners[0], corners[3]) + len(corners[1], corners[2])) / 2)
            .round()
            .clamp(16, 8000);
    final h = solveHomography(
      const [Offset(0, 0), Offset(1, 0), Offset(1, 1), Offset(0, 1)],
      corners,
    );
    final h0 = h[0], h1 = h[1], h2 = h[2];
    final h3 = h[3], h4 = h[4], h5 = h[5];
    final h6 = h[6], h7 = h[7];
    final invW = 1.0 / width;
    final invH = 1.0 / height;
    final u0 = 0.5 * invW;
    final dnx = h0 * invW;
    final dny = h3 * invW;
    final dnw = h6 * invW;

    final sw = source.width, sh = source.height;
    final swMax = sw - 1.0, shMax = sh - 1.0;
    final swLast = sw - 1, shLast = sh - 1;
    final src = source.getBytes(order: img.ChannelOrder.rgb);
    final out = img.Image(width: width, height: height, numChannels: 3);
    final dst = out.getBytes(order: img.ChannelOrder.rgb);
    var o = 0;
    for (var y = 0; y < height; y++) {
      final v = (y + 0.5) * invH;
      var nx = h0 * u0 + h1 * v + h2;
      var ny = h3 * u0 + h4 * v + h5;
      var nw = h6 * u0 + h7 * v + 1.0;
      for (var x = 0; x < width; x++) {
        final d = nw.abs() < 1e-12 ? 1e-12 : nw;
        final invD = 1.0 / d;
        var sx = nx * invD - 0.5;
        if (sx < 0.0) {
          sx = 0.0;
        } else if (sx > swMax) {
          sx = swMax;
        }
        var sy = ny * invD - 0.5;
        if (sy < 0.0) {
          sy = 0.0;
        } else if (sy > shMax) {
          sy = shMax;
        }
        final x0 = sx.floor(), y0 = sy.floor();
        final x1 = x0 < swLast ? x0 + 1 : swLast;
        final y1 = y0 < shLast ? y0 + 1 : shLast;
        final fx = sx - x0, fy = sy - y0;
        final row0 = y0 * sw, row1 = y1 * sw;
        final p00 = (row0 + x0) * 3, p10 = (row0 + x1) * 3;
        final p01 = (row1 + x0) * 3, p11 = (row1 + x1) * 3;

        final top0 = src[p00] + (src[p10] - src[p00]) * fx;
        final bot0 = src[p01] + (src[p11] - src[p01]) * fx;
        final r = (top0 + (bot0 - top0) * fy).round();
        dst[o] = r < 0 ? 0 : (r > 255 ? 255 : r);

        final top1 = src[p00 + 1] + (src[p10 + 1] - src[p00 + 1]) * fx;
        final bot1 = src[p01 + 1] + (src[p11 + 1] - src[p01 + 1]) * fx;
        final g = (top1 + (bot1 - top1) * fy).round();
        dst[o + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);

        final top2 = src[p00 + 2] + (src[p10 + 2] - src[p00 + 2]) * fx;
        final bot2 = src[p01 + 2] + (src[p11 + 2] - src[p01 + 2]) * fx;
        final b = (top2 + (bot2 - top2) * fy).round();
        dst[o + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);

        o += 3;
        nx += dnx;
        ny += dny;
        nw += dnw;
      }
    }
    return out;
  }

  /// Benzersiz geçici hedef (aynı yola yazmak Flutter'ın görsel önbelleğini
  /// eski kareyle bırakırdı).
  static Future<String> _target(String source, String suffix) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(dir.path, '${shortBase(source)}_${suffix}_$stamp.jpg');
  }

  /// Geçici dosya adının kökü — en çok 24 karakter. Her düzenleme adı
  /// uzatıyordu (`sayfa_kirpildi_…_donduruldu_…_auto_…`); art arda yapılan
  /// düzenlemelerde ad 255 karakter sınırına dayanıp yazma hata verirdi.
  static String shortBase(String path) {
    final base = p.basenameWithoutExtension(path);
    return base.length <= 24 ? base : base.substring(0, 24);
  }
}

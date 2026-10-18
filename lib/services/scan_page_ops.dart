import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'perspective.dart' show applyHomography, solveHomography;
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
      image = img.decodeImage(bytes);
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
  static img.Image warpImage(img.Image source, List<Offset> corners) {
    double len(Offset a, Offset b) => (a - b).distance;
    final width = ((len(corners[0], corners[1]) + len(corners[3], corners[2])) / 2)
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
    final sw = source.width, sh = source.height;
    final src = source.getBytes(order: img.ChannelOrder.rgb);
    final out = img.Image(width: width, height: height, numChannels: 3);
    final dst = out.getBytes(order: img.ChannelOrder.rgb);
    for (var y = 0; y < height; y++) {
      final v = (y + 0.5) / height;
      for (var x = 0; x < width; x++) {
        final at = applyHomography(h, Offset((x + 0.5) / width, v));
        final sx = (at.dx - 0.5).clamp(0.0, sw - 1.0);
        final sy = (at.dy - 0.5).clamp(0.0, sh - 1.0);
        final x0 = sx.floor(), y0 = sy.floor();
        final x1 = math.min(x0 + 1, sw - 1), y1 = math.min(y0 + 1, sh - 1);
        final fx = sx - x0, fy = sy - y0;
        final o = (y * width + x) * 3;
        final p00 = (y0 * sw + x0) * 3, p10 = (y0 * sw + x1) * 3;
        final p01 = (y1 * sw + x0) * 3, p11 = (y1 * sw + x1) * 3;
        for (var c = 0; c < 3; c++) {
          final top = src[p00 + c] + (src[p10 + c] - src[p00 + c]) * fx;
          final bottom = src[p01 + c] + (src[p11 + c] - src[p01 + c]) * fx;
          dst[o + c] = (top + (bottom - top) * fy).round().clamp(0, 255);
        }
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

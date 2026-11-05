import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'scan_page_ops.dart';

/// Tek sayfanın kalite ölçümü (Faz 35 / madde 5).
class ScanQualityReport {
  /// Laplace varyansı (küçültülmüş gri kopyada) — düşük = bulanık.
  final double sharpness;

  /// Ortalama parlaklık 0–255 — düşük = karanlık çekim.
  final double brightness;

  /// Tahmini eğiklik (derece, + saat yönü).
  final double skew;

  const ScanQualityReport({
    required this.sharpness,
    required this.brightness,
    required this.skew,
  });

  static const blurLimit = 45.0;
  static const darkLimit = 85.0;
  static const skewLimit = 2.0;

  bool get blurry => sharpness < blurLimit;
  bool get dark => brightness < darkLimit;
  bool get skewed => skew.abs() >= skewLimit;

  /// Kullanıcıya gösterilecek TEK öneri (öncelik: bulanık > karanlık > eğik).
  String? get hint => blurry
      ? 'blurry'
      : dark
          ? 'dark'
          : skewed
              ? 'skewed'
              : null;
}

/// **Kalite metrikleri**: keskinlik, ışık, eğiklik → "yeniden çek" /
/// "feneri aç" / "düzleştir" önerisi. Ölçüm küçültülmüş (uzun kenar
/// [sampleEdge]) gri kopyada, izolatta; tam görsel bellekte tutulmaz.
abstract final class ScanQualityCheck {
  static const sampleEdge = 640;

  static Future<ScanQualityReport?> measure(String path) =>
      compute(measureFile, path);

  static ScanQualityReport? measureFile(String path) {
    try {
      final image = ScanPageOps.decode(File(path).readAsBytesSync());
      if (image == null) return null;
      return measureImage(image);
    } catch (_) {
      return null;
    }
  }

  static ScanQualityReport measureImage(img.Image source) {
    var image = source;
    final long = math.max(image.width, image.height);
    if (long > sampleEdge) {
      final r = sampleEdge / long;
      image = img.copyResize(image,
          width: math.max(1, (image.width * r).round()),
          height: math.max(1, (image.height * r).round()),
          interpolation: img.Interpolation.average);
    }
    final w = image.width, h = image.height;
    final rgb = image.getBytes(order: img.ChannelOrder.rgb);
    final gray = Uint8List(w * h);
    var sum = 0;
    for (var i = 0, j = 0; i < gray.length; i++, j += 3) {
      final v = (rgb[j] * 299 + rgb[j + 1] * 587 + rgb[j + 2] * 114) ~/ 1000;
      gray[i] = v;
      sum += v;
    }
    return ScanQualityReport(
      sharpness: laplacianVariance(gray, w, h),
      brightness: gray.isEmpty ? 0 : sum / gray.length,
      skew: estimateSkew(gray, w, h),
    );
  }

  /// Laplace (4-komşu) yanıtının varyansı.
  static double laplacianVariance(Uint8List g, int w, int h) {
    if (w < 3 || h < 3) return 0;
    var n = 0;
    var mean = 0.0, m2 = 0.0;
    for (var y = 1; y < h - 1; y++) {
      for (var x = 1; x < w - 1; x++) {
        final i = y * w + x;
        final v = (4 * g[i] - g[i - 1] - g[i + 1] - g[i - w] - g[i + w])
            .toDouble();
        n++;
        final d = v - mean;
        mean += d / n;
        m2 += d * (v - mean);
      }
    }
    return n < 2 ? 0 : m2 / (n - 1);
  }

  /// İzdüşüm profili: koyu pikseller [-maxDeg, maxDeg] açılarla kaydırılıp
  /// satır histogramı çıkarılır; metin satırları hizalandığında histogram
  /// varyansı en yüksek olur. Az mürekkepli sayfada 0 döner.
  static double estimateSkew(Uint8List g, int w, int h,
      {double maxDeg = 6, double stepDeg = 0.5}) {
    if (w < 16 || h < 16) return 0;
    // Uyarlamasız basit eşik: ortalamanın %75'inin altı "mürekkep".
    var total = 0;
    for (final v in g) {
      total += v;
    }
    final limit = total / g.length * 0.75;
    final xs = <int>[], ys = <int>[];
    for (var y = 0; y < h; y += 1) {
      for (var x = 0; x < w; x += 2) {
        if (g[y * w + x] < limit) {
          xs.add(x);
          ys.add(y);
        }
      }
    }
    if (xs.length < 200 || xs.length > g.length ~/ 3) return 0;
    var bestAngle = 0.0;
    var bestScore = -1.0;
    final bins = Float64List(h * 2);
    // 0'dan dışa doğru: eşitlikte (düz/boş sayfa) küçük açı kazanır.
    final angles = <double>[0];
    for (var a = stepDeg; a <= maxDeg + 1e-9; a += stepDeg) {
      angles..add(a)..add(-a);
    }
    for (final a in angles) {
      final t = math.tan(a * math.pi / 180);
      bins.fillRange(0, bins.length, 0);
      for (var k = 0; k < xs.length; k++) {
        final row = (ys[k] - xs[k] * t).round() + h ~/ 2;
        if (row >= 0 && row < bins.length) bins[row] += 1;
      }
      var s = 0.0;
      for (final b in bins) {
        s += b * b;
      }
      if (bestScore < 0 || s > bestScore * 1.01) {
        bestScore = s;
        bestAngle = a;
      }
    }
    return bestAngle;
  }
}

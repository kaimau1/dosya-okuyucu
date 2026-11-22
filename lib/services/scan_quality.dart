import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show compute;
import 'package:image/image.dart' as img;

import 'gemini_decisions.dart';
import 'scan_dewarp.dart' show ScanDewarp;
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

  static Future<ScanQualityReport?> measure(String path,
          {double? knownSkew}) =>
      compute(_measureRequest, (path: path, knownSkew: knownSkew));

  static ScanQualityReport? _measureRequest(
          ({String path, double? knownSkew}) req) =>
      measureFile(req.path, knownSkew: req.knownSkew);

  static ScanQualityReport? measureFile(String path, {double? knownSkew}) {
    try {
      final image = ScanPageOps.decode(File(path).readAsBytesSync());
      if (image == null) return null;
      return measureImage(image, knownSkew: knownSkew);
    } catch (_) {
      return null;
    }
  }

  static ScanQualityReport measureImage(img.Image source,
      {double? knownSkew}) {
    // Eğim, Düzleştir düğmesinin boru hattıyla ölçülür (aksi hâlde uyarı
    // "eğik" deyip düğme "zaten düz" diyebiliyordu — 2026-11-10).
    // Aynı kaynağın filtreli kopyalarında [knownSkew] geçirilir; eğim
    // yeniden hesaplanmaz.
    final skew = knownSkew ?? ScanDewarp.measureSkew(source);
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
      skew: skew,
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
}

/// **AI ile kalite kontrolü** (B2 dilim 4, PLAN §1.2 Decisions kullanımları):
/// yerel ölçüm (keskinlik/ışık/eğim) parlamayı, kadraj dışı kalan kenarı ve
/// okunaksız yazıyı göremez. Görünen sayfanın küçük önizlemesi Decisions'a
/// üç evet/hayır sorusuyla gider; sorun varsa "Yeniden çek" önerilir.
abstract final class ScanAiQuality {
  /// Bu olasılığın üstü "sorun var" sayılır (yanlış uyarı az olsun).
  static const threshold = 0.6;

  static const questions = [
    DecisionQuestion.yesNo('legible', 'Legible?',
        'Is the text on this scanned document page clearly legible?'),
    DecisionQuestion.yesNo(
        'glare',
        'Glare?',
        'Does glare, a reflection or a strong shadow hide part of the text '
            'on this document page?'),
    DecisionQuestion.yesNo('cut', 'Cut off?',
        'Is part of the document page cut off at the edges of the photo?'),
  ];

  /// Yanıtlardan TEK öneri (öncelik: parlama > kesik > okunaksız); sorun
  /// yoksa null. Gelmeyen soru "sorun yok" sayılır.
  static String? hintFrom(List<DecisionAnswer> answers) {
    double? p(String id) =>
        answers.where((a) => a.question.id == id).firstOrNull?.yes;
    if ((p('glare') ?? 0) >= threshold) return 'ai_glare';
    if ((p('cut') ?? 0) >= threshold) return 'ai_cut';
    final legible = p('legible');
    if (legible != null && legible < 1 - threshold) return 'ai_illegible';
    return null;
  }
}

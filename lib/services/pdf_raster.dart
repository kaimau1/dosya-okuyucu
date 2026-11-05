/// **PDF sayfa → görüntü** (pdfium/pdfrx) — Faz 39 ortak katmanı: kalıcı
/// karartma, agresif sıkıştırma, görsel karşılaştırma, boş sayfa algılama ve
/// PDF→görsel toplu dışa aktarma hep buradan çizer.
///
/// Anayasa: çizim pdfium izleğinde, piksel işleme + JPEG kodlama izolatta
/// (k.1); boyut `PerfBudget.pdfRasterMaxPx` ile kenetli (k.3/k.4); sayfalar
/// TEK TEK çizilir ve hemen bırakılır — 500 sayfalık belgede bellekte en çok
/// bir sayfa bitmap'i durur.
library;

import 'dart:isolate';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as imglib;
import 'package:pdfrx/pdfrx.dart';

import '../core/app_colors.dart';
import '../core/device_profile.dart';

/// Çizilmiş bir sayfa: JPEG + piksel ve punto ölçüleri (görünen yönde).
class RasterPage {
  final int index;
  final Uint8List jpeg;
  final int widthPx;
  final int heightPx;
  final double widthPt;
  final double heightPt;

  const RasterPage({
    required this.index,
    required this.jpeg,
    required this.widthPx,
    required this.heightPx,
    required this.widthPt,
    required this.heightPt,
  });
}

/// Gri tonlu küçük çizim (karşılaştırma/boş sayfa için).
class GrayPage {
  final int width;
  final int height;

  /// Satır satır parlaklık 0..255.
  final Uint8List luma;
  const GrayPage(this.width, this.height, this.luma);
}

abstract final class PdfRaster {
  /// [pages] sayfalarını JPEG'e çizer. [blackout] sayfa → görünen sayfa
  /// koordinatında (sol-üst, pt) dikdörtgenler: pikseller SİYAHA boyanır
  /// (karartma). [dpi] istenen çözünürlük; uzun kenar bütçeyi aşmaz.
  static Future<List<RasterPage>> renderJpegs(
    List<int> bytes,
    List<int> pages, {
    String? password,
    double dpi = 150,
    int quality = 80,
    bool grayscale = false,
    Map<int, List<ui.Rect>> blackout = const {},
    void Function(int done, int total)? onProgress,
  }) async {
    final doc = await PdfDocument.openData(
      Uint8List.fromList(bytes),
      passwordProvider: password == null ? null : () async => password,
    );
    final maxPx = DeviceProfile.budget.pdfRasterMaxPx;
    final out = <RasterPage>[];
    try {
      for (var n = 0; n < pages.length; n++) {
        final index = pages[n];
        final page = doc.pages[index];
        var scale = dpi / 72;
        final longest = (page.width > page.height ? page.width : page.height);
        if (longest * scale > maxPx) scale = maxPx / longest;
        final img = await page.render(
          fullWidth: page.width * scale,
          fullHeight: page.height * scale,
          backgroundColor: AppColors.page,
        );
        if (img == null) throw StateError('Sayfa ${index + 1} çizilemedi');
        final w = img.width, h = img.height;
        final bgra = img.format == ui.PixelFormat.bgra8888;
        final TransferableTypedData pixels;
        try {
          pixels = TransferableTypedData.fromList([img.pixels]);
        } finally {
          img.dispose();
        }
        final rects = [
          for (final r in blackout[index] ?? const <ui.Rect>[])
            [r.left * scale, r.top * scale, r.right * scale, r.bottom * scale],
        ];
        final jpeg = await Isolate.run(() => encodeJpeg(
              pixels.materialize().asUint8List(),
              w,
              h,
              bgraOrder: bgra,
              quality: quality,
              grayscale: grayscale,
              blackout: rects,
            ));
        out.add(RasterPage(
          index: index,
          jpeg: jpeg,
          widthPx: w,
          heightPx: h,
          widthPt: page.width,
          heightPt: page.height,
        ));
        onProgress?.call(n + 1, pages.length);
      }
    } finally {
      await doc.dispose();
    }
    return out;
  }

  /// Sayfaları [widthPx] genişlikte gri tonlu çizer (karşılaştırma, boş
  /// sayfa). [pages] `null` → tümü.
  static Future<List<GrayPage>> renderGray(
    List<int> bytes, {
    List<int>? pages,
    String? password,
    int? widthPx,
  }) async {
    final doc = await PdfDocument.openData(
      Uint8List.fromList(bytes),
      passwordProvider: password == null ? null : () async => password,
    );
    final width = widthPx ?? DeviceProfile.budget.pdfCompareWidthPx;
    final out = <GrayPage>[];
    try {
      for (final index in pages ?? List<int>.generate(doc.pages.length, (i) => i)) {
        final page = doc.pages[index];
        final scale = width / page.width;
        final img = await page.render(
          fullWidth: width.toDouble(),
          fullHeight: page.height * scale,
          backgroundColor: AppColors.page,
        );
        if (img == null) throw StateError('Sayfa ${index + 1} çizilemedi');
        final w = img.width, h = img.height;
        final bgra = img.format == ui.PixelFormat.bgra8888;
        final TransferableTypedData pixels;
        try {
          pixels = TransferableTypedData.fromList([img.pixels]);
        } finally {
          img.dispose();
        }
        final luma = await Isolate.run(
            () => toLuma(pixels.materialize().asUint8List(), w, h, bgraOrder: bgra));
        out.add(GrayPage(w, h, luma));
      }
    } finally {
      await doc.dispose();
    }
    return out;
  }

  /// Saf: 4 kanallı pikseller → parlaklık.
  static Uint8List toLuma(Uint8List px, int w, int h, {required bool bgraOrder}) {
    final out = Uint8List(w * h);
    final ri = bgraOrder ? 2 : 0, bi = bgraOrder ? 0 : 2;
    for (var i = 0, j = 0; i < out.length; i++, j += 4) {
      out[i] = (px[j + ri] * 77 + px[j + 1] * 150 + px[j + bi] * 29) >> 8;
    }
    return out;
  }

  /// Saf: pikseller → JPEG; [blackout] piksel dikdörtgenleri `[l,t,r,b]`
  /// tamamen siyaha boyanır (piksel verisi YOK EDİLİR, üst katman değil).
  static Uint8List encodeJpeg(
    Uint8List px,
    int w,
    int h, {
    required bool bgraOrder,
    int quality = 80,
    bool grayscale = false,
    List<List<double>> blackout = const [],
  }) {
    var image = imglib.Image.fromBytes(
      width: w,
      height: h,
      bytes: px.buffer,
      bytesOffset: px.offsetInBytes,
      numChannels: 4,
      order: bgraOrder ? imglib.ChannelOrder.bgra : imglib.ChannelOrder.rgba,
    );
    // Saydamlık JPEG'de anlamsız; 3 kanala in (dosya küçülür).
    image = image.convert(numChannels: 3);
    for (final r in blackout) {
      final int x1 = r[0].floor().clamp(0, w).toInt();
      final int y1 = r[1].floor().clamp(0, h).toInt();
      final int x2 = r[2].ceil().clamp(0, w).toInt();
      final int y2 = r[3].ceil().clamp(0, h).toInt();
      if (x2 <= x1 || y2 <= y1) continue;
      imglib.fillRect(image,
          x1: x1, y1: y1, x2: x2 - 1, y2: y2 - 1, color: imglib.ColorRgb8(0, 0, 0));
    }
    if (grayscale) image = imglib.grayscale(image);
    return imglib.encodeJpg(image, quality: quality);
  }
}

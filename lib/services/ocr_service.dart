import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfrx/pdfrx.dart';

/// Cihaz-içi OCR (Google ML Kit, Latin alfabesi — Türkçe karakterler dahil).
///
/// İnternet gerekmez; model APK ile gelir. Görsel dosyalardan ve taranmış
/// (metin katmanı olmayan) PDF'lerden metin çıkarır. PDF sayfaları pdfium ile
/// bitmap'e çizilir, geçici PNG üzerinden ML Kit'e verilir.
class OcrService {
  /// Tek OCR turunda işlenecek en fazla PDF sayfası (süre/pil koruması).
  static const maxPdfPages = 25;

  /// Bir görsel dosyadan metin tanır. Metin yoksa boş dize döner.
  static Future<String> recognizeImageFile(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final result =
          await recognizer.processImage(InputImage.fromFilePath(path));
      return result.text.trim();
    } finally {
      await recognizer.close();
    }
  }

  /// Açık bir PDF belgesinin sayfalarını (en çok [maxPdfPages]) OCR'lar.
  /// [onProgress] her sayfa öncesi (işlenen, toplam) ile çağrılır.
  static Future<String> recognizePdf(
    PdfDocument document, {
    void Function(int done, int total)? onProgress,
  }) async {
    final pages = document.pages;
    final total = pages.length > maxPdfPages ? maxPdfPages : pages.length;
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final sb = StringBuffer();
    try {
      for (var i = 0; i < total; i++) {
        onProgress?.call(i, total);
        final path = await _renderPageToPng(pages[i], i);
        if (path == null) continue;
        try {
          final result =
              await recognizer.processImage(InputImage.fromFilePath(path));
          final text = result.text.trim();
          if (text.isNotEmpty) {
            if (total > 1) sb.writeln('— Sayfa ${i + 1} —');
            sb.writeln(text);
            sb.writeln();
          }
        } finally {
          try {
            File(path).deleteSync();
          } catch (_) {}
        }
      }
      onProgress?.call(total, total);
      return sb.toString().trim();
    } finally {
      await recognizer.close();
    }
  }

  /// Sayfayı ~1600px genişlikte PNG'ye çizer (OCR için yeterli çözünürlük).
  static Future<String?> _renderPageToPng(PdfPage page, int index) async {
    final scale = (1600 / page.width).clamp(1.0, 4.0);
    final img = await page.render(
      fullWidth: page.width * scale,
      fullHeight: page.height * scale,
      backgroundColor: const ui.Color(0xFFFFFFFF),
    );
    if (img == null) return null;
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        img.pixels,
        img.width,
        img.height,
        img.format,
        completer.complete,
      );
      final uiImage = await completer.future;
      final png = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      uiImage.dispose();
      if (png == null) return null;
      final f = File(
          '${Directory.systemTemp.path}/ocr_page_${index}_${page.pageNumber}.png');
      await f.writeAsBytes(png.buffer.asUint8List());
      return f.path;
    } finally {
      img.dispose();
    }
  }
}

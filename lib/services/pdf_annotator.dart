import 'dart:ui' show Rect;

import 'package:pdfrx/pdfrx.dart' show PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// PDF'e **kalıcı vurgu (highlight) annotation** yazan Syncfusion yardımcısı.
///
/// Mimari (bkz. HAFIZA 2026-07-23 Syncfusion kararı): görüntüleme pdfrx/pdfium'da
/// KALIR (yüksek sadakat); burada yalnız düzenlenmiş PDF baytı ÜRETİLİR
/// (annotate → yeni bayt → dosyaya yaz → pdfrx'te yeniden aç). İki PDF yığını
/// bilinçli yan yana. pdfrx salt-render olduğu için yazma tek yol Syncfusion.
class PdfAnnotator {
  const PdfAnnotator._();

  /// [bytes] PDF'inin [pageIndex] (0-tabanlı) sayfasına, [pdfRects] (pdfium PDF
  /// koordinatı — satır/parça başına bir dikdörtgen, `PdfSelectLayer`'dan gelir)
  /// alanlarını kaplayan tek bir highlight annotation ekler; yeni PDF baytlarını
  /// döndürür. [colorArgb] = Flutter renk değeri (0xAARRGGBB); alfa yok sayılır.
  ///
  /// Seçim boşsa dosya değiştirilmeden aynı baytlar döner.
  static Future<List<int>> addHighlight({
    required List<int> bytes,
    required int pageIndex,
    required List<PdfRect> pdfRects,
    required int colorArgb,
  }) async {
    if (pdfRects.isEmpty) return bytes;
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final pageHeight = page.size.height;
      final rects = <Rect>[
        for (final r in pdfRects)
          pdfToSyncfusionRect(
            left: r.left,
            pdfTop: r.top,
            width: r.width,
            height: r.height,
            pageHeight: pageHeight,
          ),
      ];
      // Tüm satırları kapsayan sınır kutusu = annotation /Rect; satırlar quad'lar.
      var bounds = rects.first;
      for (final r in rects.skip(1)) {
        bounds = bounds.expandToInclude(r);
      }
      final annotation = PdfTextMarkupAnnotation(
        bounds,
        '',
        PdfColor(
          (colorArgb >> 16) & 0xFF,
          (colorArgb >> 8) & 0xFF,
          colorArgb & 0xFF,
        ),
        boundsCollection: rects,
      )..textMarkupAnnotationType = PdfTextMarkupAnnotationType.highlight;
      page.annotations.add(annotation);
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }
}

/// pdfium `PdfRect` (origin **sol-alt**, Y **yukarı** → `top` sayfa-alt'tan ölçülür,
/// `top > bottom`) → Syncfusion/Flutter `Rect` (origin **sol-üst**, Y **aşağı**).
///
/// KOORDİNAT TUZAĞI (bkz. KALANLAR PDF Faz 2): Syncfusion annotation sol-üst köşe
/// bekler; sayfa üstünden mesafe = `pageHeight - pdfTop`. Genişlik/yükseklik aynı.
///
/// ponytail: sayfa /Rotate=0 varsayar (çoğu PDF). Döndürülmüş sayfada pdfium ve
/// Syncfusion yükseklikleri ayrışabilir → gerekirse rotasyonu ayrıca ele al.
Rect pdfToSyncfusionRect({
  required double left,
  required double pdfTop,
  required double width,
  required double height,
  required double pageHeight,
}) =>
    Rect.fromLTWH(left, pageHeight - pdfTop, width, height);

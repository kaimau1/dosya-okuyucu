import 'dart:ui' show Rect;

import 'package:pdfrx/pdfrx.dart' show PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'pdf_tools.dart' show pdfToSyncfusionRect;

// `pdfToSyncfusionRect` artık `pdf_tools.dart`'ta: yerinde metin değiştirme de
// aynı çeviriyi kullanıyor, geometri yardımcıları orada toplu duruyor.
// Buradan yeniden dışa aktarılıyor ki mevcut çağıranlar/testler kırılmasın.
export 'pdf_tools.dart' show pdfToSyncfusionRect;

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


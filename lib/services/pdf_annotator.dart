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

  /// [pdfRects] alanlarına DEĞEN vurguları siler; yeni baytları ve silinen
  /// vurgu sayısını döndürür.
  ///
  /// Kullanıcı bulgusu (2026-08-29): *"vurgula gibi işlerde vurgu kaldır vb
  /// işlemler yok."* Vurgu eklenebiliyor ama kaldırılamıyordu: yanlış yeri
  /// vurgulayan kullanıcının tek çaresi dosyayı kaydetmeden çıkmaktı — o da
  /// aradaki tüm düzeltmeleri birlikte götürüyordu.
  ///
  /// **Yalnız METİN İŞARETLEME (highlight/altını çiz/üstünü çiz) annotation'ı
  /// silinir**; imza, form alanı, not gibi başka annotation türlerine
  /// dokunulmaz — kullanıcı "vurguyu kaldır" derken imzasının silinmesini
  /// beklemez.
  ///
  /// Kesişim testi: seçim satırının annotation'ın sınır kutusuyla ÖRTÜŞMESİ
  /// yeterli. Tam kapsama aranmaz; kullanıcı vurgulu metnin bir kelimesini
  /// seçip "kaldır" dediğinde o vurgunun tamamı gitmeli.
  static Future<(List<int>, int)> removeHighlights({
    required List<int> bytes,
    required int pageIndex,
    required List<PdfRect> pdfRects,
  }) async {
    if (pdfRects.isEmpty) return (bytes, 0);
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final pageHeight = page.size.height;
      final targets = <Rect>[
        for (final r in pdfRects)
          pdfToSyncfusionRect(
            left: r.left,
            pdfTop: r.top,
            width: r.width,
            height: r.height,
            pageHeight: pageHeight,
          ),
      ];
      // Sondan başa: silme sırasında dizin kayar, baştan gidilirse aradaki
      // annotation atlanır (klasik indeks tuzağı).
      var removed = 0;
      for (var i = page.annotations.count - 1; i >= 0; i--) {
        final annotation = page.annotations[i];
        // Belgeden OKUNAN vurgular da bu türle geliyor: koleksiyon
        // `/Subtype` Highlight/Underline/StrikeOut/Squiggly gördüğünde
        // `PdfTextMarkupAnnotation` üretiyor (paketin `_getAnnotation`
        // dağıtımı). Ayrı bir "loaded" sınıfı yok.
        if (annotation is! PdfTextMarkupAnnotation) continue;
        final bounds = annotation.bounds;
        if (targets.any((t) => t.overlaps(bounds))) {
          page.annotations.remove(annotation);
          removed++;
        }
      }
      if (removed == 0) return (bytes, 0);
      return (await doc.save(), removed);
    } finally {
      doc.dispose();
    }
  }
}


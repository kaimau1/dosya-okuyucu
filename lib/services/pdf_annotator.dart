import 'dart:isolate';
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
/// Belgeye yazılacak bir vurgu: sayfa (0 tabanlı), satır kutuları (pdfium
/// PDF koordinatı `[sol, üst, sağ, alt]` — isolate sınırından düz sayı
/// listesi olarak geçer) ve renk (0xAARRGGBB).
typedef PdfHighlightSpec = ({int pageIndex, List<List<double>> rects, int color});

class PdfAnnotator {
  const PdfAnnotator._();

  /// Vurgunun saydamlığı. 1 (eski değer) koyu renklerde metni boğuyordu —
  /// kullanıcının ekran görüntüsünde pembe vurgu "kavmim!" kelimesini kiremit
  /// rengi bir kutuya çevirmişti. Çarpımsal harmanla birlikte yarı saydam:
  /// her görüntüleyicide metin okunur kalır.
  static const double highlightOpacity = 0.55;

  /// Birden çok vurguyu TEK geçişte ve **ana izleğin dışında** yazar
  /// (2026-09-27).
  ///
  /// Eskiden her vurgu ana izlekte Syncfusion ile belgenin tamamını açıp
  /// kaydediyordu: 3239 sayfalık kitapta ekran saniyelerce donuyor, sonra
  /// belge baştan yükleniyordu ("PDF kapanıp açılıyor gibi"). Artık vurgular
  /// ekranda bekler ve kaydederken hepsi birlikte, izolatta yazılır.
  static Future<List<int>> addHighlightsInBackground(
      List<int> bytes, List<PdfHighlightSpec> marks) {
    if (marks.isEmpty) return Future.value(bytes);
    return Isolate.run(() => _addHighlightsSync(bytes, marks));
  }

  static Future<List<int>> _addHighlightsSync(
      List<int> bytes, List<PdfHighlightSpec> marks) async {
    final doc = PdfDocument(inputBytes: bytes);
    try {
      for (final m in marks) {
        if (m.rects.isEmpty ||
            m.pageIndex < 0 ||
            m.pageIndex >= doc.pages.count) {
          continue;
        }
        final page = doc.pages[m.pageIndex];
        _addTo(page, [
          for (final r in m.rects)
            pdfToSyncfusionRect(
              left: r[0],
              pdfTop: r[1],
              width: r[2] - r[0],
              height: r[1] - r[3],
              pageHeight: page.size.height,
            ),
        ], m.color);
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }

  static void _addTo(PdfPage page, List<Rect> rects, int colorArgb) {
    if (rects.isEmpty) return;
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
      opacity: highlightOpacity,
    )..textMarkupAnnotationType = PdfTextMarkupAnnotationType.highlight;
    page.annotations.add(annotation);
  }

  /// [removeHighlights]'ın izolatta koşan hâli.
  static Future<(List<int>, int)> removeHighlightsInBackground({
    required List<int> bytes,
    required int pageIndex,
    required List<List<double>> rects,
  }) =>
      Isolate.run(() => removeHighlights(
            bytes: bytes,
            pageIndex: pageIndex,
            pdfRects: [
              for (final r in rects)
                PdfRect(r[0], r[1], r[2], r[3]),
            ],
          ));

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
      _addTo(page, rects, colorArgb);
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


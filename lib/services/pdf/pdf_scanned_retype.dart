import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdfrx/pdfrx.dart' show PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

import '../pdf_tools.dart' show pdfToSyncfusionRect;

/// Taranmış sayfadaki BİR OCR satırı: tanınan metin + PDF koordinatında
/// (y yukarı; `top > bottom`) kutusu.
class ScannedLine {
  final String text;
  final PdfRect box;
  const ScannedLine(this.text, this.box);
}

/// Taranmış (görüntü) PDF sayfasında **satır üstüne yazma** (2026-08-06
/// kullanıcı isteği: *"taranmış belge deyip düzenleme yaptırmıyor — PDF'de
/// yapılabilmeli"*).
///
/// Gerçek bir metin akışı olmadığı için "yerinde düzenleme" fiziksel olarak
/// imkânsız; yapılabilir olan, tarayıcı uygulamalarının da yaptığı şey:
/// satırın görüntüsü beyaz bir kapakla örtülür ve yeni metin AYNI yere,
/// gömülü fontla (Carlito — Türkçe glifler tam) YAZILIR. Görüntünün geri
/// kalanı hiç bozulmaz; işlem çalışma kopyasında yapılır, geri alınabilir.
///
/// Sınırı dürüstçe söylüyoruz: kapak düz BEYAZdır — renkli/desenli zeminde
/// yama görünebilir. Taranmış belgelerin ezici çoğunluğu beyaz kâğıt olduğu
/// için v1 kararı bu; zemin renk örnekleme HAFIZA'da açık iş.
abstract final class PdfScannedRetype {
  static Uint8List? _fontCache;

  static Future<Uint8List> _font() async => _fontCache ??=
      (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
          .buffer
          .asUint8List();

  /// [box] satırını beyazla örtüp [newText]'i aynı konuma yazar; yeni PDF
  /// baytlarını döndürür. [newText] boşsa satır yalnız SİLİNİR (kapak kalır).
  static Future<List<int>> apply({
    required List<int> bytes,
    required int pageIndex,
    required PdfRect box,
    required String newText,
  }) async {
    final font = await _font();
    final doc = PdfDocument(inputBytes: bytes);
    try {
      final page = doc.pages[pageIndex];
      final rect = pdfToSyncfusionRect(
        left: box.left,
        pdfTop: box.top,
        width: box.width,
        height: box.height,
        pageHeight: page.size.height,
      );
      // Kapak satırdan bir tık büyük: OCR kutusu glif uçlarını (ç/ğ kuyruğu,
      // noktalama) kıl payı kaçırabiliyor; artık görünmesin.
      final cover = Rect.fromLTRB(
          rect.left - 2, rect.top - 2, rect.right + 2, rect.bottom + 2);
      page.graphics
          .drawRectangle(brush: PdfBrushes.white, bounds: cover);

      final text = newText.trim();
      if (text.isNotEmpty) {
        // Punto satır yüksekliğinden: OCR kutusu glif kutusudur, x-yüksekliği
        // payı için ~%74'ü alınır. Yazım alanı sağa doğru sayfa kenarına
        // kadar uzar — kullanıcı satırı UZATIRSA metin kırpılmasın.
        final size = (rect.height * 0.74).clamp(6.0, 96.0).toDouble();
        final drawBounds = Rect.fromLTWH(
          rect.left,
          rect.top - 1,
          math.max(rect.width, page.size.width - rect.left - 8),
          rect.height + 2,
        );
        page.graphics.drawString(
          text,
          PdfTrueTypeFont(font, size),
          brush: PdfSolidBrush(PdfColor(25, 25, 25)),
          bounds: drawBounds,
          format: PdfStringFormat(
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }
      return await doc.save();
    } finally {
      doc.dispose();
    }
  }
}

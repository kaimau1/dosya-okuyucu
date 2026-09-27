import 'dart:ui' show Offset, Size;

import 'package:dosya_okuyucu/services/pdf/pdf_font_class.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Yerinde düzenleme yedeğinde yazı tipi ailesi (2026-09-27: serif kitapta
/// düzeltilen kelime sans ve iri çıkıyordu).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PdfFontClass.of', () {
    test('serif / sans / mono', () {
      expect(PdfFontClass.of('TimesNewRomanPSMT').serif, isTrue);
      expect(PdfFontClass.of('Times-Roman').serif, isTrue);
      expect(PdfFontClass.of('Georgia-Bold').serif, isTrue);
      expect(PdfFontClass.of('ArialMT').serif, isFalse);
      expect(PdfFontClass.of('Helvetica').serif, isFalse);
      expect(PdfFontClass.of('DejaVuSans').serif, isFalse);
      expect(PdfFontClass.of('NotoSerif-Regular').serif, isTrue);
      expect(PdfFontClass.of('CourierNewPSMT').mono, isTrue);
    });

    test('kalın / italik', () {
      final bi = PdfFontClass.of('TimesNewRomanPS-BoldItalicMT');
      expect(bi.bold && bi.italic && bi.serif, isTrue);
      expect(PdfFontClass.of('Arial,Bold').bold, isTrue);
      expect(PdfFontClass.of('Helvetica-Oblique').italic, isTrue);
      expect(PdfFontClass.of('Calibri').bold, isFalse);
    });

    test('gömülü karşılık dosyası', () {
      expect(PdfFontClass.of('Times-Roman').assetPath,
          'assets/fonts/Tinos-Regular.ttf');
      expect(PdfFontClass.of('Times-BoldItalic').assetPath,
          'assets/fonts/Tinos-BoldItalic.ttf');
      expect(PdfFontClass.of('Arial-BoldMT').assetPath,
          'assets/fonts/Carlito-Bold.ttf');
      expect(PdfFontClass.of('').assetPath, 'assets/fonts/Carlito-Regular.ttf');
      expect(PdfFontClass.of('Times-Roman').previewFamily, 'Tinos');
    });
  });

  test('textStyleAt belgenin yazı tipi adını okur', () async {
    final doc = PdfDocument();
    final page = doc.pages.add();
    page.graphics.drawString(
      'Bir zat zuhur etmisti',
      PdfStandardFont(PdfFontFamily.timesRoman, 14),
      bounds: const Offset(40, 40) & const Size(400, 30),
    );
    final bytes = await doc.save();
    doc.dispose();
    // Standart fontun genişlik tablosu yok → paragraf kurulamaz; sayfanın
    // fontundan aile yine bulunur.
    final probe = PdfPageEdit.textStyleAt(bytes, 0, 120, 790);
    expect(probe.font, contains('Times'));
    expect(PdfFontClass.of(probe.font).serif, isTrue);
  });
}

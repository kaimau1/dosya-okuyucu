import 'dart:ui' show Offset, Size;

import 'package:flutter/services.dart' show rootBundle;

import 'package:dosya_okuyucu/services/pdf/pdf_font_class.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_pending_objects.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

import 'support/pdf_fixtures.dart';

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
      // PS2c (Faz 51): Calibri → Carlito, Arial/Helvetica → Arimo.
      expect(PdfFontClass.of('Calibri-Bold').previewFamily, 'Carlito');
      expect(PdfFontClass.of('ArialMT').previewFamily, 'Arimo');
      expect(PdfFontClass.of('Helvetica').previewFamily, 'Arimo');
      expect(PdfFontClass.of('CourierNewPSMT').previewFamily, 'JetBrains Mono');
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

  // 2026-11-02: "Üstüne yaz" kendi programını kullanamayınca aynı aileden
  // gömülü karşılık seçer (eskiden hep Carlito; sınıf hiç bağlanmamıştı).
  group('Üstüne yaz yedek yazı tipi', () {
    test('aile ve italik belgeden, kalınlık kullanıcıdan', () {
      expect(PdfOverwrite.fontAssetFor('TimesNewRomanPSMT', bold: false),
          'assets/fonts/Tinos-Regular.ttf');
      expect(PdfOverwrite.fontAssetFor('TimesNewRomanPS-ItalicMT', bold: true),
          'assets/fonts/Tinos-BoldItalic.ttf');
      // Belge kalın ama kullanıcı kalını kapattı → normal kesim.
      expect(PdfOverwrite.fontAssetFor('Arial-BoldMT', bold: false),
          'assets/fonts/Carlito-Regular.ttf');
      expect(PdfOverwrite.fontAssetFor(null, bold: true),
          'assets/fonts/Carlito-Bold.ttf');
    });

    test('paragrafın /BaseFont adı okunur', () {
      final bytes = PdfFixtures.textual();
      expect(
          PdfPageEdit.paragraphBaseFont(bytes,
              pageIndex: 0, paragraphIndex: 0),
          'Arial');
      expect(
          PdfPageEdit.paragraphBaseFont(bytes,
              pageIndex: 0, paragraphIndex: 999),
          isNull);
      expect(
          PdfPageEdit.paragraphBaseFont(const [1, 2, 3],
              pageIndex: 0, paragraphIndex: 0),
          isNull);
    });

    test('Tinos varlıkları pakette', () async {
      for (final style in ['Regular', 'Bold', 'Italic', 'BoldItalic']) {
        final data = await rootBundle.load('assets/fonts/Tinos-$style.ttf');
        expect(data.lengthInBytes, greaterThan(10000));
      }
    });
  });
}

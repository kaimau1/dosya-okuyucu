import 'package:dosya_okuyucu/services/xlsx/sheet_pdf.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 36 madde 6 — sayfa → PDF: çok sayfa, başlık her sayfada.
void main() {
  test('200 satır birden çok sayfaya bölünür, başlık yinelenir', () async {
    final cells = [
      ['Ad', 'Tutar'],
      for (var i = 1; i <= 200; i++) ['Satir$i', '$i'],
    ];
    final pdf = await SheetPdf.build(
      cells: cells,
      colWidthsPx: const [120, 80],
      spec: const SheetPrintSpec(repeatRows: 1),
      numeric: {for (var i = 1; i <= 200; i++) i * 16384 + 1},
    );
    final doc = PdfDocument(inputBytes: pdf);
    expect(doc.pages.count, greaterThan(1));
    final ex = PdfTextExtractor(doc);
    for (var p = 0; p < doc.pages.count; p++) {
      expect(ex.extractText(startPageIndex: p, endPageIndex: p), contains('Tutar'));
    }
    doc.dispose();
  });
}

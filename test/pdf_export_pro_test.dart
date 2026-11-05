import 'dart:convert';
import 'dart:ui' show Rect;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pdf_export_pro.dart';
import 'package:dosya_okuyucu/services/pdf_redact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 3 — PDF → Excel (tablo), Word (düzen), PDF/A.
Future<List<int>> _tableDoc() async {
  final doc = PdfDocument();
  final g = doc.pages.add().graphics;
  final f = PdfStandardFont(PdfFontFamily.helvetica, 11);
  const cols = [40.0, 200.0, 360.0];
  const data = [
    ['Urun', 'Adet', 'Fiyat'],
    ['Kalem', '12', '1.250,50'],
    ['Defter', '3', '40'],
  ];
  for (var r = 0; r < data.length; r++) {
    for (var c = 0; c < 3; c++) {
      g.drawString(data[r][c], f,
          bounds: Rect.fromLTWH(cols[c], 60.0 + r * 24, 120, 16));
    }
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

String _part(List<int> zip, String name) => utf8.decode(
    ZipDecoder().decodeBytes(zip).files.firstWhere((f) => f.name == name).content
        as List<int>);

void main() {
  test('öbekleme: geniş boşluk yeni hücre, dar boşluk aynı hücre', () {
    final chunks = PdfExportPro.chunksOf([
      (text: 'Ad', bounds: const Rect.fromLTWH(0, 0, 12, 10), size: 10),
      (text: 'Soyad', bounds: const Rect.fromLTWH(15, 0, 30, 10), size: 10),
      (text: '42', bounds: const Rect.fromLTWH(120, 0, 12, 10), size: 10),
    ]);
    expect(chunks.map((c) => c.text), ['Ad Soyad', '42']);
  });

  test('tablo satır/sütunları algılanır', () async {
    final rows = PdfExportPro.rows(await _tableDoc());
    final table = PdfExportPro.tableOf(rows.single);
    expect(table, hasLength(3));
    expect(table.first, ['Urun', 'Adet', 'Fiyat']);
    expect(table[1], ['Kalem', '12', '1.250,50']);
  });

  test('xlsx: sayı hücresi sayı olarak yazılır', () async {
    final xlsx = PdfExportPro.tablesToXlsx(await _tableDoc());
    final sheet = _part(xlsx, 'xl/worksheets/sheet1.xml');
    expect(sheet, contains('<v>1250.5</v>'));
    expect(_part(xlsx, 'xl/workbook.xml'), contains('Sayfa1'));
  });

  test('docx: her satır paragraf, girinti ve punto korunur', () async {
    final docx = PdfExportPro.toLayoutDocx(await _tableDoc());
    final xml = _part(docx, 'word/document.xml');
    expect(xml, contains('w:pgSz'));
    expect('<w:p>'.allMatches(xml).length, greaterThanOrEqualTo(3));
    expect(xml, contains('Kalem'));
    expect(xml, contains('w:val="22"')); // 11 pt
  });

  test('PDF/A-2b: uyum düzeyi meta verisi yazılır, sayfa sayısı korunur',
      () async {
    final out = await PdfRedact.apply(await _tableDoc(),
        rects: const {},
        rasters: const [],
        conformance: PdfConformanceLevel.a2b);
    final text = latin1.decode(out);
    expect(text, contains('pdfaid:part'));
    final doc = PdfDocument(inputBytes: out);
    expect(doc.pages.count, 1);
    doc.dispose();
  });
}

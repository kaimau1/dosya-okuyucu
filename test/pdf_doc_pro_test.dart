import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf_doc_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 5 — yer imi düzenleme, izinler, damga, numaralandırma.
Future<List<int>> _doc(int pages) async {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawString(
        'Bolum ${i + 1}', PdfStandardFont(PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(40, 300, 300, 20));
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

String _text(List<int> bytes, {String? password}) {
  final doc = PdfDocument(inputBytes: bytes, password: password);
  try {
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

void main() {
  test('yer imi ağacı yazılır ve aynen okunur', () async {
    const items = [
      PdfOutlineItem('Giriş', 0, 0),
      PdfOutlineItem('Amaç', 1, 1),
      PdfOutlineItem('Kapsam', 1, 1),
      PdfOutlineItem('Sonuç', 2, 0),
    ];
    final out = await PdfDocPro.writeOutline(await _doc(3), items);
    expect(PdfDocPro.readOutline(out), items);
    // Silme = listeden çıkarıp yeniden yazmak.
    final fewer = await PdfDocPro.writeOutline(out, [items.first]);
    expect(PdfDocPro.readOutline(fewer), [items.first]);
  });

  test('aşırı düzey bir öncekinin bir altına kenetlenir', () async {
    final out = await PdfDocPro.writeOutline(await _doc(1),
        const [PdfOutlineItem('A', 0, 0), PdfOutlineItem('B', 0, 5)]);
    expect(PdfDocPro.readOutline(out).last.level, 1);
  });

  test('izinler: sahip parolası + yalnız yazdırma', () async {
    final out = await PdfDocPro.setPermissions(await _doc(1),
        ownerPassword: 'sahip123', allow: {PdfAllow.print});
    // Kullanıcı parolası boş: parolasız açılır.
    expect(_text(out), contains('Bolum 1'));
    final allowed = PdfDocPro.readPermissions(out, password: 'sahip123');
    expect(allowed, contains(PdfAllow.print));
    expect(allowed, isNot(contains(PdfAllow.copy)));
  });

  test('damga yalnız seçili sayfalara basılır', () async {
    final out = await PdfDocPro.addStamp(await _doc(2),
        text: 'APPROVED', colorArgb: 0xFF2E7D32, pages: [1], subline: '05.11.2026');
    final doc = PdfDocument(inputBytes: out);
    final ex = PdfTextExtractor(doc);
    expect(ex.extractText(startPageIndex: 0, endPageIndex: 0),
        isNot(contains('APPROVED')));
    expect(ex.extractText(startPageIndex: 1, endPageIndex: 1), contains('APPROVED'));
    doc.dispose();
  });

  test('numara etiketleri', () {
    expect(PdfDocPro.roman(14), 'XIV');
    expect(PdfDocPro.roman(1999), 'MCMXCIX');
    expect(
        PdfDocPro.numberLabel(PdfNumberStyle.bates,
            number: 7, total: 9, prefix: 'DAVA-', digits: 5),
        'DAVA-00007');
    expect(
        PdfDocPro.numberLabel(PdfNumberStyle.pageOfTotal,
            number: 2, total: 9, pageWord: 'Page'),
        'Page 2 / 9');
    expect(PdfDocPro.numberLabel(PdfNumberStyle.roman, number: 4, total: 9), 'iv');
  });

  test('Bates numarası her sayfaya, kapak atlanır', () async {
    final out = await PdfDocPro.addNumbering(await _doc(3),
        style: PdfNumberStyle.bates,
        prefix: 'EK',
        digits: 3,
        skipFirstPage: true,
        place: PdfNumberPlace.topRight);
    final doc = PdfDocument(inputBytes: out);
    final ex = PdfTextExtractor(doc);
    expect(ex.extractText(startPageIndex: 0, endPageIndex: 0), isNot(contains('EK0')));
    expect(ex.extractText(startPageIndex: 1, endPageIndex: 1), contains('EK001'));
    expect(ex.extractText(startPageIndex: 2, endPageIndex: 2), contains('EK002'));
    doc.dispose();
  });
}

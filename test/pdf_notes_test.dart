import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf_notes.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 6/10 — vurgu/not kitapçığı: işaretlemenin altındaki metin
/// çıkarılır, sayfa ve konum sırasıyla Markdown'a yazılır.
Future<List<int>> _doc() async {
  final doc = PdfDocument();
  final f = PdfStandardFont(PdfFontFamily.helvetica, 14);
  final p1 = doc.pages.add();
  p1.graphics.drawString('Onemli cumle burada', f,
      bounds: const Rect.fromLTWH(40, 100, 400, 20));
  p1.graphics.drawString('Silinecek ifade', f,
      bounds: const Rect.fromLTWH(40, 200, 400, 20));
  final w1 = f.measureString('Onemli cumle burada');
  p1.annotations.add(PdfTextMarkupAnnotation(
      Rect.fromLTWH(40, 100, w1.width, w1.height), 'kontrol et',
      PdfColor(255, 235, 59),
      textMarkupAnnotationType: PdfTextMarkupAnnotationType.highlight));
  final w2 = f.measureString('Silinecek ifade');
  p1.annotations.add(PdfTextMarkupAnnotation(
      Rect.fromLTWH(40, 200, w2.width, w2.height), '', PdfColor(255, 0, 0),
      textMarkupAnnotationType: PdfTextMarkupAnnotationType.strikethrough));
  doc.pages.add().annotations.add(
      PdfPopupAnnotation(const Rect.fromLTWH(20, 20, 20, 20), 'Ikinci sayfa notu'));
  final out = await doc.save();
  doc.dispose();
  return out;
}

void main() {
  test('işaretlemeler sırayla, altındaki metinle toplanır', () async {
    final items = PdfNotes.collect(await _doc());
    expect(items, hasLength(3));
    expect(items[0].kind, PdfNoteKind.highlight);
    expect(items[0].quote, 'Onemli cumle burada');
    expect(items[0].comment, 'kontrol et');
    expect(items[1].kind, PdfNoteKind.strikethrough);
    expect(items[1].quote, 'Silinecek ifade');
    expect(items[2].page, 2);
    expect(items[2].kind, PdfNoteKind.note);
  });

  test('Markdown kitapçık', () async {
    final md = PdfNotes.toMarkdown(
      PdfNotes.collect(await _doc()),
      title: 'Belge',
      labels: const {
        PdfNoteKind.highlight: 'Vurgu',
        PdfNoteKind.strikethrough: 'Üstü çizili',
        PdfNoteKind.note: 'Not',
      },
      pageLabel: (n) => 'Sayfa $n',
    );
    expect(md, startsWith('# Belge'));
    expect(md, contains('## Sayfa 1'));
    expect(md, contains('**Vurgu:** “Onemli cumle burada”'));
    expect(md, contains('  - kontrol et'));
    expect(md, contains('~~Silinecek ifade~~'));
    expect(md, contains('**Not:** Ikinci sayfa notu'));
  });
}

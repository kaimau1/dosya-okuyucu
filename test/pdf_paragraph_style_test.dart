import 'package:dosya_okuyucu/services/pdf/pdf_paragraph_layout.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/pdf_fixtures.dart';

/// Faz 31 kalanı: paragrafa **kalın** (belgenin gömülü kalın kesimiyle) ve
/// **renk**; kesim yoksa açıklamalı ret.
void main() {
  // Elle kurulan PDF: /F1 = Arial, /F2 = Arial-BoldMT (aynı aile).
  Future<List<int>> pdf({bool withBold = true}) async => PdfFixtures.hand(
      [PdfFixtures.textContent(['Toplantı notları burada'])],
      boldFont: withBold);

  int indexOf(List<int> bytes, String start) => PdfPageEdit.outline(bytes, 0)
      .paragraphs
      .indexWhere((p) => p.text.startsWith(start));

  test('kalın: aynı ailenin gömülü kalın kesimine geçer', () async {
    final src = await pdf();
    final i = indexOf(src, 'Toplantı');
    expect(i, isNonNegative);
    final out = PdfPageEdit.replaceParagraph(src,
        pageIndex: 0,
        paragraphIndex: i,
        newText: 'Toplantı notları burada',
        bold: true);
    final par = PdfPageEdit.outline(out, 0)
        .paragraphs
        .firstWhere((p) => p.text.startsWith('Toplantı'));
    expect(par.runs.map((r) => r.fontName).toSet(), {'F2'},
        reason: 'paragraf aynı ailenin kalın kesimiyle (Arial-BoldMT) yazıldı');
  });

  test('renk: dolgu rengi yazılır, sonraki içerik eski renge döner', () async {
    final src = await pdf();
    final i = indexOf(src, 'Toplantı');
    final out = PdfPageEdit.replaceParagraph(src,
        pageIndex: 0,
        paragraphIndex: i,
        newText: 'Toplantı notları burada',
        colorArgb: 0xFFC00000);
    final par = PdfPageEdit.outline(out, 0)
        .paragraphs
        .firstWhere((p) => p.text.startsWith('Toplantı'));
    expect(String.fromCharCodes(par.runs.first.colorBytes),
        String.fromCharCodes(pdfFillColorOp(0xFFC00000)));
  });

  test('kalın kesim belgede yoksa açıklamalı ret', () async {
    final src = await pdf(withBold: false);
    final i = indexOf(src, 'Toplantı');
    expect(
        () => PdfPageEdit.replaceParagraph(src,
            pageIndex: 0,
            paragraphIndex: i,
            newText: 'Toplantı notları burada',
            bold: true),
        throwsA(isA<PdfParagraphRefused>()));
  });
}

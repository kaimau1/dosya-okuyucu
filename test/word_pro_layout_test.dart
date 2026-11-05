import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_layout_ops.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_pdf.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 2 — sayfa düzeni + baskı önizleme PDF'i.
Uint8List _fx(String n) =>
    File('test/fixtures/office/$n.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

DocxPdfFonts testFonts() => DocxPdfFonts({
      for (final n in const [
        'Carlito-Regular', 'Carlito-Bold', 'Carlito-Italic', 'Carlito-BoldItalic',
        'Tinos-Regular', 'Tinos-Bold', 'Tinos-Italic', 'Tinos-BoldItalic',
      ])
        n: File('assets/fonts/$n.ttf').readAsBytesSync(),
    });

void main() {
  test('özel kenar boşluğu, yatay, Letter, 2 sütun, farklı ilk sayfa', () {
    final b = _fx('stiller_basliklar');
    final spec = DocxLayoutOps.read(DocxPackage.open(b)).copyWith(
      width: 12240,
      height: 15840,
      landscape: true,
      top: DocxPageSpec.cmToTwip(2),
      left: DocxPageSpec.cmToTwip(3.5),
      gutter: DocxPageSpec.cmToTwip(0.5),
      columns: 2,
      titlePage: true,
    );
    final out = _apply(b, DocxLayoutOps.apply(spec));
    final back = DocxLayoutOps.read(DocxPackage.open(out));
    expect(back.landscape, isTrue);
    expect(back.width, 15840);
    expect(back.height, 12240);
    expect(back.top, 1134);
    expect(back.left, 1984);
    expect(back.gutter, 283);
    expect(back.columns, 2);
    expect(back.titlePage, isTrue);
    // Editör modeli de aynı ayarı görür.
    final ps = DocxDocument.parse(out).pageSetup();
    expect(ps.landscape, isTrue);
    expect(ps.columns, 2);
  });

  test('bölüm sonu: önceki bölüm paragrafta, tür sonraki bölümde', () {
    final b = _fx('stiller_basliklar');
    final out = _apply(b, DocxLayoutOps.sectionBreak(1, 'continuous'));
    final pkg = DocxPackage.open(out);
    final p = pkg.modelParagraphs()[1];
    expect(kid(kid(p, 'pPr'), 'sectPr'), isNotNull);
    expect(attrOf(kid(pkg.bodySectPr, 'type')), 'continuous');
    expect(DocxDocument.parse(out).paras.length,
        DocxDocument.parse(b).paras.length);
  });

  test('baskı önizleme PDF: gömülü yazı tipi, sayfa sonu yeni sayfa', () async {
    for (final f in ['stiller_basliklar', 'tablo', 'liste_duzeyli', 'word_kaydedilmis_cok_sayfa']) {
      final pdf = await DocxPdf.render(_fx(f), fonts: testFonts(), compress: false);
      final head = String.fromCharCodes(pdf.take(5));
      expect(head, '%PDF-', reason: f);
      expect(String.fromCharCodes(pdf).contains('FontFile2'), isTrue,
          reason: '$f: yazı tipi gömülü değil');
    }
    final withBreak = _apply(_fx('stiller_basliklar'), DocxLayoutOps.pageBreakAfter(0));
    final a = await DocxPdf.render(_fx('stiller_basliklar'), fonts: testFonts(), compress: false);
    final b = await DocxPdf.render(withBreak, fonts: testFonts(), compress: false);
    int pages(Uint8List p) =>
        RegExp(r'/Type\s*/Page[^s]').allMatches(String.fromCharCodes(p)).length;
    expect(pages(b), greaterThan(pages(a)));
  });
}

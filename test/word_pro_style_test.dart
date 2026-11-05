import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 37 madde 1 — stili güncelle + belge teması.
Uint8List _fixture() =>
    File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

void main() {
  test('modelParagraphs editör paragraf sayısıyla aynı', () {
    for (final f in ['stiller_basliklar', 'tablo', 'liste_duzeyli', 'madde_imleri']) {
      final b = File('test/fixtures/office/$f.docx').readAsBytesSync();
      expect(DocxPackage.open(b).modelParagraphs().length,
          DocxDocument.parse(b).paras.length,
          reason: f);
    }
  });

  test('stili güncelle: doğrudan biçim stile taşınır, paragraftan silinir', () {
    final b = _fixture();
    final doc = DocxDocument.parse(b);
    // İlk paragrafa doğrudan kalın + 20 pt + ortala uygula.
    final i = doc.paras.indexWhere((p) =>
        !p.opaque && p.cell == null && p.text.trim().length > 3 &&
        !p.text.contains(kDocxAtom));
    final p0 = doc.paras[i];
    doc.paras[i] = doc.setAlign(
        p0.format(0, p0.length,
            patch: const DocxRunPatch(bold: true, sizePt: 20)),
        'center');
    final edited = doc.save();
    final styleId = DocxDocument.parse(edited).paras[i].look.styleId ??
        'Normal';
    final out = _apply(edited, DocxStyleOps.updateStyleFromParagraph(i));
    final pkg = DocxPackage.open(out);
    final style = DocxStyleOps.styleById(
        pkg.read('word/styles.xml')!.rootElement, styleId)!;
    expect(attrOf(kid(kid(style, 'pPr'), 'jc')), 'center');
    expect(attrOf(kid(kid(style, 'rPr'), 'sz')), '40');
    final p = pkg.modelParagraphs()[i];
    expect(kid(kid(p, 'pPr'), 'jc'), isNull);
    // Görünüş korunur (artık stilden).
    final again = DocxDocument.parse(out).paras[i];
    expect(again.look.align, 'center');
    expect(again.styles.first.effective.sizePt, 20);
  });

  test('tema: başlık ve gövde yazı tipi + punto', () {
    final set = kDocxStyleSets.firstWhere((s) => s.id == 'classic');
    final out = _apply(_fixture(), DocxStyleOps.applyStyleSet(set));
    final (_, body) = DocxStyleOps.themeFonts(DocxPackage.open(out));
    expect(body, 'Times New Roman');
    final root = DocxPackage.open(out).read('word/styles.xml')!.rootElement;
    final h1 = DocxStyleOps.styleById(root, 'Heading1')!;
    expect(attrOf(kid(kid(h1, 'rPr'), 'rFonts'), 'ascii'), 'Times New Roman');
    expect(DocxDocument.parse(out).paras, isNotEmpty);
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_insert_pro.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_package.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_style_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 37 madde 9 — kenarlık, metin kutusu, şekil, sarma, kapak, alan,
/// çapraz başvuru, kaynakça.
Uint8List _fx(String n) =>
    File('test/fixtures/office/$n.docx').readAsBytesSync();

Uint8List _apply(Uint8List b, DocxOp op) {
  final pkg = DocxPackage.open(b);
  op(pkg);
  return pkg.save();
}

/// İmlece işaret yazılmış belge (editörün yaptığı gibi).
(Uint8List, int) _withMarker(Uint8List b) {
  final doc = DocxDocument.parse(b);
  final i = doc.paras.indexWhere((p) =>
      !p.opaque && p.cell == null && p.text.length > 4 && !p.text.contains(kDocxAtom));
  final p = doc.paras[i];
  doc.paras[i] = p.replace(2, 2, kDocxMarker, p.typingStyleAt(2));
  return (doc.save(), i);
}

void main() {
  test('paragraf kenarlığı ve gölge', () {
    final out = _apply(_fx('stiller_basliklar'), DocxInsertPro.paraBorder(0, 'box'));
    final pBdr = DocxPackage.open(out).modelParagraphs()[0].findAllElements('w:pBdr').single;
    expect(pBdr.childElements.map((e) => e.name.local), ['top', 'left', 'bottom', 'right']);
    final none = _apply(out, DocxInsertPro.paraBorder(0, 'none'));
    expect(DocxPackage.open(none).modelParagraphs()[0].findAllElements('w:pBdr'), isEmpty);
  });

  test('metin kutusu + şekil: DrawingML, editör açar', () {
    final b = _fx('stiller_basliklar');
    final tb = _apply(b, DocxInsertPro.textBox(0, 'Kutu\nikinci'));
    final pkg = DocxPackage.open(tb);
    expect(pkg.body.findAllElements('w:txbxContent'), hasLength(1));
    expect(pkg.document.rootElement.getAttribute('xmlns:wps'), kWps);
    expect(DocxDocument.parse(tb).paras.length, DocxDocument.parse(b).paras.length + 1);
    final sh = _apply(tb, DocxInsertPro.shape(0, 'ellipse'));
    final ids = DocxPackage.open(sh).body.findAllElements('wp:docPr').map((e) => e.getAttribute('id')).toSet();
    expect(ids.length, 2, reason: 'docPr kimlikleri tekil');
  });

  test('sarma: satır içi → kare → arkada → satır içi', () {
    final b = _apply(_fx('stiller_basliklar'), DocxInsertPro.shape(0, 'rect'));
    var out = _apply(b, DocxInsertPro.imageWrap(1, 'square'));
    expect(DocxInsertPro.wrapOf(DocxPackage.open(out), 1), 'square');
    out = _apply(out, DocxInsertPro.imageWrap(1, 'behind'));
    expect(DocxInsertPro.wrapOf(DocxPackage.open(out), 1), 'behind');
    out = _apply(out, DocxInsertPro.imageWrap(1, 'inline'));
    expect(DocxInsertPro.wrapOf(DocxPackage.open(out), 1), 'inline');
    expect(DocxDocument.parse(out).paras, isNotEmpty);
  });

  test('kapak: başta başlık + sayfa sonu', () {
    final out = _apply(_fx('stiller_basliklar'),
        DocxInsertPro.cover('Rapor', 'Alt', 'Ayşe', '05.11.2026'));
    final doc = DocxDocument.parse(out);
    expect(doc.paras.first.text, 'Rapor');
    expect(doc.paras.first.look.styleId, 'Title');
  });

  test('alan imleçte: işaret kalkar, fldSimple yerinde', () {
    final (b, i) = _withMarker(_fx('stiller_basliklar'));
    final before = DocxDocument.parse(b).paras[i].text;
    final out = _apply(b, DocxInsertPro.field('PAGE', '1'));
    final p = DocxPackage.open(out).modelParagraphs()[i];
    expect(p.innerText.contains(kDocxMarker), isFalse);
    final f = p.findAllElements('w:fldSimple').single;
    expect(f.getAttribute('w:instr'), ' PAGE ');
    // Metin işaretin iki yanında aynen.
    final t = p.innerText;
    expect(t, before.replaceFirst(kDocxMarker, '1'));
  });

  test('çapraz başvuru: başlığa _Ref yer imi + REF alanı', () {
    final b0 = _fx('stiller_basliklar');
    final h = DocxDocument.parse(b0).paras.indexWhere((p) => p.look.headingLevel > 0);
    final (b, _) = _withMarker(b0);
    final out = _apply(b, DocxInsertPro.crossRef(h, 'text', result: 'Başlık'));
    final pkg = DocxPackage.open(out);
    final bm = pkg.body.findAllElements('w:bookmarkStart')
        .firstWhere((e) => (e.getAttribute('w:name') ?? '').startsWith('_Ref'));
    final f = pkg.body.findAllElements('w:fldSimple').single;
    expect(f.getAttribute('w:instr'), contains('REF ${bm.getAttribute('w:name')}'));
  });

  test('kaynakça: atıf + alfabetik girdi, tekrar yazılmaz', () {
    final (b, _) = _withMarker(_fx('stiller_basliklar'));
    var out = _apply(b, DocxInsertPro.cite(const DocxSource('Yılmaz, Ali', '2020', 'Kitap', 'Yayınevi')));
    final (b2, _) = _withMarker(out);
    out = _apply(b2, DocxInsertPro.cite(const DocxSource('Aksoy, Can', '2019', 'Makale', '')));
    final (b3, _) = _withMarker(out);
    out = _apply(b3, DocxInsertPro.cite(const DocxSource('Aksoy, Can', '2019', 'Makale', '')));
    final text = DocxDocument.parse(out).plainText();
    expect(text, contains('(Yılmaz, 2020)'));
    final lines = text.split('\n');
    final a = lines.indexWhere((l) => l.startsWith('Aksoy'));
    final y = lines.indexWhere((l) => l.startsWith('Yılmaz'));
    expect(a, lessThan(y));
    expect(lines.where((l) => l.startsWith('Aksoy')), hasLength(1));
    expect(const DocxSource('Ali Veli', '', 'X', '').citation, '(Veli, t.y.)');
  });
}

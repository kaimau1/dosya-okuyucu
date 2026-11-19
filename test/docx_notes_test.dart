import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_pdf.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/docx_synth.dart';
import 'word_pro_layout_test.dart' show testFonts;

/// B9 m.5 — dipnot / sonnot: numara belge sırasıyla (`w:id`den bağımsız),
/// sonnot ekle/düzenle, sil + kaydette budama, geri al, PDF'te not listesi.

const _rel = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships';
const _ct = 'application/vnd.openxmlformats-officedocument.wordprocessingml';
const _w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';

String _ref(String tag, int id) =>
    '<w:r><w:rPr><w:vertAlign w:val="superscript"/></w:rPr>'
    '<w:${tag}Reference w:id="$id"/></w:r>';

String _note(String tag, int id, String text) =>
    '<w:$tag w:id="$id"><w:p><w:r><w:${tag}Ref/></w:r>'
    '<w:r><w:t xml:space="preserve"> $text</w:t></w:r></w:p></w:$tag>';

String _sep(String tag) =>
    '<w:$tag w:type="separator" w:id="-1"><w:p><w:r><w:separator/></w:r></w:p></w:$tag>'
    '<w:$tag w:type="continuationSeparator" w:id="0"><w:p><w:r><w:continuationSeparator/></w:r></w:p></w:$tag>';

/// Dipnot kimlikleri bilerek sırasız (5 önce, 2 sonra) + bir sonnot.
final _doc = synthDocx(
  '<w:p><w:r><w:t>Birinci</w:t></w:r>${_ref('footnote', 5)}</w:p>'
  '<w:p><w:r><w:t>İkinci</w:t></w:r>${_ref('footnote', 2)}'
  '<w:r><w:t xml:space="preserve"> son</w:t></w:r>${_ref('endnote', 3)}</w:p>',
  parts: {
    'word/footnotes.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:footnotes $_w>${_sep('footnote')}'
        '${_note('footnote', 2, 'iki')}${_note('footnote', 5, 'beş')}</w:footnotes>',
    'word/endnotes.xml': '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n'
        '<w:endnotes $_w>${_sep('endnote')}${_note('endnote', 3, 'üç')}</w:endnotes>',
  },
  rels: '<Relationship Id="rId8" Type="$_rel/footnotes" Target="footnotes.xml"/>'
      '<Relationship Id="rId9" Type="$_rel/endnotes" Target="endnotes.xml"/>',
  types: '<Override PartName="/word/footnotes.xml" ContentType="$_ct.footnotes+xml"/>'
      '<Override PartName="/word/endnotes.xml" ContentType="$_ct.endnotes+xml"/>',
);

List<(String, String)> _labels(DocxEditController c) => [
      for (final p in c.paras)
        for (final a in p.atoms.whereType<DocxAtom>())
          if (a.kind == DocxAtomKind.note) (c.doc.noteKey(a), c.noteLabels[a]!),
    ];

void main() {
  test('numara belge sırasıyla: dipnot 1, 2 (kimlik 5, 2) · sonnot i', () {
    final c = DocxEditController(DocxDocument.parse(_doc));
    expect(_labels(c), [('5', '1'), ('2', '2'), ('e:3', 'i')]);
    expect(c.footnoteText('5'), 'beş');
    expect(c.footnoteText('e:3'), 'üç');
    expect(c.noteNumberOf('2'), '2');
  });

  test('Word numara biçimleri', () {
    expect(docxNoteNumber('decimal', 12), '12');
    expect(docxNoteNumber('lowerRoman', 4), 'iv');
    expect(docxNoteNumber('upperRoman', 14), 'XIV');
    expect(docxNoteNumber('lowerLetter', 27), 'aa');
    expect(docxNoteNumber('upperLetter', 3), 'C');
    expect(docxNoteNumber('chicago', 6), '††');
    expect(docxNoteNumber('bilinmeyen', 7), '7');
  });

  test('başa eklenen dipnot 1 olur, ötekiler kayar', () {
    final c = DocxEditController(DocxDocument.parse(_doc));
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertFootnote('yeni');
    final l = _labels(c);
    expect(l.map((e) => e.$2), ['1', '2', '3', 'i']);
    expect(c.footnoteText(l.first.$1), 'yeni');
    // Yeni kimlik en büyükten sonra (5 → 6), çakışma yok.
    expect(l.first.$1, '6');
  });

  test('sonnot ekle → endnotes.xml + başvuru; metin düzenle', () {
    final c = DocxEditController(DocxDocument.parse(synthDocx(synthP('Metin'))));
    c.select(const DocPos(0, 5), const DocPos(0, 5));
    c.insertFootnote('Kaynak', endnote: true);
    final out = c.doc.save();
    final ex = synthPart(out, 'word/endnotes.xml');
    expect(ex, contains('w:type="separator"'));
    expect(ex, contains('Kaynak'));
    expect(synthPart(out, 'word/document.xml'), contains('endnoteReference'));
    expect(synthPart(out, 'word/_rels/document.xml.rels'), contains('/endnotes'));
    expect(synthPart(out, '[Content_Types].xml'), contains('endnotes+xml'));
    final again = DocxEditController(DocxDocument.parse(out));
    expect(_labels(again), [('e:1', 'i')]);
    expect(again.setFootnoteText('e:1', 'Kaynak 2'), isTrue);
    expect(synthPart(again.doc.save(), 'word/endnotes.xml'), contains('Kaynak 2'));
  });

  test('sil: başvuru kalkar, not kaydette budanır (ayırıcılar kalır); geri al getirir', () {
    final c = DocxEditController(DocxDocument.parse(_doc));
    c.deleteNote('5');
    expect(_labels(c), [('2', '1'), ('e:3', 'i')]);
    final out = c.doc.save();
    final fx = synthPart(out, 'word/footnotes.xml');
    expect(fx, isNot(contains('beş')));
    expect(fx, contains('iki'));
    expect(fx, contains('w:type="separator"'));
    expect(synthPart(out, 'word/endnotes.xml'), contains('üç'));
    c.undo();
    expect(_labels(c).first, ('5', '1'));
    // Budama bellekteki parçaya dokunmaz: geri alınan not metniyle kaydedilir.
    expect(c.footnoteText('5'), 'beş');
    expect(synthPart(c.doc.save(), 'word/footnotes.xml'), contains('beş'));

    final d = DocxEditController(DocxDocument.parse(_doc));
    d.deleteNote('e:3');
    expect(synthPart(d.doc.save(), 'word/endnotes.xml'), isNot(contains('üç')));
  });

  test('dokunulmayan belgede not parçaları aynen kalır', () {
    final c = DocxEditController(DocxDocument.parse(_doc));
    final out = c.doc.save();
    expect(synthPart(out, 'word/footnotes.xml'), synthPart(_doc, 'word/footnotes.xml'));
    expect(synthPart(out, 'word/endnotes.xml'), synthPart(_doc, 'word/endnotes.xml'));
  });

  test('PDF: notlu belge çizilir, not listesi eklenir', () async {
    final plain = synthDocx('<w:p><w:r><w:t>Birinci</w:t></w:r></w:p>'
        '<w:p><w:r><w:t>İkinci son</w:t></w:r></w:p>');
    final a = await DocxPdf.render(plain, fonts: testFonts(), compress: false);
    final b = await DocxPdf.render(_doc, fonts: testFonts(), compress: false);
    expect(String.fromCharCodes(b.take(5)), '%PDF-');
    expect(b.length, greaterThan(a.length));
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 24b — tablo satır/sütun işlemleri, geri al/yinele, izlenen değişiklik
/// kabul/ret, üst/alt bilgi.
const _fixture = 'test/fixtures/office/stiller_basliklar.docx';

Uint8List _bytes() => File(_fixture).readAsBytesSync();

String _part(Uint8List bytes, String name) => utf8.decode(ZipDecoder()
    .decodeBytes(bytes)
    .files
    .firstWhere((f) => f.name == name)
    .content as List<int>);

bool _has(Uint8List bytes, String name) =>
    ZipDecoder().decodeBytes(bytes).files.any((f) => f.name == name);

DocxEditController _open() => DocxEditController(DocxDocument.parse(_bytes()));

Uint8List _docx(String bodyXml) {
  const w = 'xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main"';
  final a = Archive();
  void add(String n, String s) =>
      a.addFile(ArchiveFile(n, utf8.encode(s).length, utf8.encode(s)));
  add('[Content_Types].xml',
      '<?xml version="1.0" encoding="UTF-8"?><Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/></Types>');
  add('_rels/.rels',
      '<?xml version="1.0" encoding="UTF-8"?><Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/></Relationships>');
  add('word/document.xml',
      '<?xml version="1.0" encoding="UTF-8"?><w:document $w><w:body>$bodyXml<w:sectPr/></w:body></w:document>');
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

List<XmlElement> _tables(Uint8List out) =>
    XmlDocument.parse(_part(out, 'word/document.xml'))
        .findAllElements('w:tbl')
        .toList();

/// Yeni eklenen 2×3 tablo (fixture'daki tablodan ayırt edilir).
XmlElement _fresh(Uint8List out, int rows, int cols) => _tables(out).firstWhere(
    (t) =>
        t.findElements('w:tr').length == rows &&
        t.findElements('w:tblGrid').first.findElements('w:gridCol').length ==
            cols);

void _expectConsistent(XmlElement t) {
  final grid = t.findElements('w:tblGrid').first.findElements('w:gridCol').length;
  for (final tr in t.findElements('w:tr')) {
    final cells = tr.findElements('w:tc').toList();
    expect(cells.fold<int>(0, (a, c) {
      final g = c.findAllElements('w:gridSpan').firstOrNull;
      return a + (int.tryParse(g?.getAttribute('w:val') ?? '') ?? 1);
    }), grid);
    for (final tc in cells) {
      expect(tc.findElements('w:p'), isNotEmpty);
    }
  }
}

void main() {
  test('satır ve sütun ekle → kaydet: 3×4, ızgara tutarlı, ilk hücre imleçte', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertTable(2, 3);
    c.tableRow(below: true);
    expect(c.inTable, isTrue);
    c.tableColumn(right: true);
    final out = c.doc.save();
    final t = _fresh(out, 3, 4);
    _expectConsistent(t);
    final again = DocxDocument.parse(out);
    expect(again.paras.where((p) => identical(p.cell?.table, again.paras.firstWhere((q) => q.cell != null && q.cell!.table.findElements('w:tr').length == 3 && q.cell!.table.findElements('w:tr').first.findElements('w:tc').length == 4).cell!.table)).length, 12);
  });

  test('geri al / yinele: yeni satır ve tablo kaybolmaz ve geri gelir', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertTable(2, 3);
    c.tableRow(below: false);
    c.undo(); // satır gitti
    var out = c.doc.save();
    _expectConsistent(_fresh(out, 2, 3));
    c.redo();
    out = c.doc.save();
    _expectConsistent(_fresh(out, 3, 3));
    // Tabloyu da geri al → yinele: yinelemede XML'e yeniden bağlanır.
    c.undo();
    c.undo();
    expect(_tables(c.doc.save()).length, 1);
    c.redo();
    c.redo();
    expect(_fresh(c.doc.save(), 3, 3), isNotNull);
  });

  test('satır / sütun / tablo sil', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertTable(3, 3);
    c.deleteTableRow();
    c.deleteTableColumn();
    var out = c.doc.save();
    _expectConsistent(_fresh(out, 2, 2));
    c.deleteWholeTable();
    expect(c.inTable, isFalse);
    out = c.doc.save();
    expect(_tables(out).length, 1);
    c.undo();
    expect(_fresh(c.doc.save(), 2, 2), isNotNull);
  });

  test('başlık / bant / gölge ayarları ve geri alınmaları', () {
    final c = _open();
    c.select(const DocPos(0, 0), const DocPos(0, 0));
    c.insertTable(2, 2);
    c.setTableHeader(false);
    c.setTableBanded(false);
    c.setCellShade(0xFFFF00);
    expect(c.cellShade, 0xFFFF00);
    var out = c.doc.save();
    final t = _fresh(out, 2, 2);
    final look = t.findAllElements('w:tblLook').first;
    expect(look.getAttribute('w:firstRow'), '0');
    expect(look.getAttribute('w:noHBand'), '1');
    expect(t.findAllElements('w:shd').first.getAttribute('w:fill'), 'FFFF00');
    c.undo();
    expect(c.cellShade, isNull);
    c.undo();
    expect(c.tableBanded, isTrue);
    c.undo();
    expect(c.tableHeader, isTrue);
  });

  test('izlenen değişiklikler: kabul → ins/del kalmaz, metin eklenen+kalan', () {
    final bytes = _docx(
        '<w:p><w:r><w:t>A </w:t></w:r><w:ins w:id="1" w:author="x"><w:r><w:t>yeni </w:t></w:r></w:ins><w:del w:id="2" w:author="x"><w:r><w:delText>eski </w:delText></w:r></w:del><w:r><w:t>son</w:t></w:r></w:p>');
    final c = DocxEditController(DocxDocument.parse(bytes));
    expect(c.trackedChanges, 2);
    c.resolveTracked(accept: true);
    expect(c.trackedChanges, 0);
    final out = c.doc.save();
    final x = _part(out, 'word/document.xml');
    expect(x.contains('w:ins'), isFalse);
    expect(x.contains('w:del'), isFalse);
    expect(DocxDocument.parse(out).paras.first.text, 'A yeni son');
  });

  test('izlenen değişiklikler: reddet → silinen geri gelir, eklenen gider', () {
    final bytes = _docx(
        '<w:p><w:r><w:t>A </w:t></w:r><w:ins w:id="1" w:author="x"><w:r><w:t>yeni </w:t></w:r></w:ins><w:del w:id="2" w:author="x"><w:r><w:delText>eski </w:delText></w:r></w:del><w:r><w:t>son</w:t></w:r></w:p>');
    final c = DocxEditController(DocxDocument.parse(bytes));
    c.resolveTracked(accept: false);
    final out = c.doc.save();
    final x = _part(out, 'word/document.xml');
    expect(x.contains('w:ins'), isFalse);
    expect(x.contains('delText'), isFalse);
    expect(DocxDocument.parse(out).paras.first.text, 'A eski son');
  });

  test('biçim değişikliği reddi eski rPr\'yi geri getirir', () {
    final bytes = _docx(
        '<w:p><w:r><w:rPr><w:b/><w:rPrChange w:id="1" w:author="x"><w:rPr><w:i/></w:rPr></w:rPrChange></w:rPr><w:t>m</w:t></w:r></w:p>');
    final c = DocxEditController(DocxDocument.parse(bytes));
    expect(c.trackedChanges, 1);
    c.resolveTracked(accept: false);
    final x = _part(c.doc.save(), 'word/document.xml');
    expect(x.contains('w:i/'), isTrue);
    expect(x.contains('w:b/'), isFalse);
    expect(x.contains('rPrChange'), isFalse);
  });

  test('üst ve alt bilgi: yarat → kaydet → yeniden aç → oku', () {
    final bytes = _docx('<w:p><w:r><w:t>x</w:t></w:r></w:p>');
    final c = DocxEditController(DocxDocument.parse(bytes));
    expect(c.headerFooter(header: true).text, '');
    expect(c.setHeaderFooter(header: true, text: 'Gizli', pageNumber: false), isTrue);
    expect(c.setHeaderFooter(header: false, text: 'Sayfa', pageNumber: true), isTrue);
    final out = c.doc.save();
    expect(_has(out, 'word/header1.xml'), isTrue);
    expect(_has(out, 'word/footer1.xml'), isTrue);
    expect(_part(out, '[Content_Types].xml'), contains('/word/header1.xml'));
    expect(_part(out, 'word/document.xml'), contains('w:headerReference'));
    expect(_part(out, 'word/document.xml'), contains('w:footerReference'));
    final again = DocxEditController(DocxDocument.parse(out));
    expect(again.headerFooter(header: true).text, 'Gizli');
    final f = again.headerFooter(header: false);
    expect(f.text, 'Sayfa');
    expect(f.pageNumber, isTrue);
    // Var olanı düzenle: yeni parça açılmaz.
    expect(again.setHeaderFooter(header: true, text: 'Yeni', pageNumber: false), isTrue);
    final out2 = again.doc.save();
    expect(_has(out2, 'word/header2.xml'), isFalse);
    expect(DocxEditController(DocxDocument.parse(out2)).headerFooter(header: true).text, 'Yeni');
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hızlı hücre tarayıcı, DOM yoluyla BİREBİR aynı modeli üretmeli.
Uint8List _book(String sheet, String sharedStrings) {
  ArchiveFile f(String n, String s) {
    final b = utf8.encode(s);
    return ArchiveFile(n, b.length, b);
  }

  final a = Archive()
    ..addFile(f('xl/workbook.xml',
        '<workbook xmlns:r="urn:r"><sheets><sheet name="A" r:id="rId1"/></sheets></workbook>'))
    ..addFile(f('xl/_rels/workbook.xml.rels',
        '<Relationships><Relationship Id="rId1" Target="worksheets/sheet1.xml"/></Relationships>'))
    ..addFile(f('xl/worksheets/sheet1.xml', sheet))
    ..addFile(f('xl/sharedStrings.xml', sharedStrings));
  return Uint8List.fromList(ZipEncoder().encode(a)!);
}

String _dump(XlsxWorkbook wb) {
  final out = StringBuffer();
  for (final s in wb.sheets) {
    out.writeln('${s.name} ${s.maxRow} ${s.maxCol} ${s.truncated} ${s.partPath} '
        '${s.rowHeights} ${s.hiddenRows} ${s.rowStyles} ${s.colWidths} '
        '${s.merges.length} ${s.autoFilterRef} ${s.frozenRows}');
    final keys = s.cells.keys.toList()..sort();
    for (final k in keys) {
      final c = s.cells[k]!;
      out.writeln('$k ${c.row} ${c.col} ${c.styleIndex} ${c.number} '
          '${jsonEncode(c.text)} ${c.boolean} ${c.error} ${jsonEncode(c.formula)} '
          '${c.runs?.map((r) => '${r.text}/${r.bold}/${r.italic}').join('|')}');
    }
  }
  return out.toString();
}

void main() {
  tearDown(() => XlsxReader.forceDom = false);

  void same(Uint8List bytes) {
    XlsxReader.forceDom = true;
    final dom = _dump(XlsxReader.read(bytes));
    XlsxReader.forceDom = false;
    expect(_dump(XlsxReader.read(bytes)), dom);
  }

  test('zorlu sayfa: varlıklar, satır içi, paylaşılan formül, sınır, öz. durum', () {
    const sheet = '''<?xml version="1.0"?><worksheet xmlns="m" xmlns:x14ac="x">
<cols><col min="1" max="2" width="12.5"/></cols>
<sheetData>
<row r="1" ht="30" customFormat="1" s="2" x14ac:dyDescent="0.25"><c r="A1" t="s"><v>0</v></c><c r="B1" t="s"><v>1</v></c><c r="C1" s="1"/><c r="D1"/></row>
<row r="2" hidden="1"><c r="A2"><v>1.5</v></c><c r="B2" t="b"><v>1</v></c><c r="C2" t="e"><v>#N/A</v></c><c r="D2" t="str"><f>"a&amp;b"&amp;"&lt;"</f><v>a&amp;b&lt;</v></c></row>
<row r="3"><c r="A3" t="inlineStr"><is><t xml:space="preserve"> x &#233;&#x11F; </t></is></c><c r="B3" t="inlineStr"><is><r><rPr><b/></rPr><t>ka</t></r><r><t>lın</t></r><rPh sb="0"><t>ph</t></rPh></is></c><c r="C3" t="inlineStr"><is/></c></row>
<row r="4"><c r="A4"><f t="shared" ref="A4:A6" si="0">B4+1</f><v>2</v></c></row>
<row r="5"><c r="A5"><f t="shared" si="0"/><v>3</v></c></row>
<row r="6"><c r="A6"><f t="shared" si="0"></f><v>4</v></c><c r="\$C\$6"><v>9</v></c><c r="BAD"><v>1</v></c><c><v>2</v></c><c r="XFE6"><v>3</v></c></row>
<row/>
<row r="7"/>
<row r="8"><c r="C9"><v/></c><c r="D8" t="d"><v>2026-01-02</v></c><c r="E8"><v>abc</v></c></row>
<row r="99999999"><c r="A99999999"><v>1</v></c></row>
<row r="99999998"/>
</sheetData>
<mergeCells><mergeCell ref="A1:B1"/></mergeCells><autoFilter ref="A1:C3"/></worksheet>''';
    const strings = '''<sst><si><t>düz &amp; ğ</t></si><si><r><rPr><b/></rPr><t>K</t></r><r><rPr><i/></rPr><t>ı</t></r></si>
<si/><si><t xml:space="preserve"> b </t><rPh sb="0" eb="1"><t>yok</t></rPh></si></sst>''';
    same(_book(sheet, strings));
  });

  test('yedek: CDATA ve ön ekli ad DOM yoluyla aynı okunur', () {
    same(_book(
        '<worksheet><sheetData><row r="1"><c r="A1" t="str"><v><![CDATA[<x>]]></v></c></row></sheetData></worksheet>',
        '<sst><si><t><![CDATA[a]]></t></si></sst>'));
    same(_book(
        '<x:worksheet xmlns:x="m"><x:sheetData><x:row r="1"><x:c r="A1"><x:v>5</x:v></x:c></x:row></x:sheetData></x:worksheet>',
        '<x:sst xmlns:x="m"><x:si><x:t>a</x:t></x:si></x:sst>'));
  });

  test('gerçek örnek dosyalar iki yolda aynı', () {
    final dir = Directory('test/fixtures/office');
    for (final f in dir.listSync(recursive: true).whereType<File>()) {
      if (f.path.endsWith('.xlsx')) same(f.readAsBytesSync());
    }
  });

  test('200 bin hücre DOM yolundan en az 3 kat hızlı', () {
    final sb = StringBuffer('<worksheet><sheetData>');
    for (var r = 1; r <= 10000; r++) {
      sb.write('<row r="$r">');
      for (var c = 0; c < 20; c++) {
        sb.write('<c r="${String.fromCharCode(65 + c)}$r"><v>${r * c}</v></c>');
      }
      sb.write('</row>');
    }
    sb.write('</sheetData></worksheet>');
    final bytes = _book(sb.toString(), '<sst/>');
    int run(bool dom) {
      XlsxReader.forceDom = dom;
      final w = Stopwatch()..start();
      final wb = XlsxReader.read(bytes);
      expect(wb.sheets.single.cells.length, 200000);
      return w.elapsedMilliseconds;
    }

    final dom = run(true);
    final fast = run(false);
    // ignore: avoid_print
    print('dom=$dom ms hızlı=$fast ms');
    expect(fast * 3, lessThan(dom));
  }, tags: 'perf', timeout: const Timeout(Duration(minutes: 3)));
}

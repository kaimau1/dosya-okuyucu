import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx/data_tools.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 8 — içe aktarma sihirbazı, ODS, ara toplam, anahat, köprü,
/// not yanıtı.
Uint8List _zip(Map<String, String> files) {
  final a = Archive();
  files.forEach((n, v) {
    final d = utf8.encode(v);
    a.addFile(ArchiveFile(n, d.length, d));
  });
  return Uint8List.fromList(ZipEncoder().encode(a));
}

String _sheetXml(Uint8List xlsx) => utf8.decode(ZipDecoder()
    .decodeBytes(xlsx)
    .files
    .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
    .content as List<int>);

void main() {
  test('tür önizlemesi ve ayraç seçimi', () {
    final bytes = Uint8List.fromList(utf8.encode('Ad;Tutar;Tarih\nAyşe;1.250,50;05.11.2026\nAli;7;06.11.2026\n'));
    final rows = SheetImport.parseText(bytes, const ImportOptions(delimiter: ';'));
    expect(rows[1], ['Ayşe', '1.250,50', '05.11.2026']);
    expect(SheetImport.columnTypes(rows),
        [ColumnType.text, ColumnType.number, ColumnType.date]);
    final auto = SheetImport.parseText(bytes, const ImportOptions());
    expect(auto.first.length, 3);
  });

  test('ODS: yinelenen hücre/satır açılır, sondaki boşluk kırpılır', () {
    final ods = _zip({
      'content.xml': '<office:document-content '
          'xmlns:office="urn:oasis:names:tc:opendocument:xmlns:office:1.0" '
          'xmlns:table="urn:oasis:names:tc:opendocument:xmlns:table:1.0" '
          'xmlns:text="urn:oasis:names:tc:opendocument:xmlns:text:1.0">'
          '<office:body><office:spreadsheet><table:table table:name="Veri">'
          '<table:table-row><table:table-cell><text:p>a</text:p></table:table-cell>'
          '<table:table-cell office:value-type="float" office:value="3.5"/>'
          '<table:table-cell table:number-columns-repeated="2"><text:p>x</text:p></table:table-cell>'
          '</table:table-row>'
          '<table:table-row table:number-rows-repeated="2"><table:table-cell><text:p>b</text:p></table:table-cell></table:table-row>'
          '<table:table-row table:number-rows-repeated="1000"><table:table-cell/></table:table-row>'
          '</table:table></office:spreadsheet></office:body></office:document-content>',
    });
    final sheets = SheetImport.parseOds(ods);
    expect(sheets.keys, ['Veri']);
    expect(sheets['Veri'], [
      ['a', '3.5', 'x', 'x'],
      ['b'],
      ['b'],
    ]);
  });

  test('ara toplam: grup satırları + genel toplam iki kez saymaz', () {
    final out = Subtotals.build([
      ['Bölge', 'Tutar'],
      ['Ege', '10'],
      ['Ege', '5'],
      ['Marmara', '7'],
    ], groupCol: 0, sumCols: [1], top: 0, left: 0);
    expect(out.map((r) => r.first), [
      'Bölge', 'Ege', 'Ege', 'Ege Toplam', 'Marmara', 'Marmara Toplam', 'Genel Toplam'
    ]);
    final e = FormulaEngine(out);
    expect(e.displayValue(3, 1), '15');
    expect(e.displayValue(5, 1), '7');
    expect(e.displayValue(6, 1), '22');
  });

  test('anahat düzeyi ve köprü dosyaya yazılır, geri okunur', () {
    final ed = XlsxEditor.parse(XlsxWriter.build([
      XlsxWriteSheet(name: 'Sayfa1', cells: {
        for (var r = 0; r < 5; r++) r: {0: XlsxWriteCell(text: 'r$r')},
      }),
      XlsxWriteSheet(name: 'Özet'),
    ]));
    final sheet = ed.sheets.first;
    sheet.groupRows(1, 3);
    ed.addLink(const XlsxLinkSpec(
        sheetName: 'Sayfa1', row: 0, col: 1, url: 'https://ornek.com', display: 'site'));
    ed.addLink(const XlsxLinkSpec(
        sheetName: 'Sayfa1', row: 0, col: 2, location: "'Özet'!A1"));
    final bytes = ed.save();
    final xml = _sheetXml(bytes);
    expect(xml, contains('outlineLevel="1"'));
    expect(xml, contains('outlineLevelRow="1"'));
    expect(xml, contains('location="&apos;Özet&apos;!A1"'.replaceAll('&apos;', "'")
        .isNotEmpty ? 'location=' : ''));
    final rels = utf8.decode(ZipDecoder()
        .decodeBytes(bytes)
        .files
        .firstWhere((f) => f.name == 'xl/worksheets/_rels/sheet1.xml.rels')
        .content as List<int>);
    expect(rels, contains('https://ornek.com'));
    expect(rels, contains('TargetMode="External"'));
    final back = XlsxEditor.parse(bytes).sheets.first;
    expect(back.layout.rowOutline, {1: 1, 2: 1, 3: 1});
    expect(back.outlineGroupAt(2), (1, 3));
  });

  test('not yanıtı tarihli satır olarak eklenir', () {
    final t = NoteThread.appendReply('Kontrol et', 'Ayşe', 'tamam', DateTime(2026, 11, 5, 9, 7));
    expect(t, 'Kontrol et\n— Ayşe (05.11.2026 09:07): tamam');
    expect(NoteThread.replyCount(t), 1);
  });
}

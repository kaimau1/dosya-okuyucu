import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Excel'in kaydettiği etkin sayfa (`activeTab`) ve etkin hücre okunur —
/// dosya bırakıldığı yerde açılsın (uyumluluk, gelistirme-office).
Uint8List _book() {
  final bytes = xlsxFrom({'A1': 1}, extraSheets: [
    XlsxWriteSheet(name: 'Özet', cells: {0: {0: const XlsxWriteCell(text: 'x')}}),
  ]);
  final archive = ZipDecoder().decodeBytes(bytes);
  final rebuilt = Archive();
  for (final f in archive.files) {
    var xml = utf8.decode(f.content as List<int>, allowMalformed: true);
    if (f.name == 'xl/workbook.xml') {
      xml = xml.replaceFirst(
          '<sheets>', '<bookViews><workbookView activeTab="1"/></bookViews><sheets>');
    } else if (f.name == 'xl/worksheets/sheet2.xml') {
      xml = xml.replaceFirst(
          '</sheetView>', '<selection activeCell="C5" sqref="C5"/></sheetView>');
    } else {
      rebuilt.addFile(f);
      continue;
    }
    final data = utf8.encode(xml);
    rebuilt.addFile(ArchiveFile(f.name, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(rebuilt));
}

void main() {
  test('activeTab ve activeCell okunur', () {
    final e = XlsxEditor.parse(_book());
    expect(e.workbook.activeTab, 1);
    expect(e.sheets[1].layout.activeCell, (4, 2));
    expect(e.sheets[0].layout.activeCell, isNull);
  });

  test('kayıtsız kitapta varsayılan ilk sayfa', () {
    expect(XlsxEditor.parse(xlsxFrom({'A1': 1})).workbook.activeTab, 0);
  });
}

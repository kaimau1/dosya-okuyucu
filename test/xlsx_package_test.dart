import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Faz 7 / D6 — `excel` paketi olmadan kaydetme: özgün paket korunur, yalnız
/// değişen parçalar yazılır.
Map<String, String> _parts(Uint8List bytes) => {
      for (final f in ZipDecoder().decodeBytes(bytes).files)
        if (f.isFile) f.name: utf8.decode(f.content as List<int>, allowMalformed: true),
    };

/// İki sayfalı kitap + tanımadığımız bir parça (grafik yerine sahte) +
/// calcChain + yerel ad.
Uint8List _book() {
  final base = xlsxFrom({'A1': 'bir', 'B1': 1}, extraSheets: [
    XlsxWriteSheet(name: 'İki', cells: {
      0: {0: const XlsxWriteCell(text: 'iki')},
    }),
  ]);
  final archive = ZipDecoder().decodeBytes(base);
  final out = Archive();
  for (final f in archive.files) {
    if (f.name == 'xl/workbook.xml') {
      final xml = utf8.decode(f.content as List<int>).replaceFirst('</sheets>',
          '</sheets><definedNames><definedName name="Yerel" localSheetId="1">\'İki\'!\$A\$1</definedName></definedNames>');
      final d = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, d.length, d));
    } else if (f.name == 'xl/_rels/workbook.xml.rels') {
      final xml = utf8.decode(f.content as List<int>).replaceFirst('</Relationships>',
          '<Relationship Id="rId99" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/calcChain" Target="calcChain.xml"/></Relationships>');
      final d = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, d.length, d));
    } else {
      out.addFile(f);
    }
  }
  for (final (name, text) in [
    ('xl/calcChain.xml', '<calcChain/>'),
    ('xl/charts/chart1.xml', '<chartSpace>GRAFİK</chartSpace>'),
  ]) {
    final d = utf8.encode(text);
    out.addFile(ArchiveFile(name, d.length, d));
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

void main() {
  test('değer düzenleyip kaydetmek tanımadığımız parçaları baytı baytına taşır', () {
    final e = XlsxEditor.parse(_book());
    e.setCell(e.sheets.first.name, 2, 0, 'yeni');
    final parts = _parts(e.save());
    expect(parts['xl/charts/chart1.xml'], '<chartSpace>GRAFİK</chartSpace>');
    expect(parts.containsKey('xl/calcChain.xml'), isFalse,
        reason: 'bayat hesap zinciri Excel\'de onarım sorusu çıkarır');
    expect(parts['xl/workbook.xml'], contains('fullCalcOnLoad="1"'));
    final back = XlsxEditor.parse(e.save());
    expect(back.sheets.first.rawAt(2, 0), 'yeni');
    expect(back.sheets.first.rawAt(0, 1), '1');
    expect(back.sheets[1].rawAt(0, 0), 'iki');
  });

  test('sayfa taşıma: sıra ve yerel adın localSheetId\'si birlikte değişir', () {
    final e = XlsxEditor.parse(_book());
    expect(e.moveSheet('İki', 0), isTrue);
    final bytes = e.save();
    final back = XlsxEditor.parse(bytes);
    expect(back.sheets.map((s) => s.name), ['İki', 'Sheet1']);
    expect(back.sheets.first.rawAt(0, 0), 'iki');
    expect(_parts(bytes)['xl/workbook.xml'], contains('localSheetId="0"'));
  });

  test('yeniden adlandırma + yeni sayfa + silme', () {
    final e = XlsxEditor.parse(_book());
    expect(e.renameSheet('Sheet1', 'Gelir'), isTrue);
    final added = e.addSheet('Yeni')!;
    e.setCell(added.name, 0, 0, '=1+2');
    expect(e.deleteSheet('İki'), isTrue);
    final bytes = e.save();
    final back = XlsxEditor.parse(bytes);
    expect(back.sheets.map((s) => s.name), ['Gelir', 'Yeni']);
    expect(back.sheets[1].rawAt(0, 0), '=1+2');
    // Silinen sayfanın yerel adı da gider (geçersiz localSheetId kalmaz).
    expect(_parts(bytes)['xl/workbook.xml'], isNot(contains('localSheetId')));
  });

  test('satır ekleme sonrası değerler ve sayılar doğru yerde', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 'baş', 'A2': 5, 'A3': '007'}));
    final name = e.sheets.first.name;
    e.insertRow(name, 1);
    final back = XlsxEditor.parse(e.save()).sheets.first;
    expect(back.rawAt(0, 0), 'baş');
    expect(back.rawAt(1, 0), '');
    expect(back.rawAt(2, 0), '5');
    expect(back.isNumericAt(2, 0), isTrue);
    expect(back.rawAt(3, 0), '007', reason: 'baştaki sıfır metin kalır');
  });

  test('boş editör geçerli bir dosya yazar', () {
    final e = XlsxEditor.blank();
    e.setCell('Sayfa1', 0, 0, 'merhaba');
    final back = XlsxEditor.parse(e.save());
    expect(back.sheets.single.rawAt(0, 0), 'merhaba');
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/sheet_edit.dart' show sortRowOrder;
import 'package:dosya_okuyucu/services/sheet_structure.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Faz 25 / X3 — satır/sütun ekle-silde başvuru kaydırma.
const _ins5 = SheetShift(rows: true, at: 4, delta: 1); // 5. satırın önüne
const _del3 = SheetShift(rows: true, at: 2, delta: -1); // 3. satırı sil
const _insB = SheetShift(rows: false, at: 1, delta: 1); // B'nin önüne

String _f(String f, SheetShift op, {String cur = 'S', String tgt = 'S'}) =>
    shiftFormulaStructural(f, op, currentSheet: cur, targetSheet: tgt);

Map<String, String> _parts(Uint8List b) => {
      for (final f in ZipDecoder().decodeBytes(b).files)
        if (f.isFile) f.name: utf8.decode(f.content as List<int>, allowMalformed: true),
    };

/// Koşullu biçim + doğrulama + köprü + not + tanımlı ad içeren kitap.
Uint8List _rich() {
  final base = xlsxFrom({
    'A1': 1, 'A2': 2, 'A3': 3, 'A4': 4, 'A5': 5,
  }, extraSheets: [
    XlsxWriteSheet(name: 'Özet', cells: {0: {0: const XlsxWriteCell(text: 'x')}}),
  ]);
  final a = ZipDecoder().decodeBytes(base);
  final out = Archive();
  for (final f in a.files) {
    var d = f.content as List<int>;
    if (f.name == 'xl/worksheets/sheet1.xml') {
      var x = utf8.decode(d);
      x = x.replaceFirst('</sheetData>',
          '</sheetData><conditionalFormatting sqref="A3:A5"><cfRule type="expression" priority="1" dxfId="0"><formula>A3&gt;\$A\$4</formula></cfRule></conditionalFormatting>'
          '<conditionalFormatting sqref="A3"><cfRule type="expression" priority="2"><formula>TRUE</formula></cfRule></conditionalFormatting>'
          '<dataValidations count="1"><dataValidation type="whole" sqref="A2:A4"><formula1>0</formula1></dataValidation></dataValidations>');
      d = utf8.encode(x);
    } else if (f.name == 'xl/workbook.xml') {
      d = utf8.encode(utf8.decode(d).replaceFirst('</sheets>',
          '</sheets><definedNames><definedName name="Veri">Sheet1!\$A\$2:\$A\$5</definedName></definedNames>'));
    }
    out.addFile(ArchiveFile(f.name, d.length, d));
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

void main() {
  group('shiftFormulaStructural', () {
    final cases = <(String, SheetShift, String)>[
      ('SUM(A1:A10)', _ins5, 'SUM(A1:A11)'),
      (r'SUM($A$1:$A$10)', _ins5, r'SUM($A$1:$A$11)'),
      ('A3+A5', _ins5, 'A3+A6'),
      ('A3+A5', _del3, '#REF!+A4'),
      ('SUM(A1:A10)', _del3, 'SUM(A1:A9)'),
      ('SUM(A3:A3)', _del3, 'SUM(#REF!)'),
      ('B2*C2', _insB, 'C2*D2'),
      ('A1&"A5"', _ins5, 'A1&"A5"'),
      ('SUM(A:A)', _ins5, 'SUM(A:A)'),
      ('SUM(B:C)', _insB, 'SUM(C:D)'),
      ('SUM(5:7)', _ins5, 'SUM(6:8)'),
      ('LOG10(A6)', _ins5, 'LOG10(A7)'),
      ('Diğer!A6+A6', _ins5, 'Diğer!A6+A7'),
    ];
    for (final (input, op, out) in cases) {
      test('$input  [$op]', () => expect(_f(input, op), out));
    }
    test('başka sayfadan bu sayfaya nitelenmiş başvuru kayar', () {
      expect(_f('S!A6+A6', _ins5, cur: 'Diğer'), 'S!A7+A6');
      expect(_f("'Gelir Tablosu'!A6", _ins5, cur: 'X', tgt: 'Gelir Tablosu'),
          "'Gelir Tablosu'!A7");
    });
    test('sqref', () {
      expect(shiftSqref('A3:A5 C7', _ins5), 'A3:A6 C8');
      expect(shiftSqref('A3', _del3), isNull);
    });
  });

  test('satır ekleyince =TOPLA(A1:A5) → A1:A6; silinen hücreye başvuru #BAŞV!', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 1, 'A2': 2, 'A3': 3}));
    final s = e.sheets.first.name;
    e.setCell(s, 5, 0, '=TOPLA(A1:A5)');
    e.setCell(s, 5, 1, '=A3*2');
    e.insertRow(s, 1);
    expect(e.sheets.first.rawAt(6, 0), '=TOPLA(A1:A6)');
    expect(e.sheets.first.rawAt(6, 1), '=A4*2');
    e.deleteRow(s, 3); // A4 (eski A3) silinir
    expect(e.sheets.first.rawAt(5, 1), '=#REF!*2');
    final eng = FormulaEngine(e.sheets.first.rows);
    expect(eng.displayValue(5, 1), '#BAŞV!');
  });

  test('başka sayfadaki formül de kayar', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 1}, extraSheets: [
      XlsxWriteSheet(name: 'Özet', cells: {0: {0: const XlsxWriteCell(text: 'x')}}),
    ]));
    final s = e.sheets.first.name;
    e.setCell('Özet', 0, 1, '=$s!A5+A5');
    e.insertRow(s, 0);
    expect(e.sheets[1].rawAt(0, 1), '=$s!A6+A5');
  });

  test('birleştirme ve süzgeç aralığı kayar', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 'b'},
        merges: [const XlsxWriteMerge(2, 0, 3, 1)]));
    final s = e.sheets.first;
    s.layout.autoFilterRef = 'A1:B9';
    e.insertRow(s.name, 1);
    expect(s.merges.single.rowStart, 3);
    expect(s.layout.autoFilterRef, 'A1:B10');
  });

  test('kayıtta özgün XML: koşullu biçim, doğrulama ve tanımlı ad kayar', () {
    final e = XlsxEditor.parse(_rich());
    final s = e.sheets.first.name;
    e.deleteRow(s, 2); // A3 silinir
    final p = _parts(e.save());
    final x = p['xl/worksheets/sheet1.xml']!;
    expect(x, contains('sqref="A3:A4"'), reason: 'A3:A5 → A3:A4');
    expect(x, matches(RegExp(r'A3(&gt;|>)\$A\$3')),
        reason: 'çapası silinen kural formülü yeni çapaya göre');
    expect(x, isNot(contains('priority="2"')), reason: 'yalnız A3 olan kural kalkar');
    expect(x, contains('<dataValidation type="whole" sqref="A2:A3">'));
    expect(p['xl/workbook.xml'], contains(r'Sheet1!$A$2:$A$4'));
    // Yeniden açılınca görünüm modeli de tutarlı.
    final back = XlsxEditor.parse(e.save());
    expect(back.sheets.first.layout.condFormats, hasLength(1));
  });

  test('geri al: ekle+tersi formülleri, birleştirmeyi ve kayıt günlüğünü aynen geri koyar', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 1, 'A2': 2, 'A3': 3},
        merges: [const XlsxWriteMerge(2, 0, 2, 1)]));
    final s = e.sheets.first.name;
    e.setCell(s, 4, 0, '=A3+A2');
    final snapRow = e.captureRow(s, 2);
    final struct = e.captureStructure(s);
    e.deleteRow(s, 2);
    expect(e.sheets.first.rawAt(3, 0), '=#REF!+A2');
    e.insertRow(s, 2);
    e.restoreRow(s, 2, snapRow);
    e.restoreStructure(struct);
    expect(e.sheets.first.rawAt(4, 0), '=A3+A2');
    expect(e.sheets.first.merges.single.rowStart, 2);
    expect(e.sheets.first.structuralOps, isEmpty);
  });

  test('sıralama formülün SONUCUYLA (X4) ve kararlı', () {
    // Satır 1..4: =A9*2 (sonuç 10), 3, =B1 (sonuç 3), "elma"
    final order = sortRowOrder({1: '10', 2: '3', 3: '3', 4: 'elma'},
        ascending: true);
    expect(order, [2, 3, 1, 4]);
    expect(sortRowOrder({1: '10', 2: '9'}, ascending: false), [1, 2]);
  });
}

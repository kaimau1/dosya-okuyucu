import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Faz 20 / X1 — Türkçe yazılmış formül dosyaya İngilizce + `,` yazılır;
/// yoksa masaüstü Excel `#AD?` gösterir.
String _sheetXml(Uint8List bytes) {
  final f = ZipDecoder()
      .decodeBytes(bytes)
      .files
      .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml');
  return utf8.decode(f.content as List<int>);
}

void main() {
  group('toFileFormula', () {
    final cases = <String, String>{
      'EĞER(A1>0;"a;b";TOPLA(B1:B3))': 'IF(A1>0,"a;b",SUM(B1:B3))',
      'TOPLA(A1;A2)': 'SUM(A1,A2)',
      'SUM(A1,A2)': 'SUM(A1,A2)',
      'A1*0,5+TOPLA(1;2)': 'A1*0.5+SUM(1,2)',
      'DÜŞEYARA(A1;Sayfa2!A:B;2;YANLIŞ)': 'VLOOKUP(A1,Sayfa2!A:B,2,FALSE)',
      "TOPLA('Gelir Tablosu'!B1:B9)": "SUM('Gelir Tablosu'!B1:B9)",
      'ÇOKEĞER(A1>1;"x";DOĞRU;"y")': '_xlfn.IFS(A1>1,"x",TRUE,"y")',
      'ÇAPRAZARA(A1;B:B;C:C)': '_xlfn.XLOOKUP(A1,B:B,C:C)',
      'STDEV.S(A1:A9)': '_xlfn.STDEV.S(A1:A9)',
      '_xlfn.IFS(A1>1,1,TRUE,2)': '_xlfn.IFS(A1>1,1,TRUE,2)',
      'BENİMİŞLEVİM(A1)': 'BENİMİŞLEVİM(A1)',
      r'yuvarla($A$1;2)': r'ROUND($A$1,2)',
      'BİRLEŞTİR("ü;ş";"""x;y""")': 'CONCATENATE("ü;ş","""x;y""")',
      'ROUND(A1,2)': 'ROUND(A1,2)',
    };
    cases.forEach((input, expected) {
      test(input, () => expect(FormulaEngine.toFileFormula(input), expected));
    });
  });

  test('motor Türkçe ondalık virgülü (`;` yazımında) sayı olarak okur', () {
    final e = FormulaEngine([
      ['=TOPLA(1,5;2)'],
    ]);
    expect(e.displayValue(0, 0), '3.5');
  });

  test('motor _xlfn. önekli işlevi tanır', () {
    final e = FormulaEngine([
      ['=_xlfn.IFS(1>2,"a",TRUE,"b")'],
    ]);
    expect(e.displayValue(0, 0), 'b');
  });

  test('kaydedilen <f> İngilizce; yeniden açınca aynı sonuç', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 1, 'A2': 2}));
    final sheet = e.sheets.first.name;
    e.setCell(sheet, 2, 0, '=EĞER(A1>0;"a;b";TOPLA(A1:A2))');
    final bytes = e.save();
    final xml = _sheetXml(bytes);
    expect(xml, contains('<f>IF(A1&gt;0,&quot;a;b&quot;,SUM(A1:A2))</f>'));
    expect(xml, isNot(contains('TOPLA')));
    final back = XlsxEditor.parse(bytes);
    final eng = FormulaEngine(back.sheets.first.rows);
    expect(eng.displayValue(2, 0), 'a;b');
  });
}

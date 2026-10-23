import 'package:dosya_okuyucu/services/calc_log.dart';
import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/xlsx_fixture.dart';

/// Faz 26 — kalıcı hesap durumu: değer önbelleği + bağımlılık grafiği.
void main() {
  FormulaEngine eng(List<List<String>> g, CalcState st,
          [Map<String, List<List<String>>>? all, String name = 'S']) =>
      FormulaEngine(g, sheetName: name, sheets: all ?? {name: g}, state: st);

  test('sayfasız başvuru formülün KENDİ sayfasına gider (çapraz sayfa hatası)', () {
    final s1 = [['=Sayfa2!B1']];
    final s2 = [['', '=C1*2', '5']];
    final e = FormulaEngine(s1,
        sheetName: 'Sayfa1', sheets: {'Sayfa1': s1, 'Sayfa2': s2});
    expect(e.displayValue(0, 0), '10'); // eskiden 0: Sayfa1!C1 okunuyordu
  });

  test('hücre değişince YALNIZ bağımlıları yeniden hesaplanır (sayaç)', () {
    final g = <List<String>>[
      for (var i = 0; i < 1000; i++) ['${i + 1}', '=A${i + 1}*2'],
    ];
    g[0].add('=SUM(B1:B1000)');
    final st = CalcState();
    final e = eng(g, st);
    expect(e.displayValue(0, 2), '${1001000}');
    expect(st.evaluations, 1001);
    // Görünen her hücreyi yeniden istemek hesap YAPMAZ.
    for (var r = 0; r < 1000; r++) {
      e.displayValue(r, 1);
    }
    expect(st.evaluations, 1001);
    // A5: 5 → 105
    g[4][0] = '105';
    expect(st.invalidate('S', 4, 0), 2); // B5 + C1
    for (var r = 0; r < 1000; r++) {
      eng(g, st).displayValue(r, 1);
    }
    expect(eng(g, st).displayValue(0, 2), '${1001000 + 200}');
    expect(st.evaluations, 1003);
  });

  test('10 bin halkalı zincir: satır sırasıyla ısınır, yığın taşmaz', () {
    final g = <List<String>>[
      ['1'],
      for (var i = 1; i < 10000; i++) ['=A$i+1'],
    ];
    final st = CalcState()..warmUp({'S': g});
    expect(eng(g, st).displayValue(9999, 0), '10000');
    g[0][0] = '11';
    expect(st.invalidate('S', 0, 0), 9999);
    // Yeniden ısınma (ekran bunu tembelce yapar; burada sırayla).
    st.warmUp({'S': g});
    expect(eng(g, st).displayValue(9999, 0), '10010');
  });

  test('döngü #DÖNGÜ; döngü kırılınca doğru değer', () {
    final g = [['=B1', '=A1']];
    final st = CalcState();
    expect(eng(g, st).displayValue(0, 0), '#DÖNGÜ');
    g[0][1] = '7';
    st.invalidate('S', 0, 1);
    expect(eng(g, st).displayValue(0, 0), '7');
  });

  test('KAYDIR / DOLAYLI: hesapta okunan aralık bağımlılık olur', () {
    final g = [
      ['1', '3', '=SUM(OFFSET(A1,0,0,B1,1))', '=INDIRECT("A"&B1)'],
      ['2'],
      ['4'],
    ];
    final st = CalcState();
    expect(eng(g, st).displayValue(0, 2), '7');
    expect(eng(g, st).displayValue(0, 3), '4');
    g[2][0] = '10';
    st.invalidate('S', 2, 0);
    expect(eng(g, st).displayValue(0, 2), '13');
    expect(eng(g, st).displayValue(0, 3), '10');
  });

  test('uçucu işlev her değişiklikte geçersiz', () {
    final g = [['=RAND()', '=A1*0+1', '5']];
    final st = CalcState();
    eng(g, st).displayValue(0, 1);
    final n = st.evaluations;
    st.invalidateVolatile();
    eng(g, st).displayValue(0, 1);
    expect(st.evaluations, n + 2); // RAND + ona bakan B1
  });

  test('sayfa adı büyük/küçük harf duyarsız: değişiklik doğru formülü bulur', () {
    final s1 = [['=sayfa2!A1*2']];
    final s2 = [['4']];
    final all = {'Sayfa1': s1, 'Sayfa2': s2};
    final st = CalcState();
    expect(eng(s1, st, all, 'Sayfa1').displayValue(0, 0), '8');
    s2[0][0] = '5';
    expect(st.invalidate('Sayfa2', 0, 0), 1);
    expect(eng(s1, st, all, 'Sayfa1').displayValue(0, 0), '10');
  });

  test('model günlüğü: setCell hücre, yapısal işlem toplu kayıt düşer', () {
    final editor = XlsxEditor.parse(xlsxFrom({'A1': 1, 'B1': '=A1*2'}));
    final CalcLog log = editor.calcLog;
    final name = editor.sheets.first.name;
    editor.setCell(name, 0, 0, '3');
    expect(log.cells, [(name, 0, 0)]);
    editor.setCell(name, 0, 0, '3'); // aynı değer: kayıt yok
    expect(log.cells.length, 1);
    final gen = log.generation;
    editor.insertRow(name, 0);
    expect(log.generation, gen + 1);
    expect(log.cells, isEmpty);
  });

  test('kaydette formüllerin <v> önbellek değeri yazılır', () {
    final editor = XlsxEditor.parse(xlsxFrom({'A1': 2, 'A2': 3}));
    final name = editor.sheets.first.name;
    editor.setCell(name, 0, 1, '=SUM(A1:A2)');
    editor.setCell(name, 1, 1, '=1/0');
    editor.setCell(name, 2, 1, '=A1>1');
    editor.setCell(name, 3, 1, '="a"&"b"');
    final zip = ZipDecoder().decodeBytes(editor.save());
    final xml = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
    expect(xml, contains('<c r="B1"><f>SUM(A1:A2)</f><v>5</v></c>'));
    expect(xml, contains('<c r="B2" t="e"><f>1/0</f><v>#DIV/0!</v></c>'));
    expect(xml, contains('<c r="B3" t="b"><f>A1&gt;1</f><v>1</v></c>'));
    expect(xml, contains('<c r="B4" t="str"><f>&quot;a&quot;&amp;&quot;b&quot;</f><v>ab</v></c>'));
  });
}

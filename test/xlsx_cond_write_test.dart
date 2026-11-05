import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 2 (A7.5) — koşullu biçim YAZMA: renk ölçeği, veri çubuğu,
/// simge kümesi, formül kuralı; kaydet → yeniden aç gidiş-dönüşü.
void main() {
  XlsxEditor book() => XlsxEditor.parse(XlsxWriter.build([
        XlsxWriteSheet(name: 'Sayfa1', cells: {
          for (var r = 0; r < 5; r++)
            r: {0: XlsxWriteCell(number: (r + 1) * 10.0)},
        }),
      ]));

  test('dört görsel/formül kuralı yazılır ve aynen okunur', () {
    final ed = book();
    final sheet = ed.sheets.first;
    const range = XlsxRange(0, 0, 4, 0);
    sheet.addCondRule(
        range: range,
        type: 'colorScale',
        scaleColors: const [0xFFF8696B, 0xFFFFEB84, 0xFF63BE7B]);
    sheet.addCondRule(range: range, type: 'dataBar', barColorArgb: 0xFF638EC6);
    sheet.addCondRule(range: range, type: 'iconSet', iconSet: '3TrafficLights1');
    sheet.addCondRule(
        range: range, type: 'expression', formulas: const ['A1>25'], fillArgb: 0xFFFFC7CE);
    final back = XlsxEditor.parse(ed.save()).sheets.first.layout.condFormats;
    final byType = {for (final r in back) r.type: r};
    expect(byType.keys, containsAll(['colorScale', 'dataBar', 'iconSet', 'expression']));
    expect(byType['colorScale']!.scaleColors, [0xFFF8696B, 0xFFFFEB84, 0xFF63BE7B]);
    expect(byType['dataBar']!.barColorArgb, 0xFF638EC6);
    expect(byType['iconSet']!.iconSet, '3TrafficLights1');
    expect(byType['expression']!.formulas, ['A1>25']);
    expect(byType['expression']!.dxfId, isNotNull);
    // Görsel kurallar dxf kullanmaz.
    expect(byType['colorScale']!.dxfId, isNull);
  });

  test('geri alma: görsel kural kaldırılınca dosyaya yazılmaz', () {
    final ed = book();
    final sheet = ed.sheets.first;
    final rule = sheet.addCondRule(
        range: const XlsxRange(0, 0, 4, 0), type: 'dataBar', barColorArgb: 0xFF63C384);
    sheet.removeCondRule(rule);
    final back = XlsxEditor.parse(ed.save()).sheets.first.layout.condFormats;
    expect(back.where((r) => r.type == 'dataBar'), isEmpty);
  });

  test('yönetici: dosyadaki kural silinir, geri alınınca yerinde kalır', () {
    final ed = book();
    ed.sheets.first.addCondRule(
        range: const XlsxRange(0, 0, 4, 0), type: 'dataBar', barColorArgb: 0xFF638EC6);
    ed.sheets.first.addCondRule(
        range: const XlsxRange(0, 0, 0, 0), type: 'iconSet', iconSet: '3Arrows');
    final saved = ed.save();

    final ed2 = XlsxEditor.parse(saved);
    final s2 = ed2.sheets.first;
    expect(s2.layout.condFormats.length, 2);
    final bar = s2.layout.condFormats.firstWhere((r) => r.type == 'dataBar');
    s2.deleteCondRule(bar);
    final back = XlsxEditor.parse(ed2.save()).sheets.first.layout.condFormats;
    expect(back.map((r) => r.type), ['iconSet']);

    final ed3 = XlsxEditor.parse(saved);
    final s3 = ed3.sheets.first;
    final undo = s3.deleteCondRule(s3.layout.condFormats.first);
    undo();
    expect(XlsxEditor.parse(ed3.save()).sheets.first.layout.condFormats.length, 2);
  });

  test('yönetici: oturumda eklenen ortadaki kural silinir', () {
    final ed = book();
    final sheet = ed.sheets.first;
    const range = XlsxRange(0, 0, 4, 0);
    sheet.addCondRule(range: range, type: 'dataBar', barColorArgb: 0xFF638EC6);
    final mid = sheet.addCondRule(range: range, type: 'iconSet', iconSet: '3Arrows');
    sheet.addCondRule(
        range: range, type: 'colorScale', scaleColors: const [0xFFFFFFFF, 0xFF5A8AC6]);
    sheet.deleteCondRule(mid);
    final back = XlsxEditor.parse(ed.save()).sheets.first.layout.condFormats;
    expect(back.map((r) => r.type).toSet(), {'dataBar', 'colorScale'});
  });
}

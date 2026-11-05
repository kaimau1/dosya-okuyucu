import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
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
}

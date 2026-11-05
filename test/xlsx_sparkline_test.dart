import 'dart:convert';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart' show paintSparkline;
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 3 — mini grafik: `x14:sparklineGroups` yaz → oku, çizim.
void main() {
  XlsxEditor book() => XlsxEditor.parse(XlsxWriter.build([
        XlsxWriteSheet(name: 'Satış', cells: {
          0: {
            for (var c = 0; c < 5; c++) c: XlsxWriteCell(number: (c * 3 % 7).toDouble()),
          },
        }),
      ]));

  test('mini grafik dosyaya yazılır ve geri okunur', () {
    final ed = book();
    final sheet = ed.sheets.first;
    sheet.addSparkline(
        source: const XlsxRange(0, 0, 0, 4), row: 0, col: 5, type: 'column');
    final bytes = ed.save();
    final xml = utf8.decode(ZipDecoder()
        .decodeBytes(bytes)
        .files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>);
    expect(xml, contains('sparklineGroup'));
    expect(xml, contains('Satış!A1:E1'));
    final back = XlsxEditor.parse(bytes).sheets.first;
    final sp = back.sparklineAt(0, 5)!;
    expect(sp.type, 'column');
    expect(sp.range!.c2, 4);
    expect(sp.sheet, 'Satış');
  });

  test('geri alınan mini grafik yazılmaz', () {
    final ed = book();
    final sheet = ed.sheets.first;
    final sp = sheet.addSparkline(
        source: const XlsxRange(0, 0, 0, 4), row: 0, col: 5);
    sheet.removeSparkline(sp);
    expect(XlsxEditor.parse(ed.save()).sheets.first.sparklineAt(0, 5), isNull);
  });

  test('çizim: çizgi/sütun/kazanç-kayıp boş değerle çökmez', () {
    final rec = PictureRecorder();
    final canvas = Canvas(rec);
    for (final t in ['line', 'column', 'stacked']) {
      paintSparkline(canvas, const Rect.fromLTWH(0, 0, 60, 16),
          [1, double.nan, -2, 3], t, const Color(0xFF376092));
    }
    paintSparkline(canvas, const Rect.fromLTWH(0, 0, 60, 16), [double.nan], 'line',
        const Color(0xFF376092));
    rec.endRecording().dispose();
  });
}

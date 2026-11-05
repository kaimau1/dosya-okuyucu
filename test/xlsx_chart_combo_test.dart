import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/widgets/chart_insert_dialog.dart' show chartPreviewOf;
import 'package:dosya_okuyucu/widgets/chart_painter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/xlsx_fixture.dart';

/// Faz 36 madde 11 — kombinasyon, ikincil eksen, eğilim çizgisi, stil.
void main() {
  XlsxChartSpec spec() {
    final e = XlsxEditor.parse(xlsxFrom({
      'A1': 'Ay', 'B1': 'Satış', 'C1': 'Oran',
      'A2': 'Ocak', 'B2': 120, 'C2': 0.4,
      'A3': 'Şubat', 'B3': 150, 'C3': 0.6,
      'A4': 'Mart', 'B4': 90, 'C4': 0.5,
    }));
    final sheet = e.sheets.first;
    return XlsxChartSpec.fromRange(
      sheetName: sheet.name,
      kind: XlsxChartKind.column,
      top: 0, left: 0, bottom: 3, right: 2,
      display: sheet.rawAt,
    )!;
  }

  test('kombinasyon + ikincil eksen: çubuk ve çizgi ayrı eksen çiftinde', () {
    final s = spec().copyWith(combo: true, secondaryAxis: true, trendline: true, style: 2);
    expect(s.isCombo, isTrue);
    final xml = XmlDocument.parse(XlsxChartWriter.chartXml(s));
    final bar = xml.findAllElements('c:barChart').single;
    final line = xml.findAllElements('c:lineChart').single;
    expect(bar.findAllElements('c:ser'), hasLength(1));
    expect(line.findAllElements('c:ser'), hasLength(1));
    expect(line.findAllElements('c:axId').map((e) => e.getAttribute('val')),
        ['5000003', '5000004']);
    expect(xml.findAllElements('c:valAx'), hasLength(2));
    expect(xml.findAllElements('c:trendline'), hasLength(2));
    // Stil 2'nin ilk rengi.
    expect(XlsxChartWriter.chartXml(s), contains(XlsxChartWriter.styles[2][0]));
  });

  test('önizleme: son seri çizgi + ikincil, eğilim her seride', () {
    final s = spec().copyWith(combo: true, secondaryAxis: true, trendline: true);
    final vm = chartPreviewOf(s);
    expect(vm.series.last.asLine, isTrue);
    expect(vm.series.last.secondary, isTrue);
    expect(vm.series.first.asLine, isFalse);
    expect(vm.series.every((x) => x.trend), isTrue);
  });

  test('doğrusal uydurma', () {
    final fit = ChartPainter.linearFit([1, 3, 5, 7])!;
    expect(fit.$1, closeTo(1, 1e-9));
    expect(fit.$2, closeTo(2, 1e-9));
    expect(ChartPainter.linearFit([4]), isNull);
  });
}

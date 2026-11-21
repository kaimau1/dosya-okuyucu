import 'dart:convert';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/widgets/chart_insert_dialog.dart';
import 'package:dosya_okuyucu/widgets/chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/office_fixtures.dart';

/// B10 m.1 — grafik türleri: alan, dağılım (XY), halka, radar, yığılmış /
/// %100 yığılmış sütun-çubuk. Tür başına YAZ (xlsx) → OKU (ortak ayrıştırıcı,
/// slaytla aynı) → ÇİZ (ortak `ChartPainter`). Dosyadaki bilinmeyen tür en
/// yakın türle + "yaklaşık" rozetiyle çizilir (önceden hiç çizilmiyordu).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  void paint(ChartVM vm) {
    final rec = ui.PictureRecorder();
    ChartPainter(vm).paint(Canvas(rec), const Size(400, 260));
    rec.endRecording().dispose();
  }

  const expected = {
    XlsxChartKind.columnStacked: (ChartType.column, ChartGrouping.stacked, 'c:barChart'),
    XlsxChartKind.columnPercent: (ChartType.column, ChartGrouping.percent, 'c:barChart'),
    XlsxChartKind.barStacked: (ChartType.bar, ChartGrouping.stacked, 'c:barChart'),
    XlsxChartKind.barPercent: (ChartType.bar, ChartGrouping.percent, 'c:barChart'),
    XlsxChartKind.area: (ChartType.area, ChartGrouping.standard, 'c:areaChart'),
    XlsxChartKind.doughnut: (ChartType.pie, ChartGrouping.standard, 'c:doughnutChart'),
    XlsxChartKind.scatter: (ChartType.scatter, ChartGrouping.standard, 'c:scatterChart'),
    XlsxChartKind.radar: (ChartType.radar, ChartGrouping.standard, 'c:radarChart'),
  };

  for (final MapEntry(key: kind, value: (type, grouping, tag)) in expected.entries) {
    test('${kind.name}: yaz → oku → çiz', () {
      final e = XlsxEditor.parse(OfficeFixtures.xlsxSales());
      final sheet = e.sheets.first;
      final spec = XlsxChartSpec.fromRange(
        sheetName: sheet.name,
        kind: kind,
        top: 0, left: 0, bottom: 3, right: 2,
        display: sheet.rawAt,
      )!;
      final xml = XlsxChartWriter.chartXml(spec);
      expect(xml, contains('<$tag>'));
      expect(() => XmlDocument.parse(xml), returnsNormally);
      // Excel sabit RGB yazar (tema rengi yalnız slayt bağlamında).
      expect(xml, contains('<a:srgbClr val="${XlsxChartWriter.palette[0]}"/>'));
      expect(xml, isNot(contains('schemeClr')));
      if (grouping == ChartGrouping.percent) {
        expect(xml, contains('<c:grouping val="percentStacked"/>'));
        expect(xml, contains('<c:overlap val="100"/>'));
      }
      if (kind == XlsxChartKind.radar) expect(xml, isNot(contains('c:smooth')));
      if (kind == XlsxChartKind.area) {
        expect(xml, isNot(contains('invertIfNegative')));
      }

      e.addChart(spec);
      final vm = XlsxEditor.parse(e.save()).fileCharts.single.chart;
      expect(vm.type, type);
      expect(vm.grouping, grouping);
      expect(vm.doughnut, kind == XlsxChartKind.doughnut);
      expect(vm.approx, isFalse);
      expect(vm.series, isNotEmpty);
      expect(vm.series.first.values, [120, 150, 90]);
      paint(vm);
      paint(chartPreviewOf(spec));
    });
  }

  test('dağılım: sayısal X sütunu xVal olarak yazılır ve okunur', () {
    const grid = [
      ['X', 'Y'],
      ['1', '10'],
      ['3', '30'],
      ['7', '20'],
    ];
    final spec = XlsxChartSpec.fromRange(
      sheetName: 'S',
      kind: XlsxChartKind.scatter,
      top: 0, left: 0, bottom: 3, right: 1,
      display: (r, c) => grid[r][c],
    )!;
    expect(spec.series.single.values, [10, 30, 20]);
    final xml = XlsxChartWriter.chartXml(spec);
    expect(xml, contains('<c:xVal><c:numRef>'));
    expect(xml, contains('<c:yVal>'));
    final vm = _parse(xml)!;
    expect(vm.series.single.xValues, [1, 3, 7]);
    expect(vm.series.single.asLine, isFalse, reason: 'yalnız işaretçi');
    expect(chartPreviewOf(spec).series.single.xValues, [1, 3, 7]);
  });

  group('bilinmeyen tür → en yakın tür + yaklaşık', () {
    String chart(String body) =>
        '<c:chartSpace xmlns:c="http://schemas.openxmlformats.org/drawingml/2006/chart" '
        'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">'
        '<c:chart><c:plotArea>$body</c:plotArea><c:legend/></c:chart></c:chartSpace>';
    const ser = '<c:ser><c:idx val="0"/><c:order val="0"/>'
        '<c:val><c:numRef><c:numCache><c:ptCount val="2"/>'
        '<c:pt idx="0"><c:v>2</c:v></c:pt><c:pt idx="1"><c:v>5</c:v></c:pt>'
        '</c:numCache></c:numRef></c:val></c:ser>';
    const xySer = '<c:ser><c:idx val="0"/><c:order val="0"/>'
        '<c:yVal><c:numRef><c:numCache><c:ptCount val="2"/>'
        '<c:pt idx="0"><c:v>2</c:v></c:pt><c:pt idx="1"><c:v>5</c:v></c:pt>'
        '</c:numCache></c:numRef></c:yVal></c:ser>';

    final cases = {
      '<c:bar3DChart><c:barDir val="bar"/>$ser</c:bar3DChart>': ChartType.bar,
      '<c:pie3DChart>$ser</c:pie3DChart>': ChartType.pie,
      '<c:area3DChart>$ser</c:area3DChart>': ChartType.area,
      '<c:stockChart>$ser</c:stockChart>': ChartType.line,
      '<c:bubbleChart>$xySer</c:bubbleChart>': ChartType.scatter,
    };
    cases.forEach((body, type) {
      test(type.name + body.substring(0, 16), () {
        final vm = _parse(chart(body))!;
        expect(vm.type, type);
        expect(vm.approx, isTrue);
        paint(vm);
      });
    });

    test('tanınan tür yaklaşık değil; hiç bilinmeyen tür çizilmez', () {
      expect(_parse(chart('<c:lineChart>$ser</c:lineChart>'))!.approx, isFalse);
      expect(_parse(chart('<c:fooChart>$ser</c:fooChart>')), isNull);
    });

    test('radar filled + yığılmış çizgi okunur', () {
      final r = _parse(chart(
          '<c:radarChart><c:radarStyle val="filled"/>$ser</c:radarChart>'))!;
      expect((r.type, r.filled), (ChartType.radar, true));
      final l = _parse(chart('<c:lineChart><c:grouping val="stacked"/>'
          '$ser$ser</c:lineChart>'))!;
      expect(l.grouping, ChartGrouping.stacked);
      paint(r);
      paint(l);
    });
  });
}

ChartVM? _parse(String xml) {
  final bytes = utf8.encode(xml);
  final a = Archive()..addFile(ArchiveFile('c.xml', bytes.length, bytes));
  return PptxRender(a).chartPart('c.xml');
}


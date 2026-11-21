import 'dart:ui' as ui;

import 'package:dosya_okuyucu/services/pptx/pro/pptx_chart_ops.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_package.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/widgets/chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// B11 m.2 — slayta Excel'le AYNI türlerde grafik ekleme / tür değiştirme.
/// Tür başına YAZ (`PptxChartOps.insert`) → OKU (çizim modeli + veri
/// düzenleyicinin okuyucusu) → ÇİZ (ortak `ChartPainter`).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PptxPro.inIsolate = false;
  final deck = PptxWriter.build([const SlideDraft('Grafik', ['A'])]);

  const expected = {
    SlideChartKind.column: (ChartType.column, ChartGrouping.standard, 'c:barChart'),
    SlideChartKind.columnStacked: (ChartType.column, ChartGrouping.stacked, 'c:barChart'),
    SlideChartKind.columnPercent: (ChartType.column, ChartGrouping.percent, 'c:barChart'),
    SlideChartKind.bar: (ChartType.bar, ChartGrouping.standard, 'c:barChart'),
    SlideChartKind.barStacked: (ChartType.bar, ChartGrouping.stacked, 'c:barChart'),
    SlideChartKind.barPercent: (ChartType.bar, ChartGrouping.percent, 'c:barChart'),
    SlideChartKind.line: (ChartType.line, ChartGrouping.standard, 'c:lineChart'),
    SlideChartKind.area: (ChartType.area, ChartGrouping.standard, 'c:areaChart'),
    SlideChartKind.pie: (ChartType.pie, ChartGrouping.standard, 'c:pieChart'),
    SlideChartKind.doughnut: (ChartType.pie, ChartGrouping.standard, 'c:doughnutChart'),
    SlideChartKind.scatter: (ChartType.scatter, ChartGrouping.standard, 'c:scatterChart'),
    SlideChartKind.radar: (ChartType.radar, ChartGrouping.standard, 'c:radarChart'),
  };

  test('her tür menüde var', () {
    expect(expected.keys.toSet(), SlideChartKind.values.toSet());
  });

  for (final MapEntry(key: kind, value: (type, grouping, tag)) in expected.entries) {
    test('${kind.name}: yaz → oku → çiz', () async {
      final d = SlideChartData(kind, const ['1', '2', '3'], const [
        ('S1', [4.0, 2.5, 3.0]),
        ('S2', [1.0, 3.5, 2.0]),
      ], title: 'T');
      final b = await PptxPro.run(deck, PptxChartOps.insert(0, d));
      final pkg = PptxPackage.open(b);
      final part = pkg.names.firstWhere((n) => n.startsWith('ppt/charts/chart'));
      final xml = pkg.xml(part)!.toXmlString();
      expect(xml, contains('<$tag>'));
      if (grouping != ChartGrouping.standard) {
        expect(xml, contains(grouping == ChartGrouping.stacked
            ? '<c:grouping val="stacked"/>'
            : '<c:grouping val="percentStacked"/>'));
      }
      expect(xml, contains('<c:externalData'));

      final shape = PptxEditor.parse(b)
          .slides
          .first
          .view!
          .shapes
          .firstWhere((s) => s.chart != null);
      final vm = shape.chart!;
      expect(vm.type, type);
      expect(vm.grouping, grouping);
      expect(vm.doughnut, kind == SlideChartKind.doughnut);
      expect(vm.approx, isFalse);
      expect(vm.series, isNotEmpty);

      final back = PptxChartOps.read(pkg, 0, shape.id)!;
      expect(back.kind, kind);
      expect(back.title, 'T');
      expect(back.series.first.$2, [4.0, 2.5, 3.0]);

      final rec = ui.PictureRecorder();
      ChartPainter(vm).paint(Canvas(rec), const Size(400, 260));
      rec.endRecording().dispose();
    });
  }

  test('tür değiştir: sütun → %100 yığılmış çubuk → radar', () async {
    var b = await PptxPro.run(deck, PptxChartOps.insert(0, SlideChartData.sample));
    final id = PptxEditor.parse(b).slides.first.view!.shapes.firstWhere((s) => s.chart != null).id;
    for (final k in [SlideChartKind.barPercent, SlideChartKind.radar]) {
      final cur = PptxChartOps.read(PptxPackage.open(b), 0, id)!;
      b = await PptxPro.run(
          b, PptxChartOps.update(0, id, SlideChartData(k, cur.categories, cur.series)));
      final back = PptxChartOps.read(PptxPackage.open(b), 0, id)!;
      expect(back.kind, k);
      expect(back.series, hasLength(2));
    }
    // Gömülü kitap yerinde değişir (çoğalmaz).
    expect(PptxPackage.open(b).names.where((n) => n.endsWith('.xlsx')), hasLength(1));
  });
}

import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/widgets/chart_painter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
import 'support/office_fixtures.dart';

/// Faz 27 kalanı: dosyada zaten olan grafikler ızgarada çizilir — önce
/// okunabilmeleri gerekir (çalışma kitabı → sayfa → çizim → grafik parçası).
void main() {
  test('kaydedilen grafik yeniden açılınca dosya grafiği olarak okunur', () {
    final e = XlsxEditor.parse(OfficeFixtures.xlsxSales());
    final sheet = e.sheets.first;
    expect(e.fileCharts, isEmpty);
    e.addChart(XlsxChartSpec.fromRange(
      sheetName: sheet.name,
      kind: XlsxChartKind.line,
      top: 0, left: 0, bottom: 3, right: 2,
      display: sheet.rawAt,
    )!.copyWith(anchorRow: 5, anchorCol: 4, widthCols: 7, heightRows: 12));
    final again = XlsxEditor.parse(e.save());
    final charts = again.fileCharts;
    expect(charts, hasLength(1));
    final c = charts.single;
    expect(c.sheetName, sheet.name);
    expect((c.fromRow, c.fromCol), (5, 4));
    expect(c.toCol - c.fromCol, 7);
    expect(c.toRow - c.fromRow, 12);
    expect(c.chart.type, ChartType.line);
    expect(c.chart.series, isNotEmpty);
    expect(c.chart.series.first.values, isNotEmpty);
  });

  test('bozuk / boş paket grafiksiz açılır', () {
    expect(XlsxEditor.blank().fileCharts, isEmpty);
  });

  group('ızgarada', () {
    late Directory dir;
    setUp(() async {
      SpreadsheetEditorScreen.parseInIsolate = false;
      EditPrefs.autoSave = false;
      dir = await Directory.systemTemp.createTemp('xl_file_chart');
      final e = XlsxEditor.parse(OfficeFixtures.xlsxSales());
      final sheet = e.sheets.first;
      e.addChart(XlsxChartSpec.fromRange(
        sheetName: sheet.name,
        kind: XlsxChartKind.column,
        top: 0, left: 0, bottom: 3, right: 2,
        display: sheet.rawAt,
      )!.copyWith(anchorRow: 1, anchorCol: 1));
      await File('${dir.path}/g.xlsx').writeAsBytes(e.save());
    });
    tearDown(() {
      SpreadsheetEditorScreen.parseInIsolate = true;
      EditPrefs.autoSave = true;
      removeTempDir(dir);
    });

    testWidgets('dosyadaki grafik hücrelerin üstünde çizilir', (t) async {
      t.view.physicalSize = const Size(1080, 2200);
      t.view.devicePixelRatio = 2.75;
      addTearDown(t.view.reset);
      await t.pumpWidget(MaterialApp(
        home: SpreadsheetEditorScreen(
            path: '${dir.path}/g.xlsx', name: 'g.xlsx', plainText: ''),
      ));
      await t.pump();
      await t.pump(const Duration(milliseconds: 100));
      expect(find.byKey(const ValueKey('xl-file-chart-1-1')), findsOneWidget);
      expect(
          find.byWidgetPredicate(
              (w) => w is CustomPaint && w.painter is ChartPainter),
          findsOneWidget);
    });
  });
}

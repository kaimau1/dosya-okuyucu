import 'package:dosya_okuyucu/services/pptx_render.dart' show ChartType;
import 'package:dosya_okuyucu/services/xlsx_chart.dart';
import 'package:dosya_okuyucu/widgets/chart_insert_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 9 / Y2 — grafik ekleme penceresi: tür seçimi önizlemeyi değiştirir,
/// "Ekle" seçilen türü ve başlığı döndürür.
void main() {
  const grid = [
    ['Ay', 'Satış'],
    ['Ocak', '10'],
    ['Şubat', '20'],
  ];
  XlsxChartSpec? build(XlsxChartKind kind, String title) =>
      XlsxChartSpec.fromRange(
        sheetName: 'S',
        kind: kind,
        top: 0,
        left: 0,
        bottom: 2,
        right: 1,
        display: (r, c) => grid[r][c],
        title: title,
      );

  test('önizleme modeli türü ve renkleri taşır', () {
    final vm = chartPreviewOf(build(XlsxChartKind.pie, '')!);
    expect(vm.type, ChartType.pie);
    expect(vm.series.single.pointColors, hasLength(2));
    expect(vm.categories, ['Ocak', 'Şubat']);
  });

  testWidgets('tür + başlık seçilip eklenir', (tester) async {
    XlsxChartSpec? result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async =>
                result = await showChartInsertDialog(context, build),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Çizgi'));
    await tester.enterText(find.byType(TextField), 'Satışlar');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, 'Ekle'));
    await tester.pumpAndSettle();
    expect(result?.kind, XlsxChartKind.line);
    expect(result?.title, 'Satışlar');
  });
}

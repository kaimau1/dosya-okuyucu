import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/pptx_render.dart' show ChartSeries, ChartType, ChartVM;
import '../services/xlsx_chart.dart';
import 'chart_painter.dart';
import '../core/app_icons.dart';
import '../core/app_colors.dart';

/// Excel'de **grafik ekle** penceresi (Faz 9 / Y2): tür seçimi + başlık +
/// CANLI önizleme. Önizleme slayt grafiklerini çizen [ChartPainter] ile
/// çizilir — kullanıcı eklemeden önce neyin ekleneceğini görür.
///
/// [build] seçilen tür için spesifikasyonu kurar (veri aralığı çağıranda).
Future<XlsxChartSpec?> showChartInsertDialog(
  BuildContext context,
  XlsxChartSpec? Function(XlsxChartKind kind, String title) build,
) {
  return showDialog<XlsxChartSpec>(
    context: context,
    builder: (_) => _ChartInsertDialog(build: build),
  );
}

/// Grafik spesifikasyonunun çizilebilir modeli (önizleme ve testler için).
ChartVM chartPreviewOf(XlsxChartSpec spec) => ChartVM(
      type: switch (spec.kind) {
        XlsxChartKind.column => ChartType.column,
        XlsxChartKind.bar => ChartType.bar,
        XlsxChartKind.line => ChartType.line,
        XlsxChartKind.pie => ChartType.pie,
      },
      categories: spec.categories,
      showLegend: true,
      series: [
        for (var i = 0; i < spec.series.length; i++)
          ChartSeries(
            name: spec.series[i].name,
            color: _color(XlsxChartWriter.palette[
                i % XlsxChartWriter.palette.length]),
            values: [for (final v in spec.series[i].values) v ?? 0],
            pointColors: spec.kind == XlsxChartKind.pie
                ? {
                    for (var k = 0; k < spec.series[i].values.length; k++)
                      k: _color(XlsxChartWriter.palette[
                          k % XlsxChartWriter.palette.length]),
                  }
                : const {},
          ),
      ],
    );

Color _color(String hex) => Color(0xFF000000 | int.parse(hex, radix: 16));

class _ChartInsertDialog extends StatefulWidget {
  final XlsxChartSpec? Function(XlsxChartKind kind, String title) build;
  const _ChartInsertDialog({required this.build});

  @override
  State<_ChartInsertDialog> createState() => _ChartInsertDialogState();
}

class _ChartInsertDialogState extends State<_ChartInsertDialog> {
  var _kind = XlsxChartKind.column;
  final _title = TextEditingController();

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  static const _kinds = [
    (XlsxChartKind.column, AppIcons.barChart, 'chart.column'),
    (XlsxChartKind.bar, AppIcons.alignHorizontalLeft, 'chart.bar'),
    (XlsxChartKind.line, AppIcons.showChart, 'chart.line'),
    (XlsxChartKind.pie, AppIcons.pieChartOutline, 'chart.pie'),
  ];

  @override
  Widget build(BuildContext context) {
    final spec = widget.build(_kind, _title.text.trim());
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(context.t('chart.insert')),
      content: SizedBox(
        width: 360,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final k in _kinds)
                    ChoiceChip(
                      avatar: Icon(k.$2, size: 18),
                      label: Text(context.t(k.$3)),
                      selected: _kind == k.$1,
                      onSelected: (_) => setState(() => _kind = k.$1),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _title,
                decoration: InputDecoration(
                  labelText: context.t('chart.title'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              Container(
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.page,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: spec == null
                    ? Center(child: Text(context.t('chart.no_numbers')))
                    : CustomPaint(painter: ChartPainter(chartPreviewOf(spec))),
              ),
              const SizedBox(height: 8),
              Text(context.t('chart.hint'),
                  style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: spec == null ? null : () => Navigator.pop(context, spec),
          child: Text(context.t('chart.add')),
        ),
      ],
    );
  }
}

part of '../spreadsheet_editor_screen.dart';

/// **Faz 36 madde 11** — grafik: kombinasyon (son seri çizgi), ikincil
/// eksen, doğrusal eğilim çizgisi, renk stilleri; görüntü/PDF paylaş.
extension _SpreadsheetProChartPart on _SpreadsheetEditorScreenState {
  Widget _chartOptionsButton(XlsxChartSpec spec) => PopupMenuButton<String>(
        key: const ValueKey('xl-chart-options'),
        tooltip: context.t('xp.chart_options'),
        icon: const Icon(AppIcons.tune, size: 20),
        onSelected: (k) => _chartOption(spec, k),
        itemBuilder: (ctx) => [
          if (spec.kind == XlsxChartKind.column ||
              spec.kind == XlsxChartKind.bar) ...[
            CheckedPopupMenuItem(
              value: 'combo',
              checked: spec.combo,
              enabled: spec.series.length >= 2,
              child: Text(ctx.t('xp.chart_combo')),
            ),
            CheckedPopupMenuItem(
              value: 'secondary',
              checked: spec.secondaryAxis,
              enabled: spec.isCombo,
              child: Text(ctx.t('xp.chart_secondary')),
            ),
          ],
          if (spec.kind != XlsxChartKind.pie)
            CheckedPopupMenuItem(
              value: 'trend',
              checked: spec.trendline,
              child: Text(ctx.t('xp.chart_trend')),
            ),
          const PopupMenuDivider(),
          for (var i = 0; i < XlsxChartWriter.styles.length; i++)
            CheckedPopupMenuItem(
              value: 'style$i',
              checked: spec.style == i,
              child: Text(ctx.t('xp.chart_style', {'n': i + 1})),
            ),
          const PopupMenuDivider(),
          PopupMenuItem(value: 'png', child: Text(ctx.t('xp.chart_share_png'))),
          PopupMenuItem(value: 'pdf', child: Text(ctx.t('xp.chart_share_pdf'))),
        ],
      );

  void _chartOption(XlsxChartSpec spec, String key) {
    switch (key) {
      case 'combo':
        _replaceChart(spec, spec.copyWith(combo: !spec.combo));
      case 'secondary':
        _replaceChart(spec, spec.copyWith(secondaryAxis: !spec.secondaryAxis));
      case 'trend':
        _replaceChart(spec, spec.copyWith(trendline: !spec.trendline));
      case 'png':
      case 'pdf':
        _shareChart(spec, pdf: key == 'pdf');
      default:
        if (key.startsWith('style')) {
          _replaceChart(
              spec, spec.copyWith(style: int.tryParse(key.substring(5)) ?? 0));
        }
    }
  }

  /// Grafiği beyaz zeminde 1600×1000 PNG'ye çizer (önizlemeyle aynı çizici).
  Future<Uint8List> _chartPng(XlsxChartSpec spec) async {
    const size = Size(1600, 1000);
    final rec = ui.PictureRecorder();
    final canvas = Canvas(rec);
    canvas.drawRect(
        Offset.zero & size, Paint()..color = AppColors.chartExportPaper);
    canvas.translate(32, 32);
    ChartPainter(chartPreviewOf(spec))
        .paint(canvas, Size(size.width - 64, size.height - 64));
    final img = await rec
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
    try {
      final data = await img.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    } finally {
      img.dispose();
    }
  }

  Future<void> _shareChart(XlsxChartSpec spec, {required bool pdf}) async {
    final png = await _chartPng(spec);
    final bytes = pdf ? await SheetPdf.image(png) : png;
    final base = spec.title.trim().isEmpty
        ? '${p.basenameWithoutExtension(widget.name)}-chart'
        : spec.title.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final f = File(p.join(Directory.systemTemp.path, '$base.${pdf ? 'pdf' : 'png'}'));
    await f.writeAsBytes(bytes, flush: true);
    if (!mounted) return;
    await Share.shareXFiles([XFile(f.path)]);
  }
}

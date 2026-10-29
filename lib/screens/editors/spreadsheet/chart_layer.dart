part of '../spreadsheet_editor_screen.dart';

/// Faz 27 madde 9 — eklenen grafikler **ızgarada** çizilir: dokun = seç,
/// sürükle = taşı (bırakınca en yakın hücreye oturur), sağ alt köşe =
/// boyutlandır (sütun/satır adımıyla); seçiliyken üstte tür / sil çubuğu.
/// Konum ve boyut kaydette `<xdr:from>/<xdr:to>`ya yazılır. Geri alınabilir.
extension _SpreadsheetChartLayerPart on _SpreadsheetEditorScreenState {
  /// [list] gövde listesinin üstüne bu sayfanın grafikleri.
  Widget _withCharts(
      Widget list, SheetAxisMetrics rows, SheetAxisMetrics cols) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return list;
    final specs = [
      for (final c in editor.charts)
        if (c.sheetName == sheet.name) c,
    ];
    if (specs.isEmpty) return list;
    return Stack(
      children: [
        list,
        for (final spec in specs) _chartBox(spec, rows, cols),
      ],
    );
  }

  /// Satır/sütun ölçüsünde [index]'in başlangıcı (gizli/donmuşsa yaklaşık).
  static double _axisStart(SheetAxisMetrics m, int index) {
    final at = m.indices.indexOf(index);
    if (at >= 0) return m.startAt(at);
    // Pencere dışı: en yakın küçük indeksin sonuna.
    var best = 0.0;
    for (var i = 0; i < m.length; i++) {
      if (m.indices[i] > index) break;
      best = m.startAt(i) + m.sizeAt(i);
    }
    return best;
  }

  /// Konum → en yakın indeks.
  static int _axisIndexAt(SheetAxisMetrics m, double pos) {
    if (m.length == 0) return 0;
    for (var i = 0; i < m.length; i++) {
      if (m.startAt(i) + m.sizeAt(i) / 2 >= pos) return m.indices[i];
    }
    return m.indices.last;
  }

  Widget _chartBox(
      XlsxChartSpec spec, SheetAxisMetrics rows, SheetAxisMetrics cols) {
    final left = _axisStart(cols, spec.anchorCol);
    final right = _axisStart(cols, spec.anchorCol + spec.widthCols);
    final top = _axisStart(rows, spec.anchorRow);
    final bottom = _axisStart(rows, spec.anchorRow + spec.heightRows);
    final selected = identical(_chartSel, spec);
    final w = math.max(80.0, (right - left) + (selected ? _chartGrow.dx : 0));
    final h = math.max(60.0, (bottom - top) + (selected ? _chartGrow.dy : 0));
    final scheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: _vBody,
      builder: (context, child) {
        final dy = _vBody.hasClients ? _vBody.offset : 0.0;
        final off = selected ? _chartDrag : Offset.zero;
        return Positioned(
          left: left + off.dx,
          top: top - dy + off.dy,
          width: w,
          height: h,
          child: child!,
        );
      },
      child: GestureDetector(
        key: ValueKey('xl-chart-${spec.anchorRow}-${spec.anchorCol}'),
        behavior: HitTestBehavior.opaque,
        onTap: () => _partSetState(() {
          _chartSel = selected ? null : spec;
          _chartDrag = Offset.zero;
          _chartGrow = Offset.zero;
        }),
        onPanStart: (_) => _partSetState(() {
          _chartSel = spec;
          _chartDrag = Offset.zero;
        }),
        onPanUpdate: (d) => _partSetState(() => _chartDrag += d.delta),
        onPanEnd: (_) {
          final col = _axisIndexAt(cols, left + _chartDrag.dx);
          final row = _axisIndexAt(rows, top + _chartDrag.dy);
          _replaceChart(spec, spec.copyWith(anchorRow: row, anchorCol: col));
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Paper.docSurface(context),
                  border: Border.all(
                      color: selected ? OfficeColors.excel : scheme.outlineVariant,
                      width: selected ? 2 : 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: CustomPaint(painter: ChartPainter(chartPreviewOf(spec))),
                ),
              ),
            ),
            if (selected) ...[
              PositionedDirectional(
                top: 2,
                end: 2,
                child: Material(
                  color: scheme.surfaceContainerHigh,
                  borderRadius: BorderRadius.circular(Radii.control),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    PopupMenuButton<XlsxChartKind>(
                      key: const ValueKey('xl-chart-kind'),
                      tooltip: context.t('chart.type'),
                      icon: const Icon(AppIcons.insertChart, size: 20),
                      onSelected: (k) => _replaceChart(spec, spec.copyWith(kind: k)),
                      itemBuilder: (ctx) => [
                        for (final k in XlsxChartKind.values)
                          CheckedPopupMenuItem(
                            value: k,
                            checked: k == spec.kind,
                            child: Text(ctx.t('chart.${k.name}')),
                          ),
                      ],
                    ),
                    IconButton(
                      key: const ValueKey('xl-chart-delete'),
                      tooltip: context.t('common.delete'),
                      icon: const Icon(AppIcons.delete, size: 20),
                      onPressed: () => _replaceChart(spec, null),
                    ),
                  ]),
                ),
              ),
              PositionedDirectional(
                end: 0,
                bottom: 0,
                child: GestureDetector(
                  key: const ValueKey('xl-chart-resize'),
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (d) =>
                      _partSetState(() => _chartGrow += d.delta),
                  onPanEnd: (_) {
                    final endCol = _axisIndexAt(cols, left + w);
                    final endRow = _axisIndexAt(rows, top + h);
                    _replaceChart(
                        spec,
                        spec.copyWith(
                          widthCols: math.max(2, endCol - spec.anchorCol),
                          heightRows: math.max(4, endRow - spec.anchorRow),
                        ));
                  },
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: Paper.docSurface(context),
                      shape: BoxShape.circle,
                      border: Border.all(color: OfficeColors.excel, width: 2),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Grafiği değiştirir ([next] null = sil); tek geri al adımı.
  void _replaceChart(XlsxChartSpec spec, XlsxChartSpec? next) {
    final editor = _editor;
    if (editor == null) return;
    final i = editor.charts.indexOf(spec);
    if (i < 0) return;
    void apply() {
      final at = editor.charts.indexOf(spec);
      if (at < 0) return;
      if (next == null) {
        editor.charts.removeAt(at);
      } else {
        editor.charts[at] = next;
      }
    }

    void revert() {
      if (next == null) {
        editor.charts.insert(i.clamp(0, editor.charts.length), spec);
      } else {
        final at = editor.charts.indexOf(next);
        if (at >= 0) editor.charts[at] = spec;
      }
    }

    apply();
    _recordStep(next == null ? 'chart.undo_delete' : 'chart.undo_edit', apply,
        revert);
    _session.changed();
    _partSetState(() {
      _chartSel = next;
      _chartDrag = Offset.zero;
      _chartGrow = Offset.zero;
    });
  }
}

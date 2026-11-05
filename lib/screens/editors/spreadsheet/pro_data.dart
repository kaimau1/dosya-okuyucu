part of '../spreadsheet_editor_screen.dart';

/// Özet tablo bağı: hangi sayfa hangi kaynaktan, hangi ayarla üretildi
/// (oturum içi; "Özeti yenile" bununla kaynağı yeniden okur).
class _PivotLink {
  final String source;
  final CellRange range;
  final PivotSpec spec;
  const _PivotLink(this.source, this.range, this.spec);
}

/// Faz 36 — Excel pro veri araçları (özet tablo …).
extension _SpreadsheetProDataPart on _SpreadsheetEditorScreenState {
  /// Aralığın GÖRÜNEN değerleri (formül sonucu dahil).
  List<List<String>> _rangeValues(XlsxSheet sheet, CellRange r) {
    final engine = _engineFor(sheet);
    String shown(int row, int col) => sheet.rawAt(row, col).startsWith('=')
        ? engine.displayValue(row, col)
        : sheet.rawAt(row, col);
    return [
      for (var row = r.top; row <= r.bottom; row++)
        [for (var c = r.left; c <= r.right; c++) shown(row, c)],
    ];
  }

  // ── 1. Özet tablo ──────────────────────────────────────────────────────

  Future<void> _createPivot() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _dataRange(sheet);
    if (r.bottom <= r.top) {
      _snack(context.t('excel.dup_needs_range'));
      return;
    }
    final data = _rangeValues(sheet, r);
    final header = [
      for (var i = 0; i < data.first.length; i++)
        data.first[i].trim().isEmpty ? CellRef.colName(r.left + i) : data.first[i].trim(),
    ];
    final spec = await showAppSheet<PivotSpec>(
      context,
      title: context.t('xp.pivot'),
      builder: (_) => _PivotSheet(header: header, data: data),
    );
    if (spec == null || !mounted) return;
    final link = _PivotLink(sheet.name, r, spec);
    var n = 1;
    while (editor.hasSheet(context.t('xp.pivot_sheet', {'n': n}))) {
      n++;
    }
    final added = editor.addSheet(context.t('xp.pivot_sheet', {'n': n}));
    if (added == null) return;
    _writePivot(added.name, link, data);
    _partSetState(() {
      _pivots[added.name] = link;
      _sheetIndex = editor.sheets.indexOf(added);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _session.changed();
      _gridVersion++;
    });
    _syncField();
  }

  /// Özet sonucunu [target] sayfasına düz değer olarak yazar (önce temizler).
  void _writePivot(String target, _PivotLink link, List<List<String>> data) {
    final editor = _editor!;
    final result = Pivot.build(
      data,
      link.spec,
      totalLabel: context.t('xp.grand_total'),
      blankLabel: context.t('xp.blank'),
      valueHeader: context.t('xp.agg_header', {
        'agg': context.t('xp.agg_${link.spec.agg.name}'),
        'field': data.first[link.spec.valueField],
      }),
    );
    final model = editor.sheets.firstWhere((s) => s.name == target);
    for (var row = 0; row < model.rows.length; row++) {
      for (var c = 0; c < model.rows[row].length; c++) {
        if (model.rows[row][c].isNotEmpty) editor.setCell(target, row, c, '');
      }
    }
    for (var row = 0; row < result.cells.length; row++) {
      for (var c = 0; c < result.cells[row].length; c++) {
        editor.setCell(target, row, c, result.cells[row][c]);
      }
    }
  }

  /// Etkin sayfa bir özetse kaynağını yeniden okuyup sonucu tazeler.
  void _refreshPivot() {
    final sheet = _sheet;
    final editor = _editor;
    final link = sheet == null ? null : _pivots[sheet.name];
    if (sheet == null || editor == null || link == null) return;
    _endEdit();
    final source = editor.sheets.where((s) => s.name == link.source).firstOrNull;
    if (source == null) {
      _snack(context.t('xp.pivot_source_gone'));
      return;
    }
    _writePivot(sheet.name, link, _rangeValues(source, link.range));
    _partSetState(() {
      _session.changed();
      _gridVersion++;
    });
    _syncField();
    _snack(context.t('xp.pivot_refreshed'));
  }

  // ── 2. Koşullu biçim yazma ─────────────────────────────────────────────

  XlsxRange _selXlsxRange() =>
      XlsxRange(_range.top, _range.left, _range.bottom, _range.right);

  /// Kuralı ekler, geri al/yinele adımı kaydeder, ızgarayı tazeler.
  void _commitCondRule(XlsxCondRule Function() add) {
    final sheet = _sheet;
    if (sheet == null) return;
    XlsxCondRule? added;
    void apply() => added = add();
    apply();
    _recordStep('excel.undo_cond_format', apply, () {
      final rule = added;
      if (rule != null) sheet.removeCondRule(rule);
    });
    _condCache.clear();
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// Renk ölçeği / veri çubuğu / simge kümesi (görünüm kuralın kendisinde).
  void _addVisualCond(String type, {List<int>? scale, int? bar}) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final xr = _selXlsxRange();
    _commitCondRule(() => sheet.addCondRule(
          range: xr,
          type: type,
          scaleColors: scale,
          barColorArgb: bar,
          iconSet: type == 'iconSet' ? '3TrafficLights1' : null,
        ));
  }

  /// Formül kuralı: aralığın sol-üst hücresine göre yazılmış koşul
  /// (`=B2>100`); doğruysa seçilen dolgu.
  Future<void> _askFormulaCond() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final top = '${CellRef.colName(_range.left)}${_range.top + 1}';
    final input = await showAppPrompt(
      context,
      title: context.t('xp.cond_formula'),
      label: context.t('xp.cond_formula_hint', {'cell': top}),
      initial: '=$top>0',
    );
    if (input == null || !mounted) return;
    final body = input.startsWith('=') ? input.substring(1) : input;
    // Dosyaya İngilizce işlev adlarıyla yazılır (Excel/LibreOffice okur).
    final formula = _turkishFormulas
        ? FormulaEngine.toFileFormula(body, turkish: true)
        : body;
    await _pickColor(context.t('excel.fill_color'), (color) {
      final fill = _SpreadsheetEditorScreenState._argbOf(
          color ?? AppColors.condFillDefault);
      final xr = _selXlsxRange();
      _commitCondRule(() => sheet.addCondRule(
            range: xr,
            type: 'expression',
            formulas: [formula],
            fillArgb: fill,
          ));
    });
  }

  // ── 3. Mini grafik ─────────────────────────────────────────────────────

  /// Seçimin HER SATIRI için, seçimin sağındaki ilk sütuna bir mini grafik
  /// (Excel'in "Konum aralığı" varsayılanı). Tek satırlık seçimde tek grafik.
  Future<void> _insertSparklines() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    if (r.right <= r.left && r.bottom <= r.top) {
      _snack(context.t('xp.sparkline_needs_range'));
      return;
    }
    final type = await showAppSheet<String>(
      context,
      title: context.t('xp.sparkline'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (t, icon) in const [
            ('line', AppIcons.trendingUp),
            ('column', AppIcons.barChart),
            ('stacked', AppIcons.swapVert),
          ])
            ListTile(
              key: ValueKey('spark-$t'),
              leading: Icon(icon),
              title: Text(ctx.t('xp.spark_$t')),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    // Tek sütunlu seçim → dikey seri, hedef sütunun altındaki hücre.
    final vertical = r.right == r.left;
    final added = <XlsxSparkline>[];
    void apply() {
      added.clear();
      if (vertical) {
        added.add(sheet.addSparkline(
          source: XlsxRange(r.top, r.left, r.bottom, r.right),
          row: r.bottom + 1,
          col: r.left,
          type: type,
        ));
        return;
      }
      for (var row = r.top; row <= r.bottom; row++) {
        added.add(sheet.addSparkline(
          source: XlsxRange(row, r.left, row, r.right),
          row: row,
          col: r.right + 1,
          type: type,
        ));
      }
    }

    apply();
    _recordStep('xp.undo_sparkline', apply, () {
      for (final sp in added) {
        sheet.removeSparkline(sp);
      }
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }
}

/// Özet tablo ayar levhası: satır / sütun / değer alanı, işlev, süzgeç.
class _PivotSheet extends StatefulWidget {
  const _PivotSheet({required this.header, required this.data});

  final List<String> header;
  final List<List<String>> data;

  @override
  State<_PivotSheet> createState() => _PivotSheetState();
}

class _PivotSheetState extends State<_PivotSheet> {
  int _row = 0;
  int? _col;
  late int _value = widget.header.length - 1;
  PivotAgg _agg = PivotAgg.sum;
  int? _filter;
  Set<String> _allowed = {};

  DropdownButtonFormField<int?> _field(String key, String label, int? value,
          ValueChanged<int?> onChanged, {bool optional = false}) =>
      DropdownButtonFormField<int?>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            DropdownMenuItem<int?>(value: null, child: Text(context.t('xp.none'))),
          for (var i = 0; i < widget.header.length; i++)
            DropdownMenuItem<int?>(value: i, child: Text(widget.header[i])),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final values = _filter == null
        ? const <String>[]
        : Pivot.distinct(widget.data, _filter!, limit: 60);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('pv-row', context.t('xp.rows'), _row,
              (v) => setState(() => _row = v ?? 0)),
          _field('pv-col', context.t('xp.cols'), _col,
              (v) => setState(() => _col = v), optional: true),
          _field('pv-value', context.t('xp.values'), _value,
              (v) => setState(() => _value = v ?? _value)),
          DropdownButtonFormField<PivotAgg>(
            key: const ValueKey('pv-agg'),
            initialValue: _agg,
            decoration: InputDecoration(labelText: context.t('xp.agg')),
            items: [
              for (final a in PivotAgg.values)
                DropdownMenuItem(value: a, child: Text(context.t('xp.agg_${a.name}'))),
            ],
            onChanged: (v) => setState(() => _agg = v ?? _agg),
          ),
          _field('pv-filter', context.t('xp.filter'), _filter,
              (v) => setState(() {
                    _filter = v;
                    _allowed = {};
                  }),
              optional: true),
          if (values.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final v in values)
                    FilterChip(
                      label: Text(v.isEmpty ? context.t('xp.blank') : v),
                      selected: _allowed.contains(v),
                      onSelected: (on) => setState(
                          () => on ? _allowed.add(v) : _allowed.remove(v)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('pv-run'),
            onPressed: () => Navigator.pop(
              context,
              PivotSpec(
                rowField: _row,
                colField: _col,
                valueField: _value,
                agg: _agg,
                filterField: _filter,
                filterValues: {..._allowed},
              ),
            ),
            child: Text(context.t('xp.pivot_create')),
          ),
        ],
      ),
    );
  }
}

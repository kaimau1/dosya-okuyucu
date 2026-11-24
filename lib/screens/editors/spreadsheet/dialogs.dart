part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenDialogsPart on _SpreadsheetEditorScreenState {
  /// Koşullu biçimlendirme kuralları — eskiden yalnız OKUNUYORDU, kullanıcı
  /// kural ekleyemiyordu.
  ///
  /// Kural seçili aralığa uygulanır. Karşılaştırma değeri **serbest metin**:
  /// sayı kuralları için sayı, metin kuralları için aranan sözcük.
  void _showCondFormat() {
    _endEdit();
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.cond_format'), [
        DocMoreItem(AppIcons.trendingUp, context.t('excel.cond_greater'),
            () => _askCondRule('cellIs', operator: 'greaterThan')),
        DocMoreItem(AppIcons.trendingDown, context.t('excel.cond_less'),
            () => _askCondRule('cellIs', operator: 'lessThan')),
        DocMoreItem(AppIcons.dragHandle, context.t('excel.cond_equal'),
            () => _askCondRule('cellIs', operator: 'equal')),
        DocMoreItem(AppIcons.textFields, context.t('excel.cond_contains'),
            () => _askCondRule('containsText')),
        if (_excelPro) ...[
        DocMoreItem(AppIcons.functions, context.t('xp.cond_formula'),
            _askFormulaCond),
        DocMoreItem(AppIcons.listAlt, context.t('xp.cond_manage'),
            _showCondManager),
        ],
      ]),
      // Faz 36 madde 2: görsel kurallar (dosyaya yazılır).
      if (_excelPro)
      DocMoreGroup(context.t('xp.cond_visual'), [
        DocMoreItem(AppIcons.formatColorFill, context.t('xp.scale_rg'),
            () => _addVisualCond('colorScale',
                scale: const [0xFFF8696B, 0xFF63BE7B])),
        DocMoreItem(AppIcons.formatColorFill, context.t('xp.scale_ryg'),
            () => _addVisualCond('colorScale',
                scale: const [0xFFF8696B, 0xFFFFEB84, 0xFF63BE7B])),
        DocMoreItem(AppIcons.formatColorFill, context.t('xp.scale_wb'),
            () => _addVisualCond('colorScale',
                scale: const [0xFFFFFFFF, 0xFF5A8AC6])),
        DocMoreItem(AppIcons.barChart, context.t('xp.data_bar'),
            () => _addVisualCond('dataBar', bar: 0xFF638EC6)),
        DocMoreItem(AppIcons.barChart, context.t('xp.data_bar_green'),
            () => _addVisualCond('dataBar', bar: 0xFF63C384)),
        DocMoreItem(AppIcons.trafficLight, context.t('xp.icon_set'),
            () => _addVisualCond('iconSet')),
      ]),
    ]);
  }

  /// Kuralın eşiğini ve rengini sorar, sonra uygular.
  Future<void> _askCondRule(String type, {String? operator}) async {
    final editor = _editor;
    final sheet = _sheet;
    if (editor == null || sheet == null) return;
    final ctrl = TextEditingController();
    final String? value;
    try {
      value = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(ctx.t('excel.cond_format')),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: type == 'cellIs'
                ? const TextInputType.numberWithOptions(decimal: true)
                : TextInputType.text,
            decoration: InputDecoration(
                labelText: ctx.t(type == 'cellIs'
                    ? 'excel.cond_value'
                    : 'excel.cond_text')),
            onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(ctx.t('common.cancel'))),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
                child: Text(ctx.t('common.ok'))),
          ],
        ),
      );
    } finally {
      ctrl.dispose();
    }
    if (value == null || value.isEmpty || !mounted) return;
    final val = value;

    await _pickColor(context.t('excel.fill_color'), (color) {
      final range = _range;
      final xr = XlsxRange(range.top, range.left, range.bottom, range.right);
      // "Renk yok" seçilirse Excel'in varsayılan açık kırmızısı kullanılır:
      // renksiz bir kuralın ekranda hiçbir etkisi olmazdı.
      final fill = _SpreadsheetEditorScreenState._argbOf(color ?? const Color(0xFFFFC7CE));
      // Yinele (redo) kuralı YENİDEN kurar; hangi nesnenin söküleceğini
      // bilmek için son eklenen tutulur.
      XlsxCondRule? added;
      void apply() {
        added = sheet.addCondRule(
          range: xr,
          type: type,
          operator: operator,
          formulas: type == 'cellIs' ? [val] : const [],
          text: type == 'cellIs' ? null : val,
          fillArgb: fill,
        );
      }

      apply();
      _recordStep('excel.undo_cond_format', apply, () {
        final rule = added;
        if (rule != null) sheet.removeCondRule(rule);
      });
      _session.changed();
      _gridVersion++;
      _partSetState(() {});
    });
  }

  /// Kenarlık ön ayarları (Excel'in "Kenarlıklar" menüsü).
  void _showBorders() {
    const thin = 'thin';
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.borders'), [
        DocMoreItem(AppIcons.borderAll, context.t('excel.border_all'),
            () => _applyBorder(const {
                  'left': thin,
                  'right': thin,
                  'top': thin,
                  'bottom': thin,
                })),
        DocMoreItem(AppIcons.borderOuter, context.t('excel.border_outline'),
            _applyOutlineBorder),
        DocMoreItem(AppIcons.borderBottom, context.t('excel.border_bottom'),
            () => _applyBorder(const {'bottom': thin})),
        DocMoreItem(AppIcons.borderTop, context.t('excel.border_top'),
            () => _applyBorder(const {'top': thin})),
        DocMoreItem(AppIcons.borderClear, context.t('excel.border_none'),
            () => _applyBorder(const {
                  'left': null,
                  'right': null,
                  'top': null,
                  'bottom': null,
                })),
      ]),
    ]);
  }

  /// "Dış kenarlık": aralığın yalnız DIŞ kenarlarına çizgi — içteki hücre
  /// sınırları boş kalır. Her hücrenin hangi kenarı dışta olduğu konumuna
  /// bağlı olduğu için bu, [_applyCellFormat]'ın tek biçimli döngüsüne
  /// sığmıyor; adım burada elle kurulur.
  void _applyOutlineBorder() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final range = _range;
    final name = sheet.name;
    final before = <CellRef, XlsxBorder>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): (sheet.styleAt(r, c) ?? const XlsxCellStyle()).border,
    };
    final overridesBefore = <CellRef, XlsxCellStyle?>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): sheet.overrideAt(r, c),
    };
    final editsBefore = <(int, int), XlsxStyleEdit?>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          (r, c): sheet.styleEdits[(r, c)],
    };
    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          editor.setCellBorder(name, r, c, {
            'left': c == range.left ? 'thin' : null,
            'right': c == range.right ? 'thin' : null,
            'top': r == range.top ? 'thin' : null,
            'bottom': r == range.bottom ? 'thin' : null,
          });
        }
      }
    }

    applyNow();
    _recordStep('excel.undo_border', applyNow, () {
      before.forEach((at, b) => editor.setCellBorder(name, at.row, at.col, {
            'left': b.left.visible ? b.left.style : null,
            'right': b.right.visible ? b.right.style : null,
            'top': b.top.visible ? b.top.style : null,
            'bottom': b.bottom.visible ? b.bottom.style : null,
          }));
      overridesBefore
          .forEach((at, style) => sheet.patchStyle(at.row, at.col, style));
      editsBefore.forEach((k, edit) {
        if (edit == null) {
          sheet.styleEdits.remove(k);
        } else {
          sheet.styleEdits[k] = edit;
        }
      });
    });
    _session.changed();
    _partSetState(() {});
  }

  Widget _cellMenuPill(ColorScheme scheme) => Flexible(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 6),
          child: Material(
            color: scheme.primaryContainer.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(Radii.control),
            child: InkWell(
              key: const ValueKey('xl-status-menu'),
              onTap: _showCellMenu,
              borderRadius: BorderRadius.circular(Radii.control),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  context.t('excel.cell_menu'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.type.caption.copyWith(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

  /// Excel'in durum çubuğu: seçili aralığın kopyalanabilir istatistikleri
  /// ve her durumda tek dokunuşla ulaşılabilen hücre menüsü + sayfa konumu.
  Widget _statusBar() {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    if (!_hasRange) {
      final fmt = sheet.numFmtCode(_selRow, _selCol);
      final text = context.t('excel.cell_label',
              {'ref': '${XlsxRange.colName(_selCol)}${_selRow + 1}'}) +
          (fmt == 'General' ? '' : '  ·  $fmt');
      return _statusRow(
        scheme,
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: [_cellMenuPill(scheme)],
      );
    }

    final engine = _engineFor(sheet);
    final memoKey = (sheet.name, _anchorRow, _anchorCol, _selRow, _selCol,
        _calcStamp, context.language);
    _RangeStatusData? stats;
    final memo = _statusMemo;
    if (memo != null && memo.$1 == memoKey) {
      stats = memo.$2;
    } else {
      final r1 = math.min(_anchorRow, _selRow);
      final r2 = math.max(_anchorRow, _selRow);
      final c1 = math.min(_anchorCol, _selCol);
      final c2 = math.max(_anchorCol, _selCol);
      final cellCount = (r2 - r1 + 1) * (c2 - c1 + 1);
      if (cellCount > 200000) {
        return _statusText(
            context.t('excel.selection_cells', {'n': cellCount}), scheme);
      }
      var sum = 0.0;
      var count = 0;
      var filled = 0;
      var minVal = double.infinity;
      var maxVal = -double.infinity;
      for (var r = r1; r <= r2; r++) {
        for (var c = c1; c <= c2; c++) {
          final raw = engine.displayValue(r, c);
          if (raw.isEmpty) continue;
          filled++;
          final v = double.tryParse(raw);
          if (v == null) continue;
          sum += v;
          count++;
          if (v < minVal) minVal = v;
          if (v > maxVal) maxVal = v;
        }
      }
      stats = _RangeStatusData(
        cellCount: cellCount,
        filled: filled,
        count: count,
        sum: sum,
        avg: count == 0 ? 0 : sum / count,
        min: count == 0 ? 0 : minVal,
        max: count == 0 ? 0 : maxVal,
      );
      _statusMemo = (memoKey, stats);
    }
    if (stats.count == 0) {
      return _statusText(
        context.t('excel.selection_filled',
            {'n': stats.cellCount, 'filled': stats.filled}),
        scheme,
      );
    }
    Widget statChip(String key, String rawValue) {
      final label = context.t(key, {'v': rawValue});
      return Padding(
        padding: const EdgeInsetsDirectional.only(end: 6),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.sheet),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: rawValue));
            if (mounted) _snack(context.t('excel.copied_stat', {'v': rawValue}));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(Radii.sheet),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Text(
              label,
              style: context.type.caption.copyWith(color: scheme.onSurface),
            ),
          ),
        ),
      );
    }

    return _statusRow(
      scheme,
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              statChip('excel.stat_sum_short', generalNumber(stats.sum)),
              statChip('excel.stat_avg_short', generalNumber(stats.avg)),
              statChip('excel.stat_count_short', '${stats.count}'),
              statChip('excel.stat_min_short', generalNumber(stats.min)),
              statChip('excel.stat_max_short', generalNumber(stats.max)),
            ],
          ),
        ),
      ),
      trailing: [_cellMenuPill(scheme)],
    );
  }

  Widget _statusText(String text, ColorScheme scheme) => _statusRow(
        scheme,
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.type.caption.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        trailing: [_cellMenuPill(scheme)],
      );

  /// Durum çubuğu satırı — solda seçim bilgisi/istatistikler, sağda ek + sayfa konumu.
  Widget _statusRow(
    ColorScheme scheme,
    Widget body, {
    List<Widget> trailing = const [],
  }) {
    final sheets =
        _editor?.sheets.where((s) => !s.layout.hidden).toList() ?? const [];
    final at = _sheet == null
        ? -1
        : sheets.indexWhere((s) => s.name == _sheet!.name);
    final style = context.type.caption.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          body,
          ...trailing,
          if (at >= 0) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                context.t('excel.sheet_pos',
                    {'n': at + 1, 'total': sheets.length}),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: style,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

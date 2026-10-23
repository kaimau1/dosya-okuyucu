part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenDialogsPart on _SpreadsheetEditorScreenState {
  /// Koşullu biçimlendirme kuralları — eskiden yalnız OKUNUYORDU, kullanıcı
  /// kural ekleyemiyordu (KALANLAR maddesi).
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
      ]),
    ]);
  }

  /// Kuralın eşiğini ve rengini sorar, sonra uygular.
  Future<void> _askCondRule(String type, {String? operator}) async {
    final editor = _editor;
    final sheet = _sheet;
    if (editor == null || sheet == null) return;
    final ctrl = TextEditingController();
    final value = await showDialog<String>(
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
    if (value == null || value.isEmpty || !mounted) return;

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
          formulas: type == 'cellIs' ? [value] : const [],
          text: type == 'cellIs' ? null : value,
          fillArgb: fill,
        );
      }

      apply();
      _recordStep('excel.undo_cond_format', apply, () {
        final rule = added;
        if (rule != null) sheet.removeCondRule(rule);
      });
      _dirty = true;
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
    });
    _dirty = true;
    _partSetState(() {});
  }

  /// Excel'in durum çubuğu: seçili aralığın ortalaması / sayısı / toplamı.
  Widget _statusBar() {
    final sheet = _sheet;
    if (sheet == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    String text;
    if (!_hasRange) {
      final fmt = sheet.numFmtCode(_selRow, _selCol);
      text = context.t('excel.cell_label',
              {'ref': '${XlsxRange.colName(_selCol)}${_selRow + 1}'}) +
          (fmt == 'General' ? '' : '  ·  $fmt');
    } else {
      final engine = _engineFor(sheet);
      final r1 = math.min(_anchorRow, _selRow);
      final r2 = math.max(_anchorRow, _selRow);
      final c1 = math.min(_anchorCol, _selCol);
      final c2 = math.max(_anchorCol, _selCol);
      final cellCount = (r2 - r1 + 1) * (c2 - c1 + 1);
      // Çok büyük seçimde (tümünü seç) hücre hücre hesap ekranı dondurur;
      // Excel de yalnız sayıyı gösterir.
      if (cellCount > 200000) {
        return _statusText(
            context.t('excel.selection_cells', {'n': cellCount}), scheme);
      }
      var sum = 0.0;
      var count = 0;
      var filled = 0;
      for (var r = r1; r <= r2; r++) {
        for (var c = c1; c <= c2; c++) {
          final raw = engine.displayValue(r, c);
          if (raw.isEmpty) continue;
          filled++;
          final v = double.tryParse(raw);
          if (v == null) continue;
          sum += v;
          count++;
        }
      }
      text = count == 0
          ? context.t(
              'excel.selection_filled', {'n': cellCount, 'filled': filled})
          : context.t('excel.selection_stats', {
              'avg': generalNumber(sum / count),
              'count': count,
              'sum': generalNumber(sum),
            });
    }
    return _statusText(text, scheme);
  }

  /// Durum çubuğu — solda seçim bilgisi, sağda **kaçıncı sayfadayız**
  /// (2026-08-01 kullanıcı isteği: toplam sayfa sayısı her belgede görünsün).
  /// Excel'in "sayfa"sı çalışma sayfasıdır; gizli sayfalar sayılmaz çünkü
  /// sekmelerde de görünmezler.
  Widget _statusText(String text, ColorScheme scheme) {
    final sheets =
        _editor?.sheets.where((s) => !s.layout.hidden).toList() ?? const [];
    final at = _sheet == null ? -1 : sheets.indexWhere((s) => s.name == _sheet!.name);
    final style = context.type.caption.copyWith(color: scheme.onSurfaceVariant);
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: style),
          ),
          if (at >= 0) ...[
            const SizedBox(width: 8),
            Text(
              context.t('excel.sheet_pos',
                  {'n': at + 1, 'total': sheets.length}),
              style: style,
            ),
          ],
        ],
      ),
    );
  }
}

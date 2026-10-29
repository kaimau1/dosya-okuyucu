part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenRibbonPart on _SpreadsheetEditorScreenState {
  /// **Excel şeridi** (2026-08-07 kullanıcı isteği: *"xls şeritte Excel gibi
  /// simgeler bile yok"*).
  ///
  /// Sekmeler Excel'in kendi düzeni: Giriş / Ekle / Veri / Görünüm. Simge dili
  /// üç editörde ortak (`OfficeIcons`) — aynı iş Word'de de aynı simge.
  ///
  /// Eski "sade altı düğme + Daha fazla" kararı BURADA GEÇERSİZ: sadeliğin
  /// bedeli, kullanıcının Excel'de refleksle bulduğu her şeyin (yazı tipi,
  /// punto, kenarlık, süzgeç, zoom) menü içinde kaybolmasıydı. Etiketli
  /// "Daha fazla" sayfası **duruyor** — sekmelerin dışında kalan seyrek
  /// işler hâlâ orada.
  Widget _ribbon() {
    final selStyle = _sheet?.styleAt(_selRow, _selCol);
    final align = selStyle?.hAlign;
    final merged = _sheet?.mergeAt(_selRow, _selCol) != null;

    return OfficeRibbon(
      compact: true,
      tabs: [
        RibbonTab(context.t('excel.tab_home'), [
          RibbonChip(
            icon: OfficeIcons.fontFamily,
            label: selStyle?.fontFamily ?? context.t('excel.font_default'),
            tooltip: context.t('word.font_family'),
            onTap: _pickFontFamily,
          ),
          RibbonChip(
            icon: OfficeIcons.fontSize,
            label: _sizeText(selStyle?.fontSize),
            tooltip: context.t('word.font_size'),
            onTap: _pickFontSize,
          ),
          RibbonButton(OfficeIcons.fontGrow, context.t('vw.text_bigger'),
              onTap: () => _bumpFontSize(1)),
          RibbonButton(OfficeIcons.fontShrink, context.t('vw.text_smaller'),
              onTap: () => _bumpFontSize(-1)),
          const RibbonSep(),
          RibbonButton(OfficeIcons.bold, context.t('common.bold'),
              active: selStyle?.bold ?? false,
              onTap: () => _applyStyle(bold: !(selStyle?.bold ?? false))),
          RibbonButton(OfficeIcons.italic, context.t('common.italic'),
              active: selStyle?.italic ?? false,
              onTap: () => _applyStyle(italic: !(selStyle?.italic ?? false))),
          RibbonButton(OfficeIcons.textColor, context.t('excel.font_color'),
              onTap: () =>
                  _pickColor(context.t('excel.font_color'), _applyFontColor)),
          RibbonButton(OfficeIcons.fillColor, context.t('excel.fill_color'),
              onTap: () =>
                  _pickColor(context.t('excel.fill_color'), _applyFillColor)),
          RibbonButton(OfficeIcons.borders, context.t('excel.borders'),
              onTap: _showBorders),
          const RibbonSep(),
          RibbonMenu<TextAlign>(
            icon: _alignIcon(align),
            tooltip: context.t('excel.alignment'),
            onSelected: (a) => _applyStyle(align: a),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: TextAlign.left,
                checked: align == XlsxHAlign.left,
                child: Text(context.t('common.align_left')),
              ),
              CheckedPopupMenuItem(
                value: TextAlign.center,
                checked: align == XlsxHAlign.center,
                child: Text(context.t('common.align_center')),
              ),
              CheckedPopupMenuItem(
                value: TextAlign.right,
                checked: align == XlsxHAlign.right,
                child: Text(context.t('common.align_right')),
              ),
            ],
          ),
          RibbonButton(OfficeIcons.wrapText, context.t('excel.wrap_text'),
              active: selStyle?.wrap ?? false,
              onTap: () => _applyWrap(!(selStyle?.wrap ?? false))),
          RibbonButton(OfficeIcons.merge,
              context.t(merged ? 'excel.unmerge' : 'excel.merge'),
              active: merged, onTap: _toggleMerge),
          const RibbonSep(),
          RibbonMenu<String>(
            icon: OfficeIcons.numberFormat,
            tooltip: context.t('excel.number_format'),
            onSelected: (code) => _applyNumberFormat((_) => code),
            itemBuilder: (_) => [
              for (final (key, code) in _SpreadsheetEditorScreenState._numberFormatPresets)
                CheckedPopupMenuItem(
                  value: code,
                  checked: _sheet?.numFmtCode(_selRow, _selCol) == code,
                  child: Text(context.t(key)),
                ),
            ],
          ),
          RibbonButton(AppIcons.add, context.t('excel.decimal_more'),
              onTap: () => _applyNumberFormat((c) => bumpDecimals(c, 1))),
          RibbonButton(AppIcons.remove, context.t('excel.decimal_less'),
              onTap: () => _applyNumberFormat((c) => bumpDecimals(c, -1))),
          RibbonButton(OfficeIcons.autoSum, context.t('excel.autosum'),
              onTap: _autoSum),
          const RibbonSep(),
          RibbonButton(AppIcons.cellStyles, context.t('excel.format_cells'),
              key: const ValueKey('xl-format-cells'),
              onTap: () => _showFormatCells()),
          RibbonButton(AppIcons.palette, context.t('excel.cell_styles'),
              key: const ValueKey('xl-cell-styles'), onTap: _showCellStyles),
        ]),
        RibbonTab(context.t('excel.tab_insert'), [
          RibbonButton(AppIcons.keyboardArrowUp,
              context.t('excel.insert_row_above'),
              onTap: () => _insertRow(below: false)),
          RibbonButton(AppIcons.keyboardArrowDown,
              context.t('excel.insert_row_below'),
              onTap: () => _insertRow(below: true)),
          RibbonButton(AppIcons.keyboardArrowLeft,
              context.t('excel.insert_col_left'),
              onTap: () => _insertColumn(right: false)),
          RibbonButton(AppIcons.keyboardArrowRight,
              context.t('excel.insert_col_right'),
              onTap: () => _insertColumn(right: true)),
          const RibbonSep(),
          RibbonButton(OfficeIcons.insertRow, context.t('excel.delete_row'),
              onTap: _deleteRow),
          RibbonButton(
              OfficeIcons.insertColumn, context.t('excel.delete_col'),
              onTap: _deleteColumn),
          RibbonButton(
              OfficeIcons.clearContents, context.t('excel.clear_contents'),
              onTap: _clearSelection),
          const RibbonSep(),
          RibbonButton(OfficeIcons.rowHeight, context.t('excel.row_height'),
              onTap: () => _showSizeDialog(row: _selRow)),
          RibbonButton(
              OfficeIcons.columnWidth, context.t('excel.column_width'),
              onTap: () => _showSizeDialog(col: _selCol)),
          RibbonButton(OfficeIcons.sheetAdd, context.t('excel.add_sheet'),
              onTap: _addSheet),
          const RibbonSep(),
          RibbonButton(AppIcons.insertChart, context.t('chart.insert'),
              key: const ValueKey('xl-ins-chart'), onTap: _insertChart),
          RibbonButton(AppIcons.comment, context.t('excel.note_new'),
              key: const ValueKey('xl-ins-note'), onTap: _editNote),
        ]),
        RibbonTab(context.t('excel.tab_formulas'), [
          RibbonButton(OfficeIcons.autoSum, context.t('excel.autosum'),
              onTap: _autoSum),
          for (final (fn, key) in const [
            ('ORTALAMA', 'excel.fn_average'),
            ('BAĞ_DEĞ_SAY', 'excel.fn_count'),
            ('MAK', 'excel.fn_max'),
            ('MİN', 'excel.fn_min'),
          ])
            RibbonButton(OfficeIcons.autoSum, context.t(key),
                key: ValueKey('xl-fn-$fn'), onTap: () => _autoFunction(fn)),
        ]),
        RibbonTab(context.t('excel.tab_data'), [
          RibbonButton(OfficeIcons.sortAsc, context.t('excel.sort_asc'),
              onTap: () => _sortSelection(true)),
          RibbonButton(OfficeIcons.sortDesc, context.t('excel.sort_desc'),
              onTap: () => _sortSelection(false)),
          RibbonButton(OfficeIcons.sortAsc, context.t('excel.custom_sort'),
              key: const ValueKey('xl-custom-sort'), onTap: _customSort),
          RibbonButton(OfficeIcons.filter,
              context.t(_sheet?.layout.autoFilterRef == null
                  ? 'excel.filter_create'
                  : 'excel.filter_remove'),
              key: const ValueKey('xl-filter-toggle'),
              active: _sheet?.layout.autoFilterRef != null,
              onTap: _toggleAutoFilter),
          RibbonButton(OfficeIcons.filter, context.t('excel.filter'),
              onTap: _filterSelectedColumn),
          RibbonButton(AppIcons.validation, context.t('excel.validation'),
              key: const ValueKey('xl-validation'), onTap: _showValidation),
          const RibbonSep(),
          RibbonButton(AppIcons.clipCopy, context.t('excel.dup_title'),
              key: const ValueKey('xl-dedup'), onTap: _removeDuplicates),
          RibbonButton(AppIcons.viewColumn, context.t('excel.split_title'),
              key: const ValueKey('xl-split'), onTap: _splitTextToColumns),
          const RibbonSep(),
          RibbonButton(OfficeIcons.condFormat, context.t('excel.cond_format'),
              onTap: _showCondFormat),
          RibbonButton(OfficeIcons.search, context.t('common.search'),
              active: _finding, onTap: _toggleFind),
          RibbonButton(OfficeIcons.goTo, context.t('excel.goto_cell_menu'),
              onTap: _showGoTo),
          const RibbonSep(),
          RibbonButton(OfficeIcons.cut, context.t('excel.cut'),
              onTap: () => _copySelection(cut: true)),
          RibbonButton(OfficeIcons.copy, context.t('common.copy'),
              onTap: _copySelection),
          RibbonButton(OfficeIcons.paste, context.t('excel.paste'),
              onTap: _paste),
        ]),
        RibbonTab(context.t('word.tab_review'), [
          RibbonButton(AppIcons.comment,
              context.t(_noteHere ? 'excel.note_edit' : 'excel.note_new'),
              key: const ValueKey('xl-note'), onTap: _editNote),
          if (_noteHere)
            RibbonButton(AppIcons.delete, context.t('excel.note_delete'),
                key: const ValueKey('xl-note-delete'),
                onTap: () => _setNote(_selRow, _selCol, null)),
          RibbonButton(OfficeIcons.translate, context.t('common.translate'),
              onTap: _translate),
        ]),
        RibbonTab(context.t('excel.tab_view'), [
          RibbonButton(OfficeIcons.zoomOut, context.t('excel.zoom_out'),
              onTap: () => _zoomCtl.zoomBy(1 / 1.25)),
          RibbonChip(
            icon: AppIcons.search,
            label: '%${(_zoom * 100).round()}',
            tooltip: context.t('excel.zoom_reset'),
            onTap: () => _zoomCtl.setZoom(1),
          ),
          RibbonButton(OfficeIcons.zoomIn, context.t('excel.zoom_in'),
              onTap: () => _zoomCtl.zoomBy(1.25)),
          const RibbonSep(),
          RibbonMenu<String>(
            key: const ValueKey('xl-freeze-menu'),
            icon: OfficeIcons.freeze,
            tooltip: context.t('excel.freeze_menu'),
            onSelected: _setFreeze,
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'cell', child: Text(ctx.t('excel.freeze_cell'))),
              PopupMenuItem(
                  value: 'row', child: Text(ctx.t('excel.freeze_row'))),
              PopupMenuItem(
                  value: 'col', child: Text(ctx.t('excel.freeze_col'))),
              if (_sheetHasFreeze)
                PopupMenuItem(
                    value: 'none', child: Text(ctx.t('excel.unfreeze_panes'))),
            ],
          ),
          if (_sheetHasFreeze)
            RibbonButton(
                AppIcons.hidden,
                context.t(_freeze
                    ? 'excel.freeze_off_view'
                    : 'excel.freeze_on_view'),
                active: _freeze,
                onTap: _toggleFreeze),
          RibbonMenu<String>(
            key: const ValueKey('xl-hide-menu'),
            icon: AppIcons.hiddenOff,
            tooltip: context.t('excel.hide_show'),
            onSelected: (v) {
              switch (v) {
                case 'hide-row':
                  _hideLines(rows: true);
                case 'hide-col':
                  _hideLines(rows: false);
                case 'show-row':
                  _showHiddenLines(rows: true);
                case 'show-col':
                  _showHiddenLines(rows: false);
              }
            },
            itemBuilder: (ctx) => [
              PopupMenuItem(
                  value: 'hide-row', child: Text(ctx.t('excel.hide_row'))),
              PopupMenuItem(
                  value: 'hide-col', child: Text(ctx.t('excel.hide_col'))),
              PopupMenuItem(
                  value: 'show-row', child: Text(ctx.t('excel.show_rows'))),
              PopupMenuItem(
                  value: 'show-col', child: Text(ctx.t('excel.show_cols'))),
            ],
          ),
          RibbonButton(AppIcons.borders, context.t('excel.gridlines'),
              key: const ValueKey('xl-gridlines'),
              active: _sheet?.layout.showGridLines ?? true,
              onTap: _toggleGridLines),
          RibbonButton(AppIcons.formView, context.t('excel.form_view'),
              key: const ValueKey('xl-form-view'), onTap: _showFormView),
          if (_editor?.sheets.any((s) => s.layout.hidden) ?? false)
            RibbonButton(AppIcons.hiddenOff, context.t('excel.unhide_sheet'),
                key: const ValueKey('xl-unhide-sheet'), onTap: _unhideSheet),
          RibbonButton(AppIcons.formatTextdirectionRToL,
              context.t('excel.sheet_rtl'),
              active: _sheet?.rightToLeft ?? false,
              onTap: _toggleSheetDirection),
          RibbonButton(OfficeIcons.undo, context.t('excel.undo'),
              onTap: _undo.canUndo ? _undoStep : null),
          RibbonButton(OfficeIcons.redo, context.t('excel.redo'),
              onTap: _undo.canRedo ? _redoStep : null),
        ]),
      ],
      // Etiketli sayfa: seyrek ama gerekli olan her şey burada kalır.
      trailing: TextButton.icon(
        onPressed: _showMore,
        icon: const Icon(OfficeIcons.more, size: 20),
        label: Text(context.t('common.more')),
      ),
    );
  }

  /// Seçili hücrenin puntosu (yoksa dosyanın tabanı 11).
  String _sizeText(double? size) => '${(size ?? 11).round()}';

  /// Seçili aralığın yazı tipini değiştirir. Liste uygulamada GÖMÜLÜ olan ve
  /// her cihazda bulunan ailelerle sınırlı: seçilen ad hem ekranda çizilebilsin
  /// hem de dosyaya yazılınca Excel'de aynı görünsün.
  Future<void> _pickFontFamily() async {
    _endEdit();
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontFamily;
    final pick = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final f in _SpreadsheetEditorScreenState._fontFamilies)
              ListTile(
                // Örnek yazı GÖMÜLÜ karşılıkla çizilir: "Georgia" adıyla
                // çizmeye kalkmak Android'de sessizce Roboto'ya düşerdi.
                title: Text(f, style: TextStyle(fontFamily: renderFamilyFor(f))),
                trailing: f == current ? const Icon(AppIcons.check) : null,
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    _applyCellFormat(
      'excel.undo_font',
      (ed, s, r, c) => ed.setFontFamily(s, r, c, pick),
      (ed, s, r, c, before) => ed.setFontFamily(s, r, c, before.fontFamily),
    );
  }

  Future<void> _pickFontSize() async {
    _endEdit();
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontSize ?? 11;
    final pick = await showModalBottomSheet<double>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final s in _SpreadsheetEditorScreenState._fontSizes)
              ListTile(
                title: Text('${s.round()}'),
                trailing:
                    (s - current).abs() < 0.25 ? const Icon(AppIcons.check) : null,
                onTap: () => Navigator.pop(ctx, s),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    _applyFontSize(pick);
  }

  /// Puntoyu bir kademe büyütür/küçültür (Excel'in A▲ A▼ düğmeleri).
  void _bumpFontSize(int delta) {
    final current = _sheet?.styleAt(_selRow, _selCol)?.fontSize ?? 11;
    _applyFontSize((current + delta).clamp(6, 72).toDouble());
  }

  void _applyFontSize(double size) => _applyCellFormat(
        'excel.undo_font',
        (ed, s, r, c) => ed.setFontSize(s, r, c, size),
        (ed, s, r, c, before) => ed.setFontSize(s, r, c, before.fontSize ?? 11),
      );

  /// Seçili sütuna göre sıralar.
  ///
  /// Kaynak aralık sırayla: (1) çok satırlı seçim, (2) sayfanın otomatik
  /// süzgeç aralığı. İkisi de yoksa sıralamıyoruz — "hangi satırlar veri,
  /// hangisi başlık" tahmini yanlış çıkarsa tablo bozulur ve kullanıcı bunu
  /// ancak kaydettikten sonra fark eder.
  void _sortSelection(bool ascending) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r1 = math.min(_anchorRow, _selRow);
    final r2 = math.max(_anchorRow, _selRow);
    if (r2 > r1) {
      _sortByColumn(sheet, _selCol, r1, r2, ascending);
      return;
    }
    final range = _filterRange(sheet);
    if (range != null && _selCol >= range.c1 && _selCol <= range.c2) {
      _sortByColumn(sheet, _selCol, range.r1 + 1,
          math.max(range.r1 + 1, sheet.maxRows - 1), ascending);
      return;
    }
    _snack(context.t('excel.sort_needs_range'));
  }

  /// Süzgeç okunun yaptığını şeritten yapar (aralık yoksa açıklar).
  void _filterSelectedColumn() {
    final sheet = _sheet;
    if (sheet == null) return;
    if (!_filterCoversColumn(sheet, _selCol)) {
      _snack(context.t('excel.filter_needs_table'));
      return;
    }
    _showColumnFilter(sheet, _selCol);
  }

  IconData _alignIcon(XlsxHAlign? align) => switch (align) {
        XlsxHAlign.center => AppIcons.formatAlignCenter,
        XlsxHAlign.right => AppIcons.formatAlignRight,
        XlsxHAlign.justify => AppIcons.formatAlignJustify,
        _ => AppIcons.formatAlignLeft,
      };

  /// Çubuğa sığmayan eylemler — hepsi ETİKETLİ ve konusuna göre gruplu.
  void _showMore() {
    _endEdit();
    DocMoreSheet.show(context, [
      DocMoreGroup(context.t('excel.group_clipboard'), [
        DocMoreItem(AppIcons.cut, context.t('excel.cut'),
            () => _copySelection(cut: true)),
        DocMoreItem(
            AppIcons.clipCopy, context.t('common.copy'), _copySelection),
        DocMoreItem(AppIcons.paste, context.t('excel.paste'), _paste),
        DocMoreItem(AppIcons.backspace,
            context.t('excel.clear_contents'), _clearSelection),
      ]),
      DocMoreGroup(context.t('excel.group_number'), [
        DocMoreItem(AppIcons.add, context.t('excel.decimal_more'),
            () => _applyNumberFormat((c) => bumpDecimals(c, 1))),
        DocMoreItem(AppIcons.remove, context.t('excel.decimal_less'),
            () => _applyNumberFormat((c) => bumpDecimals(c, -1))),
      ]),
      DocMoreGroup(context.t('excel.group_format'), [
        DocMoreItem(AppIcons.formatColorFill, context.t('excel.fill_color'),
            () => _pickColor(context.t('excel.fill_color'), _applyFillColor)),
        DocMoreItem(AppIcons.formatColorText, context.t('excel.font_color'),
            () => _pickColor(context.t('excel.font_color'), _applyFontColor)),
        DocMoreItem(AppIcons.borderAll, context.t('excel.borders'), _showBorders),
        DocMoreItem(
          AppIcons.wrapText,
          context.t('excel.wrap_text'),
          () => _applyWrap(!(_sheet?.styleAt(_selRow, _selCol)?.wrap ?? false)),
          selected: _sheet?.styleAt(_selRow, _selCol)?.wrap ?? false,
        ),
        DocMoreItem(
          AppIcons.mergeType,
          context.t(_sheet?.mergeAt(_selRow, _selCol) != null
              ? 'excel.unmerge'
              : 'excel.merge'),
          _toggleMerge,
        ),
        DocMoreItem(AppIcons.rule, context.t('excel.cond_format'),
            _showCondFormat),
      ]),
      DocMoreGroup(context.t('chart.group_insert'), [
        DocMoreItem(
            AppIcons.insertChart, context.t('chart.insert'), _insertChart),
      ]),
      DocMoreGroup(context.t('excel.row'), [
        DocMoreItem(AppIcons.keyboardArrowUp,
            context.t('excel.insert_row_above'), () => _insertRow(below: false)),
        DocMoreItem(AppIcons.keyboardArrowDown,
            context.t('excel.insert_row_below'), () => _insertRow(below: true)),
        DocMoreItem(
            AppIcons.delete, context.t('excel.delete_row'), _deleteRow,
            danger: true),
        DocMoreItem(AppIcons.height, context.t('excel.row_height'),
            () => _showSizeDialog(row: _selRow)),
      ]),
      DocMoreGroup(context.t('excel.column'), [
        DocMoreItem(AppIcons.keyboardArrowLeft, context.t('excel.insert_col_left'),
            () => _insertColumn(right: false)),
        DocMoreItem(AppIcons.keyboardArrowRight,
            context.t('excel.insert_col_right'), () => _insertColumn(right: true)),
        DocMoreItem(
            AppIcons.delete, context.t('excel.delete_col'), _deleteColumn,
            danger: true),
        DocMoreItem(AppIcons.straighten, context.t('excel.column_width'),
            () => _showSizeDialog(col: _selCol)),
      ]),
    ]);
  }

  /// **Grafik ekle** (Faz 9 / Y2): seçili aralıktan (ilk satır başlık, ilk
  /// sütun kategori) önizlemeli pencere → grafik modele eklenir, kaydedince
  /// dosyaya yazılır (bkz. [XlsxChartWriter]). Geri alınabilir.
  Future<void> _insertChart() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _range;
    if (r.bottom <= r.top) {
      _snack(context.t('chart.select_range'));
      return;
    }
    final engine = _engineFor(sheet);
    final spec = await showChartInsertDialog(
      context,
      (kind, title) => XlsxChartSpec.fromRange(
        sheetName: sheet.name,
        kind: kind,
        top: r.top,
        left: r.left,
        bottom: r.bottom,
        right: r.right,
        display: engine.displayValue,
        title: title,
      ),
    );
    if (spec == null || !mounted) return;
    editor.addChart(spec);
    _recordStep('chart.undo_add', () => editor.charts.add(spec),
        () => editor.charts.remove(spec));
    _session.changed();
    _partSetState(() {});
    _snack(context.t('chart.added'));
  }

  /// Çevir: birden çok hücre seçiliyse seçimin görünen metni (sekme/satır
  /// düzeniyle), değilse belgenin tamamı.
  void _translate() {
    final sheet = _sheet;
    if (sheet == null || !_hasRange) {
      TranslateFlow.run(context, widget.plainText, title: widget.name);
      return;
    }
    _endEdit();
    final engine = _engineFor(sheet);
    final r = _range;
    final text = rangeText(r, engine.displayValue);
    if (text.trim().isEmpty) {
      _snack(context.t('tf.no_text'));
      return;
    }
    QuickTranslateSheet.show(context, text, title: widget.name);
  }
}

/// Aralığın metni: sütunlar sekmeyle, satırlar satır sonuyla; tamamen boş
/// satırlar atlanır (Excel'den kopyalanan biçimin aynısı).
String rangeText(CellRange r, String Function(int row, int col) value) {
  final lines = <String>[];
  for (var row = r.top; row <= r.bottom; row++) {
    final cells = [for (var c = r.left; c <= r.right; c++) value(row, c)];
    if (cells.every((v) => v.trim().isEmpty)) continue;
    lines.add(cells.join('\t').trimRight());
  }
  return lines.join('\n');
}

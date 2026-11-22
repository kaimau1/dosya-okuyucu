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

    // Sadeleştirilmiş şerit (Faz 36 madde 7): tek sekme, en sık işler.
    // Tam şerit Görünüm sekmesinden ya da buradaki düğmeden geri gelir.
    if (_simpleRibbon && _excelPro) {
      final scheme = Theme.of(context).colorScheme;
      return OfficeRibbon(
        compact: true,
        tabs: [
          RibbonTab(context.t('xp.ribbon_simple'), [
            RibbonButton(OfficeIcons.bold, context.t('common.bold'),
                active: selStyle?.bold ?? false,
                onTap: () => _applyStyle(bold: !(selStyle?.bold ?? false))),
            RibbonButton(OfficeIcons.underline, context.t('common.underline'),
                key: const ValueKey('xl-underline'),
                active: selStyle?.underline ?? false,
                onTap: () =>
                    _applyDecoration(underline: !(selStyle?.underline ?? false))),
            RibbonButton(OfficeIcons.fillColor, context.t('excel.fill_color'),
                indicator:
                    selStyle?.background ?? scheme.surfaceContainerHighest,
                onTap: () =>
                    _pickColor(context.t('excel.fill_color'), _applyFillColor)),
            RibbonButton(OfficeIcons.borders, context.t('excel.borders'),
                onTap: _showBorders),
            RibbonButton(OfficeIcons.autoSum, context.t('excel.autosum'),
                onTap: _autoSum),
            RibbonButton(OfficeIcons.sortAsc, context.t('excel.sort_asc'),
                onTap: () => _sortSelection(true)),
            RibbonButton(OfficeIcons.filter, context.t('excel.filter'),
                onTap: _filterSelectedColumn),
            RibbonButton(OfficeIcons.condFormat, context.t('excel.cond_format'),
                onTap: _showCondFormat),
            RibbonButton(AppIcons.insertChart, context.t('chart.insert'),
                onTap: _insertChart),
            RibbonButton(AppIcons.pdfTable, context.t('xp.pivot'),
                onTap: _createPivot),
            const RibbonSep(),
            RibbonButton(AppIcons.tune, context.t('xp.ribbon_full'),
                key: const ValueKey('xl-ribbon-full'),
                onTap: () => _setSimpleRibbon(false)),
          ]),
        ],
      );
    }

    final scheme = Theme.of(context).colorScheme;
    RibbonChip chip(String labelKey, IconData icon, VoidCallback? onTap,
            {Key? key, String? tipKey, bool? active}) =>
        RibbonChip(
          key: key,
          icon: icon,
          label: context.t(labelKey),
          tooltip: context.t(tipKey ?? labelKey),
          active: active,
          onTap: onTap,
        );

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
          RibbonButton(OfficeIcons.underline, context.t('common.underline'),
              key: const ValueKey('xl-underline'),
              active: selStyle?.underline ?? false,
              onTap: () =>
                  _applyDecoration(underline: !(selStyle?.underline ?? false))),
          RibbonButton(OfficeIcons.textColor, context.t('excel.font_color'),
              indicator: selStyle?.fontColor ?? scheme.onSurface,
              onTap: () =>
                  _pickColor(context.t('excel.font_color'), _applyFontColor)),
          RibbonButton(OfficeIcons.fillColor, context.t('excel.fill_color'),
              indicator: selStyle?.background ?? scheme.surfaceContainerHighest,
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
          if (_excelPro)
          RibbonButton(AppIcons.formatPaint, context.t('xp.painter'),
              key: const ValueKey('xl-format-painter'),
              active: _painter != null,
              onTap: _toggleFormatPainter),
        ]),
        RibbonTab(context.t('excel.tab_insert'), [
          chip('excel.row_above_short', AppIcons.keyboardArrowUp,
              () => _insertRow(below: false),
              tipKey: 'excel.insert_row_above'),
          chip('excel.row_below_short', AppIcons.keyboardArrowDown,
              () => _insertRow(below: true),
              tipKey: 'excel.insert_row_below'),
          chip('excel.col_left_short', AppIcons.keyboardArrowLeft,
              () => _insertColumn(right: false),
              tipKey: 'excel.insert_col_left'),
          chip('excel.col_right_short', AppIcons.keyboardArrowRight,
              () => _insertColumn(right: true),
              tipKey: 'excel.insert_col_right'),
          const RibbonSep(),
          chip('excel.delete_row', AppIcons.delete, _deleteRow),
          chip('excel.delete_col', AppIcons.removeCircleOutline, _deleteColumn),
          chip('excel.clear_contents', OfficeIcons.clearContents,
              _clearSelection),
          const RibbonSep(),
          chip('excel.row_height', OfficeIcons.rowHeight,
              () => _showSizeDialog(row: _selRow)),
          chip('excel.column_width', OfficeIcons.columnWidth,
              () => _showSizeDialog(col: _selCol)),
          chip('excel.add_sheet', OfficeIcons.sheetAdd, _addSheet),
          const RibbonSep(),
          chip('chart.insert', AppIcons.insertChart, _insertChart,
              key: const ValueKey('xl-ins-chart')),
          if (_excelPro)
            chip('xp.sparkline', AppIcons.trendingUp, _insertSparklines,
                key: const ValueKey('xl-ins-spark')),
          if (_excelPro)
            chip('xp.link', AppIcons.link, _insertLink,
                key: const ValueKey('xl-ins-link')),
        ]),
        RibbonTab(context.t('excel.tab_formulas'), [
          chip('excel.fn_sum_short', OfficeIcons.autoSum, _autoSum,
              tipKey: 'excel.autosum', key: const ValueKey('xl-fn-SUM')),
          for (final (fn, icon, key) in const [
            ('AVERAGE', AppIcons.topicTax, 'excel.fn_average'),
            ('COUNT', AppIcons.numbers, 'excel.fn_count'),
            ('MAX', AppIcons.expandLess, 'excel.fn_max'),
            ('MIN', AppIcons.expandMore, 'excel.fn_min'),
          ])
            chip(key, icon, () => _autoFunction(fn),
                key: ValueKey('xl-fn-$fn')),
          chip('excel.fx_library', AppIcons.functions, _showFunctionLibrary,
              key: const ValueKey('xl-fx-lib')),
          if (_excelPro) ...[
            const RibbonSep(),
            chip('xp.trace_prec', AppIcons.accountTree, _tracePrecedents,
                key: const ValueKey('xl-trace-prec')),
            chip('xp.trace_dep', AppIcons.traceDependents, _traceDependents,
                key: const ValueKey('xl-trace-dep')),
            if (_arrows.isNotEmpty)
              chip('xp.trace_clear', AppIcons.close, _clearArrows,
                  active: true),
            chip('xp.goal_seek', AppIcons.goalSeek, _goalSeek,
                key: const ValueKey('xl-goal-seek')),
          ],
        ]),
        RibbonTab(context.t('excel.tab_data'), [
          chip('excel.sort_asc_short', OfficeIcons.sortAsc,
              () => _sortSelection(true),
              tipKey: 'excel.sort_asc'),
          chip('excel.sort_desc_short', OfficeIcons.sortDesc,
              () => _sortSelection(false),
              tipKey: 'excel.sort_desc'),
          chip('excel.custom_sort', AppIcons.sort, _customSort,
              key: const ValueKey('xl-custom-sort')),
          chip(
              _sheet?.layout.autoFilterRef == null
                  ? 'excel.filter_create'
                  : 'excel.filter_remove',
              OfficeIcons.filter,
              _toggleAutoFilter,
              key: const ValueKey('xl-filter-toggle'),
              active: _sheet?.layout.autoFilterRef != null),
          chip('excel.filter', AppIcons.filterAlt, _filterSelectedColumn),
          chip('excel.validation', AppIcons.validation, _showValidation,
              key: const ValueKey('xl-validation')),
          const RibbonSep(),
          chip('excel.dup_title', AppIcons.clipCopy, _removeDuplicates,
              key: const ValueKey('xl-dedup')),
          chip('excel.split_title', AppIcons.viewColumn, _splitTextToColumns,
              key: const ValueKey('xl-split')),
          chip('excel.flash_fill', AppIcons.bolt, _flashFill,
              key: const ValueKey('xl-flash-fill')),
          if (_excelPro) ...[
            chip('xp.pivot', AppIcons.pdfTable, _createPivot,
                key: const ValueKey('xl-pivot')),
            chip('xp.import', AppIcons.download, _importData,
                key: const ValueKey('xl-import')),
            chip('xp.subtotal', AppIcons.functions, _insertSubtotals,
                key: const ValueKey('xl-subtotal')),
            chip('xp.group', AppIcons.formatIndentIncrease,
                () => _groupSelectedRows(true),
                key: const ValueKey('xl-group')),
            chip('xp.ungroup', AppIcons.formatIndentDecrease,
                () => _groupSelectedRows(false),
                key: const ValueKey('xl-ungroup')),
            chip('xp.toggle_group', AppIcons.expandLess, _toggleOutlineGroup,
                key: const ValueKey('xl-toggle-group')),
          ],
          if (_pivots.containsKey(_sheet?.name))
            chip('xp.pivot_refresh', AppIcons.refresh, _refreshPivot,
                key: const ValueKey('xl-pivot-refresh')),
          const RibbonSep(),
          chip('excel.cond_format', OfficeIcons.condFormat, _showCondFormat),
          chip('excel.goto_cell_menu', OfficeIcons.goTo, _showGoTo),
        ]),
        RibbonTab(context.t('word.tab_review'), [
          chip(_noteHere ? 'excel.note_edit' : 'excel.note_new',
              AppIcons.comment, _editNote,
              key: const ValueKey('xl-note')),
          if (_noteHere && _excelPro)
            chip('xp.note_reply', AppIcons.forum, _replyToNote,
                key: const ValueKey('xl-note-reply')),
          if (_noteHere)
            chip('excel.note_delete', AppIcons.delete,
                () => _setNote(_selRow, _selCol, null),
                key: const ValueKey('xl-note-delete')),
          // Faz 36 madde 12: sayfa koruması + düzenlenebilir aralık.
          if (_excelPro || (_sheet?.isProtected ?? false)) ...[
            const RibbonSep(),
            chip(
                (_sheet?.isProtected ?? false)
                    ? 'xp.unprotect'
                    : 'xp.protect_sheet',
                (_sheet?.isProtected ?? false) ? AppIcons.unlock : AppIcons.lock,
                _toggleSheetProtection,
                key: const ValueKey('xl-protect'),
                active: _sheet?.isProtected ?? false),
            chip('xp.allow_edit', AppIcons.editNote, _toggleAllowEdit,
                key: const ValueKey('xl-allow-edit')),
          ],
        ]),
        RibbonTab(context.t('excel.tab_view'), [
          if (_excelPro) ...[
            chip('xp.ribbon_simple', AppIcons.tune,
                () => _setSimpleRibbon(true),
                key: const ValueKey('xl-ribbon-simple')),
            PopupMenuButton<double>(
              key: const ValueKey('xl-density'),
              tooltip: context.t('xp.density'),
              onSelected: _setDensity,
              itemBuilder: (ctx) => [
                for (final (v, k) in const [
                  (0.85, 'xp.density_compact'),
                  (1.0, 'xp.density_normal'),
                  (1.2, 'xp.density_comfortable'),
                ])
                  PopupMenuItem(value: v, child: Text(ctx.t(k))),
              ],
              child: RibbonChip(
                icon: AppIcons.formatLineSpacing,
                label: context.t('xp.density'),
                tooltip: context.t('xp.density'),
              ),
            ),
            const RibbonSep(),
          ],
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
          PopupMenuButton<String>(
            key: const ValueKey('xl-freeze-menu'),
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
            child: RibbonChip(
              icon: OfficeIcons.freeze,
              label: context.t('excel.freeze_menu'),
              tooltip: context.t('excel.freeze_menu'),
            ),
          ),
          if (_sheetHasFreeze)
            chip(
                _freeze ? 'excel.freeze_off_view' : 'excel.freeze_on_view',
                AppIcons.hidden,
                _toggleFreeze,
                active: _freeze),
          PopupMenuButton<String>(
            key: const ValueKey('xl-hide-menu'),
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
            child: RibbonChip(
              icon: AppIcons.hiddenOff,
              label: context.t('excel.hide_show'),
              tooltip: context.t('excel.hide_show'),
            ),
          ),
          chip('excel.gridlines', AppIcons.borders, _toggleGridLines,
              key: const ValueKey('xl-gridlines'),
              active: _sheet?.layout.showGridLines ?? true),
          chip('excel.form_view', AppIcons.formView, _showFormView,
              key: const ValueKey('xl-form-view')),
          if (_editor?.sheets.any((s) => s.layout.hidden) ?? false)
            chip('excel.unhide_sheet', AppIcons.hiddenOff, _unhideSheet,
                key: const ValueKey('xl-unhide-sheet')),
          chip('excel.sheet_rtl', AppIcons.formatTextdirectionRToL,
              _toggleSheetDirection,
              active: _sheet?.rightToLeft ?? false),
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
      // Faz 36 madde 6: yazdırma düzeni / PDF + parola.
      if (_excelPro)
      DocMoreGroup(context.t('xp.print_group'), [
        DocMoreItem(AppIcons.pdf, context.t('xp.print_pdf'), _printToPdf),
        DocMoreItem(AppIcons.print, context.t('xp.print_area_set_btn'),
            () => _setPrintArea(clear: false)),
        if (_sheet?.printArea != null)
          DocMoreItem(AppIcons.close, context.t('xp.print_area_clear'),
              () => _setPrintArea(clear: true)),
        if (_filePassword == null)
          DocMoreItem(AppIcons.lock, context.t('xp.password_set'),
              _protectWithPassword)
        else
          DocMoreItem(AppIcons.unlock, context.t('xp.password_remove'),
              _removePassword),
      ]),
      DocMoreGroup(context.t('chart.group_insert'), [
        DocMoreItem(
            AppIcons.insertChart, context.t('chart.insert'), _insertChart),
        if (_excelPro)
        DocMoreItem(
            AppIcons.trendingUp, context.t('xp.sparkline'), _insertSparklines),
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
      TranslateFlow.run(context, _docText, title: widget.name);
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

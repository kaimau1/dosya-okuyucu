part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenHeadersPart on _SpreadsheetEditorScreenState {
  Widget _colHeader(XlsxSheet sheet, int c) {
    final scheme = Theme.of(context).colorScheme;
    final active = _inSelection(_selRow, c) ||
        (c >= math.min(_anchorCol, _selCol) &&
            c <= math.max(_anchorCol, _selCol));
    final width = sheet.colWidth(c) * _zoom;
    final height = _SpreadsheetEditorScreenState._headerH * _zoom;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _endEdit();
                _partSetState(() {
                  _anchorRow = 0;
                  _anchorCol = c;
                  _selRow = math.max(0, sheet.maxRows - 1);
                  _selCol = c;
                });
              },
              onLongPress: () => _showSizeDialog(col: c),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? OfficeColors.excel.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                      color: Theme.of(context).dividerColor, width: 0.5),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(XlsxRange.colName(c),
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 11 * _zoom)),
                      ),
                    ),
                    // Otomatik süzgeç oku: dosyada `<autoFilter>` varsa ve bu
                    // sütun aralığındaysa çizilir.
                    if (_filterCoversColumn(sheet, c))
                      GestureDetector(
                        onTap: () => _showColumnFilter(sheet, c),
                        child: Icon(
                          sheet.isColFiltered(c)
                              ? AppIcons.filterAlt
                              : AppIcons.dropDown,
                          size: 12 * _zoom,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Sağ kenardaki sürükleme tutamağı — dar sütunda başlığın yarısından
          // fazlasını kaplamasın (yoksa sütun seçilemez olurdu).
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            width: math.min(_SpreadsheetEditorScreenState._resizeGrip, math.max(8, width * 0.45)),
            child: _resizeGripFor(col: c),
          ),
        ],
      ),
    );
  }

  /// Bu sütunda süzgeç oku çizilmeli mi (aralık sütunu kapsıyor mu)?
  bool _filterCoversColumn(XlsxSheet sheet, int c) {
    final range = _filterRange(sheet);
    return range != null && c >= range.c1 && c <= range.c2;
  }

  /// Sayfanın otomatik süzgeç aralığı (yoksa null).
  XlsxRange? _filterRange(XlsxSheet sheet) {
    final ref = sheet.layout.autoFilterRef;
    if (ref == null) return null;
    return XlsxRange.parse(ref);
  }

  /// Süzgeç oku menüsü: A→Z / Z→A sırala + değer / içerir / ilk-son 10 /
  /// renge göre süz (B10 m.5).
  Future<void> _showColumnFilter(XlsxSheet sheet, int c) async {
    _endEdit();
    final range = _filterRange(sheet);
    if (range == null) return;
    // Başlık satırı süzgecin ilk satırıdır; veri onun altından başlar.
    final firstData = range.r1 + 1;
    final lastData = math.max(firstData, sheet.maxRows - 1);

    final values = <String>{};
    final fills = <int>{};
    for (var r = firstData; r <= lastData; r++) {
      values.add(sheet.rawAt(r, c));
      final f = sheet.styleAt(r, c)?.background?.toARGB32();
      if (f != null && fills.length < 12) fills.add(f);
    }
    final sorted = values.toList()..sort(compareCellText);
    final hidden = sheet.filterHidden[c] ?? const <int>{};
    final initial = sheet.filterCriteria[c] ??
        ColumnFilter(hiddenValues: {
          for (final r in hidden)
            if (r >= firstData && r <= lastData) sheet.rawAt(r, c),
        });
    final fillList = fills.toList();

    if (!mounted) return;
    final result = await showModalBottomSheet<ColumnFilter>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColumnFilterSheet(
        title: context.t('excel.filter_column',
            {'col': XlsxRange.colName(c)}),
        values: sorted,
        initial: initial,
        fills: fillList,
        onSort: (asc) {
          Navigator.pop(ctx);
          _sortByColumn(sheet, c, firstData, lastData, asc);
        },
      ),
    );
    if (result == null || !mounted) return;
    _applyColumnFilter(sheet, c, firstData, lastData, result);
  }

  /// Ölçüte uymayan satırları gizler (geri alınabilir); ölçüt dosyaya yazılır.
  void _applyColumnFilter(XlsxSheet sheet, int c, int firstData, int lastData,
      ColumnFilter filter) {
    final before = {...(sheet.filterHidden[c] ?? const <int>{})};
    final criterionBefore = sheet.filterCriteria[c];
    final engine = _engineFor(sheet);
    String shown(int r) => sheet.rawAt(r, c).startsWith('=')
        ? engine.displayValue(r, c)
        : sheet.rawAt(r, c);
    final after = filter.hiddenRows(
      firstData,
      lastData,
      raw: (r) => filter.hiddenValues.isNotEmpty ? sheet.rawAt(r, c) : shown(r),
      number: (r) => double.tryParse(shown(r).replaceAll(',', '.')),
      fill: (r) => sheet.styleAt(r, c)?.background?.toARGB32(),
    );
    void write(Set<int> rows, ColumnFilter? criterion) {
      // Önce bu sütunun eski gizlemeleri kaldırılır: başka bir sütunun
      // süzgeci ya da kullanıcının elle gizlediği satır ETKİLENMEMELİ.
      for (final r in sheet.filterHidden[c] ?? const <int>{}) {
        final stillHidden = sheet.filterHidden.entries
            .any((e) => e.key != c && e.value.contains(r));
        if (!stillHidden) sheet.layout.hiddenRows.remove(r);
      }
      sheet.filterHidden[c] = {...rows};
      sheet.layout.hiddenRows.addAll(rows);
      sheet.setFilterCriterion(c, criterion);
    }

    write(after, filter);
    _recordStep('excel.undo_filter', () => write(after, filter),
        () => write(before, criterionBefore));
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// Süzgeç aralığını bu sütuna göre sıralar. Satırlar **bütün olarak**
  /// taşınır (değer + biçim + hücre kaydı), yoksa satırın gerisi yerinde
  /// kalıp veri birbirine karışırdı.
  void _sortByColumn(
      XlsxSheet sheet, int c, int firstData, int lastData, bool ascending) {
    final editor = _editor;
    if (editor == null || lastData <= firstData) return;
    final name = sheet.name;
    // Satır genişliği bir kez (eskiden her satırda bütün satırlar taranıyordu
    // → 10 bin satırda ~100 M işlem, X4).
    final width = sheet.maxCols;
    final before = [
      for (var r = firstData; r <= lastData; r++)
        editor.captureRow(name, r, width: width),
    ];
    // Formül hücresi SONUCUYLA karşılaştırılır (X4: eskiden formül METNİYLE
    // — "=A1*2" metin olarak sıralanıyordu). Anahtar satır başına bir kez.
    final engine = _engineFor(sheet);
    final keys = <int, String>{
      for (var r = firstData; r <= lastData; r++)
        r: sheet.rawAt(r, c).startsWith('=')
            ? engine.displayValue(r, c)
            : sheet.rawAt(r, c),
    };
    final order = sortRowOrder(keys, ascending: ascending);
    final after = [
      for (final r in order) before[r - firstData],
    ];
    // B10 m.5: süzgeç aralığının sıralaması dosyaya `sortState` olarak yazılır.
    final sortBefore = sheet.filterSort;
    final sortAfter = [(col: c, descending: !ascending)];
    void write(List<SheetLineSnapshot> rows, List<SortLevelRef> sort) {
      for (var i = 0; i < rows.length; i++) {
        editor.restoreRow(name, firstData + i, rows[i]);
      }
      sheet.setFilterSort(sort);
    }

    write(after, sortAfter);
    _recordStep('excel.undo_sort', () => write(after, sortAfter),
        () => write(before, sortBefore));
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  Widget _rowHeader(XlsxSheet sheet, int r) {
    final scheme = Theme.of(context).colorScheme;
    final active = r >= math.min(_anchorRow, _selRow) &&
        r <= math.max(_anchorRow, _selRow);
    final width = _SpreadsheetEditorScreenState._rowHeaderW * _zoom;
    final height = sheet.rowHeight(r) * _zoom;
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () {
                _endEdit();
                _partSetState(() {
                  _anchorRow = r;
                  _anchorCol = 0;
                  _selRow = r;
                  _selCol = math.max(0, sheet.maxCols - 1);
                });
              },
              onLongPress: () => _showSizeDialog(row: r),
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: active
                      ? OfficeColors.excel.withValues(alpha: 0.22)
                      : scheme.surfaceContainerHighest,
                  border: Border.all(
                      color: Theme.of(context).dividerColor, width: 0.5),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text('${r + 1}',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 11 * _zoom)),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: math.min(_SpreadsheetEditorScreenState._resizeGrip, math.max(6, height * 0.45)),
            child: _resizeGripFor(row: r),
          ),
        ],
      ),
    );
  }

  /// Bir satırın hücreleri — birleştirilmiş hücrelerde ÇAPA tüm genişliği
  /// kaplar, kapsanan sütunlar atlanır (yoksa satır taşar). Çapa görünen
  /// pencerenin solunda kalmışsa kapsanan hücreler boş çizilir.
  List<Widget> _rowCells(_RenderContext ctx, int r, List<int> cols) {
    final sheet = ctx.sheet;
    final out = <Widget>[];
    final drawn = <int>{};
    // Görünen değerler satır başına BİR KEZ çözülür: hem taşma hesabı hem
    // hücre çizimi aynı değeri kullanır (formül hücrelerinde motor iki kez
    // koşmasın).
    final views = <int, XlsxCellView>{
      for (final c in cols)
        c: sheet.viewAt(r, c, ctx.engine.displayValue(r, c)),
    };
    final spill = _spillPlan(ctx, r, cols, views);
    for (final c in cols) {
      if (drawn.contains(c)) continue;
      final merge = sheet.mergeAt(r, c);
      if (merge != null && merge.colStart < c && cols.contains(merge.colStart)) {
        continue; // çapa bu satırda zaten çizildi ve genişliği kapsıyor
      }
      if (merge != null && merge.colStart == c) {
        for (var k = merge.colStart; k <= merge.colEnd; k++) {
          drawn.add(k);
        }
      }
      out.add(_cell(ctx, r, c, cols, views: views, spill: spill));
    }
    return out;
  }
}

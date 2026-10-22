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
                              ? Icons.filter_alt_rounded
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

  /// Süzgeç oku menüsü: A→Z / Z→A sırala + değere göre süz.
  Future<void> _showColumnFilter(XlsxSheet sheet, int c) async {
    _endEdit();
    final range = _filterRange(sheet);
    if (range == null) return;
    // Başlık satırı süzgecin ilk satırıdır; veri onun altından başlar.
    final firstData = range.r1 + 1;
    final lastData = math.max(firstData, sheet.maxRows - 1);

    final values = <String>{};
    for (var r = firstData; r <= lastData; r++) {
      values.add(sheet.rawAt(r, c));
    }
    final sorted = values.toList()..sort(_SpreadsheetEditorScreenState._compareCellText);
    final hidden = {...(sheet.filterHidden[c] ?? const <int>{})};
    // Gizli satırların değerleri "işaretsiz" gelmeli.
    final unchecked = <String>{
      for (final r in hidden)
        if (r >= firstData && r <= lastData) sheet.rawAt(r, c),
    };

    if (!mounted) return;
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _ColumnFilterSheet(
        title: context.t('excel.filter_column',
            {'col': XlsxRange.colName(c)}),
        values: sorted,
        unchecked: unchecked,
        onSort: (asc) {
          Navigator.pop(ctx);
          _sortByColumn(sheet, c, firstData, lastData, asc);
        },
      ),
    );
    if (result == null || !mounted) return;
    _applyColumnFilter(sheet, c, firstData, lastData, result);
  }

  /// Seçilmeyen değerlere sahip satırları gizler (geri alınabilir).
  void _applyColumnFilter(XlsxSheet sheet, int c, int firstData, int lastData,
      Set<String> unchecked) {
    final before = {...(sheet.filterHidden[c] ?? const <int>{})};
    final after = <int>{
      for (var r = firstData; r <= lastData; r++)
        if (unchecked.contains(sheet.rawAt(r, c))) r,
    };
    void write(Set<int> rows) {
      // Önce bu sütunun eski gizlemeleri kaldırılır: başka bir sütunun
      // süzgeci ya da kullanıcının elle gizlediği satır ETKİLENMEMELİ.
      for (final r in sheet.filterHidden[c] ?? const <int>{}) {
        final stillHidden = sheet.filterHidden.entries
            .any((e) => e.key != c && e.value.contains(r));
        if (!stillHidden) sheet.layout.hiddenRows.remove(r);
      }
      sheet.filterHidden[c] = {...rows};
      sheet.layout.hiddenRows.addAll(rows);
    }

    write(after);
    _recordStep('excel.undo_filter', () => write(after), () => write(before));
    _dirty = true;
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
    final before = [
      for (var r = firstData; r <= lastData; r++) editor.captureRow(name, r),
    ];
    final order = [for (var r = firstData; r <= lastData; r++) r]
      ..sort((a, b) {
        final cmp = _SpreadsheetEditorScreenState._compareCellText(sheet.rawAt(a, c), sheet.rawAt(b, c));
        return ascending ? cmp : -cmp;
      });
    final after = [
      for (final r in order) before[r - firstData],
    ];
    void write(List<SheetLineSnapshot> rows) {
      for (var i = 0; i < rows.length; i++) {
        editor.restoreRow(name, firstData + i, rows[i]);
      }
    }

    write(after);
    _recordStep('excel.undo_sort', () => write(after), () => write(before));
    _dirty = true;
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

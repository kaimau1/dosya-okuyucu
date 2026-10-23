part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenEditOpsPart on _SpreadsheetEditorScreenState {
  void _onHScroll() {
    if (!_syncing && _hTop.hasClients) {
      _syncing = true;
      final target = _hBody.offset.clamp(
          _hTop.position.minScrollExtent, _hTop.position.maxScrollExtent);
      if ((target - _hTop.offset).abs() > 0.01) _hTop.jumpTo(target);
      _syncing = false;
    }
    _updateColWindow();
  }

  void _onVScroll() {
    // Kenara yaklaşınca ızgara büyür (Faz 25 / madde 12).
    if (_vBody.hasClients && _vBody.position.extentAfter < 400 &&
        _vBody.position.maxScrollExtent > 0) {
      _extraRows += 100;
      _gridVersion++;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _partSetState(() {});
      });
    }
    if (_syncing || !_vLeft.hasClients) return;
    _syncing = true;
    final target = _vBody.offset.clamp(
        _vLeft.position.minScrollExtent, _vLeft.position.maxScrollExtent);
    if ((target - _vLeft.offset).abs() > 0.01) _vLeft.jumpTo(target);
    _syncing = false;
  }

  /// Görünen sütun penceresini yeniden hesaplar; DEĞİŞTİYSE yeniden çizer.
  /// (Her kaydırma pikselinde değil, sütun sınırı geçilince.)
  void _updateColWindow() {
    if (_colMetrics.isEmpty) return;
    final offset = _hBody.hasClients ? _hBody.offset : 0.0;
    final first = _colMetrics.firstAt(offset);
    final last = _colMetrics.lastAt(offset + _viewportW);
    if (first != _firstCol || last != _lastCol) {
      _partSetState(() {
        _firstCol = first;
        _lastCol = last;
      });
    }
  }

  /// Seçili hücreyi görünür yapar (Hücreye git, Enter ile aşağı inme,
  /// pencere dışında kalan seçim). Excel de seçimi kendine doğru kaydırır.
  void _ensureVisible(int r, int c) {
    if (_hBody.hasClients && !_colMetrics.isEmpty && _viewportW > 0) {
      final i = _colMetrics.positionOf(c);
      if (i >= 0) {
        final start = _colMetrics.startAt(i);
        final size = _colMetrics.sizeAt(i);
        final off = _hBody.offset;
        double? target;
        if (start < off) {
          target = start;
        } else if (start + size > off + _viewportW) {
          target = start + size - _viewportW;
        }
        if (target != null) {
          _hBody.jumpTo(target.clamp(0.0, _hBody.position.maxScrollExtent));
        }
      }
    }
    if (_vBody.hasClients && !_rowMetrics.isEmpty && _viewportH > 0) {
      final i = _rowMetrics.positionOf(r);
      if (i >= 0) {
        final start = _rowMetrics.startAt(i);
        final size = _rowMetrics.sizeAt(i);
        final off = _vBody.offset;
        double? target;
        if (start < off) {
          target = start;
        } else if (start + size > off + _viewportH) {
          target = start + size - _viewportH;
        }
        if (target != null) {
          _vBody.jumpTo(target.clamp(0.0, _vBody.position.maxScrollExtent));
        }
      }
    }
    _updateColWindow();
  }

  Future<void> _load() async {
    try {
      if (SpreadsheetEditorScreen.parseInIsolate) {
        try {
          _editor = await compute(_SpreadsheetEditorScreenState._readAndParse, widget.path);
        } catch (_) {
          // İzolat üretilemezse/sonuç taşınamazsa ana izlekte çöz.
          _editor = _SpreadsheetEditorScreenState._readAndParse(widget.path);
        }
      } else {
        _editor = _SpreadsheetEditorScreenState._readAndParse(widget.path);
      }
      _syncField();
    } catch (e) {
      _error = userErrorText(e);
    }
    if (mounted) _partSetState(() {});
    // Ekran açılmayı BEKLEMEZ: kaynak damgası + taslak araması arkada.
    // Okuma sınırında kesilmiş kitap kaydedilemez (Faz 26b): otomatik
    // kaydetme kapanır, kullanıcı şeritten nedenini okur.
    if (_editor?.truncated == true) _session.autoSaveForDoc = false;
    if (_editor != null) {
      unawaited(_warmCalc());
      unawaited(_session.captureSource());
      unawaited(lookForDraft(widget.savePath ?? widget.path));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
  }

  XlsxSheet? get _sheet {
    final e = _editor;
    if (e == null || e.sheets.isEmpty) return null;
    if (_sheetIndex >= e.sheets.length) return e.sheets.first;
    return e.sheets[_sheetIndex];
  }

  /// Formül motoru: tüm sayfalar görünür (çapraz sayfa referansı çalışsın).
  /// Motor ucuz bir görünümdür; hesap durumu ([_calc]) KALICIDIR — Faz 26.
  FormulaEngine _engineFor(XlsxSheet sheet) {
    _syncCalc();
    return FormulaEngine(
      sheet.rows,
      sheetName: sheet.name,
      sheets: {
        for (final s in _editor?.sheets ?? const <XlsxSheet>[]) s.name: s.rows,
      },
      state: _calc,
    );
  }

  /// Modelin değişiklik günlüğünü hesap durumuna işler: toplu değişiklikte
  /// (yapısal işlem, sayfa kümesi) baştan, hücre yazımında yalnız
  /// bağımlılar geçersiz.
  void _syncCalc() {
    final editor = _editor;
    if (editor == null) return;
    final log = editor.calcLog;
    // Güvenlik ağı: günlüğe uğramayan bir yol sayfa kümesini/boyunu
    // değiştirdiyse yine baştan kur.
    final shape = [
      for (final s in editor.sheets) '${s.name}:${s.rows.length}',
    ].join('|');
    if (!identical(editor, _calcEditor) ||
        log.generation != _calcGen ||
        shape != _calcShape) {
      _calc.reset();
      _calcEditor = editor;
      _calcGen = log.generation;
      _calcShape = shape;
      log.cells.clear();
      _calcChanged();
      return;
    }
    if (log.cells.isEmpty) return;
    for (final (s, r, c) in log.cells) {
      _calc.invalidate(s, r, c);
    }
    log.cells.clear();
    _calc.invalidateVolatile();
    _calcChanged();
  }

  /// Çok formüllü kitapta (≥ [CalcState.isolateThreshold]) ilk hesap
  /// isolate'te; bitince sonuç alınır — arada model değiştiyse atılır.
  Future<void> _warmCalc() async {
    final editor = _editor;
    if (editor == null || !SpreadsheetEditorScreen.parseInIsolate) return;
    final sheets = {for (final s in editor.sheets) s.name: s.rows};
    if (CalcState.formulaCount(sheets) < CalcState.isolateThreshold) return;
    _syncCalc();
    final stamp = _calcStamp;
    final gen = editor.calcLog.generation;
    final CalcState warmed;
    try {
      warmed = await compute(_SpreadsheetEditorScreenState._warmUp, sheets);
    } catch (_) {
      return; // isolate kurulamadı: tembel hesap sürer
    }
    if (!mounted ||
        !identical(_editor, editor) ||
        editor.calcLog.generation != gen ||
        editor.calcLog.cells.isNotEmpty ||
        _calcStamp != stamp) {
      return;
    }
    _calc = warmed;
    _calcChanged();
    _partSetState(() {});
  }

  void _calcChanged() {
    _calcStamp++;
    _condCache.clear();
    _statusMemo = null;
  }

  int _rowCount(XlsxSheet sheet) => math.max(
      math.max(sheet.rows.length, sheet.layout.rowCount) + _extraRows,
      _SpreadsheetEditorScreenState._minRows);

  int _colCount(XlsxSheet sheet) =>
      math.max(sheet.maxCols + _extraCols, _SpreadsheetEditorScreenState._minCols)
          .clamp(1, _SpreadsheetEditorScreenState._maxCols);

  /// Dosyadaki dondurulmuş satır/sütun sayısı (kullanıcı bölmeleri çözdüyse 0).
  int _frozenColsWanted(XlsxSheet sheet) =>
      _freeze ? math.min(sheet.frozenCols, _colCount(sheet)) : 0;

  int _frozenRowsWanted(XlsxSheet sheet) =>
      _freeze ? math.min(sheet.frozenRows, _rowCount(sheet)) : 0;

  List<int> _frozenRowList(XlsxSheet sheet) => [
        for (var r = 0; r < _frozenRowsFit; r++)
          if (!sheet.isRowHidden(r)) r,
      ];

  List<int> _frozenColList(XlsxSheet sheet) => [
        for (var c = 0; c < _frozenColsFit; c++)
          if (!sheet.isColHidden(c)) c,
      ];

  /// Kaydırılan bölgenin satır/sütun ölçüleri — imza değişmedikçe yeniden
  /// hesaplanmaz (zoom, sayfa, bölme ya da yapı değişince yenilenir).
  void _refreshMetrics(XlsxSheet sheet) {
    final key = '${sheet.name}|$_zoom|$_frozenRowsFit|$_frozenColsFit|'
        '${_rowCount(sheet)}|${_colCount(sheet)}|$_gridVersion';
    if (key == _metricsKey) return;
    _metricsKey = key;
    _autoFitRows(sheet);
    _colMetrics = SheetAxisMetrics.build(
      from: _frozenColsFit,
      to: _colCount(sheet),
      sizeOf: (c) => sheet.colWidth(c) * _zoom,
      hidden: sheet.isColHidden,
    );
    _rowMetrics = SheetAxisMetrics.build(
      from: _frozenRowsFit,
      to: _rowCount(sheet),
      sizeOf: (r) => sheet.rowHeight(r) * _zoom,
      hidden: sheet.isRowHidden,
    );
  }

  void _autoFitRows(XlsxSheet sheet) {
    sheet.autoRowHeights.clear();
    final byRow = <int, List<double>>{};
    var measured = 0;
    for (final entry in sheet.layout.cells.entries) {
      if (measured >= _SpreadsheetEditorScreenState._autoFitCellLimit) break;
      final r = rowOfKey(entry.key);
      final c = colOfKey(entry.key);
      // Dosya bu satırın yüksekliğini SÖYLEDİYSE ona dokunulmaz: kullanıcının
      // (ya da Excel'in) verdiği ölçü bizim tahminimizden önce gelir.
      if (sheet.layout.rowHeights.containsKey(r)) continue;
      if (sheet.isRowHidden(r) || sheet.isColHidden(c)) continue;
      if (sheet.mergeAt(r, c) != null) continue;
      // ÖNCE ucuz eleme: kaydırma bayrağı (önbellekli stil) ve ham metindeki
      // satır sonu. Biçimlendirilmiş metni (`viewAt`) üretmek 200 bin hücrelik
      // bir dosyada her ölçü tazelemesinde sayfayı bekletirdi.
      final style = sheet.styleAt(r, c);
      final raw = sheet.rawAt(r, c);
      if (raw.isEmpty) continue;
      if (!(style?.wrap ?? false) && !raw.contains('\n')) continue;
      final text = _autoFitText(sheet, r, c);
      if (text.isEmpty) continue;
      final width = sheet.colWidth(c) -
          SheetCell.horizontalPadding(style);
      if (width <= 8) continue;
      measured++;
      byRow
          .putIfAbsent(r, () => <double>[])
          .add(_measure.heightOf(
            text,
            SheetCell.metricsStyle(style, numeric: false),
            width,
          ));
    }
    byRow.forEach((r, heights) {
      final pt = autoRowHeightPt(
        contentHeights: heights,
        defaultPt: sheet.layout.defaultRowHeightPt,
      );
      if (pt != null) sheet.autoRowHeights[r] = pt;
    });
  }

  /// Otomatik yükseklikte ölçülecek metin. Formül hücrelerinde motoru
  /// çalıştırmak yerine Excel'in dosyaya yazdığı SONUÇ kullanılır: açılışta
  /// bütün sayfanın formüllerini hesaplatmak (yalnız yükseklik için) pahalı.
  String _autoFitText(XlsxSheet sheet, int r, int c) {
    final raw = sheet.rawAt(r, c);
    if (raw.startsWith('=')) return sheet.cachedResultAt(r, c) ?? '';
    if (raw.isEmpty) return '';
    return sheet.viewAt(r, c, raw).text;
  }

  /// Satırın **taşma planı** — hangi hücre komşusunun üstüne sarkıyor.
  /// Görünen sütunlar için her karede kurulur; ölçüm önbelleklidir.
  SheetSpillPlan _spillPlan(
    _RenderContext ctx,
    int r,
    List<int> cols,
    Map<int, XlsxCellView> views,
  ) {
    final sheet = ctx.sheet;
    final rtl = sheet.rightToLeft;
    final cells = <SheetSpillCell>[];
    for (final c in cols) {
      final view = views[c] ?? const XlsxCellView('');
      final style = sheet.styleAt(r, c);
      final align = style?.alignFor(view.numeric, rightToLeft: rtl) ??
          (rtl ? TextAlign.right : TextAlign.left);
      final merged = sheet.mergeAt(r, c) != null;
      final wrap = style?.wrap ?? false;
      cells.add(SheetSpillCell(
        col: c,
        text: view.text,
        columnWidth: sheet.colWidth(c),
        // Faz 26b: sayı / kaydırılan / birleşik hücre hiç taşmaz
        // (`planRowSpill` onları atlar) — ölçmek kaydırmada kare başına
        // yüzlerce boşa metin düzeni demekti.
        textWidth: view.text.isEmpty || view.numeric || wrap || merged
            ? 0
            : _measure.widthOf(view.text,
                    SheetCell.metricsStyle(style, numeric: view.numeric)) +
                SheetCell.horizontalPadding(style),
        wrap: wrap,
        merged: merged,
        numeric: view.numeric,
        align: switch (align) {
          TextAlign.right => SheetSpillAlign.right,
          TextAlign.center => SheetSpillAlign.center,
          _ => SheetSpillAlign.left,
        },
      ));
    }
    // Sağdan sola sayfada ekranda soldaki sütun, dosyada sağdaki sütundur:
    // taşma yönü ekran sırasına göre çözülür.
    return planRowSpill(rtl ? cells.reversed.toList() : cells);
  }

  String _valueAt(int r, int c) => _sheet?.rawAt(r, c) ?? '';

  void _syncField() => _cellField.text = _displayAt(_selRow, _selCol);

  void _select(int r, int c, {bool extend = false}) {
    // İşaret kipi: formül yazarken hücreye dokunmak başvuru EKLER.
    if (!extend && _pointInsertable()) {
      _insertPointRef(r, c);
      return;
    }
    // Seçili ARALIĞA ikinci dokunuş → bağlam menüsü.
    if (!extend && _hasRange && !_editing && _range.contains(r, c)) {
      _showCellMenu();
      return;
    }
    if (extend) {
      _partSetState(() {
        _selRow = r;
        _selCol = c;
      });
      return;
    }
    if (r == _selRow && c == _selCol && _anchorRow == r && _anchorCol == c) {
      if (_editing) return;
      _syncField();
      _cellField.selection =
          TextSelection.collapsed(offset: _cellField.text.length);
      _beginEdit(r, c);
      return;
    }
    _jumpTo(r, c);
  }

  /// Faz 25: düzenleme HER yakınlaştırmada hücrenin üstündeki yüzer
  /// editörde açılır (eski 30×72 dp eşiği kalktı — 100 %'de hücre ~20×64 dp
  /// olduğundan düzenleme hep formül çubuğuna kaçıyordu).
  void _beginEdit(int r, int c, {bool caret = true}) => _openEditor(caret: caret);

  /// Seçimi taşır — [_select]'in aksine aynı hücreye ikinci kez gelince
  /// düzenlemeye GEÇMEZ (Hücreye git / Bul bunu istemez).
  void _jumpTo(int r, int c) {
    _endEdit();
    _partSetState(() {
      _selRow = r;
      _selCol = c;
      _anchorRow = r;
      _anchorCol = c;
    });
    _syncField();
    _ensureVisible(r, c);
  }

  bool _inSelection(int r, int c) {
    if (_range.contains(r, c)) return true;
    // Doldurma tutamağı sürüklenirken hedef alan da vurgulanır: kullanıcı
    // bırakmadan önce nereye yazılacağını görsün (Excel'in önizleme çerçevesi).
    return _fillPreview?.contains(r, c) ?? false;
  }

  /// Sürükleme sırasında doldurulacak aralık (yoksa null). Tutamaç iki
  /// eksende de dışarı çekilirse alan KÖŞEGEN büyür (Faz 9 / Y2: önce
  /// satırlar, sonra sütunlar doldurulur — bkz. [_applyFill]).
  CellRange? get _fillPreview {
    final toRow = _fillToRow, toCol = _fillToCol;
    if (toRow == null || toCol == null) return null;
    final src = _range;
    final vertical = toRow < src.top || toRow > src.bottom;
    final horizontal = toCol < src.left || toCol > src.right;
    if (!vertical && !horizontal) return null;
    return CellRange(
      vertical ? math.min(src.top, toRow) : src.top,
      horizontal ? math.min(src.left, toCol) : src.left,
      vertical ? math.max(src.bottom, toRow) : src.bottom,
      horizontal ? math.max(src.right, toCol) : src.right,
    );
  }

  bool get _hasRange => _anchorRow != _selRow || _anchorCol != _selCol;

  /// Açık düzenlemeyi **kaydeder**. Formül çubuğuna yazılmış ama onaylanmamış
  /// metin de buradan geçer.
  ///
  /// Kullanıcı 2026-08-17: *"tik işaretine basmadan kaydolmuyor"*. Eskiden ilk
  /// satır `if (!_editing) return;` idi: hücre İÇİNDE düzenleme açık değilken
  /// (yani formül çubuğuna yazılmışken) yazılan metin sessizce atılıyordu —
  /// başka bir hücreye dokunmak `_syncField()` ile üstüne yazıyordu. Artık
  /// bayraktan bağımsız olarak, alandaki metin hücrenin değerinden FARKLIYSA
  /// yazılır; Excel'in davranışı da budur (imleci taşımak girişi onaylar).
  void _endEdit() {
    final changed = _cellField.text != _displayAt(_selRow, _selCol);
    _pointSpan = null;
    final wasEditing = _editing;
    _editing = false;
    if (changed) {
      _applyCell(_cellField.text);
    } else if (wasEditing) {
      _partSetState(() {});
    }
  }

  /// Enter: girişi yazar, ALT hücreye geçer ve **yazmaya devam eder**.
  ///
  /// Eskiden `_select` çağrılıyordu: seçim iniyordu ama düzenleme kapanıyor,
  /// klavye her satırda kapanıp açılıyordu. Bir sütuna arka arkaya veri girmek
  /// (kullanıcı 2026-08-17: *"karelere veri girişi çok zor"*) bu yüzden her
  /// satırda iki fazladan dokunuş istiyordu. Excel'de Enter zinciri kesmez.
  void _commitAndMoveDown(int rowCount) {
    final wasEditing = _editing;
    _endEdit();
    _growTo(_selRow + 1, _selCol);
    _jumpTo(_selRow + 1, _selCol);
    if (wasEditing || _barFocus.hasFocus) _beginEdit(_selRow, _selCol, caret: false);
  }

  /// Girilen metni yazar: formül Türkçe gösterimden dosya biçimine, sayı /
  /// para / yüzde / tarih akıllı girişle (Faz 25 / madde 7, 11).
  void _applyCell(String value) {
    final sheet = _sheet;
    final m = _toModel(value);
    final at = CellRef(_selRow, _selCol);
    final code = sheet?.numFmtCode(_selRow, _selCol).trim() ?? 'General';
    final fmt = m.numberFormat != null && (code.isEmpty || code == 'General')
        ? {at: m.numberFormat!}
        : null;
    _editCells('excel.undo_typing', {at: m.raw}, numberFormats: fmt);
    if (m.noteKey != null) _snack(context.t(m.noteKey!));
  }

  /// Seçili aralık (tek hücrede de geçerli).
  CellRange get _range =>
      CellRange.between(_anchorRow, _anchorCol, _selRow, _selCol);

  /// Bir grup hücre yazımını uygular ve **tek** geri alma adımı olarak kaydeder.
  ///
  /// Yapıştırma, doldurma, temizleme, Σ ve düz yazma hepsi buradan geçer:
  /// böylece "geri al" her zaman kullanıcının yaptığı TEK işlemi geri alır,
  /// hücre hücre değil.
  ///
  /// [formatSources] verilirse hedef hücrelerin **görünümü** de kaynağınkine
  /// çekilir (yapıştırma). Değer ve biçim TEK adımda kaydedilir — ayrı iki
  /// adım olsaydı kullanıcı "geri al"a iki kez basmak zorunda kalırdı.
  void _editCells(String label, Map<CellRef, String> values,
      {Map<CellRef, CellRef>? formatSources,
      Map<CellRef, String>? numberFormats}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null || values.isEmpty) return;
    final name = sheet.name;
    final valueStep = SheetValueStep(
      label: label,
      before: {for (final k in values.keys) k: sheet.rawAt(k.row, k.col)},
      after: values,
      write: (at, v) => editor.setCell(name, at.row, at.col, v),
    );
    final formats = formatSources ?? const <CellRef, CellRef>{};
    final numFmts = numberFormats ?? const <CellRef, String>{};
    if (valueStep.isNoop && formats.isEmpty) return;

    final stylesBefore = <CellRef, XlsxCellStyle?>{
      for (final at in {...formats.keys, ...numFmts.keys})
        at: sheet.overrideAt(at.row, at.col),
    };
    final numFmtBefore = <CellRef, String?>{
      for (final at in numFmts.keys)
        at: sheet.numberFormatEdits[(at.row, at.col)],
    };
    final step = _CallbackStep(
      label,
      () {
        valueStep.apply();
        formats.forEach((at, src) =>
            editor.copyCellFormat(name, src.row, src.col, at.row, at.col));
        numFmts.forEach((at, code) => sheet.setNumberFormat(at.row, at.col, code));
      },
      () {
        valueStep.revert();
        stylesBefore.forEach((at, s) => sheet.patchStyle(at.row, at.col, s));
        numFmtBefore.forEach((at, code) {
          if (code == null) {
            sheet.numberFormatEdits.remove((at.row, at.col));
          } else {
            sheet.numberFormatEdits[(at.row, at.col)] = code;
          }
        });
        // Kaydetmeye giden iz de silinir; yoksa geri alınmış bir yapıştırmanın
        // biçimi dosyaya yine yazılırdı.
        for (final at in formats.keys) {
          sheet.styleCopies.remove((at.row, at.col));
        }
      },
    );
    _undo.push(step);
    _session.changed();
    _gridVersion++; // yazma kullanılan alanı büyütebilir → ölçüler yenilenir
    // Yapıştırma/doldurma/Σ imlecin ALTINDAKİ değeri de değiştirmiş olabilir;
    // formül çubuğu tazelenmezse eski değeri gösterip bir sonraki düzenlemede
    // onu geri yazardı.
    _syncField();
    _partSetState(() {});
  }

  /// Geri alma yığınına, uygulanmış bir işlemin tersini kaydeder.
  void _recordStep(String label, VoidCallback apply, VoidCallback revert) =>
      _undo.record(_CallbackStep(label, apply, revert));

  void _undoStep() {
    final step = _undo.undo();
    if (step == null) return;
    _afterHistory(step.label, undone: true);
  }

  void _redoStep() {
    final step = _undo.redo();
    if (step == null) return;
    _afterHistory(step.label, undone: false);
  }

  void _afterHistory(String label, {required bool undone}) {
    _editing = false;
    _session.changed();
    _gridVersion++;
    final sheet = _sheet;
    if (sheet != null) {
      // Yapısal geri alma satır/sütun sayısını değiştirmiş olabilir; imleç
      // sayfanın dışında kalmasın.
      _selRow = _selRow.clamp(0, math.max(0, _rowCount(sheet) - 1));
      _selCol = _selCol.clamp(0, math.max(0, _colCount(sheet) - 1));
      _anchorRow = _anchorRow.clamp(0, math.max(0, _rowCount(sheet) - 1));
      _anchorCol = _anchorCol.clamp(0, math.max(0, _colCount(sheet) - 1));
    }
    _syncField();
    _partSetState(() {});
    _snack(context.t(undone ? 'excel.undone' : 'excel.redone',
        {'what': context.t(label)}));
  }

  void _afterStructural() {
    _editing = false;
    final sheet = _sheet;
    if (sheet != null) {
      final maxRow = math.max(0, _rowCount(sheet) - 1);
      final maxCol = math.max(0, sheet.maxCols - 1);
      _selRow = _selRow.clamp(0, maxRow);
      _selCol = _selCol.clamp(0, maxCol);
      _anchorRow = _selRow;
      _anchorCol = _selCol;
    }
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
    _syncField();
  }

  void _insertRow({required bool below}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = below ? _selRow + 1 : _selRow;
    final struct = editor.captureStructure(name);
    editor.insertRow(name, at);
    // Eklemenin tersi silme + yapı anlık görüntüsü (kaydırılan formüller,
    // birleştirmeler, koşullu biçim … tam olarak geri gelsin).
    _recordStep('excel.undo_insert_row', () => editor.insertRow(name, at), () {
      editor.deleteRow(name, at);
      editor.restoreStructure(struct);
    });
    if (below) _selRow += 1;
    _afterStructural();
  }

  void _deleteRow() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = _selRow;
    // Silmenin tersi "ekle" DEĞİL, "ekle + içeriği geri koy": satırın
    // değerleri, biçimleri ve yüksekliği yakalanmadan geri alma veri kaybeder.
    final snap = editor.captureRow(name, at);
    final struct = editor.captureStructure(name);
    editor.deleteRow(name, at);
    _recordStep('excel.undo_delete_row', () => editor.deleteRow(name, at), () {
      editor.insertRow(name, at);
      editor.restoreRow(name, at, snap);
      editor.restoreStructure(struct);
    });
    _afterStructural();
  }

  void _insertColumn({required bool right}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = right ? _selCol + 1 : _selCol;
    final struct = editor.captureStructure(name);
    editor.insertColumn(name, at);
    _recordStep('excel.undo_insert_col', () => editor.insertColumn(name, at),
        () {
      editor.deleteColumn(name, at);
      editor.restoreStructure(struct);
    });
    if (right) _selCol += 1;
    _afterStructural();
  }

  void _deleteColumn() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final at = _selCol;
    final snap = editor.captureColumn(name, at);
    final struct = editor.captureStructure(name);
    editor.deleteColumn(name, at);
    _recordStep('excel.undo_delete_col', () => editor.deleteColumn(name, at),
        () {
      editor.insertColumn(name, at);
      editor.restoreColumn(name, at, snap);
      editor.restoreStructure(struct);
    });
    _afterStructural();
  }

  /// Seçili aralığı panoya alır. [cut] ise yapıştırdıktan sonra kaynak
  /// temizlenir — Excel'de kesme budur (kaynak hemen değil, YAPIŞTIRINCA
  /// boşalır; kullanıcı vazgeçerse veri yerinde kalır).
  Future<void> _copySelection({bool cut = false}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    final clip = SheetClip(
      values: [
        for (var row = r.top; row <= r.bottom; row++)
          [for (var col = r.left; col <= r.right; col++) sheet.rawAt(row, col)],
      ],
      origin: CellRef(r.top, r.left),
      cut: cut,
    );
    _partSetState(() => _clip = clip);
    // Sistem panosuna TSV: kullanıcı başka bir uygulamaya (gerçek Excel dahil)
    // yapıştırabilsin.
    await Clipboard.setData(ClipboardData(text: clip.toTsv()));
    if (!mounted) return;
    _snack(context.t(cut ? 'excel.cut_done' : 'excel.copy_done',
        {'n': r.cellCount}));
  }

  /// Panoyu seçime yapıştırır.
  ///
  /// Uygulama içi pano varsa o kullanılır (formül kaydırması ve kesme bilgisi
  /// oradadır); yoksa **sistem panosundaki metin** TSV olarak çözümlenir —
  /// böylece başka uygulamadan kopyalanan tablo da yapışır.
  Future<void> _paste() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    var clip = _clip;
    if (clip == null) {
      final data = await Clipboard.getData('text/plain');
      clip = SheetClip.fromTsv(data?.text ?? '',
          origin: CellRef(_selRow, _selCol));
    }
    if (clip == null || clip.isEmpty) {
      if (mounted) _snack(context.t('excel.clipboard_empty'));
      return;
    }
    final values = pasteCells(clip, _range);
    // Excel yapıştırırken hücrenin BİÇİMİNİ de taşır. Yalnız uygulama içi
    // panoda yapılabilir: sistem panosundan gelen düz metnin biçimi yok.
    final formats = _clip == null ? null : pasteSources(clip, _range);
    if (clip.cut) {
      // Kesmede kaynak da aynı adımda temizlenir; iki ayrı adım olsaydı
      // "geri al" yarım bir durum bırakırdı.
      for (var r = 0; r < clip.rows; r++) {
        for (var c = 0; c < clip.cols; c++) {
          final at = CellRef(clip.origin.row + r, clip.origin.col + c);
          values.putIfAbsent(at, () => '');
        }
      }
    }
    _editCells('excel.undo_paste', values, formatSources: formats);
    if (clip.cut) _partSetState(() => _clip = null);
  }

  /// Seçili aralığın içeriğini siler (Excel'de Delete tuşu).
  void _clearSelection() {
    _endEdit();
    final r = _range;
    _editCells('excel.undo_clear', {
      for (var row = r.top; row <= r.bottom; row++)
        for (var col = r.left; col <= r.right; col++) CellRef(row, col): '',
    });
  }

  /// Σ — imlecin üstündeki (yoksa solundaki) bitişik sayı bloğunu toplar.
  void _autoSum() {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final range = autoSumRange(
        _selRow, _selCol, (r, c) => sheet.isNumericAt(r, c));
    final formula = range == null
        ? '=TOPLA()'
        : '=TOPLA(${CellRef(range.top, range.left)}:'
            '${CellRef(range.bottom, range.right)})';
    _editCells('excel.undo_autosum', {CellRef(_selRow, _selCol): formula});
    if (range == null && mounted) _snack(context.t('excel.autosum_empty'));
  }

  /// Doldurma tutamağı bırakıldığında seriyi yazar.
  ///
  /// Tek eksende sürüklemede o eksen doldurulur. **İki eksende birden**
  /// (köşegen — Faz 9 / Y2) önce satırlar aşağı/yukarı uzatılır, sonra
  /// UZAMIŞ blok sağa/sola uzatılır; böylece köşedeki hücreler de iki serinin
  /// devamıyla dolar. Hesap saf işlevde ([fillDiagonal]) ve testli.
  void _applyFill(int toRow, int toCol) {
    final sheet = _sheet;
    if (sheet == null) return;
    final src = _range;
    final vertical = toRow < src.top || toRow > src.bottom;
    final horizontal = toCol < src.left || toCol > src.right;
    if (!vertical && !horizontal) return;

    final values = fillDiagonal(src, toRow, toCol, sheet.rawAt);
    _editCells('excel.undo_fill', values);
    // Doldurulan alan Excel'de seçili kalır.
    _partSetState(() {
      if (vertical) {
        _anchorRow = math.min(src.top, toRow);
        _selRow = math.max(src.bottom, toRow);
      }
      if (horizontal) {
        _anchorCol = math.min(src.left, toCol);
        _selCol = math.max(src.right, toCol);
      }
    });
  }
}

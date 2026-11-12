part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenEntryMenusPart on _SpreadsheetEditorScreenState {
  // ── seçim tutamakları (madde 8) ─────────────────────────────────────────

  List<Widget> _selectionHandles() {
    if (_editing) return const [];
    return [
      AnimatedBuilder(
        animation: Listenable.merge([_hBody, _vBody]),
        builder: (context, _) {
          final tl = _rectOf(_tlKey);
          final br = _rectOf(_brKey);
          return Stack(
            children: [
              if (tl != null) _handle(tl.topLeft, start: true),
              if (br != null) _handle(br.bottomRight, start: false),
            ],
          );
        },
      ),
    ];
  }

  Widget _handle(Offset at, {required bool start}) {
    const touch = 34.0, dot = 14.0;
    // Doldurma karesi sağ-alt köşenin İÇİNDE; seçim tutamağı köşenin dışına
    // taşar — iki hedef çakışmaz.
    final c = start ? at : at + const Offset(8, 8);
    final scheme = Theme.of(context).colorScheme;
    return Positioned(
      left: c.dx - touch / 2,
      top: c.dy - touch / 2,
      child: RawGestureDetector(
        key: ValueKey(start ? 'sel-handle-start' : 'sel-handle-end'),
        behavior: HitTestBehavior.opaque,
        gestures: {
          ImmediateMultiDragGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<
                  ImmediateMultiDragGestureRecognizer>(
            ImmediateMultiDragGestureRecognizer.new,
            (r) => r.onStart = (_) => _HandleDrag(
                  onMove: (g) => _onHandleMove(g, start: start),
                  onFling: (v) => _onHandleFling(v, start: start),
                ),
          ),
        },
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: OfficeColors.excel, width: 2.5),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _onHandleMove(Offset global, {required bool start}) {
    final ctx = _gridAreaKey.currentContext;
    if (ctx == null) return;
    final pos = _cellAtGlobal(ctx, global);
    if (pos == null) return;
    final range = _range;
    _partSetState(() {
      if (start) {
        // Sol-üst tutamak: karşı köşe (sağ-alt) sabit.
        _anchorRow = range.bottom;
        _anchorCol = range.right;
      } else {
        _anchorRow = range.top;
        _anchorCol = range.left;
      }
      _selRow = pos.$1;
      _selCol = pos.$2;
    });
    _syncField();
  }

  /// Fırlatma: tutamağın yönünde verinin kenarına kadar (Ctrl+ok).
  void _onHandleFling(Velocity v, {required bool start}) {
    final sheet = _sheet;
    if (sheet == null) return;
    final dx = v.pixelsPerSecond.dx, dy = v.pixelsPerSecond.dy;
    if (math.max(dx.abs(), dy.abs()) < 900) return;
    final vertical = dy.abs() >= dx.abs();
    final sign = (vertical ? dy : dx) > 0 ? 1 : -1;
    final edge = _dataEdge(_selRow, _selCol, vertical ? sign : 0,
        vertical ? 0 : sign);
    _partSetState(() {
      _selRow = edge.$1;
      _selCol = edge.$2;
    });
    _syncField();
    _ensureVisible(edge.$1, edge.$2);
  }

  /// Ctrl+ok: dolu bir bloğun kenarına (ya da bir sonraki dolu hücreye).
  (int, int) _dataEdge(int r, int c, int dr, int dc) {
    final sheet = _sheet!;
    final maxR = math.max(0, sheet.maxRows - 1);
    final maxC = math.max(0, sheet.maxCols - 1);
    bool filled(int rr, int cc) => sheet.rawAt(rr, cc).isNotEmpty;
    var rr = r, cc = c;
    bool inside(int a, int b) => a >= 0 && b >= 0 && a <= maxR && b <= maxC;
    final startFilled = filled(rr, cc) && inside(rr + dr, cc + dc) &&
        filled(rr + dr, cc + dc);
    while (inside(rr + dr, cc + dc)) {
      final nf = filled(rr + dr, cc + dc);
      if (startFilled ? !nf : nf) {
        if (!startFilled) {
          rr += dr;
          cc += dc;
        }
        return (rr, cc);
      }
      rr += dr;
      cc += dc;
    }
    return (rr, cc);
  }

  // ── bağlam menüsü (madde 9) ─────────────────────────────────────────────

  Future<void> _showCellMenu() async {
    _endEdit();
    final picked = await showAppSheet<String>(
      context,
      title: _selectionLabel,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (id, icon, key) in [
            ('cut', AppIcons.cut, 'excel.cut'),
            ('copy', AppIcons.copy, 'common.copy'),
            ('paste', AppIcons.paste, 'common.paste'),
            ('paste_values', AppIcons.paste, 'excel.paste_values'),
            ('paste_formats', AppIcons.formatPaint, 'excel.paste_formats'),
            ('paste_transpose', AppIcons.swapHoriz, 'excel.paste_transpose'),
            ('clear', AppIcons.backspace, 'excel.clear_contents'),
            ('clear_formats', AppIcons.formatClear, 'excel.clear_formats'),
            ('fill_down', AppIcons.arrowDown, 'excel.fill_down'),
            ('fill_right', AppIcons.arrowForward, 'excel.fill_right'),
            ('insert_row', OfficeIcons.insertRow, 'excel.insert_row'),
            ('delete_row', OfficeIcons.deleteCells, 'excel.delete_row'),
            ('insert_col', OfficeIcons.insertColumn, 'excel.insert_col'),
            ('delete_col', OfficeIcons.deleteCells, 'excel.delete_col'),
            ('sort_asc', OfficeIcons.sortAsc, 'excel.sort_asc'),
            ('sort_desc', OfficeIcons.sortDesc, 'excel.sort_desc'),
            ('format_cells', AppIcons.cellStyles, 'excel.format_cells'),
            ('note', AppIcons.comment, 'excel.note_new'),
          ])
            ListTile(
              key: ValueKey('cellmenu-$id'),
              dense: true,
              leading: Icon(icon),
              title: Text(ctx.t(key)),
              onTap: () => Navigator.pop(ctx, id),
            ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    switch (picked) {
      case 'cut':
        await _copySelection(cut: true);
      case 'copy':
        await _copySelection();
      case 'paste':
        await _paste();
      case 'paste_values':
        _pasteSpecial(values: true);
      case 'paste_formats':
        _pasteSpecial(formats: true);
      case 'paste_transpose':
        _pasteSpecial(transpose: true);
      case 'clear':
        _clearSelection();
      case 'clear_formats':
        _clearFormats();
      case 'fill_down':
        _fillWithin(down: true);
      case 'fill_right':
        _fillWithin(down: false);
      case 'insert_row':
        _insertRow(below: false);
      case 'delete_row':
        _deleteRow();
      case 'insert_col':
        _insertColumn(right: false);
      case 'delete_col':
        _deleteColumn();
      case 'format_cells':
        await _showFormatCells();
      case 'note':
        await _editNote();
      case 'sort_asc':
      case 'sort_desc':
        final sheet = _sheet;
        if (sheet == null) break;
        final range = _range;
        _sortByColumn(sheet, _selCol, range.top, math.max(range.bottom,
            sheet.maxRows - 1), picked == 'sort_asc');
    }
  }

  /// Özel yapıştır: yalnız değerler (formüller sonuca indirgenir), yalnız
  /// biçim ya da devrik.
  void _pasteSpecial({bool values = false, bool formats = false, bool transpose = false}) {
    final clip = _clip;
    final sheet = _sheet;
    if (clip == null || sheet == null) {
      _snack(context.t('excel.nothing_to_paste'));
      return;
    }
    final engine = _engineFor(sheet);
    final out = <CellRef, String>{};
    final fmt = <CellRef, CellRef>{};
    for (var i = 0; i < clip.rows; i++) {
      for (var j = 0; j < clip.cols; j++) {
        final dst = transpose
            ? CellRef(_selRow + j, _selCol + i)
            : CellRef(_selRow + i, _selCol + j);
        final src = CellRef(clip.origin.row + i, clip.origin.col + j);
        if (!formats) {
          final raw = clip.values[i][j];
          out[dst] = values && raw.startsWith('=')
              ? engine.displayValue(src.row, src.col)
              : (transpose ? raw : raw);
        }
        if (formats || transpose) fmt[dst] = src;
      }
    }
    if (formats) {
      // Yalnız biçim: değerler yerinde kalır.
      for (final d in fmt.keys) {
        out[d] = sheet.rawAt(d.row, d.col);
      }
    }
    _editCells('excel.undo_paste', out, formatSources: fmt.isEmpty ? null : fmt);
  }

  void _clearFormats() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final range = _range;
    final before = <CellRef, XlsxCellStyle?>{};
    for (var r = range.top; r <= range.bottom; r++) {
      for (var c = range.left; c <= range.right; c++) {
        before[CellRef(r, c)] = sheet.overrideAt(r, c);
      }
    }
    void apply() {
      for (final at in before.keys) {
        sheet.patchStyle(at.row, at.col, const XlsxCellStyle());
        sheet.recordStyleEdit(at.row, at.col, _plainStyle);
      }
    }

    apply();
    _recordStep('excel.clear_formats', apply, () {
      before.forEach((at, s) {
        sheet.patchStyle(at.row, at.col, s);
        sheet.styleEdits.remove((at.row, at.col));
      });
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// Doldur ▾ aşağı/sağa: seçimin ilk satırı/sütunu kalanına kopyalanır.
  void _fillWithin({required bool down}) {
    final range = _range;
    if (down ? range.bottom == range.top : range.right == range.left) return;
    final sheet = _sheet;
    if (sheet == null) return;
    final out = <CellRef, String>{};
    for (var r = range.top; r <= range.bottom; r++) {
      for (var c = range.left; c <= range.right; c++) {
        final sr = down ? range.top : r, sc = down ? c : range.left;
        if (sr == r && sc == c) continue;
        final raw = sheet.rawAt(sr, sc);
        out[CellRef(r, c)] = raw.startsWith('=')
            ? '=${shiftFormula(raw.substring(1), r - sr, c - sc)}'
            : raw;
      }
    }
    _editCells('excel.undo_fill', out);
  }

  /// "Biçimi temizle": düz yazı, dolgu/kenarlık yok.
  static const _plainStyle = XlsxStyleEdit(
    bold: false,
    italic: false,
    underline: false,
    fillArgb: XlsxStyleEdit.noFill,
    fontArgb: 0xFF000000,
    wrap: false,
    borders: {'left': null, 'right': null, 'top': null, 'bottom': null},
  );

  // ── metin otomatik tamamlama (madde 10) ─────────────────────────────────

  /// Sütunda daha önce yazılmış ve yazılanla başlayan değer (yoksa null).
  String? _textCompletion() {
    final t = _cellField.text;
    final sheet = _sheet;
    if (!_editing || sheet == null || t.length < 2 || t.startsWith('=')) {
      return null;
    }
    if (double.tryParse(t.replaceAll(',', '.')) != null) return null;
    final low = t.toLowerCase();
    String? hit;
    final n = math.min(sheet.maxRows, 2000);
    for (var r = 0; r < n; r++) {
      if (r == _selRow) continue;
      final v = sheet.rawAt(r, _selCol);
      if (v.length > t.length && !v.startsWith('=') &&
          v.toLowerCase().startsWith(low)) {
        if (hit != null && hit != v) return null; // belirsiz → önerme
        hit = v;
      }
    }
    return hit;
  }

  // ── işlev kitaplığı (madde 6) ───────────────────────────────────────────

  Future<void> _showFunctionLibrary() async {
    final tr = _turkishFormulas;
    final lib = formulaLibrary();
    final picked = await showAppSheet<String>(
      context,
      title: context.t('excel.fx_library'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final cat in FormulaCategory.values)
            if (lib[cat] != null)
              ExpansionTile(
                key: ValueKey('fx-${cat.name}'),
                title: Text(ctx.t('excel.fxcat_${cat.name}')),
                children: [
                  for (final s in lib[cat]!)
                    () {
                      final shown = tr
                          ? FormulaEngine.toTurkishFormula('${s.name}()')
                              .replaceAll('()', '')
                          : s.name;
                      final args = (tr ? s.argsTr : s.argsEn)
                          .join(tr ? '; ' : ', ');
                      return ListTile(
                        dense: true,
                        title: Text(shown),
                        subtitle: Text('$shown($args)',
                            maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => Navigator.pop(ctx, shown),
                      );
                    }(),
                ],
              ),
        ],
      ),
    );
    if (picked == null || !mounted) return;
    if (!_editing) _openEditor(caret: true);
    final t = _cellField.text;
    if (t.isEmpty || !t.startsWith('=')) {
      _cellField.value = TextEditingValue(
          text: '=$picked(',
          selection: TextSelection.collapsed(offset: picked.length + 2));
    } else {
      _replaceSelection('$picked(');
    }
    _partSetState(() {});
    _cellFocus.requestFocus();
  }

  /// Bağımsız değişken ipucu: `DÜŞEYARA(aranan_değer; **tablo_dizisi**; …)`.
  Widget? _argumentHint() {
    final t = _cellField.text;
    if (!t.startsWith('=')) return null;
    final sel = _cellField.selection;
    final call = activeCall(t, sel.isValid ? sel.extentOffset : t.length);
    if (call == null) return null;
    final sig = signatureOf(call.$1);
    if (sig == null) return null;
    final tr = _turkishFormulas;
    final args = tr ? sig.argsTr : sig.argsEn;
    if (args.isEmpty) return null;
    var active = call.$2;
    if (active >= args.length) {
      // `…` tekrarlanır: son adlandırılmış bağımsız değişken etkin sayılır.
      active = args.last == '…' ? args.length - 2 : args.length - 1;
    }
    final scheme = Theme.of(context).colorScheme;
    final sep = tr ? '; ' : ', ';
    return Container(
      key: const ValueKey('arg-hint'),
      width: double.infinity,
      color: scheme.surfaceContainerHigh,
      padding: const EdgeInsetsDirectional.fromSTEB(70, 0, 12, 4),
      child: Text.rich(
        TextSpan(
          style: context.type.small.copyWith(color: scheme.onSurfaceVariant),
          children: [
            TextSpan(text: '${call.$1.toUpperCase()}('),
            for (var k = 0; k < args.length; k++) ...[
              if (k > 0) TextSpan(text: sep),
              TextSpan(
                text: args[k],
                style: k == active
                    ? TextStyle(
                        fontWeight: FontWeight.w800, color: scheme.onSurface)
                    : null,
              ),
            ],
            const TextSpan(text: ')'),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }

  // ── veri doğrulama listesi (madde 13) ───────────────────────────────────

  Future<void> _pickFromValidation() async {
    final options = _validationOptions();
    if (options.isEmpty) return;
    final v = await showAppSheet<String>(
      context,
      title: context.t('excel.pick_from_list'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final o in options)
            ListTile(title: Text(o), onTap: () => Navigator.pop(ctx, o)),
        ],
      ),
    );
    if (v == null || !mounted) return;
    _cellField.text = v;
    _applyCell(v);
  }
}

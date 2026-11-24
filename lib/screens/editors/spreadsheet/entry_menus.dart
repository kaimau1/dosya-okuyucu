part of '../spreadsheet_editor_screen.dart';

extension _SpreadsheetEditorScreenEntryMenusPart on _SpreadsheetEditorScreenState {
  // ── seçim tutamakları (madde 8) ─────────────────────────────────────────

  List<Widget> _selectionHandles() {
    if (_editing) return const [];
    final surface = Theme.of(context).colorScheme.surface;
    final startDot = _handleBody(surface, start: true);
    final endDot = _handleBody(surface, start: false);
    const touch = 34.0;
    return [
      // Kendi katmanı: kaydırma boyunca tutamak konumu değişirken alttaki
      // ızgaranın tamamını kirletmez.
      Positioned.fill(
        child: RepaintBoundary(
          child: AnimatedBuilder(
            animation: _gridScroll,
            builder: (context, _) {
              final tl = _rectOf(_tlKey);
              final br = _rectOf(_brKey);
              if (tl == null && br == null) return const SizedBox.shrink();
              return Stack(
                children: [
                  if (tl != null)
                    Positioned(
                      left: tl.left - touch / 2,
                      top: tl.top - touch / 2,
                      child: startDot,
                    ),
                  if (br != null)
                    Positioned(
                      left: br.right + 8 - touch / 2,
                      top: br.bottom + 8 - touch / 2,
                      child: endDot,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    ];
  }

  Widget _handleBody(Color surface, {required bool start}) {
    const touch = 34.0, dot = 14.0;
    // Doldurma karesi sağ-alt köşenin İÇİNDE; seçim tutamağı köşenin dışına
    // taşar — iki hedef çakışmaz.
    return RawGestureDetector(
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
              color: surface,
              shape: BoxShape.circle,
              border: Border.all(color: OfficeColors.excel, width: 2.5),
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
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        Widget quickTile(String id, IconData icon, String key,
                {bool danger = false}) =>
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Material(
                  color: danger
                      ? scheme.errorContainer.withValues(alpha: 0.4)
                      : scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(Radii.card),
                  child: InkWell(
                    key: ValueKey('cellmenu-$id'),
                    borderRadius: BorderRadius.circular(Radii.card),
                    onTap: () => Navigator.pop(ctx, id),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: Gap.xs, vertical: Gap.sm + 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(Radii.card),
                        border: Border.all(
                          color: danger
                              ? scheme.error.withValues(alpha: 0.25)
                              : scheme.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: danger
                                  ? scheme.error.withValues(alpha: 0.14)
                                  : scheme.primaryContainer
                                      .withValues(alpha: 0.7),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              icon,
                              size: 18,
                              color: danger
                                  ? scheme.error
                                  : scheme.onPrimaryContainer,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            ctx.t(key),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: ctx.type.caption.copyWith(
                              color: danger
                                  ? scheme.error
                                  : scheme.onSurface,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
        Widget groupHeader(String key) => Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  Gap.lg, Gap.md, Gap.lg, Gap.xs),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  ctx.t(key),
                  style: ctx.type.caption.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            );
        Widget row(String id, IconData icon, String key) => ListTile(
              key: ValueKey('cellmenu-$id'),
              dense: true,
              leading: Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(Radii.control),
                ),
                child: Icon(icon, size: 17, color: scheme.primary),
              ),
              title: Text(
                ctx.t(key),
                style: ctx.type.body.copyWith(fontWeight: FontWeight.w500),
              ),
              onTap: () => Navigator.pop(ctx, id),
            );
        Widget groupCard(List<Widget> children) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Material(
                color: scheme.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(Radii.card),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < children.length; i++) ...[
                      children[i],
                      if (i < children.length - 1)
                        Divider(
                          height: 1,
                          indent: 56,
                          color: scheme.outlineVariant.withValues(alpha: 0.4),
                        ),
                    ],
                  ],
                ),
              ),
            );
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            groupHeader('excel.quick_actions'),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: Gap.md, vertical: Gap.xs),
              child: Row(
                children: [
                  quickTile('cut', AppIcons.cut, 'excel.cut'),
                  quickTile('copy', AppIcons.copy, 'common.copy'),
                  quickTile('paste', AppIcons.paste, 'common.paste'),
                  quickTile('clear', AppIcons.backspace, 'excel.clear_contents',
                      danger: true),
                ],
              ),
            ),
            const SizedBox(height: Gap.xs),
            groupCard([
              row('format_cells', AppIcons.cellStyles, 'excel.format_cells'),
              row('note', AppIcons.comment, 'excel.note_new'),
            ]),
            groupHeader('excel.paste_special_group'),
            groupCard([
              for (final (id, icon, key) in const [
                ('paste_values', AppIcons.paste, 'excel.paste_values'),
                ('paste_formulas', AppIcons.paste, 'excel.paste_formulas'),
                ('paste_formats', AppIcons.formatPaint, 'excel.paste_formats'),
                ('paste_transpose', AppIcons.swapHoriz, 'excel.paste_transpose'),
                ('clear_formats', AppIcons.formatClear, 'excel.clear_formats'),
              ])
                row(id, icon, key),
            ]),
            groupHeader('excel.fill_sort_group'),
            groupCard([
              for (final (id, icon, key) in const [
                ('fill_down', AppIcons.arrowDown, 'excel.fill_down'),
                ('fill_right', AppIcons.arrowForward, 'excel.fill_right'),
                ('sort_asc', OfficeIcons.sortAsc, 'excel.sort_asc'),
                ('sort_desc', OfficeIcons.sortDesc, 'excel.sort_desc'),
              ])
                row(id, icon, key),
            ]),
            groupHeader('excel.rows_cols_group'),
            groupCard([
              for (final (id, icon, key) in const [
                ('insert_row', OfficeIcons.insertRow, 'excel.insert_row'),
                ('delete_row', OfficeIcons.deleteCells, 'excel.delete_row'),
                ('insert_col', OfficeIcons.insertColumn, 'excel.insert_col'),
                ('delete_col', OfficeIcons.deleteCells, 'excel.delete_col'),
              ])
                row(id, icon, key),
            ]),
            const SizedBox(height: Gap.md),
          ],
        );
      },
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
      case 'paste_formulas':
        _pasteFormulas();
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
        var r1 = range.top;
        final r2 = _hasRange
            ? range.bottom
            : math.max(range.bottom, sheet.maxRows - 1);
        if (!_hasRange && r1 == 0 && r2 > 0) {
          final f = _filterRange(sheet);
          final filterHeader = f != null && f.r1 == 0;
          final row0Text = sheet.rawAt(0, _selCol).trim().isNotEmpty &&
              !sheet.isNumericAt(0, _selCol);
          final row1Diff = sheet.isNumericAt(1, _selCol) ||
              (sheet.styleAt(0, _selCol)?.bold ?? false) !=
                  (sheet.styleAt(1, _selCol)?.bold ?? false) ||
              Iterable<int>.generate(sheet.maxCols).any(
                  (c) => !sheet.isNumericAt(0, c) && sheet.isNumericAt(1, c));
          if (filterHeader || (row0Text && row1Diff)) {
            r1 = 1;
          }
        }
        _sortByColumn(sheet, _selCol, r1, r2, picked == 'sort_asc');
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
    final editor = _editor;
    final srcSheetName = _clipSheetName ?? sheet.name;
    final srcSheet = editor?.sheets
            .where((s) => s.name == srcSheetName)
            .firstOrNull ??
        sheet;
    final srcEngine = _engineFor(srcSheet);
    final disp = _clipDisplayValues;
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
          final cachedDisp =
              disp != null && i < disp.length && j < disp[i].length
                  ? disp[i][j]
                  : null;
          out[dst] = values
              ? (raw.startsWith('=')
                  ? (cachedDisp ?? srcEngine.displayValue(src.row, src.col))
                  : (cachedDisp ?? raw))
              : raw;
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
    if (transpose && clip.cut) {
      if (srcSheetName == sheet.name) {
        for (var r = 0; r < clip.rows; r++) {
          for (var c = 0; c < clip.cols; c++) {
            final at = CellRef(clip.origin.row + r, clip.origin.col + c);
            out.putIfAbsent(at, () => '');
          }
        }
      } else if (editor != null) {
        for (var r = 0; r < clip.rows; r++) {
          for (var c = 0; c < clip.cols; c++) {
            editor.setCell(
                srcSheetName, clip.origin.row + r, clip.origin.col + c, '');
          }
        }
      }
    }
    _editCells('excel.undo_paste', out,
        formatSources: fmt.isEmpty ? null : fmt,
        formatSourceSheet: srcSheetName);
    if (transpose && clip.cut) {
      _partSetState(() {
        _clip = null;
        _clipSheetName = null;
        _clipDisplayValues = null;
      });
    }
  }

  /// Yalnız formüller (B10 m.7): değer/formül başvuruları normal yapıştırma
  /// gibi kayar, hedefin biçimi korunur.
  void _pasteFormulas() {
    final clip = _clip;
    if (clip == null || _sheet == null) {
      _snack(context.t('excel.nothing_to_paste'));
      return;
    }
    _editCells('excel.undo_paste', pasteCells(clip, _range));
  }

  void _clearFormats() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final range = _range;
    final before = <CellRef, XlsxCellStyle?>{};
    final editsBefore = <(int, int), XlsxStyleEdit?>{};
    for (var r = range.top; r <= range.bottom; r++) {
      for (var c = range.left; c <= range.right; c++) {
        before[CellRef(r, c)] = sheet.overrideAt(r, c);
        editsBefore[(r, c)] = sheet.styleEdits[(r, c)];
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
        final k = (at.row, at.col);
        sheet.patchStyle(at.row, at.col, s);
        final prevEdit = editsBefore[k];
        if (prevEdit == null) {
          sheet.styleEdits.remove(k);
        } else {
          sheet.styleEdits[k] = prevEdit;
        }
      });
    });
    _session.changed();
    _gridVersion++;
    _autoFitVersion++;
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
  /// Sütun adayları (sayfa, sütun, satır, hesap damgası) başına bir kez
  /// derlenir — her harfte 2.000 satır taranmaz.
  String? _textCompletion() {
    final t = _cellField.text;
    final sheet = _sheet;
    if (!_editing || sheet == null || t.length < 2 || t.startsWith('=')) {
      return null;
    }
    if (double.tryParse(t.replaceAll(',', '.')) != null) return null;
    final key = (sheet.name, _selCol, _selRow, _calcStamp);
    final cached = _colTextCache;
    final List<(String, String)> entries;
    if (cached != null && cached.$1 == key) {
      entries = cached.$2;
    } else {
      final seen = <String>{};
      final built = <(String, String)>[];
      final n = math.min(sheet.maxRows, 2000);
      for (var r = 0; r < n; r++) {
        if (r == _selRow) continue;
        final v = sheet.rawAt(r, _selCol);
        if (v.length >= 2 && !v.startsWith('=') && seen.add(v)) {
          built.add((v, v.toLowerCase()));
        }
      }
      _colTextCache = (key, built);
      entries = built;
    }
    final low = t.toLowerCase();
    String? hit;
    for (final (raw, lower) in entries) {
      if (raw.length > t.length && lower.startsWith(low)) {
        if (hit != null && hit != raw) return null; // belirsiz → önerme
        hit = raw;
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

  /// Seçim levhası: aralıktan gelen uzun listede de kaydırılır (öğeler
  /// tembel kurulur); seçili değer işaretli.
  Future<void> _pickFromValidation() async {
    final options = _validationOptions();
    if (options.isEmpty) {
      _snack(context.t('excel.val_list_none'));
      return;
    }
    final current = _sheet?.rawAt(_selRow, _selCol).trim().toLowerCase() ?? '';
    final v = await showAppSheet<String>(
      context,
      title: context.t('excel.pick_from_list'),
      scrollable: false,
      builder: (ctx) => ListView.builder(
        shrinkWrap: true,
        itemCount: options.length,
        itemBuilder: (_, i) {
          final o = options[i];
          return ListTile(
            key: ValueKey('validation-option-$i'),
            title: Text(o),
            trailing: o.toLowerCase() == current
                ? const Icon(AppIcons.check, size: 20)
                : null,
            onTap: () => Navigator.pop(ctx, o),
          );
        },
      ),
    );
    if (v == null || !mounted) return;
    _cellField.text = v;
    _applyCell(v);
  }
}

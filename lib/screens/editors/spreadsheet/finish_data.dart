part of '../spreadsheet_editor_screen.dart';

/// Faz 27 (kalan) — çok düzeyli sıralama, süzgeç oluştur/kaldır, veri
/// doğrulama, notlar, kılavuz çizgileri, sekme rengi/gizle/çoğalt ve form
/// görünümü. Her değişiklik tek geri al adımı.
extension _SpreadsheetDataFinishPart on _SpreadsheetEditorScreenState {
  // ── çok düzeyli sıralama ────────────────────────────────────────────────

  Future<void> _customSort() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    var range = _range;
    if (range.bottom <= range.top) {
      final f = _filterRange(sheet);
      if (f == null) {
        _snack(context.t('excel.sort_needs_range'));
        return;
      }
      range = CellRange(f.r1, f.c1, math.max(f.r1 + 1, sheet.maxRows - 1), f.c2);
    }
    final engine = _engineFor(sheet);
    var header = true;
    final levels = <(int, bool)>[(range.left, true)];
    String colLabel(int c) {
      final h = header ? engine.displayValue(range.top, c).trim() : '';
      return h.isEmpty
          ? context.t('excel.column_n', {'c': XlsxRange.colName(c)})
          : '${XlsxRange.colName(c)} · $h';
    }

    final ok = await showAppSheet<bool>(
      context,
      title: context.t('excel.custom_sort'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SwitchListTile(
                key: const ValueKey('xl-sort-header'),
                contentPadding: EdgeInsets.zero,
                value: header,
                title: Text(ctx.t('excel.sort_has_header')),
                onChanged: (v) => set(() => header = v),
              ),
              for (var i = 0; i < levels.length; i++)
                Row(children: [
                  SizedBox(
                      width: 72,
                      child: Text(ctx.t(i == 0
                          ? 'excel.sort_by'
                          : 'excel.sort_then_by'))),
                  Expanded(
                    child: DropdownButton<int>(
                      key: ValueKey('xl-sort-col-$i'),
                      isExpanded: true,
                      value: levels[i].$1,
                      items: [
                        for (var c = range.left; c <= range.right; c++)
                          DropdownMenuItem(value: c, child: Text(colLabel(c))),
                      ],
                      onChanged: (c) =>
                          set(() => levels[i] = (c ?? levels[i].$1, levels[i].$2)),
                    ),
                  ),
                  IconButton(
                    key: ValueKey('xl-sort-dir-$i'),
                    tooltip: ctx.t(levels[i].$2 ? 'excel.sort_asc' : 'excel.sort_desc'),
                    icon: Icon(levels[i].$2 ? OfficeIcons.sortAsc : OfficeIcons.sortDesc),
                    onPressed: () =>
                        set(() => levels[i] = (levels[i].$1, !levels[i].$2)),
                  ),
                  if (i > 0)
                    IconButton(
                      tooltip: ctx.t('common.delete'),
                      icon: const Icon(AppIcons.close),
                      onPressed: () => set(() => levels.removeAt(i)),
                    ),
                ]),
              if (levels.length < 3)
                TextButton.icon(
                  key: const ValueKey('xl-sort-add'),
                  onPressed: () => set(() => levels.add((
                        math.min(range.right, levels.last.$1 + 1),
                        true,
                      ))),
                  icon: const Icon(AppIcons.add),
                  label: Text(ctx.t('excel.sort_add_level')),
                ),
              const SizedBox(height: 8),
              FilledButton(
                key: const ValueKey('xl-sort-ok'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('excel.sort')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final first = header ? range.top + 1 : range.top;
    final last = range.bottom;
    if (last <= first) return;
    final name = sheet.name;
    final width = sheet.maxCols;
    final before = [
      for (var r = first; r <= last; r++) editor.captureRow(name, r, width: width),
    ];
    String key(int r, int c) =>
        sheet.rawAt(r, c).startsWith('=') ? engine.displayValue(r, c) : sheet.rawAt(r, c);
    final order = multiSortOrder(first, last, [
      for (final (c, asc) in levels) SortLevel((r) => key(r, c), ascending: asc),
    ]);
    final after = [for (final r in order) before[r - first]];
    void write(List<SheetLineSnapshot> rows) {
      for (var i = 0; i < rows.length; i++) {
        editor.restoreRow(name, first + i, rows[i]);
      }
    }

    write(after);
    _recordStep('excel.undo_sort', () => write(after), () => write(before));
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  // ── süzgeç oluştur / kaldır ─────────────────────────────────────────────

  void _toggleAutoFilter() {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final before = sheet.layout.autoFilterRef;
    String? after;
    if (before == null) {
      var r = _range;
      if (r.bottom <= r.top) {
        // Tek hücre: bitişik veri bloğu (Excel'in "geçerli bölge"si).
        final top = r.top;
        var bottom = top;
        while (bottom + 1 < sheet.maxRows &&
            sheet.rawAt(bottom + 1, r.left).trim().isNotEmpty) {
          bottom++;
        }
        var right = r.left;
        while (right + 1 < sheet.maxCols &&
            sheet.rawAt(top, right + 1).trim().isNotEmpty) {
          right++;
        }
        r = CellRange(top, r.left, bottom, right);
      }
      after = XlsxRange(r.top, r.left, r.bottom, r.right).ref;
    }
    final hiddenBefore = {
      for (final e in sheet.filterHidden.entries) e.key: {...e.value},
    };
    void apply() => editor.setAutoFilter(sheet.name, after);
    void revert() {
      editor.setAutoFilter(sheet.name, before);
      hiddenBefore.forEach((c, rows) {
        sheet.filterHidden[c] = {...rows};
        sheet.layout.hiddenRows.addAll(rows);
      });
    }

    apply();
    _recordStep(after == null ? 'excel.undo_filter_off' : 'excel.undo_filter_on',
        apply, revert);
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
    _snack(context.t(after == null ? 'excel.filter_removed' : 'excel.filter_created'));
  }

  // ── veri doğrulama ──────────────────────────────────────────────────────

  Future<void> _showValidation() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final range = _xlRange;
    final cur = sheet.validationAt(_selRow, _selCol);
    var type = cur?.type ?? 'list';
    var op = cur?.operator ?? 'between';
    final listCtl = _valCtl[0]..text = cur?.options?.join(', ') ?? '';
    final aCtl = _valCtl[1]..text = cur?.formula1 ?? '';
    final bCtl = _valCtl[2]..text = cur?.formula2 ?? '';
    final errCtl = _valCtl[3]..text = cur?.error ?? '';
    final result = await showAppSheet<String>(
      context,
      title: context.t('excel.validation'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(range.ref, style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final t in const ['list', 'whole', 'decimal', 'date', 'textLength'])
                  ChoiceChip(
                    key: ValueKey('xl-val-type-$t'),
                    label: Text(ctx.t('excel.val_$t')),
                    selected: type == t,
                    onSelected: (_) => set(() => type = t),
                  ),
              ]),
              const SizedBox(height: 8),
              if (type == 'list')
                TextField(
                  key: const ValueKey('xl-val-list'),
                  controller: listCtl,
                  decoration:
                      InputDecoration(labelText: ctx.t('excel.val_list_hint')),
                )
              else ...[
                DropdownButton<String>(
                  key: const ValueKey('xl-val-op'),
                  isExpanded: true,
                  value: op,
                  items: [
                    for (final o in const [
                      'between', 'notBetween', 'equal', 'notEqual', 'greaterThan',
                      'lessThan', 'greaterThanOrEqual', 'lessThanOrEqual',
                    ])
                      DropdownMenuItem(value: o, child: Text(ctx.t('excel.op_$o'))),
                  ],
                  onChanged: (v) => set(() => op = v ?? op),
                ),
                TextField(
                  key: const ValueKey('xl-val-a'),
                  controller: aCtl,
                  keyboardType: type == 'date'
                      ? TextInputType.datetime
                      : const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                      labelText: ctx.t(type == 'date'
                          ? 'excel.val_date_hint'
                          : (op == 'between' || op == 'notBetween'
                              ? 'excel.val_min'
                              : 'excel.val_value'))),
                ),
                if (op == 'between' || op == 'notBetween')
                  TextField(
                    key: const ValueKey('xl-val-b'),
                    controller: bCtl,
                    keyboardType: type == 'date'
                        ? TextInputType.datetime
                        : const TextInputType.numberWithOptions(decimal: true, signed: true),
                    decoration: InputDecoration(labelText: ctx.t('excel.val_max')),
                  ),
              ],
              TextField(
                key: const ValueKey('xl-val-error'),
                controller: errCtl,
                decoration: InputDecoration(labelText: ctx.t('excel.val_error')),
              ),
              const SizedBox(height: 12),
              Row(children: [
                if (cur != null)
                  TextButton(
                    key: const ValueKey('xl-val-clear'),
                    onPressed: () => Navigator.pop(ctx, 'clear'),
                    child: Text(ctx.t('excel.val_clear')),
                  ),
                const Spacer(),
                FilledButton(
                  key: const ValueKey('xl-val-ok'),
                  onPressed: () => Navigator.pop(ctx, 'ok'),
                  child: Text(ctx.t('common.apply')),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
    String? toBound(String s) {
      final t = s.trim();
      if (t.isEmpty) return null;
      if (type == 'date') {
        // gg.aa.yyyy → Excel seri numarası (dosyada sayı durur).
        final m = RegExp(r'^(\d{1,2})[./](\d{1,2})[./](\d{4})$').firstMatch(t);
        if (m == null) return t;
        final dt = DateTime.utc(int.parse(m[3]!), int.parse(m[2]!), int.parse(m[1]!));
        return '${dt.difference(DateTime.utc(1899, 12, 30)).inDays}';
      }
      return t.replaceAll(',', '.');
    }

    final listText = listCtl.text, a = aCtl.text, b = bCtl.text, err = errCtl.text;
    if (result == null || !mounted) return;
    final name = sheet.name;
    final previous = [
      for (final v in sheet.layout.validations)
        if (v.ranges.any((x) =>
            x.r1 <= range.r2 && x.r2 >= range.r1 && x.c1 <= range.c2 && x.c2 >= range.c1))
          v,
    ];
    void Function() apply;
    if (result == 'clear') {
      apply = () => editor.clearValidations(name, range);
    } else {
      final opts = listText
          .split(RegExp(r'[,;]'))
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      if (type == 'list' && opts.isEmpty) {
        _snack(context.t('excel.val_list_empty'));
        return;
      }
      final v = XlsxDataValidation(
        type: type,
        ranges: [range],
        options: type == 'list' ? opts : null,
        formula1: type == 'list' ? '"${opts.join(',')}"' : toBound(a),
        formula2: type == 'list' || !(op == 'between' || op == 'notBetween')
            ? null
            : toBound(b),
        operator: type == 'list' ? 'between' : op,
        error: err.trim().isEmpty ? null : err.trim(),
      );
      apply = () => editor.addValidation(name, range, v);
    }
    apply();
    _recordStep('excel.undo_validation', apply,
        () => editor.restoreValidations(name, range, previous));
    _session.changed();
    _partSetState(() {});
  }

  /// Girişi doğrulama kuralına göre denetler; uymuyorsa Excel'in "Durdur"
  /// uyarısı (giriş yazılmaz). true = yazılabilir.
  bool _passesValidation(String value) {
    final v = _sheet?.validationAt(_selRow, _selCol);
    if (v == null || v.accepts(value)) return true;
    showAppConfirm(
      context,
      title: context.t('excel.val_invalid_title'),
      message: v.error ?? context.t('excel.val_invalid'),
      confirmLabel: context.t('common.ok'),
    );
    return false;
  }

  /// Seçili hücrede not var mı (şerit düğmesinin adı).
  bool get _noteHere {
    final sheet = _sheet;
    return sheet != null &&
        sheet.layout.comments.containsKey(cellKey(_selRow, _selCol));
  }

  /// Formüller sekmesi: Σ gibi ama [fn] işleviyle (ORTALAMA, MAK…).
  void _autoFunction(String fn) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final range = autoSumRange(
        _selRow, _selCol, (r, c) => sheet.isNumericAt(r, c));
    final formula = range == null
        ? '=$fn()'
        : '=$fn(${CellRef(range.top, range.left)}:'
            '${CellRef(range.bottom, range.right)})';
    _editCells('excel.undo_autosum', {CellRef(_selRow, _selCol): formula});
    if (range == null && mounted) _snack(context.t('excel.autosum_empty'));
  }

  // ── notlar ──────────────────────────────────────────────────────────────

  Future<void> _editNote() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _selRow, c = _selCol;
    final cur = editor.noteAt(sheet.name, r, c);
    final text = await showAppPrompt(
      context,
      title: context.t(cur == null ? 'excel.note_new' : 'excel.note_edit'),
      label: context.t('excel.note_hint'),
      initial: cur?.text ?? '',
      confirmLabel: context.t('common.save'),
    );
    if (text == null || !mounted) return;
    _setNote(r, c, text);
  }

  void _setNote(int r, int c, String? text) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final name = sheet.name;
    final before = editor.noteAt(name, r, c);
    void apply() => editor.setNote(name, r, c, text,
        author: before?.author ?? context.t('excel.note_author'));
    void revert() =>
        editor.setNote(name, r, c, before?.text, author: before?.author ?? '');
    apply();
    _recordStep('excel.undo_note', apply, revert);
    _session.changed();
    _partSetState(() {});
  }

  // ── görünüm ─────────────────────────────────────────────────────────────

  void _toggleGridLines() {
    final sheet = _sheet;
    if (sheet == null) return;
    final now = sheet.layout.showGridLines;
    void set(bool v) => sheet.layout.showGridLines = v;
    set(!now);
    _recordStep('excel.undo_gridlines', () => set(!now), () => set(now));
    _session.changed();
    _partSetState(() {});
  }

  // ── sekmeler ────────────────────────────────────────────────────────────

  Future<void> _pickTabColor(XlsxSheet sheet) async {
    final editor = _editor;
    if (editor == null) return;
    final before = sheet.layout.tabColorArgb;
    await _pickColor(context.t('excel.tab_color'), (c) {
      final after = c?.toARGB32();
      void apply() => editor.setTabColor(sheet.name, after);
      apply();
      _recordStep('excel.undo_tab_color', apply,
          () => editor.setTabColor(sheet.name, before));
      _session.changed();
      _partSetState(() {});
    });
  }

  void _hideSheet(XlsxSheet sheet) {
    final editor = _editor;
    if (editor == null) return;
    if (!editor.setSheetHidden(sheet.name, true)) {
      _snack(context.t('excel.last_visible_sheet'));
      return;
    }
    _recordStep('excel.undo_hide_sheet',
        () => editor.setSheetHidden(sheet.name, true),
        () => editor.setSheetHidden(sheet.name, false));
    final visible = editor.sheets.indexWhere((s) => !s.layout.hidden);
    _partSetState(() {
      _sheetIndex = visible < 0 ? 0 : visible;
      _gridVersion++;
    });
    _session.changed();
    _syncField();
  }

  Future<void> _unhideSheet() async {
    final editor = _editor;
    if (editor == null) return;
    final hidden = editor.sheets.where((s) => s.layout.hidden).toList();
    if (hidden.isEmpty) return;
    final pick = await showAppSheet<XlsxSheet>(
      context,
      title: context.t('excel.unhide_sheet'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in hidden)
            ListTile(
              key: ValueKey('xl-unhide-${s.name}'),
              title: Text(s.name),
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (pick == null || !mounted) return;
    editor.setSheetHidden(pick.name, false);
    _recordStep('excel.undo_unhide_sheet',
        () => editor.setSheetHidden(pick.name, false),
        () => editor.setSheetHidden(pick.name, true));
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(pick);
      _gridVersion++;
    });
    _session.changed();
    _syncField();
  }

  void _duplicateSheet(XlsxSheet sheet) {
    final editor = _editor;
    if (editor == null) return;
    _endEdit();
    final copy = editor.duplicateSheet(sheet.name);
    if (copy == null) return;
    _recordStep('excel.undo_duplicate_sheet', () {
      if (!editor.sheets.contains(copy)) {
        editor.sheets.insert(
            (editor.sheets.indexOf(sheet) + 1).clamp(0, editor.sheets.length),
            copy);
        editor.calcLog.bulk();
      }
    }, () {
      editor.sheets.remove(copy);
      editor.calcLog.bulk();
      _sheetIndex = _sheetIndex.clamp(0, editor.sheets.length - 1);
    });
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(copy);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _gridVersion++;
    });
    _session.changed();
    _syncField();
  }

  // ── form görünümü ───────────────────────────────────────────────────────

  /// Telefona özel kayıt kartı: seçili satır başlıkları etiket, hücreleri
  /// alan olarak gösterir; ‹ › satır, "Yeni kayıt" tablonun sonuna ekler.
  Future<void> _showFormView() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final headerRow = sheet.layout.autoFilterRef != null
        ? XlsxRange.parse(sheet.layout.autoFilterRef)!.r1
        : 0;
    var lastCol = 0;
    for (var c = 0; c < sheet.maxCols; c++) {
      if (sheet.rawAt(headerRow, c).trim().isNotEmpty) lastCol = c;
    }
    var lastRow = headerRow;
    for (var r = headerRow + 1; r < sheet.maxRows; r++) {
      if (sheet.rows.length > r && sheet.rows[r].any((v) => v.isNotEmpty)) {
        lastRow = r;
      }
    }
    var row = math.max(headerRow + 1, _selRow);
    await Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (ctx) => _SheetFormPage(
        headers: [
          for (var c = 0; c <= lastCol; c++)
            sheet.rawAt(headerRow, c).trim().isEmpty
                ? XlsxRange.colName(c)
                : _engineFor(sheet).displayValue(headerRow, c),
        ],
        firstRow: headerRow + 1,
        lastRow: () => lastRow,
        initialRow: row,
        valueAt: (r, c) => sheet.rawAt(r, c),
        numeric: (c) => sheet.isNumericAt(headerRow + 1, c),
        options: (r, c) => sheet.validationAt(r, c)?.options,
        validate: (r, c, v) {
          final rule = sheet.validationAt(r, c);
          return rule == null || rule.accepts(v) ? null : (rule.error ?? ctx.t('excel.val_invalid'));
        },
        save: (r, values) {
          final edits = <CellRef, String>{
            for (final MapEntry(key: c, value: v) in values.entries)
              if (sheet.rawAt(r, c) != v) CellRef(r, c): v,
          };
          if (edits.isNotEmpty) _editCells('excel.undo_form', edits);
          if (r > lastRow) lastRow = r;
        },
      ),
    ));
    if (mounted) _partSetState(() {});
  }
}

/// Form görünümü sayfası (madde 8): bir kayıt = bir kart.
class _SheetFormPage extends StatefulWidget {
  final List<String> headers;
  final int firstRow;
  final int Function() lastRow;
  final int initialRow;
  final String Function(int r, int c) valueAt;
  final bool Function(int c) numeric;
  final List<String>? Function(int r, int c) options;
  final String? Function(int r, int c, String value) validate;
  final void Function(int r, Map<int, String> values) save;

  const _SheetFormPage({
    required this.headers,
    required this.firstRow,
    required this.lastRow,
    required this.initialRow,
    required this.valueAt,
    required this.numeric,
    required this.options,
    required this.validate,
    required this.save,
  });

  @override
  State<_SheetFormPage> createState() => _SheetFormPageState();
}

class _SheetFormPageState extends State<_SheetFormPage> {
  late int _row = widget.initialRow;
  late final List<TextEditingController> _ctl = [
    for (var c = 0; c < widget.headers.length; c++) TextEditingController(),
  ];
  final Map<int, String?> _errors = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _ctl) {
      c.dispose();
    }
    super.dispose();
  }

  void _load() {
    for (var c = 0; c < _ctl.length; c++) {
      _ctl[c].text = widget.valueAt(_row, c);
    }
    _errors.clear();
  }

  /// Geçerliyse yazar; geçersiz alan varsa yazmaz (false).
  bool _commit() {
    _errors.clear();
    for (var c = 0; c < _ctl.length; c++) {
      final e = widget.validate(_row, c, _ctl[c].text);
      if (e != null) _errors[c] = e;
    }
    if (_errors.isNotEmpty) {
      setState(() {});
      return false;
    }
    final values = {for (var c = 0; c < _ctl.length; c++) c: _ctl[c].text};
    final empty = values.values.every((v) => v.trim().isEmpty);
    if (!empty || _row <= widget.lastRow()) widget.save(_row, values);
    return true;
  }

  void _go(int row) {
    if (!_commit()) return;
    setState(() {
      _row = row;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final last = widget.lastRow();
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('excel.form_record', {
          'n': _row - widget.firstRow + 1,
          'total': math.max(last, _row) - widget.firstRow + 1,
        })),
        actions: [
          IconButton(
            key: const ValueKey('xl-form-done'),
            tooltip: context.t('common.done'),
            icon: const Icon(AppIcons.check),
            onPressed: () {
              if (_commit()) Navigator.pop(context);
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (var c = 0; c < widget.headers.length; c++)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _field(c),
            ),
        ],
      ),
      bottomNavigationBar: _nav(last),
    );
  }

  Widget _field(int c) {
    final opts = widget.options(_row, c);
    return opts != null
                  ? DropdownButtonFormField<String>(
                      key: ValueKey('xl-form-field-$c'),
                      initialValue: opts.contains(_ctl[c].text) ? _ctl[c].text : null,
                      decoration: InputDecoration(
                          labelText: widget.headers[c], errorText: _errors[c]),
                      items: [
                        for (final o in opts)
                          DropdownMenuItem(value: o, child: Text(o)),
                      ],
                      onChanged: (v) => _ctl[c].text = v ?? '',
                    )
                  : TextField(
                      key: ValueKey('xl-form-field-$c'),
                      controller: _ctl[c],
                      keyboardType: widget.numeric(c)
                          ? const TextInputType.numberWithOptions(
                              decimal: true, signed: true)
                          : TextInputType.text,
                      decoration: InputDecoration(
                          labelText: widget.headers[c], errorText: _errors[c]),
                    );
  }

  Widget _nav(int last) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            IconButton(
              key: const ValueKey('xl-form-prev'),
              tooltip: context.t('excel.form_prev'),
              icon: const Icon(AppIcons.back),
              onPressed: _row > widget.firstRow ? () => _go(_row - 1) : null,
            ),
            IconButton(
              key: const ValueKey('xl-form-next'),
              tooltip: context.t('excel.form_next'),
              icon: const Icon(AppIcons.arrowForward),
              onPressed: _row < last ? () => _go(_row + 1) : null,
            ),
            const Spacer(),
            FilledButton.tonalIcon(
              key: const ValueKey('xl-form-new'),
              onPressed: () => _go(math.max(last, _row) + 1),
              icon: const Icon(AppIcons.add),
              label: Text(context.t('excel.form_new')),
            ),
          ]),
        ),
      );
}

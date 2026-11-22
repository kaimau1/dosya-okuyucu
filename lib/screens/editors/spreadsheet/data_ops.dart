part of '../spreadsheet_editor_screen.dart';

/// Faz 27 — Veri araçları (yinelenenleri kaldır, metni sütunlara böl),
/// bölme dondurma, satır/sütun gizle-göster.
extension _SpreadsheetEditorScreenDataPart on _SpreadsheetEditorScreenState {
  /// Seçim tek hücreyse: süzgeç aralığı ya da kullanılan alan; değilse seçim.
  CellRange _dataRange(XlsxSheet sheet) {
    if (_hasRange) return _range;
    final f = _filterRange(sheet);
    if (f != null) {
      return CellRange(f.r1, f.c1, math.max(f.r1, sheet.maxRows - 1), f.c2);
    }
    return CellRange(
        0, 0, math.max(0, sheet.maxRows - 1), math.max(0, sheet.maxCols - 1));
  }

  // ── yinelenenleri kaldır ───────────────────────────────────────────────

  Future<void> _removeDuplicates() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _dataRange(sheet);
    if (r.bottom <= r.top) {
      _snack(context.t('excel.dup_needs_range'));
      return;
    }
    final engine = _engineFor(sheet);
    String shown(int row, int col) => sheet.rawAt(row, col).startsWith('=')
        ? engine.displayValue(row, col)
        : sheet.rawAt(row, col);
    var header = true;
    final go = await showAppSheet<bool>(
      context,
      title: context.t('excel.dup_title'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              CheckboxListTile(
                key: const ValueKey('dup-header'),
                value: header,
                onChanged: (v) => set(() => header = v ?? true),
                title: Text(ctx.t('excel.dup_has_header')),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: Gap.sm),
              FilledButton(
                key: const ValueKey('dup-run'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('excel.dup_run')),
              ),
            ],
          ),
        ),
      ),
    );
    if (go != true || !mounted) return;
    final rows = [
      for (var row = r.top; row <= r.bottom; row++)
        [for (var c = r.left; c <= r.right; c++) shown(row, c)],
    ];
    final drop = duplicateRowIndexes(rows, hasHeader: header).toSet();
    if (drop.isEmpty) {
      _snack(context.t('excel.dup_none'));
      return;
    }
    // Kalan satırlar yukarı kayar; alttaki boşalan satırlar temizlenir.
    final keep = [
      for (var i = 0; i < rows.length; i++)
        if (!drop.contains(i)) i,
    ];
    final values = <CellRef, String>{};
    for (var i = 0; i < rows.length; i++) {
      for (var c = r.left; c <= r.right; c++) {
        final src = i < keep.length ? keep[i] : -1;
        values[CellRef(r.top + i, c)] =
            src < 0 ? '' : sheet.rawAt(r.top + src, c);
      }
    }
    _editCells('excel.undo_dedup', values);
    _snack(context.t('excel.dup_done',
        {'n': drop.length, 'm': keep.length - (header ? 1 : 0)}));
  }

  // ── metni sütunlara böl ────────────────────────────────────────────────

  Future<void> _splitTextToColumns() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    var comma = true, semi = false, tab = false, space = false, merge = false;
    final custom = TextEditingController();
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('excel.split_title'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) {
          Widget chip(String key, String label, bool on, void Function(bool) f) =>
              FilterChip(
                key: ValueKey(key),
                label: Text(label),
                selected: on,
                onSelected: (v) => set(() => f(v)),
              );
          return Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(spacing: Gap.sm, children: [
                  chip('split-comma', ctx.t('excel.split_comma'), comma,
                      (v) => comma = v),
                  chip('split-semi', ctx.t('excel.split_semi'), semi,
                      (v) => semi = v),
                  chip('split-tab', ctx.t('excel.split_tab'), tab,
                      (v) => tab = v),
                  chip('split-space', ctx.t('excel.split_space'), space,
                      (v) => space = v),
                  chip('split-merge', ctx.t('excel.split_merge'), merge,
                      (v) => merge = v),
                ]),
                const SizedBox(height: Gap.sm),
                TextField(
                  key: const ValueKey('split-custom'),
                  controller: custom,
                  decoration:
                      InputDecoration(labelText: ctx.t('excel.split_custom')),
                ),
                const SizedBox(height: Gap.md),
                FilledButton(
                  key: const ValueKey('split-run'),
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(ctx.t('excel.split_run')),
                ),
              ],
            ),
          );
        },
      ),
    );
    final customText = custom.text;
    custom.dispose();
    if (ok != true || !mounted) return;
    final spec = SplitSpec(
        comma: comma,
        semicolon: semi,
        tab: tab,
        space: space,
        custom: customText,
        merge: merge);
    if (!spec.any) return;
    final values = <CellRef, String>{};
    var widest = 0;
    final engine = _engineFor(sheet);
    for (var row = r.top; row <= r.bottom; row++) {
      final raw = sheet.rawAt(row, r.left);
      final text = raw.startsWith('=') ? engine.displayValue(row, r.left) : raw;
      final parts = splitText(text, spec);
      widest = math.max(widest, parts.length);
      for (var k = 0; k < parts.length; k++) {
        values[CellRef(row, r.left + k)] = parts[k];
      }
    }
    if (widest <= 1) {
      _snack(context.t('excel.split_none'));
      return;
    }
    // Aynı satırda önceki bölmeden kalan sağdaki hücreler ezilmez; yalnız
    // üretilen parçalar yazılır (Excel de hedefi ezer, boşaltmaz).
    _editCells('excel.undo_split', values);
    _snack(context.t('excel.split_done', {'n': widest}));
  }

  // ── hızlı doldurma (B10 m.4) ───────────────────────────────────────────

  /// Excel'in "Hızlı doldurma"sı: seçili hücrenin sütununa yazılmış
  /// örneklerden (ör. "Ali Veli" → "Ali") komşu sütunlara bakarak desen
  /// çıkarır ve aynı bloktaki BOŞ hücreleri doldurur. Desen bulunamazsa
  /// hiçbir şey yazılmaz; kullanıcı bir örnek daha yazıp yeniden dener.
  void _flashFill() {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final col = _selCol;
    final lastRow = math.max(0, sheet.maxRows - 1);
    final lastCol = _colCount(sheet) - 1;
    bool filled(int r, int c) =>
        c >= 0 && c <= lastCol && sheet.rawAt(r, c).trim().isNotEmpty;
    bool neighbour(int r) => filled(r, col - 1) || filled(r, col + 1);
    if (!neighbour(_selRow)) {
      _snack(context.t('excel.flash_need_data'));
      return;
    }
    var top = _selRow, bottom = _selRow;
    while (top > 0 && neighbour(top - 1)) {
      top--;
    }
    while (bottom < lastRow && neighbour(bottom + 1)) {
      bottom++;
    }
    // Kaynak: hedefin iki yanındaki bitişik dolu sütunlar (en çok 6'şar).
    bool colHasData(int c) {
      for (var r = top; r <= bottom; r++) {
        if (filled(r, c)) return true;
      }
      return false;
    }

    final sources = <int>[];
    for (var c = col - 1; c >= 0 && col - c <= 6 && colHasData(c); c--) {
      sources.insert(0, c);
    }
    for (var c = col + 1; c <= lastCol && c - col <= 6 && colHasData(c); c++) {
      sources.add(c);
    }
    final engine = _engineFor(sheet);
    String shown(int r, int c) {
      final raw = sheet.rawAt(r, c);
      return raw.startsWith('=') ? engine.displayValue(r, c) : raw;
    }

    final rows = [
      for (var r = top; r <= bottom; r++) [for (final c in sources) shown(r, c)],
    ];
    final examples = <int, String>{};
    for (var r = top; r <= bottom; r++) {
      final raw = sheet.rawAt(r, col);
      if (raw.trim().isNotEmpty && !raw.startsWith('=')) examples[r - top] = raw;
    }
    if (examples.isEmpty) {
      _snack(context.t('excel.flash_need_example'));
      return;
    }
    var found = FlashFill.infer(rows, examples);
    // Üst satır başlık olabilir ("Ad Soyad" → "Ad"): onsuz bir kez daha dene.
    if (found == null && examples.containsKey(0) && examples.length > 1) {
      found = FlashFill.infer(rows, {...examples}..remove(0));
      found?.remove(0);
    }
    final values = <CellRef, String>{
      for (final e in (found ?? const <int, String>{}).entries)
        if (sheet.rawAt(top + e.key, col).trim().isEmpty)
          CellRef(top + e.key, col): e.value,
    };
    if (values.isEmpty) {
      _snack(context.t('excel.flash_none'));
      return;
    }
    _editCells('excel.flash_fill', values);
    _snack(context.t('excel.flash_done', {'n': values.length}));
  }

  // ── bölmeleri dondur ───────────────────────────────────────────────────

  /// [mode]: `cell` (seçili hücrenin üstü/solu), `row` (ilk satır),
  /// `col` (ilk sütun), `none` (çöz).
  void _setFreeze(String mode) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final oldR = sheet.frozenRows, oldC = sheet.frozenCols;
    final (newR, newC) = switch (mode) {
      'cell' => (_selRow, _selCol),
      'row' => (1, 0),
      'col' => (0, 1),
      _ => (0, 0),
    };
    final name = sheet.name;
    void apply(int r, int c) {
      sheet.setFreeze(r, c);
      _freeze = r > 0 || c > 0;
      _firstCol = 0;
      _lastCol = 0;
    }

    apply(newR, newC);
    _recordStep('excel.undo_freeze', () => apply(newR, newC), () {
      if (editor.hasSheet(name)) apply(oldR, oldC);
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateColWindow());
  }

  // ── satır / sütun gizle - göster ───────────────────────────────────────

  void _hideLines({required bool rows}) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _range;
    final lines = rows
        ? [for (var i = r.top; i <= r.bottom; i++) i]
        : [for (var i = r.left; i <= r.right; i++) i];
    _setHidden(rows, lines, true, 'excel.undo_hide');
  }

  /// Seçim aralığındaki (ve bir yanındaki) gizli satır/sütunları gösterir.
  void _showHiddenLines({required bool rows}) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    final lo = rows ? r.top : r.left, hi = rows ? r.bottom : r.right;
    final set = rows ? sheet.layout.hiddenRows : sheet.layout.hiddenCols;
    final lines = [
      for (var i = math.max(0, lo - 1); i <= hi + 1; i++)
        if (set.contains(i)) i,
    ];
    if (lines.isEmpty) {
      _snack(context.t('excel.nothing_hidden'));
      return;
    }
    _setHidden(rows, lines, false, 'excel.undo_unhide');
  }

  void _setHidden(bool rows, List<int> lines, bool hide, String label) {
    final editor = _editor;
    final sheet = _sheet;
    if (editor == null || sheet == null) return;
    void put(bool h) {
      for (final i in lines) {
        rows ? sheet.setRowHidden(i, h) : sheet.setColHidden(i, h);
      }
    }

    put(hide);
    _recordStep(label, () => put(hide), () => put(!hide));
    _session.changed();
    _gridVersion++;
    _autoFitVersion++;
    _partSetState(() {});
  }
}

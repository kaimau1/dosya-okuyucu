part of '../spreadsheet_editor_screen.dart';

/// Özet tablo bağı: hangi sayfa hangi kaynaktan, hangi ayarla üretildi
/// (oturum içi; "Özeti yenile" bununla kaynağı yeniden okur).
class _PivotLink {
  final String source;
  final CellRange range;
  final PivotSpec spec;
  const _PivotLink(this.source, this.range, this.spec);
}

/// Faz 36 — Excel pro veri araçları (özet tablo …).
extension _SpreadsheetProDataPart on _SpreadsheetEditorScreenState {
  /// Aralığın GÖRÜNEN değerleri (formül sonucu dahil).
  List<List<String>> _rangeValues(XlsxSheet sheet, CellRange r) {
    final engine = _engineFor(sheet);
    String shown(int row, int col) => sheet.rawAt(row, col).startsWith('=')
        ? engine.displayValue(row, col)
        : sheet.rawAt(row, col);
    return [
      for (var row = r.top; row <= r.bottom; row++)
        [for (var c = r.left; c <= r.right; c++) shown(row, c)],
    ];
  }

  // ── 1. Özet tablo ──────────────────────────────────────────────────────

  Future<void> _createPivot() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _dataRange(sheet);
    if (r.bottom <= r.top) {
      _snack(context.t('excel.dup_needs_range'));
      return;
    }
    final data = _rangeValues(sheet, r);
    final header = [
      for (var i = 0; i < data.first.length; i++)
        data.first[i].trim().isEmpty ? CellRef.colName(r.left + i) : data.first[i].trim(),
    ];
    final spec = await showAppSheet<PivotSpec>(
      context,
      title: context.t('xp.pivot'),
      builder: (_) => _PivotSheet(header: header, data: data),
    );
    if (spec == null || !mounted) return;
    final link = _PivotLink(sheet.name, r, spec);
    var n = 1;
    while (editor.hasSheet(context.t('xp.pivot_sheet', {'n': n}))) {
      n++;
    }
    final added = editor.addSheet(context.t('xp.pivot_sheet', {'n': n}));
    if (added == null) return;
    await _writePivot(added.name, link, data);
    if (!mounted) return;
    _partSetState(() {
      _pivots[added.name] = link;
      _sheetIndex = editor.sheets.indexOf(added);
      _selRow = 0;
      _selCol = 0;
      _anchorRow = 0;
      _anchorCol = 0;
      _session.changed();
      _gridVersion++;
    });
    _syncField();
  }

  /// Özet sonucunu [target] sayfasına düz değer olarak yazar (önce temizler).
  /// Hesap (gruplama) izolatta koşar — 100 bin satırda UI izleği donmaz
  /// (Faz 36 perf).
  Future<void> _writePivot(
      String target, _PivotLink link, List<List<String>> data) async {
    final editor = _editor!;
    final spec = link.spec;
    final totalLabel = context.t('xp.grand_total');
    final blankLabel = context.t('xp.blank');
    final valueHeader = context.t('xp.agg_header', {
      'agg': context.t('xp.agg_${spec.agg.name}'),
      'field': data.first[spec.valueField],
    });
    PivotResult run() => Pivot.build(data, spec,
        totalLabel: totalLabel, blankLabel: blankLabel, valueHeader: valueHeader);
    final result = data.length > 5000 ? await Isolate.run(run) : run();
    final model = editor.sheets.firstWhere((s) => s.name == target);
    for (var row = 0; row < model.rows.length; row++) {
      for (var c = 0; c < model.rows[row].length; c++) {
        if (model.rows[row][c].isNotEmpty) editor.setCell(target, row, c, '');
      }
    }
    for (var row = 0; row < result.cells.length; row++) {
      for (var c = 0; c < result.cells[row].length; c++) {
        editor.setCell(target, row, c, result.cells[row][c]);
      }
    }
  }

  /// Etkin sayfa bir özetse kaynağını yeniden okuyup sonucu tazeler.
  Future<void> _refreshPivot() async {
    final sheet = _sheet;
    final editor = _editor;
    final link = sheet == null ? null : _pivots[sheet.name];
    if (sheet == null || editor == null || link == null) return;
    _endEdit();
    final source = editor.sheets.where((s) => s.name == link.source).firstOrNull;
    if (source == null) {
      _snack(context.t('xp.pivot_source_gone'));
      return;
    }
    await _writePivot(sheet.name, link, _rangeValues(source, link.range));
    if (!mounted) return;
    _partSetState(() {
      _session.changed();
      _gridVersion++;
    });
    _syncField();
    _snack(context.t('xp.pivot_refreshed'));
  }

  // ── 2. Koşullu biçim yazma ─────────────────────────────────────────────

  XlsxRange _selXlsxRange() =>
      XlsxRange(_range.top, _range.left, _range.bottom, _range.right);

  /// Kuralı ekler, geri al/yinele adımı kaydeder, ızgarayı tazeler.
  void _commitCondRule(XlsxCondRule Function() add) {
    final sheet = _sheet;
    if (sheet == null) return;
    XlsxCondRule? added;
    void apply() => added = add();
    apply();
    _recordStep('excel.undo_cond_format', apply, () {
      final rule = added;
      if (rule != null) sheet.removeCondRule(rule);
    });
    _condCache.clear();
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// Renk ölçeği / veri çubuğu / simge kümesi (görünüm kuralın kendisinde).
  void _addVisualCond(String type, {List<int>? scale, int? bar}) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final xr = _selXlsxRange();
    _commitCondRule(() => sheet.addCondRule(
          range: xr,
          type: type,
          scaleColors: scale,
          barColorArgb: bar,
          iconSet: type == 'iconSet' ? '3TrafficLights1' : null,
        ));
  }

  /// Formül kuralı: aralığın sol-üst hücresine göre yazılmış koşul
  /// (`=B2>100`); doğruysa seçilen dolgu.
  Future<void> _askFormulaCond() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final top = '${CellRef.colName(_range.left)}${_range.top + 1}';
    final input = await showAppPrompt(
      context,
      title: context.t('xp.cond_formula'),
      label: context.t('xp.cond_formula_hint', {'cell': top}),
      initial: '=$top>0',
    );
    if (input == null || !mounted) return;
    final body = input.startsWith('=') ? input.substring(1) : input;
    // Dosyaya İngilizce işlev adlarıyla yazılır (Excel/LibreOffice okur).
    final formula = _turkishFormulas
        ? FormulaEngine.toFileFormula(body, turkish: true)
        : body;
    await _pickColor(context.t('excel.fill_color'), (color) {
      final fill = _SpreadsheetEditorScreenState._argbOf(
          color ?? AppColors.condFillDefault);
      final xr = _selXlsxRange();
      _commitCondRule(() => sheet.addCondRule(
            range: xr,
            type: 'expression',
            formulas: [formula],
            fillArgb: fill,
          ));
    });
  }

  // ── 3. Mini grafik ─────────────────────────────────────────────────────

  /// Seçimin HER SATIRI için, seçimin sağındaki ilk sütuna bir mini grafik
  /// (Excel'in "Konum aralığı" varsayılanı). Tek satırlık seçimde tek grafik.
  Future<void> _insertSparklines() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    if (r.right <= r.left && r.bottom <= r.top) {
      _snack(context.t('xp.sparkline_needs_range'));
      return;
    }
    final type = await showAppSheet<String>(
      context,
      title: context.t('xp.sparkline'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (t, icon) in const [
            ('line', AppIcons.trendingUp),
            ('column', AppIcons.barChart),
            ('stacked', AppIcons.swapVert),
          ])
            ListTile(
              key: ValueKey('spark-$t'),
              leading: Icon(icon),
              title: Text(ctx.t('xp.spark_$t')),
              onTap: () => Navigator.pop(ctx, t),
            ),
        ],
      ),
    );
    if (type == null || !mounted) return;
    // Tek sütunlu seçim → dikey seri, hedef sütunun altındaki hücre.
    final vertical = r.right == r.left;
    final added = <XlsxSparkline>[];
    void apply() {
      added.clear();
      if (vertical) {
        added.add(sheet.addSparkline(
          source: XlsxRange(r.top, r.left, r.bottom, r.right),
          row: r.bottom + 1,
          col: r.left,
          type: type,
        ));
        return;
      }
      for (var row = r.top; row <= r.bottom; row++) {
        added.add(sheet.addSparkline(
          source: XlsxRange(row, r.left, row, r.right),
          row: row,
          col: r.right + 1,
          type: type,
        ));
      }
    }

    apply();
    _recordStep('xp.undo_sparkline', apply, () {
      for (final sp in added) {
        sheet.removeSparkline(sp);
      }
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  // ── 6. Parola ile aç / koru ────────────────────────────────────────────

  /// Dosya parolalıysa sorar, çözer ve modeli kurar (true). Parolasızsa
  /// false (normal açılış). Vazgeçilirse `_error`.
  Future<bool> _openEncrypted() async {
    final ext = p.extension(widget.path).toLowerCase();
    if (ext != '.xlsx' && ext != '.xlsm') return false;
    // Önce 8 baytlık imza EŞZAMANLI okunur: sıradan xlsx (ZIP) burada
    // döner, açılış yolu eskisi gibi kalır (zaman uyumsuz okuma test
    // saatinde ve açılışta gereksiz bekleme yaratıyordu).
    try {
      final raf = File(widget.path).openSync();
      try {
        if (!OleFile.looksLikeOle(raf.readSync(8))) return false;
      } finally {
        raf.closeSync();
      }
    } on FileSystemException {
      return false;
    }
    final bytes = await File(widget.path).readAsBytes();
    if (!OfficeCrypto.isEncrypted(bytes)) return false;
    String? hint;
    for (var attempt = 0; attempt < 5; attempt++) {
      if (!mounted) return true;
      final pw = await _askFilePassword(context.t('xp.password_open'), hint);
      if (pw == null) {
        _error = AppStrings.current.t('xp.password_cancelled');
        return true;
      }
      try {
        final plain = await OfficeCrypto.decryptInBackground(bytes, pw);
        _editor = await compute(XlsxEditor.parse, plain);
        _filePassword = pw;
        return true;
      } on OfficeCryptoException catch (e) {
        if (e.code != 'wrong_password') {
          _error = AppStrings.current.t('xp.password_unsupported');
          return true;
        }
        hint = AppStrings.current.t('xp.password_wrong');
      }
    }
    _error = AppStrings.current.t('xp.password_wrong');
    return true;
  }

  /// Gizli girişli parola levhası; [error] altta kırmızı.
  Future<String?> _askFilePassword(String title, String? error,
      {bool confirm = false}) {
    return showAppSheet<String>(
      context,
      title: title,
      builder: (_) => _PasswordSheet(error: error, confirm: confirm),
    );
  }

  Future<void> _protectWithPassword() async {
    _endEdit();
    final pw = await _askFilePassword(context.t('xp.password_set'), null,
        confirm: true);
    if (pw == null || pw.isEmpty || !mounted) return;
    _partSetState(() => _filePassword = pw);
    _session.changed();
    _snack(context.t('xp.password_set_done'));
  }

  void _removePassword() {
    if (_filePassword == null) return;
    _partSetState(() => _filePassword = null);
    _session.changed();
    _snack(context.t('xp.password_removed'));
  }

  // ── 6. Yazdırma düzeni → PDF ───────────────────────────────────────────

  Future<void> _printToPdf() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final spec = await showAppSheet<SheetPrintSpec>(
      context,
      title: context.t('xp.print_pdf'),
      builder: (_) => _PrintSheet(title: sheet.name),
    );
    if (spec == null || !mounted) return;
    // Seçim varsa yalnız seçim, yoksa yazdırma alanı (Faz 36 madde 12),
    // o da yoksa kullanılan alan; gizli satır/sütun yok.
    final area = sheet.printArea;
    final r = _hasRange
        ? _range
        : area != null
            ? CellRange(area.r1, area.c1, area.r2, area.c2)
            : CellRange(0, 0, math.max(0, sheet.maxRows - 1),
                math.max(0, sheet.maxCols - 1));
    final engine = _engineFor(sheet);
    final cols = [
      for (var c = r.left; c <= r.right; c++)
        if (!sheet.isColHidden(c)) c,
    ];
    final cells = <List<String>>[];
    final numeric = <int>{};
    for (var row = r.top; row <= r.bottom; row++) {
      if (sheet.isRowHidden(row)) continue;
      final out = <String>[];
      for (var k = 0; k < cols.length; k++) {
        final view = sheet.viewAt(row, cols[k], engine.displayValue(row, cols[k]));
        out.add(view.text);
        if (view.numeric) numeric.add(cells.length * 16384 + k);
      }
      cells.add(out);
    }
    // Sondaki boş satırlar atılır.
    while (cells.isNotEmpty && cells.last.every((v) => v.isEmpty)) {
      cells.removeLast();
    }
    if (cells.isEmpty) {
      _snack(context.t('xp.print_empty'));
      return;
    }
    final widths = [for (final c in cols) sheet.colWidth(c)];
    final label = context.t('xp.print_page');
    final ok = context.t('xp.print_done');
    final font = await rootBundle.load('assets/fonts/Carlito-Regular.ttf');
    final fontBytes = font.buffer.asUint8List();
    final pdf = await Isolate.run(() => SheetPdf.build(
          cells: cells,
          colWidthsPx: widths,
          spec: spec,
          numeric: numeric,
          fontBytes: fontBytes,
          pageLabel: (n, t) => label.replaceAll('{n}', '$n').replaceAll('{t}', '$t'),
        ));
    final f = File(p.join(Directory.systemTemp.path,
        '${p.basenameWithoutExtension(widget.name)}-${sheet.name}.pdf'));
    await f.writeAsBytes(pdf, flush: true);
    if (!mounted) return;
    _snack(ok);
    await SharePlus.instance.share(ShareParams(files: [XFile(f.path)]));
  }

  // ── 7. Görünüm: sade şerit, yoğunluk ───────────────────────────────────

  static const _simpleRibbonKey = 'excel_simple_ribbon';
  static const _densityKey = 'excel_density';

  /// Görünüm tercihleri (açılışta bir kez; dosyanın kendi yakınlığı varsa o
  /// kazanır — `_load` sonrası `zoomScale`).
  Future<void> _loadViewPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final simple = prefs.getBool(_simpleRibbonKey) ?? false;
      final density = prefs.getDouble(_densityKey);
      final pro = prefs.getBool('excel_pro_v1') ?? true;
      if (!mounted) return;
      if (pro != _excelPro) _partSetState(() => _excelPro = pro);
      if (simple != _simpleRibbon) _partSetState(() => _simpleRibbon = simple);
      final fileZoom = _sheet?.layout.zoomScale ?? 1;
      if (density != null && density != 1 && fileZoom == 1) {
        _zoomCtl.setZoom(density);
      }
    } catch (_) {
      // Tercih okunamazsa varsayılan görünüm.
    }
  }

  void _setSimpleRibbon(bool on) {
    _partSetState(() => _simpleRibbon = on);
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setBool(_simpleRibbonKey, on))
        .catchError((_) => false));
  }

  /// Yoğunluk = taban yakınlık (kompakt 0,85 · normal 1 · rahat 1,2).
  void _setDensity(double v) {
    _zoomCtl.setZoom(v);
    unawaited(SharedPreferences.getInstance()
        .then((p) => p.setDouble(_densityKey, v))
        .catchError((_) => false));
  }

  // ── 8. Veri: içe aktar, ara toplam, gruplama, not dizisi, köprü ────────

  /// Yeni sayfaya hücre değerleri (ham) yazar ve oraya geçer.
  void _writeNewSheet(String base, List<List<String>> rows) {
    final editor = _editor;
    if (editor == null) return;
    var name = base.length > 28 ? base.substring(0, 28) : base;
    name = name.replaceAll(RegExp(r'[\[\]:*?/\\]'), '_');
    var candidate = name;
    for (var n = 2; editor.hasSheet(candidate); n++) {
      candidate = '$name ($n)';
    }
    final added = editor.addSheet(candidate);
    if (added == null) return;
    for (var r = 0; r < rows.length; r++) {
      for (var c = 0; c < rows[r].length; c++) {
        if (rows[r][c].isNotEmpty) editor.setCell(added.name, r, c, rows[r][c]);
      }
    }
    _partSetState(() {
      _sheetIndex = editor.sheets.indexOf(added);
      _selRow = _selCol = _anchorRow = _anchorCol = 0;
      _session.changed();
      _gridVersion++;
    });
    _syncField();
  }

  Future<void> _importData() async {
    _endEdit();
    final res = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt', 'ods'],
    );
    final path = res?.files.single.path;
    if (path == null || !mounted) return;
    final bytes = await File(path).readAsBytes();
    if (!mounted) return;
    final base = p.basenameWithoutExtension(path);
    if (p.extension(path).toLowerCase() == '.ods') {
      try {
        final sheets = await Isolate.run(() => SheetImport.parseOds(bytes));
        if (!mounted) return;
        for (final e in sheets.entries) {
          _writeNewSheet(sheets.length == 1 ? base : e.key, e.value);
        }
        _snack(context.t('xp.import_done', {'n': sheets.length}));
      } catch (e) {
        if (mounted) _snack(userErrorText(e));
      }
      return;
    }
    final rows = await showAppSheet<List<List<String>>>(
      context,
      title: context.t('xp.import'),
      builder: (_) => _ImportSheet(bytes: bytes),
    );
    if (rows == null || !mounted) return;
    _writeNewSheet(base, rows);
    _snack(context.t('xp.import_done', {'n': 1}));
  }

  Future<void> _insertSubtotals() async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _dataRange(sheet);
    if (r.bottom <= r.top) {
      _snack(context.t('excel.dup_needs_range'));
      return;
    }
    final raw = [
      for (var row = r.top; row <= r.bottom; row++)
        [for (var c = r.left; c <= r.right; c++) sheet.rawAt(row, c)],
    ];
    final header = [
      for (var i = 0; i < raw.first.length; i++)
        raw.first[i].trim().isEmpty ? CellRef.colName(r.left + i) : raw.first[i],
    ];
    final picked = await showAppSheet<(int, List<int>)>(
      context,
      title: context.t('xp.subtotal'),
      builder: (_) => _SubtotalSheet(header: header),
    );
    if (picked == null || !mounted) return;
    final out = Subtotals.build(
      raw,
      groupCol: picked.$1,
      sumCols: picked.$2,
      top: 0,
      left: 0,
      totalSuffix: context.t('xp.subtotal_suffix'),
      grandLabel: context.t('xp.grand_total'),
    );
    // Özgün aralığa dokunulmaz: sonuç yeni sayfada (A1'den), formüller oraya göre.
    _writeNewSheet(context.t('xp.subtotal_sheet', {'name': sheet.name}), out);
  }

  void _groupSelectedRows(bool group) {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    final r = _range;
    void apply() => group
        ? sheet.groupRows(r.top, r.bottom)
        : sheet.ungroupRows(r.top, r.bottom);
    void revert() => group
        ? sheet.ungroupRows(r.top, r.bottom)
        : sheet.groupRows(r.top, r.bottom);
    apply();
    _recordStep(group ? 'xp.group' : 'xp.ungroup', apply, revert);
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  /// İmlecin bulunduğu grubu daraltır/genişletir (satırları gizler/gösterir).
  void _toggleOutlineGroup() {
    final sheet = _sheet;
    if (sheet == null) return;
    final g = sheet.outlineGroupAt(_selRow);
    if (g == null) {
      _snack(context.t('xp.no_group'));
      return;
    }
    final lines = [for (var i = g.$1; i <= g.$2; i++) i];
    final hide = !lines.every(sheet.isRowHidden);
    _setHidden(true, lines, hide, hide ? 'xp.collapse' : 'xp.expand');
    if (hide) {
      // İmleç görünür bir satıra (grubun üstü) çıkar.
      _partSetState(() => _selRow = _anchorRow = math.max(0, g.$1 - 1));
    }
  }

  Future<void> _replyToNote() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final r = _selRow, c = _selCol;
    final cur = editor.noteAt(sheet.name, r, c);
    final reply = await showAppPrompt(
      context,
      title: context.t('xp.note_reply'),
      label: context.t('excel.note_hint'),
      multiline: true,
    );
    if (reply == null || !mounted) return;
    _setNote(r, c,
        NoteThread.appendReply(cur?.text ?? '', context.t('excel.note_author'),
            reply, DateTime.now()));
  }

  Future<void> _insertLink() async {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _endEdit();
    final kind = await showAppSheet<String>(
      context,
      title: context.t('xp.link'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            key: const ValueKey('link-web'),
            leading: const Icon(AppIcons.pdfWeb),
            title: Text(ctx.t('xp.link_web')),
            onTap: () => Navigator.pop(ctx, 'web'),
          ),
          for (final s in editor.sheets)
            ListTile(
              leading: const Icon(AppIcons.tableView),
              title: Text(ctx.t('xp.link_sheet', {'name': s.name})),
              onTap: () => Navigator.pop(ctx, 'sheet:${s.name}'),
            ),
        ],
      ),
    );
    if (kind == null || !mounted) return;
    final r = _selRow, c = _selCol;
    String? url, location, display;
    if (kind == 'web') {
      final input = await showAppPrompt(context,
          title: context.t('xp.link_web'), label: 'https://', initial: 'https://');
      if (input == null || !mounted) return;
      url = input.contains('://') || input.startsWith('mailto:')
          ? input
          : 'https://$input';
      display = url;
    } else {
      final target = kind.substring(6);
      final cell = await showAppPrompt(context,
          title: context.t('xp.link_cell', {'name': target}), initial: 'A1');
      if (cell == null || !mounted) return;
      final quoted = "'${target.replaceAll("'", "''")}'";
      location = '$quoted!${cell.toUpperCase()}';
      display = '$target!${cell.toUpperCase()}';
    }
    editor.addLink(XlsxLinkSpec(
      sheetName: sheet.name,
      row: r,
      col: c,
      url: url,
      location: location,
      display: display,
    ));
    if (sheet.rawAt(r, c).isEmpty) {
      _editCells('xp.link', {CellRef(r, c): display});
    }
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }
}

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
    await Share.shareXFiles([XFile(f.path)]);
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
      if (!mounted) return;
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

/// İçe aktarma önizlemesi: ayraç, kodlama, başlık + ilk satırlar ve türler.
class _ImportSheet extends StatefulWidget {
  const _ImportSheet({required this.bytes});

  final Uint8List bytes;

  @override
  State<_ImportSheet> createState() => _ImportSheetState();
}

class _ImportSheetState extends State<_ImportSheet> {
  String? _delimiter;
  String _encoding = 'auto';
  bool _header = true;

  @override
  Widget build(BuildContext context) {
    final rows = SheetImport.parseText(widget.bytes,
        ImportOptions(delimiter: _delimiter, encoding: _encoding, header: _header));
    final types = SheetImport.columnTypes(rows, header: _header);
    final preview = rows.take(6).toList();
    String typeLabel(ColumnType t) => context.t('xp.type_${t.name}');
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(context.t('xp.delimiter'), style: context.type.caption),
          Wrap(spacing: Gap.xs, children: [
            for (final (v, k) in const [
              (null, 'xp.delim_auto'),
              (',', 'xp.delim_comma'),
              (';', 'xp.delim_semi'),
              ('\t', 'xp.delim_tab'),
              ('|', 'xp.delim_pipe'),
            ])
              ChoiceChip(
                label: Text(context.t(k)),
                selected: _delimiter == v,
                onSelected: (_) => setState(() => _delimiter = v),
              ),
          ]),
          Text(context.t('xp.encoding'), style: context.type.caption),
          Wrap(spacing: Gap.xs, children: [
            for (final (v, k) in const [
              ('auto', 'xp.delim_auto'),
              ('utf8', 'xp.enc_utf8'),
              ('cp1254', 'xp.enc_cp1254'),
            ])
              ChoiceChip(
                label: Text(context.t(k)),
                selected: _encoding == v,
                onSelected: (_) => setState(() => _encoding = v),
              ),
          ]),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: _header,
            onChanged: (v) => setState(() => _header = v),
            title: Text(context.t('excel.dup_has_header')),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 28,
              dataRowMinHeight: 24,
              dataRowMaxHeight: 28,
              columns: [
                for (var c = 0; c < types.length; c++)
                  DataColumn(
                    label: Text(
                      '${_header && preview.isNotEmpty && c < preview.first.length ? preview.first[c] : CellRef.colName(c)}\n${typeLabel(types[c])}',
                      style: context.type.caption,
                    ),
                  ),
              ],
              rows: [
                for (final row in preview.skip(_header ? 1 : 0))
                  DataRow(cells: [
                    for (var c = 0; c < types.length; c++)
                      DataCell(Text(c < row.length ? row[c] : '',
                          style: context.type.small)),
                  ]),
              ],
            ),
          ),
          Text(context.t('xp.import_rows', {'n': rows.length}),
              style: context.type.caption),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('xl-import-go'),
            onPressed: () => Navigator.pop(context, rows),
            child: Text(context.t('xp.import_go')),
          ),
        ],
      ),
    );
  }
}

/// Ara toplam: grup sütunu + toplanacak sütunlar.
class _SubtotalSheet extends StatefulWidget {
  const _SubtotalSheet({required this.header});

  final List<String> header;

  @override
  State<_SubtotalSheet> createState() => _SubtotalSheetState();
}

class _SubtotalSheetState extends State<_SubtotalSheet> {
  int _group = 0;
  late final Set<int> _sum = {widget.header.length - 1};

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _group,
              decoration: InputDecoration(labelText: context.t('xp.subtotal_by')),
              items: [
                for (var i = 0; i < widget.header.length; i++)
                  DropdownMenuItem(value: i, child: Text(widget.header[i])),
              ],
              onChanged: (v) => setState(() => _group = v ?? 0),
            ),
            const SizedBox(height: Gap.sm),
            Text(context.t('xp.subtotal_sum'), style: context.type.caption),
            Wrap(spacing: Gap.xs, children: [
              for (var i = 0; i < widget.header.length; i++)
                if (i != _group)
                  FilterChip(
                    label: Text(widget.header[i]),
                    selected: _sum.contains(i),
                    onSelected: (on) =>
                        setState(() => on ? _sum.add(i) : _sum.remove(i)),
                  ),
            ]),
            const SizedBox(height: Gap.sm),
            FilledButton(
              onPressed: _sum.isEmpty
                  ? null
                  : () => Navigator.pop(context,
                      (_group, (_sum.where((c) => c != _group).toList()..sort()))),
              child: Text(context.t('xp.subtotal_go')),
            ),
          ],
        ),
      );
}

/// Yazdırma ayarları: yön, sayfaya sığdır, başlık yinele, ızgara.
class _PrintSheet extends StatefulWidget {
  const _PrintSheet({required this.title});

  final String title;

  @override
  State<_PrintSheet> createState() => _PrintSheetState();
}

class _PrintSheetState extends State<_PrintSheet> {
  bool _landscape = false;
  bool _fit = true;
  int _repeat = 1;
  bool _grid = true;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<bool>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: false, label: Text(context.t('xp.portrait'))),
                ButtonSegment(value: true, label: Text(context.t('xp.landscape'))),
              ],
              selected: {_landscape},
              onSelectionChanged: (v) => setState(() => _landscape = v.first),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _fit,
              onChanged: (v) => setState(() => _fit = v),
              title: Text(context.t('xp.fit_width')),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _grid,
              onChanged: (v) => setState(() => _grid = v),
              title: Text(context.t('xp.print_grid')),
            ),
            Text(context.t('xp.repeat_rows'), style: context.type.caption),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                for (final n in const [0, 1, 2])
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_repeat},
              onSelectionChanged: (v) => setState(() => _repeat = v.first),
            ),
            const SizedBox(height: Gap.sm),
            FilledButton(
              key: const ValueKey('xl-print-go'),
              onPressed: () => Navigator.pop(
                context,
                SheetPrintSpec(
                  landscape: _landscape,
                  fitWidth: _fit,
                  repeatRows: _repeat,
                  gridLines: _grid,
                  title: widget.title,
                ),
              ),
              child: Text(context.t('xp.print_go')),
            ),
          ],
        ),
      );
}

/// Parola girişi (gizli) + isteğe bağlı doğrulama alanı.
class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({this.error, this.confirm = false});

  final String? error;
  final bool confirm;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _pw = TextEditingController();
  final _again = TextEditingController();
  late String? _error = widget.error;

  @override
  void dispose() {
    _pw.dispose();
    _again.dispose();
    super.dispose();
  }

  void _submit() {
    if (_pw.text.isEmpty) return;
    if (widget.confirm && _pw.text != _again.text) {
      setState(() => _error = context.t('xp.password_mismatch'));
      return;
    }
    Navigator.pop(context, _pw.text);
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              key: const ValueKey('xl-password'),
              controller: _pw,
              autofocus: true,
              obscureText: true,
              decoration: InputDecoration(
                labelText: context.t('xp.password'),
                errorText: widget.confirm ? null : _error,
              ),
              onSubmitted: widget.confirm ? null : (_) => _submit(),
            ),
            if (widget.confirm)
              TextField(
                key: const ValueKey('xl-password-again'),
                controller: _again,
                obscureText: true,
                decoration: InputDecoration(
                    labelText: context.t('xp.password_again'),
                    errorText: _error),
                onSubmitted: (_) => _submit(),
              ),
            const SizedBox(height: Gap.sm),
            FilledButton(onPressed: _submit, child: Text(context.t('common.ok'))),
          ],
        ),
      );
}

/// Özet tablo ayar levhası: satır / sütun / değer alanı, işlev, süzgeç.
class _PivotSheet extends StatefulWidget {
  const _PivotSheet({required this.header, required this.data});

  final List<String> header;
  final List<List<String>> data;

  @override
  State<_PivotSheet> createState() => _PivotSheetState();
}

class _PivotSheetState extends State<_PivotSheet> {
  int _row = 0;
  int? _col;
  late int _value = widget.header.length - 1;
  PivotAgg _agg = PivotAgg.sum;
  int? _filter;
  Set<String> _allowed = {};

  DropdownButtonFormField<int?> _field(String key, String label, int? value,
          ValueChanged<int?> onChanged, {bool optional = false}) =>
      DropdownButtonFormField<int?>(
        key: ValueKey(key),
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          if (optional)
            DropdownMenuItem<int?>(value: null, child: Text(context.t('xp.none'))),
          for (var i = 0; i < widget.header.length; i++)
            DropdownMenuItem<int?>(value: i, child: Text(widget.header[i])),
        ],
        onChanged: onChanged,
      );

  @override
  Widget build(BuildContext context) {
    final values = _filter == null
        ? const <String>[]
        : Pivot.distinct(widget.data, _filter!, limit: 60);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _field('pv-row', context.t('xp.rows'), _row,
              (v) => setState(() => _row = v ?? 0)),
          _field('pv-col', context.t('xp.cols'), _col,
              (v) => setState(() => _col = v), optional: true),
          _field('pv-value', context.t('xp.values'), _value,
              (v) => setState(() => _value = v ?? _value)),
          DropdownButtonFormField<PivotAgg>(
            key: const ValueKey('pv-agg'),
            initialValue: _agg,
            decoration: InputDecoration(labelText: context.t('xp.agg')),
            items: [
              for (final a in PivotAgg.values)
                DropdownMenuItem(value: a, child: Text(context.t('xp.agg_${a.name}'))),
            ],
            onChanged: (v) => setState(() => _agg = v ?? _agg),
          ),
          _field('pv-filter', context.t('xp.filter'), _filter,
              (v) => setState(() {
                    _filter = v;
                    _allowed = {};
                  }),
              optional: true),
          if (values.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: Gap.sm),
              child: Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final v in values)
                    FilterChip(
                      label: Text(v.isEmpty ? context.t('xp.blank') : v),
                      selected: _allowed.contains(v),
                      onSelected: (on) => setState(
                          () => on ? _allowed.add(v) : _allowed.remove(v)),
                    ),
                ],
              ),
            ),
          const SizedBox(height: Gap.sm),
          FilledButton(
            key: const ValueKey('pv-run'),
            onPressed: () => Navigator.pop(
              context,
              PivotSpec(
                rowField: _row,
                colField: _col,
                valueField: _value,
                agg: _agg,
                filterField: _filter,
                filterValues: {..._allowed},
              ),
            ),
            child: Text(context.t('xp.pivot_create')),
          ),
        ],
      ),
    );
  }
}

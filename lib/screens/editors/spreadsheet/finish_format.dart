part of '../spreadsheet_editor_screen.dart';

/// Faz 27 (kalan) — Excel mobilin "Hücreleri biçimlendir" paneli (Sayı ·
/// Hizalama · Yazı tipi · Kenarlık · Dolgu), hücre stilleri, "Tablo olarak
/// biçimlendir" ve CSV uyarısı. Her değişiklik tek geri al adımı.
extension _SpreadsheetFinishPart on _SpreadsheetEditorScreenState {
  XlsxRange get _xlRange {
    final r = _range;
    return XlsxRange(r.top, r.left, r.bottom, r.right);
  }

  // ── CSV ─────────────────────────────────────────────────────────────────

  /// CSV açıkken biçim düğmeleri: biçim dosyada SAKLANMAZ — bir kez söylenir,
  /// "XLSX olarak kaydet" önerilir. true = biçim yine uygulansın (ekranda).
  bool _csvFormatGuard() {
    if (_editor?.csv == null) return true;
    if (_csvWarned) return true;
    _csvWarned = true;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      key: const ValueKey('xl-csv-warning'),
      content: Text(context.t('excel.csv_format_lost')),
      action: SnackBarAction(
          label: context.t('excel.csv_save_xlsx'), onPressed: _saveCsvAsXlsx),
    ));
    return true;
  }

  /// CSV'yi aynı ada `.xlsx` olarak kaydeder (biçimler korunur); düzenleme
  /// CSV'de sürer.
  Future<void> _saveCsvAsXlsx() async {
    final editor = _editor;
    final f = editor?.csv;
    if (editor == null || f == null) return;
    _endEdit();
    final target = '${p.withoutExtension(widget.savePath ?? widget.path)}.xlsx';
    try {
      editor.csv = null;
      final bytes = await editor.saveAsync();
      await SafeWrite.bytes(target, bytes);
      if (mounted) {
        _snack(context.t('excel.saved_as_xlsx', {'name': p.basename(target)}));
      }
    } catch (e) {
      if (mounted) {
        _snack(AppStrings.current
            .t('common.save_failed', {'error': userErrorText(e)}));
      }
    } finally {
      editor.csv = f;
    }
  }

  // ── Hücreleri biçimlendir ───────────────────────────────────────────────

  static const _numCats = [
    'general', 'number', 'currency', 'accounting', 'date', 'time', 'percent',
    'fraction', 'scientific', 'text', 'custom',
  ];

  /// Biçim kodundan kategori (panel açılınca doğru sekme seçili gelsin).
  static String _catOf(String code) {
    final c = code.trim();
    if (c.isEmpty || c == 'General') return 'general';
    if (c == '@') return 'text';
    if (c.contains('E+')) return 'scientific';
    if (c.contains('?/')) return 'fraction';
    if (c.contains('%')) return 'percent';
    if (c.startsWith('_-') || c.startsWith('_(')) return 'accounting';
    if (RegExp(r'[₺$€£]').hasMatch(c)) return 'currency';
    final f = ExcelNumberFormat.parse(c);
    if (f.isDate) {
      return RegExp(r'[dy]', caseSensitive: false).hasMatch(c.replaceAll(RegExp(r'\[[^\]]*\]'), ''))
          ? 'date'
          : 'time';
    }
    if (RegExp(r'^[#0,.;\[\]Red()\-]+$').hasMatch(c)) return 'number';
    return 'custom';
  }

  static String _dec(int n) => n <= 0 ? '' : '.${'0' * n}';

  static String _numberCode(String cat,
      {int decimals = 2,
      bool thousands = true,
      String negative = 'minus',
      String symbol = '₺',
      bool symbolAfter = true}) {
    final d = _dec(decimals);
    switch (cat) {
      case 'general':
        return 'General';
      case 'number':
        final b = '${thousands ? '#,##0' : '0'}$d';
        return switch (negative) {
          'red' => '$b;[Red]$b',
          'paren' => '$b;($b)',
          'redParen' => '$b;[Red]($b)',
          _ => b,
        };
      case 'currency':
        final b = '#,##0$d';
        return symbolAfter ? '$b "$symbol"' : '"$symbol"$b';
      case 'accounting':
        return '_-* #,##0$d "$symbol"_-;-* #,##0$d "$symbol"_-;'
            '_-* "-"?? "$symbol"_-;_-@_-';
      case 'percent':
        return '0$d%';
      case 'scientific':
        return '0${_dec(decimals)}E+00';
      case 'text':
        return '@';
    }
    return 'General';
  }

  static const _dateCodes = [
    'dd.mm.yyyy', 'd mmmm yyyy', 'dddd, d mmmm yyyy', 'dd.mm.yy',
    'yyyy-mm-dd', 'mmm yy', 'd mmm',
  ];
  static const _timeCodes = ['hh:mm', 'hh:mm:ss', 'dd.mm.yyyy hh:mm', '[h]:mm'];
  static const _fractionCodes = ['# ?/?', '# ??/??', '# ?/2', '# ?/4', '# ?/10'];

  /// Seçili hücrenin değerinin [code] ile görünüşü (canlı önizleme).
  String _formatPreview(String code) {
    final sheet = _sheet;
    if (sheet == null) return '';
    final raw = sheet.rawAt(_selRow, _selCol);
    final engine = _engineFor(sheet);
    final shown = raw.startsWith('=') ? engine.displayValue(_selRow, _selCol) : raw;
    final n = double.tryParse(raw.startsWith('=') ? '' : raw) ??
        double.tryParse(shown.replaceAll('.', '').replaceAll(',', '.'));
    try {
      final f = ExcelNumberFormat.parse(code);
      return f.format(n ?? (shown.isEmpty ? 1234.5 : shown)).text;
    } catch (_) {
      return '—';
    }
  }

  void _applyAlign({XlsxHAlign? h, XlsxVAlign? v, int? indent, int? rotation}) {
    _csvFormatGuard();
    _applyCellFormat(
      'excel.undo_format',
      (ed, s, r, c) => ed.setCellFormat(s, r, c,
          hAlign: h, vAlign: v, indent: indent, rotation: rotation),
      (ed, s, r, c, b) => ed.setCellFormat(s, r, c,
          hAlign: h == null ? null : b.hAlign,
          vAlign: v == null ? null : b.vAlign,
          indent: indent == null ? null : b.indent,
          rotation: rotation == null ? null : b.rotation),
    );
  }

  void _applyDecoration({bool? underline, bool? strike}) {
    _csvFormatGuard();
    _applyCellFormat(
      'excel.undo_format',
      (ed, s, r, c) =>
          ed.setCellFormat(s, r, c, underline: underline, strike: strike),
      (ed, s, r, c, b) => ed.setCellFormat(s, r, c,
          underline: underline == null ? null : b.underline,
          strike: strike == null ? null : b.strike),
    );
  }

  /// Kenarlık ön ayarı: `all`, `outline`, `inside`, `top`, `bottom`, `left`,
  /// `right`, `thickOutline`, `none` — çizgi biçimi ve rengiyle.
  void _applyBorderPreset(String preset, String style, Color? color) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    _csvFormatGuard();
    _endEdit();
    final range = _range;
    final name = sheet.name;
    final before = <CellRef, XlsxBorder>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): (sheet.styleAt(r, c) ?? const XlsxCellStyle()).border,
    };
    Map<String, String?> sidesFor(int r, int c) {
      final top = r == range.top, bottom = r == range.bottom;
      final left = c == range.left, right = c == range.right;
      final st = preset == 'thickOutline' ? 'thick' : style;
      return switch (preset) {
        'all' => {'left': st, 'right': st, 'top': st, 'bottom': st},
        'outline' || 'thickOutline' => {
            if (left) 'left': st,
            if (right) 'right': st,
            if (top) 'top': st,
            if (bottom) 'bottom': st,
          },
        'inside' => {
            if (!left) 'left': st,
            if (!right) 'right': st,
            if (!top) 'top': st,
            if (!bottom) 'bottom': st,
          },
        'top' => {if (top) 'top': st},
        'bottom' => {if (bottom) 'bottom': st},
        'left' => {if (left) 'left': st},
        'right' => {if (right) 'right': st},
        _ => {'left': null, 'right': null, 'top': null, 'bottom': null},
      };
    }

    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          final sides = sidesFor(r, c);
          if (sides.isEmpty) continue;
          editor.setCellBorderColored(name, r, c, sides, color);
        }
      }
    }

    applyNow();
    _recordStep('excel.undo_border', applyNow, () {
      before.forEach((at, b) {
        for (final (side, s) in [
          ('left', b.left),
          ('right', b.right),
          ('top', b.top),
          ('bottom', b.bottom),
        ]) {
          editor.setCellBorderColored(name, at.row, at.col,
              {side: s.visible ? s.style : null},
              s.colorArgb == null ? null : Color(s.colorArgb!));
        }
      });
    });
    _session.changed();
    _partSetState(() {});
  }

  Future<void> _showFormatCells({int initialTab = 0}) async {
    final sheet = _sheet;
    if (sheet == null) return;
    _endEdit();
    var cat = _catOf(sheet.numFmtCode(_selRow, _selCol));
    var decimals = 2, thousands = true, negative = 'minus';
    var symbol = '₺', symbolAfter = true;
    var borderStyle = 'thin';
    Color? borderColor;
    final custom = _fcCustom..text = sheet.numFmtCode(_selRow, _selCol);
    await showAppSheet<void>(
      context,
      title: context.t('excel.format_cells'),
      scrollable: false,
      builder: (ctx) => DefaultTabController(
        length: 5,
        initialIndex: initialTab,
        child: StatefulBuilder(builder: (ctx, set) {
          final st = _sheet?.styleAt(_selRow, _selCol) ?? const XlsxCellStyle();
          final scheme = Theme.of(ctx).colorScheme;
          Widget chip(String label, bool on, VoidCallback tap, {Key? key}) =>
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
                child: ChoiceChip(
                    key: key,
                    label: Text(label),
                    selected: on,
                    onSelected: (_) {
                      tap();
                      set(() {});
                    }),
              );
          Widget section(String title, List<Widget> kids) => Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(ctx).textTheme.labelLarge),
                    const SizedBox(height: 6),
                    Wrap(children: kids),
                  ],
                ),
              );
          String currentCode() => switch (cat) {
                'date' || 'time' || 'fraction' || 'custom' => custom.text,
                _ => _numberCode(cat,
                    decimals: decimals,
                    thousands: thousands,
                    negative: negative,
                    symbol: symbol,
                    symbolAfter: symbolAfter),
              };
          void applyNumber(String code) {
            custom.text = code;
            _csvFormatGuard();
            _applyNumberFormat((_) => code);
            set(() {});
          }

          final number = ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              section(ctx.t('excel.fc_category'), [
                for (final k in _numCats)
                  chip(ctx.t('excel.fc_$k'), cat == k, () {
                    cat = k;
                    if (k == 'date') custom.text = _dateCodes.first;
                    if (k == 'time') custom.text = _timeCodes.first;
                    if (k == 'fraction') custom.text = _fractionCodes.first;
                  }, key: ValueKey('xl-fc-cat-$k')),
              ]),
              if (const {'number', 'currency', 'accounting', 'percent', 'scientific'}
                  .contains(cat))
                section(ctx.t('excel.fc_decimals'), [
                  for (var d = 0; d <= 4; d++)
                    chip('$d', decimals == d, () => decimals = d,
                        key: ValueKey('xl-fc-dec-$d')),
                ]),
              if (cat == 'number') ...[
                section(ctx.t('excel.fc_thousands'), [
                  chip(ctx.t('common.yes'), thousands, () => thousands = true),
                  chip(ctx.t('common.no'), !thousands, () => thousands = false),
                ]),
                section(ctx.t('excel.fc_negative'), [
                  for (final (k, sample) in const [
                    ('minus', '-1234'),
                    ('red', '1234 ●'),
                    ('paren', '(1234)'),
                    ('redParen', '(1234) ●'),
                  ])
                    chip(sample, negative == k, () => negative = k),
                ]),
              ],
              if (cat == 'currency' || cat == 'accounting') ...[
                section(ctx.t('excel.fc_symbol'), [
                  for (final s in const ['₺', '\$', '€', '£'])
                    chip(s, symbol == s, () => symbol = s),
                ]),
                if (cat == 'currency')
                  section(ctx.t('excel.fc_symbol_pos'), [
                    chip('1.234 $symbol', symbolAfter, () => symbolAfter = true),
                    chip('${symbol}1.234', !symbolAfter, () => symbolAfter = false),
                  ]),
              ],
              if (cat == 'date' || cat == 'time' || cat == 'fraction')
                section(ctx.t('excel.fc_type'), [
                  for (final c in cat == 'date'
                      ? _dateCodes
                      : cat == 'time'
                          ? _timeCodes
                          : _fractionCodes)
                    chip(_formatPreview(c), custom.text == c, () => custom.text = c),
                ]),
              if (cat == 'custom')
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    key: const ValueKey('xl-fc-custom'),
                    controller: custom,
                    decoration:
                        InputDecoration(labelText: ctx.t('excel.fc_code')),
                    onChanged: (_) => set(() {}),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${ctx.t('excel.fc_sample')}: ${_formatPreview(currentCode())}',
                      key: const ValueKey('xl-fc-preview'),
                      style: Theme.of(ctx).textTheme.titleMedium,
                    ),
                  ),
                  FilledButton(
                    key: const ValueKey('xl-fc-apply-number'),
                    onPressed: () => applyNumber(currentCode()),
                    child: Text(ctx.t('common.apply')),
                  ),
                ]),
              ),
            ],
          );

          final align = ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              section(ctx.t('excel.fc_horizontal'), [
                for (final (h, k) in const [
                  (XlsxHAlign.general, 'excel.fc_general'),
                  (XlsxHAlign.left, 'common.align_left'),
                  (XlsxHAlign.center, 'common.align_center'),
                  (XlsxHAlign.right, 'common.align_right'),
                  (XlsxHAlign.justify, 'common.align_justify'),
                ])
                  chip(ctx.t(k), st.hAlign == h, () => _applyAlign(h: h),
                      key: ValueKey('xl-fc-h-${h.name}')),
              ]),
              section(ctx.t('excel.fc_vertical'), [
                for (final (v, k) in const [
                  (XlsxVAlign.top, 'excel.fc_top'),
                  (XlsxVAlign.center, 'excel.fc_middle'),
                  (XlsxVAlign.bottom, 'excel.fc_bottom'),
                ])
                  chip(ctx.t(k), st.vAlign == v, () => _applyAlign(v: v),
                      key: ValueKey('xl-fc-v-${v.name}')),
              ]),
              section(ctx.t('excel.fc_indent'), [
                IconButton(
                  tooltip: ctx.t('sl.indent_less'),
                  icon: const Icon(OfficeIcons.indentLess),
                  onPressed: st.indent <= 0
                      ? null
                      : () {
                          _applyAlign(indent: st.indent - 1);
                          set(() {});
                        },
                ),
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text('${st.indent}'),
                ),
                IconButton(
                  key: const ValueKey('xl-fc-indent-more'),
                  tooltip: ctx.t('sl.indent_more'),
                  icon: const Icon(OfficeIcons.indentMore),
                  onPressed: st.indent >= 15
                      ? null
                      : () {
                          _applyAlign(indent: st.indent + 1);
                          set(() {});
                        },
                ),
              ]),
              section(ctx.t('excel.fc_rotation'), [
                for (final (deg, label) in const [
                  (0, '0°'),
                  (45, '45°'),
                  (90, '90°'),
                  (135, '−45°'),
                  (180, '−90°'),
                ])
                  chip(label, st.rotation == deg, () => _applyAlign(rotation: deg),
                      key: ValueKey('xl-fc-rot-$deg')),
              ]),
              section(ctx.t('excel.fc_control'), [
                chip(ctx.t('excel.wrap_text'), st.wrap, () => _applyWrap(!st.wrap)),
                chip(
                    ctx.t(_sheet?.mergeAt(_selRow, _selCol) != null
                        ? 'excel.unmerge'
                        : 'excel.merge_center'),
                    _sheet?.mergeAt(_selRow, _selCol) != null, () {
                  final merging = _sheet?.mergeAt(_selRow, _selCol) == null;
                  _toggleMerge();
                  if (merging) _applyAlign(h: XlsxHAlign.center);
                }),
              ]),
            ],
          );

          final font = ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              ListTile(
                leading: const Icon(OfficeIcons.fontFamily),
                title: Text(st.fontFamily ?? ctx.t('excel.font_default')),
                subtitle: Text(ctx.t('word.font_family')),
                onTap: () async {
                  await _pickFontFamily();
                  set(() {});
                },
              ),
              ListTile(
                leading: const Icon(OfficeIcons.fontSize),
                title: Text(_sizeText(st.fontSize)),
                subtitle: Text(ctx.t('word.font_size')),
                onTap: () async {
                  await _pickFontSize();
                  set(() {});
                },
              ),
              section(ctx.t('excel.fc_style'), [
                chip(ctx.t('common.bold'), st.bold,
                    () => _applyStyle(bold: !st.bold)),
                chip(ctx.t('common.italic'), st.italic,
                    () => _applyStyle(italic: !st.italic)),
                chip(ctx.t('common.underline'), st.underline,
                    () => _applyDecoration(underline: !st.underline),
                    key: const ValueKey('xl-fc-underline')),
                chip(ctx.t('common.strike'), st.strike,
                    () => _applyDecoration(strike: !st.strike),
                    key: const ValueKey('xl-fc-strike')),
              ]),
              section(ctx.t('excel.font_color'), [
                for (final argb in _SpreadsheetEditorScreenState._palette)
                  _swatch(ctx, Color(argb), st.fontColor?.toARGB32() == argb, () {
                    _applyFontColor(Color(argb));
                    set(() {});
                  }),
                ActionChip(
                  label: Text(ctx.t('excel.color_auto')),
                  onPressed: () {
                    _applyFontColor(null);
                    set(() {});
                  },
                ),
              ]),
            ],
          );

          final border = ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              section(ctx.t('excel.fc_presets'), [
                for (final (k, icon) in const [
                  ('all', AppIcons.borderAll),
                  ('outline', AppIcons.borderOuter),
                  ('inside', AppIcons.borders),
                  ('top', AppIcons.borderTop),
                  ('bottom', AppIcons.borderBottom),
                  ('left', AppIcons.alignHorizontalLeft),
                  ('right', AppIcons.formatAlignRight),
                  ('thickOutline', AppIcons.borderOuter),
                  ('none', AppIcons.borderClear),
                ])
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
                    child: ActionChip(
                      key: ValueKey('xl-fc-border-$k'),
                      avatar: Icon(icon, size: 18),
                      label: Text(ctx.t('excel.border_$k')),
                      onPressed: () {
                        _applyBorderPreset(k, borderStyle, borderColor);
                        set(() {});
                      },
                    ),
                  ),
              ]),
              section(ctx.t('excel.fc_line'), [
                for (final s in const [
                  'thin', 'medium', 'thick', 'double', 'dashed', 'dotted',
                ])
                  chip(ctx.t('excel.line_$s'), borderStyle == s,
                      () => borderStyle = s,
                      key: ValueKey('xl-fc-line-$s')),
              ]),
              section(ctx.t('excel.fc_line_color'), [
                ActionChip(
                  label: Text(ctx.t('excel.color_auto')),
                  backgroundColor:
                      borderColor == null ? scheme.secondaryContainer : null,
                  onPressed: () => set(() => borderColor = null),
                ),
                for (final argb in _SpreadsheetEditorScreenState._palette)
                  _swatch(ctx, Color(argb), borderColor?.toARGB32() == argb,
                      () => set(() => borderColor = Color(argb))),
              ]),
            ],
          );

          final fill = ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: [
              section(ctx.t('excel.fill_color'), [
                for (final argb in _SpreadsheetEditorScreenState._palette)
                  _swatch(ctx, Color(argb), st.background?.toARGB32() == argb, () {
                    _applyFillColor(Color(argb));
                    set(() {});
                  }),
              ]),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      _applyFillColor(null);
                      set(() {});
                    },
                    icon: const Icon(AppIcons.formatColorReset),
                    label: Text(ctx.t('excel.color_none')),
                  ),
                ),
              ),
            ],
          );

          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.62,
            child: Column(
              children: [
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    for (final k in const [
                      'excel.fc_tab_number',
                      'excel.alignment',
                      'excel.fc_tab_font',
                      'excel.borders',
                      'excel.fc_tab_fill',
                    ])
                      Tab(text: ctx.t(k)),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                      children: [number, align, font, border, fill]),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _swatch(BuildContext ctx, Color c, bool on, VoidCallback tap) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 6, bottom: 6),
        child: InkWell(
          onTap: tap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: c,
              shape: BoxShape.circle,
              border: Border.all(
                  color: on
                      ? Theme.of(ctx).colorScheme.primary
                      : Theme.of(ctx).colorScheme.outlineVariant,
                  width: on ? 3 : 1),
            ),
          ),
        ),
      );

  // ── hücre stilleri / tablo olarak biçimlendir ───────────────────────────

  /// Excel'in yerleşik hücre stillerinin görünüşü (doğrudan biçim olarak
  /// uygulanır — adlandırılmış stil yazılmaz).
  static const _cellStyles = <String, (int?, int?, bool, double?, String?)>{
    // anahtar: (dolgu, yazı rengi, kalın, punto, alt kenarlık)
    'good': (0xFFC6EFCE, 0xFF006100, false, null, null),
    'bad': (0xFFFFC7CE, 0xFF9C0006, false, null, null),
    'neutral': (0xFFFFEB9C, 0xFF9C5700, false, null, null),
    'title': (null, 0xFF44546A, true, 18, null),
    'heading1': (null, 0xFF44546A, true, 15, 'thick'),
    'heading2': (null, 0xFF44546A, true, 13, 'medium'),
    'heading3': (null, 0xFF44546A, true, 11, 'thin'),
    'total': (null, 0xFF000000, true, null, 'double'),
    'note': (0xFFFFFFCC, null, false, null, 'thin'),
    'normal': (null, null, false, 11, null),
  };

  void _applyCellStyle(String key) {
    final sheet = _sheet;
    final editor = _editor;
    final spec = _cellStyles[key];
    if (sheet == null || editor == null || spec == null) return;
    _csvFormatGuard();
    _endEdit();
    final (fill, ink, bold, size, bottom) = spec;
    final range = _range;
    final name = sheet.name;
    final before = <CellRef, XlsxCellStyle>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): sheet.styleAt(r, c) ?? const XlsxCellStyle(),
    };
    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          editor.setCellFill(name, r, c, fill == null ? null : Color(fill));
          editor.setFontColor(name, r, c, ink == null ? null : Color(ink));
          editor.setCellStyle(name, r, c, bold: bold);
          if (size != null) editor.setFontSize(name, r, c, size);
          editor.setCellBorder(name, r, c, {'bottom': bottom});
          if (key == 'total') editor.setCellBorder(name, r, c, {'top': 'thin'});
        }
      }
    }

    applyNow();
    _recordStep('excel.undo_cell_style', applyNow, () {
      before.forEach((at, b) {
        editor.setCellFill(name, at.row, at.col, b.background);
        editor.setFontColor(name, at.row, at.col, b.fontColor);
        editor.setCellStyle(name, at.row, at.col, bold: b.bold);
        editor.setFontSize(name, at.row, at.col, b.fontSize ?? 11);
        editor.setCellBorder(name, at.row, at.col, {
          'bottom': b.border.bottom.visible ? b.border.bottom.style : null,
          'top': b.border.top.visible ? b.border.top.style : null,
        });
      });
    });
    _session.changed();
    _partSetState(() {});
  }

  /// Tablo olarak biçimlendir: başlık satırı (koyu dolgu, beyaz kalın),
  /// bantlı satırlar, ince kenarlık ve otomatik süzgeç — tek adım.
  void _formatAsTable(int accent) {
    final sheet = _sheet;
    final editor = _editor;
    if (sheet == null || editor == null) return;
    final range = _range;
    if (range.bottom <= range.top) {
      _snack(context.t('excel.table_needs_range'));
      return;
    }
    _csvFormatGuard();
    _endEdit();
    final name = sheet.name;
    final band = Color.alphaBlend(Color(accent).withValues(alpha: 0.18),
        AppColors.page);
    final before = <CellRef, XlsxCellStyle>{
      for (var r = range.top; r <= range.bottom; r++)
        for (var c = range.left; c <= range.right; c++)
          CellRef(r, c): sheet.styleAt(r, c) ?? const XlsxCellStyle(),
    };
    final filterBefore = sheet.layout.autoFilterRef;
    final ref = _xlRange.ref;
    void applyNow() {
      for (var r = range.top; r <= range.bottom; r++) {
        for (var c = range.left; c <= range.right; c++) {
          final head = r == range.top;
          final odd = (r - range.top).isOdd;
          editor.setCellFill(name, r, c,
              head ? Color(accent) : (odd ? band : null));
          if (head) {
            editor.setFontColor(name, r, c, AppColors.page);
            editor.setCellStyle(name, r, c, bold: true);
          }
          editor.setCellBorderColored(
              name,
              r,
              c,
              const {'left': 'thin', 'right': 'thin', 'top': 'thin', 'bottom': 'thin'},
              Color(accent));
        }
      }
      editor.setAutoFilter(name, ref);
    }

    applyNow();
    _recordStep('excel.undo_table_format', applyNow, () {
      before.forEach((at, b) {
        editor.setCellFill(name, at.row, at.col, b.background);
        editor.setFontColor(name, at.row, at.col, b.fontColor);
        editor.setCellStyle(name, at.row, at.col, bold: b.bold);
        editor.setCellBorder(name, at.row, at.col, {
          'left': b.border.left.visible ? b.border.left.style : null,
          'right': b.border.right.visible ? b.border.right.style : null,
          'top': b.border.top.visible ? b.border.top.style : null,
          'bottom': b.border.bottom.visible ? b.border.bottom.style : null,
        });
      });
      editor.setAutoFilter(name, filterBefore);
    });
    _session.changed();
    _gridVersion++;
    _partSetState(() {});
  }

  Future<void> _showCellStyles() async {
    _endEdit();
    final picked = await showAppSheet<String>(
      context,
      title: context.t('excel.cell_styles'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final MapEntry(key: k, value: (fill, ink, bold, _, _))
                    in _cellStyles.entries)
                  ActionChip(
                    key: ValueKey('xl-style-$k'),
                    backgroundColor: fill == null ? null : Color(fill),
                    label: Text(ctx.t('excel.style_$k'),
                        style: TextStyle(
                            color: ink == null ? null : Color(ink),
                            fontWeight: bold ? FontWeight.w700 : null)),
                    onPressed: () => Navigator.pop(ctx, k),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(ctx.t('excel.format_as_table'),
                style: Theme.of(ctx).textTheme.labelLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final argb in const [
                  0xFF4472C4, 0xFF70AD47, 0xFFED7D31, 0xFF7030A0, 0xFF595959,
                ])
                  InkWell(
                    key: ValueKey('xl-table-$argb'),
                    onTap: () => Navigator.pop(ctx, 'table:$argb'),
                    child: Column(children: [
                      for (var i = 0; i < 4; i++)
                        Container(
                          width: 48,
                          height: 9,
                          color: i == 0
                              ? Color(argb)
                              : (i.isEven
                                  ? Color(argb).withValues(alpha: 0.2)
                                  : Theme.of(ctx).colorScheme.surface),
                        ),
                    ]),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
    if (picked == null || !mounted) return;
    if (picked.startsWith('table:')) {
      _formatAsTable(int.parse(picked.substring(6)));
    } else {
      _applyCellStyle(picked);
    }
  }
}

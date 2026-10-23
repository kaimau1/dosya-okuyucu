part of '../spreadsheet_editor_screen.dart';

/// Faz 25 — Excel mobil gibi veri girişi (2026-10-23):
/// * hücrenin ÜSTÜNDE açılan, sığmazsa büyüyen yüzer editör (en az 16 sp;
///   eski 30×72 dp eşiği kalktı — 100 % yakınlaştırmada da hücrede yazılır);
/// * iki dokunuş dili: dokun = seç, seçiliye dokun = düzenle (imleç sonda);
///   Enter/⇥/ok ile gelinen hücrede yazmaya başlamak içeriği DEĞİŞTİRİR
///   (metin seçili açılır — Excel'in "Giriş" kipi);
/// * klavye üstü çubuk: ✗ ✓ ← → ↑ ↓ ⇥ ↵ = Σ fx 123/ABC;
/// * uygulama içi sayı/formül tuş takımı (K20) — sayı biçimli hücrede
///   kendiliğinden;
/// * işaret kipi: formül yazarken hücreye dokunmak başvuru ekler, uzun bas +
///   sürükle aralık; başvurular renklenir, ızgarada aynı renkte çerçeve;
///   $ düğmesi (F4) mutlak/göreli döngüsü;
/// * seçim tutamakları (sürükle = genişlet, fırlat = veri kenarı), bağlam
///   menüsü, metin otomatik tamamlama, akıllı giriş, büyüyen ızgara.
extension _SpreadsheetEditorScreenEntryPart on _SpreadsheetEditorScreenState {
  // ── formül dili (K22) ───────────────────────────────────────────────────

  /// Arayüz Türkçe ve "Formülleri İngilizce göster" kapalı: formüller Türkçe
  /// ad + `;` + virgül ondalıkla gösterilir ve girilir; dosyaya İngilizce.
  bool get _turkishFormulas =>
      context.language == AppLanguage.tr && !EditPrefs.formulaEnglish;

  /// Hücrenin formül çubuğunda/editörde GÖRÜNEN hâli.
  String _displayAt(int r, int c) {
    final raw = _valueAt(r, c);
    if (raw.length > 1 && raw.startsWith('=') && _turkishFormulas) {
      return '=${FormulaEngine.toTurkishFormula(raw.substring(1))}';
    }
    return raw;
  }

  /// Girilen metin → modele yazılacak ham değer + verilecek sayı biçimi.
  SmartInput _toModel(String text) {
    if (text.length > 1 && text.startsWith('=')) {
      return SmartInput(_turkishFormulas
          ? '=${FormulaEngine.toFileFormula(text.substring(1), turkish: true)}'
          : text);
    }
    return parseSmartInput(text, turkish: context.language == AppLanguage.tr);
  }

  // ── düzenlemeye giriş / çıkış ────────────────────────────────────────────

  /// Hücrenin sayı tuş takımını mı yoksa harf klavyesini mi istediği (K20):
  /// sayı/para/yüzde/tarih biçimli ya da sayı içeren hücre.
  bool _prefersKeypad(int r, int c) {
    final sheet = _sheet;
    if (sheet == null) return false;
    final raw = sheet.rawAt(r, c);
    if (raw.startsWith('=')) return false;
    if (raw.isNotEmpty && double.tryParse(raw) != null) return true;
    final code = sheet.numFmtCode(r, c).trim();
    if (code.isEmpty || code == 'General' || code == '@') {
      // Boş hücrede: üstündeki hücre sayıysa (sütun sayı sütunudur).
      if (raw.isEmpty && r > 0) {
        final up = sheet.rawAt(r - 1, c);
        return up.isNotEmpty && double.tryParse(up) != null;
      }
      return false;
    }
    return true;
  }

  /// Seçili hücrede düzenlemeyi açar. [caret]: imleç sonda (ikinci dokunuş /
  /// F2); değilse metin seçili açılır, yazmak içeriği değiştirir.
  void _openEditor({required bool caret}) {
    _caretMode = caret;
    _syncField();
    _cellField.selection = caret
        ? TextSelection.collapsed(offset: _cellField.text.length)
        : TextSelection(baseOffset: 0, extentOffset: _cellField.text.length);
    _keypad = _prefersKeypad(_selRow, _selCol);
    _pointSpan = null;
    _partSetState(() => _editing = true);
    if (_keypad) {
      _keypadPanel.open();
    } else if (_keypadPanel.isOpen) {
      _keypadPanel.close();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_editing) return;
      _cellFocus.requestFocus();
      _partSetState(() {}); // yüzer editör hücrenin yeni konumuna otursun
    });
  }

  /// Düzenlemeden vazgeç (✗ / Esc).
  void _cancelEdit() {
    _editing = false;
    _pointSpan = null;
    _syncField();
    _keypadPanel.close();
    _cellFocus.unfocus();
    _partSetState(() {});
  }

  /// Girişi yazar ve seçimi [dr]/[dc] kadar taşır; düzenleme "Giriş"
  /// kipinde sürer (bir sütuna arka arkaya veri girmek).
  void _commitAndMove(int dr, int dc, {bool keepEditing = true}) {
    final sheet = _sheet;
    if (sheet == null) return;
    final wasEditing = _editing;
    _endEdit();
    var r = _selRow + dr, c = _selCol + dc;
    if (dc != 0) {
      _tabStartCol ??= _selCol;
    } else if (dr != 0 && _tabStartCol != null) {
      // ⇥ ile girilen satırda Enter satırın başındaki sütuna döner (Excel).
      c = _tabStartCol!;
      _tabStartCol = null;
    }
    r = math.max(0, r);
    c = c.clamp(0, _SpreadsheetEditorScreenState._maxCols - 1);
    _growTo(r, c);
    _jumpTo(r, c);
    if (keepEditing && wasEditing) _openEditor(caret: false);
  }

  /// Izgara sınırsız hissi (madde 12): kenara yaklaşınca büyür.
  void _growTo(int r, int c) {
    final sheet = _sheet;
    if (sheet == null) return;
    if (r >= _rowCount(sheet) - 5) _extraRows += 100;
    if (c >= _colCount(sheet) - 3) _extraCols += 26;
  }

  // ── klavye üstü çubuk + tuş takımı ──────────────────────────────────────

  Widget _excelAccessory() => KeyboardAccessoryBar(
        key: const ValueKey('excel-accessory'),
        items: [
          AccessoryItem(
              key: const ValueKey('acc-cancel'),
              icon: AppIcons.close,
              tooltip: context.t('common.cancel'),
              onPressed: _cancelEdit),
          AccessoryItem(
              key: const ValueKey('acc-ok'),
              icon: AppIcons.check,
              tooltip: context.t('common.apply'),
              onPressed: _acceptEntry),
          for (final (k, icon, dr, dc) in [
            ('left', AppIcons.keyboardArrowLeft, 0, -1),
            ('right', AppIcons.keyboardArrowRight, 0, 1),
            ('up', AppIcons.keyboardArrowUp, -1, 0),
            ('down', AppIcons.keyboardArrowDown, 1, 0),
          ])
            AccessoryItem(
                key: ValueKey('acc-$k'),
                icon: icon,
                tooltip: context.t('excel.move_$k'),
                onPressed: () => _arrow(dr, dc)),
          AccessoryItem(
              key: const ValueKey('acc-tab'),
              icon: AppIcons.keyboardTab,
              tooltip: context.t('excel.key_tab'),
              onPressed: () => _commitAndMove(0, 1)),
          AccessoryItem(
              key: const ValueKey('acc-enter'),
              icon: AppIcons.keyboardReturn,
              tooltip: context.t('excel.key_enter'),
              onPressed: () => _commitAndMove(1, 0)),
          AccessoryItem(
              text: '=',
              tooltip: context.t('excel.start_formula'),
              onPressed: () => _insertText('=')),
          AccessoryItem(
              icon: OfficeIcons.autoSum,
              tooltip: context.t('excel.autosum'),
              onPressed: () {
                _cancelEdit();
                _autoSum();
              }),
          AccessoryItem(
              key: const ValueKey('acc-fx'),
              text: 'fx',
              tooltip: context.t('excel.fx_library'),
              onPressed: _showFunctionLibrary),
          AccessoryItem(
              key: const ValueKey('acc-keypad'),
              text: _keypad ? 'ABC' : '123',
              tooltip: context.t(_keypad ? 'excel.keyboard_abc' : 'excel.keyboard_123'),
              onPressed: _toggleKeypad),
        ],
      );

  /// ✓: girişi yazar, seçim yerinde kalır, düzenleme kapanır.
  void _acceptEntry() {
    final completion = _textCompletion();
    if (completion != null) _cellField.text = completion;
    _endEdit();
    _keypadPanel.close();
    _cellFocus.unfocus();
    _partSetState(() {});
  }

  /// Oklar: düzenlemede ve imleç kipindeyse imleci metinde gezdirir;
  /// değilse girişi yazıp seçimi taşır.
  void _arrow(int dr, int dc) {
    if (_editing && _caretMode && dc != 0) {
      final sel = _cellField.selection;
      final at = (sel.isValid ? sel.extentOffset : _cellField.text.length) + dc;
      _cellField.selection = TextSelection.collapsed(
          offset: at.clamp(0, _cellField.text.length));
      return;
    }
    _tabStartCol = null;
    if (_editing) {
      _commitAndMove(dr, dc);
    } else {
      _jumpTo(math.max(0, _selRow + dr),
          (_selCol + dc).clamp(0, _SpreadsheetEditorScreenState._maxCols - 1));
    }
  }

  void _toggleKeypad() {
    if (_keypad) {
      _partSetState(() => _keypad = false);
      _keypadPanel.close(showKeyboard: true);
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _cellFocus.requestFocus());
    } else {
      _partSetState(() => _keypad = true);
      _keypadPanel.open();
    }
  }

  /// Uygulama içi tuş takımı (K20) — klavye yüksekliğinde panelde.
  Widget _keypadGrid() {
    final dec = context.language == AppLanguage.tr ? ',' : '.';
    final sep = _turkishFormulas ? ';' : ',';
    final rows = <List<(String, String)>>[
      [('7', '7'), ('8', '8'), ('9', '9'), ('+', '+'), ('−', '-'), ('(', '('), (')', ')'), ('⌫', 'bs')],
      [('4', '4'), ('5', '5'), ('6', '6'), ('×', '*'), ('÷', '/'), (sep, sep), (':', ':'), (r'$', 'abs')],
      [('1', '1'), ('2', '2'), ('3', '3'), ('%', '%'), ('^', '^'), ('=', '='), ('&', '&'), ('↵', 'enter')],
      [('0', '0'), (dec, dec), ('<', '<'), ('>', '>'), ('"', '"'), ('←', 'left'), ('→', 'right'), ('⇥', 'tab')],
    ];
    final scheme = Theme.of(context).colorScheme;
    return Column(
      key: const ValueKey('excel-keypad'),
      children: [
        for (final row in rows)
          Row(
            children: [
              for (final (label, action) in row)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Material(
                      color: RegExp(r'^\d$').hasMatch(label)
                          ? scheme.surface
                          : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        key: ValueKey('key-$action'),
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => _keypadKey(action),
                        child: SizedBox(
                          height: 44,
                          child: Center(
                            // ⌫ ↵ ⇥ ← → her yazı tipinde yok: ikon.
                            child: switch (action) {
                              'bs' => const Icon(AppIcons.backspace, size: 20),
                              'enter' => const Icon(AppIcons.keyboardReturn, size: 20),
                              'tab' => const Icon(AppIcons.keyboardTab, size: 20),
                              'left' => const Icon(AppIcons.keyboardArrowLeft, size: 22),
                              'right' => const Icon(AppIcons.keyboardArrowRight, size: 22),
                              _ => Text(label,
                                  style: context.type.body
                                      .copyWith(fontWeight: FontWeight.w600)),
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  void _keypadKey(String action) {
    switch (action) {
      case 'bs':
        final sel = _cellField.selection;
        final t = _cellField.text;
        if (!sel.isValid) return;
        if (!sel.isCollapsed) {
          _replaceSelection('');
        } else if (sel.start > 0) {
          _cellField.value = TextEditingValue(
            text: t.replaceRange(sel.start - 1, sel.start, ''),
            selection: TextSelection.collapsed(offset: sel.start - 1),
          );
        }
        _partSetState(() {});
      case 'enter':
        _commitAndMove(1, 0);
      case 'tab':
        _commitAndMove(0, 1);
      case 'left':
        _arrow(0, -1);
      case 'right':
        _arrow(0, 1);
      case 'abs':
        _toggleAbsolute();
      default:
        _insertText(action);
    }
  }

  /// İmlece metin koyar (seçim varsa yerine).
  void _insertText(String s) {
    if (!_editing) _openEditor(caret: true);
    _replaceSelection(s);
    _partSetState(() {});
  }

  void _replaceSelection(String s) {
    final t = _cellField.text;
    final sel = _cellField.selection;
    final a = sel.isValid ? sel.start : t.length;
    final b = sel.isValid ? sel.end : t.length;
    _cellField.value = TextEditingValue(
      text: t.replaceRange(a, b, s),
      selection: TextSelection.collapsed(offset: a + s.length),
    );
    _caretMode = true;
  }

  /// $ (F4): imleçteki başvurunun mutlak/göreli döngüsü.
  void _toggleAbsolute() {
    final sel = _cellField.selection;
    final at = sel.isValid ? sel.extentOffset : _cellField.text.length;
    final r = cycleAbsolute(_cellField.text, at);
    if (r == null) {
      _insertText(r'$');
      return;
    }
    _cellField.value = TextEditingValue(
        text: r.$1, selection: TextSelection.collapsed(offset: r.$2));
    _pointSpan = null;
    _partSetState(() {});
  }

  // ── işaret kipi (madde 5) ────────────────────────────────────────────────

  /// Formül yazılırken imleç bir başvuru BEKLEYEN yerde mi (`=`, `(`, `;`,
  /// işleç sonrası) ya da az önce işaretle eklenen başvurunun sonunda mı.
  bool _pointInsertable() {
    final t = _cellField.text;
    if (!_editing || !t.startsWith('=')) return false;
    final sel = _cellField.selection;
    final at = sel.isValid ? sel.extentOffset : t.length;
    final span = _pointSpan;
    if (span != null && at == span.$2) return true;
    if (at <= 0) return false;
    var k = at - 1;
    while (k > 0 && t[k] == ' ') {
      k--;
    }
    return '=(;,+-*/^&<>:'.contains(t[k]);
  }

  String _refText(int r1, int c1, int r2, int c2) {
    final a = '${XlsxRange.colName(math.min(c1, c2))}${math.min(r1, r2) + 1}';
    if (r1 == r2 && c1 == c2) return a;
    return '$a:${XlsxRange.colName(math.max(c1, c2))}${math.max(r1, r2) + 1}';
  }

  /// Başvuruyu imlece koyar; bir öncekinin hemen ardından dokunulduysa onun
  /// YERİNE (Excel: başka hücreye dokunmak başvuruyu değiştirir).
  void _insertPointRef(int r1, int c1, [int? r2, int? c2]) {
    final ref = _refText(r1, c1, r2 ?? r1, c2 ?? c1);
    final t = _cellField.text;
    final sel = _cellField.selection;
    var at = sel.isValid ? sel.extentOffset : t.length;
    var from = at;
    final span = _pointSpan;
    if (span != null && at == span.$2) from = span.$1;
    final next = t.replaceRange(from, at, ref);
    at = from + ref.length;
    _cellField.value = TextEditingValue(
        text: next, selection: TextSelection.collapsed(offset: at));
    _pointSpan = (from, at);
    _caretMode = true;
    _partSetState(() {});
  }

  /// Formüldeki başvurular + renkleri (ızgarada çerçeve).
  List<(XlsxRange, Color)> _formulaRefColors() {
    final t = _cellField.text;
    if (!_editing || !t.startsWith('=')) return const [];
    final name = _sheet?.name;
    final out = <(XlsxRange, Color)>[];
    var k = 0;
    for (final r in formulaRefs(t)) {
      final color = _refPalette[k++ % _refPalette.length];
      if (r.sheet != null && r.sheet!.toLowerCase() != name?.toLowerCase()) {
        continue;
      }
      out.add((r.range, color));
    }
    return out;
  }

  static const _refPalette = [
    AppHues.blue,
    AppHues.red,
    AppHues.purple,
    AppHues.green,
    AppHues.orange,
    AppHues.teal,
  ];

  // ── yüzer hücre editörü (madde 1) ────────────────────────────────────────

  Rect? _rectOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject();
    final stack = _overlayKey.currentContext?.findRenderObject();
    if (box is! RenderBox || stack is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !stack.hasSize) return null;
    final o = box.localToGlobal(Offset.zero, ancestor: stack);
    return o & box.size;
  }

  Widget _floatingEditor(BoxConstraints area) {
    return AnimatedBuilder(
      animation: Listenable.merge([_hBody, _vBody, _cellField]),
      builder: (context, _) {
        final rect = _rectOf(_cursorKey);
        final sheet = _sheet;
        if (rect == null || sheet == null) return const SizedBox.shrink();
        final style = sheet.styleAt(_selRow, _selCol);
        final base = SheetCell.metricsStyle(style, numeric: false, zoom: _zoom);
        final size = math.max(16.0, base.fontSize ?? 16);
        final textStyle = base.copyWith(
            fontSize: size, color: Theme.of(context).colorScheme.onSurface);
        final measure = TextPainter(
          text: TextSpan(text: '${_cellField.text}  ', style: textStyle),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
        final maxW = math.max(rect.width, area.maxWidth - rect.left - 8);
        final w = (measure.width + 16).clamp(rect.width, maxW).toDouble();
        final multi = _cellField.text.contains('\n') || (style?.wrap ?? false);
        final h = math.max(rect.height, size * 1.35 + 10);
        final scheme = Theme.of(context).colorScheme;
        return Positioned(
          left: rect.left,
          top: rect.top,
          child: Material(
            key: const ValueKey('floating-cell-editor'),
            elevation: 4,
            color: scheme.surface,
            shape: const RoundedRectangleBorder(
              side: BorderSide(color: OfficeColors.excel, width: 2),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                  minWidth: w, maxWidth: w, minHeight: h, maxHeight: multi ? h * 4 : h),
              child: TextField(
                controller: _cellField,
                focusNode: _cellFocus,
                style: textStyle,
                keyboardType: _keypad
                    ? TextInputType.none
                    : (_prefersKeypad(_selRow, _selCol)
                        ? const TextInputType.numberWithOptions(
                            decimal: true, signed: true)
                        : TextInputType.text),
                textInputAction: TextInputAction.next,
                maxLines: multi ? 4 : 1,
                minLines: 1,
                onChanged: (_) {
                  _pointSpan = null;
                  _caretMode = true;
                  _partSetState(() {});
                },
                onSubmitted: (_) => _commitAndMove(1, 0),
                decoration: const InputDecoration(
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

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

/// Seçim tutamağı sürüklemesi (fırlatma hızıyla).
class _HandleDrag extends Drag {
  final void Function(Offset global) onMove;
  final void Function(Velocity v) onFling;
  _HandleDrag({required this.onMove, required this.onFling});

  @override
  void update(DragUpdateDetails details) => onMove(details.globalPosition);

  @override
  void end(DragEndDetails details) => onFling(details.velocity);
}

/// Formül metnindeki başvuruları renklendiren denetleyici (Excel'in renkli
/// başvuruları; ızgaradaki çerçevelerle aynı sıra ve renk).
class _FormulaFieldController extends TextEditingController {
  @override
  TextSpan buildTextSpan(
      {required BuildContext context,
      TextStyle? style,
      required bool withComposing}) {
    final t = text;
    if (!t.startsWith('=') || (withComposing && value.composing.isValid)) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final refs = formulaRefs(t);
    if (refs.isEmpty) {
      return super.buildTextSpan(
          context: context, style: style, withComposing: withComposing);
    }
    final kids = <TextSpan>[];
    var at = 0;
    var k = 0;
    for (final r in refs) {
      if (r.start > at) kids.add(TextSpan(text: t.substring(at, r.start)));
      final color = _SpreadsheetEditorScreenEntryPart
          ._refPalette[k++ % _SpreadsheetEditorScreenEntryPart._refPalette.length];
      kids.add(TextSpan(
          text: t.substring(r.start, r.end),
          style: TextStyle(color: color, fontWeight: FontWeight.w700)));
      at = r.end;
    }
    if (at < t.length) kids.add(TextSpan(text: t.substring(at)));
    return TextSpan(style: style, children: kids);
  }
}

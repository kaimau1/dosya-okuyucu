part of '../spreadsheet_editor_screen.dart';

/// **Donanım klavyesiyle ızgara** (Faz 33 / madde 2): tablet, DeX, Bluetooth
/// klavye. Excel masaüstündeki el alışkanlıkları:
/// ok = hücre · ⇧+ok = aralık · Ctrl+ok = veri kenarı · Ctrl+⇧+ok = kenara
/// kadar seç · ⇥ / ⇧⇥ = sağ/sol · ↵ / ⇧↵ = alt/üst · F2 = hücrede düzenle ·
/// Delete / ⌫ = içeriği sil · Home = satır başı · Ctrl+Home = A1 ·
/// PageUp/PageDown = 20 satır · basılan harf = hücreye yazmaya başla.
///
/// Izgara kendi odağını taşır; hücre editörü ya da formül çubuğu açıkken
/// tuşlar onların (oklar imleci yürütür, ⇥/↵ zaten editörde bağlı).
extension _SpreadsheetKeyboardPart on _SpreadsheetEditorScreenState {
  Widget _keyboardGrid(Widget child) => Semantics(
        label: context.t('excel.grid_label'),
        child: Focus(
          focusNode: _gridFocus,
          autofocus: true,
          onKeyEvent: (_, e) => _onGridKey(e),
          child: child,
        ),
      );

  /// Düzenleme bitince odak ızgaraya döner (yoksa sonraki ok tuşu kaybolur).
  void _refocusGridAfterEdit() {
    if (!mounted || _editing || _cellFocus.hasFocus || _barFocus.hasFocus) {
      return;
    }
    final primary = FocusManager.instance.primaryFocus;
    if (primary == null || primary is FocusScopeNode) {
      _gridFocus.requestFocus();
    }
  }

  KeyEventResult _onGridKey(KeyEvent e) {
    if (e is KeyUpEvent) return KeyEventResult.ignored;
    if (_editing || _sheet == null || !_gridFocus.hasFocus) {
      return KeyEventResult.ignored;
    }
    // Izgaranın içindeki bir metin alanı (ör. grafik başlığı) tuşları kendi
    // işler; yalnız metin olmayan odaklar ızgaraya düşer.
    final primary = FocusManager.instance.primaryFocus?.context?.widget;
    if (primary is EditableText) return KeyEventResult.ignored;
    final hw = HardwareKeyboard.instance;
    final shift = hw.isShiftPressed;
    final ctrl = hw.isControlPressed || hw.isMetaPressed;
    final k = e.logicalKey;
    final dir = switch (k) {
      LogicalKeyboardKey.arrowUp => (-1, 0),
      LogicalKeyboardKey.arrowDown => (1, 0),
      LogicalKeyboardKey.arrowLeft => (0, (_sheet?.rightToLeft ?? false) ? 1 : -1),
      LogicalKeyboardKey.arrowRight => (0, (_sheet?.rightToLeft ?? false) ? -1 : 1),
      _ => null,
    };
    if (dir != null) {
      _keyMove(dir.$1, dir.$2, extend: shift, toEdge: ctrl);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.pageDown || k == LogicalKeyboardKey.pageUp) {
      _keyMove(k == LogicalKeyboardKey.pageDown ? 20 : -20, 0, extend: shift);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.home) {
      if (ctrl) {
        _jumpTo(0, 0);
      } else {
        _jumpTo(_selRow, 0);
      }
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.tab) {
      _commitAndMove(0, shift ? -1 : 1, keepEditing: false);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.enter || k == LogicalKeyboardKey.numpadEnter) {
      _commitAndMove(shift ? -1 : 1, 0, keepEditing: false);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.f2) {
      _beginEdit(_selRow, _selCol);
      return KeyEventResult.handled;
    }
    if (k == LogicalKeyboardKey.delete || k == LogicalKeyboardKey.backspace) {
      _clearSelection();
      return KeyEventResult.handled;
    }
    // Yazmaya başla: hücrenin içeriği basılan harfle DEĞİŞİR (Excel'in
    // "Giriş" kipi).
    final ch = e.character;
    if (!ctrl &&
        ch != null &&
        ch.length == 1 &&
        ch.codeUnitAt(0) >= 0x20 &&
        ch.codeUnitAt(0) != 0x7f) {
      _openEditor(caret: false);
      _cellField.value = TextEditingValue(
          text: ch, selection: TextSelection.collapsed(offset: ch.length));
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Seçimi taşır ya da (⇧) genişletir; Ctrl ile verinin kenarına.
  void _keyMove(int dr, int dc, {bool extend = false, bool toEdge = false}) {
    var (r, c) = toEdge
        ? _dataEdge(_selRow, _selCol, dr.sign, dc.sign)
        : (_selRow + dr, _selCol + dc);
    r = math.max(0, r);
    c = c.clamp(0, _SpreadsheetEditorScreenState._maxCols - 1);
    _growTo(r, c);
    if (extend) {
      _partSetState(() {
        _selRow = r;
        _selCol = c;
      });
      _syncField();
      _ensureVisible(r, c);
    } else {
      _jumpTo(r, c);
    }
  }
}

part of 'docx_edit_controller.dart';

extension DocxEditKeys on DocxEditController {
  // ── donanım klavyesi ─────────────────────────────────────────────────────

  /// Geri silme tuşu (yazılım klavyesinin KEYCODE_DEL'i de buraya gelir).
  ///
  /// Android motoru DEL tuş olayını editable'a UYGULAMAZ; normal metin
  /// alanında bunu `EditableText`'in `DeleteCharacterIntent` eylemi yapar.
  /// Kendi istemcimizde işlenmezse yazma çalışır ama silme düşer.
  void deleteBackward() {
    if (!collapsed) return deleteSelection();
    final i = extent.para, at = extent.offset;
    if (paras[i].opaque) return;
    if (at == 0) {
      mergeWithPrevious(i, notify: false);
    } else {
      final t = paras[i].text;
      final n = at >= 2 && _isLow(t.codeUnitAt(at - 1)) &&
              _isHigh(t.codeUnitAt(at - 2))
          ? 2
          : 1;
      _lastTyping = false;
      _replace(i, at - n, at, '');
      composing = TextRange.empty;
    }
    _changed(notify: true);
    _syncIme();
  }

  /// İleri silme (Delete): paragraf sonunda sonrakini buna katar.
  void deleteForward() {
    if (!collapsed) return deleteSelection();
    final i = extent.para, at = extent.offset;
    final p = paras[i];
    if (p.opaque) return;
    if (at >= p.length) {
      if (i + 1 >= paras.length) return;
      final next = paras[i + 1];
      if (next.opaque || !identical(next.container, p.container)) return;
      _record(typing: false);
      doc.paras[i] = p.join(next);
      doc.paras.removeAt(i + 1);
      base = extent = DocPos(i, at);
      structure++;
    } else {
      final n = at + 1 < p.length && _isHigh(p.text.codeUnitAt(at)) &&
              _isLow(p.text.codeUnitAt(at + 1))
          ? 2
          : 1;
      _lastTyping = false;
      _replace(i, at, at + n, '');
    }
    composing = TextRange.empty;
    _changed(notify: true);
    _syncIme();
  }

  static bool _isHigh(int u) => u >= 0xD800 && u <= 0xDBFF;
  static bool _isLow(int u) => u >= 0xDC00 && u <= 0xDFFF;

  /// Ok tuşları paragraf sınırını aşar (IME paragraf içinde kalır);
  /// Geri sil / Sil tuşları modelde uygulanır.
  bool handleKey(KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return false;
    if (e.logicalKey == LogicalKeyboardKey.backspace) {
      deleteBackward();
      return true;
    }
    if (e.logicalKey == LogicalKeyboardKey.delete) {
      deleteForward();
      return true;
    }
    final shift = HardwareKeyboard.instance.isShiftPressed;
    DocPos? to;
    final x = extent;
    if (e.logicalKey == LogicalKeyboardKey.arrowLeft && x.offset == 0 && x.para > 0) {
      to = DocPos(x.para - 1, paras[x.para - 1].length);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowRight &&
        x.offset >= paras[x.para].length &&
        x.para < paras.length - 1) {
      to = DocPos(x.para + 1, 0);
    } else if (e.logicalKey == LogicalKeyboardKey.arrowUp && x.para > 0) {
      to = DocPos(x.para - 1, x.offset.clamp(0, paras[x.para - 1].length));
    } else if (e.logicalKey == LogicalKeyboardKey.arrowDown &&
        x.para < paras.length - 1) {
      to = DocPos(x.para + 1, x.offset.clamp(0, paras[x.para + 1].length));
    }
    if (to == null) return false;
    select(shift ? base : to, to);
    return true;
  }
}

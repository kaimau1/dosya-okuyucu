/// Kod düzenleme yardımcıları (Faz 30): Enter'da girinti koruma, parantez/
/// tırnak otomatik kapatma, Tab ile (çok satırlı) girinti, parantez eşleme.
/// Hepsi saf işlev — `TextEditingValue` alır, yenisini verir.
library;

import 'package:flutter/services.dart';

/// Girinti birimi: [width] boşluk.
String indentUnit(int width) => ' ' * width;

/// [pos]'u içeren satırın başlangıç indeksi (`lastIndexOf(-1)` atar).
int lineStartOf(String text, int pos) =>
    pos <= 0 ? 0 : text.lastIndexOf('\n', pos - 1) + 1;

const _pairs = {'(': ')', '[': ']', '{': '}', '"': '"', "'": "'", '`': '`'};
const _closers = {')', ']', '}'};

bool _isWord(String ch) => RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(ch);

/// Yazarken uygulanan düzenleme kuralları: tek karakter eklenmişse
/// (yapıştırma, silme, IME birleştirmesi değilse) ilgili kuralı çalıştırır.
class CodeInputFormatter extends TextInputFormatter {
  /// Satır başı girintisi (boşluk sayısı).
  final int indentWidth;

  /// `() [] {} "" ''` otomatik kapatma.
  final bool autoClose;

  /// Python/YAML gibi `:` sonrası girinti artırılsın mı.
  final bool colonIndent;

  const CodeInputFormatter({
    this.indentWidth = 2,
    this.autoClose = true,
    this.colonIndent = false,
  });

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    // IME birleştirme sürerken (Türkçe/öneri) dokunma.
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    if (!oldValue.selection.isValid || !oldValue.selection.isCollapsed) {
      return newValue;
    }
    final pos = oldValue.selection.start;
    final o = oldValue.text;
    final nw = newValue.text;
    // Tek karakter eklendi mi? (konum = eski imleç)
    if (nw.length == o.length + 1 &&
        nw.startsWith(o.substring(0, pos)) &&
        nw.endsWith(o.substring(pos)) &&
        newValue.selection.isCollapsed &&
        newValue.selection.start == pos + 1) {
      final ch = nw[pos];
      if (ch == '\n') return _onEnter(o, pos);
      if (autoClose) {
        final r = _onTyped(o, pos, ch);
        if (r != null) return r;
      }
      return newValue;
    }
    // Tek karakter silindi (geri sil) ve imleç `()` ortasında mıydı?
    if (autoClose &&
        nw.length == o.length - 1 &&
        pos > 0 &&
        pos < o.length &&
        _pairs[o[pos - 1]] == o[pos] &&
        nw == o.substring(0, pos - 1) + o.substring(pos)) {
      final t = o.substring(0, pos - 1) + o.substring(pos + 1);
      return TextEditingValue(
          text: t, selection: TextSelection.collapsed(offset: pos - 1));
    }
    return newValue;
  }

  TextEditingValue _onEnter(String o, int pos) {
    final lineStart = lineStartOf(o, pos);
    final prefix = o.substring(lineStart, pos);
    final lead = RegExp(r'^[ \t]*').stringMatch(prefix) ?? '';
    final before = prefix.trimRight();
    final lastCh = before.isEmpty ? '' : before[before.length - 1];
    final opens = lastCh == '{' ||
        lastCh == '[' ||
        lastCh == '(' ||
        (colonIndent && lastCh == ':');
    final extra = opens ? indentUnit(indentWidth) : '';
    final next = pos < o.length ? o[pos] : '';
    // `{|}` arasında Enter: iki satır aç, imleç ortada.
    if (opens && _pairs[lastCh] == next) {
      final ins = '\n$lead$extra\n$lead';
      final t = o.substring(0, pos) + ins + o.substring(pos);
      return TextEditingValue(
          text: t,
          selection: TextSelection.collapsed(
              offset: pos + 1 + lead.length + extra.length));
    }
    final ins = '\n$lead$extra';
    final t = o.substring(0, pos) + ins + o.substring(pos);
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: pos + ins.length));
  }

  TextEditingValue? _onTyped(String o, int pos, String ch) {
    final next = pos < o.length ? o[pos] : '';
    // Kapatıcıyı yazınca zaten oradaysa üzerinden atla.
    if ((_closers.contains(ch) || ch == '"' || ch == "'" || ch == '`') &&
        next == ch) {
      return TextEditingValue(
          text: o, selection: TextSelection.collapsed(offset: pos + 1));
    }
    final close = _pairs[ch];
    if (close == null) return null;
    final isQuote = ch == '"' || ch == "'" || ch == '`';
    if (isQuote) {
      // Kelime içinde (don't) ya da kelimenin ardından kapatma.
      final prev = pos > 0 ? o[pos - 1] : '';
      if (prev.isNotEmpty && _isWord(prev)) return null;
    }
    // Sonrası kelimeyse kapatma (var olan metni sarmayalım).
    if (next.isNotEmpty && _isWord(next)) return null;
    final t = o.substring(0, pos) + ch + close + o.substring(pos);
    return TextEditingValue(
        text: t, selection: TextSelection.collapsed(offset: pos + 1));
  }
}

/// Tab: seçim yoksa girinti birimi ekler; çok satırlı seçimde her satırın
/// başına ekler.
TextEditingValue indentSelection(TextEditingValue v, int width) {
  final unit = indentUnit(width);
  final sel = v.selection;
  if (!sel.isValid) return v;
  final text = v.text;
  if (sel.isCollapsed) {
    final t = text.replaceRange(sel.start, sel.end, unit);
    return TextEditingValue(
        text: t,
        selection: TextSelection.collapsed(offset: sel.start + unit.length));
  }
  final first = lineStartOf(text, sel.start);
  var end = sel.end;
  if (end > sel.start && end > 0 && text[end - 1] == '\n') end--;
  final block = text.substring(first, end);
  final lines = block.split('\n');
  final nb = lines.map((l) => l.isEmpty ? l : unit + l).join('\n');
  final t = text.replaceRange(first, end, nb);
  final added = nb.length - block.length;
  return TextEditingValue(
      text: t,
      selection: TextSelection(
          baseOffset: sel.start + (lines.first.isEmpty ? 0 : unit.length),
          extentOffset: sel.end + added));
}

/// Shift+Tab: satır başından en çok [width] boşluk (ya da bir sekme) siler.
TextEditingValue outdentSelection(TextEditingValue v, int width) {
  final sel = v.selection;
  if (!sel.isValid) return v;
  final text = v.text;
  final first = lineStartOf(text, sel.start);
  var end = sel.end;
  if (end > sel.start && end > 0 && text[end - 1] == '\n') end--;
  final block = text.substring(first, end);
  var removedFirst = 0;
  var removedTotal = 0;
  final lines = block.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    var k = 0;
    while (k < width && k < l.length && l[k] == ' ') {
      k++;
    }
    if (k == 0 && l.isNotEmpty && l[0] == '\t') k = 1;
    lines[i] = l.substring(k);
    removedTotal += k;
    if (i == 0) removedFirst = k;
  }
  final nb = lines.join('\n');
  final t = text.replaceRange(first, end, nb);
  int clamp(int x) => x < 0 ? 0 : (x > t.length ? t.length : x);
  return TextEditingValue(
      text: t,
      selection: TextSelection(
          baseOffset: clamp(sel.start - removedFirst < first
              ? first
              : sel.start - removedFirst),
          extentOffset: clamp(sel.end - removedTotal)));
}

/// İmleç konumuna [text] ekler (seçim varsa yerini alır). [cursorBack]:
/// eklemeden sonra imleç sondan bu kadar geri (örn. `{}` yazıp ortaya).
TextEditingValue insertAtCursor(TextEditingValue v, String text,
    {int cursorBack = 0}) {
  var sel = v.selection;
  if (!sel.isValid) sel = TextSelection.collapsed(offset: v.text.length);
  final t = v.text.replaceRange(sel.start, sel.end, text);
  return TextEditingValue(
      text: t,
      selection: TextSelection.collapsed(
          offset: sel.start + text.length - cursorBack));
}

/// İmleci [delta] karakter kaydırır (sınırda durur).
TextEditingValue moveCursor(TextEditingValue v, int delta) {
  final sel = v.selection;
  if (!sel.isValid) return v;
  final o = (sel.extentOffset + delta).clamp(0, v.text.length);
  return v.copyWith(selection: TextSelection.collapsed(offset: o));
}

/// İmlecin yanındaki parantezin eşi. Dönen çift `(imleç yanı, eş)`; yoksa
/// null. Tarama [maxScan] karakterle sınırlı (dev dosyada tuş başına maliyet).
(int, int)? matchBracket(String text, int caret, {int maxScan = 20000}) {
  const open = '([{';
  const close = ')]}';
  int at = -1;
  if (caret > 0 && caret <= text.length && '$open$close'.contains(text[caret - 1])) {
    at = caret - 1;
  } else if (caret >= 0 &&
      caret < text.length &&
      '$open$close'.contains(text[caret])) {
    at = caret;
  }
  if (at < 0) return null;
  final ch = text[at];
  final isOpen = open.contains(ch);
  final want = isOpen ? close[open.indexOf(ch)] : open[close.indexOf(ch)];
  var depth = 0;
  final step = isOpen ? 1 : -1;
  var i = at;
  var scanned = 0;
  while (i >= 0 && i < text.length && scanned < maxScan) {
    final c = text[i];
    if (c == ch) {
      depth++;
    } else if (c == want) {
      depth--;
      if (depth == 0) return (at, i);
    }
    i += step;
    scanned++;
  }
  return null;
}

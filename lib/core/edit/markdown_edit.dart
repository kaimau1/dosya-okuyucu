/// Markdown araç çubuğunun işlevleri (Faz 30) — saf, `TextEditingValue` →
/// `TextEditingValue`. Seçili metni sarar, satır başına önek koyar ya da
/// şablon ekler; ikinci kez uygulanınca geri alır (aç/kapa).
library;

import 'package:flutter/services.dart';

import 'code_editing.dart' show lineStartOf;

/// Seçimi [open]/[close] ile sarar; zaten sarılıysa kaldırır. Seçim yoksa
/// `open+close` ekler ve imleci ortaya koyar.
TextEditingValue mdWrap(TextEditingValue v, String open, [String? close]) {
  close ??= open;
  final raw = _sel(v);
  // Çok satırlı seçim: Markdown kalın/eğik satır aşmaz → her satır ayrı
  // sarılır, satır başı öneki (`## `, `- [ ] `) dışarıda kalır (2026-11-12:
  // `**## başlık … sonucu**` gibi biçim yerine ham işaret kalıyordu).
  if (raw.start != raw.end && v.text.substring(raw.start, raw.end).contains('\n')) {
    return _wrapLines(v, raw, open, close);
  }
  final sel = _trimSel(v.text, raw);
  final t = v.text;
  final inner = t.substring(sel.start, sel.end);
  // Seçimin hemen çevresi zaten sarılmış mı? (`**kalın**` içinde seçili)
  final hasBefore = sel.start >= open.length &&
      t.substring(sel.start - open.length, sel.start) == open;
  final hasAfter = sel.end + close.length <= t.length &&
      t.substring(sel.end, sel.end + close.length) == close;
  if (hasBefore && hasAfter && open.isNotEmpty) {
    final nt = t.substring(0, sel.start - open.length) +
        inner +
        t.substring(sel.end + close.length);
    return TextEditingValue(
        text: nt,
        selection: TextSelection(
            baseOffset: sel.start - open.length,
            extentOffset: sel.end - open.length));
  }
  if (inner.startsWith(open) &&
      inner.endsWith(close) &&
      inner.length >= open.length + close.length) {
    final stripped =
        inner.substring(open.length, inner.length - close.length);
    return TextEditingValue(
        text: t.replaceRange(sel.start, sel.end, stripped),
        selection: TextSelection(
            baseOffset: sel.start, extentOffset: sel.start + stripped.length));
  }
  final nt = t.replaceRange(sel.start, sel.end, '$open$inner$close');
  if (inner.isEmpty) {
    return TextEditingValue(
        text: nt,
        selection: TextSelection.collapsed(offset: sel.start + open.length));
  }
  return TextEditingValue(
      text: nt,
      selection: TextSelection(
          baseOffset: sel.start + open.length,
          extentOffset: sel.start + open.length + inner.length));
}

/// Seçimi satır öneki ve kenar boşluklarından arındırır (`**` boşlukla
/// başlarsa Markdown onu kalın saymaz).
TextSelection _trimSel(String t, TextSelection s) {
  if (s.isCollapsed) return s;
  var a = s.start, b = s.end;
  final ls = lineStartOf(t, a);
  if (a == ls) {
    final m = _linePrefix.firstMatch(t.substring(ls));
    if (m != null && ls + m.end <= b) a = ls + m.end;
  }
  while (a < b && (t[a] == ' ' || t[a] == '\t')) {
    a++;
  }
  while (b > a && (t[b - 1] == ' ' || t[b - 1] == '\t')) {
    b--;
  }
  return a == b ? s : TextSelection(baseOffset: a, extentOffset: b);
}

TextEditingValue _wrapLines(
    TextEditingValue v, TextSelection sel, String open, String close) {
  final t = v.text;
  final first = lineStartOf(t, sel.start);
  var lineEnd = t.indexOf('\n', sel.end > sel.start && t[sel.end - 1] == '\n' ? sel.end - 1 : sel.end);
  if (lineEnd == -1) lineEnd = t.length;
  final lines = t.substring(first, lineEnd).split('\n');
  final parts = <(String, String, String)>[]; // önek, gövde, kuyruk boşluğu
  for (final l in lines) {
    final m = _linePrefix.firstMatch(l);
    final pre = m == null ? '' : m.group(0)!;
    var body = l.substring(pre.length);
    final lead = body.length - body.trimLeft().length;
    final pre2 = pre + body.substring(0, lead);
    body = body.substring(lead);
    final trimmed = body.trimRight();
    parts.add((pre2, trimmed, body.substring(trimmed.length)));
  }
  bool wrapped(String b) =>
      b.length >= open.length + close.length &&
      b.startsWith(open) &&
      b.endsWith(close);
  final all = parts.every((x) => x.$2.isEmpty || wrapped(x.$2));
  final out = [
    for (final (pre, body, tail) in parts)
      if (body.isEmpty)
        '$pre$body$tail'
      else if (all)
        '$pre${body.substring(open.length, body.length - close.length)}$tail'
      else if (wrapped(body))
        '$pre$body$tail'
      else
        '$pre$open$body$close$tail'
  ].join('\n');
  return TextEditingValue(
      text: t.replaceRange(first, lineEnd, out),
      selection: TextSelection(baseOffset: first, extentOffset: first + out.length));
}

final _linePrefix = RegExp(r'^(\s*)(#{1,6} |> |- \[[ xX]\] |[-*+] |\d+\. )');

/// Seçili satırların başındaki biçim önekini [prefix] ile değiştirir; zaten
/// [prefix] ise kaldırır. [numbered] ise 1., 2., 3. diye sayar.
TextEditingValue mdLinePrefix(TextEditingValue v, String prefix,
    {bool numbered = false}) {
  final sel = _sel(v);
  final t = v.text;
  final first = lineStartOf(t, sel.start);
  var end = sel.end;
  if (end > sel.start && end > 0 && t[end - 1] == '\n') end--;
  var lineEnd = t.indexOf('\n', end);
  if (lineEnd == -1) lineEnd = t.length;
  final lines = t.substring(first, lineEnd).split('\n');
  // Hepsi zaten bu önekte mi → kaldır.
  String pre(int i) => numbered ? '${i + 1}. ' : prefix;
  var allHave = true;
  for (var i = 0; i < lines.length; i++) {
    final m = _linePrefix.firstMatch(lines[i]);
    if (m == null || m.group(2) != pre(i)) allHave = false;
  }
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    final l = lines[i];
    final m = _linePrefix.firstMatch(l);
    final body = m == null ? l : l.substring(m.group(0)!.length);
    final lead = m?.group(1) ?? '';
    if (allHave) {
      out.add('$lead$body');
    } else if (l.trim().isEmpty && lines.length > 1) {
      out.add(l);
    } else {
      out.add('$lead${pre(i)}$body');
    }
  }
  final joined = out.join('\n');
  return TextEditingValue(
      text: t.replaceRange(first, lineEnd, joined),
      selection: TextSelection(
          baseOffset: first, extentOffset: first + joined.length));
}

/// Başlık: bu satırın düzeyi [level] ise kaldırır, değilse [level] yapar.
TextEditingValue mdHeading(TextEditingValue v, int level) =>
    mdLinePrefix(v, '${'#' * level} ');

/// Bağlantı: seçili metin etiket olur → `[etiket](https://)`; adresin
/// üzerine imleç konur.
TextEditingValue mdLink(TextEditingValue v, {String url = 'https://'}) {
  final sel = _sel(v);
  final label = v.text.substring(sel.start, sel.end);
  final shown = label.isEmpty ? 'bağlantı' : label;
  final ins = '[$shown]($url)';
  final nt = v.text.replaceRange(sel.start, sel.end, ins);
  final urlStart = sel.start + shown.length + 3;
  return TextEditingValue(
      text: nt,
      selection:
          TextSelection(baseOffset: urlStart, extentOffset: urlStart + url.length));
}

/// Kod: tek satırlık seçim → `` `satır içi` ``; çok satırlı → çitli blok.
TextEditingValue mdCode(TextEditingValue v) {
  final sel = _sel(v);
  final inner = v.text.substring(sel.start, sel.end);
  if (!inner.contains('\n')) return mdWrap(v, '`');
  final block = '```\n$inner\n```';
  return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, block),
      selection: TextSelection(
          baseOffset: sel.start + 4, extentOffset: sel.start + 4 + inner.length));
}

/// 2×2 tablo şablonu ekler (imleç satır başında değilse önce satır sonu).
TextEditingValue mdTable(TextEditingValue v, {int cols = 2, int rows = 2}) {
  final sel = _sel(v);
  final head = '| ${List.filled(cols, 'Başlık').join(' | ')} |';
  final sep = '| ${List.filled(cols, '---').join(' | ')} |';
  final row = '| ${List.filled(cols, '   ').join(' | ')} |';
  final body = List.filled(rows, row).join('\n');
  final needNl = sel.start > 0 && v.text[sel.start - 1] != '\n';
  final ins = '${needNl ? '\n' : ''}$head\n$sep\n$body\n';
  return TextEditingValue(
      text: v.text.replaceRange(sel.start, sel.end, ins),
      selection: TextSelection.collapsed(offset: sel.start + ins.length));
}

/// Liste/onay kutusu satırında Enter: bir sonraki satıra aynı öneki koyar
/// (numaralıysa artırır); boş maddede Enter öneki siler (listeden çıkar).
/// Uygulanamazsa null.
TextEditingValue? mdContinueList(TextEditingValue v) {
  final sel = v.selection;
  if (!sel.isValid || !sel.isCollapsed) return null;
  final t = v.text;
  final pos = sel.start;
  final ls = lineStartOf(t, pos);
  final line = t.substring(ls, pos);
  final m = RegExp(r'^(\s*)([-*+] \[[ xX]\] |[-*+] |(\d+)\. )(.*)$').firstMatch(line);
  if (m == null) return null;
  final lead = m.group(1)!;
  final marker = m.group(2)!;
  final rest = m.group(4)!;
  if (rest.isEmpty) {
    // Boş madde: öneki sil.
    return TextEditingValue(
        text: t.replaceRange(ls, pos, ''),
        selection: TextSelection.collapsed(offset: ls));
  }
  String next;
  if (m.group(3) != null) {
    next = '${int.parse(m.group(3)!) + 1}. ';
  } else if (marker.contains('[')) {
    next = marker.replaceAll(RegExp(r'\[[xX]\]'), '[ ]');
  } else {
    next = marker;
  }
  final ins = '\n$lead$next';
  return TextEditingValue(
      text: t.replaceRange(pos, pos, ins),
      selection: TextSelection.collapsed(offset: pos + ins.length));
}

TextSelection _sel(TextEditingValue v) =>
    v.selection.isValid ? v.selection : TextSelection.collapsed(offset: v.text.length);

/// Markdown'da Enter: liste / onay kutusu devam eder ([mdContinueList]); aksi
/// halde satır başı girintisi korunur.
class MarkdownEnterFormatter extends TextInputFormatter {
  const MarkdownEnterFormatter();

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.composing.isValid && !newValue.composing.isCollapsed) {
      return newValue;
    }
    final sel = oldValue.selection;
    if (!sel.isValid || !sel.isCollapsed) return newValue;
    final pos = sel.start;
    final o = oldValue.text;
    final n = newValue.text;
    if (n.length == o.length + 1 &&
        n[pos] == '\n' &&
        n == o.replaceRange(pos, pos, '\n')) {
      final r = mdContinueList(oldValue);
      if (r != null) return r;
    }
    return newValue;
  }
}

/// Markdown düzenleyicide **canlı biçim** (2026-11-12 kullanıcı: *"biçim yerine
/// başına sonuna işaret koyuyor, kodu kalıyor"*). Dosya yine düz Markdown
/// olarak kaydedilir; editörde ise `**kalın**` kalın, `## Başlık` büyük ve
/// kalın, `_eğik_` eğik görünür, işaretler soluklaşır. Metin değişmez (yalnız
/// boya) — imleç, seçim, IME ve geri al etkilenmez.
library;

import 'package:flutter/material.dart';

/// Bir karakterin biçim bayrakları (birleşebilir).
abstract final class MdFlag {
  static const bold = 1;
  static const italic = 2;
  static const code = 4;
  static const strike = 8;

  /// Biçim işareti (`**`, `## `, `- ` …) — soluk çizilir.
  static const mark = 16;
  static const link = 32;
  static const h1 = 64;
  static const h2 = 128;
  static const h3 = 256;
  static const quote = 512;

  /// Liste/görev işareti (vurgu renginde).
  static const bullet = 1024;
}

/// Bu boyun üstünde biçimlenmez (her tuşta yeniden hesaplanıyor).
const int markdownStyleMaxChars = 200000;

final _heading = RegExp(r'^(\s{0,3})(#{1,6})( +)');
final _quote = RegExp(r'^(\s*)(>+ ?)');
final _bullet = RegExp(r'^(\s*)([-*+] \[[ xX]\] |[-*+] |\d+[.)] )');
final _code = RegExp(r'`[^`\n]+`');
final _bold = RegExp(r'(\*\*|__)(?=\S)(.+?)(?<=\S)\1');
final _italicStar = RegExp(r'(?<![*\w])\*(?=[^\s*])([^*\n]+?)(?<=\S)\*(?![*\w])');
final _italicUnder = RegExp(r'(?<![_\w])_(?=[^\s_])([^_\n]+?)(?<=\S)_(?![_\w])');
final _strike = RegExp(r'~~(?=\S)(.+?)(?<=\S)~~');
final _link = RegExp(r'\[([^\]\n]+)\]\(([^)\n]*)\)');

/// Her karakterin bayrağı (saf; test edilir).
List<int> markdownFlags(String t) {
  final f = List<int>.filled(t.length, 0);
  void set(int a, int b, int flag) {
    for (var i = a; i < b; i++) {
      f[i] |= flag;
    }
  }

  var pos = 0;
  var inFence = false;
  while (pos <= t.length) {
    var end = t.indexOf('\n', pos);
    if (end == -1) end = t.length;
    final line = t.substring(pos, end);
    final trimmed = line.trimLeft();
    if (trimmed.startsWith('```') || trimmed.startsWith('~~~')) {
      set(pos, end, MdFlag.code | MdFlag.mark);
      inFence = !inFence;
    } else if (inFence) {
      set(pos, end, MdFlag.code);
    } else {
      var body = 0; // satır içi biçimin başladığı yer (satıra göre)
      final h = _heading.firstMatch(line);
      if (h != null) {
        final level = h.group(2)!.length;
        final hf = level == 1
            ? MdFlag.h1
            : level == 2
                ? MdFlag.h2
                : MdFlag.h3;
        set(pos, end, hf | MdFlag.bold);
        set(pos + h.group(1)!.length, pos + h.end, MdFlag.mark);
        body = h.end;
      } else {
        final q = _quote.firstMatch(line);
        if (q != null) {
          set(pos, end, MdFlag.quote);
          set(pos + q.group(1)!.length, pos + q.end, MdFlag.mark);
          body = q.end;
        }
        final b = _bullet.firstMatch(line.substring(body));
        if (b != null) {
          set(pos + body + b.group(1)!.length, pos + body + b.end,
              MdFlag.bullet);
          body += b.end;
        }
      }
      _inline(t, pos + body, end, f, set);
    }
    pos = end + 1;
  }
  return f;
}

void _inline(String t, int from, int to, List<int> f,
    void Function(int, int, int) set) {
  if (from >= to) return;
  final s = t.substring(from, to);
  bool free(int a, int b) {
    for (var i = a; i < b; i++) {
      if (f[from + i] & MdFlag.code != 0) return false;
    }
    return true;
  }

  for (final m in _code.allMatches(s)) {
    set(from + m.start, from + m.end, MdFlag.code);
    set(from + m.start, from + m.start + 1, MdFlag.mark);
    set(from + m.end - 1, from + m.end, MdFlag.mark);
  }
  void wrapped(RegExp re, int open, int flag) {
    for (final m in re.allMatches(s)) {
      if (!free(m.start, m.end)) continue;
      set(from + m.start, from + m.end, flag);
      set(from + m.start, from + m.start + open, MdFlag.mark);
      set(from + m.end - open, from + m.end, MdFlag.mark);
    }
  }

  wrapped(_bold, 2, MdFlag.bold);
  wrapped(_strike, 2, MdFlag.strike);
  wrapped(_italicStar, 1, MdFlag.italic);
  wrapped(_italicUnder, 1, MdFlag.italic);
  for (final m in _link.allMatches(s)) {
    if (!free(m.start, m.end)) continue;
    final labelEnd = m.start + 1 + m.group(1)!.length;
    set(from + m.start, from + m.start + 1, MdFlag.mark);
    set(from + m.start + 1, from + labelEnd, MdFlag.link);
    set(from + labelEnd, from + m.end, MdFlag.mark);
  }
}

/// Bayrakları boyalı parçalara çevirir.
List<InlineSpan> markdownSpans(String t, TextStyle? base, ColorScheme scheme) {
  final f = markdownFlags(t);
  final faded = scheme.onSurface.withValues(alpha: 0.38);
  TextStyle styleOf(int k) {
    final factor = k & MdFlag.h1 != 0
        ? 1.45
        : k & MdFlag.h2 != 0
            ? 1.25
            : k & MdFlag.h3 != 0
                ? 1.1
                : 1.0;
    // Başlık büyütmesi tabanın boyuna göre (boy yoksa büyütülmez).
    var s = factor != 1.0 && base?.fontSize != null
        ? base!.apply(fontSizeFactor: factor)
        : const TextStyle();
    if (k & MdFlag.bold != 0) s = s.copyWith(fontWeight: FontWeight.w700);
    if (k & MdFlag.italic != 0) s = s.copyWith(fontStyle: FontStyle.italic);
    if (k & MdFlag.quote != 0) {
      s = s.copyWith(
          fontStyle: FontStyle.italic, color: scheme.onSurfaceVariant);
    }
    if (k & MdFlag.strike != 0) {
      s = s.copyWith(decoration: TextDecoration.lineThrough);
    }
    if (k & MdFlag.code != 0) {
      s = s.copyWith(
          fontFamily: 'monospace',
          backgroundColor: scheme.surfaceContainerHighest);
    }
    if (k & MdFlag.link != 0) {
      s = s.copyWith(
          color: scheme.primary, decoration: TextDecoration.underline);
    }
    if (k & MdFlag.bullet != 0) {
      s = s.copyWith(color: scheme.primary, fontWeight: FontWeight.w700);
    }
    if (k & MdFlag.mark != 0) {
      s = s.copyWith(
          color: faded, fontWeight: FontWeight.w400, decoration: TextDecoration.none);
    }
    return s;
  }

  final spans = <InlineSpan>[];
  var a = 0;
  for (var i = 1; i <= t.length; i++) {
    if (i == t.length || f[i] != f[a]) {
      spans.add(TextSpan(
          text: t.substring(a, i), style: f[a] == 0 ? null : styleOf(f[a])));
      a = i;
    }
  }
  return spans;
}

/// Slayt metin kutusunun **zengin metin modeli** (Faz 28, 2026-10-23).
///
/// Eskiden kutunun her paragrafı ayrı, düz bir `TextField`ti ve kaydetme
/// paragraf metnini ilk `a:t`'ye topluyordu (SL2): ikinci run'daki kalın
/// kelime ilk run'ın biçimine dönüyordu, biçim (K/T/A, punto) tüm kutuya ya
/// hep ya hiç uygulanıyordu (SL4). Bu model kutunun bütün paragraflarını TEK
/// metin olarak tutar (paragraf arası `\n`, `a:br` satır sonu ` `) ve
/// her karakterin hangi özgün run'dan geldiğini + üstüne eklenen biçimi
/// bilir. Böylece:
/// * yazma yalnız değişen aralığa dokunur (ortak önek/sonek farkı), el
///   değmeyen run'lar kaydette AYNEN (özgün düğümün kopyası) yazılır;
/// * biçim seçime uygulanır (run bölünür);
/// * Enter yeni `a:p` açar, paragraf başında geri silme birleştirir.
///
/// XML'e yazma `PptxEditor.writeRichText`'te; çizim `SlideTextController`da.
library;

import 'package:flutter/painting.dart' show Color, TextAlign;
import 'package:xml/xml.dart';

import 'pptx_render.dart';

/// `a:br` satır sonunun modeldeki karşılığı (Flutter bunu zorunlu satır
/// sonu olarak çizer; paragraf ayırıcı `\n` ile karışmaz).
const String kSlideLineBreak = ' ';

/// Bir karakterin biçimi: özgün run + kullanıcının üstüne eklediği biçim.
class RunStyle {
  /// Özgün `a:r` / `a:fld` (yeni metinde ve boş paragrafta null).
  final XmlElement? source;

  /// Özgün görünüş (çizim modelinden).
  final RunVM look;

  final bool? bold, italic, underline;
  final double? sizePt;
  final Color? color;

  /// Dosyaya yazılacak yazı tipi adı (ekranda gömülü karşılığıyla çizilir).
  final String? font;

  const RunStyle(
    this.source,
    this.look, {
    this.bold,
    this.italic,
    this.underline,
    this.sizePt,
    this.color,
    this.font,
  });

  /// Kullanıcı biçimi eklenmedi mi (özgün run aynen yazılabilir).
  bool get plain =>
      bold == null &&
      italic == null &&
      underline == null &&
      sizePt == null &&
      color == null &&
      font == null;

  bool get isBold => bold ?? look.bold;
  bool get isItalic => italic ?? look.italic;
  bool get isUnderline => underline ?? look.underline;
  double get size => sizePt ?? look.sizePt;
  Color get fg => color ?? look.color;

  /// Verilen özellikleri örter (null = olduğu gibi).
  RunStyle merge({
    bool? bold,
    bool? italic,
    bool? underline,
    double? sizePt,
    Color? color,
    String? font,
  }) =>
      RunStyle(
        source,
        look,
        bold: bold ?? this.bold,
        italic: italic ?? this.italic,
        underline: underline ?? this.underline,
        sizePt: sizePt ?? this.sizePt,
        color: color ?? this.color,
        font: font ?? this.font,
      );

  /// Özgün run'dan kopmuş (yazılırken şablon olarak kullanılan) hâli: yeni
  /// yazılan metin özgün run'ın rPr'ini taşır ama "aynen kopyala" sayılmaz.
  @override
  bool operator ==(Object other) =>
      other is RunStyle &&
      identical(other.source, source) &&
      identical(other.look, look) &&
      other.bold == bold &&
      other.italic == italic &&
      other.underline == underline &&
      other.sizePt == sizePt &&
      other.color == color &&
      other.font == font;

  @override
  int get hashCode => Object.hash(
      source, look, bold, italic, underline, sizePt, color, font);
}

/// Paragraf biçimi: özgün `a:p` + kullanıcının değiştirdiği paragraf
/// özellikleri (null = dokunulmadı).
class ParaStyle {
  /// Özgün `a:p` (bölmeyle doğan yeni paragrafta null).
  final XmlElement? source;

  /// Yeni paragrafın `a:pPr`/`a:endParaRPr`'i bu düğümden kopyalanır.
  final XmlElement? cloneOf;

  final ParaVM? look;
  TextAlign? align;

  /// `none` | `char` | `num`.
  String? bullet;
  int? level;

  /// Metni ya da biçimi değişti mi (değişmeyen paragraf kaydette AYNEN kalır).
  bool touched;

  ParaStyle({
    this.source,
    this.cloneOf,
    this.look,
    this.align,
    this.bullet,
    this.level,
    this.touched = false,
  });

  ParaStyle copy() => ParaStyle(
        source: source,
        cloneOf: cloneOf,
        look: look,
        align: align,
        bullet: bullet,
        level: level,
        touched: touched,
      );

  /// Enter ile doğan kardeş: aynı biçim, özgün düğümsüz.
  ParaStyle split() => ParaStyle(
        cloneOf: source ?? cloneOf,
        look: look,
        align: align,
        bullet: bullet,
        level: level,
        touched: true,
      );

  TextAlign get effAlign => align ?? look?.align ?? TextAlign.left;

  String get effBullet {
    if (bullet != null) return bullet!;
    final b = look?.bullet ?? '';
    if (b.isEmpty) return 'none';
    return RegExp(r'^\d+\.$').hasMatch(b) ? 'num' : 'char';
  }

  int get effLevel => level ?? look?.level ?? 0;

  /// Paragraf sonu görünüşü (boş paragrafa yazılan ilk harf bunu alır).
  RunVM get endLook =>
      look?.endLook ??
      (look != null && look!.runs.isNotEmpty
          ? look!.runs.first
          : const RunVM(text: ''));
}

/// Geri al için tam durum.
class RichSnapshot {
  final String text;
  final List<(int, RunStyle)> segs;
  final List<ParaStyle> paras;
  const RichSnapshot(this.text, this.segs, this.paras);
}

/// Kutunun zengin metni.
class SlideRichText {
  String _text;

  /// (uzunluk, biçim) dizisi — toplam uzunluk == [text] uzunluğu.
  final List<(int, RunStyle)> _segs;
  final List<ParaStyle> paras;

  SlideRichText._(this._text, this._segs, this.paras);

  String get text => _text;

  /// Çizim modelindeki paragraflardan kurar.
  factory SlideRichText.fromParagraphs(List<ParaVM> source) {
    final sb = StringBuffer();
    final segs = <(int, RunStyle)>[];
    final paras = <ParaStyle>[];
    void add(String s, RunStyle st) {
      if (s.isEmpty) return;
      sb.write(s);
      if (segs.isNotEmpty && segs.last.$2 == st) {
        segs[segs.length - 1] = (segs.last.$1 + s.length, st);
      } else {
        segs.add((s.length, st));
      }
    }

    for (var i = 0; i < source.length; i++) {
      final p = source[i];
      final ps = ParaStyle(source: p.source, look: p);
      paras.add(ps);
      RunStyle? last;
      for (final r in p.runs) {
        if (r.source?.name.qualified == 'a:br' || r.text == '\n') {
          add(kSlideLineBreak, last ?? RunStyle(null, ps.endLook));
          continue;
        }
        last = RunStyle(r.source, r);
        add(r.text, last);
      }
      if (i < source.length - 1) add('\n', RunStyle(null, ps.endLook));
    }
    if (paras.isEmpty) paras.add(ParaStyle(touched: true));
    return SlideRichText._(sb.toString(), segs, paras);
  }

  // ── Sorgular ─────────────────────────────────────────────────────────────

  /// [offset]'teki karakterin biçimi (sınır dışında null).
  RunStyle? charStyle(int offset) {
    if (offset < 0 || offset >= _text.length) return null;
    var at = 0;
    for (final (len, st) in _segs) {
      if (offset < at + len) return st;
      at += len;
    }
    return null;
  }

  /// [offset]'e yazılacak harfin biçimi: önceki karakter (paragraf başında
  /// sonraki), boş paragrafta paragraf sonu biçimi.
  RunStyle typingStyleAt(int offset) {
    if (offset > 0 && _text[offset - 1] != '\n') {
      final st = charStyle(offset - 1);
      if (st != null) return st;
    }
    if (offset < _text.length && _text[offset] != '\n') {
      final st = charStyle(offset);
      if (st != null) return st;
    }
    return RunStyle(null, paras[paraIndexAt(offset)].endLook);
  }

  /// [offset]'in bulunduğu paragrafın sırası.
  int paraIndexAt(int offset) {
    var n = 0;
    final end = offset.clamp(0, _text.length);
    for (var i = 0; i < end; i++) {
      if (_text.codeUnitAt(i) == 0x0A) n++;
    }
    return n.clamp(0, paras.length - 1);
  }

  /// Paragraf aralıkları (`\n` hariç).
  List<(int, int)> paragraphRanges() {
    final out = <(int, int)>[];
    var start = 0;
    for (var i = 0; i < _text.length; i++) {
      if (_text.codeUnitAt(i) == 0x0A) {
        out.add((start, i));
        start = i + 1;
      }
    }
    out.add((start, _text.length));
    return out;
  }

  /// Biçim dizisi (çizim için): (başlangıç, bitiş, biçim).
  Iterable<(int, int, RunStyle)> spans() sync* {
    var at = 0;
    for (final (len, st) in _segs) {
      yield (at, at + len, st);
      at += len;
    }
  }

  /// [start, end) aralığındaki karakter grupları — paragraf yazıcısı için.
  /// Aynı biçimli ardışık karakterler tek grup; ` ` tek başına grup.
  List<(String, RunStyle)> groupsIn(int start, int end) {
    final out = <(String, RunStyle)>[];
    var at = 0;
    for (final (len, st) in _segs) {
      final s = at < start ? start : at;
      final e = at + len > end ? end : at + len;
      at += len;
      if (s >= e) continue;
      final piece = _text.substring(s, e);
      // Satır sonları ayrı gruba bölünür.
      var from = 0;
      for (var i = 0; i < piece.length; i++) {
        if (piece[i] == kSlideLineBreak) {
          if (i > from) _push(out, piece.substring(from, i), st);
          out.add((kSlideLineBreak, st));
          from = i + 1;
        }
      }
      if (from < piece.length) _push(out, piece.substring(from), st);
    }
    return out;
  }

  static void _push(List<(String, RunStyle)> out, String s, RunStyle st) {
    if (out.isNotEmpty && out.last.$2 == st && out.last.$1 != kSlideLineBreak) {
      out[out.length - 1] = (out.last.$1 + s, st);
    } else {
      out.add((s, st));
    }
  }

  // ── Düzenleme ────────────────────────────────────────────────────────────

  /// Metni [next] yapar. Fark ortak önek/sonekle bulunur; eklenen metin
  /// [typing] biçimini (yoksa ekleme noktasının biçimini) alır. Silinen
  /// `\n`'ler paragrafları birleştirir (öndeki paragrafın biçimi kalır),
  /// eklenen `\n`'ler paragraf böler (yeni paragraf öncekinin biçimini alır).
  void applyText(String next, {RunStyle? typing}) {
    final old = _text;
    if (next == old) return;
    var p = 0;
    final minLen = old.length < next.length ? old.length : next.length;
    while (p < minLen && old.codeUnitAt(p) == next.codeUnitAt(p)) {
      p++;
    }
    var s = 0;
    while (s < minLen - p &&
        old.codeUnitAt(old.length - 1 - s) ==
            next.codeUnitAt(next.length - 1 - s)) {
      s++;
    }
    final removed = old.substring(p, old.length - s);
    final inserted = next.substring(p, next.length - s);
    final style = typing ?? typingStyleAt(p);

    // Paragraflar.
    final pi = paraIndexAt(p);
    paras[pi].touched = true;
    final removedNl = '\n'.allMatches(removed).length;
    if (removedNl > 0) {
      paras.removeRange(pi + 1, (pi + 1 + removedNl).clamp(0, paras.length));
    }
    final insertedNl = '\n'.allMatches(inserted).length;
    for (var k = 0; k < insertedNl; k++) {
      paras.insert(pi + 1, paras[pi].split());
    }

    // Biçim dizisi.
    _remove(p, removed.length);
    _insert(p, inserted, style);
    _text = next;
  }

  void _remove(int at, int count) {
    if (count <= 0) return;
    var pos = 0;
    final out = <(int, RunStyle)>[];
    for (final (len, st) in _segs) {
      final s = pos, e = pos + len;
      pos = e;
      final keepLeft = (at - s).clamp(0, len);
      final keepRight = (e - (at + count)).clamp(0, len);
      final keep = keepLeft + keepRight > len ? len : keepLeft + keepRight;
      if (keep > 0) _append(out, keep, st);
    }
    _segs
      ..clear()
      ..addAll(out);
  }

  void _insert(int at, String text, RunStyle style) {
    if (text.isEmpty) return;
    var pos = 0;
    final out = <(int, RunStyle)>[];
    var done = false;
    for (final (len, st) in _segs) {
      if (!done && at <= pos + len && at >= pos) {
        final left = at - pos;
        if (left > 0) _append(out, left, st);
        _append(out, text.length, style);
        if (len - left > 0) _append(out, len - left, st);
        done = true;
      } else {
        _append(out, len, st);
      }
      pos += len;
    }
    if (!done) _append(out, text.length, style);
    _segs
      ..clear()
      ..addAll(out);
  }

  static void _append(List<(int, RunStyle)> out, int len, RunStyle st) {
    if (len <= 0) return;
    if (out.isNotEmpty && out.last.$2 == st) {
      out[out.length - 1] = (out.last.$1 + len, st);
    } else {
      out.add((len, st));
    }
  }

  /// [start, end) aralığına karakter biçimi uygular (`\n` biçimi önemsiz
  /// ama tutarlılık için o da değişir).
  void formatRange(
    int start,
    int end, {
    bool? bold,
    bool? italic,
    bool? underline,
    double? sizePt,
    Color? color,
    String? font,
  }) {
    if (start >= end) return;
    var pos = 0;
    final out = <(int, RunStyle)>[];
    for (final (len, st) in _segs) {
      final s = pos, e = pos + len;
      pos = e;
      final a = start > s ? start : s;
      final b = end < e ? end : e;
      if (a >= b) {
        _append(out, len, st);
        continue;
      }
      _append(out, a - s, st);
      _append(
          out,
          b - a,
          st.merge(
              bold: bold,
              italic: italic,
              underline: underline,
              sizePt: sizePt,
              color: color,
              font: font));
      _append(out, e - b, st);
    }
    _segs
      ..clear()
      ..addAll(out);
    for (var i = paraIndexAt(start); i <= paraIndexAt(end); i++) {
      paras[i].touched = true;
    }
  }

  /// [start, end] aralığının değdiği paragraflara paragraf biçimi uygular.
  void formatParagraphs(int start, int end,
      {TextAlign? align, String? bullet, int? level, int? levelDelta}) {
    for (var i = paraIndexAt(start); i <= paraIndexAt(end); i++) {
      final p = paras[i];
      if (align != null) p.align = align;
      if (bullet != null) p.bullet = bullet;
      if (level != null) p.level = level;
      if (levelDelta != null) {
        p.level = (p.effLevel + levelDelta).clamp(0, 8);
      }
      p.touched = true;
    }
  }

  /// Aralıktaki bütün karakterler [test]'i sağlıyor mu (boş aralıkta
  /// yazma biçimi sorulur).
  bool every(int start, int end, bool Function(RunStyle) test) {
    if (start >= end) return test(typingStyleAt(start));
    var any = false;
    for (final (s, e, st) in spans()) {
      if (e <= start || s >= end) continue;
      final a = s > start ? s : start;
      final b = e < end ? e : end;
      if (_text.substring(a, b).replaceAll('\n', '').isEmpty) continue;
      any = true;
      if (!test(st)) return false;
    }
    return any || test(typingStyleAt(start));
  }

  RichSnapshot snapshot() => RichSnapshot(
      _text, List.of(_segs), [for (final p in paras) p.copy()]);

  void restore(RichSnapshot s) {
    _text = s.text;
    _segs
      ..clear()
      ..addAll(s.segs);
    paras
      ..clear()
      ..addAll([for (final p in s.paras) p.copy()]);
  }

  /// Herhangi bir paragraf değişti mi.
  bool get touched => paras.any((p) => p.touched);
}

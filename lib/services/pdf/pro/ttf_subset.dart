/// **Dart TrueType alt kümeleyici** (PDF Pro Faz 56 / 5).
///
/// Yedek font belgeye gömülürken yalnız KULLANILAN glifler gider: `glyf`,
/// `loca`, `hmtx` sıkıştırılır (bileşik glif kapanışı dahil), Unicode `cmap`
/// (biçim 4, gerekirse 12) yeniden kurulur — metin aranabilir/kopyalanabilir
/// kalır. İpuçlama (hinting) komutları atılır; `cvt`/`fpgm`/`prep` ve değişken
/// font tabloları taşınmaz (varsayılan kesim kalır).
///
/// Yalnız `glyf` taslaklı (TrueType) fontlar; CFF'li font → null.
library;

import 'dart:typed_data';

class TtfSubset {
  /// [codePoints]'i taşıyan alt küme; font okunamıyorsa ya da TrueType
  /// taslaklı değilse null. Fontta olmayan karakter sessizce atlanır.
  ///
  /// [family]/[style] verilirse `name` tablosu "ABCDEF+Aile-Kesim" PostScript
  /// adıyla yeniden yazılır (etiket harf kümesinden türetilir). KÖK NEDEN:
  /// PDFium aynı BaseFont adlı iki fontu karıştırıyor — belgede zaten
  /// "Carlito-Regular" varsa bizim gömdüğümüz alt kümenin harfleri kayıttan
  /// sonra o fontun eşlemesiyle okunuyordu ("I" → "M").
  static Uint8List? build(Uint8List font, Iterable<int> codePoints,
      {String? family, String style = 'Regular'}) {
    try {
      return _Subsetter(font).run(codePoints.toSet(), family, style);
    } catch (_) {
      // Bilinçli: bozuk/desteklenmeyen font "alt küme yok" demektir; çağıran
      // (PdfFallbackFonts) yedeği kullanmadan açık glif reddi verir.
      return null;
    }
  }

  /// Fontun Unicode → glif eşlemesi ([codePoints] için; olmayan yok).
  static Map<int, int> glyphsOf(Uint8List font, Iterable<int> codePoints) {
    try {
      final s = _Subsetter(font);
      return {
        for (final c in codePoints)
          if (s.glyphOf(c) case final g? when g != 0) c: g
      };
    } catch (_) {
      return const {}; // Bilinçli: okunamayan font = kapsama yok.
    }
  }
}

class _Subsetter {
  final Uint8List bytes;
  final ByteData d;
  final Map<String, (int, int)> tables = {};

  _Subsetter(this.bytes) : d = ByteData.sublistView(bytes) {
    final n = d.getUint16(4);
    for (var i = 0; i < n; i++) {
      final o = 12 + i * 16;
      final tag = String.fromCharCodes(bytes.sublist(o, o + 4));
      tables[tag] = (d.getUint32(o + 8), d.getUint32(o + 12));
    }
    _readCmap();
  }

  // format 4 dilimleri ya da format 12 grupları
  int _cmap4 = -1, _cmap12 = -1;

  void _readCmap() {
    final t = tables['cmap'];
    if (t == null) throw const FormatException('cmap yok');
    final base = t.$1;
    final n = d.getUint16(base + 2);
    for (var i = 0; i < n; i++) {
      final o = base + 4 + i * 8;
      final plat = d.getUint16(o), enc = d.getUint16(o + 2);
      final off = base + d.getUint32(o + 4);
      final fmt = d.getUint16(off);
      final unicode = plat == 0 || (plat == 3 && (enc == 1 || enc == 10));
      if (!unicode) continue;
      if (fmt == 12) _cmap12 = off;
      if (fmt == 4 && _cmap4 < 0) _cmap4 = off;
    }
    if (_cmap4 < 0 && _cmap12 < 0) throw const FormatException('Unicode cmap yok');
  }

  int? glyphOf(int code) {
    if (_cmap12 >= 0) {
      final groups = d.getUint32(_cmap12 + 12);
      var lo = 0, hi = groups - 1;
      while (lo <= hi) {
        final mid = (lo + hi) >> 1;
        final o = _cmap12 + 16 + mid * 12;
        final start = d.getUint32(o), end = d.getUint32(o + 4);
        if (code < start) {
          hi = mid - 1;
        } else if (code > end) {
          lo = mid + 1;
        } else {
          return d.getUint32(o + 8) + (code - start);
        }
      }
      if (_cmap4 < 0) return null;
    }
    if (code > 0xFFFF) return null;
    final segX2 = d.getUint16(_cmap4 + 6);
    final ends = _cmap4 + 14;
    final starts = ends + segX2 + 2;
    final deltas = starts + segX2;
    final ranges = deltas + segX2;
    for (var i = 0; i < segX2; i += 2) {
      final end = d.getUint16(ends + i);
      if (code > end) continue;
      final start = d.getUint16(starts + i);
      if (code < start) return null;
      final delta = d.getUint16(deltas + i);
      final range = d.getUint16(ranges + i);
      if (range == 0) return (code + delta) & 0xFFFF;
      final g = d.getUint16(ranges + i + range + (code - start) * 2);
      return g == 0 ? null : (g + delta) & 0xFFFF;
    }
    return null;
  }

  Uint8List? run(Set<int> codes, [String? family, String style = 'Regular']) {
    final glyf = tables['glyf'], loca = tables['loca'];
    final head = tables['head'], hhea = tables['hhea'];
    final hmtx = tables['hmtx'], maxp = tables['maxp'];
    if (glyf == null ||
        loca == null ||
        head == null ||
        hhea == null ||
        hmtx == null ||
        maxp == null) {
      return null;
    }
    final numGlyphs = d.getUint16(maxp.$1 + 4);
    final longLoca = d.getInt16(head.$1 + 50) != 0;
    final numH = d.getUint16(hhea.$1 + 34);
    (int, int) glyphRange(int g) {
      if (g < 0 || g >= numGlyphs) return (0, 0);
      final a = longLoca
          ? d.getUint32(loca.$1 + g * 4)
          : d.getUint16(loca.$1 + g * 2) * 2;
      final b = longLoca
          ? d.getUint32(loca.$1 + g * 4 + 4)
          : d.getUint16(loca.$1 + g * 2 + 2) * 2;
      return (glyf.$1 + a, b - a);
    }

    // Eski glif → yeni glif (0 = .notdef her zaman).
    final order = <int>[0];
    final remap = <int, int>{0: 0};
    int take(int g) => remap.putIfAbsent(g, () {
          order.add(g);
          return order.length - 1;
        });
    final cmap = <int, int>{}; // kod → yeni glif
    for (final c in codes.toList()..sort()) {
      final g = glyphOf(c);
      if (g == null || g == 0 || g >= numGlyphs) continue;
      cmap[c] = take(g);
    }
    // Bileşik glif kapanışı.
    for (var i = 0; i < order.length; i++) {
      final (off, len) = glyphRange(order[i]);
      if (len < 10 || d.getInt16(off) >= 0) continue;
      var p = off + 10;
      while (true) {
        final flags = d.getUint16(p);
        take(d.getUint16(p + 2));
        p += 4 + ((flags & 1) != 0 ? 4 : 2);
        if ((flags & 8) != 0) {
          p += 2;
        } else if ((flags & 0x40) != 0) {
          p += 4;
        } else if ((flags & 0x80) != 0) {
          p += 8;
        }
        if ((flags & 0x20) == 0) break;
      }
    }

    // glyf + loca (ipuçlama komutları atılır).
    final glyfOut = BytesBuilder();
    final locaOut = ByteData((order.length + 1) * 4);
    for (var i = 0; i < order.length; i++) {
      locaOut.setUint32(i * 4, glyfOut.length);
      final (off, len) = glyphRange(order[i]);
      if (len <= 0) continue;
      final g = _stripGlyph(off, len, remap);
      glyfOut.add(g);
      if (g.length.isOdd) glyfOut.addByte(0);
    }
    locaOut.setUint32(order.length * 4, glyfOut.length);

    // hmtx: her glif için (ilerleme, sol yan boşluk).
    final hm = ByteData(order.length * 4);
    for (var i = 0; i < order.length; i++) {
      final g = order[i];
      final adv = g < numH
          ? d.getUint16(hmtx.$1 + g * 4)
          : d.getUint16(hmtx.$1 + (numH - 1) * 4);
      final lsb = g < numH
          ? d.getInt16(hmtx.$1 + g * 4 + 2)
          : d.getInt16(hmtx.$1 + numH * 4 + (g - numH) * 2);
      hm
        ..setUint16(i * 4, adv)
        ..setInt16(i * 4 + 2, lsb);
    }

    final headOut = Uint8List.fromList(bytes.sublist(head.$1, head.$1 + 54));
    ByteData.sublistView(headOut)
      ..setUint32(8, 0) // checkSumAdjustment sonra
      ..setInt16(50, 1); // uzun loca
    final hheaOut = Uint8List.fromList(bytes.sublist(hhea.$1, hhea.$1 + 36));
    ByteData.sublistView(hheaOut).setUint16(34, order.length);
    final maxpOut =
        Uint8List.fromList(bytes.sublist(maxp.$1, maxp.$1 + maxp.$2));
    ByteData.sublistView(maxpOut).setUint16(4, order.length);
    final post = ByteData(32)
      ..setUint32(0, 0x00030000)
      ..setUint32(4, tables['post'] == null ? 0 : d.getUint32(tables['post']!.$1 + 4))
      ..setInt16(8, tables['post'] == null ? 0 : d.getInt16(tables['post']!.$1 + 8))
      ..setInt16(10, tables['post'] == null ? 0 : d.getInt16(tables['post']!.$1 + 10));

    final out = <String, Uint8List>{
      'cmap': _buildCmap(cmap),
      'glyf': glyfOut.toBytes(),
      'head': headOut,
      'hhea': hheaOut,
      'hmtx': hm.buffer.asUint8List(),
      'loca': locaOut.buffer.asUint8List(),
      'maxp': maxpOut,
      'post': post.buffer.asUint8List(),
    };
    for (final tag in ['OS/2', if (family == null) 'name']) {
      final t = tables[tag];
      if (t != null) out[tag] = bytes.sublist(t.$1, t.$1 + t.$2);
    }
    if (family != null) {
      var h = 0x811c9dc5;
      for (final c in cmap.keys) {
        h = ((h ^ c) * 0x01000193) & 0xFFFFFFFF;
      }
      final tag = String.fromCharCodes(
          [for (var i = 0; i < 6; i++) 0x41 + ((h >> (i * 5)) & 31) % 26]);
      out['name'] = _buildName(family, style, '$tag+$family-$style');
    }
    return _assemble(out);
  }

  /// Glifin ipuçlama komutlarını atar, bileşik glifte bileşen numaralarını
  /// yeni sıraya çevirir.
  Uint8List _stripGlyph(int off, int len, Map<int, int> remap) {
    final contours = d.getInt16(off);
    if (contours >= 0) {
      final endPts = off + 10;
      final instrLenAt = endPts + contours * 2;
      if (instrLenAt + 2 > off + len) return bytes.sublist(off, off + len);
      final instr = d.getUint16(instrLenAt);
      final out = BytesBuilder()
        ..add(bytes.sublist(off, instrLenAt))
        ..add(const [0, 0])
        ..add(bytes.sublist(instrLenAt + 2 + instr, off + len));
      return out.toBytes();
    }
    final g = Uint8List.fromList(bytes.sublist(off, off + len));
    final gd = ByteData.sublistView(g);
    var p = 10;
    while (true) {
      final flags = gd.getUint16(p);
      gd.setUint16(p, flags & ~0x100); // WE_HAVE_INSTRUCTIONS kalkar
      gd.setUint16(p + 2, remap[gd.getUint16(p + 2)] ?? 0);
      p += 4 + ((flags & 1) != 0 ? 4 : 2);
      if ((flags & 8) != 0) {
        p += 2;
      } else if ((flags & 0x40) != 0) {
        p += 4;
      } else if ((flags & 0x80) != 0) {
        p += 8;
      }
      if ((flags & 0x20) == 0) break;
    }
    return g.sublist(0, p);
  }

  static Uint8List _buildCmap(Map<int, int> map) {
    final bmp = map.keys.where((c) => c <= 0xFFFF).toList()..sort();
    final all = map.keys.toList()..sort();
    final needs12 = all.any((c) => c > 0xFFFF);
    // Biçim 4: her kod kendi dilimi (delta ile), sonda 0xFFFF bekçisi.
    final segs = <(int, int, int)>[]; // başlangıç, bitiş, delta
    for (final c in bmp) {
      final g = map[c]!;
      if (segs.isNotEmpty &&
          segs.last.$2 + 1 == c &&
          ((c + segs.last.$3) & 0xFFFF) == g) {
        segs[segs.length - 1] = (segs.last.$1, c, segs.last.$3);
      } else {
        segs.add((c, c, (g - c) & 0xFFFF));
      }
    }
    if (segs.isEmpty || segs.last.$2 != 0xFFFF) segs.add((0xFFFF, 0xFFFF, 1));
    final n = segs.length;
    final f4 = ByteData(16 + n * 8);
    var pow = 1, sel = 0;
    while (pow * 2 <= n) {
      pow *= 2;
      sel++;
    }
    f4
      ..setUint16(0, 4)
      ..setUint16(2, 16 + n * 8)
      ..setUint16(4, 0)
      ..setUint16(6, n * 2)
      ..setUint16(8, pow * 2)
      ..setUint16(10, sel)
      ..setUint16(12, n * 2 - pow * 2);
    for (var i = 0; i < n; i++) {
      f4
        ..setUint16(14 + i * 2, segs[i].$2)
        ..setUint16(16 + n * 2 + i * 2, segs[i].$1)
        ..setUint16(16 + n * 4 + i * 2, segs[i].$3)
        ..setUint16(16 + n * 6 + i * 2, 0);
    }
    ByteData? f12;
    if (needs12) {
      final groups = <(int, int, int)>[];
      for (final c in all) {
        final g = map[c]!;
        if (groups.isNotEmpty &&
            groups.last.$2 + 1 == c &&
            groups.last.$3 + (c - groups.last.$1) == g) {
          groups[groups.length - 1] = (groups.last.$1, c, groups.last.$3);
        } else {
          groups.add((c, c, g));
        }
      }
      f12 = ByteData(16 + groups.length * 12)
        ..setUint16(0, 12)
        ..setUint32(4, 16 + groups.length * 12)
        ..setUint32(12, groups.length);
      for (var i = 0; i < groups.length; i++) {
        f12
          ..setUint32(16 + i * 12, groups[i].$1)
          ..setUint32(20 + i * 12, groups[i].$2)
          ..setUint32(24 + i * 12, groups[i].$3);
      }
    }
    final recs = f12 == null ? 1 : 2;
    final headLen = 4 + recs * 8;
    final out = ByteData(headLen + f4.lengthInBytes + (f12?.lengthInBytes ?? 0))
      ..setUint16(2, recs)
      ..setUint16(4, 3)
      ..setUint16(6, 1)
      ..setUint32(8, headLen);
    if (f12 != null) {
      out
        ..setUint16(12, 3)
        ..setUint16(14, 10)
        ..setUint32(16, headLen + f4.lengthInBytes);
    }
    final b = out.buffer.asUint8List();
    b.setAll(headLen, f4.buffer.asUint8List());
    if (f12 != null) {
      b.setAll(headLen + f4.lengthInBytes, f12.buffer.asUint8List());
    }
    return b;
  }

  /// Ad tablosu: aile (1), kesim (2), tam ad (4), PostScript adı (6) —
  /// Windows (UTF-16BE) ve Mac (ASCII) kayıtları.
  static Uint8List _buildName(String family, String style, String ps) {
    final ids = {1: family, 2: style, 4: '$family $style', 6: ps};
    final recs = <(int, int, int, int, Uint8List)>[];
    for (final e in ids.entries) {
      recs.add((1, 0, 0, e.key, Uint8List.fromList(e.value.codeUnits)));
    }
    for (final e in ids.entries) {
      final b = BytesBuilder();
      for (final u in e.value.codeUnits) {
        b
          ..addByte(u >> 8)
          ..addByte(u & 0xFF);
      }
      recs.add((3, 1, 0x409, e.key, b.toBytes()));
    }
    final strings = BytesBuilder();
    final head = ByteData(6 + recs.length * 12)
      ..setUint16(2, recs.length)
      ..setUint16(4, 6 + recs.length * 12);
    for (var i = 0; i < recs.length; i++) {
      final (plat, enc, lang, id, data) = recs[i];
      head
        ..setUint16(6 + i * 12, plat)
        ..setUint16(8 + i * 12, enc)
        ..setUint16(10 + i * 12, lang)
        ..setUint16(12 + i * 12, id)
        ..setUint16(14 + i * 12, data.length)
        ..setUint16(16 + i * 12, strings.length);
      strings.add(data);
    }
    return Uint8List.fromList([...head.buffer.asUint8List(), ...strings.toBytes()]);
  }

  static int _sum(Uint8List t) {
    var s = 0;
    final n = (t.length + 3) & ~3;
    for (var i = 0; i < n; i += 4) {
      var v = 0;
      for (var k = 0; k < 4; k++) {
        v = (v << 8) | (i + k < t.length ? t[i + k] : 0);
      }
      s = (s + v) & 0xFFFFFFFF;
    }
    return s;
  }

  static Uint8List _assemble(Map<String, Uint8List> tables) {
    final tags = tables.keys.toList()..sort();
    final n = tags.length;
    var pow = 1, sel = 0;
    while (pow * 2 <= n) {
      pow *= 2;
      sel++;
    }
    var size = 12 + n * 16;
    final offsets = <int>[];
    for (final t in tags) {
      offsets.add(size);
      size += (tables[t]!.length + 3) & ~3;
    }
    final out = Uint8List(size);
    final od = ByteData.sublistView(out)
      ..setUint32(0, 0x00010000)
      ..setUint16(4, n)
      ..setUint16(6, pow * 16)
      ..setUint16(8, sel)
      ..setUint16(10, n * 16 - pow * 16);
    var headAt = -1;
    for (var i = 0; i < n; i++) {
      final t = tables[tags[i]]!;
      final rec = 12 + i * 16;
      out.setAll(rec, tags[i].codeUnits);
      od
        ..setUint32(rec + 4, _sum(t))
        ..setUint32(rec + 8, offsets[i])
        ..setUint32(rec + 12, t.length);
      out.setAll(offsets[i], t);
      if (tags[i] == 'head') headAt = offsets[i];
    }
    if (headAt >= 0) {
      od.setUint32(headAt + 8, (0xB1B0AFBA - _sum(out)) & 0xFFFFFFFF);
    }
    return out;
  }
}

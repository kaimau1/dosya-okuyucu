/// Bir TrueType programının (çoğu zaman PDF'e gömülü **alt küme**) verilen
/// metnin her harfi için GERÇEK bir glifi var mı?
///
/// Alt küme fontlarda glif kimlikleri korunur ama kullanılmayan gliflerin
/// verisi boştur — `cmap`te harf görünse de çizilecek bir şey yoktur. Bu
/// yüzden `cmap` (biçim 4 / 12) + `loca` uzunluğuna birlikte bakılır.
/// Ayrıştırılamayan her durumda false (çağıran güvenli yedeğe — Carlito —
/// düşer).
library;

import 'dart:typed_data';

abstract final class TtfCoverage {
  static bool covers(List<int> ttf, String text) {
    try {
      return _covers(Uint8List.fromList(ttf), text);
    } catch (_) {
      return false;
    }
  }

  static bool _covers(Uint8List b, String text) {
    final d = ByteData.sublistView(b);
    final numTables = d.getUint16(4);
    final tables = <String, (int, int)>{};
    for (var i = 0; i < numTables; i++) {
      final rec = 12 + 16 * i;
      final tag = String.fromCharCodes(b.sublist(rec, rec + 4));
      tables[tag] = (d.getUint32(rec + 8), d.getUint32(rec + 12));
    }
    final cmap = tables['cmap'], head = tables['head'], loca = tables['loca'];
    final maxp = tables['maxp'];
    if (cmap == null || head == null || loca == null || maxp == null) {
      return false;
    }
    final longLoca = d.getInt16(head.$1 + 50) == 1;
    final numGlyphs = d.getUint16(maxp.$1 + 4);
    int locaAt(int gid) => longLoca
        ? d.getUint32(loca.$1 + gid * 4)
        : d.getUint16(loca.$1 + gid * 2) * 2;
    bool hasOutline(int gid) =>
        gid > 0 && gid < numGlyphs && locaAt(gid + 1) > locaAt(gid);

    // En iyi Unicode alt tablosu: (3,10) biçim 12, yoksa (3,1)/(0,x) biçim 4.
    int? sub4, sub12;
    final n = d.getUint16(cmap.$1 + 2);
    for (var i = 0; i < n; i++) {
      final rec = cmap.$1 + 4 + 8 * i;
      final platform = d.getUint16(rec), encoding = d.getUint16(rec + 2);
      final off = cmap.$1 + d.getUint32(rec + 4);
      final format = d.getUint16(off);
      final unicode = platform == 0 || (platform == 3 && (encoding == 1 || encoding == 10));
      if (!unicode) continue;
      if (format == 12) sub12 ??= off;
      if (format == 4) sub4 ??= off;
    }

    int glyphOf(int cp) {
      if (sub12 != null) {
        final groups = d.getUint32(sub12 + 12);
        for (var g = 0; g < groups; g++) {
          final r = sub12 + 16 + 12 * g;
          final start = d.getUint32(r), end = d.getUint32(r + 4);
          if (cp >= start && cp <= end) return d.getUint32(r + 8) + cp - start;
        }
        return 0;
      }
      final t = sub4;
      if (t == null || cp > 0xFFFF) return 0;
      final segX2 = d.getUint16(t + 6);
      final ends = t + 14;
      final starts = ends + segX2 + 2;
      final deltas = starts + segX2;
      final ranges = deltas + segX2;
      for (var s = 0; s < segX2 ~/ 2; s++) {
        final end = d.getUint16(ends + 2 * s);
        if (cp > end) continue;
        final start = d.getUint16(starts + 2 * s);
        if (cp < start) return 0;
        final delta = d.getInt16(deltas + 2 * s);
        final rangeOff = d.getUint16(ranges + 2 * s);
        if (rangeOff == 0) return (cp + delta) & 0xFFFF;
        final at = ranges + 2 * s + rangeOff + 2 * (cp - start);
        final gid = d.getUint16(at);
        return gid == 0 ? 0 : (gid + delta) & 0xFFFF;
      }
      return 0;
    }

    for (final rune in text.runes) {
      if (rune == 0x20 || rune == 0x09 || rune == 0x0A || rune == 0xA0) continue;
      if (!hasOutline(glyphOf(rune))) return false;
    }
    return true;
  }
}

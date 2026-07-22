import 'dart:typed_data';

import 'ole_cfb.dart';

/// Eski **.doc / .ppt** ikili dosyalarından metin çıkarır.
///
/// İki katman:
/// 1. **Yapısal ayrıştırma** (tercih edilen): .doc'ta FIB + piece table
///    ([MS-DOC] CLX/PlcPcd) — metin doğru SIRADA ve doğru kodlamayla
///    (CP1252 / UTF-16) gelir; .ppt'te kayıt ağacı ([MS-PPT]) gezilip
///    TextCharsAtom/TextBytesAtom'lar belge sırasıyla toplanır.
/// 2. **Bayt tarama** (yedek): yapısal yol uymayan/bozuk dosyada eski
///    UTF-16LE + CP1252 dizisi taraması devreye girer (içerik yine okunur,
///    sıra/boşluk kusurlu olabilir). O da yetersizse null → "harici aç".
class LegacyText {
  /// En az bu kadar harf çıkmazsa çıkarım başarısız sayılır.
  static const _minLetters = 8;

  static String? fromDoc(Uint8List fileBytes) {
    final ole = OleFile.tryParse(fileBytes);
    if (ole == null) return null;
    final wd = ole.stream('WordDocument');
    if (wd == null) return null;
    final structured = _docPieceText(ole, wd);
    if (structured != null && _letters(structured) >= _minLetters) {
      return structured;
    }
    return _best(wd);
  }

  static String? fromPpt(Uint8List fileBytes) {
    final ole = OleFile.tryParse(fileBytes);
    if (ole == null) return null;
    final s = ole.firstOf(
        ['PowerPoint Document', 'PowerPoint Document Stream', 'Presentation']);
    if (s == null) return null;
    final structured = _pptAtomText(s);
    if (structured != null && _letters(structured) >= _minLetters) {
      return structured;
    }
    return _best(s);
  }

  // ── Word 97-2003: piece table ─────────────────────────────────────────────

  /// FIB'den CLX'i bulup piece table üzerinden ana belge metnini (ccpText)
  /// çıkarır. Word 97+ değilse veya tutarsızlık görülürse null (yedek tarama).
  static String? _docPieceText(OleFile ole, Uint8List wd) {
    try {
      if (wd.length < 0x200) return null;
      final d = ByteData.sublistView(wd);
      if (d.getUint16(0, Endian.little) != 0xA5EC) return null; // Word97+ FIB
      final flags = d.getUint16(0x0A, Endian.little);
      // fWhichTblStm (0x0200): piece table hangi Table stream'inde.
      final table = ole.stream((flags & 0x0200) != 0 ? '1Table' : '0Table') ??
          ole.firstOf(['1Table', '0Table']);
      if (table == null) return null;
      final ccpText = d.getUint32(0x4C, Endian.little); // ana belge cp sayısı
      final fcClx = d.getUint32(0x1A2, Endian.little);
      final lcbClx = d.getUint32(0x1A6, Endian.little);
      if (ccpText == 0 || lcbClx < 5 || fcClx + lcbClx > table.length) {
        return null;
      }

      // Clx = Prc blokları (0x01, atlanır) + Pcdt (0x02 → PlcPcd).
      final td = ByteData.sublistView(table);
      var p = fcClx;
      final endClx = fcClx + lcbClx;
      while (p < endClx) {
        final tag = table[p];
        if (tag == 0x01) {
          if (p + 3 > endClx) return null;
          p += 3 + td.getUint16(p + 1, Endian.little);
        } else if (tag == 0x02) {
          if (p + 5 > endClx) return null;
          final lcb = td.getUint32(p + 1, Endian.little);
          return _readPieces(wd, table, p + 5, lcb, ccpText);
        } else {
          return null;
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// PlcPcd: n+1 CP + n adet 8 baytlık PCD. Her parça ya CP1252 (fc/2'den tek
  /// bayt) ya UTF-16LE (fc'den çift bayt). ccpText'e ulaşınca durur (dipnot/
  /// üstbilgi metnine taşmaz).
  static String? _readPieces(
      Uint8List wd, Uint8List table, int start, int lcb, int ccpText) {
    if (lcb < 4 + 12 || start + lcb > table.length) return null;
    final n = (lcb - 4) ~/ 12;
    final td = ByteData.sublistView(table);
    final sb = StringBuffer();
    var remaining = ccpText;
    for (var i = 0; i < n && remaining > 0; i++) {
      final cpStart = td.getUint32(start + i * 4, Endian.little);
      final cpEnd = td.getUint32(start + (i + 1) * 4, Endian.little);
      if (cpEnd <= cpStart) continue;
      var count = cpEnd - cpStart;
      if (count > remaining) count = remaining;
      final pcd = start + (n + 1) * 4 + i * 8;
      final fcRaw = td.getUint32(pcd + 2, Endian.little);
      final compressed = (fcRaw & 0x40000000) != 0;
      final fc = fcRaw & 0x3FFFFFFF;
      if (compressed) {
        final off = fc ~/ 2;
        if (off + count > wd.length) return null;
        for (var k = 0; k < count; k++) {
          sb.writeCharCode(_cp1252(wd[off + k]));
        }
      } else {
        if (fc + count * 2 > wd.length) return null;
        for (var k = 0; k < count; k++) {
          sb.writeCharCode(wd[fc + k * 2] | (wd[fc + k * 2 + 1] << 8));
        }
      }
      remaining -= count;
    }
    final out = _cleanDocText(sb.toString());
    return out.isEmpty ? null : out;
  }

  /// Word kontrol karakterlerini okunur hale getirir: paragraf/hücre sonları,
  /// alan kodları (0x13 kod → gizle, 0x14 sonuç → göster, 0x15 son).
  static String _cleanDocText(String raw) {
    final sb = StringBuffer();
    var fieldCode = 0;
    for (final ch in raw.codeUnits) {
      switch (ch) {
        case 0x0D: // paragraf sonu
        case 0x0B: // satır sonu
        case 0x0C: // sayfa sonu
          sb.write('\n');
          break;
        case 0x07: // tablo hücre/satır sonu
          sb.write('\t');
          break;
        case 0x13:
          fieldCode++;
          break;
        case 0x14:
          if (fieldCode > 0) fieldCode--;
          break;
        case 0x15:
          break;
        case 0x1E: // kırılmaz tire
          sb.write('-');
          break;
        case 0x1F: // isteğe bağlı tire
          break;
        default:
          if (fieldCode > 0) break; // alan kodu (ör. HYPERLINK "...") gizli
          if (ch >= 0x20 || ch == 0x09) sb.writeCharCode(ch);
      }
    }
    return sb.toString().trim();
  }

  // ── PowerPoint 97-2003: kayıt ağacı ──────────────────────────────────────

  /// Kayıt ağacını (8 baytlık başlıklar; recVer==0xF → kap) gezip metin
  /// atomlarını belge sırasıyla toplar. Hiç metin yoksa/bozuksa null.
  static String? _pptAtomText(Uint8List s) {
    try {
      final sb = StringBuffer();
      final slideNo = <int>[0];
      _pptWalk(s, 0, s.length, 0, sb, slideNo);
      final out = sb.toString().trim();
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }

  static void _pptWalk(Uint8List s, int start, int end, int depth,
      StringBuffer sb, List<int> slideNo) {
    if (depth > 32) return;
    final d = ByteData.sublistView(s);
    var p = start;
    while (p + 8 <= end) {
      final verInst = d.getUint16(p, Endian.little);
      final type = d.getUint16(p + 2, Endian.little);
      final len = d.getUint32(p + 4, Endian.little);
      final body = p + 8;
      if (len > end - body) break; // bozuk uzunluk → bu kapta dur
      if ((verInst & 0x000F) == 0x000F) {
        _pptWalk(s, body, body + len, depth + 1, sb, slideNo); // kap → içine gir
      } else if (type == 0x03F3) {
        // SlidePersistAtom: SlideListWithText içinde yeni slaytın metni başlıyor.
        slideNo[0]++;
        sb.write('\n[Slayt ${slideNo[0]}]\n');
      } else if (type == 0x0FA0) {
        // TextCharsAtom — UTF-16LE (Türkçe karakterler burada).
        final chars = <int>[];
        for (var k = 0; k + 1 < len; k += 2) {
          chars.add(s[body + k] | (s[body + k + 1] << 8));
        }
        _pptEmit(chars, sb);
      } else if (type == 0x0FA8) {
        // TextBytesAtom — UTF-16'nın düşük baytları (CP1252 eşlemesiyle).
        _pptEmit([for (var k = 0; k < len; k++) _cp1252(s[body + k])], sb);
      }
      p = body + len;
    }
  }

  static void _pptEmit(List<int> chars, StringBuffer sb) {
    if (chars.isEmpty) return;
    for (final c in chars) {
      if (c == 0x0D || c == 0x0B) {
        sb.write('\n');
      } else if (c >= 0x20 || c == 0x09 || c == 0x0A) {
        sb.writeCharCode(c);
      }
    }
    sb.write('\n');
  }

  // ── ortak yardımcılar ─────────────────────────────────────────────────────

  /// CP1252'nin 0x80-0x9F bandı (akıllı tırnak, uzun tire, € …); kalanı 1:1.
  static const _cp1252Hi = [
    0x20AC, 0x0081, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x008D, 0x017D, 0x008F, //
    0x0090, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x009D, 0x017E, 0x0178, //
  ];

  static int _cp1252(int b) =>
      b >= 0x80 && b <= 0x9F ? _cp1252Hi[b - 0x80] : b;

  /// Testler / genel kullanım: bir ham stream'den metin çıkarır.
  static String? extractFromStream(Uint8List stream) => _best(stream);

  static String? _best(Uint8List b) {
    final u16 = _utf16Runs(b);
    final u8 = _cp1252Runs(b);
    final pick = _letters(u16) >= _letters(u8) ? u16 : u8;
    final cleaned = pick.trim();
    return _letters(cleaned) >= _minLetters ? cleaned : null;
  }

  static int _letters(String s) {
    var n = 0;
    for (final r in s.runes) {
      if (_isLetter(r)) n++;
    }
    return n;
  }

  static bool _isLetter(int r) =>
      (r >= 0x41 && r <= 0x5A) ||
      (r >= 0x61 && r <= 0x7A) ||
      (r >= 0xC0 && r <= 0x24F); // Latin-1 ek + Latin genişletilmiş (Türkçe dahil)

  static bool _accept(int ch) {
    if (ch == 9 || ch == 10 || ch == 13) return true; // tab/newline
    if (ch >= 0x20 && ch <= 0x7E) return true; // ASCII yazdırılabilir
    if (ch >= 0xA0 && ch <= 0x24F) return true; // Latin-1/genişletilmiş
    if (ch >= 0x2010 && ch <= 0x2027) return true; // tipografik tire/tırnak
    return false;
  }

  static String _utf16Runs(Uint8List b) {
    final sb = StringBuffer();
    final run = <int>[];
    void flush() {
      if (run.length >= 4) {
        sb.writeln(String.fromCharCodes(run).trim());
      }
      run.clear();
    }

    for (var i = 0; i + 1 < b.length; i += 2) {
      final ch = b[i] | (b[i + 1] << 8);
      if (ch == 13 || ch == 10) {
        flush();
      } else if (_accept(ch)) {
        run.add(ch);
      } else {
        flush();
      }
    }
    flush();
    return sb.toString();
  }

  static String _cp1252Runs(Uint8List b) {
    final sb = StringBuffer();
    final run = <int>[];
    void flush() {
      if (run.length >= 4) {
        sb.writeln(String.fromCharCodes(run).trim());
      }
      run.clear();
    }

    for (var i = 0; i < b.length; i++) {
      final ch = b[i];
      if (ch == 13 || ch == 10) {
        flush();
      } else if (_accept(ch)) {
        run.add(ch);
      } else {
        flush();
      }
    }
    flush();
    return sb.toString();
  }
}

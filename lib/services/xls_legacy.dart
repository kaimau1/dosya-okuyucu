import 'dart:typed_data';

import 'ole_cfb.dart';

/// Eski **.xls (BIFF8)** dosyalarını okur: OLE2 kabından `Workbook` stream'ini
/// alır, BIFF kayıtlarından hücre değerlerini (metin/sayı) çıkarır. Amaç, dosyayı
/// düzenlemek değil **görüntülemek** — değerler aynı Excel ızgarasında gösterilir.
///
/// Kapsam: SST (paylaşılan metinler), BOUNDSHEET (sayfa adları), LABELSST, LABEL,
/// RK, MULRK, NUMBER, FORMULA (sayısal sonuç) + STRING. Biçim/stil okunmaz.
/// Bozuk/desteklenmeyen dosyada [tryParse] null döner (fırlatmaz).
///
/// Sınır: çok büyük SST'lerde metinler CONTINUE kayıtlarına bölünür ve araya bir
/// bayt (grbit) girer; bu sürüm bunu tam çözmez (tek-kayıtlı SST — küçük/orta
/// dosyalar — doğru; çok büyük dosyalarda bazı metinler eksik olabilir, çökme yok).
class XlsLegacySheet {
  final String name;
  final List<List<String>> rows;
  XlsLegacySheet(this.name, this.rows);
}

class XlsLegacy {
  final List<XlsLegacySheet> sheets;
  XlsLegacy(this.sheets);

  /// Tüm sayfaların düz metni (AI/aramada kullanmak için).
  String get plainText {
    final sb = StringBuffer();
    for (final s in sheets) {
      if (sheets.length > 1) sb.writeln('# ${s.name}');
      for (final row in s.rows) {
        sb.writeln(row.join('\t'));
      }
    }
    return sb.toString().trim();
  }

  static XlsLegacy? tryParse(Uint8List fileBytes) {
    final ole = OleFile.tryParse(fileBytes);
    if (ole == null) return null;
    final wb = ole.firstOf(['Workbook', 'Book']);
    if (wb == null) return null;
    try {
      final parsed = _parse(wb);
      return parsed.sheets.isEmpty ? null : parsed;
    } catch (_) {
      return null;
    }
  }

  static XlsLegacy _parse(Uint8List wb) {
    final records = _scan(wb);

    // Paylaşılan metin tablosu (SST + izleyen CONTINUE'lar).
    final sst = <String>[];
    for (var i = 0; i < records.length; i++) {
      if (records[i].type == 0x00FC) {
        final blocks = <Uint8List>[records[i].data];
        var j = i + 1;
        while (j < records.length && records[j].type == 0x003C) {
          blocks.add(records[j].data);
          j++;
        }
        _parseSst(blocks, sst);
        break;
      }
    }

    // Sayfa konumları (BOUNDSHEET) → kayıt indeksi.
    final offsetToIndex = <int, int>{};
    for (var i = 0; i < records.length; i++) {
      offsetToIndex[records[i].offset] = i;
    }
    final bounds = <_Bound>[];
    for (final r in records) {
      if (r.type == 0x0085 && r.data.length >= 8) {
        final bd = ByteData.sublistView(r.data);
        final lbPly = bd.getUint32(0, Endian.little);
        bounds.add(_Bound(_shortUnicode(r.data, 6), lbPly));
      }
    }

    final sheets = <XlsLegacySheet>[];
    if (bounds.isEmpty) {
      // BOUNDSHEET yoksa: ilk worksheet BOF'undan tek sayfa.
      for (var i = 0; i < records.length; i++) {
        if (records[i].type == 0x0809) {
          final rows = _parseSheet(records, i, sst);
          if (rows.isNotEmpty) sheets.add(XlsLegacySheet('Sayfa1', rows));
          break;
        }
      }
    } else {
      var n = 1;
      for (final b in bounds) {
        final idx = offsetToIndex[b.pos];
        if (idx == null) continue;
        final rows = _parseSheet(records, idx, sst);
        final name = b.name.trim().isEmpty ? 'Sayfa${n}' : b.name;
        sheets.add(XlsLegacySheet(name, rows));
        n++;
      }
    }
    return XlsLegacy(sheets);
  }

  /// Kayıtları (offset, tip, veri) olarak tarar.
  static List<_Rec> _scan(Uint8List wb) {
    final records = <_Rec>[];
    final d = ByteData.sublistView(wb);
    var pos = 0;
    while (pos + 4 <= wb.length) {
      final type = d.getUint16(pos, Endian.little);
      final len = d.getUint16(pos + 2, Endian.little);
      final start = pos + 4;
      if (start + len > wb.length) break;
      records.add(_Rec(pos, type, Uint8List.sublistView(wb, start, start + len)));
      pos = start + len;
    }
    return records;
  }

  /// [startIdx] (worksheet BOF) → EOF arasındaki hücre kayıtlarını ızgaraya çevirir.
  static List<List<String>> _parseSheet(
      List<_Rec> records, int startIdx, List<String> sst) {
    final cells = <int, Map<int, String>>{}; // satır → (sütun → metin)
    var maxRow = -1;
    var maxCol = -1;

    void put(int r, int c, String v) {
      (cells[r] ??= <int, String>{})[c] = v;
      if (r > maxRow) maxRow = r;
      if (c > maxCol) maxCol = c;
    }

    for (var i = startIdx + 1; i < records.length; i++) {
      final r = records[i];
      if (r.type == 0x000A) break; // EOF
      if (r.type == 0x0809) break; // sonraki substream'e taşma koruması
      final d = ByteData.sublistView(r.data);
      switch (r.type) {
        case 0x00FD: // LABELSST
          if (r.data.length >= 10) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final isst = d.getUint32(6, Endian.little);
            put(row, col, isst < sst.length ? sst[isst] : '');
          }
          break;
        case 0x0204: // LABEL (inline metin)
          if (r.data.length >= 8) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            put(row, col, _unicodeString16(r.data, 6));
          }
          break;
        case 0x027E: // RK
          if (r.data.length >= 10) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            put(row, col, _numStr(_rk(d.getUint32(6, Endian.little))));
          }
          break;
        case 0x00BD: // MULRK
          if (r.data.length >= 6) {
            final row = d.getUint16(0, Endian.little);
            final colFirst = d.getUint16(2, Endian.little);
            final count = (r.data.length - 6) ~/ 6;
            for (var k = 0; k < count; k++) {
              final rk = d.getUint32(4 + 2 + k * 6, Endian.little);
              put(row, colFirst + k, _numStr(_rk(rk)));
            }
          }
          break;
        case 0x0203: // NUMBER
          if (r.data.length >= 14) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            put(row, col, _numStr(d.getFloat64(6, Endian.little)));
          }
          break;
        case 0x0006: // FORMULA
          if (r.data.length >= 14) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            // Sonuç 8 bayt: son iki bayt 0xFFFF ise sayısal DEĞİL (metin/bool/hata).
            final isText = d.getUint16(12, Endian.little) == 0xFFFF;
            if (!isText) {
              put(row, col, _numStr(d.getFloat64(6, Endian.little)));
            } else if (r.data.length >= 8 && d.getUint8(6) == 0) {
              // Sonraki STRING kaydı metni taşır.
              if (i + 1 < records.length && records[i + 1].type == 0x0207) {
                put(row, col, _unicodeString16(records[i + 1].data, 0));
              }
            }
          }
          break;
      }
    }

    if (maxRow < 0) return const [];
    final out = <List<String>>[];
    for (var r = 0; r <= maxRow; r++) {
      final rowMap = cells[r];
      final row = <String>[];
      for (var c = 0; c <= maxCol; c++) {
        row.add(rowMap?[c] ?? '');
      }
      out.add(row);
    }
    return out;
  }

  // --------------------------------------------------------------- yardımcı

  /// SST bloklarını sırayla okuyup metinleri [out]'a ekler. Tek blokta (çoğu
  /// dosya) tam doğru; bozulmada sessizce durur (elde edilenleri korur).
  static void _parseSst(List<Uint8List> blocks, List<String> out) {
    final buf = BytesBuilder();
    for (final b in blocks) {
      buf.add(b);
    }
    final data = buf.toBytes();
    if (data.length < 8) return;
    final d = ByteData.sublistView(data);
    final unique = d.getUint32(4, Endian.little);
    var p = 8;
    for (var i = 0; i < unique; i++) {
      if (p + 3 > data.length) break;
      final cch = d.getUint16(p, Endian.little);
      final flags = data[p + 2];
      final high = (flags & 0x01) != 0;
      final rich = (flags & 0x08) != 0;
      final ext = (flags & 0x04) != 0;
      p += 3;
      var cRun = 0;
      var cbExt = 0;
      if (rich) {
        if (p + 2 > data.length) break;
        cRun = d.getUint16(p, Endian.little);
        p += 2;
      }
      if (ext) {
        if (p + 4 > data.length) break;
        cbExt = d.getUint32(p, Endian.little);
        p += 4;
      }
      final chars = <int>[];
      for (var k = 0; k < cch; k++) {
        if (high) {
          if (p + 2 > data.length) {
            out.add(String.fromCharCodes(chars));
            return;
          }
          chars.add(data[p] | (data[p + 1] << 8));
          p += 2;
        } else {
          if (p >= data.length) {
            out.add(String.fromCharCodes(chars));
            return;
          }
          chars.add(data[p]);
          p += 1;
        }
      }
      out.add(String.fromCharCodes(chars));
      p += cRun * 4; // rich metin çalışmaları atlanır
      p += cbExt; // uzak-doğu fonetik verisi atlanır
    }
  }

  /// Kısa Unicode dizi (cch: 1 bayt).
  static String _shortUnicode(Uint8List data, int off) {
    if (off + 2 > data.length) return '';
    final cch = data[off];
    final high = (data[off + 1] & 0x01) != 0;
    return _chars(data, off + 2, cch, high);
  }

  /// Unicode dizi (cch: 2 bayt).
  static String _unicodeString16(Uint8List data, int off) {
    if (off + 3 > data.length) return '';
    final cch = data[off] | (data[off + 1] << 8);
    final high = (data[off + 2] & 0x01) != 0;
    return _chars(data, off + 3, cch, high);
  }

  static String _chars(Uint8List data, int start, int cch, bool high) {
    final chars = <int>[];
    var p = start;
    for (var k = 0; k < cch; k++) {
      if (high) {
        if (p + 2 > data.length) break;
        chars.add(data[p] | (data[p + 1] << 8));
        p += 2;
      } else {
        if (p >= data.length) break;
        chars.add(data[p]);
        p += 1;
      }
    }
    return String.fromCharCodes(chars);
  }

  /// RK kodlu sayı → double ([MS-XLS] 2.5.166).
  static double _rk(int rk) {
    final cents = (rk & 1) != 0;
    final isInt = (rk & 2) != 0;
    double num;
    if (isInt) {
      var s = rk & 0xFFFFFFFF;
      if ((s & 0x80000000) != 0) s -= 0x100000000; // işaretli 32-bit
      num = (s >> 2).toDouble();
    } else {
      final hi = rk & 0xFFFFFFFC;
      final bd = ByteData(8);
      bd.setUint32(4, hi & 0xFFFFFFFF, Endian.little);
      num = bd.getFloat64(0, Endian.little);
    }
    return cents ? num / 100.0 : num;
  }

  static String _numStr(double v) {
    if (!v.isFinite) return '';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    return v.toString();
  }
}

class _Rec {
  final int offset;
  final int type;
  final Uint8List data;
  _Rec(this.offset, this.type, this.data);
}

class _Bound {
  final String name;
  final int pos;
  _Bound(this.name, this.pos);
}

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../core/excel_format.dart';
import 'ole_cfb.dart';
import 'xlsx_writer.dart';

/// Eski **.xls (BIFF8)** dosyalarını okur: OLE2 kabından `Workbook` stream'ini
/// alır, BIFF kayıtlarından hücre değerlerini ve **görünümünü** çıkarır.
///
/// **2026-08-07 — artık salt-okunur bir liste değil.** Okunan çalışma kitabı
/// [toXlsxBytes] ile geçerli bir `.xlsx`e çevriliyor; uygulama onu normal
/// Excel ızgarasında açıyor (zoom, şerit, formül, düzenleme, kaydetme).
/// *Niye çevrim:* `.xls` YAZMAK (BIFF üretmek) hem çok daha büyük bir iş hem
/// de gereksiz — kullanıcı dosyayı düzenleyip kaydettiğinde modern biçim
/// zaten daha iyi. Okuma tarafında hiçbir şey kaybolmuyor.
///
/// Kapsam: SST (paylaşılan metinler, CONTINUE'lar dahil), BOUNDSHEET,
/// LABELSST, LABEL, RK, MULRK, NUMBER, BLANK, MULBLANK, BOOLERR,
/// FORMULA (sayısal/metin sonuç), FORMAT, FONT, XF, PALETTE, ROW, COLINFO,
/// MERGEDCELLS, WINDOW2/PANE, DATEMODE.
/// Bozuk/desteklenmeyen dosyada [tryParse] null döner (fırlatmaz).
class XlsLegacySheet {
  final String name;

  /// Ham hücre metinleri (AI bağlamı, arama, eski salt-okunur yol).
  final List<List<String>> rows;

  /// satır → (sütun → hücre). Çevrimin asıl kaynağı budur; [rows] bunun
  /// düzleştirilmiş metin hâli.
  final Map<int, Map<int, XlsLegacyCell>> cells;

  final Map<int, double> colWidths;
  final Map<int, double> rowHeights;
  final Set<int> hiddenCols;
  final Set<int> hiddenRows;
  final List<XlsxWriteMerge> merges;
  final int frozenRows;
  final int frozenCols;
  final bool hidden;
  final bool rightToLeft;
  final bool showGridLines;

  XlsLegacySheet(
    this.name,
    this.rows, {
    Map<int, Map<int, XlsLegacyCell>>? cells,
    Map<int, double>? colWidths,
    Map<int, double>? rowHeights,
    Set<int>? hiddenCols,
    Set<int>? hiddenRows,
    List<XlsxWriteMerge>? merges,
    this.frozenRows = 0,
    this.frozenCols = 0,
    this.hidden = false,
    this.rightToLeft = false,
    this.showGridLines = true,
  })  : cells = cells ?? {},
        colWidths = colWidths ?? {},
        rowHeights = rowHeights ?? {},
        hiddenCols = hiddenCols ?? {},
        hiddenRows = hiddenRows ?? {},
        merges = merges ?? [];
}

/// Tek hücre: değer + biçim (XF) indeksi.
class XlsLegacyCell {
  final String? text;
  final double? number;
  final bool? boolean;
  final String? error;

  /// XF (biçim) kaydının indeksi; [XlsLegacy.styles] içine bakar.
  final int xf;

  const XlsLegacyCell({
    this.text,
    this.number,
    this.boolean,
    this.error,
    this.xf = -1,
  });

  /// Görünen ham metin (sayı ham hâliyle; biçim ekranda uygulanır).
  String get raw {
    if (text != null) return text!;
    if (boolean != null) return boolean! ? 'DOĞRU' : 'YANLIŞ';
    if (error != null) return error!;
    if (number != null) return XlsLegacy.numText(number!);
    return '';
  }
}

class XlsLegacy {
  final List<XlsLegacySheet> sheets;

  /// XF indeksine karşılık gelen hücre görünümleri.
  final List<XlsxWriteStyle> styles;

  /// 1904 tarih sistemi (eski Mac dosyaları).
  final bool date1904;

  XlsLegacy(this.sheets, {this.styles = const [], this.date1904 = false});

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

  /// Çalışma kitabını **.xlsx baytlarına** çevirir. Değerler, sayı biçimleri,
  /// yazı tipi/renk/hizalama, sütun genişliği, satır yüksekliği, birleşik
  /// hücreler ve dondurulmuş bölme taşınır.
  Uint8List toXlsxBytes() {
    final out = <XlsxWriteSheet>[];
    for (final s in sheets) {
      final cells = <int, Map<int, XlsxWriteCell>>{};
      s.cells.forEach((r, row) {
        final target = <int, XlsxWriteCell>{};
        row.forEach((c, cell) {
          // Yazıcı 0. sırayı varsayılan stile ayırdığı için XF indeksi +1.
          final style = cell.xf >= 0 && cell.xf < styles.length ? cell.xf + 1 : 0;
          target[c] = XlsxWriteCell(
            text: cell.text,
            number: cell.number,
            boolean: cell.boolean,
            error: cell.error,
            style: style,
          );
        });
        if (target.isNotEmpty) cells[r] = target;
      });
      out.add(XlsxWriteSheet(
        name: s.name,
        cells: cells,
        colWidths: s.colWidths,
        rowHeights: s.rowHeights,
        hiddenCols: s.hiddenCols,
        hiddenRows: s.hiddenRows,
        merges: s.merges,
        frozenRows: s.frozenRows,
        frozenCols: s.frozenCols,
        hidden: s.hidden,
        rightToLeft: s.rightToLeft,
        showGridLines: s.showGridLines,
      ));
    }
    return XlsxWriter.build(out, styles: styles, date1904: date1904);
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

  /// OLE kabı olmadan **doğrudan Workbook stream'ini** çözer. Testler BIFF
  /// kayıtlarını elle üretip buraya verebilsin diye açık: OLE2 kabı üretmek
  /// testin konusu değil (onun kendi testi var: `ole_cfb_test.dart`).
  @visibleForTesting
  static XlsLegacy parseWorkbookStream(Uint8List wb) => _parse(wb);

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

    // Çalışma kitabı düzeyindeki biçim kayıtları — sayfa kayıtlarından ÖNCE
    // gelirler, bu yüzden tek geçişte toplanabilirler.
    final formats = <int, String>{};
    final fonts = <_Font>[];
    final xfs = <_Xf>[];
    final palette = List<int>.from(_defaultPalette);
    var date1904 = false;

    for (final r in records) {
      final d = ByteData.sublistView(r.data);
      switch (r.type) {
        case 0x0022: // DATEMODE
          if (r.data.length >= 2 && d.getUint16(0, Endian.little) == 1) {
            date1904 = true;
          }
        case 0x041E: // FORMAT
          if (r.data.length >= 4) {
            formats[d.getUint16(0, Endian.little)] =
                _unicodeString16(r.data, 2);
          }
        case 0x0031: // FONT
          if (r.data.length >= 14) fonts.add(_Font.parse(r.data));
        case 0x00E0: // XF
          if (r.data.length >= 20) xfs.add(_Xf.parse(r.data));
        case 0x0092: // PALETTE
          if (r.data.length >= 2) {
            final count = d.getUint16(0, Endian.little);
            for (var k = 0; k < count && 2 + k * 4 + 4 <= r.data.length; k++) {
              final b = 2 + k * 4;
              palette[8 + k] = 0xFF000000 |
                  (r.data[b] << 16) |
                  (r.data[b + 1] << 8) |
                  r.data[b + 2];
            }
          }
      }
    }

    final styles = [
      for (final xf in xfs) xf.toStyle(fonts, formats, palette),
    ];

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
        // hsState: 0 görünür, 1 gizli, 2 çok gizli.
        final hidden = (r.data[4] & 0x03) != 0;
        bounds.add(_Bound(_shortUnicode(r.data, 6), lbPly, hidden));
      }
    }

    final sheets = <XlsLegacySheet>[];
    if (bounds.isEmpty) {
      // BOUNDSHEET yoksa: ilk worksheet BOF'undan tek sayfa.
      for (var i = 0; i < records.length; i++) {
        if (records[i].type == 0x0809) {
          final sheet = _parseSheet(records, i, sst, 'Sayfa1', false);
          if (sheet != null) sheets.add(sheet);
          break;
        }
      }
    } else {
      var n = 1;
      for (final b in bounds) {
        final idx = offsetToIndex[b.pos];
        if (idx == null) continue;
        final name = b.name.trim().isEmpty ? 'Sayfa$n' : b.name;
        final sheet = _parseSheet(records, idx, sst, name, b.hidden);
        if (sheet != null) sheets.add(sheet);
        n++;
      }
    }
    return XlsLegacy(sheets, styles: styles, date1904: date1904);
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

  /// [startIdx] (worksheet BOF) → EOF arasındaki kayıtları sayfaya çevirir.
  /// Sayfada hiç hücre yoksa **yine de** bir sayfa döner (boş sayfa da
  /// dosyanın parçası; eskiden atılıyordu ve sayfa sekmeleri eksik çıkıyordu).
  static XlsLegacySheet? _parseSheet(List<_Rec> records, int startIdx,
      List<String> sst, String name, bool hidden) {
    final cells = <int, Map<int, XlsLegacyCell>>{};
    final colWidths = <int, double>{};
    final rowHeights = <int, double>{};
    final hiddenCols = <int>{};
    final hiddenRows = <int>{};
    final merges = <XlsxWriteMerge>[];
    var maxRow = -1;
    var maxCol = -1;
    var frozenRows = 0;
    var frozenCols = 0;
    var frozen = false;
    var rightToLeft = false;
    var showGridLines = true;

    void put(int r, int c, XlsLegacyCell cell) {
      if (r < 0 || c < 0 || r > 1048575 || c > 16383) return;
      (cells[r] ??= <int, XlsLegacyCell>{})[c] = cell;
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
            final xf = d.getUint16(4, Endian.little);
            final isst = d.getUint32(6, Endian.little);
            put(row, col,
                XlsLegacyCell(text: isst < sst.length ? sst[isst] : '', xf: xf));
          }
        case 0x0204: // LABEL (inline metin)
          if (r.data.length >= 8) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final xf = d.getUint16(4, Endian.little);
            put(row, col,
                XlsLegacyCell(text: _unicodeString16(r.data, 6), xf: xf));
          }
        case 0x027E: // RK
          if (r.data.length >= 10) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final xf = d.getUint16(4, Endian.little);
            put(row, col,
                XlsLegacyCell(number: _rk(d.getUint32(6, Endian.little)), xf: xf));
          }
        case 0x00BD: // MULRK
          if (r.data.length >= 6) {
            final row = d.getUint16(0, Endian.little);
            final colFirst = d.getUint16(2, Endian.little);
            final count = (r.data.length - 6) ~/ 6;
            for (var k = 0; k < count; k++) {
              final base = 4 + k * 6;
              final xf = d.getUint16(base, Endian.little);
              final rk = d.getUint32(base + 2, Endian.little);
              put(row, colFirst + k,
                  XlsLegacyCell(number: _rk(rk), xf: xf));
            }
          }
        case 0x0203: // NUMBER
          if (r.data.length >= 14) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final xf = d.getUint16(4, Endian.little);
            put(row, col,
                XlsLegacyCell(number: d.getFloat64(6, Endian.little), xf: xf));
          }
        case 0x0201: // BLANK — değeri yok, BİÇİMİ var (dolgu/kenarlık).
          if (r.data.length >= 6) {
            put(d.getUint16(0, Endian.little), d.getUint16(2, Endian.little),
                XlsLegacyCell(xf: d.getUint16(4, Endian.little)));
          }
        case 0x00BE: // MULBLANK
          if (r.data.length >= 6) {
            final row = d.getUint16(0, Endian.little);
            final colFirst = d.getUint16(2, Endian.little);
            final count = (r.data.length - 6) ~/ 2;
            for (var k = 0; k < count; k++) {
              put(row, colFirst + k,
                  XlsLegacyCell(xf: d.getUint16(4 + k * 2, Endian.little)));
            }
          }
        case 0x0205: // BOOLERR
          if (r.data.length >= 8) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final xf = d.getUint16(4, Endian.little);
            final value = r.data[6];
            final isError = r.data[7] == 1;
            put(
              row,
              col,
              isError
                  ? XlsLegacyCell(error: _errorText(value), xf: xf)
                  : XlsLegacyCell(boolean: value != 0, xf: xf),
            );
          }
        case 0x0006: // FORMULA
          if (r.data.length >= 14) {
            final row = d.getUint16(0, Endian.little);
            final col = d.getUint16(2, Endian.little);
            final xf = d.getUint16(4, Endian.little);
            // Sonuç 8 bayt: son iki bayt 0xFFFF ise sayısal DEĞİL.
            final special = d.getUint16(12, Endian.little) == 0xFFFF;
            if (!special) {
              put(row, col,
                  XlsLegacyCell(number: d.getFloat64(6, Endian.little), xf: xf));
            } else {
              final kind = d.getUint8(6);
              if (kind == 0) {
                // Sonraki STRING kaydı metni taşır.
                final next = _skipToString(records, i);
                put(
                  row,
                  col,
                  XlsLegacyCell(
                      text: next == null ? '' : _unicodeString16(next, 0),
                      xf: xf),
                );
              } else if (kind == 1) {
                put(row, col,
                    XlsLegacyCell(boolean: d.getUint8(8) != 0, xf: xf));
              } else if (kind == 2) {
                put(row, col,
                    XlsLegacyCell(error: _errorText(d.getUint8(8)), xf: xf));
              } else {
                // 3 = boş dize
                put(row, col, XlsLegacyCell(text: '', xf: xf));
              }
            }
          }
        case 0x0208: // ROW — yükseklik + gizli
          if (r.data.length >= 16) {
            final row = d.getUint16(0, Endian.little);
            final miyRw = d.getUint16(6, Endian.little);
            final grbit = d.getUint16(12, Endian.little);
            if ((grbit & 0x0020) != 0) hiddenRows.add(row);
            // bit15 "varsayılan yükseklik" işareti; bit6 (fUnsynced) özel
            // yükseklik demek. Yalnız özel olanı yazıyoruz.
            if ((grbit & 0x0040) != 0) {
              final pt = (miyRw & 0x7FFF) / 20.0;
              if (pt > 0 && pt < 1000) rowHeights[row] = pt;
            }
          }
        case 0x007D: // COLINFO — genişlik + gizli
          if (r.data.length >= 10) {
            final first = d.getUint16(0, Endian.little);
            final last = d.getUint16(2, Endian.little);
            final coldx = d.getUint16(4, Endian.little);
            final grbit = d.getUint16(8, Endian.little);
            // coldx 1/256 karakter; Excel'in `width` birimi karakter.
            final chars = coldx / 256.0;
            for (var c = first; c <= last && c <= 16383; c++) {
              if (chars > 0 && chars < 300) colWidths[c] = chars;
              if ((grbit & 0x0001) != 0) hiddenCols.add(c);
            }
          }
        case 0x00E5: // MERGEDCELLS
          if (r.data.length >= 2) {
            final count = d.getUint16(0, Endian.little);
            for (var k = 0; k < count && 2 + k * 8 + 8 <= r.data.length; k++) {
              final b = 2 + k * 8;
              merges.add(XlsxWriteMerge(
                d.getUint16(b, Endian.little),
                d.getUint16(b + 4, Endian.little),
                d.getUint16(b + 2, Endian.little),
                d.getUint16(b + 6, Endian.little),
              ));
            }
          }
        case 0x023E: // WINDOW2
          if (r.data.length >= 2) {
            final grbit = d.getUint16(0, Endian.little);
            showGridLines = (grbit & 0x0002) != 0;
            frozen = (grbit & 0x0008) != 0;
            rightToLeft = (grbit & 0x0040) != 0;
          }
        case 0x0041: // PANE
          if (r.data.length >= 4) {
            frozenCols = d.getUint16(0, Endian.little);
            frozenRows = d.getUint16(2, Endian.little);
          }
      }
    }

    // Bölme yalnız "dondurulmuş" işaretliyken bölmedir; kaydırma bölmesi
    // (split) piksel cinsindendir ve satır/sütun sayısı değildir.
    if (!frozen) {
      frozenRows = 0;
      frozenCols = 0;
    }

    final rows = <List<String>>[];
    for (var r = 0; r <= maxRow; r++) {
      final rowMap = cells[r];
      final row = <String>[];
      for (var c = 0; c <= maxCol; c++) {
        row.add(rowMap?[c]?.raw ?? '');
      }
      rows.add(row);
    }

    return XlsLegacySheet(
      name,
      rows,
      cells: cells,
      colWidths: colWidths,
      rowHeights: rowHeights,
      hiddenCols: hiddenCols,
      hiddenRows: hiddenRows,
      merges: merges,
      frozenRows: frozenRows,
      frozenCols: frozenCols,
      hidden: hidden,
      rightToLeft: rightToLeft,
      showGridLines: showGridLines,
    );
  }

  /// FORMULA'yı izleyen STRING kaydının verisi (araya SHRFMLA/ARRAY gibi
  /// kayıtlar girebilir). Bulunamazsa null.
  static Uint8List? _skipToString(List<_Rec> records, int from) {
    for (var j = from + 1; j < records.length && j <= from + 4; j++) {
      if (records[j].type == 0x0207) return records[j].data;
      if (records[j].type == 0x0006 || records[j].type == 0x000A) break;
    }
    return null;
  }

  static String _errorText(int code) => switch (code) {
        0x00 => '#NULL!',
        0x07 => '#DIV/0!',
        0x0F => '#VALUE!',
        0x17 => '#REF!',
        0x1D => '#NAME?',
        0x24 => '#NUM!',
        0x2A => '#N/A',
        _ => '#N/A',
      };

  // --------------------------------------------------------------- yardımcı

  /// SST bloklarını okur.
  ///
  /// **CONTINUE tuzağı (2026-08-07 düzeltmesi):** BIFF8'de bir metin kayıt
  /// sınırında bölünebilir ve devam kaydı **1 baytlık yeni bir kodlama
  /// bayrağıyla** başlar. Eski sürüm blokları düz düz birleştiriyordu; ilk
  /// sınırdan sonraki bütün metinler kayıyor, büyük dosyalarda tablo
  /// anlamsızlaşıyordu. Artık okuma blok sınırını biliyor: karakter verisi
  /// sınırı geçerken bayrak baytı tüketilip kodlama güncelleniyor.
  static void _parseSst(List<Uint8List> blocks, List<String> out) {
    if (blocks.isEmpty || blocks.first.length < 8) return;
    final cursor = _SstCursor(blocks);
    final first = ByteData.sublistView(blocks.first);
    final unique = first.getUint32(4, Endian.little);
    cursor.skip(8);

    for (var i = 0; i < unique; i++) {
      final header = cursor.take(3);
      if (header == null) return;
      final cch = header[0] | (header[1] << 8);
      final flags = header[2];
      var high = (flags & 0x01) != 0;
      final ext = (flags & 0x04) != 0;
      final rich = (flags & 0x08) != 0;

      var cRun = 0;
      var cbExt = 0;
      if (rich) {
        final b = cursor.take(2);
        if (b == null) return;
        cRun = b[0] | (b[1] << 8);
      }
      if (ext) {
        final b = cursor.take(4);
        if (b == null) return;
        cbExt = b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24);
      }

      final chars = <int>[];
      for (var k = 0; k < cch; k++) {
        // Blok bittiyse: devam kaydının ilk baytı yeni kodlama bayrağıdır.
        if (cursor.atBlockEnd) {
          final flag = cursor.nextBlockFlag();
          if (flag == null) {
            out.add(String.fromCharCodes(chars));
            return;
          }
          high = (flag & 0x01) != 0;
        }
        final b = cursor.take(high ? 2 : 1);
        if (b == null) {
          out.add(String.fromCharCodes(chars));
          return;
        }
        chars.add(high ? (b[0] | (b[1] << 8)) : b[0]);
      }
      out.add(String.fromCharCodes(chars));
      // Zengin metin çalışmaları ve uzak-doğu fonetik verisi atlanır (bunlar
      // bölünürken bayrak baytı YOKTUR — düz atlama doğru).
      cursor.skip(cRun * 4 + cbExt);
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

  /// Sayının ham metin karşılığı (biçim UYGULANMAZ).
  static String numText(double v) {
    if (!v.isFinite) return '';
    if (v == v.roundToDouble() && v.abs() < 1e15) return v.toStringAsFixed(0);
    return v.toString();
  }

  /// BIFF8 varsayılan renk paleti (icv indeksi → ARGB). 0–7 sabit, 8–63
  /// PALETTE kaydıyla değiştirilebilir.
  static const List<int> _defaultPalette = [
    0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00, 0xFF0000FF, 0xFFFFFF00,
    0xFFFF00FF, 0xFF00FFFF, 0xFF000000, 0xFFFFFFFF, 0xFFFF0000, 0xFF00FF00,
    0xFF0000FF, 0xFFFFFF00, 0xFFFF00FF, 0xFF00FFFF, 0xFF800000, 0xFF008000,
    0xFF000080, 0xFF808000, 0xFF800080, 0xFF008080, 0xFFC0C0C0, 0xFF808080,
    0xFF9999FF, 0xFF993366, 0xFFFFFFCC, 0xFFCCFFFF, 0xFF660066, 0xFFFF8080,
    0xFF0066CC, 0xFFCCCCFF, 0xFF000080, 0xFFFF00FF, 0xFFFFFF00, 0xFF00FFFF,
    0xFF800080, 0xFF800000, 0xFF008080, 0xFF0000FF, 0xFF00CCFF, 0xFFCCFFFF,
    0xFFCCFFCC, 0xFFFFFF99, 0xFF99CCFF, 0xFFFF99CC, 0xFFCC99FF, 0xFFFFCC99,
    0xFF3366FF, 0xFF33CCCC, 0xFF99CC00, 0xFFFFCC00, 0xFFFF9900, 0xFFFF6600,
    0xFF666699, 0xFF969696, 0xFF003366, 0xFF339966, 0xFF003300, 0xFF333300,
    0xFF993300, 0xFF993366, 0xFF333399, 0xFF333333,
  ];
}

/// SST bloklarında gezinen imleç — blok sınırını **bilir** (CONTINUE bayrağı).
class _SstCursor {
  final List<Uint8List> blocks;
  int _block = 0;
  int _pos = 0;

  _SstCursor(this.blocks);

  /// Şu anki blok bitti ve arkasında devam bloğu var mı? (Karakter verisi
  /// tam burada bölünmüştür.)
  bool get atBlockEnd =>
      _block < blocks.length &&
      _pos >= blocks[_block].length &&
      _block + 1 < blocks.length;

  /// Devam bloğuna geçip ilk baytını (kodlama bayrağı) tüketir.
  int? nextBlockFlag() {
    if (!atBlockEnd) return null;
    _block++;
    _pos = 0;
    if (_pos >= blocks[_block].length) return null;
    return blocks[_block][_pos++];
  }

  /// [n] bayt okur; blok sınırını sessizce geçer (bayrak tüketmez).
  Uint8List? take(int n) {
    final out = Uint8List(n);
    for (var i = 0; i < n; i++) {
      if (!_advance()) return null;
      out[i] = blocks[_block][_pos++];
    }
    return out;
  }

  void skip(int n) {
    for (var i = 0; i < n; i++) {
      if (!_advance()) return;
      _pos++;
    }
  }

  bool _advance() {
    while (_block < blocks.length && _pos >= blocks[_block].length) {
      _block++;
      _pos = 0;
    }
    return _block < blocks.length;
  }
}

/// FONT kaydı.
class _Font {
  final double size;
  final bool bold;
  final bool italic;
  final bool underline;
  final bool strike;
  final int colorIndex;
  final String name;

  const _Font({
    required this.size,
    required this.bold,
    required this.italic,
    required this.underline,
    required this.strike,
    required this.colorIndex,
    required this.name,
  });

  static _Font parse(Uint8List data) {
    final d = ByteData.sublistView(data);
    final dyHeight = d.getUint16(0, Endian.little);
    final grbit = d.getUint16(2, Endian.little);
    final icv = d.getUint16(4, Endian.little);
    final bls = d.getUint16(6, Endian.little);
    final uls = data.length > 10 ? data[10] : 0;
    return _Font(
      size: dyHeight / 20.0,
      bold: bls >= 700,
      italic: (grbit & 0x0002) != 0,
      underline: uls != 0,
      strike: (grbit & 0x0008) != 0,
      colorIndex: icv,
      name: data.length > 14 ? XlsLegacy._shortUnicode(data, 14) : '',
    );
  }
}

/// XF (hücre biçimi) kaydı.
class _Xf {
  final int fontIndex;
  final int formatIndex;
  final int hAlign;
  final int vAlign;
  final bool wrap;
  final int indent;
  final int fillPattern;
  final int fillForeIndex;

  const _Xf({
    required this.fontIndex,
    required this.formatIndex,
    required this.hAlign,
    required this.vAlign,
    required this.wrap,
    required this.indent,
    required this.fillPattern,
    required this.fillForeIndex,
  });

  static _Xf parse(Uint8List data) {
    final d = ByteData.sublistView(data);
    final align = data[6];
    final indentByte = data[8];
    // 14–17: icvTop:7 icvBottom:7 icvDiag:7 dgDiag:4 fls:6 → en üst 6 bit
    // dolgu desenidir.
    final borderFill = d.getUint32(14, Endian.little);
    final fillColors = d.getUint16(18, Endian.little);
    return _Xf(
      fontIndex: d.getUint16(0, Endian.little),
      formatIndex: d.getUint16(2, Endian.little),
      hAlign: align & 0x07,
      vAlign: (align >> 4) & 0x07,
      wrap: (align & 0x08) != 0,
      indent: indentByte & 0x0F,
      fillPattern: (borderFill >> 26) & 0x3F,
      fillForeIndex: fillColors & 0x7F,
    );
  }

  /// Bu XF'in ekranda/dosyada karşılığı.
  XlsxWriteStyle toStyle(
      List<_Font> fonts, Map<int, String> formats, List<int> palette) {
    // BIFF8'de 4 numaralı yazı tipi indeksi YOKTUR: 4 ve üstü bir kayar.
    final fi = fontIndex >= 4 ? fontIndex - 1 : fontIndex;
    final font = fi >= 0 && fi < fonts.length ? fonts[fi] : null;
    final code = formats[formatIndex] ??
        builtinNumberFormats[formatIndex] ??
        'General';
    int? color(int index) {
      // 0x7FFF = "otomatik" (tema rengi) — dokunma.
      if (index >= 0x40) return null;
      return index >= 0 && index < palette.length ? palette[index] : null;
    }

    return XlsxWriteStyle(
      bold: font?.bold ?? false,
      italic: font?.italic ?? false,
      underline: font?.underline ?? false,
      strike: font?.strike ?? false,
      fontSize: font?.size,
      fontName: (font?.name.isNotEmpty ?? false) ? font!.name : null,
      fontArgb: font == null ? null : color(font.colorIndex),
      // Desen 0 = dolgu yok; diğer desenler ön renkle yaklaşık gösterilir
      // (Excel'in 18 deseni için ayrı çizim yapmıyoruz — bilinçli sınır).
      fillArgb: fillPattern == 0 ? null : color(fillForeIndex),
      numFmtCode: code,
      hAlign: switch (hAlign) {
        1 => 'left',
        2 => 'center',
        3 => 'right',
        5 => 'justify',
        6 => 'center',
        _ => '',
      },
      vAlign: switch (vAlign) {
        0 => 'top',
        1 => 'center',
        3 => 'justify',
        _ => '',
      },
      wrap: wrap,
      indent: indent,
    );
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
  final bool hidden;
  _Bound(this.name, this.pos, this.hidden);
}

/// **CSV/TSV düzenleme** (Faz 27 madde 11): dosya Excel ızgarasında açılır,
/// kaydette ÖZGÜN biçimiyle geri yazılır — ayraç, kodlama (BOM dahil), satır
/// sonu, son satır sonu ve "her alan tırnaklı" düzeni korunur. Biçim (renk,
/// kenarlık…) CSV'de saklanamaz; ekran bunu söyler.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'csv_codec.dart';
import 'text_decode.dart';

enum CsvEncoding { utf8, utf8Bom, utf16le, utf16be, cp1254 }

/// Dosyanın yazım biçimi (okurken bulunur, yazarken aynen kullanılır).
class CsvFormat {
  final String delimiter;
  final CsvEncoding encoding;
  final String eol;
  final bool trailingNewline;
  final bool quoteAll;

  /// Özgün en geniş satırın alan sayısı (sondaki boş alanlar kaybolmasın;
  /// ızgaranın boş sütun payı da yazılmasın).
  final int columns;

  /// Özgün satır sayısı (sondaki boş satırlar yazılmasın).
  final int rows;

  const CsvFormat({
    this.delimiter = ',',
    this.encoding = CsvEncoding.utf8,
    this.eol = '\r\n',
    this.trailingNewline = false,
    this.quoteAll = false,
    this.columns = 0,
    this.rows = 0,
  });

  String get encodingLabel => switch (encoding) {
        CsvEncoding.utf8 => 'UTF-8',
        CsvEncoding.utf8Bom => 'UTF-8 (BOM)',
        CsvEncoding.utf16le => 'UTF-16 LE',
        CsvEncoding.utf16be => 'UTF-16 BE',
        CsvEncoding.cp1254 => 'Windows-1254',
      };
}

class CsvDocument {
  final CsvFormat format;
  final List<List<String>> rows;
  const CsvDocument(this.format, this.rows);

  /// Baytları çözer; [tsv] ise ayraç sekme (uzantıdan).
  static CsvDocument parse(Uint8List bytes, {bool tsv = false}) {
    final enc = _encodingOf(bytes);
    final text = TextDecode.decode(bytes);
    final delimiter = tsv ? '\t' : CsvCodec.detectDelimiter(text);
    final rows = CsvCodec.parse(text, delimiter: delimiter);
    final crlf = text.contains('\r\n');
    final eol = crlf ? '\r\n' : (text.contains('\n') ? '\n' : '\r\n');
    final trailing = text.endsWith('\n') || text.endsWith('\r');
    // "Her alan tırnaklı" düzeni: ilk kaydın her alanı tırnakla başlıyorsa.
    final firstLine = text.split(RegExp(r'\r?\n')).first;
    final quoteAll = firstLine.isNotEmpty &&
        firstLine.startsWith('"') &&
        firstLine.trimRight().endsWith('"') &&
        (rows.isEmpty ||
            rows.first.length <= 1 ||
            firstLine.contains('"$delimiter"'));
    var cols = 0;
    for (final r in rows) {
      if (r.length > cols) cols = r.length;
    }
    return CsvDocument(
      CsvFormat(
        delimiter: delimiter,
        encoding: enc,
        eol: eol,
        trailingNewline: trailing,
        quoteAll: quoteAll,
        columns: cols,
        rows: rows.length,
      ),
      rows,
    );
  }

  static CsvEncoding _encodingOf(List<int> b) {
    if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return CsvEncoding.utf16le;
    if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return CsvEncoding.utf16be;
    if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) {
      return CsvEncoding.utf8Bom;
    }
    try {
      utf8.decode(b);
      return CsvEncoding.utf8;
    } on FormatException {
      return CsvEncoding.cp1254;
    }
  }

  /// [cells] (ızgaranın ham değerleri) özgün biçimle baytlara.
  static Uint8List encode(List<List<String>> cells, CsvFormat f) {
    // Sondaki tamamen boş satırlar (ızgaranın boş payı) yazılmaz — özgün
    // dosyadaki satır sayısının altına inilmez.
    var last = cells.length - 1;
    while (last >= f.rows && last >= 0 && cells[last].every((v) => v.isEmpty)) {
      last--;
    }
    var width = f.columns;
    for (var r = 0; r <= last; r++) {
      final row = cells[r];
      for (var c = row.length - 1; c >= 0; c--) {
        if (row[c].isNotEmpty) {
          if (c + 1 > width) width = c + 1;
          break;
        }
      }
    }
    final sb = StringBuffer();
    for (var r = 0; r <= last; r++) {
      final row = cells[r];
      // Dikdörtgen yazılır (özgün en geniş satır kadar): Excel de böyle yazar;
      // düzensiz (kısa satırlı) bir dosya boş alanlarla tamamlanır.
      for (var c = 0; c < width; c++) {
        if (c > 0) sb.write(f.delimiter);
        final v = c < row.length ? row[c] : '';
        sb.write(_escape(v, f));
      }
      if (r < last || f.trailingNewline) sb.write(f.eol);
    }
    final text = sb.toString();
    return Uint8List.fromList(switch (f.encoding) {
      CsvEncoding.utf8 => utf8.encode(text),
      CsvEncoding.utf8Bom => [0xEF, 0xBB, 0xBF, ...utf8.encode(text)],
      CsvEncoding.utf16le => [
          0xFF,
          0xFE,
          for (final u in text.codeUnits) ...[u & 0xFF, u >> 8],
        ],
      CsvEncoding.utf16be => [
          0xFE,
          0xFF,
          for (final u in text.codeUnits) ...[u >> 8, u & 0xFF],
        ],
      CsvEncoding.cp1254 => TextDecode.encodeCp1254(text),
    });
  }

  static String _escape(String v, CsvFormat f) {
    final needs = f.quoteAll ||
        v.contains(f.delimiter) ||
        v.contains('"') ||
        v.contains('\n') ||
        v.contains('\r');
    return needs ? '"${v.replaceAll('"', '""')}"' : v;
  }
}

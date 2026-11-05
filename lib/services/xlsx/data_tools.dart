/// **Excel veri araçları (pro)** — Faz 36 madde 8: CSV/TSV/ODS içe aktarma
/// sihirbazı (ayraç, kodlama, başlık, tür önizlemesi), ara toplam, satır
/// gruplama (anahat). Saf + testli; UI `spreadsheet/pro_data.dart`.
/// (Yinelenenleri kaldır ve metni sütunlara böl zaten vardı — Faz 27.)
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

import '../csv_codec.dart';
import '../text_decode.dart';

/// Sütunun önizlemedeki türü.
enum ColumnType { text, number, date, empty }

class ImportOptions {
  /// `null` → otomatik.
  final String? delimiter;

  /// `auto` | `utf8` | `cp1254`.
  final String encoding;
  final bool header;
  const ImportOptions({this.delimiter, this.encoding = 'auto', this.header = true});
}

abstract final class SheetImport {
  static String decode(Uint8List bytes, String encoding) => switch (encoding) {
        'utf8' => TextDecode.stripBom(utf8.decode(bytes, allowMalformed: true)),
        'cp1254' => TextDecode.decodeCp1254(bytes),
        _ => TextDecode.decode(bytes),
      };

  static List<List<String>> parseText(Uint8List bytes, ImportOptions o) {
    final text = decode(bytes, o.encoding);
    return CsvCodec.parse(text,
        delimiter: o.delimiter ?? CsvCodec.detectDelimiter(text));
  }

  /// Saf: değerden tür (Türkçe/İngilizce sayı, gg.aa.yyyy / yyyy-aa-gg).
  static ColumnType typeOf(String v) {
    final t = v.trim();
    if (t.isEmpty) return ColumnType.empty;
    if (RegExp(r'^\d{1,2}[./-]\d{1,2}[./-]\d{2,4}$').hasMatch(t) ||
        RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(t)) {
      return ColumnType.date;
    }
    final num = t.replaceAll(RegExp(r'[\s₺$€£%]|TL', caseSensitive: false), '');
    if (RegExp(r'^-?(\d+|\d{1,3}([.,]\d{3})+)([.,]\d+)?$').hasMatch(num)) {
      return ColumnType.number;
    }
    return ColumnType.text;
  }

  /// Sütun türleri: boş olmayan değerlerin hepsi aynı türse o, değilse metin.
  static List<ColumnType> columnTypes(List<List<String>> rows,
      {bool header = true, int sample = 200}) {
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    final out = List<ColumnType>.filled(width, ColumnType.empty);
    final body = rows.skip(header ? 1 : 0).take(sample);
    for (var c = 0; c < width; c++) {
      ColumnType? seen;
      for (final r in body) {
        final t = typeOf(c < r.length ? r[c] : '');
        if (t == ColumnType.empty) continue;
        if (seen == null) {
          seen = t;
        } else if (seen != t) {
          seen = ColumnType.text;
          break;
        }
      }
      out[c] = seen ?? ColumnType.empty;
    }
    return out;
  }

  /// ODS (OpenDocument hesap tablosu) → sayfa adı → satırlar. Yinelenen
  /// satır/hücre (`number-*-repeated`) açılır; sondaki boşluk yinelemeleri
  /// (dosya sonuna dek uzanan biçim satırları) kırpılır.
  static Map<String, List<List<String>>> parseOds(Uint8List bytes) {
    final zip = ZipDecoder().decodeBytes(bytes);
    final content = zip.files.where((f) => f.name == 'content.xml').firstOrNull;
    if (content == null) throw const FormatException('content.xml yok');
    final doc = XmlDocument.parse(
        utf8.decode(content.content as List<int>, allowMalformed: true));
    String? attr(XmlElement e, String local) {
      for (final a in e.attributes) {
        if (a.name.local == local) return a.value;
      }
      return null;
    }

    final out = <String, List<List<String>>>{};
    for (final table in doc.descendants.whereType<XmlElement>()) {
      if (table.name.local != 'table') continue;
      final name = attr(table, 'name') ?? 'Sheet${out.length + 1}';
      final rows = <List<String>>[];
      for (final row in table.descendants.whereType<XmlElement>()) {
        if (row.name.local != 'table-row') continue;
        final cells = <String>[];
        for (final cell in row.childElements) {
          if (cell.name.local != 'table-cell' &&
              cell.name.local != 'covered-table-cell') {
            continue;
          }
          final type = attr(cell, 'value-type');
          var text = switch (type) {
            'float' || 'percentage' || 'currency' => attr(cell, 'value') ?? '',
            'date' => attr(cell, 'date-value') ?? '',
            'boolean' => (attr(cell, 'boolean-value') ?? '') == 'true' ? 'TRUE' : 'FALSE',
            _ => [
                for (final p in cell.childElements)
                  if (p.name.local == 'p') p.innerText,
              ].join('\n'),
          };
          if (type == 'date' && text.length >= 10) text = text.substring(0, 10);
          final rep = (int.tryParse(attr(cell, 'number-columns-repeated') ?? '') ?? 1)
              .clamp(1, 1024)
              .toInt();
          for (var k = 0; k < rep; k++) {
            cells.add(text);
          }
        }
        while (cells.isNotEmpty && cells.last.isEmpty) {
          cells.removeLast();
        }
        final rep = (int.tryParse(attr(row, 'number-rows-repeated') ?? '') ?? 1)
            .clamp(1, 100000)
            .toInt();
        for (var k = 0; k < rep; k++) {
          rows.add(List.of(cells));
        }
      }
      while (rows.isNotEmpty && rows.last.isEmpty) {
        rows.removeLast();
      }
      out[name] = rows;
    }
    return out;
  }
}

/// Ara toplam: grup sütunu değiştikçe altına `=SUBTOTAL(9; …)` satırı.
abstract final class Subtotals {
  /// [rows] başlıklı veri (ilk satır başlık); [groupCol] ve [sumCols] veri
  /// aralığındaki göreli sütunlar. [top]/[left] aralığın sayfadaki yeri
  /// (formüllerin mutlak başvuruları için). Sonuç: yeni satırlar (ham
  /// değer/formül) — çağıran aralığın yerine yazar.
  static List<List<String>> build(
    List<List<String>> rows, {
    required int groupCol,
    required List<int> sumCols,
    required int top,
    required int left,
    String totalSuffix = ' Toplam',
    String grandLabel = 'Genel Toplam',
    String Function(int c)? colName,
  }) {
    if (rows.isEmpty) return rows;
    final name = colName ?? _col;
    final width = rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
    List<String> padded(List<String> r) =>
        [...r, for (var i = r.length; i < width; i++) ''];
    final out = <List<String>>[padded(rows.first)];
    var groupStart = 1; // out içindeki ilk veri satırı
    String? current;
    final groupTotalRows = <int>[];
    void close() {
      if (current == null) return;
      final sheetFirst = top + groupStart;
      final sheetLast = top + out.length - 1;
      final line = List<String>.filled(width, '');
      line[groupCol] = '$current$totalSuffix';
      for (final c in sumCols) {
        final col = name(left + c);
        line[c] = '=SUBTOTAL(9,$col${sheetFirst + 1}:$col${sheetLast + 1})';
      }
      out.add(line);
      groupTotalRows.add(out.length - 1);
    }

    for (final r in rows.skip(1)) {
      final key = groupCol < r.length ? r[groupCol].trim() : '';
      if (current != null && key != current) {
        close();
        groupStart = out.length;
      }
      current = key;
      out.add(padded(r));
    }
    close();
    final grand = List<String>.filled(width, '');
    grand[groupCol] = grandLabel;
    for (final c in sumCols) {
      final col = name(left + c);
      // SUBTOTAL başka SUBTOTAL'ları saymaz → tüm aralık güvenle toplanır.
      grand[c] = '=SUBTOTAL(9,$col${top + 2}:$col${top + out.length})';
    }
    out.add(grand);
    return out;
  }

  static String _col(int index) {
    var n = index + 1;
    var s = '';
    while (n > 0) {
      final m = (n - 1) % 26;
      s = String.fromCharCode(65 + m) + s;
      n = (n - 1) ~/ 26;
    }
    return s;
  }
}

/// Not yorum dizisi: yanıtlar notun sonuna tarihli satır olarak eklenir
/// (xlsx notu tek metindir; Excel'de de okunur kalır).
abstract final class NoteThread {
  static String appendReply(String text, String author, String reply, DateTime at) {
    String two(int v) => v.toString().padLeft(2, '0');
    final when = '${two(at.day)}.${two(at.month)}.${at.year} ${two(at.hour)}:${two(at.minute)}';
    final line = '— $author ($when): ${reply.trim()}';
    return text.trim().isEmpty ? line : '${text.trimRight()}\n$line';
  }

  /// Satırlara ayrılmış dizi: ilk satır(lar) asıl not, `— ` ile başlayanlar yanıt.
  static int replyCount(String text) =>
      text.split('\n').where((l) => l.startsWith('— ')).length;
}

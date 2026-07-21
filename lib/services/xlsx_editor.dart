import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter/painting.dart' show TextAlign;
import 'package:xml/xml.dart';

/// Bir hücrenin Excel'deki görünümü (yazı tipi, renk, hizalama).
class XlsxCellStyle {
  final bool bold;
  final bool italic;
  final double? fontSize;
  final Color? fontColor;
  final Color? background;
  final TextAlign align;
  const XlsxCellStyle({
    this.bold = false,
    this.italic = false,
    this.fontSize,
    this.fontColor,
    this.background,
    this.align = TextAlign.left,
  });
}

/// Birleştirilmiş hücre aralığı (0 tabanlı, uçlar dahil).
class XlsxMerge {
  final int rowStart, colStart, rowEnd, colEnd;
  const XlsxMerge(this.rowStart, this.colStart, this.rowEnd, this.colEnd);
  bool covers(int r, int c) =>
      r >= rowStart && r <= rowEnd && c >= colStart && c <= colEnd;
  bool isAnchor(int r, int c) => r == rowStart && c == colStart;
}

class XlsxSheet {
  final String name;
  final List<List<String>> rows;
  final Sheet _sheet;
  final List<XlsxMerge> merges;

  /// Hücre → Excel sayı biçim kodu (ör. "0%", "#,##0.00", "\"₺\"#,##0.00").
  /// Anahtar: [_key]. Yalnızca sayı/para/yüzde biçimli hücreler; tarihler
  /// excel paketinin verdiği gösterimle bırakılır. Boşsa biçimleme yapılmaz.
  final Map<int, String> numFmts;

  XlsxSheet(this.name, this.rows, this._sheet, this.merges,
      [this.numFmts = const {}]);

  int get maxCols => rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);

  static int _key(int r, int c) => r * 16384 + c;

  /// Bu hücrenin sayı biçim kodu (varsa). Tarih/genel biçimler için null döner.
  String? numFmtCode(int r, int c) => numFmts[_key(r, c)];

  /// Hücrede **Excel'de göründüğü gibi** metin. [computed] formül motorunun
  /// verdiği ham sonuçtur; bu değer sayıysa ve hücrenin bir sayı biçimi varsa
  /// (yüzde/para/binlik/ondalık) o biçim uygulanır. Aksi halde [computed] aynen
  /// döner (metin, tarih ve biçimsiz sayılar değişmez).
  String displayText(int r, int c, String computed) {
    final code = numFmtCode(r, c);
    if (code == null || computed.isEmpty) return computed;
    final v = double.tryParse(computed);
    if (v == null) return computed;
    return applyNumberFormat(code, v) ?? computed;
  }

  /// Excel sütun genişliği "karakter" birimindedir; ekran pikseline çevrilir.
  /// Dosyada `defaultColWidth` yoksa excel paketi null hatası fırlatır — o yüzden
  /// korumalı (gerçek dosyalarda görüldü, bkz. HAFIZA).
  double colWidth(int c) {
    double w;
    try {
      w = _sheet.getColumnWidth(c);
    } catch (_) {
      w = 8.43; // Excel varsayılanı
    }
    return (w * 7.2 + 10).clamp(28, 420);
  }

  /// Satır yüksekliği puntodur (varsayılan 15 pt).
  double rowHeight(int r) {
    double h;
    try {
      h = _sheet.getRowHeight(r);
    } catch (_) {
      h = 15;
    }
    return (h * 1.34).clamp(22, 240);
  }

  XlsxCellStyle? styleAt(int r, int c) {
    if (r >= _sheet.rows.length) return null;
    final row = _sheet.rows[r];
    if (c >= row.length) return null;
    final cell = row[c];
    final style = cell?.cellStyle;
    if (style == null) return null;

    var align = switch (style.horizontalAlignment) {
      HorizontalAlign.Center => TextAlign.center,
      HorizontalAlign.Right => TextAlign.right,
      HorizontalAlign.Left => TextAlign.left,
    };
    // Excel sayıları ve tarihleri varsayılan olarak sağa yaslar. Açık hizalama
    // okunamıyor (excel paketi hatası, bkz. HAFIZA), en azından varsayılanı doğru yap.
    if (align == TextAlign.left && _isNumeric(cell?.value)) {
      align = TextAlign.right;
    }

    return XlsxCellStyle(
      bold: style.isBold,
      italic: style.isItalic,
      fontSize: style.fontSize?.toDouble(),
      fontColor: _color(style.fontColor.colorHex),
      background: _color(style.backgroundColor.colorHex),
      align: align,
    );
  }

  static bool _isNumeric(CellValue? v) =>
      v is IntCellValue ||
      v is DoubleCellValue ||
      v is DateCellValue ||
      v is TimeCellValue ||
      v is DateTimeCellValue;
}

/// .xlsx dosyasını hücre bazında düzenler ve kaydeder (excel paketi ile).
class XlsxEditor {
  final Excel _excel;
  final List<XlsxSheet> sheets;

  XlsxEditor._(this._excel, this.sheets);

  static XlsxEditor parse(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    // Sayı biçimleri (yüzde/para/binlik) excel paketinde okunamıyor; ham XML'den
    // ayrıca çıkarılır. Bozuk/eksikse sessizce boş kalır (biçimleme yapılmaz).
    Map<String, Map<int, String>> fmts = const {};
    try {
      fmts = _readNumberFormats(bytes);
    } catch (_) {
      fmts = const {};
    }
    return XlsxEditor._(excel, _buildSheets(excel, fmts));
  }

  /// excel nesnesindeki tüm sayfaları okunabilir modele çevirir.
  static List<XlsxSheet> _buildSheets(
      Excel excel, Map<String, Map<int, String>> fmts) {
    final sheets = <XlsxSheet>[];
    for (final entry in excel.tables.entries) {
      final rows = <List<String>>[];
      for (final row in entry.value.rows) {
        rows.add(row.map(_cellText).toList());
      }
      sheets.add(XlsxSheet(
        entry.key,
        rows,
        entry.value,
        _merges(entry.value.spannedItems),
        fmts[entry.key] ?? const {},
      ));
    }
    return sheets;
  }

  XlsxSheet? _modelSheet(String name) {
    for (final s in sheets) {
      if (s.name == name) return s;
    }
    return null;
  }

  /// Hücre değerini Excel'de göründüğü gibi metne çevirir.
  static String _cellText(Data? cell) {
    final v = cell?.value;
    return switch (v) {
      null => '',
      TextCellValue() => v.value.toString(), // zengin metin parçalarını birleştirir
      IntCellValue() => '${v.value}',
      DoubleCellValue() => _trimNumber(v.value),
      BoolCellValue() => v.value ? 'DOĞRU' : 'YANLIŞ',
      DateCellValue() => '${_pad2(v.day)}.${_pad2(v.month)}.${v.year}',
      TimeCellValue() => '${_pad2(v.hour)}:${_pad2(v.minute)}',
      DateTimeCellValue() =>
        '${_pad2(v.day)}.${_pad2(v.month)}.${v.year} ${_pad2(v.hour)}:${_pad2(v.minute)}',
      // Formül çubuğunda Excel gibi baştaki '=' ile gösterilir. Sonuç cihazda
      // hesaplanmaz (offline, ücretsiz); PowerPoint/Excel dosyayı açınca hesaplar.
      FormulaCellValue() => '=${v.formula}',
    };
  }

  static String _pad2(int n) => n.toString().padLeft(2, '0');

  /// 12.0 -> "12", 12.50 -> "12.5" (Excel de gereksiz sıfırı göstermez).
  static String _trimNumber(double d) {
    if (d == d.roundToDouble() && d.abs() < 1e15) return d.toStringAsFixed(0);
    return d.toString();
  }

  static List<XlsxMerge> _merges(List<String> spans) {
    final out = <XlsxMerge>[];
    for (final s in spans) {
      final parts = s.split(':');
      if (parts.length != 2) continue;
      final a = _ref(parts[0]);
      final b = _ref(parts[1]);
      if (a == null || b == null) continue;
      out.add(XlsxMerge(a.$1, a.$2, b.$1, b.$2));
    }
    return out;
  }

  /// "B3" -> (satır 2, sütun 1)
  static (int, int)? _ref(String ref) {
    final m = RegExp(r'^([A-Z]+)(\d+)$').firstMatch(ref.toUpperCase());
    if (m == null) return null;
    var col = 0;
    for (final ch in m.group(1)!.codeUnits) {
      col = col * 26 + (ch - 64);
    }
    return (int.parse(m.group(2)!) - 1, col - 1);
  }

  /// Bir hücreyi günceller (hem model hem excel nesnesi).
  ///
  /// `=` ile başlayan değer **formül** olarak kaydedilir (ör. `=SUM(A1:A9)`);
  /// böyle bir hücreyi Excel/PowerPoint açtığında sonucu kendisi hesaplar.
  /// Sayı gibi görünen değer sayı olarak, gerisi metin olarak yazılır → dosyayı
  /// başka programda açınca doğru tipte görünür.
  void setCell(String sheetName, int rowIndex, int colIndex, String value) {
    final sheet = sheets.firstWhere((s) => s.name == sheetName);
    while (sheet.rows.length <= rowIndex) {
      sheet.rows.add(<String>[]);
    }
    final row = sheet.rows[rowIndex];
    while (row.length <= colIndex) {
      row.add('');
    }
    row[colIndex] = value;

    _excel.updateCell(
      sheetName,
      CellIndex.indexByColumnRow(columnIndex: colIndex, rowIndex: rowIndex),
      _cellValueFor(value),
    );
  }

  /// Kullanıcının yazdığı metni uygun Excel hücre tipine çevirir.
  static CellValue _cellValueFor(String value) {
    if (value.isEmpty) return TextCellValue('');
    if (value.length > 1 && value.startsWith('=')) {
      return FormulaCellValue(value.substring(1));
    }
    // Türkçe ondalık ayıracı (virgül) ve nokta ikisini de dener; ama başında
    // sıfır olan (ör. "007", telefon) veya çok uzun sayıları metin bırakır.
    final intVal = int.tryParse(value);
    if (intVal != null && !_looksLikeCode(value)) return IntCellValue(intVal);
    final dbl = double.tryParse(value);
    if (dbl != null && dbl.isFinite && !_looksLikeCode(value)) {
      return DoubleCellValue(dbl);
    }
    return TextCellValue(value);
  }

  /// "007", "0123", "+90..." gibi baştaki sıfır/işaret önemli olan diziler sayı
  /// değil metin sayılır (aksi halde anlam kaybolur).
  static bool _looksLikeCode(String v) {
    if (v.length > 1 && v.startsWith('0') && !v.startsWith('0.')) return true;
    if (v.length > 15) return true; // int precision sınırı
    return false;
  }

  // Yapısal işlemler hücreleri (değer + stil) elle kaydırarak yapılır ve model
  // doğrudan güncellenir. *Niye:* excel 4.0.6'nın Excel-seviye insertRow/
  // insertColumn'u bu dosyada no-op çıktı (sayaç değişmedi, bkz. HAFIZA); Sheet
  // hücre API'si (cell/value/cellStyle) ise güvenilir çalışıyor.

  /// [rowIndex] konumuna boş bir satır ekler (sonrakiler aşağı kayar).
  void insertRow(String sheetName, int rowIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    final at = rowIndex.clamp(0, model.rows.length);
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var r = maxR; r > at; r--) {
      for (var c = 0; c < maxC; c++) {
        _copyCell(table, r - 1, c, r, c);
      }
    }
    for (var c = 0; c < maxC; c++) {
      _clearCell(table, at, c);
    }
    model.rows.insert(at, List<String>.filled(model.maxCols, '', growable: true));
  }

  /// [rowIndex] satırını siler (sonrakiler yukarı kayar).
  void deleteRow(String sheetName, int rowIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    if (rowIndex < 0 || rowIndex >= model.rows.length) return;
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var r = rowIndex; r < maxR - 1; r++) {
      for (var c = 0; c < maxC; c++) {
        _copyCell(table, r + 1, c, r, c);
      }
    }
    if (maxR > 0) {
      for (var c = 0; c < maxC; c++) {
        _clearCell(table, maxR - 1, c);
      }
    }
    model.rows.removeAt(rowIndex);
  }

  /// [colIndex] konumuna boş bir sütun ekler (sonrakiler sağa kayar).
  void insertColumn(String sheetName, int colIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    final at = colIndex.clamp(0, model.maxCols);
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var c = maxC; c > at; c--) {
      for (var r = 0; r < maxR; r++) {
        _copyCell(table, r, c - 1, r, c);
      }
    }
    for (var r = 0; r < maxR; r++) {
      _clearCell(table, r, at);
    }
    for (final row in model.rows) {
      if (at <= row.length) row.insert(at, '');
    }
  }

  /// [colIndex] sütununu siler (sonrakiler sola kayar).
  void deleteColumn(String sheetName, int colIndex) {
    final table = _excel.tables[sheetName];
    final model = _modelSheet(sheetName);
    if (table == null || model == null) return;
    if (colIndex < 0 || colIndex >= model.maxCols) return;
    final maxR = table.maxRows;
    final maxC = table.maxColumns;
    for (var c = colIndex; c < maxC - 1; c++) {
      for (var r = 0; r < maxR; r++) {
        _copyCell(table, r, c + 1, r, c);
      }
    }
    if (maxC > 0) {
      for (var r = 0; r < maxR; r++) {
        _clearCell(table, r, maxC - 1);
      }
    }
    for (final row in model.rows) {
      if (colIndex < row.length) row.removeAt(colIndex);
    }
  }

  /// Bir hücrenin değerini ve stilini başka bir konuma kopyalar.
  static void _copyCell(Sheet t, int sr, int sc, int dr, int dc) {
    final src =
        t.cell(CellIndex.indexByColumnRow(columnIndex: sc, rowIndex: sr));
    final dst =
        t.cell(CellIndex.indexByColumnRow(columnIndex: dc, rowIndex: dr));
    dst.value = src.value;
    dst.cellStyle = src.cellStyle;
  }

  /// Bir hücrenin değerini boşaltır (stil el değmeden kalır).
  static void _clearCell(Sheet t, int r, int c) {
    t.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r)).value =
        null;
  }

  Uint8List save() {
    final bytes = _excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }

  // ------------------------------------------------------- sayı biçimleri

  /// Testler için: ham baytlardan sayfa→hücre→biçim kodu tablosunu okur.
  static Map<String, Map<int, String>> debugReadNumberFormats(Uint8List bytes) =>
      _readNumberFormats(bytes);

  /// Testler için hücre anahtarı üretir (satır, sütun; 0 tabanlı).
  static int debugCellKey(int r, int c) => XlsxSheet._key(r, c);

  /// .xlsx içinden hücre bazlı sayı biçim kodlarını okur.
  /// Dönüş: sayfa adı → (hücre anahtarı → biçim kodu). Yalnızca sayı/para/
  /// yüzde/binlik biçimleri saklanır; tarih ve genel biçimler dışarıda bırakılır
  /// (onları excel paketinin gösterimi karşılar).
  static Map<String, Map<int, String>> _readNumberFormats(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    XmlDocument? xml(String name) {
      for (final f in archive.files) {
        if (f.name == name) {
          try {
            return XmlDocument.parse(
                utf8.decode(f.content as List<int>, allowMalformed: true));
          } catch (_) {
            return null;
          }
        }
      }
      return null;
    }

    // styles.xml: numFmtId → kod, ve xf sırası → numFmtId.
    final styles = xml('xl/styles.xml');
    final codeById = <int, String>{..._builtinNumFmt};
    final xfFmtId = <int>[];
    if (styles != null) {
      for (final nf in styles.findAllElements('numFmt')) {
        final id = int.tryParse(nf.getAttribute('numFmtId') ?? '');
        final code = nf.getAttribute('formatCode');
        if (id != null && code != null) codeById[id] = code;
      }
      final cellXfsAll = styles.findAllElements('cellXfs');
      if (cellXfsAll.isNotEmpty) {
        for (final xf in cellXfsAll.first.findElements('xf')) {
          xfFmtId.add(int.tryParse(xf.getAttribute('numFmtId') ?? '0') ?? 0);
        }
      }
    }

    // workbook.xml + rels: sayfa adı → worksheet dosyası.
    final wb = xml('xl/workbook.xml');
    final rels = xml('xl/_rels/workbook.xml.rels');
    final relTarget = <String, String>{};
    if (rels != null) {
      for (final r in rels.rootElement.childElements) {
        final id = r.getAttribute('Id');
        final tgt = r.getAttribute('Target');
        if (id != null && tgt != null) relTarget[id] = tgt;
      }
    }

    final out = <String, Map<int, String>>{};
    if (wb == null) return out;
    for (final s in wb.findAllElements('sheet')) {
      final name = s.getAttribute('name');
      final rid = s.getAttribute('r:id') ?? s.getAttribute('id');
      if (name == null || rid == null) continue;
      var target = relTarget[rid];
      if (target == null) continue;
      if (target.startsWith('/')) {
        target = target.substring(1);
      } else {
        target = 'xl/${target.replaceFirst('./', '')}';
      }
      final ws = xml(target);
      if (ws == null) continue;

      final cells = <int, String>{};
      for (final c in ws.findAllElements('c')) {
        final ref = c.getAttribute('r');
        final sAttr = c.getAttribute('s');
        if (ref == null || sAttr == null) continue;
        final rc = _ref(ref);
        if (rc == null) continue;
        final xfIdx = int.tryParse(sAttr);
        if (xfIdx == null || xfIdx < 0 || xfIdx >= xfFmtId.length) continue;
        final code = codeById[xfFmtId[xfIdx]];
        // Yalnızca uyguladığımız biçimleri sakla (tarih/genel atlanır).
        if (code == null || !_isNumberFormat(code)) continue;
        cells[XlsxSheet._key(rc.$1, rc.$2)] = code;
      }
      if (cells.isNotEmpty) out[name] = cells;
    }
    return out;
  }
}

/// Yaygın yerleşik Excel sayı biçim kimlikleri → kod. Tarih/saat kimlikleri
/// (14-22, 45-47) bilinçli olarak dışarıda: onları excel paketi zaten
/// tarih/saat metnine çevirir, üstüne biçim uygulamayız.
const Map<int, String> _builtinNumFmt = {
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  9: '0%',
  10: '0.00%',
  37: '#,##0;(#,##0)',
  38: '#,##0;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  44: r'"₺"#,##0.00',
  // 5-8 para (yerel simge); genel karşılık:
  5: r'"₺"#,##0',
  6: r'"₺"#,##0',
  7: r'"₺"#,##0.00',
  8: r'"₺"#,##0.00',
};

/// Bir biçim kodunun bizim uyguladığımız türlerden (yüzde/para/binlik/ondalık)
/// biri olup olmadığını söyler. Tarih/saat/metin/genel için false.
bool _isNumberFormat(String code) {
  final c = code.split(';').first.trim();
  if (c.isEmpty || c == 'General' || c == '@') return false;
  // Tarih/saat göstergeleri → bizim işimiz değil.
  if (RegExp(r'[yYmMdDhHsS]').hasMatch(c) &&
      !RegExp(r'[#0]').hasMatch(c.replaceAll(RegExp(r'[eE]'), ''))) {
    return false;
  }
  // Tarih ayıraçları içeren tipik kodlar (ay/gün) — sayı işareti yoksa tarih say.
  return RegExp(r'[#0]').hasMatch(c);
}

/// Excel sayı biçim kodunu bir sayıya uygular ve **Türkçe gösterimle** (binlik
/// ayıracı `.`, ondalık `,`) metin döndürür. Uygulanamıyorsa null döner.
///
/// Desteklenen: yüzde (`0%`, `0.00%`), para (`"₺"#,##0.00`, `[$$-...]`), binlik
/// gruplama (`#,##0`), sabit ondalık (`0.00`), tam sayı (`0`). Bilimsel/özel
/// bölümlü kodlar için ilk bölüm kullanılır.
String? applyNumberFormat(String code, double value) {
  final section = code.split(';').first.trim();
  if (section.isEmpty || section == 'General' || section == '@') return null;

  final grouping = section.contains(',');
  final decimals = _decimalsOfFormat(section);

  if (section.contains('%')) {
    return '%${_trNumber(value * 100, decimals, grouping)}';
  }

  final symbol = _currencySymbol(section);
  final number = _trNumber(value, decimals, grouping);
  return symbol == null ? number : '$symbol$number';
}

/// Biçimin ondalık basamak sayısı (`.`den sonraki `0`/`#` adedi).
int _decimalsOfFormat(String section) {
  final dot = section.indexOf('.');
  if (dot == -1) return 0;
  var n = 0;
  for (var i = dot + 1; i < section.length; i++) {
    final ch = section[i];
    if (ch == '0' || ch == '#') {
      n++;
    } else {
      break;
    }
  }
  return n;
}

/// Biçimdeki para simgesini bulur: `[$₺-41F]`, tırnaklı `"₺"` ya da bilinen
/// simgelerden biri. Yoksa null (para değil).
String? _currencySymbol(String section) {
  final bracket = RegExp(r'\[\$([^\-\]]+)').firstMatch(section);
  if (bracket != null) return bracket.group(1);
  final quoted = RegExp(r'"([^"]+)"').firstMatch(section);
  if (quoted != null) {
    final q = quoted.group(1)!;
    for (final s in const ['₺', r'$', '€', '£', '¥', 'TL', 'USD', 'EUR']) {
      if (q.contains(s)) return q;
    }
  }
  for (final s in const ['₺', r'$', '€', '£', '¥']) {
    if (section.contains(s)) return s;
  }
  return null;
}

/// Bir sayıyı Türkçe biçimle metne çevirir: binlik `.`, ondalık `,`.
/// [group] false ise binlik ayıracı konmaz.
String _trNumber(double value, int decimals, bool group) {
  final negative = value < 0;
  final abs = value.abs();
  final fixed = abs.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  var intPart = parts[0];
  if (group) {
    final buf = StringBuffer();
    for (var i = 0; i < intPart.length; i++) {
      if (i > 0 && (intPart.length - i) % 3 == 0) buf.write('.');
      buf.write(intPart[i]);
    }
    intPart = buf.toString();
  }
  var out = intPart;
  if (decimals > 0) out = '$out,${parts[1]}';
  return negative ? '-$out' : out;
}

/// "FFRRGGBB" / "RRGGBB" -> Color. "none" veya bozuksa null.
Color? _color(String hex) {
  if (hex.isEmpty || hex.toLowerCase() == 'none') return null;
  var h = hex.replaceAll('#', '');
  if (h.length == 6) h = 'FF$h';
  if (h.length != 8) return null;
  final v = int.tryParse(h, radix: 16);
  return v == null ? null : Color(v);
}

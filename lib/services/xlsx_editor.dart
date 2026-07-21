import 'dart:typed_data';
import 'dart:ui' show Color;

import 'package:excel/excel.dart';
import 'package:flutter/painting.dart' show TextAlign;

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

  XlsxSheet(this.name, this.rows, this._sheet, this.merges);

  int get maxCols => rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);

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
      ));
    }
    return XlsxEditor._(excel, sheets);
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
      FormulaCellValue() => v.formula,
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
      TextCellValue(value),
    );
  }

  Uint8List save() {
    final bytes = _excel.encode();
    return Uint8List.fromList(bytes ?? const []);
  }
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

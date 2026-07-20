import 'dart:typed_data';

import 'package:excel/excel.dart';

class XlsxSheet {
  final String name;
  final List<List<String>> rows;
  XlsxSheet(this.name, this.rows);

  int get maxCols =>
      rows.fold<int>(0, (m, r) => r.length > m ? r.length : m);
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
        rows.add(row
            .map((c) => c?.value == null ? '' : c!.value.toString())
            .toList());
      }
      sheets.add(XlsxSheet(entry.key, rows));
    }
    return XlsxEditor._(excel, sheets);
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

import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Gerçek bir .xlsx üretir: metin, sayı, tarih, kalın+renkli başlık,
/// özel sütun genişliği ve birleştirilmiş hücre.
Uint8List _sampleXlsx() {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];

  sheet.cell(CellIndex.indexByString('A1')).value = TextCellValue('Başlık');
  sheet.cell(CellIndex.indexByString('A1')).cellStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.red,
    horizontalAlign: HorizontalAlign.Center,
  );
  sheet.cell(CellIndex.indexByString('A2')).value = IntCellValue(42);
  sheet.cell(CellIndex.indexByString('B2')).value = DoubleCellValue(3.50);
  sheet.cell(CellIndex.indexByString('C2')).value =
      DateCellValue(year: 2026, month: 7, day: 21);

  sheet.setColumnWidth(0, 25);
  sheet.merge(CellIndex.indexByString('A1'), CellIndex.indexByString('C1'));

  return Uint8List.fromList(excel.encode()!);
}

void main() {
  test('hücre değerleri Excel\'deki gibi metne çevrilir', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final s = e.sheets.first;

    expect(s.rows[0][0], 'Başlık');
    expect(s.rows[1][0], '42');
    expect(s.rows[1][1], '3.5'); // gereksiz sıfır atılır
    expect(s.rows[1][2], '21.07.2026'); // seri numara değil, tarih
  });

  test('stil, sütun genişliği ve birleştirme okunur', () {
    final s = XlsxEditor.parse(_sampleXlsx()).sheets.first;

    final style = s.styleAt(0, 0)!;
    expect(style.bold, isTrue);
    expect(style.fontColor, isNotNull);
    // Açık hizalama excel paketinin ayrıştırıcı hatası yüzünden okunamıyor
    // (parse.dart:445 <alignment> yerine üst düğüme bakıyor). Metin sola,
    // sayı/tarih sağa yaslanır — Excel'in varsayılanı.
    expect(style.align, TextAlign.left);
    expect(s.styleAt(1, 0)?.align, TextAlign.right); // 42 -> sayı
    expect(s.styleAt(1, 2)?.align, TextAlign.right); // tarih

    // 25 karakterlik sütun, varsayılandan (8.43) belirgin geniş olmalı.
    expect(s.colWidth(0), greaterThan(s.colWidth(3)));

    expect(s.merges, isNotEmpty);
    final m = s.merges.first;
    expect(m.isAnchor(0, 0), isTrue);
    expect(m.covers(0, 2), isTrue); // A1:C1
    expect(m.covers(1, 0), isFalse);
  });

  test('hücre düzenlemesi kaydedilen dosyaya yazılır', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final name = e.sheets.first.name;

    e.setCell(name, 1, 0, 'yeni değer');
    expect(e.sheets.first.rows[1][0], 'yeni değer');

    final again = XlsxEditor.parse(e.save());
    expect(again.sheets.first.rows[1][0], 'yeni değer');
  });
}

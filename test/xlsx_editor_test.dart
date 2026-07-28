import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
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
  test('ham değerler modelde HAM durur, gösterimde Excel gibi biçimlenir', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final s = e.sheets.first;

    // rows = formül motorunun girdisi → sayı ham (`3.5`), tarih seri numara.
    expect(s.rows[0][0], 'Başlık');
    expect(s.rows[1][0], '42');
    expect(s.rows[1][1], '3.5'); // gereksiz sıfır atılır

    // Gösterim katmanı hücrenin sayı biçimini uygular → Excel'deki görüntü.
    // (excel paketinin yazdığı tarih biçim kodu sürüme göre değişebildiği
    // için gün/ay/yıl parçaları aranıyor, tek bir dizgi değil.)
    final dateText = s.viewAt(1, 2, s.rows[1][2]).text;
    expect(dateText, contains('2026'));
    expect(dateText, contains('21'));
    expect(dateText, isNot(matches(RegExp(r'^\d{5}(\.\d+)?$'))));
    expect(s.viewAt(1, 0, s.rows[1][0]).text, '42');
  });

  test('stil, sütun genişliği ve birleştirme okunur', () {
    final s = XlsxEditor.parse(_sampleXlsx()).sheets.first;

    final style = s.styleAt(0, 0)!;
    expect(style.bold, isTrue);
    expect(style.fontColor, isNotNull);
    // Açık hizalama artık OKUNUYOR (kendi styles.xml okuyucumuz — excel
    // paketinin ayrıştırıcı hatası bizi bağlamıyor).
    expect(style.hAlign, XlsxHAlign.center);
    // Hizalaması olmayan hücrelerde Excel varsayılanı: sayı sağa, metin sola.
    expect(s.styleAt(1, 0)?.alignFor(true), TextAlign.right); // 42 -> sayı
    expect(s.styleAt(1, 0)?.alignFor(false), TextAlign.left);

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

  test('formül girişi kaydedilen dosyaya <f> olarak yazılır', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final name = e.sheets.first.name;

    e.setCell(name, 3, 0, '=SUM(A2:A3)');
    // Kaydedilen çalışma sayfası XML'i formülü içermeli → Excel açınca hesaplar.
    final saved = e.save();
    final archive = ZipDecoder().decodeBytes(saved);
    final sheetXml = archive.files
        .where((f) =>
            f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'))
        .map((f) => utf8.decode(f.content as List<int>, allowMalformed: true))
        .join();
    expect(sheetXml, contains('SUM(A2:A3)'));
  });

  test('sayı sayı tipinde, baştaki sıfırlı kod metin olarak saklanır', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final name = e.sheets.first.name;

    e.setCell(name, 4, 0, '1250');
    e.setCell(name, 4, 1, '007'); // kod/telefon: metin kalmalı
    final again = XlsxEditor.parse(e.save());
    // 1250 sayı olarak yazıldıysa yeniden okununca da 1250 döner.
    expect(again.sheets.first.rows[4][0], '1250');
    // "007" sayıya çevrilseydi "7" olurdu; metin kaldığı için sıfırlar korunur.
    expect(again.sheets.first.rows[4][1], '007');
  });

  test('satır ekleme/silme veriyi doğru taşır ve kaydeder', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final name = e.sheets.first.name;
    final before = e.sheets.first.rows.length; // 2

    // 1. indekse (2. satır) boş satır ekle → eski 42'li satır aşağı kayar.
    e.insertRow(name, 1);
    expect(e.sheets.first.rows.length, before + 1);
    expect(e.sheets.first.rows[2][0], '42');

    // Kalıcı: kaydedilip yeniden okununca 42 hâlâ 3. satırda (elle kaydırma
    // excel nesnesine de yazıldı).
    final afterInsert = XlsxEditor.parse(e.save());
    expect(afterInsert.sheets.first.rows[2][0], '42');

    // Aynı satırı sil → veri geri gelir.
    e.deleteRow(name, 1);
    expect(e.sheets.first.rows.length, before);
    expect(e.sheets.first.rows[1][0], '42');
  });

  test('sütun ekleme/silme veriyi doğru taşır', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final name = e.sheets.first.name;
    final cols = e.sheets.first.maxCols; // 3

    e.insertColumn(name, 0); // en başa sütun → 42 bir sağa kayar
    expect(e.sheets.first.maxCols, cols + 1);
    expect(e.sheets.first.rows[1][1], '42');

    e.deleteColumn(name, 0);
    expect(e.sheets.first.rows[1][0], '42');
  });

  test('setCellStyle kalın/italik/hizalamayı anında ve kalıcı uygular', () {
    final e = XlsxEditor.parse(_sampleXlsx());
    final s = e.sheets.first;

    e.setCellStyle(s.name, 1, 0, bold: true, align: TextAlign.center);
    var st = s.styleAt(1, 0)!;
    expect(st.bold, isTrue); // görünüm önbelleği anında güncellendi
    expect(st.hAlign, XlsxHAlign.center);

    // Dokunulmayan özellik korunur: italic hâlâ kapalı.
    expect(st.italic, isFalse);
    e.setCellStyle(s.name, 1, 0, italic: true);
    st = s.styleAt(1, 0)!;
    expect(st.bold, isTrue); // bold silinmedi
    expect(st.italic, isTrue);

    // Kaydet → yeniden aç: kalın/italik dosyada kalıcı.
    final again = XlsxEditor.parse(e.save());
    final st2 = again.sheets.first.styleAt(1, 0)!;
    expect(st2.bold, isTrue);
    expect(st2.italic, isTrue);
  });

  // ── ölçü sadakati ─────────────────────────────────────────────────────────

  test('aralıklı <col> genişliği kaydetmeyi SAĞ ÇIKAR', () {
    final e = XlsxEditor.parse(_rangedColsXlsx());
    final s = e.sheets.first;

    // Okuma zaten doğruydu: aralık A..J tamamen 20 karakter.
    for (var c = 0; c < 10; c++) {
      expect(s.layout.colWidthChars(c), closeTo(20, 0.01), reason: 'sütun $c');
    }

    // Regresyon: excel paketi aralığın yalnız `min`ini okuyup kaydederken
    // <cols>u baştan yazıyordu → B..J varsayılan 8.43'e düşüyordu.
    final again = XlsxEditor.parse(e.save()).sheets.first;
    for (var c = 0; c < 10; c++) {
      expect(again.layout.colWidthChars(c), closeTo(20, 0.01),
          reason: 'kaydetme sonrası sütun $c');
    }
  });

  test('setColWidthChars / setRowHeightPt anında ve kalıcı uygulanır', () {
    final e = XlsxEditor.parse(_rangedColsXlsx());
    final s = e.sheets.first;

    final before = s.colWidth(2);
    s.setColWidthChars(2, 30);
    expect(s.colWidth(2), greaterThan(before)); // ekranda anında geniş

    s.setRowHeightPt(0, 40); // veri olan satır (bkz. setRowHeightPt notu)
    expect(s.rowHeight(0), closeTo(40 * 1.34, 0.01));

    final again = XlsxEditor.parse(e.save()).sheets.first;
    expect(again.layout.colWidthChars(2), closeTo(30, 0.01));
    expect(again.layout.rowHeightPt(0), closeTo(40, 0.01));
    // Komşu sütunlar bozulmadı.
    expect(again.layout.colWidthChars(3), closeTo(20, 0.01));
  });

  test('genişlik 0 sütunu gizler, tekrar büyütmek geri getirir', () {
    final s = XlsxEditor.parse(_rangedColsXlsx()).sheets.first;

    s.setColWidthChars(1, 0);
    expect(s.isColHidden(1), isTrue);
    expect(s.colWidth(1), 0);

    s.setColWidthChars(1, 12);
    expect(s.isColHidden(1), isFalse);
    expect(s.colWidth(1), greaterThan(0));
  });
}

/// A..J sütunlarını TEK bir `<col min="1" max="10">` aralığıyla genişleten
/// dosya. `excel` paketinin `setColumnWidth`i sütunları tek tek yazdığı için
/// bu biçim ancak XML'e elle enjekte edilerek üretilebiliyor — gerçek Excel
/// dosyaları ise genelde böyle aralıklar taşır.
Uint8List _rangedColsXlsx() {
  final excel = Excel.createExcel();
  final sheet = excel[excel.getDefaultSheet()!];
  for (var c = 0; c < 10; c++) {
    sheet
        .cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0))
        .value = TextCellValue('h$c');
  }
  final archive = ZipDecoder().decodeBytes(Uint8List.fromList(excel.encode()!));
  final out = Archive();
  for (final f in archive.files) {
    if (f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml')) {
      final xml = utf8.decode(f.content as List<int>).replaceFirst(
            '<sheetData',
            '<cols><col min="1" max="10" width="20" customWidth="1"/></cols>'
                '<sheetData',
          );
      final content = utf8.encode(xml);
      out.addFile(ArchiveFile(f.name, content.length, content));
    } else {
      out.addFile(f);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

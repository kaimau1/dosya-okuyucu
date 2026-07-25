import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/excel_format.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:flutter_test/flutter_test.dart';

/// Excel sadakati testi: `rich_sheet.xlsx` Excel'in yazdığına birebir benzeyen
/// elle üretilmiş bir pakettir (test/fixtures/make_rich_sheet.py). Buradaki
/// beklentiler "dosya telefonda Excel'deki gibi görünüyor mu"nun ölçüsüdür.
void main() {
  late XlsxWorkbook wb;
  late XlsxSheetLayout veri;

  setUpAll(() {
    final bytes = Uint8List.fromList(
        File('test/fixtures/rich_sheet.xlsx').readAsBytesSync());
    wb = XlsxReader.read(bytes);
    veri = wb.sheets.first;
  });

  test('sayfalar ve sekme rengi', () {
    expect(wb.sheets.map((s) => s.name).toList(), ['Veri', 'Diğer']);
    expect(veri.tabColorArgb, 0xFF00B050);
    expect(wb.sheets[1].showGridLines, isFalse); // ikinci sayfada ızgara kapalı
    expect(veri.showGridLines, isTrue);
  });

  test('dondurulmuş bölme dosyadan okunur', () {
    expect(veri.frozenCols, 1);
    expect(veri.frozenRows, 2);
  });

  test('sütun genişliği, gizli satır/sütun', () {
    expect(veri.colWidthChars(0), 20);
    expect(veri.colWidthChars(1), 12);
    expect(veri.colWidthChars(2), 8.43); // varsayılan
    expect(veri.hiddenCols.contains(4), isTrue); // E sütunu gizli
    expect(veri.hiddenRows.contains(6), isTrue); // 7. satır gizli
    expect(veri.rowHeightPt(0), 24); // özel satır yüksekliği
  });

  test('birleştirilmiş hücre', () {
    expect(veri.merges.length, 1);
    final m = veri.merges.first;
    expect([m.r1, m.c1, m.r2, m.c2], [0, 0, 0, 2]);
  });

  test('paylaşılan dize, sayı, formül + Excel önbelleği, mantık, hata', () {
    expect(veri.cellAt(0, 0)?.text, 'Başlık');
    expect(veri.cellAt(2, 1)?.number, 1234.5);
    // Formül hücresi: hem formülü hem Excel'in hesapladığı sonucu taşır.
    expect(veri.cellAt(4, 1)?.formula, 'SUM(B3:B4)');
    expect(veri.cellAt(4, 1)?.number, 1484.5);
    expect(veri.cellAt(4, 0)?.formula, 'A3&" toplam"');
    expect(veri.cellAt(4, 0)?.text, 'Kalem toplam');
    expect(veri.cellAt(7, 0)?.boolean, isTrue);
    expect(veri.cellAt(7, 1)?.error, '#DIV/0!');
  });

  test('başlık hücresinin stili (yazı tipi, dolgu, kenarlık, hizalama)', () {
    final f = wb.styles.formatAt(veri.cellAt(0, 0)!.styleIndex);
    expect(f.font.bold, isTrue);
    expect(f.font.size, 14);
    expect(f.font.colorArgb, 0xFFFF0000);
    expect(f.fill.effectiveArgb, 0xFFFFFF00);
    expect(f.border.top.style, 'thin');
    expect(f.border.bottom.visible, isTrue);
    expect(f.align.horizontal, XlsxHAlign.center);
    expect(f.align.vertical, XlsxVAlign.center);
  });

  test('metin kaydırma, girinti, dikey hizalama ve TEMA rengi + tint', () {
    final f = wb.styles.formatAt(veri.cellAt(5, 0)!.styleIndex);
    expect(f.align.wrapText, isTrue);
    expect(f.align.indent, 2);
    expect(f.align.vertical, XlsxVAlign.top);
    // theme="4" → accent1 (#4472C4), tint -0.25 → koyulaşmış olmalı.
    final color = f.font.colorArgb!;
    expect(color, isNot(0xFF4472C4));
    expect((color >> 16) & 0xFF, lessThan(0x44));
  });

  test('hizalama YOKSA Excel varsayılanı: dikeyde alt', () {
    final f = wb.styles.formatAt(veri.cellAt(2, 1)!.styleIndex);
    expect(f.align.vertical, XlsxVAlign.bottom);
    expect(f.align.horizontal, XlsxHAlign.general);
  });

  test('sayı biçimleri Excel gibi görünür', () {
    String show(int r, int c) {
      final cell = veri.cellAt(r, c)!;
      final code = wb.styles.formatAt(cell.styleIndex).numFmtCode;
      return ExcelNumberFormat.parse(code).format(cell.number!).text;
    }

    expect(show(2, 1), '1.234,50 ₺'); // özel numFmt 164
    expect(show(2, 2), '%15'); // yerleşik 9
    expect(show(2, 3), '21.07.2026'); // yerleşik 14 (seri 46224)
    expect(show(3, 3), '22.07.2026');
  });

  test('koşullu biçimlendirme kuralları', () {
    expect(veri.condFormats.length, 2);
    final cellIs =
        veri.condFormats.firstWhere((r) => r.type == 'cellIs');
    expect(cellIs.operator, 'greaterThan');
    expect(cellIs.formulas.first, '1000');
    expect(cellIs.covers(2, 1), isTrue);
    expect(cellIs.covers(2, 2), isFalse);
    expect(cellIs.dxfId, 0);
    expect(wb.styles.dxfs.first.fill?.effectiveArgb, isNotNull);

    final scale = veri.condFormats.firstWhere((r) => r.type == 'colorScale');
    expect(scale.scaleColors, [0xFFFFFFFF, 0xFF63BE7B]);
  });

  test('veri doğrulama listesi', () {
    expect(veri.validations.length, 1);
    expect(veri.validations.first.options, ['Kalem', 'Defter', 'Silgi']);
    expect(veri.validations.first.covers(2, 0), isTrue);
  });

  test('tema paleti Excel indeks sırasına çevrilir', () {
    // theme="0" → lt1 (beyaz), theme="1" → dk1 (siyah)
    expect(wb.theme[0], 0xFFFFFFFF);
    expect(wb.theme[1], 0xFF000000);
    expect(wb.theme[4], 0xFF4472C4); // accent1
  });
  group('paylaşılan formül (t="shared")', () {
    test('göreli başvurular kaydırılarak açılır', () {
      // Excel formül metnini yalnız ana hücreye yazar; takipçi hücrede
      // sadece si vardır. Açmazsak o hücre "formülsüz" görünür.
      final bytes = File('test/fixtures/wide_freeze.xlsx').readAsBytesSync();
      final book = XlsxReader.read(Uint8List.fromList(bytes));
      final sheet = book.sheets.firstWhere((s) => s.name == 'Genis');
      expect(sheet.cellAt(3, 0)?.formula, 'A2*2'); // ana hücre A4
      expect(sheet.cellAt(3, 1)?.formula, 'B2*2'); // B4: sütun +1 kaydı
    });

    test('shiftFormulaRefs Excel gibi kaydırır', () {
      // Göreli kayar, $ ile sabitlenen kalır.
      expect(XlsxReader.shiftFormulaRefs('A1+\$B\$2', 2, 1), 'B3+\$B\$2');
      expect(XlsxReader.shiftFormulaRefs('SUM(A1:A5)', 1, 0), 'SUM(A2:A6)');
      expect(XlsxReader.shiftFormulaRefs('\$A1*B\$2', 1, 1), '\$A2*C\$2');
      // Fonksiyon adı, dize sabiti, sayı ve sayfa adı korunur.
      expect(XlsxReader.shiftFormulaRefs('LOG10(A1)', 1, 0), 'LOG10(A2)');
      expect(XlsxReader.shiftFormulaRefs('"A1"&A1', 1, 0), '"A1"&A2');
      expect(XlsxReader.shiftFormulaRefs('2e5+A1', 1, 0), '2e5+A2');
      expect(XlsxReader.shiftFormulaRefs("'Bir Ad'!A1", 0, 1), "'Bir Ad'!B1");
      // Sayfa dışına kayan başvuru Excel'de #REF! olur.
      expect(XlsxReader.shiftFormulaRefs('A1', -5, 0), '#REF!');
      // Kayma yoksa metin hiç dokunulmaz.
      expect(XlsxReader.shiftFormulaRefs('A1+B2', 0, 0), 'A1+B2');
    });
  });
}

import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yazıcının ürettiği paketin **bizim okuyucumuz** ve **excel paketi**
/// tarafından okunabildiğini doğrular. İkisi de gerekiyor: uygulama dosyayı
/// `XlsxEditor.parse` ile açıyor, o da her ikisini birden çağırıyor.
void main() {
  group('XlsxWriter — sıfırdan .xlsx', () {
    test('değerler, sayı biçimi ve stiller okunabilir bir pakete yazılır', () {
      final sheet = XlsxWriteSheet(
        name: 'Veri',
        cells: {
          0: {
            0: const XlsxWriteCell(text: 'Ürün', style: 1),
            1: const XlsxWriteCell(text: 'Tutar'),
          },
          1: {
            0: const XlsxWriteCell(text: 'Kalem'),
            1: const XlsxWriteCell(number: 1234.5, style: 2),
          },
          2: {
            0: const XlsxWriteCell(boolean: true),
            1: const XlsxWriteCell(error: '#DIV/0!'),
          },
        },
        colWidths: {0: 18.5},
        rowHeights: {0: 28},
        merges: [const XlsxWriteMerge(3, 0, 3, 1)],
        frozenRows: 1,
        frozenCols: 1,
      );

      final bytes = XlsxWriter.build(
        [sheet],
        styles: const [
          XlsxWriteStyle(bold: true, fontSize: 14, fontName: 'Arial'),
          XlsxWriteStyle(numFmtCode: '#,##0.00', hAlign: 'right'),
        ],
      );
      expect(bytes, isNotEmpty);

      final wb = XlsxReader.read(bytes);
      expect(wb.sheets.length, 1);
      final layout = wb.sheets.first;
      expect(layout.name, 'Veri');
      expect(layout.cellAt(0, 0)?.text, 'Ürün');
      expect(layout.cellAt(1, 1)?.number, 1234.5);
      expect(layout.cellAt(2, 0)?.boolean, isTrue);
      expect(layout.cellAt(2, 1)?.error, '#DIV/0!');

      // Stil indeksleri kaymamalı: 1 → kalın 14pt Arial, 2 → sayı biçimi.
      final head = wb.styles.formatAt(layout.cellAt(0, 0)!.styleIndex);
      expect(head.font.bold, isTrue);
      expect(head.font.size, 14);
      expect(head.font.name, 'Arial');
      final money = wb.styles.formatAt(layout.cellAt(1, 1)!.styleIndex);
      expect(money.numFmtCode, '#,##0.00');
      expect(money.align.horizontal, XlsxHAlign.right);

      // Ölçüler, birleşme ve dondurulmuş bölme.
      expect(layout.colWidthChars(0), closeTo(18.5, 0.001));
      expect(layout.rowHeightPt(0), closeTo(28, 0.001));
      expect(layout.merges.length, 1);
      expect(layout.frozenRows, 1);
      expect(layout.frozenCols, 1);
    });

    test('üretilen paket XlsxEditor (excel paketi dahil) ile açılır', () {
      final bytes = XlsxWriter.build([
        XlsxWriteSheet(name: 'S1', cells: {
          0: {0: const XlsxWriteCell(text: 'merhaba')},
          1: {0: const XlsxWriteCell(number: 7)},
        }),
        XlsxWriteSheet(name: 'S2', cells: {
          0: {0: const XlsxWriteCell(text: 'ikinci')},
        }),
      ]);
      final editor = XlsxEditor.parse(bytes);
      expect(editor.sheets.map((s) => s.name), containsAll(['S1', 'S2']));
      final s1 = editor.sheets.firstWhere((s) => s.name == 'S1');
      expect(s1.rawAt(0, 0), 'merhaba');
      expect(s1.rawAt(1, 0), '7');
    });

    test('geçersiz sayfa adı ve XML kaçış karakterleri paketi bozmaz', () {
      final bytes = XlsxWriter.build([
        XlsxWriteSheet(name: 'Ali/Veli[2026]*', cells: {
          // & < > ve XML'de geçersiz denetim karakteri.
          0: {0: const XlsxWriteCell(text: 'a & b <c> son')},
        }),
      ]);
      final wb = XlsxReader.read(bytes);
      expect(wb.sheets.first.name, 'Ali Veli 2026');
      expect(wb.sheets.first.cellAt(0, 0)?.text, 'a & b <c> son');
    });

    test('sütun adı A..Z, AA, AB doğru üretilir', () {
      expect(XlsxWriter.colName(0), 'A');
      expect(XlsxWriter.colName(25), 'Z');
      expect(XlsxWriter.colName(26), 'AA');
      expect(XlsxWriter.colName(27), 'AB');
      expect(XlsxWriter.colName(51), 'AZ');
      expect(XlsxWriter.colName(52), 'BA');
    });

    test('boş girdi bile geçerli bir çalışma kitabı üretir', () {
      final bytes = XlsxWriter.build(const <XlsxWriteSheet>[]);
      final wb = XlsxReader.read(Uint8List.fromList(bytes));
      expect(wb.sheets.length, 1);
    });
  });
}

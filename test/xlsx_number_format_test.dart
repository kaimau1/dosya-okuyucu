import 'dart:io';

import 'package:excel/excel.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('applyNumberFormat — Excel biçim kodu → Türkçe gösterim', () {
    test('yüzde', () {
      expect(applyNumberFormat('0%', 0.15), '%15');
      expect(applyNumberFormat('0.00%', 0.155), '%15,50');
      expect(applyNumberFormat('0%', 1), '%100');
    });

    test('binlik gruplama', () {
      expect(applyNumberFormat('#,##0', 1234567), '1.234.567');
      expect(applyNumberFormat('#,##0.00', 1234.5), '1.234,50');
    });

    test('para birimi', () {
      expect(applyNumberFormat(r'"₺"#,##0.00', 1234.5), '₺1.234,50');
      expect(applyNumberFormat(r'"$"#,##0.00', 1000), r'$1.000,00');
      expect(applyNumberFormat(r'[$€-407]#,##0.00', 5), '€5,00');
    });

    test('sabit ondalık ve tam sayı', () {
      expect(applyNumberFormat('0.0', 3.14159), '3,1');
      expect(applyNumberFormat('0.00', 2), '2,00');
      expect(applyNumberFormat('0', 42.7), '43');
    });

    test('negatif değer', () {
      expect(applyNumberFormat('#,##0.00', -1234.5), '-1.234,50');
    });

    test('genel/metin biçimi uygulanmaz (null döner)', () {
      expect(applyNumberFormat('General', 5), isNull);
      expect(applyNumberFormat('@', 5), isNull);
    });
  });

  group('XlsxSheet.displayText — biçim yalnızca sayıya uygulanır', () {
    // _sheet alanı displayText'te kullanılmaz; boş bir Sheet yeterli.
    final excel = Excel.createExcel();
    final sheet = excel[excel.getDefaultSheet()!];
    XlsxSheet make(Map<int, String> fmts) =>
        XlsxSheet('Sayfa1', const [], sheet, const [], fmts);

    test('biçimli sayı hücresi Excel gibi görünür', () {
      final s = make({XlsxEditor.debugCellKey(0, 0): '0%'});
      expect(s.displayText(0, 0, '0.15'), '%15');
    });

    test('formül sonucu da biçimlenir', () {
      final s = make({XlsxEditor.debugCellKey(1, 2): r'"₺"#,##0.00'});
      // Formül motoru "1500" döndürdüyse para biçimi uygulanır.
      expect(s.displayText(1, 2, '1500'), '₺1.500,00');
    });

    test('metin/tarih (sayı olmayan) aynen kalır', () {
      final s = make({XlsxEditor.debugCellKey(0, 0): '0%'});
      expect(s.displayText(0, 0, 'merhaba'), 'merhaba');
      expect(s.displayText(0, 0, '15.03.2025'), '15.03.2025');
    });

    test('biçimi olmayan hücre değişmez', () {
      final s = make({XlsxEditor.debugCellKey(0, 0): '0%'});
      expect(s.displayText(9, 9, '0.15'), '0.15');
    });
  });

  group('debugReadNumberFormats — .xlsx XML\'inden biçim okuma', () {
    test('fixture hücre biçimlerini doğru çıkarır', () {
      final bytes = File('test/fixtures/number_formats.xlsx').readAsBytesSync();
      final map = XlsxEditor.debugReadNumberFormats(bytes);

      expect(map.containsKey('Sayfa1'), isTrue);
      final s = map['Sayfa1']!;
      expect(s[XlsxEditor.debugCellKey(0, 1)], '0%'); // B1
      expect(s[XlsxEditor.debugCellKey(0, 2)], '0.00%'); // C1
      expect(s[XlsxEditor.debugCellKey(0, 3)], '#,##0'); // D1
      expect(s[XlsxEditor.debugCellKey(0, 4)], '#,##0.00'); // E1
      expect(s[XlsxEditor.debugCellKey(0, 5)], '"₺"#,##0.00'); // F1 currency
      expect(s[XlsxEditor.debugCellKey(0, 7)], '0.0'); // H1
      // G1 tarih biçimliydi (numFmtId 14) → dışarıda bırakılır.
      expect(s.containsKey(XlsxEditor.debugCellKey(0, 6)), isFalse);
    });
  });
}

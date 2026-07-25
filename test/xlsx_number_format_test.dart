import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/excel_format.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';

/// Excel sayı biçim motoru — hücre ekranda Excel'deki gibi görünmeli.
/// Türkçe gösterim: binlik `.`, ondalık `,`, yüzde işareti başta.
void main() {
  String f(String code, Object value) =>
      ExcelNumberFormat.parse(code).format(value).text;

  group('sayı biçimleri', () {
    test('yüzde', () {
      expect(f('0%', 0.15), '%15');
      expect(f('0.00%', 0.155), '%15,50');
      expect(f('0%', 1), '%100');
    });

    test('binlik gruplama', () {
      expect(f('#,##0', 1234567), '1.234.567');
      expect(f('#,##0.00', 1234.5), '1.234,50');
      expect(f('#,##0', 999), '999');
    });

    test('para birimi', () {
      expect(f(r'"₺"#,##0.00', 1234.5), '₺1.234,50');
      expect(f(r'"$"#,##0.00', 1000), r'$1.000,00');
      expect(f(r'[$€-407]#,##0.00', 5), '€5,00');
      expect(f(r'#,##0.00\ "₺"', 1234.5), '1.234,50 ₺');
    });

    test('sabit ondalık ve tam sayı (yuvarlama Excel gibi)', () {
      expect(f('0.0', 3.14159), '3,1');
      expect(f('0.00', 2), '2,00');
      expect(f('0', 42.7), '43');
      expect(f('00', 5), '05');
    });

    test('opsiyonel ondalık (#) sondaki sıfırı yazmaz', () {
      expect(f('0.##', 3.5), '3,5');
      expect(f('0.##', 3), '3');
    });

    test('negatif: tek bölümde işaret, iki bölümde ayrı gösterim', () {
      expect(f('#,##0.00', -1234.5), '-1.234,50');
      expect(f('#,##0;(#,##0)', -1234), '(1.234)');
      expect(f('#,##0;(#,##0)', 1234), '1.234');
    });

    test('bölümler: pozitif;negatif;sıfır;metin', () {
      const code = '0;-0;"—";"[" @ "]"';
      expect(f(code, 5), '5');
      expect(f(code, -5), '-5');
      expect(f(code, 0), '—');
      expect(f(code, 'not'), '[ not ]');
    });

    test('renk etiketi sonuca renk olarak döner', () {
      final res = ExcelNumberFormat.parse('#,##0;[Red]-#,##0').format(-5);
      expect(res.text, '-5');
      expect(res.colorArgb, 0xFFFF0000);
    });

    test('koşullu bölüm', () {
      const code = '[>=1000]0,"B";0';
      expect(f(code, 2500), '3B'); // 2500/1000 = 2,5 → "0" ile 3
      expect(f(code, 12), '12');
    });

    test('ölçekleme: sondaki virgül 1000e böler', () {
      expect(f('#,##0,', 1234567), '1.235');
    });

    test('bilimsel gösterim', () {
      expect(f('0.00E+00', 12345), '1,23E+04');
    });

    test('kesir', () {
      expect(f('# ?/?', 2.5), '2 1/2');
      expect(f('# ??/??', 0.25), '1/4');
    });

    test('metin yer tutucusu', () {
      expect(f('@" adet"', 'kalem'), 'kalem adet');
    });
  });

  group('tarih / saat biçimleri', () {
    test('seri numara Excel ile aynı güne düşer', () {
      expect(excelSerialToDate(1), DateTime.utc(1900, 1, 1));
      expect(excelSerialToDate(46224), DateTime.utc(2026, 7, 21));
      expect(dateToExcelSerial(DateTime.utc(2026, 7, 21)).round(), 46224);
    });

    test('gün/ay/yıl', () {
      expect(f('dd.mm.yyyy', 46224), '21.07.2026');
      expect(f('d.m.yyyy', 46224), '21.7.2026');
      expect(f('dd mmmm yyyy', 46224), '21 Temmuz 2026');
      expect(f('d-mmm-yy', 46224), '21-Tem-26');
      expect(f('dddd', 46224), 'Salı');
    });

    test('saat ve 12 saat gösterimi', () {
      // 0.5 = öğlen 12:00
      expect(f('hh:mm', 46224.5), '12:00');
      expect(f('h:mm AM/PM', 46224.5), '12:00 ÖS');
      expect(f('h:mm AM/PM', 46224.25), '6:00 ÖÖ');
    });

    test('geçen süre [h]:mm', () {
      expect(f('[h]:mm', 1.5), '36:00');
    });

    test('sayı biçimi içinde tarih harfi geçse de sayıdır', () {
      // "adet" içindeki d/a harfleri tarih sanılmamalı.
      expect(f('#,##0" adet"', 1200), '1.200 adet');
    });
  });

  group('applyNumberFormat (eski API)', () {
    test('genel/metin biçimi uygulanmaz (null döner)', () {
      expect(applyNumberFormat('General', 5), isNull);
      expect(applyNumberFormat('@', 5), isNull);
    });

    test('biçimli sayı', () {
      expect(applyNumberFormat('0%', 0.15), '%15');
      expect(applyNumberFormat('#,##0.00', 1234.5), '1.234,50');
    });
  });

  group('gerçek dosyadan hücre biçimi okuma', () {
    test('number_formats.xlsx hücre biçimleri', () {
      final bytes = Uint8List.fromList(
          File('test/fixtures/number_formats.xlsx').readAsBytesSync());
      final wb = XlsxReader.read(bytes);
      final sheet = wb.sheets.first;
      String codeAt(int r, int c) =>
          wb.styles.formatAt(sheet.cellAt(r, c)!.styleIndex).numFmtCode;

      expect(codeAt(0, 1), '0%'); // B1
      expect(codeAt(0, 2), '0.00%'); // C1
      expect(codeAt(0, 3), '#,##0'); // D1
      expect(codeAt(0, 4), '#,##0.00'); // E1
      expect(codeAt(0, 5), '"₺"#,##0.00'); // F1
      expect(codeAt(0, 7), '0.0'); // H1
      // G1 tarih biçimliydi (numFmtId 14) — artık BİZ biçimliyoruz.
      expect(ExcelNumberFormat.parse(codeAt(0, 6)).isDate, isTrue);
    });
  });
}

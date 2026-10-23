import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/formula_help.dart';
import 'package:dosya_okuyucu/services/sheet_input.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 25 — formül dili (K22), akıllı giriş, işlev yardımı, başvuru bulucu.
void main() {
  group('formül dili TR ↔ dosya (30 formül, gidiş-dönüş)', () {
    const formulas = [
      'SUM(A1:A10)',
      'IF(A1>0,"a;b",SUM(B1:B3))',
      'VLOOKUP(A2,Sayfa2!A:B,2,FALSE)',
      'ROUND(A1*0.5,2)',
      'AVERAGE(B2:B9)',
      'COUNTIF(A:A,">5")',
      'SUMIFS(C:C,A:A,"x",B:B,">0")',
      'IFERROR(1/0,0)',
      'AND(A1>1,B1<2)',
      'OR(TRUE,FALSE)',
      'CONCATENATE("ü;ş","x")',
      'LEFT(A1,3)&RIGHT(A1,2)',
      'MID(A1,2,3)',
      'TEXT(A1,"0.00")',
      'DATE(2026,10,23)',
      'YEAR(TODAY())',
      'INDEX(A1:C9,2,3)',
      'MATCH(5,A1:A9,0)',
      'MAX(A1:A9)-MIN(A1:A9)',
      'PMT(0.01,12,-1000)',
      'ABS(-1.25)',
      'SQRT(16)+POWER(2,3)',
      'LEN(TRIM(A1))',
      'UPPER(A1)',
      'SUBSTITUTE(A1,",",";")',
      "SUM('Gelir Tablosu'!B1:B9)",
      r'SUM($A$1:$A$9)*1.18',
      'MEDIAN(1,2,3)',
      'NOT(ISBLANK(A1))',
      'EOMONTH(A1,1)',
    ];
    for (final f in formulas) {
      test(f, () {
        final tr = FormulaEngine.toTurkishFormula(f);
        expect(FormulaEngine.toFileFormula(tr, turkish: true), f);
      });
    }
    test('örnek gösterim', () {
      expect(FormulaEngine.toTurkishFormula('IF(A1>0,"a;b",SUM(B1:B3))'),
          'EĞER(A1>0;"a;b";TOPLA(B1:B3))');
      expect(FormulaEngine.toTurkishFormula('ROUND(A1*0.5,2)'),
          'YUVARLA(A1*0,5;2)');
      expect(FormulaEngine.toTurkishFormula('_xlfn.IFS(TRUE,1)'),
          'ÇOKEĞER(DOĞRU;1)');
    });
  });

  group('akıllı giriş', () {
    final cases = <String, (String, String?)>{
      '1.234,56': ('1234.56', '#,##0.00'),
      '1234,5': ('1234.5', null),
      '%15': ('0.15', '0%'),
      '12,5%': ('0.125', '0.00%'),
      '₺100': ('100', r'#,##0.00\ ₺'),
      '1.250,50 TL': ('1250.5', r'#,##0.00\ ₺'),
      '23.10.2026': ('46318', 'dd.mm.yyyy'),
      '14:30': ('0.6041666667', 'hh:mm'),
      '007': ('007', null),
      'elma': ('elma', null),
      '=TOPLA(A1)': ('=TOPLA(A1)', null),
      '42': ('42', null),
    };
    cases.forEach((input, want) {
      test(input, () {
        final r = parseSmartInput(input);
        expect((r.raw, r.numberFormat), want);
      });
    });
    test('1/2 tarihe çevrilmez, söylenir', () {
      final r = parseSmartInput('1/2');
      expect(r.raw, '1/2');
      expect(r.noteKey, 'excel.input_kept_text');
    });
    test('23 Eki → bu yılın tarihi', () {
      final r = parseSmartInput('23 Eki', today: DateTime(2026, 1, 1));
      expect(r.raw, '46318');
    });
  });

  group('işlev yardımı', () {
    test('etkin bağımsız değişken', () {
      const f = '=DÜŞEYARA(A1;B:C;';
      final call = activeCall(f, f.length);
      expect(call, ('DÜŞEYARA', 2));
      expect(signatureOf(call!.$1)!.argsTr[call.$2], 'sütun_indis_sayısı');
      expect(activeCall('=EĞER(TOPLA(A1;A2)>1;', 21), ('EĞER', 1));
      expect(activeCall('="a(;"', 5), isNull);
    });
    test('kitaplık kategorili', () {
      final lib = formulaLibrary();
      expect(lib[FormulaCategory.lookup]!.map((s) => s.name), contains('VLOOKUP'));
    });
    test('başvurular yerleriyle; işlev adı ve metin başvuru sayılmaz', () {
      const f = '=TOPLA(A1:B3;Sayfa2!C5;"D9";LOG10(E1))';
      final refs = formulaRefs(f);
      expect(refs.map((r) => f.substring(r.start, r.end)),
          ['A1:B3', 'Sayfa2!C5', 'E1']);
      expect(refs[1].sheet, 'Sayfa2');
      expect(refs.first.range.r2, 2);
    });
    test(r'F4 döngüsü A1 → $A$1 → A$1 → $A1 → A1', () {
      var s = '=A1+B2';
      final seen = <String>[];
      var caret = 2;
      for (var k = 0; k < 4; k++) {
        final r = cycleAbsolute(s, caret)!;
        s = r.$1;
        caret = r.$2;
        seen.add(s);
      }
      expect(seen, [r'=$A$1+B2', r'=A$1+B2', r'=$A1+B2', '=A1+B2']);
    });
  });
}

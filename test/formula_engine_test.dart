import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tek hücreli formül (referanssız) değerlendirir.
String f(String formula) => FormulaEngine([
      [formula]
    ]).displayValue(0, 0);

void main() {
  test('aritmetik ve öncelik', () {
    expect(f('=1+2*3'), '7');
    expect(f('=(1+2)*3'), '9');
    expect(f('=10/4'), '2.5');
    expect(f('=2^10'), '1024');
    expect(f('=-5+3'), '-2');
    expect(f('=50%'), '0.5');
    expect(f('=200*10%'), '20');
  });

  test('formül olmayan değer aynen döner', () {
    expect(f('merhaba'), 'merhaba');
    expect(f('42'), '42');
  });

  test('karşılaştırma → mantık', () {
    expect(f('=1>0'), 'DOĞRU');
    expect(f('=5<=4'), 'YANLIŞ');
    expect(f('=3=3'), 'DOĞRU');
    expect(f('=2<>2'), 'YANLIŞ');
  });

  test('metin fonksiyonları', () {
    expect(f('=UPPER("abc")'), 'ABC');
    expect(f('=LEN("merhaba")'), '7');
    expect(f('=CONCAT("a","b","c")'), 'abc');
    expect(f('=LEFT("Merhaba",3)'), 'Mer');
    expect(f('=TRIM("  x  ")'), 'x');
  });

  test('matematik fonksiyonları', () {
    expect(f('=ROUND(3.14159,2)'), '3.14');
    expect(f('=ABS(-9)'), '9');
    expect(f('=SQRT(16)'), '4');
    expect(f('=POWER(3,3)'), '27');
    expect(f('=MOD(10,3)'), '1');
    expect(f('=INT(3.9)'), '3');
  });

  test('IF ve mantık fonksiyonları', () {
    expect(f('=IF(1>2,"büyük","küçük")'), 'küçük');
    expect(f('=IF(5>2,"E","H")'), 'E');
    expect(f('=AND(1>0,2>1)'), 'DOĞRU');
    expect(f('=OR(1>2,3>2)'), 'DOĞRU');
    expect(f('=NOT(1>2)'), 'DOĞRU');
  });

  test('hücre referansı ve aralık', () {
    final grid = [
      ['10', '20', '30'],
      ['=A1+B1', '=SUM(A1:C1)', '=AVERAGE(A1:C1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '30'); // A1+B1
    expect(e.displayValue(1, 1), '60'); // SUM(A1:C1)
    expect(e.displayValue(1, 2), '20'); // AVERAGE
  });

  test('MIN/MAX/COUNT boş ve metni atlar', () {
    final grid = [
      ['5', '', 'metin', '15'],
      ['=MIN(A1:D1)', '=MAX(A1:D1)', '=COUNT(A1:D1)', '=COUNTA(A1:D1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '5'); // MIN sayılar
    expect(e.displayValue(1, 1), '15'); // MAX
    expect(e.displayValue(1, 2), '2'); // COUNT sadece sayı (5,15)
    expect(e.displayValue(1, 3), '3'); // COUNTA boş hariç (5,metin,15)
  });

  test('zincirli formül (formül formüle bağlı)', () {
    final grid = [
      ['4'],
      ['=A1*2'], // 8
      ['=A2+1'], // 9
    ];
    expect(FormulaEngine(grid).displayValue(2, 0), '9');
  });

  test('döngüsel referans → #DÖNGÜ', () {
    final grid = [
      ['=A2'],
      ['=A1'],
    ];
    expect(FormulaEngine(grid).displayValue(0, 0), '#DÖNGÜ');
  });

  test('hatalar → #HATA', () {
    expect(f('=1/0'), '#HATA');
    expect(f('=BILINMEYEN()'), '#HATA');
    expect(f('=UPPER('), '#HATA'); // kapanmayan
    // metinle aritmetik
    final grid = [
      ['metin'],
      ['=A1+5'],
    ];
    expect(FormulaEngine(grid).displayValue(1, 0), '#HATA');
  });

  group('preview (formül çubuğu canlı önizleme)', () {
    test('yazılan formülü ızgaraya göre hesaplar', () {
      final grid = [
        ['10', '20'],
        ['', ''],
      ];
      // A1+B1 = 30, henüz hücreye yazılmadan.
      expect(FormulaEngine(grid).preview('=A1+B1', 1, 0), '30');
    });

    test('formül olmayan girdi boş önizleme', () {
      expect(FormulaEngine([['x']]).preview('düz metin', 0, 0), '');
      expect(FormulaEngine([['x']]).preview('=', 0, 0), '');
    });

    test('kendine referans → #DÖNGÜ', () {
      // A1 zaten =A1 içeriyor; A1'e yine =A1 önizlemesi döngüyü yakalar.
      expect(FormulaEngine([['=A1']]).preview('=A1', 0, 0), '#DÖNGÜ');
    });

    test('hatalı formül → #HATA', () {
      expect(FormulaEngine([['']]).preview('=1+', 0, 0), '#HATA');
    });
  });
}

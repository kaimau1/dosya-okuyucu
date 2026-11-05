import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/formula_errors.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 4 — dinamik diziler (taşma), LET, hata açıklaması.
FormulaEngine _engine(List<List<String>> grid) => FormulaEngine(grid);

void main() {
  test('SIRALI taşar: çapa ilk değer, komşular dizinin devamı', () {
    final g = [
      ['=SEQUENCE(3)', ''],
      ['', ''],
      ['', ''],
    ];
    final e = _engine(g);
    expect(e.displayValue(0, 0), '1');
    expect(e.displayValue(1, 0), '2');
    expect(e.displayValue(2, 0), '3');
  });

  test('taşma alanı doluysa #YAYILMA!', () {
    final e = _engine([
      ['=SEQUENCE(2)'],
      ['engel'],
    ]);
    expect(e.displayValue(0, 0), '#YAYILMA!');
  });

  test('FİLTRE + öğe öğe karşılaştırma, BENZERSİZ, SIRALA', () {
    final g = [
      ['Ege', '10', '=FILTER(A1:A4,B1:B4>6)', ''],
      ['Marmara', '5', '', ''],
      ['Ege', '7', '', ''],
      ['Akdeniz', '9', '', ''],
      ['=UNIQUE(A1:A4)', '', '=SORT(B1:B4,1,-1)', ''],
      ['', '', '', ''],
      ['', '', '', ''],
      ['', '', '', ''],
    ];
    final e = _engine(g);
    expect([for (var r = 0; r < 3; r++) e.displayValue(r, 2)], ['Ege', 'Ege', 'Akdeniz']);
    expect([for (var r = 4; r < 7; r++) e.displayValue(r, 0)], ['Ege', 'Marmara', 'Akdeniz']);
    expect([for (var r = 4; r < 8; r++) e.displayValue(r, 2)], ['10', '9', '7', '5']);
  });

  test('FİLTRE eşleşme yoksa boşsa değeri, yoksa #HESAP!', () {
    final e = _engine([
      ['1', '=FILTER(A1:A2,A1:A2>5,"yok")'],
      ['2', '=FILTER(A1:A2,A1:A2>5)'],
    ]);
    expect(e.displayValue(0, 1), 'yok');
    expect(e.displayValue(1, 1), '#HESAP!');
  });

  test('taşan hücreye başvuran formül dizinin değerini görür', () {
    final e = _engine([
      ['=SEQUENCE(3,1,10,5)', '=SUM(A1:A3)'],
      ['', '=A2*2'],
      ['', ''],
    ]);
    expect(e.displayValue(0, 0), '10');
    expect(e.displayValue(0, 1), '45');
    expect(e.displayValue(1, 1), '30');
  });

  test('LET: adlar sırayla bağlanır, Türkçe ayraçla da', () {
    final e = _engine([
      ['4', '=LET(x,A1*2,y,x+1,x*y)', '=LET(x;A1;x*x)'],
    ]);
    expect(e.displayValue(0, 1), '72');
    expect(e.displayValue(0, 2), '16');
  });

  test('dizi bağlamı dışında eski tek değer davranışı korunur', () {
    final e = _engine([
      ['3', '=A1:A2*2'],
      ['5', ''],
    ]);
    expect(e.displayValue(0, 1), '6');
    expect(e.displayValue(1, 1), '');
  });

  test('TOPLA.ÇARPIM öğe öğe koşul', () {
    final e = _engine([
      ['1', '10', '=SUMPRODUCT((A1:A3>1)*B1:B3)'],
      ['2', '20', ''],
      ['3', '30', ''],
    ]);
    expect(e.displayValue(0, 2), '50');
  });

  test('hata açıklaması anahtarları', () {
    expect(formulaErrorKey('#DEĞER!'), 'xp.err_value');
    expect(formulaErrorKey('#DIV/0!'), 'xp.err_div0');
    expect(formulaErrorKey('#YAYILMA!'), 'xp.err_spill');
    expect(formulaErrorKey('42'), isNull);
  });

  test('dosya biçimi önekleri', () {
    expect(FormulaEngine.toFileFormula('FİLTRE(A1:A3;B1:B3>1)', turkish: true),
        startsWith('_xlfn._xlws.FILTER('));
    expect(FormulaEngine.toFileFormula('SEQUENCE(3)'), '_xlfn.SEQUENCE(3)');
  });
}

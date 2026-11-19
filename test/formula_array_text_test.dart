import 'package:dosya_okuyucu/services/formula_engine.dart';
import 'package:dosya_okuyucu/services/formula_help.dart';
import 'package:flutter_test/flutter_test.dart';

/// B10 m.2 (2026-11-19) — dizi/metin/LAMBDA işlevleri. Beklenenler
/// Microsoft belgesindeki örneklerden (tarih örnekleri takvimle sağlandı).
///
/// Formül [col] sütununa (varsayılan K) konur; [data] A1'den başlar. Dönen
/// blok formül hücresinden itibaren [h]×[w] hücrenin gösterilen değeri.
List<List<String>> _run(String formula,
    {List<List<String>> data = const [], int h = 3, int w = 3}) {
  const col = 10;
  final rows = h > data.length ? h : data.length;
  final grid = [
    for (var r = 0; r < rows + 1; r++)
      [
        for (var c = 0; c < col + w + 1; c++)
          r < data.length && c < data[r].length ? data[r][c] : '',
      ],
  ];
  grid[0][col] = formula;
  final e = FormulaEngine(grid);
  return [
    for (var r = 0; r < h; r++)
      [for (var c = 0; c < w; c++) e.displayValue(r, col + c)],
  ];
}

String _one(String formula, {List<List<String>> data = const []}) =>
    _run(formula, data: data, h: 1, w: 1)[0][0];

void main() {
  group('TEXTSPLIT', () {
    test('sütun sınırlayıcı', () {
      expect(_run('=TEXTSPLIT("Dakota Lennon Sanchez"," ")', h: 1, w: 4),
          [
            ['Dakota', 'Lennon', 'Sanchez', ''],
          ]);
    });
    test('sütun + satır sınırlayıcı', () {
      expect(_run('=TEXTSPLIT("1,2,3;4,5,6;7,8,9",",",";")'), [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ]);
    });
    test('boşu yoksay, çoklu sınırlayıcı, doldurma değeri', () {
      expect(_run('=TEXTSPLIT("a,,b",",")', h: 1), [
        ['a', '', 'b'],
      ]);
      expect(_run('=TEXTSPLIT("a,,b",",",,TRUE)', h: 1), [
        ['a', 'b', ''],
      ]);
      expect(_run('=TEXTSPLIT("a.b-c",{".","-"})', h: 1), [
        ['a', 'b', 'c'],
      ]);
      expect(_run('=TEXTSPLIT("1,2,3;4,5",",",";")', h: 2), [
        ['1', '2', '3'],
        ['4', '5', '#YOK'],
      ]);
      expect(_run('=TEXTSPLIT("1,2,3;4,5",",",";",,,"x")', h: 2), [
        ['1', '2', '3'],
        ['4', '5', 'x'],
      ]);
    });
    test('büyük/küçük harf eşleştirme kipi', () {
      expect(_run('=TEXTSPLIT("aXbxc","x")', h: 1, w: 2), [
        ['aXb', 'c'],
      ]);
      expect(_run('=TEXTSPLIT("aXbxc","x",,,1)', h: 1), [
        ['a', 'b', 'c'],
      ]);
    });
    test('sınırlayıcısız #DEĞER!', () {
      expect(_one('=TEXTSPLIT("abc","")'), '#DEĞER!');
    });
  });

  group('VSTACK / HSTACK', () {
    test('aralıkları üst üste / yan yana koyar, eksiği #YOK', () {
      final data = [
        ['1', '2', '', 'A', 'B'],
        ['3', '4', '', 'C', 'D'],
      ];
      expect(_run('=VSTACK(A1:B2,D1:E2)', data: data, h: 4, w: 2), [
        ['1', '2'],
        ['3', '4'],
        ['A', 'B'],
        ['C', 'D'],
      ]);
      expect(_run('=HSTACK(A1:B2,D1:E2)', data: data, h: 2, w: 4), [
        ['1', '2', 'A', 'B'],
        ['3', '4', 'C', 'D'],
      ]);
      expect(_run('=VSTACK({1,2},{3})', h: 2, w: 2), [
        ['1', '2'],
        ['3', '#YOK'],
      ]);
      expect(_run('=HSTACK({1;2},{3})', h: 2, w: 2), [
        ['1', '3'],
        ['2', '#YOK'],
      ]);
    });
  });

  group('TAKE / DROP', () {
    const m = '{1,2,3;4,5,6;7,8,9}';
    test('TAKE', () {
      expect(_run('=TAKE($m,2)', h: 3), [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['', '', ''],
      ]);
      expect(_run('=TAKE($m,,3)'), [
        ['1', '2', '3'],
        ['4', '5', '6'],
        ['7', '8', '9'],
      ]);
      expect(_run('=TAKE($m,-2)', h: 2), [
        ['4', '5', '6'],
        ['7', '8', '9'],
      ]);
      expect(_run('=TAKE($m,2,2)', h: 2, w: 2), [
        ['1', '2'],
        ['4', '5'],
      ]);
      expect(_one('=TAKE($m,0)'), '#HESAP!');
    });
    test('DROP', () {
      expect(_run('=DROP($m,2)', h: 1), [
        ['7', '8', '9'],
      ]);
      expect(_run('=DROP($m,,2)', w: 1), [
        ['3'],
        ['6'],
        ['9'],
      ]);
      expect(_run('=DROP($m,-2)', h: 1), [
        ['1', '2', '3'],
      ]);
      expect(_one('=DROP($m,2,2)'), '9');
      expect(_one('=DROP($m,3)'), '#HESAP!');
    });
  });

  group('CHOOSECOLS / CHOOSEROWS', () {
    const m = '{1,2,3;4,5,6}';
    test('seçer, eksi sayı sondan, dizi sabiti olur', () {
      expect(_run('=CHOOSECOLS($m,1,3)', h: 2, w: 2), [
        ['1', '3'],
        ['4', '6'],
      ]);
      expect(_run('=CHOOSECOLS($m,-1)', h: 2, w: 1), [
        ['3'],
        ['6'],
      ]);
      expect(_run('=CHOOSECOLS($m,{2,1})', h: 1, w: 2), [
        ['2', '1'],
      ]);
      expect(_run('=CHOOSEROWS($m,2)', h: 1), [
        ['4', '5', '6'],
      ]);
      expect(_one('=CHOOSECOLS($m,4)'), '#DEĞER!');
      expect(_one('=CHOOSEROWS($m,0)'), '#DEĞER!');
    });
  });

  group('XMATCH', () {
    test('belge örnekleri', () {
      expect(_one('=XMATCH(4,{5,4,3,2,1})'), '2');
      expect(_one('=XMATCH(4.5,{5,4,3,2,1},1)'), '1');
      expect(_one('=XMATCH(4.5,{5,4,3,2,1},-1)'), '2');
      expect(_one('=XMATCH("Gr?pe",{"Apple","Grape","Banana"},2)'), '2');
      expect(_one('=XMATCH(2,{2,1,2},0,-1)'), '3');
      expect(_one('=XMATCH(9,{1,2,3})'), '#YOK');
    });
    test('aralıkta, metin büyük/küçük harf duyarsız', () {
      final data = [
        ['elma'],
        ['Armut'],
        ['kiraz'],
      ];
      expect(_one('=XMATCH("armut",A1:A3)', data: data), '2');
    });
  });

  group('LAMBDA ailesi', () {
    test('hemen çağrılan ve LET ile adlanan LAMBDA', () {
      expect(_one('=LAMBDA(x,x+1)(2)'), '3');
      expect(_one('=LET(f,LAMBDA(x,y,x*y),f(3,4))'), '12');
      expect(_one('=LAMBDA(x,x)'), '#HESAP!');
      expect(_one('=LAMBDA(x,x+1)(1,2)'), '#DEĞER!');
      // Dosyadaki parametre öneki `_xlpm.`.
      expect(_one('=_xlfn.LAMBDA(_xlpm.n,_xlpm.n*2)(5)'), '10');
      // Türkçe yazım: gövdedeki `0,5` ondalık.
      expect(_one('=LAMBDA(x;x*0,5)(4)'), '2');
    });
    test('MAP', () {
      final data = [
        ['1', '2', '3'],
        ['4', '5', '6'],
      ];
      expect(
          _run('=MAP(A1:C2,LAMBDA(a,IF(a>4,a*a,a)))', data: data, h: 2), [
        ['1', '2', '3'],
        ['4', '25', '36'],
      ]);
      expect(_run('=MAP({1,2},{10,20},LAMBDA(a,b,a+b))', h: 1, w: 2), [
        ['11', '22'],
      ]);
    });
    test('REDUCE / SCAN', () {
      final data = [
        ['1', '2', '3'],
        ['4', '5', '6'],
      ];
      expect(_one('=REDUCE(,A1:C2,LAMBDA(a,b,a+b^2))', data: data), '91');
      expect(_one('=REDUCE(1,{2,3,4},LAMBDA(a,b,a*b))'), '24');
      expect(_run('=SCAN("",{"a","b","c"},LAMBDA(a,b,a&b))', h: 1), [
        ['a', 'ab', 'abc'],
      ]);
      expect(_one('=REDUCE(0,{1,2},LAMBDA(a,a))'), '#DEĞER!');
    });
    test('BYROW / BYCOL / MAKEARRAY', () {
      final data = [
        ['1', '2', '3'],
        ['4', '5', '6'],
      ];
      expect(_run('=BYROW(A1:C2,LAMBDA(array,MAX(array)))',
          data: data, h: 2, w: 1), [
        ['3'],
        ['6'],
      ]);
      expect(_run('=BYCOL(A1:C2,LAMBDA(c,SUM(c)))', data: data, h: 1), [
        ['5', '7', '9'],
      ]);
      expect(_run('=MAKEARRAY(3,3,LAMBDA(r,c,r*c))'), [
        ['1', '2', '3'],
        ['2', '4', '6'],
        ['3', '6', '9'],
      ]);
    });
  });

  group('NETWORKDAYS.INTL / WORKDAY.INTL', () {
    final holidays = [
      ['=DATE(2006,1,2)'],
      ['=DATE(2006,1,16)'],
    ];
    test('NETWORKDAYS.INTL', () {
      expect(_one('=NETWORKDAYS.INTL(DATE(2006,1,1),DATE(2006,1,31))'), '22');
      expect(_one('=NETWORKDAYS.INTL(DATE(2006,2,28),DATE(2006,1,31))'),
          '-21');
      expect(
          _one('=NETWORKDAYS.INTL(DATE(2006,1,1),DATE(2006,2,1),7,A1:A2)',
              data: holidays),
          '22');
      expect(
          _one(
              '=NETWORKDAYS.INTL(DATE(2006,1,1),DATE(2006,2,1),"0010001",A1:A2)',
              data: holidays),
          '20');
      expect(_one('=NETWORKDAYS.INTL(1,9,"1111111")'), '#DEĞER!');
      expect(_one('=NETWORKDAYS.INTL(1,9,8)'), '#SAYI!');
    });
    test('WORKDAY.INTL', () {
      expect(_one('=WORKDAY.INTL(DATE(2012,1,1),90,11)'), '41013');
      expect(_one('=WORKDAY.INTL(DATE(2012,1,1),30,17)'), '40944');
      expect(_one('=WORKDAY.INTL(DATE(2012,1,1),-5)'), '40903');
      expect(_one('=WORKDAY.INTL(DATE(2012,1,1),30,0)'), '#SAYI!');
    });
  });

  group('dizi sabiti', () {
    test('toplamda tümü, tek değer yerinde ilk öğe', () {
      expect(_one('=SUM({1,2;3,4})'), '10');
      expect(_one('=IF(TRUE,{7,8})'), '7');
      expect(_run('={1,2;3,4}', h: 2, w: 2), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(_one('={1,2;3}'), '#DEĞER!');
    });
  });

  group('Türkçe adlar, dosya biçimi, yardım', () {
    test('Türkçe adla hesaplanır', () {
      final data = [
        ['a-b'],
        ['x'],
        ['y'],
      ];
      expect(_run('=METİNBÖL(A1;"-")', data: data, h: 1, w: 2), [
        ['a', 'b'],
      ]);
      expect(_run('=DÜŞEYYIĞ(A2;A3)', data: data, h: 2, w: 1), [
        ['x'],
        ['y'],
      ]);
      expect(_one('=ÇAPRAZEŞLEŞTİR("y";A1:A3)', data: data), '3');
      expect(_one('=İLKEŞLEŞEN(2;1;"a";2;"b")'), 'b');
      expect(
          _one('=TAMİŞGÜNÜ.ULUSL(TARİH(2006;1;1);TARİH(2006;1;31))'), '22');
    });
    test('dosyaya İngilizce ad + _xlfn. öneki', () {
      expect(FormulaEngine.toFileFormula('METİNBÖL(A1;" ")'),
          '_xlfn.TEXTSPLIT(A1," ")');
      expect(FormulaEngine.toFileFormula('AL(A1:C9;2)'), '_xlfn.TAKE(A1:C9,2)');
      expect(FormulaEngine.toFileFormula('SÜTUNSEÇ(A1:C9;1)'),
          '_xlfn.CHOOSECOLS(A1:C9,1)');
      expect(FormulaEngine.toFileFormula('ÇAPRAZEŞLEŞTİR(1;A1:A3)'),
          '_xlfn.XMATCH(1,A1:A3)');
      expect(FormulaEngine.toFileFormula('İŞGÜNÜ.ULUSL(A1;5;11)'),
          '_xlfn.WORKDAY.INTL(A1,5,11)');
      expect(FormulaEngine.toFileFormula('MAP(A1:A3;x)'), '_xlfn.MAP(A1:A3,x)');
    });
    test('Türkçe gösterim', () {
      expect(FormulaEngine.toTurkishFormula('_xlfn.TEXTSPLIT(A1," ")'),
          'METİNBÖL(A1;" ")');
      expect(FormulaEngine.toTurkishFormula('_xlfn.VSTACK(A1,B1)'),
          'DÜŞEYYIĞ(A1;B1)');
    });
  });

  /// Kapsam bekçisi (PLAN §1.10 m.2): listedeki her işlev motorda TANINIR
  /// (`#AD?` vermez), tamamlamada görünür ve yardım balonunda imzası var.
  /// Yeni işlev eklendikçe buraya da yazılır; liste yalnız büyür.
  group('kapsam bekçisi', () {
    const covered = [
      'TEXTSPLIT', 'TEXTBEFORE', 'TEXTAFTER', 'VSTACK', 'HSTACK', 'TAKE',
      'DROP', 'CHOOSECOLS', 'CHOOSEROWS', 'LAMBDA', 'MAP', 'REDUCE', 'SCAN',
      'BYROW', 'BYCOL', 'MAKEARRAY', 'NETWORKDAYS.INTL', 'WORKDAY.INTL',
      'XMATCH', 'XLOOKUP', 'IFS', 'SWITCH', 'MAXIFS', 'MINIFS', 'TEXTJOIN',
      'CONCAT', 'FILTER', 'SORT', 'UNIQUE', 'SEQUENCE', 'LET',
    ];
    for (final name in covered) {
      test(name, () {
        expect(_one('=$name(1)'), isNot('#AD?'));
        expect(FormulaEngine.functionNames, contains(name));
        expect(signatureOf(name), isNotNull, reason: 'yardım imzası');
      });
    }
  });
}

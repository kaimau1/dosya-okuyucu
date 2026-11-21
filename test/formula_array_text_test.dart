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

  group('TOCOL / TOROW / WRAPROWS / WRAPCOLS (B10 dilim 3)', () {
    const m = '{1,2,3;4,5,6}';
    test('TOCOL satır satır, sütuna göre tara', () {
      expect(_run('=TOCOL($m)', h: 6, w: 1), [
        ['1'], ['2'], ['3'], ['4'], ['5'], ['6'],
      ]);
      expect(_run('=TOCOL($m,0,TRUE)', h: 6, w: 1), [
        ['1'], ['4'], ['2'], ['5'], ['3'], ['6'],
      ]);
    });
    test('TOROW boşları ve hataları yoksayar', () {
      final data = [
        ['a', '', '=1/0'],
        ['b', 'c', ''],
      ];
      expect(_run('=TOROW(A1:C2,1)', data: data, h: 1, w: 4), [
        ['a', '#SAYI/0!', 'b', 'c'],
      ]);
      expect(_run('=TOROW(A1:C2,3)', data: data, h: 1, w: 4), [
        ['a', 'b', 'c', ''],
      ]);
      expect(_one('=TOROW(A1:C2,4)', data: data), '#DEĞER!');
    });
    test('WRAPROWS doldurma değeriyle, eksik yer #YOK', () {
      expect(_run('=WRAPROWS({1,2,3,4,5},2)', h: 3, w: 2), [
        ['1', '2'],
        ['3', '4'],
        ['5', '#YOK'],
      ]);
      expect(_run('=WRAPROWS({1,2,3,4,5},2,"x")', h: 3, w: 2), [
        ['1', '2'],
        ['3', '4'],
        ['5', 'x'],
      ]);
      expect(_one('=WRAPROWS($m,2)'), '#DEĞER!');
      expect(_one('=WRAPROWS({1,2},0)'), '#SAYI!');
    });
    test('WRAPCOLS sütun sütun', () {
      expect(_run('=WRAPCOLS({1,2,3,4,5},2,0)', h: 2, w: 3), [
        ['1', '3', '5'],
        ['2', '4', '0'],
      ]);
    });
    test('Türkçe ad ve dosya yazımı', () {
      expect(_run('=SATIRSAR({1;2;3;4};2)', h: 2, w: 2), [
        ['1', '2'],
        ['3', '4'],
      ]);
      expect(FormulaEngine.toFileFormula('SÜTUNA(A1:B2)'),
          '_xlfn.TOCOL(A1:B2)');
      expect(FormulaEngine.toTurkishFormula('_xlfn.WRAPCOLS(A1:A9,3)'),
          'SÜTUNSAR(A1:A9;3)');
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
    test('Türkçe yazım: sütun \\, satır ; — dosyada , ve ;', () {
      expect(_one('=TOPLA({1\\2;3\\4})'), '10');
      expect(_one('=SUM({1,5\\2;3\\4})'), '10.5');
      expect(FormulaEngine.toFileFormula('TOPLA({1\\2;3\\4};1)'),
          'SUM({1,2;3,4},1)');
      expect(FormulaEngine.toFileFormula('SUM({1,2;3,4})'), 'SUM({1,2;3,4})');
      expect(FormulaEngine.toTurkishFormula('SUM({1.5,2;3,4},1)'),
          'TOPLA({1,5\\2;3\\4};1)');
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

  /// PLAN §1.10 m.2 kalanı: dosyada LAMBDA/LET parametresi `_xlpm.` önekli
  /// (Excel'in kendi yazımı; öneksiz ad Excel'de `#AD?`).
  group('_xlpm. öneki (dosyaya yazma)', () {
    test('LAMBDA ve LET parametreleri, bildirim + kullanım', () {
      expect(FormulaEngine.toFileFormula('LAMBDA(x,x+1)(2)'),
          '_xlfn.LAMBDA(_xlpm.x,_xlpm.x+1)(2)');
      expect(FormulaEngine.toFileFormula('LET(x,A1*2,y,x+1,x*y)'),
          '_xlfn.LET(_xlpm.x,A1*2,_xlpm.y,_xlpm.x+1,_xlpm.x*_xlpm.y)');
      // LET'e bağlı LAMBDA çağrısı da önek alır.
      expect(FormulaEngine.toFileFormula('LET(f,LAMBDA(a,b,a*b),f(3,4))'),
          '_xlfn.LET(_xlpm.f,_xlfn.LAMBDA(_xlpm.a,_xlpm.b,_xlpm.a*_xlpm.b),_xlpm.f(3,4))');
      expect(FormulaEngine.toFileFormula('MAP(A1:B2,LAMBDA(v,v*2))'),
          '_xlfn.MAP(A1:B2,_xlfn.LAMBDA(_xlpm.v,_xlpm.v*2))');
    });
    test('Türkçe yazım: ; ayırıcı, , ondalık', () {
      expect(FormulaEngine.toFileFormula('LET(x;1,5;y;2;x+y)', turkish: true),
          '_xlfn.LET(_xlpm.x,1.5,_xlpm.y,2,_xlpm.x+_xlpm.y)');
    });
    test('dokunulmayanlar: metin, hücre, sayfa, işlev adı', () {
      expect(FormulaEngine.toFileFormula('LET(x,"x",x&A1)'),
          '_xlfn.LET(_xlpm.x,"x",_xlpm.x&A1)');
      // Parametreyle aynı adlı işlev çağrısı işlev kalır.
      expect(FormulaEngine.toFileFormula('LET(sum,1,SUM(sum,2))'),
          '_xlfn.LET(_xlpm.sum,1,SUM(_xlpm.sum,2))');
      expect(FormulaEngine.toFileFormula('SUM(A1:B2)'), 'SUM(A1:B2)');
    });
    test('LAMBDA ailesi Türkçe adlar (KARAR 2026-11-21)', () {
      expect(_one('=HARİTA({1;2};LAMBDA(v;v*3))'), '3');
      expect(_run('=DİZİOLUŞTUR(2;2;LAMBDA(r;c;r*c))', h: 2, w: 2), [
        ['1', '2'],
        ['2', '4'],
      ]);
      expect(FormulaEngine.toFileFormula('HARİTA(A1:B2;LAMBDA(v;v*2))'),
          '_xlfn.MAP(A1:B2,_xlfn.LAMBDA(_xlpm.v,_xlpm.v*2))');
      expect(FormulaEngine.toTurkishFormula('_xlfn.MAKEARRAY(2,2,1)'),
          'DİZİOLUŞTUR(2;2;1)');
      expect(FormulaEngine.toTurkishFormula('_xlfn.TEXTBEFORE(A1,"-")'),
          'ÖNCEKİMETİN(A1;"-")');
      // İngilizce adlar da çalışmaya devam eder.
      expect(_one('=MAP({1;2},LAMBDA(v,v*3))'), '3');
      expect(_one('=REDUCE(0,{1,2,3},LAMBDA(a,v,a+v))'), '6');
    });
    test('gidiş-dönüş: önekli dosya yazımı aynı kalır, gösterimde öneksiz', () {
      const file = '_xlfn.LAMBDA(_xlpm.n,_xlpm.n*2)(5)';
      expect(FormulaEngine.toFileFormula(file), file);
      expect(FormulaEngine.toTurkishFormula(file), 'LAMBDA(n;n*2)(5)');
      expect(_one('=${FormulaEngine.toFileFormula('LET(x,4,x*x)')}'), '16');
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
      'TOCOL', 'TOROW', 'WRAPROWS', 'WRAPCOLS',
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

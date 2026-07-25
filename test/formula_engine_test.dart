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

  test('metin birleştirme operatörü (&)', () {
    expect(f('="Merhaba "&"dünya"'), 'Merhaba dünya');
    expect(f('="Toplam: "&(2+3)'), 'Toplam: 5');
    // & karşılaştırmadan önce bağlar: "a"&"b"="ab" → DOĞRU
    expect(f('="a"&"b"="ab"'), 'DOĞRU');
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
    expect(f('=SUBSTITUTE("aXbXc","X","-")'), 'a-b-c');
    expect(f('=FIND("b","abc")'), '2');
    expect(f('=REPT("ab",3)'), 'ababab');
    expect(f('=PROPER("ali VELİ")'), 'Ali Veli');
    expect(f('=TEXTJOIN("-",1,"a","b","c")'), 'a-b-c');
  });

  test('matematik fonksiyonları', () {
    expect(f('=ROUND(3.14159,2)'), '3.14');
    expect(f('=ROUNDUP(3.11,1)'), '3.2');
    expect(f('=ROUNDDOWN(3.19,1)'), '3.1');
    expect(f('=ABS(-9)'), '9');
    expect(f('=SQRT(16)'), '4');
    expect(f('=POWER(3,3)'), '27');
    expect(f('=MOD(10,3)'), '1');
    expect(f('=MOD(-1,3)'), '2'); // Excel: sonuç bölenin işaretini alır
    expect(f('=INT(3.9)'), '3');
    expect(f('=CEILING(4.2,1)'), '5');
    expect(f('=SIGN(-4)'), '-1');
  });

  test('IF ve mantık fonksiyonları', () {
    expect(f('=IF(1>2,"büyük","küçük")'), 'küçük');
    expect(f('=IF(5>2,"E","H")'), 'E');
    expect(f('=AND(1>0,2>1)'), 'DOĞRU');
    expect(f('=OR(1>2,3>2)'), 'DOĞRU');
    expect(f('=NOT(1>2)'), 'DOĞRU');
    expect(f('=IFS(1>2,"a",2>1,"b")'), 'b');
    expect(f('=CHOOSE(2,"a","b","c")'), 'b');
  });

  test('Türkçe fonksiyon adları ve `;` argüman ayıracı', () {
    expect(f('=TOPLA(1;2;3)'), '6');
    expect(f('=EĞER(1>2;"büyük";"küçük")'), 'küçük');
    expect(f('=ORTALAMA(2;4)'), '3');
    expect(f('=UZUNLUK("abc")'), '3');
    expect(f('=YUVARLA(2.345;1)'), '2.3');
  });

  test('hücre referansı ve aralık', () {
    final grid = [
      ['10', '20', '30'],
      ['=A1+B1', '=SUM(A1:C1)', '=AVERAGE(A1:C1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '30');
    expect(e.displayValue(1, 1), '60');
    expect(e.displayValue(1, 2), '20');
  });

  test('MIN/MAX/COUNT boş ve metni atlar', () {
    final grid = [
      ['5', '', 'metin', '15'],
      ['=MIN(A1:D1)', '=MAX(A1:D1)', '=COUNT(A1:D1)', '=COUNTA(A1:D1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '5');
    expect(e.displayValue(1, 1), '15');
    expect(e.displayValue(1, 2), '2');
    expect(e.displayValue(1, 3), '3');
  });

  test('koşullu toplama: ETOPLA / EĞERSAY / ÇOKETOPLA', () {
    final grid = [
      ['elma', '10', 'Ankara'],
      ['armut', '20', 'İzmir'],
      ['elma', '30', 'Ankara'],
      ['=SUMIF(A1:A3,"elma",B1:B3)', '=COUNTIF(A1:A3,"elma")'],
      ['=SUMIF(B1:B3,">15")', '=SUMIFS(B1:B3,A1:A3,"elma",C1:C3,"Ankara")'],
      ['=COUNTIF(A1:A3,"el*")', '=AVERAGEIF(A1:A3,"elma",B1:B3)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(3, 0), '40');
    expect(e.displayValue(3, 1), '2');
    expect(e.displayValue(4, 0), '50');
    expect(e.displayValue(4, 1), '40');
    expect(e.displayValue(5, 0), '2'); // joker karakter
    expect(e.displayValue(5, 1), '20');
  });

  test('arama fonksiyonları: DÜŞEYARA / KAÇINCI / İNDİS', () {
    final grid = [
      ['kod', 'ad', 'fiyat'],
      ['A1', 'Kalem', '10'],
      ['A2', 'Defter', '25'],
      ['=VLOOKUP("A2",A1:C3,3,0)', '=MATCH("Defter",B1:B3,0)'],
      ['=INDEX(A1:C3,3,2)', '=DÜŞEYARA("A9",A1:C3,2,0)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(3, 0), '25');
    expect(e.displayValue(3, 1), '3');
    expect(e.displayValue(4, 0), 'Defter');
    expect(e.displayValue(4, 1), '#YOK'); // bulunamadı
  });

  test('istatistik fonksiyonları', () {
    final grid = [
      ['1', '2', '3', '4'],
      ['=MEDIAN(A1:D1)', '=LARGE(A1:D1,2)', '=SMALL(A1:D1,1)', '=STDEV(A1:D1)'],
      ['=SUMPRODUCT(A1:B1,C1:D1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '2.5');
    expect(e.displayValue(1, 1), '3');
    expect(e.displayValue(1, 2), '1');
    expect(e.displayValue(1, 3).startsWith('1.29'), isTrue);
    expect(e.displayValue(2, 0), '11'); // 1*3 + 2*4
  });

  test('tarih fonksiyonları Excel seri numarasıyla çalışır', () {
    // 46224 = 21.07.2026
    final grid = [
      ['46224'],
      ['=YEAR(A1)', '=MONTH(A1)', '=DAY(A1)', '=WEEKDAY(A1,2)'],
      ['=DATE(2026,7,21)', '=EOMONTH(A1,0)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '2026');
    expect(e.displayValue(1, 1), '7');
    expect(e.displayValue(1, 2), '21');
    expect(e.displayValue(1, 3), '2'); // Salı
    expect(e.displayValue(2, 0), '46224');
    expect(e.displayValue(2, 1), '46234'); // 31.07.2026
  });

  test('METNEÇEVİR sayıyı Excel biçimiyle metne çevirir', () {
    expect(f('=TEXT(0.15,"0%")'), '%15');
    expect(f('=TEXT(1234.5,"#,##0.00")'), '1.234,50');
  });

  test('çapraz sayfa referansı', () {
    final veri = [
      ['=Diğer!A1*2', "='Diğer'!A1+1"],
    ];
    final e = FormulaEngine(
      veri,
      sheetName: 'Veri',
      sheets: {
        'Veri': veri,
        'Diğer': [
          ['5']
        ],
      },
    );
    expect(e.displayValue(0, 0), '10');
    expect(e.displayValue(0, 1), '6');
  });

  test('zincirli formül (formül formüle bağlı)', () {
    final grid = [
      ['4'],
      ['=A1*2'],
      ['=A2+1'],
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

  test('gerçek Excel hata değerleri', () {
    expect(f('=1/0'), '#SAYI/0!');
    expect(f('=BILINMEYEN()'), '#AD?');
    expect(f('=UPPER('), '#DEĞER!'); // kapanmayan
    expect(f('=SQRT(-1)'), '#SAYI!');
    final grid = [
      ['metin'],
      ['=A1+5'],
    ];
    expect(FormulaEngine(grid).displayValue(1, 0), '#DEĞER!');
  });

  test('EĞERHATA hatayı yakalar', () {
    expect(f('=IFERROR(1/0,"yok")'), 'yok');
    expect(f('=IFERROR(4/2,"yok")'), '2');
    expect(f('=EĞERHATA(1/0;0)'), '0');
    expect(f('=ISERROR(1/0)'), 'DOĞRU');
    expect(f('=ISNUMBER(5)'), 'DOĞRU');
  });

  group('preview (formül çubuğu canlı önizleme)', () {
    test('yazılan formülü ızgaraya göre hesaplar', () {
      final grid = [
        ['10', '20'],
        ['', ''],
      ];
      expect(FormulaEngine(grid).preview('=A1+B1', 1, 0), '30');
    });

    test('formül olmayan girdi boş önizleme', () {
      expect(FormulaEngine([['x']]).preview('düz metin', 0, 0), '');
      expect(FormulaEngine([['x']]).preview('=', 0, 0), '');
    });

    test('kendine referans → #DÖNGÜ', () {
      expect(FormulaEngine([['=A1']]).preview('=A1', 0, 0), '#DÖNGÜ');
    });

    test('hatalı formül → #DEĞER!', () {
      expect(FormulaEngine([['']]).preview('=1+', 0, 0), '#DEĞER!');
    });
  });
}

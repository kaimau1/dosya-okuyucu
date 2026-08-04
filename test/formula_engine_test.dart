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

  // ── Excel sadakati turu: başvuru / istatistik / tarih / finans ──────────

  test('SATIR ve SÜTUN argümansız kendi hücresini verir', () {
    final grid = [
      ['', ''],
      ['', '=ROW()'],
      ['', '=COLUMN()'],
      ['', '=ROW(C7)'],
      ['', '=SÜTUN(C7)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 1), '2');
    expect(e.displayValue(2, 1), '2');
    expect(e.displayValue(3, 1), '7');
    expect(e.displayValue(4, 1), '3');
  });

  test('KAYDIR (OFFSET) ve DOLAYLI (INDIRECT)', () {
    final grid = [
      ['10', '20', '30'],
      ['40', '50', '60'],
      ['=OFFSET(A1,1,2)', '=SUM(OFFSET(A1,0,0,2,3))'],
      ['=INDIRECT("B2")', '=SUM(INDIRECT("A1:C1"))'],
      ['=KAYDIR(A1,5,0)', '=DOLAYLI("Z")'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(2, 0), '60');
    expect(e.displayValue(2, 1), '210');
    expect(e.displayValue(3, 0), '50');
    expect(e.displayValue(3, 1), '60');
    expect(e.displayValue(4, 0), ''); // boş hücreye kaydırma
    expect(e.displayValue(4, 1), '#BAŞV!');
  });

  test('ADRES, FORMÜLMETNİ, EFORMÜLSE, EREFSE', () {
    final grid = [
      ['5', '=A1*2'],
      ['=ADDRESS(2,3)', '=ADRES(2,3,4)'],
      ['=FORMULATEXT(B1)', '=ISFORMULA(B1)'],
      ['=EFORMÜLSE(A1)', '=ISREF(A1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), r'$C$2');
    expect(e.displayValue(1, 1), 'C2');
    expect(e.displayValue(2, 0), '=A1*2');
    expect(e.displayValue(2, 1), 'DOĞRU');
    expect(e.displayValue(3, 0), 'YANLIŞ');
    expect(e.displayValue(3, 1), 'DOĞRU');
  });

  test('ARA (LOOKUP) ve ÇAPRAZARA (XLOOKUP)', () {
    final grid = [
      ['10', 'Ucuz'],
      ['20', 'Orta'],
      ['30', 'Pahalı'],
      ['=LOOKUP(25,A1:A3,B1:B3)', '=XLOOKUP(20,A1:A3,B1:B3)'],
      ['=XLOOKUP(99,A1:A3,B1:B3,"yok")', '=ÇAPRAZARA(25,A1:A3,B1:B3,"-",-1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(3, 0), 'Orta'); // 25 → son küçük eşit (20)
    expect(e.displayValue(3, 1), 'Orta');
    expect(e.displayValue(4, 0), 'yok');
    expect(e.displayValue(4, 1), 'Orta'); // sonraki küçük
  });

  test('KYUVARLA (MROUND) ve TAVANAYUVARLA Türkçe adlarla', () {
    expect(f('=MROUND(17,5)'), '15');
    expect(f('=KYUVARLA(18,5)'), '20');
    expect(f('=MROUND(-17,5)'), '#SAYI!'); // işaretler farklı
    expect(f('=TAVANAYUVARLA(4.2,1)'), '5');
    expect(f('=CEILING.MATH(-4.2)'), '-4');
    expect(f('=FLOOR.MATH(-4.2)'), '-5');
    expect(f('=COMBIN(5,2)'), '10');
    expect(f('=PERMUT(5,2)'), '20');
  });

  test('istatistik: ORTALAMAA / YÜZDEBİRLİK / DÖRTTEBİRLİK / ORTSAP', () {
    final grid = [
      ['1', '2', '3', '4'],
      ['=PERCENTILE(A1:D1,0.5)', '=QUARTILE(A1:D1,1)'],
      ['=AVEDEV(A1:D1)', '=DEVSQ(A1:D1)'],
      ['=GEOMEAN(A1:D1)', '=PERCENTRANK(A1:D1,3)'],
      ['metin', '=AVERAGEA(A1:D1,A5)', '=AVERAGE(A1:D1,A5)'],
      ['=STDEV.S(A1:D1)', '=VAR.P(A1:D1)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '2.5');
    expect(e.displayValue(1, 1), '1.75');
    expect(e.displayValue(2, 0), '1');
    expect(e.displayValue(2, 1), '5');
    expect(e.displayValue(3, 1), '0.667');
    // AVERAGEA metni 0 sayar (10/5), AVERAGE atlar (10/4).
    expect(e.displayValue(4, 1), '2');
    expect(e.displayValue(4, 2), '2.5');
    // Noktalı (Excel 2010+) adlar da tanınır.
    expect(e.displayValue(5, 0), '1.2909944487');
    expect(e.displayValue(5, 1), '1.25');
  });

  test('metin: METİNÖNCE / METİNSONRA / SAYIDEĞERİ / SAYIDÜZENLE', () {
    expect(f('=TEXTBEFORE("ali@site.com","@")'), 'ali');
    expect(f('=TEXTAFTER("ali@site.com","@")'), 'site.com');
    expect(f('=METİNÖNCE("a-b-c","-",2)'), 'a-b');
    expect(f('=NUMBERVALUE("1.234,50")'), '1234.5');
    expect(f('=SAYIDEĞERİ("%15")'), '0.15');
    expect(f('=FIXED(1234.5678,2)'), '1.234,57');
    expect(f('=UNICHAR(199)'), 'Ç');
    expect(f('=UNICODE("Ç")'), '199');
  });

  test('tarih: HAFTASAY / TAMİŞGÜNÜ / İŞGÜNÜ / TARİHSAYISI / YILORAN', () {
    // 21.07.2026 Salı = 46224
    expect(f('=DATEVALUE("21.07.2026")'), '46224');
    expect(f('=TARİHSAYISI("2026-07-21")'), '46224');
    expect(f('=TIMEVALUE("06:00")'), '0.25');
    expect(f('=WEEKNUM(46224)'), '30');
    // 20.07.2026 Pazartesi → 24.07.2026 Cuma = 5 iş günü
    expect(f('=NETWORKDAYS(46223,46227)'), '5');
    // Cumadan bir iş günü sonrası pazartesidir.
    expect(f('=WORKDAY(46227,1)'), '46230');
    // 01.01.2026 → 01.01.2027 tam yıl; 30/360 tabanında 31 Ocak 30 gün eder.
    expect(f('=YEARFRAC(46023,46388)'), '1');
    expect(f('=YILORAN(46023,46053)'), '0.0833333333');
  });

  test('finans: DEVRESEL_ÖDEME / BD / GD / TAKSİT_SAYISI / FAİZ_ORANI', () {
    // 12 ay, yıllık %10, 1000 TL kredi → aylık taksit ≈ -87,92
    expect(f('=ROUND(PMT(0.1/12,12,1000),2)'), '-87.92');
    expect(f('=ROUND(DEVRESEL_ÖDEME(0,12,1200),2)'), '-100');
    expect(f('=ROUND(FV(0.05,10,-100,0),2)'), '1257.79');
    expect(f('=ROUND(PV(0.05,10,-100,0),2)'), '772.17');
    expect(f('=ROUND(NPER(0.05,-100,772.17),2)'), '10');
    expect(f('=ROUND(RATE(10,-100,772.17),4)'), '0.05');
    expect(f('=ROUND(IPMT(0.1/12,1,12,1000),2)'), '-8.33');
    expect(f('=ROUND(PPMT(0.1/12,1,12,1000),2)'), '-79.58');
    expect(f('=SLN(10000,1000,5)'), '1800');
  });

  test('finans: NBD ve İÇ_VERİM_ORANI aralıkla çalışır', () {
    final grid = [
      ['-1000', '400', '400', '400'],
      ['=ROUND(NPV(0.1,B1:D1),2)', '=ROUND(IRR(A1:D1),4)'],
    ];
    final e = FormulaEngine(grid);
    expect(e.displayValue(1, 0), '994.74');
    expect(e.displayValue(1, 1), '0.097');
  });

  test('ÇİFTMİ / TEKMİ / HATA.TİPİ', () {
    expect(f('=ISEVEN(4)'), 'DOĞRU');
    expect(f('=ISODD(4)'), 'YANLIŞ');
    expect(f('=ÇİFTMİ(3)'), 'YANLIŞ');
    expect(f('=ERROR.TYPE(1/0)'), '2');
    expect(f('=HATA.TİPİ(BILINMEYEN())'), '5');
    expect(f('=ERROR.TYPE(5)'), '#YOK');
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

  group('otomatik tamamlama', () {
    test('yarım addan işlev önerir (Türkçe ve İngilizce)', () {
      expect(FormulaEngine.completionsFor('TOP'), contains('TOPLA'));
      expect(FormulaEngine.completionsFor('SUM'), contains('SUM'));
      // Küçük harfle de bulunmalı.
      expect(FormulaEngine.completionsFor('top'), contains('TOPLA'));
    });

    test('baştan eşleşme yoksa İÇİNDE geçenler önerilir', () {
      // "ARA" ile başlayan yoksa DÜŞEYARA/YATAYARA gibi adlar gelmeli.
      final hits = FormulaEngine.completionsFor('EYARA');
      expect(hits, isNotEmpty);
      expect(hits.every((h) => h.contains('EYARA')), isTrue);
    });

    test('boş önek öneri vermez', () {
      expect(FormulaEngine.completionsFor(''), isEmpty);
    });

    test('öneri sayısı sınırı aşmaz', () {
      expect(FormulaEngine.completionsFor('A', limit: 3).length,
          lessThanOrEqualTo(3));
    });

    test('işlev listesi motorun takma ad tablosundan gelir', () {
      final names = FormulaEngine.functionNames;
      expect(names, contains('TOPLA'));
      expect(names, contains('SUM'));
      // Sıralı ve tekrarsız olmalı.
      expect(names.toSet().length, names.length);
    });
  });
}

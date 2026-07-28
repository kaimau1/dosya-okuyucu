import 'dart:convert';

import 'package:dosya_okuyucu/services/pdf/pdf_font_map.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_font_metrics.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_paragraph.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_paragraph_layout.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Paragraf bazlı düzenleme** — kullanıcının kararı (2026-07-27):
/// "kişi isterse 1 harf isterse 1 kelime isterse 1 cümle değiştirir, paragraf
/// ona göre yeniden yazılır, font/boyut/sayfa düzeni korunur."
///
/// Buradaki fontta her glif 500/1000 em: 10 puntoda her harf tam 5 birim.
/// Böylece beklenen konumlar elle hesaplanabiliyor ve testler "yaklaşık"
/// değil KESİN.
void main() {
  final ascii = PdfFontEncoding(
    toUnicode: {for (var c = 32; c < 127; c++) c: String.fromCharCode(c)},
    fromUnicode: {for (var c = 32; c < 127; c++) String.fromCharCode(c): c},
    codeBytes: 1,
  );
  const halfEm = PdfFontMetrics(widths: {}, defaultWidth: 500);

  final fonts = PdfFontAccess(
    encodings: {'F1': ascii, 'F2': ascii},
    metrics: {'F1': halfEm, 'F2': halfEm},
  );

  List<PdfParagraph> parse(String content, {List<double>? pageBox}) =>
      findParagraphs([latin1.encode(content)], fonts, pageBox: pageBox);

  String rewrite(String content, PdfParagraph paragraph, String newText) =>
      latin1.decode(
        rewriteParagraph(
          content: latin1.encode(content),
          paragraph: paragraph,
          newText: newText,
          fonts: fonts,
        ),
        allowInvalid: true,
      );

  // Üç satırlık bir paragraf: 50'den başlıyor, satır aralığı 12.
  const threeLines = 'BT /F1 10 Tf '
      '1 0 0 1 50 700 Tm (AAAA) Tj '
      '1 0 0 1 50 688 Tm (BBBB) Tj '
      '1 0 0 1 50 676 Tm (CC) Tj '
      'ET';

  group('paragraf bulma', () {
    test('bitişik satırlar tek paragrafta toplanır', () {
      final paragraphs = parse(threeLines);
      expect(paragraphs, hasLength(1));
      expect(paragraphs.single.text, 'AAAA BBBB CC');
      expect(paragraphs.single.lineCount, 3);
      expect(paragraphs.single.leading, closeTo(12, 1e-6));
    });

    test('araya giren büyük boşluk yeni paragraf başlatır', () {
      // Satır aralığı 12 iken 40 birimlik boşluk = yeni paragraf.
      const content = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAAA) Tj '
          '1 0 0 1 50 688 Tm (BBBB) Tj '
          '1 0 0 1 50 648 Tm (CCCC) Tj '
          'ET';
      final paragraphs = parse(content);
      expect(paragraphs, hasLength(2));
      expect(paragraphs.first.text, 'AAAA BBBB');
      expect(paragraphs.last.text, 'CCCC');
    });

    test('yan sütun aynı paragrafa girmez', () {
      // Aynı yükseklikte ama çok uzakta: yatay örtüşme yok.
      const content = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAAA) Tj '
          '1 0 0 1 400 688 Tm (BBBB) Tj '
          'ET';
      final paragraphs = parse(content);
      expect(paragraphs, hasLength(2));
    });

    test('TJ kerning boşluğu kelime arası olarak okunur', () {
      // PDF'te iki kelime arası çoğu zaman boşluk KARAKTERİ değil, kaydırma
      // sayısıdır; yok sayarsak kullanıcıya "AliVeli" gösterirdik.
      const content =
          'BT /F1 10 Tf 1 0 0 1 50 700 Tm [(Ali) -300 (Veli)] TJ ET';
      expect(parse(content).single.text, 'Ali Veli');
    });

    test('sınırlar sayfa uzayında verilir (cm dönüşümü uygulanır)', () {
      // `cm` ile 2 kat büyütülmüş metin: dokunma eşlemesi sayfa uzayında olmalı.
      const content = 'q 2 0 0 2 0 0 cm '
          'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj ET Q';
      final paragraph = parse(content).single;
      expect(paragraph.left, closeTo(100, 1e-6));
      expect(paragraph.right, closeTo(140, 1e-6)); // (50+20) × 2
      expect(paragraph.contains(120, 1402), isTrue);
      expect(paragraph.contains(20, 1402), isFalse);
    });
  });

  group('yeniden dizme', () {
    test('kısalan kelime satırı bozmaz, konum aynı kalır', () {
      final paragraph = parse(threeLines).single;
      final out = rewrite(threeLines, paragraph, 'AAAA BB CC');
      expect(out, contains('1 0 0 1 50 700 Tm'));
      expect(out, contains('(AAAA) Tj'));
      expect(out, contains('1 0 0 1 50 688 Tm'));
      expect(out, contains('(BB) Tj'));
      expect(out, contains('1 0 0 1 50 676 Tm'));
      expect(out, contains('(CC) Tj'));
      // BT/ET dışına dokunulmadı.
      expect(out.startsWith('BT /F1 10 Tf '), isTrue);
      expect(out.trimRight().endsWith('ET'), isTrue);
    });

    test('uzayan metin yeni satıra sarılır (satır aralığı korunur)', () {
      final paragraph = parse(threeLines).single;
      final out = rewrite(threeLines, paragraph, 'AAAA BBBB CCCC DDDD');
      // Dördüncü satır 676 − 12 = 664'te olmalı.
      expect(out, contains('1 0 0 1 50 664 Tm'));
      expect(out, contains('(DDDD) Tj'));
    });

    test('sığmayan metin REDDEDİLİR, belge bozulmaz', () {
      // Paragrafın 26 birim altında başka bir paragraf var → yalnız 1 satır
      // yer kalıyor, 3 satır fazla gelirse iş yapılmamalı.
      const content = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAAA) Tj '
          '1 0 0 1 50 688 Tm (BBBB) Tj '
          '1 0 0 1 50 676 Tm (CC) Tj '
          '1 0 0 1 50 650 Tm (ZZZZ) Tj '
          'ET';
      final paragraph = parse(content).first;
      expect(paragraph.text, 'AAAA BBBB CC');
      expect(
        () => rewrite(content, paragraph,
            'AAAA BBBB CCCC DDDD EEEE FFFF GGGG HHHH'),
        throwsA(isA<PdfParagraphRefused>().having(
            (e) => e.message, 'mesaj', contains('sığmıyor'))),
      );
    });

    test('dokunulmayan kısımlar kendi yazı tipini korur', () {
      // İki koşu: F1 ile "AA", F2 ile "BB". Ortadaki harf değişince
      // yalnız o koşu etkilenmeli.
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AA) Tj '
          '/F2 10 Tf 1 0 0 1 60 700 Tm (BB) Tj ET';
      final paragraph = parse(content).single;
      expect(paragraph.text, 'AABB');
      expect(paragraph.runs, hasLength(2));

      final out = rewrite(content, paragraph, 'AAXB');
      expect(out, contains('/F1 10 Tf'));
      expect(out, contains('(AA) Tj'));
      expect(out, contains('/F2 10 Tf'));
      expect(out, contains('(XB) Tj'));
    });

    test('renk operatörü koşuyla birlikte taşınır', () {
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AA) Tj '
          '1 0 0 rg 1 0 0 1 60 700 Tm (BB) Tj ET';
      final paragraph = parse(content).single;
      final out = rewrite(content, paragraph, 'AACC');
      expect(out, contains('1 0 0 rg'));
    });

    test('her satırı ayrı BT/ET bloğunda olan paragraf yeniden dizilir', () {
      // Resmi yazı üreticileri (EBYS) her SATIRI ayrı metin nesnesine yazar.
      // Eskiden aralıktaki `ET` yüzünden böyle belgelerde tek bir paragraf
      // bile düzenlenemiyordu — kullanıcı bildirimi 2026-07-28.
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj ET '
          'BT /F1 10 Tf 1 0 0 1 50 688 Tm (BBBB) Tj ET '
          'BT /F1 10 Tf 1 0 0 1 50 676 Tm (CC) Tj ET';
      final paragraph = parse(content).single;
      expect(paragraph.text, 'AAAA BBBB CC');

      final out = rewrite(content, paragraph, 'AAAA BB CC');
      expect(out, contains('(BB) Tj'));
      expect(out, contains('1 0 0 1 50 688 Tm'));
      // Asıl güvence: silinen `ET` ve `BT` sayısı eşit → yığın dengede.
      expect('BT '.allMatches(out).length, 'ET'.allMatches(out).length);
    });

    test('her satırı ayrı q…Q bloğunda olan paragraf yeniden dizilir', () {
      // Aynı belgelerin ikinci kalıbı: satır hem `BT…ET` hem `q…Q` içinde.
      // Kullanıcı bildirimi 2026-07-28: "hâlâ yeterince serbest değiliz" —
      // ekranda `Q` operatörü için ret mesajı çıkıyordu.
      const content = 'q BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj ET Q '
          'q BT /F1 10 Tf 1 0 0 1 50 688 Tm (BBBB) Tj ET Q '
          'q BT /F1 10 Tf 1 0 0 1 50 676 Tm (CC) Tj ET Q';
      final paragraph = parse(content).single;
      expect(paragraph.text, 'AAAA BBBB CC');
      expect(paragraph.uniformGraphics, isTrue);

      final out = rewrite(content, paragraph, 'AAAA BB CC');
      expect(out, contains('(BB) Tj'));
      expect('q '.allMatches(out).length, 'Q'.allMatches(out).length);
      expect('BT '.allMatches(out).length, 'ET'.allMatches(out).length);
    });

    test('kırpma altındaki bloklar birleştirilmez (yazı kesilirdi)', () {
      // Bir öncekiyle AYNI içerik, tek farkı dışarıda bir kırpma yolu olması.
      // `Q` kırpmayı da geri alır; blokları birleştirmek yazının bir kısmını
      // kestirebilir → izin yok, eski ret mesajı geçerli.
      const content = 'q 40 600 200 200 re W n '
          'q BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj ET Q '
          'q BT /F1 10 Tf 1 0 0 1 50 688 Tm (BBBB) Tj ET Q Q';
      final paragraph = parse(content).single;
      expect(paragraph.uniformGraphics, isFalse);
      expect(
        () => rewrite(content, paragraph, 'AAAA BBB'),
        throwsA(isA<PdfParagraphRefused>()
            .having((e) => e.message, 'mesaj', contains('`Q`'))),
      );
    });

    test('ortalı başlık kısalınca ORTALI kalır', () {
      // A4 (595 birim) sayfada ortalanmış tek satırlık başlık: 8 harf × 5 =
      // 40 birim, 277.5'ten başlıyor → ortası tam 297.5 = sayfa ortası.
      const content =
          'BT /F1 10 Tf 1 0 0 1 277.5 700 Tm (AAAABBBB) Tj ET '
          'BT /F1 10 Tf 1 0 0 1 50 600 Tm (CCCCCCCCCC) Tj ET';
      final paragraph =
          parse(content, pageBox: const [0, 0, 595, 842]).first;
      expect(paragraph.text, 'AAAABBBB');
      expect(paragraph.centered, isTrue);

      // 4 harfe düşüyor (20 birim) → sol kenar 297.5 − 10 = 287.5 olmalı.
      final out = rewrite(content, paragraph, 'AABB');
      expect(out, contains('1 0 0 1 287.5 700 Tm'));
      expect(out, contains('(AABB) Tj'));
    });

    test('sayfayı dolduran gövde paragrafı ortalı SAYILMAZ', () {
      // Ortası tanım gereği sayfa ortasına denk gelir; ortalı sayarsak sol
      // kenarını bozardık.
      const content = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA) Tj '
          'ET';
      final paragraph =
          parse(content, pageBox: const [0, 0, 595, 842]).single;
      expect(paragraph.centered, isFalse);
    });

    test('metin dışı çizim içeren aralık reddedilir', () {
      // `q`/`Q` yığınının içinden bir şey çıkarmak akışı dengesiz bırakır.
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj '
          'ET q 1 0 0 1 0 0 cm Q BT /F1 10 Tf 1 0 0 1 50 688 Tm (BBBB) Tj ET';
      final paragraph = parse(content).single;
      expect(
        () => rewrite(content, paragraph, 'AAAA BBBB CC'),
        throwsA(isA<PdfParagraphRefused>()),
      );
    });

    test('yazı tipinde olmayan harf reddedilir', () {
      final limited = PdfFontAccess(
        encodings: {
          'F1': PdfFontEncoding(
            toUnicode: const {65: 'A', 66: 'B', 32: ' '},
            fromUnicode: const {'A': 65, 'B': 66, ' ': 32},
            codeBytes: 1,
          ),
        },
        metrics: const {'F1': halfEm},
      );
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAAA) Tj ET';
      final paragraph = findParagraphs([latin1.encode(content)], limited).single;
      expect(
        () => rewriteParagraph(
          content: latin1.encode(content),
          paragraph: paragraph,
          newText: 'AAAÇ',
          fonts: limited,
        ),
        throwsA(isA<PdfParagraphRefused>().having(
            (e) => e.message, 'mesaj', contains('yazı tipinde yok'))),
      );
    });

    test('boş paragraf reddedilir', () {
      final paragraph = parse(threeLines).single;
      expect(() => rewrite(threeLines, paragraph, '   '),
          throwsA(isA<PdfParagraphRefused>()));
    });
  });

  group('iki yana yaslama', () {
    test('son satır hariç boşluklar sağ kenara kadar dağıtılır', () {
      // İki satır, ikisi de 50–90 arası (40 birim = 8 harf).
      const content = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AA) Tj '
          '1 0 0 1 60 700 Tm (BB) Tj '
          '1 0 0 1 80 700 Tm (CC) Tj '
          '1 0 0 1 50 688 Tm (DDDDDDDD) Tj '
          'ET';
      final paragraph = parse(content).single;
      expect(paragraph.justified, isTrue);

      final out = rewrite(content, paragraph, 'AA BB CC DDDDDDDD');
      // İlk satır yaslanır: AA(10) BB(10) CC(10) = 30, boşluk payı 40−30 = 10,
      // iki boşluğa 5'er düşer → CC 80'de başlar.
      expect(out, contains('1 0 0 1 50 700 Tm'));
      expect(out, contains('1 0 0 1 80 700 Tm'));
      // Son satır yaslanmaz.
      expect(out, contains('1 0 0 1 50 688 Tm'));
    });
  });
}

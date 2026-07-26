import 'dart:convert';

import 'package:dosya_okuyucu/services/pdf/pdf_font_map.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_font_metrics.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_text_replace.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Yeniden hizalama** — kullanıcının "Word belgesi düzenler gibi" isteği.
///
/// PDF'te bir satır çoğu zaman ayrı ayrı KONUMLANDIRILMIŞ parçalardan oluşur.
/// Bir kelimeyi uzatınca sonraki parça yerinde kaldığı için üstüne biniyor,
/// kısaltınca arada boşluk kalıyordu. Artık genişlik farkı belgenin kendi glif
/// tablolarıyla ölçülüp satırın kalanı o kadar kaydırılıyor.
///
/// Buradaki fontta her glif 500/1000 em: 10 puntoda her harf tam 5 birim.
/// Böylece beklenen kayma elle hesaplanabiliyor ve test "yaklaşık" değil KESİN.
void main() {
  // Tek baytlık ASCII kodlaması (kod = karakter kodu).
  final ascii = PdfFontEncoding(
    toUnicode: {for (var c = 32; c < 127; c++) c: String.fromCharCode(c)},
    fromUnicode: {
      for (var c = 32; c < 127; c++) String.fromCharCode(c): c,
    },
    codeBytes: 1,
  );
  const halfEm = PdfFontMetrics(widths: {}, defaultWidth: 500);

  PdfContentReplacement replace(String content, String from, String to,
      {List<double>? mediaBox}) {
    return replaceTextInContent(
      latin1.encode(content),
      from,
      to,
      fontEncodings: {'F1': ascii},
      fontMetrics: {'F1': halfEm},
      mediaBox: mediaBox,
    );
  }

  String textOf(PdfContentReplacement r) =>
      latin1.decode(r.content, allowInvalid: true);

  group('mutlak konumlu (Tm) satır', () {
    const line = 'BT /F1 10 Tf '
        '1 0 0 1 50 700 Tm (AAA) Tj '
        '1 0 0 1 65 700 Tm (BBB) Tj '
        '1 0 0 1 50 680 Tm (CCC) Tj ET';

    test('uzayan metinde satırın kalanı SAĞA kayar', () {
      // AAA = 3 harf x 5 = 15 birim; AAAA = 20 → fark 5 → 65 + 5 = 70.
      final out = replace(line, 'AAA', 'AAAA');

      expect(out.reflowed, isTrue);
      expect(textOf(out), contains('1 0 0 1 70 700 Tm'));
    });

    test('kısalan metinde satırın kalanı SOLA kayar (boşluk kalmaz)', () {
      // AAA = 15; A = 5 → fark -10 → 65 - 10 = 55.
      final out = replace(line, 'AAA', 'A');

      expect(textOf(out), contains('1 0 0 1 55 700 Tm'));
    });

    test('BAŞKA satır kımıldamaz', () {
      final out = replace(line, 'AAA', 'AAAA');

      expect(textOf(out), contains('1 0 0 1 50 680 Tm'),
          reason: 'alt satır da kaymış');
    });

    test('düzenlenen parçanın kendi konumu değişmez', () {
      final out = replace(line, 'AAA', 'AAAA');

      expect(textOf(out), contains('1 0 0 1 50 700 Tm'));
    });

    test('aynı genişlikte metinde hiçbir sayı değişmez', () {
      final out = replace(line, 'AAA', 'XYZ');

      expect(out.reflowed, isFalse);
      expect(textOf(out), contains('1 0 0 1 65 700 Tm'));
    });

    test('satırdaki HER mutlak konum ayrı ayrı kaydırılır', () {
      const three = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAA) Tj '
          '1 0 0 1 65 700 Tm (BBB) Tj '
          '1 0 0 1 80 700 Tm (CCC) Tj ET';
      final out = replace(three, 'AAA', 'AAAA');

      final text = textOf(out);
      expect(text, contains('1 0 0 1 70 700 Tm'));
      expect(text, contains('1 0 0 1 85 700 Tm'));
    });

    test('düzenlemenin SOLUNDA kalan metne dokunulmaz', () {
      // İkinci parça sayfada daha solda: üreticiler metni sırasız yazabilir.
      const outOfOrder = 'BT /F1 10 Tf '
          '1 0 0 1 200 700 Tm (AAA) Tj '
          '1 0 0 1 50 700 Tm (BBB) Tj ET';
      final out = replace(outOfOrder, 'AAA', 'AAAA');

      expect(textOf(out), contains('1 0 0 1 50 700 Tm'));
    });
  });

  group('göreli konumlu (Td) satır', () {
    test('ilk Td kaydırılır', () {
      const line = 'BT /F1 10 Tf 50 700 Td (AAA) Tj 15 0 Td (BBB) Tj ET';
      final out = replace(line, 'AAA', 'AAAA');

      expect(textOf(out), contains('20 0 Td'));
    });

    test('sonraki Td İKİNCİ kez kaydırılmaz (kayma iki katına çıkmasın)', () {
      // Td göreli: satır matrisi bir kez kaydıktan sonra kalanı onu miras alır.
      const line = 'BT /F1 10 Tf 50 700 Td (AAA) Tj '
          '15 0 Td (BBB) Tj 15 0 Td (CCC) Tj ET';
      final out = replace(line, 'AAA', 'AAAA');

      final text = textOf(out);
      expect(text, contains('20 0 Td'));
      expect(text, contains('15 0 Td'), reason: 'ikinci Td de kaydırılmış');
    });

    test('alt satıra geçen Td (ty != 0) kaydırılmaz', () {
      const line = 'BT /F1 10 Tf 50 700 Td (AAA) Tj 0 -14 Td (BBB) Tj ET';
      final out = replace(line, 'AAA', 'AAAA');

      expect(textOf(out), contains('0 -14 Td'));
    });
  });

  group('güvenlik: ne zaman hizalama YAPILMAZ', () {
    test('döndürülmüş metinde dokunulmaz', () {
      const rotated = 'BT /F1 10 Tf '
          '0 1 -1 0 50 700 Tm (AAA) Tj '
          '0 1 -1 0 50 715 Tm (BBB) Tj ET';
      final out = replace(rotated, 'AAA', 'AAAA');

      expect(out.reflowed, isFalse);
      expect(textOf(out), contains('0 1 -1 0 50 715 Tm'));
    });

    test('genişliği ölçülemeyen fontta dokunulmaz', () {
      const line = 'BT /F1 10 Tf '
          '1 0 0 1 50 700 Tm (AAA) Tj '
          '1 0 0 1 65 700 Tm (BBB) Tj ET';
      final out = replaceTextInContent(
        latin1.encode(line),
        'AAA',
        'AAAA',
        fontEncodings: {'F1': ascii},
        // Genişlik tablosu YOK.
        fontMetrics: const {},
      );

      expect(out.reflowed, isFalse);
      expect(latin1.decode(out.content, allowInvalid: true),
          contains('1 0 0 1 65 700 Tm'));
    });

    test('metin nesnesi bitince (ET) durulur', () {
      const two = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAA) Tj ET '
          'BT /F1 10 Tf 1 0 0 1 65 700 Tm (BBB) Tj ET';
      final out = replace(two, 'AAA', 'AAAA');

      expect(textOf(out), contains('1 0 0 1 65 700 Tm'));
    });
  });

  group('özgün baytların korunması', () {
    test('TJ dizisindeki kerning sayıları ve dokunulmamış parçalar kalır', () {
      // Eskiden bütün dizi tek dizeye indirgeniyordu: metin doğru çıkıyordu ama
      // harf aralıkları siliniyordu — "hiç dokunulmadı" sözü tam doğru değildi.
      const content =
          'BT /F1 10 Tf 1 0 0 1 50 700 Tm [(AA) -20 (BB) -15 (CC)] TJ ET';
      final out = replace(content, 'BB', 'DD');

      final text = textOf(out);
      expect(text, contains('-20'));
      expect(text, contains('-15'));
      expect(text, contains('(AA)'));
      expect(text, contains('(DD)'));
      expect(text, contains('(CC)'));
    });

    test('onaltılık dize onaltılık kalır', () {
      const content = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm <414243> Tj ET';
      final out = replace(content, 'ABC', 'ABD');

      expect(textOf(out), contains('<414244>'));
    });

    test("' operatörünün satır atlaması korunur", () {
      const content = "BT /F1 10 Tf 14 TL 1 0 0 1 50 700 Tm (AAA) ' ET";
      final out = replace(content, 'AAA', 'BBB');

      expect(textOf(out), contains("(BBB) '"));
    });

    test('" operatörünün aralık sayıları korunur', () {
      const content = 'BT /F1 10 Tf 14 TL 1 0 0 1 50 700 Tm 2 1 (AAA) " ET';
      final out = replace(content, 'AAA', 'BBB');

      expect(textOf(out), contains('2 1 (BBB) "'));
    });
  });

  group('taşma uyarısı', () {
    // Sayfa 200 birim geniş, metin 50'den başlıyor → sağ sınır 150 kabul edilir.
    const line = 'BT /F1 10 Tf 1 0 0 1 50 700 Tm (AAA) Tj ET';
    const page = [0.0, 0.0, 200.0, 800.0];

    test('sığan metin uyarı üretmez', () {
      final out = replace(line, 'AAA', 'AAAAAA', mediaBox: page);

      expect(out.overflows, isFalse);
    });

    test('metin alanını aşan metin uyarı üretir', () {
      // 30 harf x 5 = 150 birim → sağ kenar 200 > 150 sınırı.
      final out = replace(line, 'AAA', 'A' * 30, mediaBox: page);

      expect(out.overflows, isTrue);
    });

    test('çizim alanı bilinmiyorsa uyarı verilmez (tahmin üzerine kurulmaz)', () {
      final out = replace(line, 'AAA', 'A' * 30);

      expect(out.overflows, isFalse);
    });
  });
}

import 'package:dosya_okuyucu/services/pdf/pdf_font_map.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_glyph_names.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_paragraph.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Türkçe karakter sorunu** (2026-08-06 kullanıcı ekran görüntüsü):
/// paragraf düzenleyici `T.C. ANKARA ÜNÝVERSÝTESÝ REKTÖRLÜÐÜ` gösteriyordu.
/// Belge ekranda doğru çiziliyordu; yanlış olan bizim OKUMAMIZDI — `/ToUnicode`
/// taşımayan fontta Latin-1 varsayıyorduk (0xDD → `Ý`, 0xD0 → `Ð`).
///
/// İki savunma hattı test ediliyor:
/// 1. Fontun `/Encoding /Differences` tablosu (glif ADIYLA doğru harf).
/// 2. Hiçbir bilgi yoksa yedek tablo — Latin-1 değil **CP1254**.
void main() {
  group('glif adı → Unicode', () {
    test('Türkçe adlar', () {
      expect(glyphNameToRune('Gbreve'), 0x011E);
      expect(glyphNameToRune('gbreve'), 0x011F);
      expect(glyphNameToRune('Idotaccent'), 0x0130);
      expect(glyphNameToRune('dotlessi'), 0x0131);
      expect(glyphNameToRune('Scedilla'), 0x015E);
      expect(glyphNameToRune('scedilla'), 0x015F);
    });

    test('tek harflik ad harfin kendisidir, sonek atılır', () {
      expect(glyphNameToRune('A'), 0x41);
      expect(glyphNameToRune('z'), 0x7A);
      expect(glyphNameToRune('a.sc'), 0x61);
    });

    test('uniXXXX / uXXXX biçimleri', () {
      expect(glyphNameToRune('uni011E'), 0x011E);
      expect(glyphNameToRune('u20AC'), 0x20AC);
    });

    test('glif NUMARASI çözülemez (yanlış harf yazmaktansa null)', () {
      expect(glyphNameToRune('g43'), isNull);
      expect(glyphNameToRune('cid221'), isNull);
    });
  });

  group('/Encoding /Differences', () {
    // EBYS tarzı belgelerde görülen tipik font: gömülü TrueType, /ToUnicode
    // yok, harf eşlemesi yalnız /Differences dizisinde.
    const fontDict = '<< /Type /Font /Subtype /TrueType /BaseFont /ABCDEE+Times'
        ' /Encoding 12 0 R >>';
    const encodingDict = '<< /Type /Encoding /BaseEncoding /WinAnsiEncoding'
        ' /Differences [ 208 /Gbreve 221 /Idotaccent /Scedilla 240 /gbreve ] >>';

    test('kodlar dizideki glif adlarından çözülür', () {
      final enc = PdfFontEncoding.fromSimpleFont(fontDict,
          dictOf: (ref) => ref == 12 ? encodingDict : null);
      expect(enc, isNotNull);
      // 221 /Idotaccent — sonraki ad numarasız geldiği için 222 /Scedilla.
      expect(enc!.decode([0xDD, 0xDE, 0xD0, 0xF0]), 'İŞĞğ');
    });

    test('geri yazma simetriktir (aynı font, aynı kodlar)', () {
      final enc = PdfFontEncoding.fromSimpleFont(fontDict,
          dictOf: (ref) => ref == 12 ? encodingDict : null)!;
      expect(enc.encode('İŞĞğ'), [0xDD, 0xDE, 0xD0, 0xF0]);
    });

    test('dizide geçmeyen kodlar temel tablodan (ASCII bozulmaz)', () {
      final enc = PdfFontEncoding.fromSimpleFont(fontDict,
          dictOf: (ref) => ref == 12 ? encodingDict : null)!;
      expect(enc.decode('ANKARA'.codeUnits), 'ANKARA');
    });

    test('Type0 (2 baytlık) ve /Differences olmayan font reddedilir', () {
      expect(
        PdfFontEncoding.fromSimpleFont(
            '<< /Subtype /Type0 /Encoding 12 0 R >>',
            dictOf: (_) => encodingDict),
        isNull,
      );
      expect(
        PdfFontEncoding.fromSimpleFont(
            '<< /Subtype /TrueType /Encoding /WinAnsiEncoding >>',
            dictOf: (_) => null),
        isNull,
      );
    });

    test('Mac tabanlı kodlama reddedilir (o tabloyu taşımıyoruz)', () {
      expect(
        PdfFontEncoding.fromSimpleFont(
          '<< /Subtype /TrueType /Encoding /MacRomanEncoding >>',
          dictOf: (_) => null,
        ),
        isNull,
      );
    });
  });

  group('yedek tablo CP1254', () {
    test('Türkçe harfler doğru okunur (Ý/Ð değil İ/Ğ)', () {
      const fonts = PdfFontAccess();
      expect(fonts.decode(null, [0xDD, 0xD0, 0xDE, 0xFD, 0xF0, 0xFE]),
          'İĞŞığş');
    });

    test('tipografi bölgesi görünmez denetim karakterine düşmez', () {
      const fonts = PdfFontAccess();
      expect(fonts.decode(null, [0x92, 0x93, 0x94, 0x96]), '’“”–');
    });

    test('yazma yönü de Türkçe: İ → 0xDD', () {
      const fonts = PdfFontAccess();
      expect(fonts.encode(null, 'İĞŞığş'),
          [0xDD, 0xD0, 0xDE, 0xFD, 0xF0, 0xFE]);
    });

    test('ASCII iki yönde de bozulmaz', () {
      const fonts = PdfFontAccess();
      expect(fonts.decode(null, 'T.C. ANKARA'.codeUnits), 'T.C. ANKARA');
      expect(fonts.encode(null, 'T.C. ANKARA'), 'T.C. ANKARA'.codeUnits);
    });
  });
}

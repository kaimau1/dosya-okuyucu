import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/core/copy_text.dart';

/// Pano temizligi (2026-08-06 kullanici bulgulari): kopyalanan PDF metninde
/// gorunmez "tofu" karakterleri cikiyordu ve satirlara bolunmus basliklar
/// ("Fizik" + satir sonu + "Muayene") iki satir yapistiriliyordu.
void main() {
  group('cleanPdfCopyText', () {
    test('satir sonu bosluga doner: Fizik+CRLF+Muayene tek satir olur', () {
      expect(cleanPdfCopyText('Fizik\r\nMuayene'), 'Fizik Muayene');
      expect(cleanPdfCopyText('Fizik\nMuayene'), 'Fizik Muayene');
      expect(cleanPdfCopyText('Fizik\rMuayene'), 'Fizik Muayene');
    });

    test('gorunmez karakterler atilir (pdfium U+FFFE dahil)', () {
      expect(cleanPdfCopyText('Fizik\uFFFEMuayene'), 'FizikMuayene');
      expect(cleanPdfCopyText('a\u0007b\u009Dcd'), 'abcd');
      expect(cleanPdfCopyText('a\u200Bb\u00ADc\uFEFFd'), 'abcd');
      expect(cleanPdfCopyText('bozuk\uFFFDglif'), 'bozukglif');
    });

    test('kirilmaz bosluk normal bosluk olur', () {
      expect(cleanPdfCopyText('Fizik\u00A0Muayene'), 'Fizik Muayene');
    });

    test('2+ satir sonu paragraf olarak korunur', () {
      expect(
        cleanPdfCopyText('Birinci paragraf.\r\n\r\nIkinci paragraf.'),
        'Birinci paragraf.\nIkinci paragraf.',
      );
    });

    test('satir sonunda tireyle bolunen kelime birlesir', () {
      expect(cleanPdfCopyText('muaye-\r\nne'), 'muayene');
      // Gercek tireli ad bozulmaz: devam BUYUK harfle basliyor.
      expect(cleanPdfCopyText('Is-\r\nKur'), 'Is- Kur');
    });

    test('bosluk kosulari teke iner, uclar kirpilir', () {
      expect(cleanPdfCopyText('  Bogaz   agrisi\t Ates '), 'Bogaz agrisi Ates');
    });

    test('bos metin bos kalir', () {
      expect(cleanPdfCopyText(''), '');
      expect(cleanPdfCopyText('\r\n\u200B'), '');
    });
  });
}

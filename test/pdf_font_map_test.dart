import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_font_map.dart';
import 'package:dosya_okuyucu/services/pdf_content_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Gerçek belgelerin yazı tipi kodlaması** (`/ToUnicode`).
///
/// Kullanıcının resmî belgesinde (EBYS çıktısı) yerinde düzenleme
/// "metni bulamadım" deyip yedek yola düşüyordu; sonuç bozuk görünüyordu.
/// Sebep: o belgelerdeki fontlar **alt küme gömülü** ve çoğu zaman
/// Type0/Identity-H — yani harf başına 2 baytlık glif numarası. Tek baytlık
/// tahmin tabloları böyle bir belgede hiçbir zaman tutmaz.
///
/// Buradaki belge tam olarak o yapıda elle kuruluyor: Syncfusion böyle bir
/// font üretmediği için başka türlü bu yol hiç denenmezdi.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('CMap ayrıştırma', () {
    List<int> cmap(String body) => latin1.encode(body);

    test('bfchar tek tek eşlemeleri okur', () {
      final enc = PdfFontEncoding.parseCMap(cmap('''
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
2 beginbfchar
<0003> <0041>
<0004> <00DC>
endbfchar
'''));

      expect(enc.codeBytes, 2);
      expect(enc.decode([0x00, 0x03, 0x00, 0x04]), 'AÜ');
      expect(enc.encode('AÜ'), [0x00, 0x03, 0x00, 0x04]);
    });

    test('bfrange ardışık aralığı açar', () {
      final enc = PdfFontEncoding.parseCMap(cmap('''
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
1 beginbfrange
<0010> <0012> <0061>
endbfrange
'''));

      expect(enc.decode([0x00, 0x10, 0x00, 0x11, 0x00, 0x12]), 'abc');
    });

    test('bfrange dizi biçimini de okur', () {
      final enc = PdfFontEncoding.parseCMap(cmap('''
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
1 beginbfrange
<0020> <0022> [<011E> <0130> <015E>]
endbfrange
'''));

      // Ğ İ Ş — Türkçe harfler alt küme fontlarda böyle gelir.
      expect(enc.decode([0x00, 0x20, 0x00, 0x21, 0x00, 0x22]), 'ĞİŞ');
      expect(enc.encode('Ş'), [0x00, 0x22]);
    });

    test('tek baytlık codespace 1 bayt kod verir', () {
      final enc = PdfFontEncoding.parseCMap(cmap('''
1 begincodespacerange
<00> <FF>
endcodespacerange
1 beginbfchar
<41> <011E>
endbfchar
'''));

      expect(enc.codeBytes, 1);
      expect(enc.decode([0x41]), 'Ğ');
    });

    test('fontta olmayan harf reddedilir (null döner)', () {
      final enc = PdfFontEncoding.parseCMap(cmap('''
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
1 beginbfchar
<0003> <0041>
endbfchar
'''));

      expect(enc.encode('A'), isNotNull);
      expect(enc.encode('B'), isNull, reason: 'gömülü olmayan harf yazılmamalı');
    });
  });

  group('Type0/Identity-H belgede yerinde düzenleme', () {
    /// Gerçek bir belgenin alt küme fontunda bulunan harfler: belgede geçen
    /// TÜM harfler (tek bir cümlenin harfleri değil). Yazışma belgelerinde
    /// alfabenin tamamı + rakamlar fiilen bulunur.
    const fontChars = 'abcçdefgğhıijklmnoöprsştuüvyz'
        'ABCÇDEFGĞHIİJKLMNOÖPRSŞTUÜVYZ'
        '0123456789 .,:;/()-';

    /// Metni 2 baytlık glif kodlarıyla yazan, `/ToUnicode` taşıyan PDF.
    /// Kod = harf sırası + 3 (alt küme fontlardaki gibi keyfi numaralar).
    List<int> buildIdentityHPdf(String pageText, {String? subset}) {
      final chars = (subset ?? fontChars).split('').toSet().toList()..sort();
      final codeOf = <String, int>{
        for (var i = 0; i < chars.length; i++) chars[i]: i + 3,
      };

      final bfchar = StringBuffer();
      for (final entry in codeOf.entries) {
        final code = entry.key.codeUnitAt(0).toRadixString(16).padLeft(4, '0');
        bfchar.writeln(
            '<${entry.value.toRadixString(16).padLeft(4, '0')}> <$code>');
      }
      final toUnicode = '''
/CIDInit /ProcSet findresource begin
12 dict begin
begincmap
1 begincodespacerange
<0000> <FFFF>
endcodespacerange
${codeOf.length} beginbfchar
${bfchar.toString().trim()}
endbfchar
endcmap
end
end
''';

      // Sayfa metni: her harf 2 baytlık koduyla, onaltılık dize olarak.
      final hex = StringBuffer();
      for (final ch in pageText.split('')) {
        hex.write(codeOf[ch]!.toRadixString(16).padLeft(4, '0'));
      }
      final content = 'BT /F1 12 Tf 40 500 Td <${hex.toString()}> Tj ET';

      final out = BytesBuilder();
      final offsets = <int, int>{};
      void addObject(int number, String body) {
        offsets[number] = out.length;
        out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
      }

      out.add(latin1.encode('%PDF-1.5\n'));
      addObject(1, '<< /Type /Catalog /Pages 2 0 R >>');
      // Kaynaklar sayfada DEĞİL, üst düğümde: gerçek belgelerde sık görülen
      // miras durumu (izlenmezse font hiç bulunamaz).
      addObject(
          2,
          '<< /Type /Pages /Kids [3 0 R] /Count 1 '
          '/Resources << /Font << /F1 5 0 R >> >> >>');
      addObject(
          3,
          '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] '
          '/Contents 4 0 R >>');
      addObject(4,
          '<< /Length ${content.length} >>\nstream\n$content\nendstream');
      addObject(
          5,
          '<< /Type /Font /Subtype /Type0 /BaseFont /ABCDEF+Times '
          '/Encoding /Identity-H /DescendantFonts [7 0 R] '
          '/ToUnicode 6 0 R >>');
      final cmapCompressed = ZLibEncoder().encode(latin1.encode(toUnicode));
      offsets[6] = out.length;
      out
        ..add(latin1.encode('6 0 obj\n<< /Filter /FlateDecode '
            '/Length ${cmapCompressed.length} >>\nstream\n'))
        ..add(cmapCompressed)
        ..add(latin1.encode('\nendstream\nendobj\n'));
      addObject(
          7,
          '<< /Type /Font /Subtype /CIDFontType2 /BaseFont /ABCDEF+Times '
          '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) '
          '/Supplement 0 >> >>');

      final xrefOffset = out.length;
      final xref = StringBuffer('xref\n0 8\n0000000000 65535 f \n');
      for (var i = 1; i <= 7; i++) {
        xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
      }
      xref
        ..write('trailer\n<< /Size 8 /Root 1 0 R >>\n')
        ..write('startxref\n$xrefOffset\n%%EOF\n');
      out.add(latin1.encode(xref.toString()));
      return out.takeBytes();
    }

    String textOf(List<int> pdf) {
      final doc = PdfDocument(inputBytes: pdf);
      try {
        return PdfTextExtractor(doc).extractText().trim();
      } finally {
        doc.dispose();
      }
    }

    test('test kurulumu doğru: belge okunabiliyor', () {
      final pdf = buildIdentityHPdf('Toplanti 2026');

      expect(textOf(pdf), contains('Toplanti 2026'));
    });

    /// ASIL DÜZELTME: bu belge daha önce "metni bulamadım" deyip yedek yola
    /// düşüyordu (kullanıcının ekran görüntüsündeki bozuk çıktı).
    test('2 baytlık glif kodlu belgede metin yerinde değişir', () async {
      final pdf = buildIdentityHPdf('Toplanti 2026 tarihinde');

      final out = await PdfContentEditor.replaceText(
        pdf,
        pageIndex: 0,
        oldText: '2026',
        newText: '2027',
      );

      expect(textOf(out), contains('2027'));
      expect(textOf(out), isNot(contains('2026')));
    });

    test('Türkçe harfler özgün fontla yazılabiliyor', () async {
      final pdf = buildIdentityHPdf('Sağlık Bakanlığı Genel Müdürlüğü');

      final out = await PdfContentEditor.replaceText(
        pdf,
        pageIndex: 0,
        oldText: 'Genel',
        newText: 'Şube',
      );

      expect(textOf(out), contains('Şube'));
    });

    /// Alt küme font yalnız belgede GEÇEN harfleri taşır. Olmayan bir harfi
    /// yazmak, o harfin yerine boş/yanlış glif basılması demekti.
    test('fontta hiç geçmeyen harf reddedilir', () async {
      // Alt kümesi yalnız "abc" olan bir font: "x" gliflerde yok.
      final pdf = buildIdentityHPdf('abc', subset: 'abc');

      await expectLater(
        PdfContentEditor.replaceText(pdf,
            pageIndex: 0, oldText: 'abc', newText: 'axc'),
        throwsA(isA<PdfEditRefused>()
            .having((e) => e.message, 'mesaj', contains('yazı tipinde yok'))),
      );
    });

    test('özgün baytlar burada da korunur', () async {
      final pdf = buildIdentityHPdf('Rapor 2026');

      final out = await PdfContentEditor.replaceText(pdf,
          pageIndex: 0, oldText: '2026', newText: '2027');

      expect(out.sublist(0, pdf.length), pdf);
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_font_metrics.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Glif genişlik tabloları** — yeniden hizalamanın ölçü aleti.
///
/// Bu tablolar yanlış okunursa satırın kalanı yanlış kadar kayar, yani belge
/// görünürde bozulur. O yüzden her biçim (basit font `/Widths`, CID `/W`'nin
/// iki ayrı yazımı, varsayılanlar) ayrı ayrı ölçülüyor.
void main() {
  String? noResolve(int _) => null;

  group('basit font (/FirstChar + /Widths)', () {
    test('genişlikler koda göre sıralanır', () {
      final m = PdfFontMetrics.parse(
          '<< /Subtype /TrueType /FirstChar 65 /Widths [500 600 700] >>',
          noResolve);

      expect(m, isNotNull);
      expect(m!.widthOf(65), 500);
      expect(m.widthOf(66), 600);
      expect(m.widthOf(67), 700);
    });

    test('tabloda olmayan kod /MissingWidth alır', () {
      final m = PdfFontMetrics.parse(
        '<< /Subtype /TrueType /FirstChar 65 /Widths [500] '
        '/FontDescriptor 5 0 R >>',
        (ref) => ref == 5 ? '<< /MissingWidth 250 >>' : null,
      );

      expect(m!.widthOf(90), 250);
    });

    test('/MissingWidth yoksa varsayılan 0 (PDF kuralı)', () {
      final m = PdfFontMetrics.parse(
          '<< /Subtype /TrueType /FirstChar 65 /Widths [500] >>', noResolve);

      expect(m!.widthOf(90), 0);
    });

    test('/Widths ayrı bir nesnedeyse başvuru izlenir', () {
      final m = PdfFontMetrics.parse(
        '<< /Subtype /TrueType /FirstChar 65 /Widths 9 0 R >>',
        (ref) => ref == 9 ? '[500 600]' : null,
      );

      expect(m!.widthOf(66), 600);
    });

    test('genişlik tablosu olmayan font ÖLÇÜLMEZ (null)', () {
      // Gömülü olmayan standart 14 font böyle gelir. Tahmin etmektense
      // "ölçemiyorum" demek: çağıran o zaman hiç kaydırma yapmıyor.
      final m = PdfFontMetrics.parse(
          '<< /Subtype /Type1 /BaseFont /Helvetica >>', noResolve);

      expect(m, isNull);
    });
  });

  group('Type0/CID font (/W + /DW)', () {
    PdfFontMetrics? build(String w) => PdfFontMetrics.parse(
          '<< /Subtype /Type0 /DescendantFonts [7 0 R] >>',
          (ref) => ref == 7 ? '<< /DW 1000 /W [$w] >>' : null,
        );

    test('c [w1 w2 …] biçimi ardışık kodlara dağıtır', () {
      final m = build('3 [250 333 444]');

      expect(m!.widthOf(3), 250);
      expect(m.widthOf(4), 333);
      expect(m.widthOf(5), 444);
    });

    test('c1 c2 w biçimi aralığın tamamına aynı genişliği verir', () {
      final m = build('10 12 500');

      expect(m!.widthOf(10), 500);
      expect(m.widthOf(11), 500);
      expect(m.widthOf(12), 500);
    });

    test('iki biçim aynı dizide karışık olabilir', () {
      final m = build('3 [250 333] 10 12 500');

      expect(m!.widthOf(4), 333);
      expect(m.widthOf(11), 500);
    });

    test('dizide olmayan kod /DW alır', () {
      final m = build('3 [250]');

      expect(m!.widthOf(999), 1000);
    });

    test('/DW yoksa varsayılan 1000 (PDF kuralı)', () {
      final m = PdfFontMetrics.parse(
        '<< /Subtype /Type0 /DescendantFonts [7 0 R] >>',
        (ref) => ref == 7 ? '<< /W [3 [250]] >>' : null,
      );

      expect(m!.widthOf(999), 1000);
    });
  });

  test('Type3 fontu ölçülmez (glif uzayı 1/1000 değil)', () {
    final m = PdfFontMetrics.parse(
        '<< /Subtype /Type3 /FirstChar 65 /Widths [500] '
        '/FontMatrix [0.01 0 0 0.01 0 0] >>',
        noResolve);

    expect(m, isNull);
  });

  group('widthOfCodes', () {
    test('toplar', () {
      const m = PdfFontMetrics(widths: {1: 100, 2: 250});

      expect(m.widthOfCodes([1, 2, 1]), 450);
    });

    test('ölçülemeyen tek kod bile TÜM ölçümü düşürür', () {
      // Yarım ölçüp "yaklaşık" kaydırmak, satırı gözle görülür biçimde
      // kaydırmak demekti; ölçemiyorsak hiç dokunmuyoruz.
      const m = PdfFontMetrics(widths: {1: 100});

      expect(m.widthOfCodes([1, 7]), isNull);
    });
  });

  test('PdfFile sayfanın font genişliklerini bulur', () {
    // Kaynaklar üst düğümde (miras) — gerçek belgelerde sık.
    final pdf = _buildPdf();
    final file = PdfFile.parse(pdf);
    final metrics = file.fontMetrics(file.pages.first);

    expect(metrics.keys, contains('F1'));
    expect(metrics['F1']!.widthOf(65), 500);
  });

  test('PdfFile sayfanın çizim alanını bulur', () {
    final file = PdfFile.parse(_buildPdf());

    expect(file.mediaBox(file.pages.first), [0, 0, 400, 600]);
  });
}

List<int> _buildPdf() {
  final out = BytesBuilder();
  final offsets = <int, int>{};
  void add(int number, String body) {
    offsets[number] = out.length;
    out.add(latin1.encode('$number 0 obj\n$body\nendobj\n'));
  }

  const content = 'BT /F1 12 Tf 40 500 Td (A) Tj ET';
  out.add(latin1.encode('%PDF-1.4\n'));
  add(1, '<< /Type /Catalog /Pages 2 0 R >>');
  add(
      2,
      '<< /Type /Pages /Kids [3 0 R] /Count 1 '
      '/Resources << /Font << /F1 5 0 R >> >> >>');
  add(
      3,
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 400 600] '
      '/Contents 4 0 R >>');
  add(4, '<< /Length ${content.length} >>\nstream\n$content\nendstream');
  add(
      5,
      '<< /Type /Font /Subtype /TrueType /BaseFont /Arial '
      '/FirstChar 65 /Widths [500 600] >>');

  final xrefOffset = out.length;
  final xref = StringBuffer('xref\n0 6\n0000000000 65535 f \n');
  for (var i = 1; i <= 5; i++) {
    xref.write('${offsets[i]!.toString().padLeft(10, '0')} 00000 n \n');
  }
  xref
    ..write('trailer\n<< /Size 6 /Root 1 0 R >>\n')
    ..write('startxref\n$xrefOffset\n%%EOF\n');
  out.add(latin1.encode(xref.toString()));
  return out.takeBytes();
}

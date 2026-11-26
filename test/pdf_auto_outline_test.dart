import 'package:dosya_okuyucu/services/pdf/pdf_auto_outline.dart';
import 'package:flutter_test/flutter_test.dart';

OutlineLine body(String t, [double pos = 0.5]) => OutlineLine(t, 10, pos);

List<OutlineLine> page(int n, List<OutlineLine> lines) => [
      const OutlineLine('İHYÂ-U ULÛMİDDİN', 9, 0.95), // her sayfada üst bilgi
      ...lines,
      OutlineLine('$n', 9, 0.03), // sayfa no
    ];

void main() {
  test('büyük boy başlık düzey 0, büyük harf alt başlık düzey 1; üst bilgi atılır', () {
    final pages = [
      page(1, [
        const OutlineLine('BİRİNCİ KİTAP', 16, 0.8),
        body('Gövde metni burada uzun uzun devam eder ve okunur.'),
        body('Gövde metni ikinci satır, yine uzun bir cümle.'),
        body('İLMİN FAZİLETİ'),
        body('Gövde metni üçüncü satır ve noktayla biter.'),
      ]),
      page(2, [
        body('Gövde metni sürer, uzun bir satır daha burada.'),
        body('Gövde metni sürer, uzun bir satır daha burada.'),
      ]),
      page(3, [
        const OutlineLine('İKİNCİ KİTAP:', 16, 0.8),
        const OutlineLine('NAMAZIN SIRLARI', 16, 0.76), // iki satıra taşan başlık
        body('Gövde metni sürer, uzun bir satır daha burada.'),
      ]),
    ];
    final items = PdfAutoOutline.pickHeadings(pages);
    expect(items.map((e) => e.toString()).toList(), [
      '0:BİRİNCİ KİTAP@0',
      '1:İLMİN FAZİLETİ@0',
      '0:İKİNCİ KİTAP: NAMAZIN SIRLARI@2',
    ]);
  });

  test('metin katmanı yoksa içindekiler boş', () {
    expect(PdfAutoOutline.pickHeadings([[], []]), isEmpty);
  });

  test('karakter kutularından satır: satır sonu ve dikey sıçrama', () {
    ({double top, double bottom}) r(double top, double h) =>
        (top: top, bottom: top - h);
    final lines = PdfAutoOutline.linesFromChars(
      'AB\nCD',
      [r(700, 20), r(700, 20), r(0, 0), r(600, 10), r(600, 10)],
      800,
    );
    expect(lines.map((l) => l.text).toList(), ['AB', 'CD']);
    expect(lines.first.size, 20);
    expect(lines.first.pos, closeTo(700 / 800, 1e-9));
  });
}

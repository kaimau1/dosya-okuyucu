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

  // B19 (2026-11-27): Türkçe + Arapça alıntılı kitapta gövdeden gelen yanlış
  // başlıklar.
  List<OutlineLine> filler() => [
        for (var i = 0; i < 6; i++)
          body('Gövde metni sürer, uzun bir satır daha burada yazılı duruyor')
      ];

  test('Latin belgede iri Arapça alıntı ve uzun cümle başlık değil', () {
    final pages = [
      page(1, [
        const OutlineLine('NAMAZIN SIRLARI', 16, 0.8),
        ...filler(),
        const OutlineLine('بسم الله الرحمن الرحيم', 14, 0.5),
        const OutlineLine(
            'Bu satır iri dizilmiş ama noktayla biten uzun bir cümledir.',
            14,
            0.4),
      ]),
      page(2, filler()),
    ];
    expect(PdfAutoOutline.pickHeadings(pages).map((e) => e.toString()),
        ['0:NAMAZIN SIRLARI@0']);
  });

  test('art arda 4 iri satır alıntı bloğudur, başlık sayılmaz', () {
    final pages = [
      page(1, [
        const OutlineLine('ORUCUN FAZİLETİ', 16, 0.8),
        ...filler(),
        for (var i = 0; i < 4; i++)
          OutlineLine('İri dizilmiş alıntı satırı $i', 13, 0.5 - i * 0.03),
      ]),
      page(2, filler()),
    ];
    expect(PdfAutoOutline.pickHeadings(pages).map((e) => e.toString()),
        ['0:ORUCUN FAZİLETİ@0']);
  });

  test('gövde boyundaki bölüm kalıbı düzey 0 ve altındaki adla birleşir', () {
    final pages = [
      page(1, [
        body('BİRİNCİ BÖLÜM', 0.85),
        const OutlineLine('Abdestin Farzları', 14, 0.8),
        ...filler(),
        body('ALT KONU BAŞLIĞI'),
        ...filler(),
      ]),
      page(2, filler()),
    ];
    expect(PdfAutoOutline.pickHeadings(pages).map((e) => e.toString()), [
      '0:BİRİNCİ BÖLÜM Abdestin Farzları@0',
      '1:ALT KONU BAŞLIĞI@0',
    ]);
  });

  test('bölüm kalıbı tanıma', () {
    for (final t in [
      'BÖLÜM 3',
      'Birinci Kısım',
      '2. BAB',
      'Fasıl: Namaz',
      'İKİNCİ KİTAP:',
      'الفصل الأول',
      'Chapter 7'
    ]) {
      expect(PdfAutoOutline.isChapterLine(t), isTrue, reason: t);
    }
    for (final t in ['Bölümlerin sayısı', 'Babası geldi', 'Partiler']) {
      expect(PdfAutoOutline.isChapterLine(t), isFalse, reason: t);
    }
    expect(PdfAutoOutline.bodyLike('Kısa başlık'), isFalse);
    expect(
        PdfAutoOutline.bodyLike(
            'Bu cümle gövdeden gelir ve noktayla biter, başlık olamaz.'),
        isTrue);
  });
}

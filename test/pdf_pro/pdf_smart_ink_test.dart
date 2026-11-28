import 'dart:math' as math;

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_smart_ink.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  PdfTextBlock sampleBlock() {
    final l1 = PdfTextLine([
      const PdfTextObjectInfo(
        index: 0,
        text: 'Merhaba dünya örnek',
        left: 100,
        bottom: 497,
        right: 290,
        top: 511,
        tfSize: 12,
        fontName: 'Helvetica',
        matrix: [1, 0, 0, 1, 100, 500],
        renderMode: 0,
      ),
    ]);
    final l2 = PdfTextLine([
      const PdfTextObjectInfo(
        index: 1,
        text: 'ikinci satır metni',
        left: 100,
        bottom: 477,
        right: 280,
        top: 491,
        tfSize: 12,
        fontName: 'Helvetica',
        matrix: [1, 0, 0, 1, 100, 480],
        renderMode: 0,
      ),
    ]);
    return PdfTextBlock([l1, l2]);
  }

  test('fosforluyla yatay çizim metni keskin vurgulaya çevirir', () {
    final res = analyzeSmartInk(
      points: const [
        (x: 110, y: 505),
        (x: 160, y: 506),
        (x: 210, y: 504),
      ],
      blocks: [sampleBlock()],
      isHighlighter: true,
    );
    expect(res, isA<SmartInkTextMarkup>());
    final m = res! as SmartInkTextMarkup;
    expect(m.type, PdfAnnotType.highlight);
    expect(m.quads, isNotEmpty);
  });

  test('kalemle satır tabanı altında yatay çizim alt çizgiye çevirir', () {
    final res = analyzeSmartInk(
      points: const [
        (x: 105, y: 496),
        (x: 150, y: 495),
        (x: 195, y: 496),
      ],
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkTextMarkup>());
    expect((res! as SmartInkTextMarkup).type, PdfAnnotType.underline);
  });

  test('kalemle satır ortasından yatay çizim üzerini çizmeye çevirir', () {
    final res = analyzeSmartInk(
      points: const [
        (x: 105, y: 506),
        (x: 150, y: 506),
        (x: 195, y: 506),
      ],
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkTextMarkup>());
    expect((res! as SmartInkTextMarkup).type, PdfAnnotType.strikeout);
  });

  test('paragraf çevresine çizilen kapalı daire metni ve dörtgenleri seçer', () {
    final pts = <({double x, double y})>[];
    for (var i = 0; i <= 24; i++) {
      final a = 2 * math.pi * i / 24;
      pts.add((x: 190 + 115 * math.cos(a), y: 494 + 30 * math.sin(a)));
    }
    final res = analyzeSmartInk(
      points: pts,
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkCircleText>());
    final sel = res! as SmartInkCircleText;
    expect(sel.text, contains('Merhaba'));
    expect(sel.quads, isNotEmpty);
  });

  test('metinsiz alanda daire temiz elipse dönüşür', () {
    final pts = <({double x, double y})>[];
    for (var i = 0; i <= 24; i++) {
      final a = 2 * math.pi * i / 24;
      pts.add((x: 300 + 40 * math.cos(a), y: 200 + 30 * math.sin(a)));
    }
    final res = analyzeSmartInk(
      points: pts,
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkCleanEllipse>());
  });

  test('iki satır arasındaki kalem çizgisi yalnız EN YAKIN satırı işaretler',
      () {
    // Üst satırın tabanının ~0,9 punto altı: alt satırın harf uçlarına
    // değiyor ama üst satırın alt çizgisi (eskiden iki satır birden).
    final res = analyzeSmartInk(
      points: const [
        (x: 105, y: 489),
        (x: 150, y: 489.5),
        (x: 195, y: 489),
      ],
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkTextMarkup>());
    final m = res! as SmartInkTextMarkup;
    expect(m.type, PdfAnnotType.underline);
    // Tek satır: dörtgenlerin hepsi üst satırın bandında (taban 500).
    for (final q in m.quads) {
      expect(q[1], greaterThan(492));
    }
  });

  test('fosforlu satırın biraz altına kaysa da o satırı vurgular', () {
    final res = analyzeSmartInk(
      points: const [
        (x: 110, y: 495),
        (x: 160, y: 494.5),
        (x: 210, y: 495),
      ],
      blocks: [sampleBlock()],
      isHighlighter: true,
    );
    expect(res, isA<SmartInkTextMarkup>());
    final m = res! as SmartInkTextMarkup;
    expect(m.type, PdfAnnotType.highlight);
    for (final q in m.quads) {
      expect(q[1], greaterThan(492));
    }
  });

  test('kalemle dalgalı alt çizgi dalgalı çizgiye (squiggly) çevrilir', () {
    final pts = <({double x, double y})>[
      for (var i = 0; i <= 16; i++)
        (x: 105.0 + i * 6, y: 495.5 + (i.isEven ? 2.2 : -2.2)),
    ];
    final res = analyzeSmartInk(
      points: pts,
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isA<SmartInkTextMarkup>());
    expect((res! as SmartInkTextMarkup).type, PdfAnnotType.squiggly);
  });

  test('dağınık zikzak çizim serbest mürekkep olarak kalır', () {
    final res = analyzeSmartInk(
      points: const [
        (x: 200, y: 200),
        (x: 230, y: 260),
        (x: 260, y: 180),
        (x: 290, y: 270),
        (x: 310, y: 190),
      ],
      blocks: [sampleBlock()],
      isHighlighter: false,
    );
    expect(res, isNull);
  });
}

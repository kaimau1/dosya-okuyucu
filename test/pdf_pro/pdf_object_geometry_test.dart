// PDF Pro Faz 59 m.4–5: tutunma, hizala/dağıt, kement — saf geometri.
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_object_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const page = Size(600, 800);

  group('tutunma', () {
    test('sayfa ortasına yapışır, kılavuz ortada', () {
      final t = PdfSnapTargets(page, const [], margin: 72);
      // 100 genişlik, ortası 297'ye geliyor → 300'e yapışır.
      final s = t.snap(const Rect.fromLTWH(0, 300, 100, 50), const Offset(247, 0));
      expect(s.offset.dx, 250);
      expect(s.xs, [300]);
      expect(s.offset.dy, 0, reason: 'y ekseninde hedef yok (yakın değil)');
      expect(s.ys, isEmpty);
    });

    test('kenar boşluğuna ve öteki nesnenin kenarına yapışır', () {
      final t = PdfSnapTargets(page, const [Rect.fromLTWH(300, 100, 80, 40)],
          margin: 72);
      // Sol kenar 70 → kenar boşluğu 72.
      var s = t.snap(const Rect.fromLTWH(60, 500, 50, 50), const Offset(10, 0));
      expect(s.offset.dx, 12);
      expect(s.xs, [72]);
      // Üst kenar 103 → ötekinin üstü 100.
      s = t.snap(const Rect.fromLTWH(450, 90, 50, 50), const Offset(0, 13));
      expect(s.offset.dy, 10);
      expect(s.ys, contains(100));
    });

    test('eşikten uzaksa dokunulmaz', () {
      final t = PdfSnapTargets(page, const [], margin: 72);
      final s = t.snap(const Rect.fromLTWH(150, 150, 20, 20), const Offset(5, 5));
      expect(s.offset, const Offset(5, 5));
      expect(s.xs, isEmpty);
      expect(s.ys, isEmpty);
    });
  });

  group('hizala / dağıt', () {
    const spans = [(10.0, 30.0), (50.0, 60.0), (100.0, 140.0)];

    test('başa, sona, ortaya', () {
      expect(pdfAlignAxis(spans, PdfAxisAlign.start), [0, -40, -90]);
      expect(pdfAlignAxis(spans, PdfAxisAlign.end), [110, 80, 0]);
      expect(pdfAlignAxis(spans, PdfAxisAlign.center), [55, 20, -45]);
    });

    test('dağıt: uçlar yerinde, boşluklar eşit', () {
      // Toplam 130, genişlikler 20+10+40=70 → boşluk 30.
      final d = pdfAlignAxis(spans, PdfAxisAlign.distribute);
      expect(d[0], 0);
      expect(d[2], 0);
      expect(spans[1].$1 + d[1], 60, reason: '30 + 30');
    });

    test('tek nesne / iki nesnede dağıt etkisiz', () {
      expect(pdfAlignAxis(const [(1.0, 2.0)], PdfAxisAlign.start), [0]);
      expect(pdfAlignAxis(spans.sublist(0, 2), PdfAxisAlign.distribute), [0, 0]);
    });
  });

  test('kement: merkezi içeride kalanlar', () {
    const rects = [
      Rect.fromLTWH(10, 10, 20, 20),
      Rect.fromLTWH(90, 90, 40, 40), // merkez 110,110 — dışarıda
      Rect.fromLTWH(50, 50, 10, 10),
    ];
    expect(pdfInLasso(rects, const Rect.fromLTWH(0, 0, 100, 100)), [0, 2]);
  });
}

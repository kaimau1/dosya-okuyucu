@Tags(['perf'])
library;

import 'dart:ui' show Offset, Rect;

import 'package:dosya_okuyucu/core/device_profile.dart';
import 'package:dosya_okuyucu/screens/pdf_compare_screen.dart';
import 'package:dosya_okuyucu/services/pdf_compare.dart';
import 'package:dosya_okuyucu/services/pdf_doc_pro.dart';
import 'package:dosya_okuyucu/services/pdf_export_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 perf kapısı (anayasa k.8a, k.10): 500 sayfalık PDF'te toplu
/// işlemler TEK geçiş ve bütçe içinde; bellek tavanları sabitlerle kilitli
/// (görüntüye çizen işler parça parça, karşılaştırma tavanlı). Eşikler
/// debug/JIT için gevşek (×3).
late List<int> _big;

Future<List<int>> _doc(int pages) async {
  final doc = PdfDocument();
  final f = PdfStandardFont(PdfFontFamily.helvetica, 11);
  for (var i = 0; i < pages; i++) {
    final g = doc.pages.add().graphics;
    for (var l = 0; l < 6; l++) {
      g.drawString('Sayfa ${i + 1} satir $l  Tutar ${i * 10 + l}', f,
          bounds: Rect.fromLTWH(40, 60.0 + l * 22, 420, 16));
    }
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

void main() {
  setUpAll(() async {
    _big = await _doc(500);
  });

  test('500 sayfa: Bates numarası tek geçiş ≤ 9 sn', () async {
    final sw = Stopwatch()..start();
    final out = await PdfDocPro.addNumbering(_big,
        style: PageNumberStyle.bates, prefix: 'EK');
    sw.stop();
    // ignore: avoid_print
    print('PERF pdf_bates_500_ms=${sw.elapsedMilliseconds}');
    expect(out.length, greaterThan(_big.length));
    expect(sw.elapsedMilliseconds, lessThan(9000));
  });

  test('500 sayfa: her sayfaya paraf ≤ 9 sn', () async {
    final sw = Stopwatch()..start();
    await PdfDocPro.initialPages(_big,
        strokes: const [
          [Offset(0, 0), Offset(0.5, 1), Offset(1, 0)],
        ],
        aspect: 2);
    sw.stop();
    // ignore: avoid_print
    print('PERF pdf_initial_500_ms=${sw.elapsedMilliseconds}');
    expect(sw.elapsedMilliseconds, lessThan(9000));
  });

  test('500 sayfa: metin satırları (tablo/Word dışa aktarım) ≤ 30 sn', () {
    final sw = Stopwatch()..start();
    final rows = PdfExportPro.rows(_big);
    sw.stop();
    // ignore: avoid_print
    print('PERF pdf_rows_500_ms=${sw.elapsedMilliseconds}');
    expect(rows, hasLength(500));
    expect(sw.elapsedMilliseconds, lessThan(30000));
  });

  test('metin karşılaştırma: 1500×1500 satır LCS ≤ 3 sn', () {
    final a = [for (var i = 0; i < 1500; i++) 'satir $i ${i % 7}'];
    final b = [...a]..[700] = 'degisti';
    final sw = Stopwatch()..start();
    final d = PdfCompare.diffLines(a, b);
    sw.stop();
    // ignore: avoid_print
    print('PERF pdf_diff_1500_ms=${sw.elapsedMilliseconds}');
    expect(d.where((l) => l.any((p) => p.kind != DiffKind.same)), hasLength(1));
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('bellek tavanları: çizim bütçesi ≤ 2480 px, görsel fark ≤ 50 sayfa', () {
    for (final tier in DeviceTier.values) {
      final b = PerfBudget(tier);
      expect(b.pdfRasterMaxPx, lessThanOrEqualTo(2480));
      expect(b.pdfCompareWidthPx, lessThanOrEqualTo(1200));
    }
    expect(const PerfBudget(DeviceTier.low).pdfRasterMaxPx,
        lessThan(const PerfBudget(DeviceTier.high).pdfRasterMaxPx));
    expect(PdfCompareScreen.visualPageLimit, lessThanOrEqualTo(50));
  });
}

// PDF Pro tezgâhı (Faz 51): şimdiki Dart paragraf motorunu külliyatta ölçer
// ve tabanın ALTINA düşmeyi engeller. Rapor: docs/perf/2026-11-pdfpro-51-taban.md
// Taban: test/pdf_pro/baseline.json (bilerek iyileşince güncellenir).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_page_context.dart';
import 'package:dosya_okuyucu/services/pdf_page_edit.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../tool/pdf_pro_bench.dart';

/// Şimdiki motor (`PdfPageEdit`): editörün yaptığının aynısı — sahip
/// parolalı belgede kilit açılır, paragraf `replaceParagraph` ile yazılır.
class CurrentEngine extends BenchEngine {
  @override
  String get name => 'dart-paragraf';

  @override
  Future<Uint8List> prepare(Uint8List pdf) async {
    try {
      PdfPageContext.open(pdf, 0);
      return pdf;
    } on PdfPageRefused catch (e) {
      if (!e.encrypted) return pdf;
      return Uint8List.fromList(
          await PdfTools.removePassword(pdf, currentPassword: ''));
    }
  }

  @override
  Future<List<BenchBlock>> blocks(Uint8List pdf, int page) async => [
        for (final p in PdfPageEdit.outline(pdf, page).paragraphs)
          BenchBlock(p.text, p.left, p.bottom, p.right, p.top),
      ];

  @override
  Future<BenchEditResult> edit(
      Uint8List pdf, int page, int block, String newText) async {
    List<int> out;
    try {
      out = PdfPageEdit.replaceParagraph(pdf,
          pageIndex: page, paragraphIndex: block, newText: newText);
    } on PdfParagraphRefused catch (e) {
      throw BenchRefused(e.message, glyph: e.message.contains('yazı tipinde yok'));
    } on PdfPageRefused catch (e) {
      throw BenchRefused(e.message);
    }
    // .notdef: motor Unicode → kod eşlemesini fontun ToUnicode/kodlamasından
    // kuruyor; alt küme fontta glifin VARLIĞINI bilmiyor → ölçülemez (null).
    // (TtfCoverage alt kümenin özel cmap'iyle yanlış "eksik" diyordu.)
    // Glif bazlı yedek yok: eksik glifte reddeder → fallbackChars 0.
    return BenchEditResult(Uint8List.fromList(out), fallbackChars: 0);
  }
}

void main() {
  test('PDF Pro tezgâhı — şimdiki motor (taban)', () async {
    await pdfrxInitialize();
    final corpus = loadCorpus();
    expect(corpus.where((c) => !c.local).length, greaterThanOrEqualTo(60),
        reason: 'külliyat ≥ 60 PDF');

    final sw = Stopwatch()..start();
    final report = await runBench(CurrentEngine(), corpus);
    final out = File('build/pdf_pro_bench/dart-paragraf.json')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report.toJson()));
    // ignore: avoid_print
    print(formatSummary(report));
    // ignore: avoid_print
    print('PDFPRO_BENCH_SECONDS ${sw.elapsed.inSeconds} → ${out.path}');

    // Taban bekçisi: sayılar deterministik; bilerek iyileşince baseline.json
    // güncellenir, kötüleşme kırmızı.
    final base = jsonDecode(File('test/pdf_pro/baseline.json').readAsStringSync())
        as Map<String, dynamic>;
    final s = report.summary();
    expect(s['pageErrors'], lessThanOrEqualTo(base['pageErrors'] as int));
    expect(s['coveragePct'] as double,
        greaterThanOrEqualTo((base['coveragePct'] as num) - 0.5));
    for (final k in ['same', 'turkish']) {
      final cur = s[k] as Map<String, Object?>;
      final b = base[k] as Map<String, dynamic>;
      expect(cur['successPct'] as double,
          greaterThanOrEqualTo((b['successPct'] as num) - 0.5),
          reason: '$k başarı oranı tabanın altında');
      expect(cur['pixelDirty'] as int, lessThanOrEqualTo(b['pixelDirty'] as int),
          reason: '$k: değişmeyen bölgede piksel farkı arttı');
    }
  }, timeout: const Timeout(Duration(minutes: 20)));
}

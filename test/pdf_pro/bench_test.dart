// PDF Pro tezgâhı (Faz 51–52): iki motor külliyatta yan yana (karar kapısı
// PK1 / PK1-B) ve her biri kendi tabanının ALTINA düşemez.
// Raporlar: docs/perf/2026-11-pdfpro-51-taban.md, 2026-11-pdfpro-52-motor.md
// Tabanlar: test/pdf_pro/baseline.json (dart-paragraf), baseline_pdfium.json.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../tool/pdf_pro_bench.dart';
import 'bench_engines.dart';

Future<BenchReport> _runAndGuard(BenchEngine engine, String baseline) async {
  await pdfrxInitialize();
  final corpus = loadCorpus();
  expect(corpus.where((c) => !c.local).length, greaterThanOrEqualTo(60),
      reason: 'külliyat ≥ 60 PDF');
  final sw = Stopwatch()..start();
  final report = await runBench(engine, corpus);
  final out = File('build/pdf_pro_bench/${engine.name}.json')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent(' ').convert(report.toJson()));
  // ignore: avoid_print
  print(formatSummary(report));
  // ignore: avoid_print
  print('PDFPRO_BENCH_SECONDS ${engine.name} ${sw.elapsed.inSeconds} → ${out.path}');

  // Taban bekçisi: sayılar deterministik; bilerek iyileşince taban dosyası
  // güncellenir, kötüleşme kırmızı.
  final base =
      jsonDecode(File(baseline).readAsStringSync()) as Map<String, dynamic>;
  final s = report.summary();
  expect(s['pageErrors'], lessThanOrEqualTo(base['pageErrors'] as int));
  expect(s['coveragePct'] as double,
      greaterThanOrEqualTo((base['coveragePct'] as num) - 0.5));
  for (final k in ['same', 'turkish']) {
    final cur = s[k] as Map<String, Object?>;
    final b = base[k] as Map<String, dynamic>;
    expect(cur['successPct'] as double,
        greaterThanOrEqualTo((b['successPct'] as num) - 0.5),
        reason: '${engine.name} $k başarı oranı tabanın altında');
    expect(cur['pixelDirty'] as int, lessThanOrEqualTo(b['pixelDirty'] as int),
        reason: '${engine.name} $k: değişmeyen bölgede piksel farkı arttı');
  }
  return report;
}

void main() {
  test('PDF Pro tezgâhı — şimdiki motor (taban)',
      () => _runAndGuard(CurrentEngine(), 'test/pdf_pro/baseline.json'),
      timeout: const Timeout(Duration(minutes: 20)));

  test('PDF Pro tezgâhı — PDFium nesne motoru (Faz 52 karar kapısı)',
      () => _runAndGuard(PdfiumEngine(), 'test/pdf_pro/baseline_pdfium.json'),
      timeout: const Timeout(Duration(minutes: 20)));
}

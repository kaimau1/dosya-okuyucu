// PDF Pro Faz 54 / 6 — oturum ölçümü (PK8): uygula → piksel, geri al → piksel,
// 50 sayfalık belgede artımlı kayıt, oturumun ek belleği.
//
// CI'da (Linux, debug JIT) koşar ve `PDFPRO54_*` satırlarını basar; bunlar
// CİHAZ sayısı değildir (cihaz ölçümü `docs/CIHAZ_TESTI.md` "PDF Pro Faz 54").
// Eşikler bilerek gevşek: gerileme bekçisi, bütçe kanıtı değil.
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_save.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

const _corpus = 'test/fixtures/pdf_corpus';

/// Külliyatta düzenlemesi bilinen aileler (bir sayfada birkaç paragraf).
const _files = [
  'rl_paragraflar.pdf',
  'wd_paragraflar.pdf',
  'ch_paragraflar.pdf',
  'fp_paragraflar.pdf',
  'sf_paragraflar.pdf',
  'dp_paragraflar.pdf',
  'wd_mektup_logo.pdf',
  'rl_iki_sutun.pdf',
];

double _p(List<double> xs, double q) {
  if (xs.isEmpty) return double.nan;
  final s = [...xs]..sort();
  return s[((s.length - 1) * q).round()];
}

String _ms(double v) => v.isNaN ? 'bekliyor' : v.toStringAsFixed(1);

/// Aynı harflerle ilk ↔ son sözcük (fontta eksik glif olmaz).
String? _swap(String text) {
  final w = text.split(' ');
  if (w.length < 3 || w.first == w.last) return null;
  return [w.last, ...w.sublist(1, w.length - 1), w.first].join(' ');
}

Future<void> _render(PdfDocument doc, int page) async {
  final pg = doc.pages[page];
  // 144 dpi — tezgâhla aynı cetvel.
  final img = await pg.render(
      fullWidth: pg.width * 2, fullHeight: pg.height * 2);
  img?.dispose();
}

/// Sayfada uygulanabilen ilk takas; uygulandıysa true.
Future<bool> _applyOne(PdfEditSession s, PdfDocument doc, int page,
    {int skip = 0}) async {
  final blocks = await PdfEditBridge.blocks(doc, page);
  var seen = 0;
  for (final b in blocks) {
    final next = _swap(b.text);
    if (next == null) continue;
    if (seen++ < skip) continue;
    try {
      await s.apply(PdfReplaceBlockOp.of(page, b, next),
          label: 'pse.step_paragraph');
      return true;
    } on PdfEditBridgeRefused {
      continue;
    }
  }
  return false;
}

void main() {
  setUpAll(() async => pdfrxInitialize());

  test('uygula → piksel ve geri al → piksel (külliyat)', () async {
    final apply = <double>[], undo = <double>[];
    final rss0 = ProcessInfo.currentRss;
    var peak = rss0;
    for (final name in _files) {
      final file = File('$_corpus/$name');
      if (!file.existsSync()) continue;
      final doc = await PdfDocument.openData(file.readAsBytesSync());
      final s = PdfEditSession.forDocument(doc);
      try {
        await _render(doc, 0); // fontlar ve sayfa önbelleği ısınsın
        for (var i = 0; i < 4; i++) {
          final sw = Stopwatch()..start();
          if (!await _applyOne(s, doc, 0, skip: i)) break;
          await _render(doc, 0);
          apply.add(sw.elapsedMicroseconds / 1000);
          if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
        }
        while (s.canUndo) {
          final sw = Stopwatch()..start();
          expect(await s.undo(), isTrue);
          await _render(doc, 0);
          undo.add(sw.elapsedMicroseconds / 1000);
        }
        if (ProcessInfo.currentRss > peak) peak = ProcessInfo.currentRss;
      } finally {
        await s.close();
        await doc.dispose();
      }
    }
    print('PDFPRO54_apply n=${apply.length} p50=${_ms(_p(apply, 0.5))} '
        'p95=${_ms(_p(apply, 0.95))} ms (uygula → 144 dpi piksel)');
    print('PDFPRO54_undo n=${undo.length} p50=${_ms(_p(undo, 0.5))} '
        'p95=${_ms(_p(undo, 0.95))} ms (geri al → 144 dpi piksel)');
    print('PDFPRO54_memory tepe=+'
        '${((peak - rss0) / (1024 * 1024)).toStringAsFixed(1)} MB '
        '(koşu boyunca RSS; ${_files.length} belge art arda)');
    expect(apply.length, greaterThanOrEqualTo(8),
        reason: 'ölçülecek yeterli düzenleme uygulanamadı');
    expect(undo.length, apply.length);
    // Gerileme bekçisi (CI debug JIT; cihaz bütçesi §6 ayrı ölçülür).
    expect(_p(apply, 0.95), lessThan(3000));
    expect(_p(undo, 0.95), lessThan(3000));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('50 sayfalık belgede artımlı kayıt', () async {
    final tmp = Directory.systemTemp.createTempSync('pdf_pro_bench54');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    addTearDown(() {
      PdfVersionHistory.rootOverride = null;
      tmp.deleteSync(recursive: true);
    });
    final one = File('$_corpus/rl_cok_sayfa.pdf').readAsBytesSync();
    final merged = Uint8List.fromList(
        await PdfTools.merge([for (var i = 0; i < 17; i++) one]));
    final path = p.join(tmp.path, 'elli.pdf');
    File(path).writeAsBytesSync(merged);

    final doc = await PdfDocument.openFile(path);
    final s = PdfEditSession.forDocument(doc);
    final saver = PdfEditSaver(session: s, path: path, tempDir: tmp.path);
    addTearDown(() async {
      await s.close();
      await saver.dispose();
      await doc.dispose();
    });
    final pages = doc.pages.length;
    expect(pages, greaterThanOrEqualTo(50));

    // Üç ayrı sayfada birer düzenleme (baş, orta, son).
    var edits = 0;
    for (final page in [0, pages ~/ 2, pages - 1]) {
      if (await _applyOne(s, doc, page)) edits++;
    }
    if (edits == 0) {
      print('PDFPRO54_save50 bekliyor (birleştirilmiş belgede düzenleme '
          'uygulanamadı)');
      return;
    }
    final times = <double>[];
    PdfEditSaveResult? last;
    for (var i = 0; i < 3; i++) {
      final sw = Stopwatch()..start();
      last = await saver.save();
      times.add(sw.elapsedMicroseconds / 1000);
      expect(last.overwritten, isTrue);
      // Yeniden kirlet: sıradaki tur da gerçek kayıt olsun.
      if (i < 2 && !await _applyOne(s, doc, 0, skip: i + 1)) break;
    }
    final written = File(path).readAsBytesSync();
    expect(written.sublist(0, merged.length), merged);
    final re = await PdfDocument.openData(written);
    addTearDown(re.dispose);
    expect(re.pages.length, pages);
    print('PDFPRO54_save50 sayfa=$pages boyut=${merged.length} '
        'duzenleme=$edits n=${times.length} '
        'p50=${_ms(_p(times, 0.5))} max=${_ms(_p(times, 1))} ms '
        'ek=${last!.growth} bayt (kodla + kırp + sürüm kopyası + yaz)');
    expect(_p(times, 1), lessThan(10000));
  }, timeout: const Timeout(Duration(minutes: 5)));
}

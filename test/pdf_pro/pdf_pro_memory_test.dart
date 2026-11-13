// PDF Pro oturum belleği (§6 bütçesi +40 MB): ucuz, test edilebilir ölçüler —
// gerçek PDFium (CI: PDFIUM_PATH).
//
// Bulgu (2026-11-13): 3 paragraf düzenlemesinde geri al yığını ve canlı
// belgede KALAN bellek düzenleme başına ~10 KB; yük tuş başına geçici işte
// (bkz. HAFIZA "oturum belleği").
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfium_dart/pdfium_dart.dart' as pb;
import 'package:pdfrx/pdfrx.dart';

const _corpus = 'test/fixtures/pdf_corpus';

/// İşçi izolatında: bir yazım, kurulan ölçüm anahtarı sayısı.
int _keysPerTypeset(pb.PDFium p, int docAddr, PdfTypesetRequest m) {
  final k0 = debugFontKeyBuilds;
  debugTypeset(p, docAddr, m);
  return debugFontKeyBuilds - k0;
}

void main() {
  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  test('tuş başına ölçüm anahtarı karakter başına değil, font başına kurulur',
      () async {
    final doc = await PdfDocument.openFile('$_corpus/rl_paragraflar.pdf');
    addTearDown(doc.dispose);
    final content = await PdfEditBridge.content(doc, 0);
    final block = PdfEditBridge.blocksOf(content)
        .firstWhere((b) => b.lines.length >= 2);
    final req = PdfBlockRequest.of(0, block,
            text: 'Merhaba ${block.text}', content: content)
        .copyWith(dryRun: true);
    final keys = await doc.computeOnIdleDocument(_keysPerTypeset, req);
    // KÖK NEDEN: anahtar (dizgi + font adı FFI okuması) her karakterde
    // kuruluyordu → paragraf uzunluğu kadar.
    expect(keys, lessThanOrEqualTo(8),
        reason: '${req.text.length} karakter, $keys anahtar');
  });

  test('3 paragraf düzenlemesi: canlı belgede kalan artık sınırlı', () async {
    final tmp = Directory.systemTemp.createTempSync('pdf_pro_mem_test');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    PdfEditRecovery.rootOverride = p.join(tmp.path, 'kurtarma');
    addTearDown(() {
      PdfVersionHistory.rootOverride = null;
      PdfEditRecovery.rootOverride = null;
      tmp.deleteSync(recursive: true);
    });
    final path = p.join(tmp.path, 'rl_paragraflar.pdf');
    File(path).writeAsBytesSync(
        File('$_corpus/rl_paragraflar.pdf').readAsBytesSync());
    final doc = await PdfDocument.openFile(path);
    final c = PdfProEditController(
        document: doc, path: path, snapshotEvery: const Duration(hours: 1));
    addTearDown(() async {
      await c.close();
      await doc.dispose();
    });
    // Kırpılmamış artımlı çıktı = bellekteki her nesne (bkz. HAFIZA).
    Future<int> held() async =>
        (await doc.encodePdf(incremental: true)).length;
    final start = await held();
    for (var e = 0; e < 3; e++) {
      while (c.blocksOf(0) == null) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      final list = c.blocksOf(0)!.where((b) => b.lines.length >= 2).toList();
      expect(await c.beginEdit(0, list[e % list.length], offset: 0), isTrue);
      var t = c.live!.text;
      for (final ch in 'Merhaba '.split('')) {
        t = ch + t;
        c.liveInput(t, 1, 1);
      }
      for (var i = 0;
          i < 300 && !(c.live!.applied || c.live!.error != null);
          i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await c.commitEdit(label: 'pse.step_paragraph'), isTrue);
    }
    final grown = await held() - start;
    expect(grown, lessThan(3 * 64 * 1024), reason: '$grown bayt');
  });
}

// PDF Pro Faz 66 / 2–3: bozuk belgelerle köprü + çözümleyici (çökme 0) ve
// uzun oturum (çok düzenleme + geri al/yinele: gecikme sabit). Tam takımda
// ve test/fuzz/ değişince koşar. Gerçek PDFium (CI: PDFIUM_PATH).
@Tags(['fuzz'])
library;

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_session.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

void main() {
  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  test('bozulmuş PDF: aç → çözümle → düzenle → kaydet hiçbir adımda çökmez',
      () async {
    final rnd = Random(20261113);
    const files = [
      'rl_paragraflar.pdf',
      'wd_paragraflar.pdf',
      'ch_objstm.pdf',
      'rl_artimli.pdf',
      'rl_sifreli.pdf',
      'mu_form.pdf',
      'fp_karma_logo.pdf',
    ];
    var opened = 0, edited = 0, total = 0;
    for (final name in files) {
      final src = File('test/fixtures/pdf_corpus/$name').readAsBytesSync();
      for (var round = 0; round < 12; round++) {
        total++;
        final bytes = Uint8List.fromList(src);
        // Kip: bayt çevir · blok sıfırla · kırp · araya çöp.
        switch (round % 4) {
          case 0:
            for (var k = 0; k < 40; k++) {
              bytes[rnd.nextInt(bytes.length)] = rnd.nextInt(256);
            }
          case 1:
            final at = rnd.nextInt(bytes.length - 600);
            bytes.fillRange(at, at + 512, 0);
          case 2:
            break;
          case 3:
            final at = rnd.nextInt(bytes.length - 200);
            for (var k = 0; k < 120; k++) {
              bytes[at + k] = 0x41 + rnd.nextInt(26);
            }
        }
        final data = round % 4 == 2
            ? bytes.sublist(0, bytes.length - rnd.nextInt(bytes.length ~/ 3))
            : bytes;
        PdfDocument? doc;
        try {
          doc = await PdfDocument.openData(data)
              .timeout(const Duration(seconds: 20));
        } catch (_) {
          continue; // açılmayan belge sorun değil; çökme olmasın yeter
        }
        opened++;
        try {
          for (var p = 0; p < doc.pages.length && p < 2; p++) {
            final content = await PdfEditBridge.content(doc, p)
                .timeout(const Duration(seconds: 20));
            final blocks = PdfEditBridge.blocksOf(content);
            await PdfEditBridge.annotations(doc, p);
            for (final b in blocks.take(2)) {
              b.map.offsetAt(b.left, b.top);
              if (!b.editable) continue;
              try {
                await PdfEditBridge.replaceBlock(
                        doc, p, b, 'Işığı ${b.text}',
                        content: content)
                    .timeout(const Duration(seconds: 20));
                edited++;
              } on PdfEditBridgeRefused {
                // Açık ret: kabul.
              }
              break;
            }
          }
          await PdfEditBridge.saveIncremental(doc)
              .timeout(const Duration(seconds: 20));
        } finally {
          await doc.dispose();
        }
      }
    }
    // ignore: avoid_print
    print('FUZZ pdf_pro toplam=$total acilan=$opened duzenlenen=$edited');
    expect(opened, greaterThan(0));
  }, timeout: const Timeout(Duration(minutes: 10)));

  test('uzun oturum: 120 düzenleme + 120 geri al + 120 yinele — gecikme '
      'sabit, metin tutarlı', () async {
    final doc = await PdfDocument.openData(
        File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync());
    addTearDown(doc.dispose);
    final session = PdfEditSession.forDocument(doc);
    addTearDown(session.close);
    String squash(String s) => s.replaceAll(RegExp(r'\s+'), '');
    final before = squash((await doc.pages[0].loadText())!.fullText);
    final times = <int>[];
    for (var i = 0; i < 120; i++) {
      final content = await PdfEditBridge.content(doc, 0);
      // En uzun düzenlenebilir blok (yeniden sarma satır sayısını oynatabilir).
      final block = (PdfEditBridge.blocksOf(content)
              .where((b) => b.editable)
              .toList()
            ..sort((a, b) => b.map.length.compareTo(a.map.length)))
          .first;
      final words = block.map.text.split(' ');
      // Baştaki sözcük sona: metin uzunluğu sabit kalır.
      final next = [...words.skip(1), words.first].join(' ');
      final sw = Stopwatch()..start();
      await session.apply(
          PdfTypesetOp(PdfBlockRequest.of(0, block, text: next, content: content)),
          label: 'pse.step_paragraph');
      times.add(sw.elapsedMicroseconds);
    }
    double avg(Iterable<int> v) => v.reduce((a, b) => a + b) / v.length;
    final early = avg(times.sublist(10, 40)), late = avg(times.sublist(90));
    // ignore: avoid_print
    print('FUZZ pdf_pro_uzun ilk=${(early / 1000).toStringAsFixed(1)}ms '
        'son=${(late / 1000).toStringAsFixed(1)}ms');
    expect(late, lessThan(early * 3 + 20000),
        reason: 'düzenleme süresi oturum uzadıkça büyümemeli');
    for (var i = 0; i < 120; i++) {
      expect(await session.undo(), isTrue);
    }
    expect(squash((await doc.pages[0].loadText())!.fullText), before);
    for (var i = 0; i < 120; i++) {
      expect(await session.redo(), isTrue);
    }
    expect(session.steps, hasLength(120));
  }, timeout: const Timeout(Duration(minutes: 10)));
}

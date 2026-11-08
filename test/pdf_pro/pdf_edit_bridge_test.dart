// PDF Pro Faz 52: PDFium düzenleme köprüsü — gerçek PDFium ile (yerel Windows:
// vsshim; CI: PDFIUM_PATH). Külliyat belgeleri uydurma metinli.
import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

Future<PdfDocument> _open(String name) => PdfDocument.openData(
    File('test/fixtures/pdf_corpus/$name').readAsBytesSync());

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

void main() {
  setUpAll(() async => pdfrxInitialize());

  test('Word belgesinde bloklar bulunur (Dart motoru 0 buluyordu)', () async {
    final doc = await _open('wd_mektup_logo.pdf');
    addTearDown(doc.dispose);
    final blocks = await PdfEditBridge.blocks(doc, 0);
    expect(blocks.length, greaterThanOrEqualTo(4));
    expect(blocks.map((b) => b.text).join(' '),
        contains('T.C. ÖRNEK KURUM MÜDÜRLÜĞÜ'));
  });

  test('blok değişir, pdfium geri okur, artımlı kayıt özgün baytları korur',
      () async {
    final bytes = File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
        .readAsBytesSync();
    final doc = await PdfDocument.openData(bytes);
    addTearDown(doc.dispose);
    final blocks = await PdfEditBridge.blocks(doc, 0);
    final target = blocks.firstWhere((b) => b.text.startsWith('Müze'));
    // Başlığın alt küme fontunda yalnız kendi harfleri var (M ü z e R h b r i).
    await PdfEditBridge.replaceBlock(doc, 0, target, 'Rehberi Müze Rehberi');

    final text = (await doc.pages[0].loadText())!.fullText;
    expect(_squash(text), contains('RehberiMüzeRehberi'));
    expect(_squash(text), isNot(contains('MüzeRehberiÖğretmenler')));

    final out = await PdfEditBridge.saveIncremental(doc);
    expect(out.sublist(0, bytes.length), bytes,
        reason: 'FPDF_INCREMENTAL: özgün baytlar başta aynen');
    final re = await PdfDocument.openData(out);
    addTearDown(re.dispose);
    expect(_squash((await re.pages[0].loadText())!.fullText),
        contains('RehberiMüzeRehberi'));
  });

  test('eksik glifte geri alınır ve glif reddi verilir (sessiz bozulma yok)',
      () async {
    final doc = await _open('rl_paragraflar.pdf');
    addTearDown(doc.dispose);
    final before = (await doc.pages[0].loadText())!.fullText;
    final blocks = await PdfEditBridge.blocks(doc, 0);
    // Alt küme fontta Çince glif yok.
    await expectLater(
      PdfEditBridge.replaceBlock(doc, 0, blocks.first, '漢字テスト'),
      throwsA(isA<PdfEditBridgeRefused>().having((e) => e.glyph, 'glyph', true)),
    );
    expect(_squash((await doc.pages[0].loadText())!.fullText), _squash(before));
  });

  test('karakter → nesne eşlemesi metin uzunluğunda', () async {
    final doc = await _open('fp_paragraflar.pdf');
    addTearDown(doc.dispose);
    final map = await PdfEditBridge.charObjects(doc, 0);
    final text = (await doc.pages[0].loadText())!.fullText;
    expect(map.length, text.length);
    expect(map.where((i) => i >= 0).length, greaterThan(text.length ~/ 2));
  });
}

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

  // Faz 54 / 0 — PK1 koşulu 1: GenerateContent Tw/Tc yazmıyor; aynı akıştaki
  // dokunulmamış satırlar sabitlenmeli (ReportLab `-0.07 Tw`).
  test('Tw kullanan dokunulmamış satır düzenlemeden sonra kaymaz', () async {
    final bytes = File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
        .readAsBytesSync();
    final doc = await PdfDocument.openData(bytes);
    addTearDown(doc.dispose);
    final before = (await doc.pages[0].loadText())!;
    final blocks = await PdfEditBridge.blocks(doc, 0);
    final twPara = blocks.indexWhere((b) => b.text.startsWith('Öğretmenler'));
    final target = blocks[twPara + 1];
    final words = target.text.split(' ');
    await PdfEditBridge.replaceBlock(doc, 0, target,
        [words.last, ...words.sublist(1, words.length - 1), words.first].join(' '));
    final out = await PdfEditBridge.saveIncremental(doc, original: bytes);
    final re = await PdfDocument.openData(out);
    addTearDown(re.dispose);
    final after = (await re.pages[0].loadText())!;
    final start = before.fullText.indexOf('Öğretmenler');
    final end = before.fullText.indexOf(words.first, start + 1);
    expect(start, greaterThanOrEqualTo(0));
    expect(after.fullText.substring(start, end),
        before.fullText.substring(start, end));
    for (var i = start; i < end; i++) {
      expect((after.charRects[i].left - before.charRects[i].left).abs(),
          lessThan(0.005), reason: 'karakter $i kaydı');
    }
  });

  // Faz 54 / 0 — PK1 koşulu 2: PDFium'un eki yüklenmiş her nesneyi yazıyor;
  // kırpma yalnız değişenleri bırakır.
  test('artımlı kayıt kırpması: ek küçük, özgün baytlar aynen, metin doğru',
      () async {
    final bytes = File('test/fixtures/pdf_corpus/wd_mektup_logo.pdf')
        .readAsBytesSync();
    final doc = await PdfDocument.openData(bytes);
    addTearDown(doc.dispose);
    await doc.pages[0].render(fullWidth: 300, fullHeight: 420); // fontlar yüklensin
    final blocks = await PdfEditBridge.blocks(doc, 0);
    final target = blocks.firstWhere((b) => b.text.split(' ').length > 3);
    final words = target.text.split(' ');
    final edited =
        [words.last, ...words.sublist(1, words.length - 1), words.first].join(' ');
    await PdfEditBridge.replaceBlock(doc, 0, target, edited);
    final full = await PdfEditBridge.saveIncremental(doc);
    final out = await PdfEditBridge.saveIncremental(doc, original: bytes);
    expect(out.sublist(0, bytes.length), bytes);
    expect(out.length - bytes.length, lessThan(4096));
    expect(out.length, lessThan(full.length));
    final re = await PdfDocument.openData(out);
    addTearDown(re.dispose);
    expect(_squash((await re.pages[0].loadText())!.fullText),
        contains(_squash(edited)));
  });

  test('sağdan sola blok açıkça reddedilir (bozuk yazım yok)', () async {
    final doc = await _open('wd_arapca.pdf');
    addTearDown(doc.dispose);
    final blocks = await PdfEditBridge.blocks(doc, 0);
    final rtl = blocks.firstWhere(
        (b) => RegExp(r'[\u0600-\u06FF]').hasMatch(b.text));
    await expectLater(
      PdfEditBridge.replaceBlock(doc, 0, rtl, rtl.text),
      throwsA(isA<PdfEditBridgeRefused>().having((e) => e.glyph, 'glyph', false)),
    );
  });
}

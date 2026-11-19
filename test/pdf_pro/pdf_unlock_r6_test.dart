// B4 / P21: AES-256 (R6) kilit açma — Syncfusion sayfasız çıktı üretiyordu
// (PDF Pro tezgâhı 2026-11-08); PdfTools artık sayfa kaybında PDFium'a düşer.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart' show PdfFile;
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' as pdfrx;

Future<int> _pdfiumPages(List<int> bytes) async {
  final doc = await pdfrx.PdfDocument.openData(Uint8List.fromList(bytes));
  try {
    return doc.pages.length;
  } finally {
    await doc.dispose();
  }
}

void main() {
  setUpAll(() async => pdfrx.pdfrxInitialize());

  test('qpdf R6 (sahip parolalı Word) kilidi sayfalar korunarak açılır',
      () async {
    final locked =
        File('test/fixtures/pdf_corpus/wd_sifreli.pdf').readAsBytesSync();
    final want = await _pdfiumPages(locked);
    expect(want, greaterThan(0));

    final open =
        await PdfTools.removePasswordInBackground(locked, currentPassword: '');

    expect(PdfFile.parse(open).isEncrypted, isFalse);
    expect(await _pdfiumPages(open), want);
    expect(await PdfTools.pageCount(open), want);
  });

  test('PDFium yolu parolalı R6 belgeyi açar, yanlış parolayı reddeder',
      () async {
    final src = File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
        .readAsBytesSync();
    final locked = await PdfTools.setPassword(src, password: 'gizli');
    // Yeni koruma R6 (PDF 2.0 AES-256); R5 Adobe'ce kullanımdan kalktı.
    expect(RegExp(r'/R\s*6\b').hasMatch(latin1.decode(locked)), isTrue);

    final open =
        await PdfTools.removePasswordPdfium(locked, currentPassword: 'gizli');
    expect(PdfFile.parse(open).isEncrypted, isFalse);
    expect(await PdfTools.pageCount(open), await PdfTools.pageCount(src));

    await expectLater(
        PdfTools.removePasswordPdfium(locked, currentPassword: 'yanlis'),
        throwsA(anything));
  });
}

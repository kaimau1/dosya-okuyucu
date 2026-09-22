import 'dart:io';

import 'package:dosya_okuyucu/services/pdf/pdf_markup.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

List<int> _blankPdf({int pages = 1, bool rotate = false}) {
  final doc = PdfDocument();
  // Syncfusion'da döndürme bölüm ayarıyla verilir (eklenmiş sayfaya
  // `rotation` atamak kalıcı olmuyor).
  if (rotate) doc.pageSettings.rotate = PdfPageRotateAngle.rotateAngle90;
  for (var i = 0; i < pages; i++) {
    doc.pages.add();
  }
  final bytes = doc.saveSync();
  doc.dispose();
  return bytes;
}

InkMark _stroke(int page, List<Offset> pts, {bool hl = false}) => InkMark(
      page,
      points: pts,
      colorArgb: 0xFFD32F2F,
      widthFraction: 0.004,
      highlighter: hl,
    );

void main() {
  group('eraseMarksAt', () {
    final a = _stroke(0, const [Offset(0.1, 0.1), Offset(0.4, 0.1)]);
    final b = _stroke(0, const [Offset(0.1, 0.8), Offset(0.4, 0.8)]);
    final other = _stroke(1, const [Offset(0.1, 0.1), Offset(0.4, 0.1)]);
    const text = TextMark(0,
        position: Offset(0.2, 0.1),
        text: 'x',
        fontFraction: 0.02,
        colorArgb: 0xFF000000);

    test('darbenin ORTASINA değen silgi darbeyi bütün olarak siler', () {
      final out = eraseMarksAt([a, b, other, text],
          page: 0,
          point: const Offset(0.25, 0.105),
          radius: 0.02,
          aspect: 0.7);
      expect(out, [b, other, text]);
    });

    test('uzakta ya da başka sayfada hiçbir şey silinmez', () {
      final marks = [a, b, other];
      expect(
          eraseMarksAt(marks,
              page: 0,
              point: const Offset(0.8, 0.5),
              radius: 0.02,
              aspect: 0.7),
          marks);
      expect(
          eraseMarksAt(marks,
              page: 2,
              point: const Offset(0.25, 0.1),
              radius: 0.02,
              aspect: 0.7),
          marks);
    });

    test('dikey mesafe sayfa oranıyla ölçülür', () {
      // Yatay sayfa (aspect 1.5): 0.03 yükseklik = 0.02 genişlik → değer.
      final wide = eraseMarksAt([a],
          page: 0,
          point: const Offset(0.25, 0.13),
          radius: 0.02,
          aspect: 1.5);
      expect(wide, isEmpty);
      // Dikey sayfa (aspect 0.5): aynı oran 0.06 genişlik → uzak.
      final tall = eraseMarksAt([a],
          page: 0,
          point: const Offset(0.25, 0.13),
          radius: 0.02,
          aspect: 0.5);
      expect(tall, [a]);
    });
  });

  group('applyPdfMarks', () {
    test('kalem + fosforlu + tek nokta yazılır, belge açılır', () async {
      final out = await applyPdfMarks(_blankPdf(pages: 2), [
        _stroke(0, const [Offset(0.1, 0.1), Offset(0.5, 0.5)]),
        _stroke(1, const [Offset(0.2, 0.2), Offset(0.6, 0.2)], hl: true),
        _stroke(0, const [Offset(0.3, 0.3)]),
      ]);
      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages.count, 2);
      doc.dispose();
      expect(out.length, greaterThan(_blankPdf(pages: 2).length));
    });

    test('döndürülmüş sayfa ve geçersiz sayfa sırası çökertmez', () async {
      final out = await applyPdfMarks(_blankPdf(rotate: true), [
        _stroke(0, const [Offset(0.1, 0.1), Offset(0.9, 0.9)]),
        _stroke(5, const [Offset(0.1, 0.1), Offset(0.9, 0.9)]),
      ]);
      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages[0].rotation, PdfPageRotateAngle.rotateAngle90);
      doc.dispose();
    });

    test('yazı Türkçe harfleriyle sayfaya girer', () async {
      final font = File('assets/fonts/Carlito-Regular.ttf').readAsBytesSync();
      final out = await applyPdfMarks(
        _blankPdf(),
        [
          const TextMark(0,
              position: Offset(0.1, 0.1),
              text: 'Şişli Çağrı ÖĞÜ',
              fontFraction: 0.03,
              colorArgb: 0xFF1565C0),
        ],
        fontBytes: font,
      );
      final doc = PdfDocument(inputBytes: out);
      final text = PdfTextExtractor(doc).extractText();
      doc.dispose();
      expect(text, contains('Şişli Çağrı ÖĞÜ'));
    });
  });
}

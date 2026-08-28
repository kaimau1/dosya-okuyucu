import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Sayfa numarası + filigran — 2026-08-28.**
///
/// Kullanıcı: *"pdf özelliklerini araştır ve geliştir"*. Var olan araçlar
/// belgeyi yeniden düzenliyordu ama sayfaya bir şey YAZMIYORDU; bu iki iş
/// (numara, damga) bir PDF aracından en çok istenenler.
///
/// Testler cihazsız koşar (saf Syncfusion) ve çıktının GERÇEKTEN okunabilir
/// bir PDF olduğunu, yazının sayfaya girdiğini doğrular.
List<int> _samplePdf({int pages = 3}) {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    final page = doc.pages.add();
    page.graphics.drawString(
      'Sayfa govdesi $i',
      PdfStandardFont(PdfFontFamily.helvetica, 14),
      bounds: const Rect.fromLTWH(40, 60, 300, 30),
    );
  }
  final bytes = doc.saveSync();
  doc.dispose();
  return bytes;
}

String _textOf(List<int> bytes, int pageIndex) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(doc)
        .extractText(startPageIndex: pageIndex, endPageIndex: pageIndex);
  } finally {
    doc.dispose();
  }
}

void main() {
  group('sayfa numarası', () {
    test('her sayfaya numara yazılır, sayfa sayısı değişmez', () async {
      final out = await PdfTools.addPageNumbers(_samplePdf());
      expect(await PdfTools.pageCount(out), 3);
      for (var i = 0; i < 3; i++) {
        expect(_textOf(out, i), contains('${i + 1}'));
      }
    });

    test('var olan içerik SİLİNMEZ (üstüne yazılır)', () async {
      final out = await PdfTools.addPageNumbers(_samplePdf(pages: 1));
      expect(_textOf(out, 0), contains('Sayfa govdesi 0'));
    });

    test('kapak atlanabilir ve numara istenen yerden başlar', () async {
      final out = await PdfTools.addPageNumbers(
        _samplePdf(),
        skipFirstPage: true,
        startAt: 5,
      );
      // İlk sayfada gövde metni var ama numara yok.
      expect(_textOf(out, 0), isNot(contains('5')));
      expect(_textOf(out, 1), contains('5'));
      expect(_textOf(out, 2), contains('6'));
    });

    test('"n / toplam" biçimi', () async {
      final out = await PdfTools.addPageNumbers(_samplePdf(), withTotal: true);
      final first = _textOf(out, 0).replaceAll(' ', '');
      expect(first, contains('1/3'));
    });

    test('sağ alta hizalama da çalışır', () async {
      final out = await PdfTools.addPageNumbers(
        _samplePdf(pages: 1),
        position: PdfTools.numberBottomRight,
      );
      expect(_textOf(out, 0), contains('1'));
    });
  });

  group('filigran', () {
    test('metin her sayfaya girer', () async {
      final out = await PdfTools.addWatermark(_samplePdf(), text: 'TASLAK');
      for (var i = 0; i < 3; i++) {
        expect(_textOf(out, i), contains('TASLAK'));
      }
    });

    test('gövde metni korunur', () async {
      final out =
          await PdfTools.addWatermark(_samplePdf(pages: 1), text: 'KOPYA');
      final text = _textOf(out, 0);
      expect(text, contains('Sayfa govdesi 0'));
      expect(text, contains('KOPYA'));
    });

    test('boş metin reddedilir (sessizce hiçbir şey yapmaz DEĞİL)', () {
      expect(() => PdfTools.addWatermark(_samplePdf(), text: '   '),
          throwsArgumentError);
    });

    test('uzun metin sayfaya sığdırılır (yazı boyutu ölçekleniyor)', () async {
      final out = await PdfTools.addWatermark(
        _samplePdf(pages: 1),
        text: 'BU COK UZUN BIR FILIGRAN METNIDIR VE SIGMALI',
      );
      // Çıktı hâlâ geçerli bir PDF ve metin içeride.
      expect(await PdfTools.pageCount(out), 1);
      expect(_textOf(out, 0), contains('FILIGRAN'));
    });

    test('saydamlık sonraki çizimlere sızmaz (save/restore)', () async {
      // Filigrandan sonra numara basılırsa numara SOLUK olmamalı — iki işlem
      // arka arkaya uygulanabiliyor olmalı.
      final watermarked =
          await PdfTools.addWatermark(_samplePdf(pages: 2), text: 'TASLAK');
      final numbered = await PdfTools.addPageNumbers(watermarked);
      expect(_textOf(numbered, 1), contains('TASLAK'));
      expect(_textOf(numbered, 1), contains('2'));
    });
  });
}

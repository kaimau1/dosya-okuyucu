import 'dart:convert';
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf_annotator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 2 vurgu annotation'ının TEK gerçek riski: pdfium (Y-yukarı) →
/// Syncfusion (Y-aşağı) koordinat çevirisi. Syncfusion PDF I/O'su cihaz/
/// gerçek dosya ister; buradaki saf matematik cihazsız doğrulanır.
void main() {
  group('pdfToSyncfusionRect — Y ekseni çevirisi', () {
    test('sayfa ÜSTÜNDEKİ satır küçük top verir', () {
      // 800pt sayfa, pdfium top=780 (üstten 20pt aşağıda), yükseklik 15.
      final r = pdfToSyncfusionRect(
        left: 50,
        pdfTop: 780,
        width: 120,
        height: 15,
        pageHeight: 800,
      );
      expect(r.left, 50);
      expect(r.top, 20); // 800 - 780
      expect(r.width, 120);
      expect(r.height, 15);
      expect(r.bottom, 35); // top + height
    });

    test('sayfa ALTINDAKİ satır büyük top verir', () {
      // pdfium top=30 (sayfa altına yakın), yükseklik 10.
      final r = pdfToSyncfusionRect(
        left: 0,
        pdfTop: 30,
        width: 100,
        height: 10,
        pageHeight: 800,
      );
      expect(r.top, 770); // 800 - 30
      expect(r.bottom, 780);
    });

    test('genişlik/yükseklik ekseni çevirmez', () {
      final r = pdfToSyncfusionRect(
        left: 12,
        pdfTop: 400,
        width: 33,
        height: 9,
        pageHeight: 600,
      );
      expect(r.width, 33);
      expect(r.height, 9);
    });
  });

  /// **Döndürülmüş sayfa (`/Rotate`) sözleşmesi.**
  ///
  /// Uzun süre "vurgu /Rotate=0 varsayıyor, döndürülmüş sayfada kayabilir" diye
  /// bir şüphe taşındı. 2026-07-26'da ÖLÇÜLDÜ: kaymıyor, çünkü iki taraf da HAM
  /// sayfa uzayında konuşuyor (pdfium `charRects` ham verir; Syncfusion'ın yüklü
  /// sayfadaki `size`'ı ham kutu ölçüsüdür). Bu testler o sözleşmeyi sabitliyor —
  /// Syncfusion bir gün `/Rotate`'i `size`'a yansıtmaya başlarsa burası kırmızıya
  /// döner ve dönüşümü eklememiz gerektiğini söyler.
  group('addHighlight — /Rotate açısından bağımsız', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    /// 400x600 tek sayfalık PDF; [quarterTurns] kadar `/Rotate` uygulanmış.
    Future<List<int>> makePage(int quarterTurns) async {
      final doc = PdfDocument();
      doc.sections!.add()
        ..pageSettings = (PdfPageSettings(const Size(400, 600))
          ..margins.all = 0)
        ..pages.add();
      final bytes = await doc.save();
      doc.dispose();
      if (quarterTurns == 0) return bytes;
      // Rotasyon YALNIZ yüklü sayfaya yazılabilir (bkz. HAFIZA Faz 1 tuzağı).
      final loaded = PdfDocument(inputBytes: bytes);
      loaded.pages[0].rotation = PdfPageRotateAngle.values[quarterTurns];
      final out = await loaded.save();
      loaded.dispose();
      return out;
    }

    /// PDF'e yazılmış annotation `/Rect` girdileri.
    List<List<double>> annotationRects(List<int> pdf) {
      final raw = latin1.decode(pdf, allowInvalid: true);
      return RegExp(r'/Rect\s*\[([^\]]*)\]')
          .allMatches(raw)
          .map((m) => m
              .group(1)!
              .trim()
              .split(RegExp(r'\s+'))
              .map(double.parse)
              .toList())
          .toList();
    }

    for (final turns in [0, 1, 2, 3]) {
      test('${turns * 90}° sayfada vurgu ham koordinatta yazılır', () async {
        // pdfium'dan gelecek türden ham dikdörtgen: sol 50, üst 580, alt 560.
        final out = await PdfAnnotator.addHighlight(
          bytes: await makePage(turns),
          pageIndex: 0,
          pdfRects: const [PdfRect(50, 580, 150, 560)],
          colorArgb: 0xFFFFF176,
        );

        final rects = annotationRects(out);
        expect(rects, hasLength(1), reason: 'tek vurgu bekleniyordu');
        // /Rect = [sol, alt, sağ, üst] — girdiyle birebir, döndürmeden bağımsız.
        expect(rects.single, [50, 560, 150, 580]);
      });
    }

    test('çok satırlı seçimde sınır kutusu tüm satırları kapsar', () async {
      final out = await PdfAnnotator.addHighlight(
        bytes: await makePage(0),
        pageIndex: 0,
        pdfRects: const [
          PdfRect(50, 580, 150, 560),
          PdfRect(40, 555, 200, 535),
        ],
        colorArgb: 0xFFFFF176,
      );

      expect(annotationRects(out).single, [40, 535, 200, 580]);
    });

    test('boş seçimde dosya DEĞİŞTİRİLMEZ', () async {
      final src = await makePage(0);

      final out = await PdfAnnotator.addHighlight(
        bytes: src,
        pageIndex: 0,
        pdfRects: const [],
        colorArgb: 0xFFFFF176,
      );

      expect(identical(out, src), isTrue);
    });
  });
}

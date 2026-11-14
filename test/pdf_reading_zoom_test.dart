import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/pdf_reading_zoom.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_text_blocks.dart';

/// Ferrari H3: çift dokunma yakınlaştırmasının saf hesabı.
void main() {
  group('çift dokunma (H3.1)', () {
    test('genişliğe sığmışken yakın sayılmaz, belirgin büyükse sayılır', () {
      expect(PdfReadingZoom.isZoomedIn(1.0, 1.0), isFalse);
      expect(PdfReadingZoom.isZoomedIn(1.04, 1.0), isFalse);
      expect(PdfReadingZoom.isZoomedIn(1.2, 1.0), isTrue);
      expect(PdfReadingZoom.isZoomedIn(2, 0), isFalse,
          reason: 'ölçü yoksa yakınlık bilinmez');
    });

    test('yakınlaşma 2,5× ve tavanı aşmaz', () {
      expect(PdfReadingZoom.zoomInTarget(1.0, 8), 2.5);
      expect(PdfReadingZoom.zoomInTarget(4.0, 8), 8);
    });
  });

  // A4 benzeri 600×800 sayfa, iki sütun: sol 50–280, sağ 320–550.
  PdfTextObjectInfo line(double l, double r, double y, [String t = 'metin']) =>
      PdfTextObjectInfo(
        index: 0,
        text: t,
        left: l,
        bottom: y,
        right: r,
        top: y + 10,
        tfSize: 10,
        fontName: 'Arimo',
        matrix: [1, 0, 0, 1, l, y],
        renderMode: 0,
      );

  PdfPageContent page(List<PdfTextObjectInfo> texts,
          [List<PdfPageItem> items = const []]) =>
      PdfPageContent(texts, items, 600, 800);

  group('akıllı yakınlaştırma (H3.2)', () {
    final twoColumns = page([
      for (var y = 100.0; y < 700; y += 14) ...[
        line(50, 280, y),
        line(320, 550, y),
      ],
    ]);

    test('iki sütunlu sayfada dokunulan sütun bulunur', () {
      final left = PdfReadingZoom.columnAt(twoColumns, 120, 400)!;
      expect(left.left, lessThan(50));
      expect(left.right, greaterThan(280));
      expect(left.right, lessThan(320));
      final right = PdfReadingZoom.columnAt(twoColumns, 500, 400)!;
      expect(right.left, greaterThan(280));
      expect(right.right, greaterThan(550));
    });

    test('sözcük sözcük kutular tek sütunda birleşir', () {
      final words = page([
        for (var y = 100.0; y < 700; y += 14)
          for (var x = 50.0; x < 540; x += 40) line(x, x + 34, y, 'söz'),
      ]);
      final col = PdfReadingZoom.columnAt(words, 300, 400)!;
      expect(col.left, lessThan(50));
      expect(col.right, greaterThan(540));
    });

    test('boş yerde ya da dar parçada sütun yok', () {
      expect(PdfReadingZoom.columnAt(twoColumns, 10, 400), isNull,
          reason: 'kenar boşluğu sütun değil');
      final pageNo = page([line(290, 310, 40, '12')]);
      expect(PdfReadingZoom.columnAt(pageNo, 300, 45), isNull,
          reason: 'sayfa numarası sütun değil');
    });

    test('görsel kutusu metinden önce gelir, tam sayfa görsel sayılmaz', () {
      const img = PdfPageItem(
          index: 3, type: 3, left: 320, bottom: 300, right: 550, top: 500);
      const scan = PdfPageItem(
          index: 1, type: 3, left: 0, bottom: 0, right: 600, top: 800);
      final c = page(twoColumns.texts, const [scan, img]);
      final box = PdfReadingZoom.smartTarget(c, 400, 400)!;
      expect(box.left, 320);
      expect(box.right, 550);
      expect(PdfReadingZoom.imageAt(page(const [], const [scan]), 300, 400),
          isNull);
    });

    test('kutu zaten ekranı dolduruyorsa akıllı yakınlık yok', () {
      expect(
          PdfReadingZoom.fitBoxZoom(
              viewWidth: 400, boxWidth: 600, current: 0.66, maxZoom: 8),
          isNull);
      expect(
          PdfReadingZoom.fitBoxZoom(
              viewWidth: 400, boxWidth: 240, current: 0.66, maxZoom: 8),
          closeTo(400 / 240, 1e-9));
      expect(
          PdfReadingZoom.fitBoxZoom(
              viewWidth: 400, boxWidth: 10, current: 0.66, maxZoom: 8),
          8);
    });
  });
}

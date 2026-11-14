import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/pdf_reading_zoom.dart';

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
}

import 'package:dosya_okuyucu/services/pdf_annotator.dart';
import 'package:flutter_test/flutter_test.dart';

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
}

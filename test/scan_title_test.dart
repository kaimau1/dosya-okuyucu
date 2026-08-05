import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/ocr_service.dart' show OcrLine;
import 'package:dosya_okuyucu/services/scan_title.dart';

/// Akıllı tarama adı: OCR satırlarından başlık seçimi. Kural: üst bölgedeki
/// EN BÜYÜK puntolu satır başlıktır; kısa üst başlık ("T.C.") altındaki benzer
/// puntolu satırla birleşir; ad dosya sistemine uygun temizlenir.
void main() {
  OcrLine line(String text, {double top = 0, double height = 20}) =>
      OcrLine(text, Rect.fromLTWH(40, top, 400, height));

  group('suggestScanTitle', () {
    test('en büyük puntolu üst satır kazanır', () {
      final title = suggestScanTitle([
        line('12.03.2026', top: 10, height: 14),
        line('SAĞLIK RAPORU', top: 40, height: 42),
        line('Hasta adı ve uzun açıklama satırı', top: 100, height: 16),
      ]);
      expect(title, 'SAĞLIK RAPORU');
    });

    test('kısa üst başlık altındaki benzer puntolu satırla birleşir', () {
      final title = suggestScanTitle([
        line('T.C.', top: 10, height: 34),
        line('SAĞLIK BAKANLIĞI', top: 50, height: 30),
        line('normal paragraf metni', top: 100, height: 14),
      ]);
      expect(title, 'T.C. SAĞLIK BAKANLIĞI');
    });

    test('harf içermeyen/kısa satırlar aday olamaz', () {
      expect(suggestScanTitle([line('123456', height: 40)]), isNull);
      expect(suggestScanTitle([line('—', height: 40)]), isNull);
      expect(suggestScanTitle(const []), isNull);
    });

    test('dosya adına giremeyecek karakterler ayıklanır', () {
      final title = suggestScanTitle([
        line('FATURA: 2026/07 "Temmuz"', height: 40),
      ]);
      expect(title, isNotNull);
      expect(title!.contains(RegExp(r'[\\/:*?"<>|]')), isFalse);
      expect(title, 'FATURA 2026 07 Temmuz');
    });

    test('uzun başlık kelime sınırında 48 karaktere kısaltılır', () {
      final title = suggestScanTitle([
        line(
          'ÇOK UZUN BİR KURUM ADI VE ALTINDA UZAYIP GİDEN BELGE BAŞLIĞI SATIRI',
          height: 40,
        ),
      ])!;
      expect(title.length, lessThanOrEqualTo(48));
      expect(title.endsWith(' '), isFalse);
    });
  });

  group('scanFileName', () {
    final now = DateTime(2026, 8, 5, 17, 30, 9);

    test('başlık + tarih', () {
      expect(scanFileName('SAĞLIK RAPORU', now), 'SAĞLIK RAPORU 2026-08-05.pdf');
    });

    test('başlık yoksa damgalı eski ad (saat dahil)', () {
      expect(scanFileName(null, now), 'Tarama 2026-08-05 173009.pdf');
    });
  });
}

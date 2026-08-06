import 'package:dosya_okuyucu/services/pdf/pdf_scanned_retype.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart' show PdfRect;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Taranmış satır üstüne yazma (2026-08-06: "taranmış belge deyip düzenleme
/// yaptırmıyor"): kapak + yeni metin yazılmış PDF geçerli kalmalı ve yeni
/// metin çıkarılabilir olmalı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<List<int>> onePagePdf() async {
    final doc = PdfDocument();
    doc.pages.add();
    final bytes = await doc.save();
    doc.dispose();
    return bytes;
  }

  test('satır örtülür, yeni metin gömülü fontla yazılır', () async {
    final src = await onePagePdf();
    // A4 ~595x842 pt; PDF koordinatı y-yukarı: top > bottom.
    const box = PdfRect(50, 700, 300, 682);
    final out = await PdfScannedRetype.apply(
      bytes: src,
      pageIndex: 0,
      box: box,
      newText: 'Fizik Muayene ğüşiöç',
    );
    expect(out, isNotEmpty);

    final reopened = PdfDocument(inputBytes: out);
    try {
      final text = PdfTextExtractor(reopened).extractText(startPageIndex: 0);
      expect(text, contains('Fizik Muayene'));
      // Türkçe glifler gömülü fontla kaybolmamalı.
      expect(text, contains('ğüşiöç'));
    } finally {
      reopened.dispose();
    }
  });

  test('boş metin yalnız siler: belge geçerli kalır, metin eklenmez', () async {
    final src = await onePagePdf();
    const box = PdfRect(50, 700, 300, 682);
    final out = await PdfScannedRetype.apply(
      bytes: src,
      pageIndex: 0,
      box: box,
      newText: '   ',
    );
    final reopened = PdfDocument(inputBytes: out);
    try {
      final text =
          PdfTextExtractor(reopened).extractText(startPageIndex: 0).trim();
      expect(text, isEmpty);
    } finally {
      reopened.dispose();
    }
  });
}

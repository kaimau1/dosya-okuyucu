import 'dart:typed_data';

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

  // P19 m.2: kapak kâğıt renginde, metin mürekkep renginde.
  Uint8List region(int w, int h, List<int> paper, List<int> ink) {
    final px = Uint8List(w * h * 4);
    for (var y = 0; y < h; y++) {
      for (var x = 0; x < w; x++) {
        final c = (y > 3 && y < h - 4 && x > 3 && x < w - 4 && x.isEven)
            ? ink
            : paper;
        final i = (y * w + x) * 4;
        px[i] = c[2]; // B
        px[i + 1] = c[1]; // G
        px[i + 2] = c[0]; // R
        px[i + 3] = 255;
      }
    }
    return px;
  }

  test('sararmış kâğıt: zemin kenardan, mürekkep yazıdan örneklenir', () {
    final c = PdfScannedRetype.sampleColors(
        region(60, 20, [240, 228, 200], [20, 30, 120]), 60, 20)!;
    expect(c.background, 0xFFF0E4C8);
    expect(c.ink, 0xFF141E78);
  });

  test('yazısız bölge: mürekkep koyu gri varsayılan', () {
    final c = PdfScannedRetype.sampleColors(
        region(30, 12, [250, 250, 250], [250, 250, 250]), 30, 12)!;
    expect(c.background, 0xFFFAFAFA);
    expect(c.ink, 0xFF191919);
  });

  test('örneklenen renkle yazılan PDF geçerli kalır', () async {
    final out = await PdfScannedRetype.apply(
      bytes: await onePagePdf(),
      pageIndex: 0,
      box: const PdfRect(50, 700, 300, 682),
      newText: 'Renkli zemin',
      colors: (background: 0xFFF0E4C8, ink: 0xFF141E78),
    );
    final reopened = PdfDocument(inputBytes: out);
    try {
      expect(PdfTextExtractor(reopened).extractText(startPageIndex: 0),
          contains('Renkli zemin'));
    } finally {
      reopened.dispose();
    }
  });
}

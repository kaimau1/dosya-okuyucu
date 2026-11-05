import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:dosya_okuyucu/services/pdf_page_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 8 — boş sayfa algılama, kırpma, A4'e sığdırma.
Future<List<int>> _doc(List<Size> sizes) async {
  final doc = PdfDocument();
  for (final s in sizes) {
    final section = doc.sections!.add()
      ..pageSettings = (PdfPageSettings(s)..margins.all = 0);
    section.pages.add().graphics.drawString(
        'Metin', PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(20, 20, 100, 20));
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

List<Size> _sizes(List<int> bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return [for (var i = 0; i < doc.pages.count; i++) doc.pages[i].size];
  } finally {
    doc.dispose();
  }
}

void main() {
  test('boş sayfa: beyaz boş, yazılı dolu, kenar gölgesi sayılmaz', () {
    const w = 100, h = 140;
    final white = Uint8List(w * h)..fillRange(0, w * h, 255);
    expect(PdfPagePro.isBlank(w, h, white), isTrue);
    final edge = Uint8List.fromList(white);
    for (var y = 0; y < h; y++) {
      edge[y * w] = 0; // sol kenar gölgesi
    }
    expect(PdfPagePro.isBlank(w, h, edge), isTrue);
    final text = Uint8List.fromList(white);
    for (var i = 40 * w + 20; i < 40 * w + 80; i++) {
      text[i] = 0;
      text[i + w] = 0;
    }
    expect(PdfPagePro.isBlank(w, h, text), isFalse);
  });

  test('sığdırma: yatay içerik yatay A4, ortalanır', () {
    final f = PdfPagePro.fit(const Size(800, 400), PdfPagePro.a4);
    expect(f.page.width, greaterThan(f.page.height));
    expect(f.offset.dx, closeTo(0, 1e-6));
    expect(f.offset.dy, greaterThan(0));
  });

  test('kırpma yalnız seçili sayfayı küçültür', () async {
    final out = await PdfPagePro.crop(
        await _doc(const [Size(400, 600), Size(400, 600)]),
        const Rect.fromLTWH(50, 50, 200, 300),
        pages: [1]);
    final sizes = _sizes(out);
    expect(sizes[0].width, closeTo(400, 1));
    expect(sizes[1].width, closeTo(200, 1));
    expect(sizes[1].height, closeTo(300, 1));
  });

  test('A4e sığdır: her sayfa A4 olur', () async {
    final out =
        await PdfPagePro.resize(await _doc(const [Size(300, 300), Size(612, 792)]));
    for (final s in _sizes(out)) {
      expect(s.width, closeTo(PdfPagePro.a4.width, 1));
      expect(s.height, closeTo(PdfPagePro.a4.height, 1));
    }
  });
}

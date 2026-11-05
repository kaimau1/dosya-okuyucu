import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:dosya_okuyucu/services/pdf_raster.dart';
import 'package:dosya_okuyucu/services/pdf_redact.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as imglib;
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 2 — kalıcı karartma DOĞRULAMA testi: karartılan sözcük
/// çıktıda HİÇBİR yolla (metin çıkarma) bulunmaz, kutu dışı metin aranabilir
/// kalır, piksel verisi siyaha boyanır. (pdfium çizimi cihazda; burada
/// görüntü yerine düz beyaz JPEG verilir — katman mantığı aynı.)
Future<List<int>> _doc() async {
  final doc = PdfDocument();
  final page = doc.pages.add();
  final font = PdfStandardFont(PdfFontFamily.helvetica, 14);
  page.graphics.drawString('Hasta ADI Gizlisoyad numara',
      font, bounds: const Rect.fromLTWH(20, 40, 500, 20));
  page.graphics.drawString('Herkese acik satir', font,
      bounds: const Rect.fromLTWH(20, 120, 500, 20));
  doc.pages.add().graphics.drawString('Ikinci sayfa Gizlisoyad', font,
      bounds: const Rect.fromLTWH(20, 40, 500, 20));
  final out = await doc.save();
  doc.dispose();
  return out;
}

Uint8List _whiteJpeg() {
  final img = imglib.Image(width: 60, height: 80)
    ..clear(imglib.ColorRgb8(255, 255, 255));
  return imglib.encodeJpg(img);
}

String _text(List<int> bytes) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

void main() {
  test('findText her sayfadaki geçişi bulur', () async {
    final hits = PdfRedact.findText(await _doc(), ['gizlisoyad']);
    expect(hits.keys.toSet(), {0, 1});
  });

  test('karartılan sözcük çıktıda yok, kutu dışı metin aranabilir', () async {
    final bytes = await _doc();
    final rects = PdfRedact.findText(bytes, ['Gizlisoyad']);
    expect(_text(bytes), contains('Gizlisoyad'));
    final out = await PdfRedact.apply(
      bytes,
      rects: rects,
      rasters: [for (final i in rects.keys) RedactedRaster(i, _whiteJpeg())],
    );
    final text = _text(out);
    expect(text, isNot(contains('Gizlisoyad')));
    expect(text, contains('Herkese'));
    expect(PdfRedact.leakedWords(out, rects), isEmpty);
    // Sayfa sayısı korunur.
    final doc = PdfDocument(inputBytes: out);
    expect(doc.pages.count, 2);
    doc.dispose();
  });

  test('elle çizilen kutu: değen sözcük düşer', () async {
    final bytes = await _doc();
    // Yeni belgede `drawString` kutuları 40 pt kenar boşluklu istemci
    // alanına göredir; karartma kutusu SAYFA puntosunda (+40).
    final rects = {
      0: [const Rect.fromLTWH(55, 155, 200, 30)],
    };
    final out = await PdfRedact.apply(bytes,
        rects: rects, rasters: [RedactedRaster(0, _whiteJpeg())]);
    expect(_text(out), isNot(contains('Herkese')));
    expect(PdfRedact.leakedWords(out, rects), isEmpty);
  });

  test('özgün belgede kutu SIZDIRIR (doğrulayıcının kendisi çalışıyor)',
      () async {
    final bytes = await _doc();
    final rects = PdfRedact.findText(bytes, ['Gizlisoyad']);
    expect(PdfRedact.leakedWords(bytes, rects), isNotEmpty);
  });

  test('piksel karartma: kutu siyah, dışı beyaz', () {
    const w = 40, h = 20;
    final px = Uint8List(w * h * 4)..fillRange(0, w * h * 4, 255);
    final jpeg = PdfRaster.encodeJpeg(px, w, h,
        bgraOrder: false,
        quality: 100,
        blackout: [
          [0, 0, 20, 20],
        ]);
    final img = imglib.decodeJpg(jpeg)!;
    expect(img.getPixel(5, 10).r, lessThan(40));
    expect(img.getPixel(35, 10).r, greaterThan(215));
  });

  test('döndürülmüş sayfa: ham → görünen koordinat', () {
    const raw = Size(100, 200);
    final r = PdfRedact.rawToDisplay(
        const Rect.fromLTWH(10, 20, 30, 40), raw, 1);
    // 90°: (x,y) → (H - y, x)
    expect(r, const Rect.fromLTRB(140, 10, 180, 40));
  });
}

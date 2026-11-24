// Taranmış yazıyı değiştir (2026-11-24): kâğıt rengi ölçümü.
import 'dart:typed_data';
import 'dart:ui';

import 'package:dosya_okuyucu/services/pdf/pro/pdf_scan_block.dart';
import 'package:flutter_test/flutter_test.dart';

/// [w]×[h] BGRA görüntü: zemin [paper], [ink] dikdörtgeni koyu yazı.
Uint8List _img(int w, int h, int paper, Rect ink, int inkColor) {
  final px = Uint8List(w * h * 4);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final c = ink.contains(Offset(x + 0.5, y + 0.5)) ? inkColor : paper;
      final i = (y * w + x) * 4;
      px[i] = c & 0xFF; // B
      px[i + 1] = (c >> 8) & 0xFF; // G
      px[i + 2] = (c >> 16) & 0xFF; // R
      px[i + 3] = 0xFF;
    }
  }
  return px;
}

void main() {
  test('kitap sayfasının sarımsı kâğıdı ölçülür, yazı rengi karışmaz', () {
    const paper = 0xF3E9D2;
    const ink = Rect.fromLTWH(20, 20, 40, 10);
    final px = _img(80, 50, paper, ink, 0x202020);
    expect(PdfScanBlock.paperFromBgra(px, 80, 50, ink), 0xFF000000 | paper);
  });

  test('halkada koyu çizgi olsa da kâğıt rengi kazanır', () {
    const paper = 0xFFFFFF;
    const block = Rect.fromLTWH(20, 20, 40, 10);
    // Bloğun hemen altında koyu tablo çizgisi.
    final px = _img(80, 50, paper, const Rect.fromLTWH(10, 33, 60, 2), 0x000000);
    expect(PdfScanBlock.paperFromBgra(px, 80, 50, block), 0xFFFFFFFF);
  });

  test('görüntü dışı ya da boş girdi null döner', () {
    expect(PdfScanBlock.paperFromBgra(Uint8List(0), 0, 0, Rect.zero), isNull);
  });
}

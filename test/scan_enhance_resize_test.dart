import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:dosya_okuyucu/services/scan_enhance.dart';

/// PDF boyut denetimi: 12MP kamera sayfası (~4000 px) PDF'i sayfa başına
/// birkaç MB şişiriyordu. Filtre borusunun başında uzun kenar 2480 px'e
/// (A4 @ 300 dpi) indirilir; küçük görsele dokunulmaz, oran korunur.
void main() {
  img.Image blank(int w, int h) {
    final rgb = Uint8List(w * h * 3);
    rgb.fillRange(0, rgb.length, 220);
    return img.Image.fromBytes(width: w, height: h, bytes: rgb.buffer, numChannels: 3);
  }

  test('dev sayfa 2480 uzun kenara iner, oran korunur', () {
    final out = ScanEnhance.applyToImage(blank(4000, 3000), ScanFilter.gray);
    expect(out.width, ScanEnhance.maxLongEdge);
    expect(out.height, (3000 * ScanEnhance.maxLongEdge / 4000).round());
  });

  test('dikey sayfada uzun kenar yüksekliktir', () {
    final out = ScanEnhance.applyToImage(blank(1500, 5000), ScanFilter.auto);
    expect(out.height, ScanEnhance.maxLongEdge);
    expect(out.width, (1500 * ScanEnhance.maxLongEdge / 5000).round());
  });

  test('küçük görsel büyütülmez, boyutu aynen kalır', () {
    final out = ScanEnhance.applyToImage(blank(1200, 800), ScanFilter.gray);
    expect(out.width, 1200);
    expect(out.height, 800);
  });
}

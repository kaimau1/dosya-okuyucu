import 'dart:typed_data';

import 'package:dosya_okuyucu/core/image_decode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

void main() {
  test('yaygın biçimleri (PNG, JPEG, GIF, BMP, ICO) çözer', () {
    final src = img.Image(width: 4, height: 3);
    img.fill(src, color: img.ColorRgba8(40, 120, 220, 255));

    for (final bytes in <Uint8List>[
      img.encodePng(src),
      img.encodeJpg(src, quality: 90),
      img.encodeGif(src),
      img.encodeBmp(src),
      img.encodeIco(src),
    ]) {
      final decoded = decodeCommonImage(bytes);
      expect(decoded, isNotNull);
      expect(decoded!.width, 4);
      expect(decoded.height, 3);
    }
  });

  test('boş veya bozuk veride null döndürür', () {
    expect(decodeCommonImage(Uint8List(0)), isNull);
    expect(decodeCommonImage(Uint8List.fromList([1, 2, 3, 4, 5])), isNull);
    expect(findCommonDecoderForData(Uint8List(0)), isNull);
  });
}

import 'dart:typed_data';

import 'package:dosya_okuyucu/widgets/slide_canvas.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-09-23 bellek denetimi: PPTX'e gömülü kamera fotoğrafları TAM
/// çözünürlükte çözülüyordu (4000×3000 ≈ 48 MB / görsel).
void main() {
  test('slayt görseli en uzun kenarı sınırlanarak çözülür', () {
    final provider = slideImageProvider(Uint8List(4));
    expect(provider, isA<ResizeImage>());
    final resize = provider as ResizeImage;
    expect(resize.width, slideImageMaxEdge);
    expect(resize.height, slideImageMaxEdge);
    // `fit`: en-boy oranı korunur, iki kenar da kutuya sığar.
    expect(resize.policy, ResizeImagePolicy.fit);
    // Küçük görsel büyütülüp bellekte şişmez.
    expect(resize.allowUpscaling, isFalse);
  });

  test('tuval ve PDF aktarımı AYNI önbellek anahtarını kullanır', () async {
    // SlideSnapshot görselleri önceden önbelleğe alıyor; anahtar tuvalinkinden
    // farklı olsaydı slayt PDF'e görselsiz basılırdı (sessiz bozulma).
    // `ImageCache` sağlayıcı nesnesine değil `obtainKey`in anahtarına bakar.
    final bytes = Uint8List(4);
    final a = await slideImageProvider(bytes)
        .obtainKey(ImageConfiguration.empty);
    final b = await slideImageProvider(bytes)
        .obtainKey(ImageConfiguration.empty);
    expect(a, b);
    expect(a.hashCode, b.hashCode);
  });
}

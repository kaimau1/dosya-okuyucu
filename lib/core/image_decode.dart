import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Yaygın görsel biçimlerini dosya imzasından çözer.
///
/// Neden `img.decodeImage` yerine bu yardımcı: `package:image`in genel
/// `findDecoderForData` işlevi PSD, EXR, PVR, TGA ve PNM çözücülerini de
/// AOT derlemesine bağlar (~250–350 KB ek kod). Telefon, web ve belgelerde
/// karşılaşılan biçimler (JPEG, PNG, GIF, WebP, TIFF, BMP, ICO) doğrudan
/// seçilirken aynı çözümleme ve yönelim davranışı korunur.
img.Decoder? findCommonDecoderForData(List<int> data) {
  final bytes = data is Uint8List ? data : Uint8List.fromList(data);

  final jpg = img.JpegDecoder();
  if (jpg.isValidFile(bytes)) return jpg;

  final png = img.PngDecoder();
  if (png.isValidFile(bytes)) return png;

  final gif = img.GifDecoder();
  if (gif.isValidFile(bytes)) return gif;

  final webp = img.WebPDecoder();
  if (webp.isValidFile(bytes)) return webp;

  final tiff = img.TiffDecoder();
  if (tiff.isValidFile(bytes)) return tiff;

  final bmp = img.BmpDecoder();
  if (bmp.isValidFile(bytes)) return bmp;

  final ico = img.IcoDecoder();
  if (ico.isValidFile(bytes)) return ico;

  return null;
}

/// [data] baytlarından JPEG, PNG, GIF, WebP, TIFF, BMP veya ICO görseli çözer.
img.Image? decodeCommonImage(Uint8List data, {int? frame}) =>
    findCommonDecoderForData(data)?.decode(data, frame: frame);

/// PDF Pro görsel hazırlığı (Faz 59 / 2): eklenecek görsel cihaz bütçesine
/// göre küçültülür ve uygulamanın geçici alanına yazılır — düzenleme komutu
/// dosya yolunu taşır (kayıt/kurtarma aynı dosyadan yeniden oynatır).
library;

import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'pdf_edit_bridge.dart';

class PdfPreparedImage {
  final String path;
  final int width, height;
  const PdfPreparedImage(this.path, this.width, this.height);
}

abstract final class PdfProImages {
  /// Uzun kenar tavanı (piksel).
  static const maxEdge = 2200;

  static Future<Directory> _dir() async {
    final d = Directory(p.join(Directory.systemTemp.path, 'pdf_pro_gorsel'));
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  /// [bytes]'ı çözer, gerekirse küçültür; saydamlık yoksa JPEG, varsa PNG
  /// yazar. Çözülemezse null.
  static Future<PdfPreparedImage?> prepare(Uint8List bytes) async {
    final out = await Isolate.run(() {
      final im = img.decodeImage(bytes);
      if (im == null) return null;
      var pic = img.bakeOrientation(im);
      final long = pic.width > pic.height ? pic.width : pic.height;
      if (long > maxEdge) {
        pic = img.copyResize(pic,
            width: pic.width >= pic.height ? maxEdge : null,
            height: pic.height > pic.width ? maxEdge : null,
            interpolation: img.Interpolation.average);
      }
      var alpha = false;
      if (pic.numChannels == 4) {
        for (final px in pic) {
          if (px.a < px.maxChannelValue) {
            alpha = true;
            break;
          }
        }
      }
      return (
        alpha ? img.encodePng(pic) : img.encodeJpg(pic, quality: 88),
        alpha,
        pic.width,
        pic.height
      );
    });
    if (out == null) return null;
    final dir = await _dir();
    final file = File(p.join(dir.path,
        'g_${DateTime.now().microsecondsSinceEpoch}.${out.$2 ? 'png' : 'jpg'}'));
    await file.writeAsBytes(out.$1, flush: true);
    return PdfPreparedImage(file.path, out.$3, out.$4);
  }

  /// Görsel nesnesinin piksellerini PNG olarak verir (dışa aktarma, kırpma).
  static Future<Uint8List> png(PdfImagePixels px,
          {int left = 0, int top = 0, int? width, int? height}) =>
      Isolate.run(() {
        var im = img.Image.fromBytes(
            width: px.width,
            height: px.height,
            bytes: px.bgra.buffer,
            numChannels: 4,
            order: img.ChannelOrder.bgra);
        if (left != 0 || top != 0 || width != null || height != null) {
          im = img.copyCrop(im,
              x: left,
              y: top,
              width: width ?? px.width - left,
              height: height ?? px.height - top);
        }
        return img.encodePng(im);
      });
}

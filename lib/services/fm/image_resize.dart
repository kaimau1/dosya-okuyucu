import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../models/media_resize.dart';
import 'file_ops.dart';

/// Boyut düşürme sonucu (önce/sonra ölçüleri kullanıcıya yazılır).
class ResizeResult {
  final String sourcePath;
  final String outputPath;
  final int beforeBytes;
  final int afterBytes;
  final int width;
  final int height;

  const ResizeResult({
    required this.sourcePath,
    required this.outputPath,
    required this.beforeBytes,
    required this.afterBytes,
    required this.width,
    required this.height,
  });

  int get savedBytes => beforeBytes - afterBytes;
}

/// **Fotoğraf boyut düşürme / format çevirme** — saf Dart (`image` paketi).
///
/// Neden saf Dart: kullanıcı tek tek ya da onlarca fotoğrafı küçültür,
/// binlerce değil; native bir eklenti eklemek CI'daki derleme zincirini
/// (HAFIZA'daki sürüm cehennemi) riske atmaya değmez. Çözme/yazma
/// `Isolate.run` içinde: 12 MP bir JPEG'i ana izlekte çözmek arayüzü
/// yarım saniye dondurur.
///
/// **Özgün dosya varsayılan olarak korunur** ve çıktı aynı klasöre
/// `ad_720p.jpg` gibi yazılır: boyut düşürmek geri alınamaz, "üzerine yaz"
/// kullanıcının açık tercihi olmalı.
abstract final class ImageResizer {
  /// Tek dosyayı küçültür. Çözülemeyen/desteklenmeyen dosyada hata atar.
  static Future<ResizeResult> run(
    String path,
    MediaResizeOptions options,
  ) async {
    final before = File(path).lengthSync();
    final ext = options.imageFormat.extension ??
        (p.extension(path).replaceFirst('.', '').toLowerCase());
    final base = p.basenameWithoutExtension(path);
    final target = FileOps.uniquePath(
      p.join(p.dirname(path), '${base}_${options.suffix}.$ext'),
    );

    final result = await _runInIsolate(_ResizeArgs(
      sourcePath: path,
      outputPath: target,
      options: options,
    ));

    return ResizeResult(
      sourcePath: path,
      outputPath: target,
      beforeBytes: before,
      afterBytes: File(target).existsSync() ? File(target).lengthSync() : 0,
      width: result.width,
      height: result.height,
    );
  }

  /// Gemini'ye gönderilecek **küçük önizleme** üretir (dosyaya yazmadan).
  ///
  /// Niye: karşılaştırma için 5 MB'lık özgün fotoğrafı yüklemek hem yavaş hem
  /// pahalı; 768 pikselde model "bunlar aynı sahne mi" sorusunu rahatlıkla
  /// yanıtlıyor. Çözülemezse null.
  static Future<Uint8List?> previewJpeg(String path, {int maxEdge = 768}) async {
    try {
      return await Isolate.run(() => _previewSync(path, maxEdge));
    } catch (_) {
      try {
        return _previewSync(path, maxEdge);
      } catch (_) {
        return null;
      }
    }
  }

  static Future<({int width, int height})> _runInIsolate(
      _ResizeArgs args) async {
    try {
      return await Isolate.run(() => _resizeSync(args));
    } catch (e) {
      // İzolat kurulamadıysa (bazı test/masaüstü ortamları) ana izlekte koş:
      // yavaş ama "hiç çalışmıyor"dan iyidir.
      if (e is _ResizeFailure) rethrow;
      return _resizeSync(args);
    }
  }

  static Uint8List? _previewSync(String path, int maxEdge) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) return null;
    final longEdge =
        decoded.width > decoded.height ? decoded.width : decoded.height;
    final resized = longEdge <= maxEdge
        ? decoded
        : img.copyResize(
            decoded,
            width: decoded.width >= decoded.height ? maxEdge : null,
            height: decoded.height > decoded.width ? maxEdge : null,
            interpolation: img.Interpolation.average,
          );
    return Uint8List.fromList(img.encodeJpg(resized, quality: 75));
  }

  static ({int width, int height}) _resizeSync(_ResizeArgs args) {
    final bytes = File(args.sourcePath).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw _ResizeFailure('Görüntü çözülemedi: '
          '${p.basename(args.sourcePath)}');
    }
    final size = targetSize(
      sourceWidth: decoded.width,
      sourceHeight: decoded.height,
      options: args.options,
    );
    final resized = (size.width == decoded.width &&
            size.height == decoded.height)
        ? decoded
        : img.copyResize(
            decoded,
            width: size.width,
            height: size.height,
            // average: küçültmede en temiz sonuç (nearest tırtıklı,
            // cubic küçültmede halo üretir).
            interpolation: img.Interpolation.average,
          );

    final ext = p.extension(args.outputPath).replaceFirst('.', '').toLowerCase();
    final List<int> encoded = switch (ext) {
      'png' => img.encodePng(resized),
      'bmp' => img.encodeBmp(resized),
      'tga' => img.encodeTga(resized),
      // jpg/jpeg ve tanımadığımız her şey JPEG olarak yazılır: kalite
      // ayarının anlamı olan tek yaygın biçim.
      _ => img.encodeJpg(resized, quality: args.options.imageQuality),
    };
    File(args.outputPath).writeAsBytesSync(encoded, flush: true);
    return (width: resized.width, height: resized.height);
  }
}

class _ResizeArgs {
  final String sourcePath;
  final String outputPath;
  final MediaResizeOptions options;
  const _ResizeArgs({
    required this.sourcePath,
    required this.outputPath,
    required this.options,
  });
}

class _ResizeFailure implements Exception {
  final String message;
  const _ResizeFailure(this.message);
  @override
  String toString() => message;
}

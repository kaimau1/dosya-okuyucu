import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../models/media_resize.dart';
import 'file_ops.dart';

/// Boyut düşürme sonucu.
class ResizeResult {
  final String sourcePath;
  final String outputPath;
  final int beforeBytes;
  final int afterBytes;

  /// Çıktının **gerçek** ölçüsü; ölçülemediyse null.
  ///
  /// Nullable olması bilinçli: yedek video motoru (MediaCodec kademesi) istenen
  /// ölçüyü değil kendi kademesini uygular ve ne ürettiğini söylemez. Burada
  /// eskiden KAYNAĞIN ölçüsü yazılıydı — yani alan "çıktı 1920x1080" diyorken
  /// dosya 1280x720 olabiliyordu. Uydurmak yerine "bilmiyorum" diyoruz.
  final int? width;
  final int? height;

  const ResizeResult({
    required this.sourcePath,
    required this.outputPath,
    required this.beforeBytes,
    required this.afterBytes,
    this.width,
    this.height,
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
    final ext = options.imageFormat.extension ?? keepExtension(path);
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

  /// "Aynı kalsın" seçilince çıktının uzantısı ne olmalı?
  ///
  /// [encodableExtensions] dışındaki her uzantı `jpg`'ye düşürülür. Sebep
  /// [_resizeSync]: gerçekten yazabildiğimiz biçimler bunlar; kaynağın
  /// uzantısını körü körüne korumak `.webp` / `.gif` / `.heic` adlı ama İÇİ
  /// JPEG olan dosyalar üretiyordu (2026-07-29 sadakat denetimi). Böyle bir
  /// dosya galeride açılmaz, paylaşımda "bozuk" görünür ve kullanıcı özgününü
  /// çöpe attıysa (Özgün dosyayı çöp kutusuna at) kaybı geri alması güçtür.
  /// Uzantısız kaynakta (ör. WhatsApp'ın bazı geçici dosyaları) da `jpg`:
  /// "foto_720p." adlı bir dosya hiçbir uygulamada açılmaz.
  static String keepExtension(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return encodableExtensions.contains(ext) ? ext : 'jpg';
  }

  /// `image` paketiyle **yazabildiğimiz** uzantılar ([_resizeSync]'teki switch
  /// ile birebir aynı küme olmalı).
  static const Set<String> encodableExtensions = {
    'jpg',
    'jpeg',
    'png',
    'bmp',
    'tga',
  };

  /// Kaynak **birden çok kare/sayfa/katman** taşıyabilen bir biçim mi?
  ///
  /// `image` paketinin `decodeImage`i animasyondan yalnız İLK kareyi çözer,
  /// `encodeJpg`/`encodePng` de tek kare yazar. Yani hareketli bir GIF'i, çok
  /// sayfalı bir TIFF'i ya da katmanlı bir PSD'yi "küçültmek" onu tek bir
  /// duruk kareye indirmek demek — ve çıktı çok küçük olduğu için işlem
  /// "başarılı" sayılıp **"Özgün dosyayı çöp kutusuna at" açıkken animasyon
  /// çöpe gidiyordu** (2026-07-29 sadakat denetimi, 2. tur).
  ///
  /// Bu yüzden dönüştürme yapılır ama [ResizeAction.replaceOriginal] uygulanmaz
  /// ve kullanıcıya söylenir: duruk bir `.webp`/`.tif` küçültmek isteyen
  /// kullanıcının yolu kapanmasın, hareketli olan da kaybolmasın.
  static bool mayLoseFrames(String path) {
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return const {'gif', 'apng', 'webp', 'tif', 'tiff', 'psd', 'xcf'}
        .contains(ext);
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
    // Yazma YARIDA kalırsa (depolama doldu, SAF izni geri alındı) kullanıcının
    // albümünde 0 baytlık bir "IMG_0031_720p.jpg" kalıyordu: galeride bozuk
    // küçük resim, iş özetinde yalnız "küçültülemedi" (2026-07-29 sadakat
    // denetimi, 2. tur). Hata anında yarım dosya silinir.
    final out = File(args.outputPath);
    try {
      out.writeAsBytesSync(encoded, flush: true);
    } catch (_) {
      try {
        if (out.existsSync()) out.deleteSync();
      } catch (_) {}
      rethrow;
    }
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

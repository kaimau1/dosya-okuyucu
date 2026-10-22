import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import '../../models/media_resize.dart';
import 'exif_reader.dart';
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
    final ext = outputExtension(path, options);
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

  /// Çıktının uzantısı. **Dosya boyutu hedefi** hep JPEG: kalite ayarı olan
  /// tek yazabildiğimiz biçim — PNG'de "en çok 200 KB" kaliteyle değil ancak
  /// ölçüyle tutturulabilir, çoğu zaman da tutmaz (levha bunu söylüyor).
  static String outputExtension(String path, MediaResizeOptions options) {
    if (options.resolution == ResolutionChoice.fileSize) return 'jpg';
    return options.imageFormat.extension ?? keepExtension(path);
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

  /// Fotoğrafın ölçüsü — dosyanın yalnız **başlığı** okunur.
  ///
  /// Niye başlık: 12 MP bir JPEG'i tümüyle çözmek yarım saniye sürer; ayar
  /// sayfası beş dosya için bunu yapamaz. Ölçü, JPEG'de SOF işaretçisinde,
  /// PNG'de 16. bayttadır — ikisi de ilk kilobaytlarda. Okunamazsa null
  /// (uydurma ölçü, uydurma tahmin demek olurdu).
  static Future<({int width, int height})?> probeSize(String path) async {
    try {
      final file = File(path);
      final length = await file.length();
      final head = await file.openRead(0, length < _headBytes ? length : _headBytes)
          .fold<List<int>>(<int>[], (a, b) => a..addAll(b));
      final bytes = Uint8List.fromList(head);
      final decoder = img.findDecoderForData(bytes);
      if (decoder == null) return null;
      final info = decoder.startDecode(bytes);
      if (info == null || info.width <= 0 || info.height <= 0) return null;
      // **Görünen yön** (Faz 10b, B11): telefonun dikey fotoğrafı yatay
      // pikselle + EXIF Orientation 6/8 yazılır. Çözücü yönü uyguladığı için
      // ÇIKTI doğruydu, ama bu başlık ölçüsü ham kalıyordu → ayar sayfası
      // dikey fotoğrafa "4000×3000" diyor, "sonra" tahmini yan çıkıyordu.
      final o = ExifReader.parse(bytes).orientation ?? 1;
      if (o >= 5 && o <= 8) return (width: info.height, height: info.width);
      return (width: info.width, height: info.height);
    } catch (_) {
      return null;
    }
  }

  /// Ölçü ararken okunacak baş kısım (256 KB) — JPEG'in SOF işaretçisi çok
  /// büyük EXIF önizlemelerinde birkaç on kilobayta kadar geri kalabiliyor.
  static const int _headBytes = 256 * 1024;

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
    // `decodeImage` EXIF yönünü UYGULAR (Faz 10b piksel testi) → ölçüler
    // görünen yönde.
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw _ResizeFailure('Görüntü çözülemedi: '
          '${p.basename(args.sourcePath)}');
    }
    final ext = p.extension(args.outputPath).replaceFirst('.', '').toLowerCase();
    final options = args.options;
    final List<int> encoded;
    final img.Image out;
    if (options.resolution == ResolutionChoice.fileSize) {
      final r = fitToBytes(decoded, options.targetKb * 1024);
      encoded = r.bytes;
      out = r.image;
    } else {
      out = render(decoded, options, alpha: ext == 'png' || ext == 'tga');
      encoded = switch (ext) {
        'png' => img.encodePng(out),
        'bmp' => img.encodeBmp(out),
        'tga' => img.encodeTga(out),
        // jpg/jpeg ve tanımadığımız her şey JPEG olarak yazılır: kalite
        // ayarının anlamı olan tek yaygın biçim.
        _ => img.encodeJpg(out, quality: options.imageQuality),
      };
    }
    // Yazma YARIDA kalırsa (depolama doldu, SAF izni geri alındı) kullanıcının
    // albümünde 0 baytlık bir "IMG_0031_720p.jpg" kalıyordu: galeride bozuk
    // küçük resim, iş özetinde yalnız "küçültülemedi" (2026-07-29 sadakat
    // denetimi, 2. tur). Hata anında yarım dosya silinir.
    final file = File(args.outputPath);
    try {
      file.writeAsBytesSync(encoded, flush: true);
    } catch (_) {
      try {
        if (file.existsSync()) file.deleteSync();
      } catch (_) {}
      rethrow;
    }
    return (width: out.width, height: out.height);
  }

  /// Ayarlara göre çıktı görüntüsü (saf; testler doğrudan çağırır).
  ///
  /// [alpha]: çıktı biçimi saydamlık taşıyabiliyor mu (PNG/TGA) — saydam kenar
  /// boşluğu JPEG'de beyaza düşer.
  static img.Image render(img.Image src, MediaResizeOptions options,
      {bool alpha = false}) {
    final size = targetSize(
      sourceWidth: src.width,
      sourceHeight: src.height,
      options: options,
      video: false,
    );
    final aspect = options.resolution == ResolutionChoice.aspect;
    final fit = aspect
        ? (options.fit == ResizeFit.pad ? ResizeFit.pad : ResizeFit.cover)
        : (options.resolution == ResolutionChoice.custom &&
                options.customWidth != null &&
                options.customHeight != null)
            ? options.effectiveFit
            : ResizeFit.stretch; // hedef zaten oranlı — düz ölçekle
    switch (fit) {
      case ResizeFit.cover:
        // Kutuyu dolduracak ölçek, sonra ortadan kırp.
        final scale = _max(size.width / src.width, size.height / src.height);
        final scaled = aspect && scale == 1 ? src : _scale(src, scale);
        final x = ((scaled.width - size.width) / 2).round();
        final y = ((scaled.height - size.height) / 2).round();
        return img.copyCrop(scaled,
            x: x < 0 ? 0 : x,
            y: y < 0 ? 0 : y,
            width: size.width,
            height: size.height);
      case ResizeFit.pad:
        final scale = aspect
            ? 1.0
            : _min(size.width / src.width, size.height / src.height);
        final inner = scale == 1 ? src : _scale(src, scale);
        final canvas = _padCanvas(src, size.width, size.height,
            options.padColor, alpha: alpha);
        img.compositeImage(canvas, inner,
            dstX: ((size.width - inner.width) / 2).round(),
            dstY: ((size.height - inner.height) / 2).round());
        return canvas;
      case ResizeFit.contain:
      case ResizeFit.stretch:
        if (size.width == src.width && size.height == src.height) return src;
        return img.copyResize(
          src,
          width: size.width,
          height: size.height,
          // average: küçültmede en temiz sonuç (nearest tırtıklı, cubic
          // küçültmede halo üretir); büyütmede (K14) cubic.
          interpolation: size.width > src.width
              ? img.Interpolation.cubic
              : img.Interpolation.average,
        );
    }
  }

  static double _max(double a, double b) => a > b ? a : b;
  static double _min(double a, double b) => a < b ? a : b;

  static img.Image _scale(img.Image src, double scale) => img.copyResize(
        src,
        width: (src.width * scale).round().clamp(1, 1 << 15),
        height: (src.height * scale).round().clamp(1, 1 << 15),
        interpolation:
            scale > 1 ? img.Interpolation.cubic : img.Interpolation.average,
      );

  /// Kenar boşluğu zemini. **Bulanık:** görüntünün kendisi kutuyu dolduracak
  /// kadar büyütülüp bulanıklaştırılır (Instagram'ın "sığdır" zemini) —
  /// beyaz/siyah şeritten daha az göze batar.
  static img.Image _padCanvas(
      img.Image src, int w, int h, PadColor color, {required bool alpha}) {
    switch (color) {
      case PadColor.blur:
        final scale = _max(w / src.width, h / src.height);
        // Bulanıklık küçük kopyada yapılır (hız), sonra büyütülür.
        final small = _scale(src, scale * 0.25);
        final shortSide = math.min(small.width, small.height);
        final blurred = img.gaussianBlur(small,
            radius: (shortSide / 4).round().clamp(1, 6));
        final big = img.copyResize(blurred,
            width: (blurred.width / 0.25).round(),
            height: (blurred.height / 0.25).round());
        return img.copyCrop(big,
            x: ((big.width - w) / 2).round().clamp(0, big.width),
            y: ((big.height - h) / 2).round().clamp(0, big.height),
            width: w,
            height: h);
      case PadColor.transparent when alpha:
        return img.Image(width: w, height: h, numChannels: 4);
      case PadColor.black:
        return img.Image(width: w, height: h)
          ..clear(img.ColorRgb8(0, 0, 0));
      case PadColor.white:
      case PadColor.transparent: // JPEG saydamlık taşımaz → beyaz
        return img.Image(width: w, height: h)
          ..clear(img.ColorRgb8(255, 255, 255));
    }
  }

  /// **Dosya boyutu hedefi** (Faz 14, G4e): JPEG kalitesinde ikili arama
  /// (95 → 40); en düşük kalite de sığmazsa ölçek küçültülüp yeniden aranır.
  /// En çok [maxEncodes] kodlama — 12 MP'de her biri ~0,3 sn. Hedefe
  /// ulaşılamazsa **en küçük** sonuç döner; çağıran gerçek boyutu raporlar
  /// ("en yakın 230 KB") — sessizce hedefi aşmış gibi davranmaz.
  static ({List<int> bytes, img.Image image, int quality}) fitToBytes(
      img.Image src, int targetBytes,
      {int maxEncodes = 8}) {
    var encodes = 0;
    ({List<int> bytes, img.Image image, int quality})? best; // sığan en iyi
    ({List<int> bytes, img.Image image, int quality})? smallest;
    List<int> enc(img.Image im, int q) {
      encodes++;
      final b = img.encodeJpg(im, quality: q);
      if (smallest == null || b.length < smallest!.bytes.length) {
        smallest = (bytes: b, image: im, quality: q);
      }
      return b;
    }

    var image = src;
    while (encodes < maxEncodes) {
      final top = enc(image, 95);
      if (top.length <= targetBytes) {
        return (bytes: top, image: image, quality: 95);
      }
      if (encodes >= maxEncodes) break;
      final floor = enc(image, 40);
      if (floor.length <= targetBytes) {
        // 40 sığıyor, 95 sığmıyor → aradaki en yüksek sığan kalite.
        best = (bytes: floor, image: image, quality: 40);
        var lo = 40, hi = 95;
        while (hi - lo > 5 && encodes < maxEncodes) {
          final mid = (lo + hi) ~/ 2;
          final b = enc(image, mid);
          if (b.length <= targetBytes) {
            lo = mid;
            best = (bytes: b, image: image, quality: mid);
          } else {
            hi = mid;
          }
        }
        return best!;
      }
      // En düşük kalite bile büyük → ölçeği oranla küçült (alan ∝ bayt),
      // %8 pay bırakarak; en az %15 küçült ki döngü ilerlesin.
      final ratio = targetBytes / floor.length;
      var scale = (ratio > 0 ? math.sqrt(ratio) : 0.5) * 0.92;
      if (scale > 0.85) scale = 0.85;
      // 16 px altına inilmez (hedef saçma küçükse en küçük makul sonuç).
      final floorScale = 16 / math.min(image.width, image.height);
      if (scale < floorScale) scale = floorScale;
      if (scale >= 0.99) break;
      image = _scale(image, scale);
    }
    return best ?? smallest!;
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

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// Dosyadan görüntü sağlayıcı — baytları **Dart yığınına almadan** çözer.
///
/// ## Niye yazıldı (2026-08-17 kullanıcı bulgusu)
/// *"görüntüler sayfasına yüklenme sorunu, donma ve görülmeme sorunları
/// oluyor"* — 6476 fotoğraflı bir galeride ızgara boş kutularla açılıyor,
/// kaydırma takılıyordu.
///
/// Kök neden Flutter'ın kendi [FileImage]'ında: dosyayı `readAsBytes()` ile
/// okuyor, yani **her karenin tam boyutlu JPEG'i (6-8 MB) önce Dart yığınına**
/// kopyalanıyor, sonra çözücüye veriliyor. Ekranda 40 hücre varsa bu tek
/// kaydırmada ~300 MB'lık geçici ayırma demek: çöp toplayıcı sürekli koşuyor,
/// ana izlek duruyor (donma) ve bellek baskısı altında bazı çözümler hiç
/// tamamlanmıyor (boş kalan hücreler).
///
/// [ui.ImmutableBuffer.fromFilePath] aynı dosyayı **motorun kendi belleğine**
/// okur: Dart yığınına tek bayt girmez, çözme de motorun iş parçacığında
/// hedef ölçüde yapılır. Küçük resim ne kadar küçükse o kadar az iş.
///
/// Davranış [FileImage] ile birebir aynıdır (aynı anahtar mantığı, aynı hata
/// yolu) — dosya yoksa/bozuksa akış hata verir ve çağıranın `errorBuilder`'ı
/// devreye girer (`FmEntryIcon` orada `FsEvents.reportUnreadable` çağırıyor).
@immutable
class FmFileImage extends ImageProvider<FmFileImage> {
  final String path;

  /// Çözme genişliği (piksel). Kaynak daha genişse motor **çözerken** küçültür.
  final int? cacheWidth;

  final double scale;

  /// Kare hücre (`BoxFit.cover`) için: [cacheWidth] GENİŞLİĞİ değil KISA
  /// KENARI sınırlar. Yalnız genişlik sınırlanınca yatay fotoğrafın yüksekliği
  /// hücrenin altına düşüyor, `cover` onu yeniden büyütüp bulanıklaştırıyordu
  /// (kullanıcı 2026-11-04: *"görsellerde ön izlemeler çok kalitesiz"*).
  final bool cover;

  const FmFileImage(this.path,
      {this.cacheWidth, this.scale = 1.0, this.cover = false});

  @override
  Future<FmFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<FmFileImage>(this);

  @override
  ImageStreamCompleter loadImage(FmFileImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: key.scale,
      debugLabel: key.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${key.path}'),
      ],
    );
  }

  Future<ui.Codec> _load(FmFileImage key, ImageDecoderCallback decode) async {
    final buffer = await ui.ImmutableBuffer.fromFilePath(key.path);
    final target = key.cacheWidth;
    return decode(
      buffer,
      // En-boy oranı korunur: yalnız genişlik verilir, yükseklik ondan türer.
      // Kaynak zaten daha darsa BÜYÜTÜLMEZ — bulanık bir küçük resim
      // üretmenin anlamı yok, üstelik bellekte de daha çok yer tutardı.
      // G7.7: her durumda piksel tavanı ([fmPixelCap]) — yalnız genişlik
      // sınırı 1000×1.000.000'luk bir "bomba" görselde işe yaramaz.
      getTargetSize: (int width, int height) {
        final ui.TargetImageSize size;
        if (target == null) {
          size = ui.TargetImageSize(width: width, height: height);
        } else if (key.cover) {
          size = fmCoverTargetSize(width, height, target);
        } else if (width <= target) {
          size = ui.TargetImageSize(width: width, height: height);
        } else {
          size = ui.TargetImageSize(
            width: target,
            height: (height * target / width).round().clamp(1, height),
          );
        }
        return fmPixelCap(size.width ?? width, size.height ?? height);
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FmFileImage &&
      other.path == path &&
      other.cacheWidth == cacheWidth &&
      other.scale == scale &&
      other.cover == cover;

  @override
  int get hashCode => Object.hash(path, cacheWidth, scale, cover);

  @override
  String toString() =>
      'FmFileImage("$path", cacheWidth: $cacheWidth${cover ? ', cover' : ''})';
}

/// G7.7 (2026-11-12): çözülen bitmap'in en çok piksel sayısı. 24 MP ≈ 96 MB;
/// 3072×2304 (görüntüleyici tavanı, 7 MP) ve 1080×20000'lik uzun ekran
/// görüntüsü sığar, 100 MP+ bellek bombası en-boy korunarak küçülür.
const fmMaxDecodePixels = 24 * 1000 * 1000;

/// [width]×[height] tavanı aşarsa iki kenar aynı oranla küçültülür (saf, testli).
ui.TargetImageSize fmPixelCap(int width, int height,
    {int maxPixels = fmMaxDecodePixels}) {
  // TargetImageSize 0/eksi ölçüyü assert ile reddeder → kaynağın ölçüsü.
  if (width <= 0 || height <= 0) return const ui.TargetImageSize();
  final pixels = width * height;
  if (pixels <= maxPixels) {
    return ui.TargetImageSize(width: width, height: height);
  }
  final k = math.sqrt(maxPixels / pixels);
  return ui.TargetImageSize(
    width: (width * k).floor().clamp(1, width),
    height: (height * k).floor().clamp(1, height),
  );
}

/// `cover` çözme ölçüsü (saf, testli): kısa kenar [target]'a iner, en-boy
/// korunur; kaynak zaten küçükse büyütülmez.
ui.TargetImageSize fmCoverTargetSize(int width, int height, int target) {
  final shortSide = width < height ? width : height;
  if (shortSide <= target || shortSide <= 0) {
    return ui.TargetImageSize(width: width, height: height);
  }
  final scale = target / shortSide;
  return ui.TargetImageSize(
    width: (width * scale).round().clamp(1, width),
    height: (height * scale).round().clamp(1, height),
  );
}

/// Küçük resim çözme genişlikleri (piksel), kademeli (2026-09-26).
///
/// Eskiden her hücre `hücre × 3` genişlikte çözülüyordu: 3 sütunda 392, 4
/// sütunda 294 … her ölçü önbellekte AYRI kayıt. Kademeye yuvarlamanın iki
/// kazancı var: (1) aynı fotoğraf liste satırında ve ızgarada aynı kaydı
/// paylaşır, (2) görüntüleyici ızgaranın çözdüğü küçük resmi önbellekte
/// **bulabilir** ([fmCachedThumb]) ve ilk kareyi anında onunla çizer.
const fmThumbBuckets = <int>[96, 128, 192, 256, 320, 384, 448, 512, 640, 768];

/// [logicalSize] dp'lik bir kutu için çözme genişliği ([devicePixelRatio]
/// yoğunluğunda), bir üst kademeye yuvarlanmış.
int fmThumbWidth(double logicalSize, double devicePixelRatio) {
  final ratio = devicePixelRatio.isFinite && devicePixelRatio > 0
      ? devicePixelRatio
      : 3.0;
  final want = (logicalSize * ratio).ceil();
  for (final b in fmThumbBuckets) {
    if (b >= want) return b;
  }
  return fmThumbBuckets.last;
}

/// [path]'in önbellekte (çözülmüş ya da çözülmekte) duran EN BÜYÜK küçük
/// resmi; yoksa null. Yeni çözme BAŞLATMAZ — yalnız bakar.
FmFileImage? fmCachedThumb(String path) {
  final cache = PaintingBinding.instance.imageCache;
  for (final b in fmThumbBuckets.reversed) {
    for (final cover in const [true, false]) {
      final provider = FmFileImage(path, cacheWidth: b, cover: cover);
      if (cache.statusForKey(provider).tracked) return provider;
    }
  }
  // Izgara özgünü değil, küçük resim DOSYASINI çözmüş olabilir (2026-11-03).
  final alias = _thumbAliases[path];
  if (alias != null && cache.statusForKey(alias).tracked) return alias;
  return null;
}

/// Özgün yol → ızgaranın gösterdiği küçük resim sağlayıcısı (galeri açılırken
/// ilk kareyi anında çizebilsin).
final Map<String, FmFileImage> _thumbAliases = {};

void fmRememberThumb(String path, FmFileImage provider) {
  // ponytail: kaba tavan; önbellek zaten ~300 görsel tutuyor.
  if (_thumbAliases.length > 2000) _thumbAliases.clear();
  _thumbAliases[path] = provider;
}

/// Önbellekte TAMAMLANMIŞ görselin en-boy oranı (genişlik / yükseklik);
/// henüz çözülmüyorsa ya da çözülüyorsa null. Eşzamanlıdır: tamamlanmış
/// kayıt dinleyiciye aynı çağrı içinde verilir.
double? fmCachedAspect(ImageProvider<Object> provider) {
  double? aspect;
  final stream = provider.resolve(ImageConfiguration.empty);
  final listener = ImageStreamListener((info, _) {
    final w = info.image.width;
    final h = info.image.height;
    info.dispose();
    if (w > 0 && h > 0) aspect = w / h;
  }, onError: (_, _) {});
  stream.addListener(listener);
  stream.removeListener(listener);
  return aspect;
}

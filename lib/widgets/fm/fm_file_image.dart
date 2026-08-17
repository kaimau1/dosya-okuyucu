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

  const FmFileImage(this.path, {this.cacheWidth, this.scale = 1.0});

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
    if (target == null) return decode(buffer);
    return decode(
      buffer,
      // En-boy oranı korunur: yalnız genişlik verilir, yükseklik ondan türer.
      // Kaynak zaten daha darsa BÜYÜTÜLMEZ — bulanık bir küçük resim
      // üretmenin anlamı yok, üstelik bellekte de daha çok yer tutardı.
      getTargetSize: (int width, int height) {
        if (width <= target) return ui.TargetImageSize(width: width, height: height);
        return ui.TargetImageSize(
          width: target,
          height: (height * target / width).round().clamp(1, height),
        );
      },
    );
  }

  @override
  bool operator ==(Object other) =>
      other is FmFileImage &&
      other.path == path &&
      other.cacheWidth == cacheWidth &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(path, cacheWidth, scale);

  @override
  String toString() => 'FmFileImage("$path", cacheWidth: $cacheWidth)';
}

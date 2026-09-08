import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

import 'file_ops.dart';
import 'fs_events.dart';

/// **Görseli döndür ve kaydet.**
///
/// ## Niye (2026-09-06 denetim turu)
/// Galeri ekranı fotoğrafı yakınlaştırıyor, kaydırıyor, paylaşıyor — ama yan
/// çekilmiş bir fotoğrafı **düzeltemiyordu**. Telefonla çekilen yatay
/// fotoğrafların bir kısmı (özellikle WhatsApp'tan gelenler, EXIF yönelimi
/// silinmiş olanlar) yan görünüyor ve kullanıcının yapabildiği tek şey başka
/// bir uygulama aramaktı. Boyut düşürme zaten `image` paketiyle yapılıyor;
/// döndürme aynı paketin tek satırı.
///
/// ## Kayıpsız değil — ve bu ekranda yazıyor
/// JPEG yeniden kodlanıyor (kalite 92). Gerçek kayıpsız döndürme (jpegtran
/// gibi blok döndürme) bu pakette yok; %92 kalite gözle ayırt edilmeyen ama
/// dürüst olarak "yeniden kaydedildi" demek gereken bir sonuç veriyor.
/// PNG/BMP zaten kayıpsız.
///
/// **Üzerine yazmak seçime bağlı.** Varsayılan: yanına yeni dosya
/// (`foto (1).jpg`). Kullanıcı özgün dosyayı kaybetmemeli — bir döndürme
/// yanlış yöne gittiğinde geri dönüşü olmalı.
abstract final class ImageRotate {
  /// Bu uzantılar döndürülebiliyor. Liste `image` paketinin kodlayıcı
  /// desteğiyle sınırlı: çözebildiğimiz ama YAZAMADIĞIMIZ bir biçimi
  /// (ör. HEIC) döndürmek, dosyayı sessizce başka bir biçime çevirmek olurdu.
  static const supported = {'jpg', 'jpeg', 'png', 'bmp', 'tga'};

  static bool canRotate(String path) =>
      supported.contains(p.extension(path).replaceFirst('.', '').toLowerCase());

  /// [path]'i saat yönünde [quarterTurns] × 90° döndürür.
  ///
  /// [overwrite] açıkken aynı dosyaya yazılır; kapalıyken yanına yeni bir ad
  /// üretilir. Yazılan dosyanın yolu döner.
  ///
  /// Döndürme ve kodlama **ayrı bir isolate'te**: 48 MP bir fotoğrafta bu iş
  /// saniyeler sürüyor ve ana izlekte yapılırsa arayüz donar (uygulamanın
  /// boyut düşürme tarafı aynı sebeple isolate kullanıyor).
  static Future<String> rotate(
    String path, {
    required int quarterTurns,
    bool overwrite = false,
  }) async {
    final turns = ((quarterTurns % 4) + 4) % 4;
    if (turns == 0) return path;
    if (!canRotate(path)) {
      throw UnsupportedError('Bu biçim döndürülemiyor: ${p.extension(path)}');
    }
    final target = overwrite ? path : FileOps.uniquePath(path);
    final bytes = await Isolate.run(() => _rotateSync(path, turns));
    // Yazma isolate DIŞINDA: hedef yolu ana izlek belirliyor ve `uniquePath`
    // diske bakıyor; iki yerde iki kez karar vermek yarış üretirdi.
    await File(target).writeAsBytes(bytes, flush: true);
    FsEvents.changed();
    return target;
  }

  /// EXIF yönelim kodunun (1..8) karşılık geldiği çeyrek dönüş sayısı.
  ///
  /// Galeri fotoğrafı zaten yönelime göre çeviriyor; kullanıcı "düzelt"
  /// dediğinde asıl istediği, **çevrilmiş hâlin dosyaya işlenmesi**.
  static int turnsForOrientation(int? orientation) => switch (orientation) {
        3 || 4 => 2,
        5 || 6 => 1,
        7 || 8 => 3,
        _ => 0,
      };

  static Uint8List _rotateSync(String path, int turns) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) {
      throw const FormatException('Görsel çözümlenemedi');
    }
    final rotated = img.copyRotate(decoded, angle: turns * 90);
    final ext = p.extension(path).replaceFirst('.', '').toLowerCase();
    return switch (ext) {
      'png' => img.encodePng(rotated),
      'bmp' => img.encodeBmp(rotated),
      'tga' => img.encodeTga(rotated),
      // 92: gözle ayırt edilmeyen ama dosyayı gereksiz şişirmeyen kalite.
      _ => img.encodeJpg(rotated, quality: 92),
    };
  }
}

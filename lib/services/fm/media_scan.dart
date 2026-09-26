import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart';

/// **Galeriye haber ver** — Android 10 ve öncesinde MediaStore taraması.
///
/// Kullanıcı 2026-09-26 (harici bellek değerlendirmesinin önerisi): Android
/// 11+'da dosya yoluyla yapılan yazmaları MediaStore kendisi görüyor (FUSE
/// katmanı her oluştur/sil/yeniden adlandır işlemini veritabanına işliyor).
/// Android 10 ve öncesinde görmüyor: uygulamada kopyalanan fotoğraf Galeri'de
/// çıkmıyor, silinen ya da taşınan dosya Galeri'de boş kare olarak kalıyordu
/// (telefon yeniden başlayana kadar).
///
/// Yollar yerel tarafa olduğu gibi gider; **sürüm kontrolü ve klasör açma
/// yerel tarafta** (`ci/MainActivity.kt`, `mediaScan`): Android 11+'da çağrı
/// hiçbir şey yapmadan döner, yani yeni cihazlarda maliyeti tek bir kanal
/// mesajı. Masaüstünde / testte kanala hiç gidilmez.
abstract final class MediaScan {
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  /// Tek istekte gönderilecek en fazla yol (binlerce dosyalık bir klasör
  /// taşımasında kanal mesajı şişmesin; klasörler yerel tarafta açılıyor).
  static const maxPaths = 500;

  /// Yalnız test için: istenen yolları yakalar (masaüstünde kanal yok).
  @visibleForTesting
  static void Function(List<String> paths)? debugOnRequest;

  static void request(Iterable<String> paths) {
    final list = paths.take(maxPaths).toList();
    if (list.isEmpty) return;
    debugOnRequest?.call(list);
    if (!Platform.isAndroid) return;
    unawaited(_channel
        .invokeMethod<void>('mediaScan', {'paths': list})
        .catchError((Object _) {}));
  }
}

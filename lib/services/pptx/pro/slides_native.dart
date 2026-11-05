import 'dart:async';

import 'package:flutter/services.dart';

/// **Faz 38 — slayt yerel köprüsü** (`ci/Slayt.kt`, kanal `dosya/slides`).
/// Video dışa aktarım, arka plan kaldırma, ses tuşu kumandası, anlatım kaydı
/// ve ikinci ekran. Kanal yoksa (test, eski APK) her çağrı null/false döner.
abstract final class SlidesNative {
  static const _ch = MethodChannel('dosya/slides');
  static final _events = StreamController<(String, Object?)>.broadcast();
  static bool _wired = false;

  /// Yerelden gelen olaylar: (`volume`, `next|prev`), (`screens`, sayı).
  static Stream<(String, Object?)> get events {
    if (!_wired) {
      _wired = true;
      _ch.setMethodCallHandler((call) async {
        _events.add((call.method, call.arguments));
        return null;
      });
    }
    return _events.stream;
  }

  static Future<T?> _call<T>(String m, [Map<String, Object?>? a]) async {
    try {
      return await _ch.invokeMethod<T>(m, a);
    } on MissingPluginException {
      return null;
    }
  }

  /// PNG'lerden MP4. Hata `PlatformException` olarak yükselir.
  static Future<String?> video(List<String> paths, List<int> durationsMs,
          String out, int width, int height) =>
      _call<String>('video', {
        'paths': paths,
        'durations': durationsMs,
        'out': out,
        'width': width,
        'height': height,
      });

  static Future<void> cancelVideo() => _call<bool>('cancelVideo');

  /// Arka planı kaldırılmış PNG yolu. Model inmemişse `PlatformException`
  /// kodu `downloading`.
  static Future<String?> removeBackground(String path, String out) =>
      _call<String>('removeBg', {'path': path, 'out': out});

  static Future<void> volumeKeys(bool on) => _call<bool>('volumeKeys', {'on': on});

  static Future<bool> recordStart(String out) async =>
      await _call<bool>('recStart', {'out': out}) ?? false;

  static Future<String?> recordStop() => _call<String>('recStop');

  static Future<int> screens() async => await _call<int>('screens') ?? 0;

  static Future<bool> screenShow(Uint8List png) async =>
      await _call<bool>('screenShow', {'png': png}) ?? false;

  static Future<void> screenHide() => _call<bool>('screenHide');
}

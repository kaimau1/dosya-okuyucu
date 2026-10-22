import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/services.dart';

/// **Resim içinde resim (PiP)** — Android'in kendi küçük pencere kipi
/// (Faz 10, K8: "yüzen oynatıcı → PiP").
///
/// Eskiden `ci/FloatingPlayer.kt` başka uygulamaların üstüne kendi penceresini
/// çiziyor ve videoyu ikinci bir oynatıcıda (MediaPlayer) sürüyordu: Play'in
/// en hassas izinlerinden `SYSTEM_ALERT_WINDOW` + 671 satır yerel kod + iki
/// oynatıcı arasında konum taşıma. PiP'te uygulamanın KENDİSİ küçülür; video
/// aynı oynatıcıda kesintisiz sürer, izin gerekmez.
///
/// Kanal yoksa (`flutter test`, eski Android) her çağrı zarifçe false döner.
abstract final class Pip {
  static const _channel = MethodChannel('dosya_okuyucu/pip');

  /// Uygulama şu an PiP penceresinde mi? Oynatıcı bunu dinleyip yalnız
  /// videoyu çizer (küçük pencerede düğmeler okunmaz).
  static final ValueNotifier<bool> active = ValueNotifier<bool>(false);

  static bool _wired = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'changed') active.value = call.arguments == true;
      return null;
    });
  }

  /// Cihaz PiP destekliyor mu (Android 8+, özellik açık)?
  static Future<bool> supported() async {
    try {
      return await _channel.invokeMethod<bool>('supported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Hemen küçük pencereye geç. [aspect] videonun en/boy oranı için.
  static Future<bool> enter(Size aspect) async {
    _wire();
    try {
      return await _channel.invokeMethod<bool>('enter', _ratio(aspect)) ??
          false;
    } catch (_) {
      return false;
    }
  }

  /// Video oynarken uygulamadan çıkılınca (ana ekran hareketi) kendiliğinden
  /// küçük pencereye geçilsin mi?
  static Future<void> setAuto(bool on, [Size aspect = const Size(16, 9)]) async {
    _wire();
    try {
      await _channel.invokeMethod<bool>('auto', {'on': on, ..._ratio(aspect)});
    } catch (_) {}
  }

  static Map<String, int> _ratio(Size s) => {
        'w': s.width <= 0 ? 16 : s.width.round(),
        'h': s.height <= 0 ? 9 : s.height.round(),
      };
}

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

/// Ekranın sönmesini engelleme (wakelock) — **tek kapı**.
///
/// **Niye var (KALANLAR maddesi, 2026-08-08'de kapandı):** uzun bir videoyu
/// izlerken kimse ekrana dokunmaz; Android'in ekran zaman aşımı devreye girip
/// filmi 30 saniyede karartıyordu. Kullanıcı her seferinde ekrana dokunmak
/// zorunda kalıyordu.
///
/// **Niye ayrı bir sarmalayıcı, niye doğrudan `WakelockPlus` değil:**
/// 1. **Pil.** Wakelock pil HARCAR — bir önceki tur pil kaçaklarını kapatmakla
///    geçti, buraya kontrolsüz bir kaçak açmak o işi geri alırdı. Kilit yalnız
///    [request] ile açıkça istenen sayıda "sahip" varken tutulur; sonuncusu
///    bırakınca serbest kalır. Ekrandan çıkmak, videoyu duraklatmak ve
///    uygulamanın arkaya alınması — üçü de bırakma sebebidir.
/// 2. **Sayaç şart.** Tek bir `enable/disable` çifti olsaydı, iç içe iki sahip
///    (oynatıcı + gelecekte sunum modu) varken biri bırakınca ekran ötekinin
///    altından sönerdi.
/// 3. **Test.** Eklenti platform kanalıdır; testte çağrılırsa `MissingPlugin`
///    atar. [debugOverride] ile kanal değiştirilebiliyor, böylece "kilit
///    gerçekten istendi mi" birim testle doğrulanabiliyor.
abstract final class ScreenAwake {
  static int _holders = 0;

  /// Yalnız test: gerçek eklenti yerine çağrıları buraya yönlendirir.
  @visibleForTesting
  static Future<void> Function(bool enable)? debugOverride;

  /// Şu an kilit tutuluyor mu (test ve tanılama için).
  static bool get isHeld => _holders > 0;

  /// Kaç sahip var (test için).
  @visibleForTesting
  static int get holders => _holders;

  /// Yalnız test: sayacı sıfırlar.
  @visibleForTesting
  static void debugReset() {
    _holders = 0;
    debugOverride = null;
  }

  /// Ekranı açık tutmayı ister. Dönen işlev kilidi BIRAKIR ve **birden çok kez
  /// çağrılsa da sayacı bir kez düşürür** — `dispose` ile duraklatma aynı anda
  /// bırakmaya çalışırsa sayaç eksiye düşmemeli.
  static VoidCallback request() {
    _holders++;
    if (_holders == 1) unawaited(_apply(true));
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holders--;
      if (_holders == 0) unawaited(_apply(false));
    };
  }

  static Future<void> _apply(bool enable) async {
    // `try` testteki yönlendirmeyi de KAPSAR: çağrı `unawaited` ile
    // başlatıldığı için buradan sızan bir hata yakalanmayan asenkron hata
    // olur — üretimde uygulamayı, testte ilgisiz bir testi kırardı.
    try {
      final override = debugOverride;
      if (override != null) {
        await override(enable);
        return;
      }
      await WakelockPlus.toggle(enable: enable);
    } catch (_) {
      // Desteklemeyen platform/ROM: ekran normal davranır, akış bloklanmaz.
    }
  }
}

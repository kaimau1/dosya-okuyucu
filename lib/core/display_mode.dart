import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/gestures.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Ekran tazeleme hızını tercihe göre kurar.
///
/// [high] true → 120 Hz+ ekranlarda Android'in 60 Hz kilidini açar (akıcılık).
/// false → en düşük moda döner: **GPU saniyede yarı kadar kare çizer**; uzun
/// belge okuma ve liste kaydırmada en gözle görülür pil kazancı budur.
///
/// [adaptive] (yalnız [high] açıkken; 2026-11-10, kullanıcı: *"dinamik
/// tazeleme hızı getirelim, pil tasarrufu için yerine göre 120, yerine göre
/// 60-30"*): ekran yalnız dokunma/kaydırma sürerken en yüksek moda çıkar,
/// [DynamicRefresh.idleDelay] boyunca hiç etkileşim olmazsa cihazın en düşük
/// moduna (ekrana göre 60, 48 ya da 30 Hz) iner. Okurken/bakarken ekran
/// kıpırdamadığı için düşük hız fark edilmez; kaydırma başladığı an 120'ye
/// döner.
///
/// **Niye tercihe bağlı (2026-08-07 pil denetimi):** açılışta koşulsuz
/// `setHighRefreshRate()` çağrılıyordu. Ayar `AppState.highRefreshRate` /
/// `AppState.dynamicRefresh` ve Ayarlar > Depolama ve başarım'da.
///
/// Desteklenmeyen cihaz/ROM'da (ve Android dışı platformlarda) sessizce
/// geçilir — akış asla bloklanmaz.
Future<void> applyRefreshRate(bool high, {bool adaptive = false}) =>
    DynamicRefresh.apply(high: high, adaptive: adaptive);

abstract final class DynamicRefresh {
  /// Son dokunuştan sonra düşük hıza inmeden önce beklenen süre. Savurma
  /// (fling) kaydırması parmak kalktıktan sonra ~1-2 sn sürer; 3 sn onu
  /// kesmeden bitirir.
  static const idleDelay = Duration(seconds: 3);

  static bool _dynamic = false;
  static bool? _applied; // true = yüksek mod kurulu
  static bool _routed = false;
  static Timer? _timer;
  static DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  static int _holds = 0;

  /// Hareketli içerik (video, otomatik kaydırma) sürerken dokunuş olmasa da
  /// yüksek hız korunur. Dönen işlev bırakır (birden çok çağrı güvenli).
  static void Function() hold() {
    _holds++;
    if (_dynamic && _applied != true) unawaited(_set(true));
    var released = false;
    return () {
      if (released) return;
      released = true;
      _holds--;
      if (_holds == 0 && _dynamic) _touch();
    };
  }

  /// Şu an dinamik kipte mi (test/teşhis için).
  static bool get isDynamic => _dynamic;

  /// Son kurulan mod: true yüksek, false düşük, null henüz kurulmadı.
  static bool? get applied => _applied;

  static Future<void> apply({required bool high, bool adaptive = false}) async {
    _dynamic = high && adaptive;
    _timer?.cancel();
    _timer = null;
    if (_dynamic) {
      _ensureRoute();
      // Açılışta/ayar değişiminde etkileşim sürüyor sayılır: hemen yüksek,
      // boşta kalınca düşer.
      _touch();
      return;
    }
    await _set(high);
  }

  static void _ensureRoute() {
    if (_routed) return;
    _routed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_onPointer);
  }

  static void _onPointer(PointerEvent e) {
    if (!_dynamic) return;
    if (e is PointerDownEvent ||
        e is PointerMoveEvent ||
        e is PointerSignalEvent ||
        e is PointerPanZoomUpdateEvent) {
      _touch();
    }
  }

  /// Etkileşim oldu: yüksek moda çık, boşta zamanlayıcısını ileri at.
  /// Hareket olayları saniyede 120 kez gelir; her birinde yeni Timer
  /// kurulmaz — zamanlayıcı dolunca son dokunuşa göre yeniden kurulur.
  static void _touch() {
    _last = DateTime.now();
    if (_applied != true) unawaited(_set(true));
    _timer ??= Timer(idleDelay, _onIdleCheck);
  }

  static void _onIdleCheck() {
    _timer = null;
    if (!_dynamic) return;
    final since = DateTime.now().difference(_last);
    if (_holds > 0) {
      _timer = Timer(idleDelay, _onIdleCheck);
    } else if (since >= idleDelay) {
      unawaited(_set(false));
    } else {
      _timer = Timer(idleDelay - since, _onIdleCheck);
    }
  }

  static Future<void> _set(bool high) async {
    if (_applied == high) return;
    _applied = high;
    if (!Platform.isAndroid) return;
    try {
      if (high) {
        await FlutterDisplayMode.setHighRefreshRate();
      } else {
        await FlutterDisplayMode.setLowRefreshRate();
      }
    } catch (_) {
      // eski cihaz veya izin vermeyen ROM; varsayılan tazelemeyle devam
    }
  }
}

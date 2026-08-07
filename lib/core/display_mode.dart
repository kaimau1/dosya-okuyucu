import 'dart:io' show Platform;

import 'package:flutter_displaymode/flutter_displaymode.dart';

/// Ekran tazeleme hızını tercihe göre kurar.
///
/// [high] true → 120 Hz+ ekranlarda Android'in 60 Hz kilidini açar (akıcılık).
/// false → en düşük moda döner: **GPU saniyede yarı kadar kare çizer**; uzun
/// belge okuma ve liste kaydırmada en gözle görülür pil kazancı budur.
///
/// **Niye tercihe bağlı (2026-08-07 pil denetimi):** açılışta koşulsuz
/// `setHighRefreshRate()` çağrılıyordu. Çoğu kullanıcı için doğru varsayılan
/// ama pili biten kullanıcının bunu kapatabilmesi gerekir; ayar
/// `AppState.highRefreshRate` ve Ayarlar > Pil ve başarım'da.
///
/// Desteklenmeyen cihaz/ROM'da (ve Android dışı platformlarda) sessizce
/// geçilir — akış asla bloklanmaz.
Future<void> applyRefreshRate(bool high) async {
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

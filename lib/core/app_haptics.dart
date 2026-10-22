import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Dokunsal geri bildirim — tek kapı** (Faz 19 / G21, 2026-10-22).
///
/// `HapticFeedback` 8 yerde dağınıktı ve kapatılamıyordu. Artık her titreşim
/// buradan ve ANLAMIYLA çağrılır; Ayarlar > Görünüm'deki anahtar hepsini
/// kapatır. Bekçi: `app_haptics_test` — ham `HapticFeedback` yalnız bu dosyada.
abstract final class AppHaptics {
  static const prefKey = 'haptics_on';

  /// Açık mı? (Varsayılan açık.) Değişince ayar satırı yeniden çizilir.
  static final enabled = ValueNotifier<bool>(true);

  static Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(prefKey) ?? true;
    } catch (_) {
      // Okunamadı: varsayılan (açık) kalır.
    }
  }

  static Future<void> setEnabled(bool on) async {
    enabled.value = on;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(prefKey, on);
    } catch (_) {
      // Yazılamadı: bu oturum için yine de geçerli.
    }
  }

  /// Seçim başladı / bir öğe seçildi (uzun basış, sayfa seçici).
  static void selection() {
    if (enabled.value) HapticFeedback.selectionClick();
  }

  /// Sürükleyerek seçimde ya da kaydırıcıda bir basamak geçildi.
  static void step() {
    if (enabled.value) HapticFeedback.selectionClick();
  }

  /// Yıkıcı bir işlem onaylandı (kalıcı silme).
  static void destructive() {
    if (enabled.value) HapticFeedback.heavyImpact();
  }

  /// Uzun bir iş bitti.
  static void done() {
    if (enabled.value) HapticFeedback.lightImpact();
  }
}

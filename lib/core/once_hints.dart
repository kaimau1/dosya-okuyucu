import 'package:shared_preferences/shared_preferences.dart';

/// **Bir kez gösterilen ipuçları** (Ferrari H7.3, 2026-11-14).
///
/// "Kaydedildi. Kalıcı yer için ⋮ > Paylaş/Dışa aktar." gibi öğretici
/// metinler her seferinde çıkıyordu; ilk seferden sonra yalnız sonuç
/// ("Kaydedildi") kalır. Ayarlar › Hakkında › "İpuçlarını sıfırla" hepsini
/// (taramadan önceki rehber dahil) yeniden gösterir.
abstract final class OnceHints {
  static const _prefix = 'hint_once.';

  /// [resetAll]'ın sıfırladığı, bu sınıftan önce yazılmış sayaçlar.
  static const _legacyKeys = ['scan_tips_shown'];

  /// [id] ilk kez soruluyorsa `true` döner ve işaretler; sonra hep `false`.
  /// Kayıt okunamazsa ipucu gösterilir (zararsız).
  static Future<bool> take(String id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('$_prefix$id') ?? false) return false;
      await prefs.setBool('$_prefix$id', true);
    } catch (_) {
      // Bilinçli: kayıt yoksa ipucu yine gösterilir.
    }
    return true;
  }

  /// Tüm ipuçlarını yeniden gösterilir yapar.
  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in prefs.getKeys().toList()) {
      if (key.startsWith(_prefix) || _legacyKeys.contains(key)) {
        await prefs.remove(key);
      }
    }
  }
}

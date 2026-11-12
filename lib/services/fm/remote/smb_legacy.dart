import 'package:shared_preferences/shared_preferences.dart';

/// **G8.4 — SMB1 yalnız açık onayla** (2026-11-12).
///
/// `smb_connect` 0.0.9 varsayılanda en düşük sürüm SMB1: SMB2 konuşan bir
/// sunucuya giden pazarlık ortadaki biri tarafından SMB1'e düşürülebilir ve
/// NTLM kimliği eski protokolle gider. Bağlantı artık önce **yalnız SMB2+**
/// dener; sunucu SMB2 bilmiyorsa kullanıcıya bir kez sorulur, onay ana makine
/// başına saklanır.
abstract final class SmbLegacy {
  static const _pref = 'smb1_allowed_hosts';

  /// Arayüz kancası (main'de bağlanır). Null → SMB1 reddedilir.
  static Future<bool> Function(String host)? prompt;

  /// Paketin "sunucu SMB2 desteklemiyor" hatası mı?
  static bool isSmb1Only(Object error) =>
      '$error'.contains('does not support SMB2');

  static Future<bool> isAllowed(String host) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_pref) ?? const [])
          .contains(host.toLowerCase());
    } catch (_) {
      return false; // Bilinçli: okunamazsa onay yok sayılır (yeniden sorulur).
    }
  }

  /// Saklı onay yoksa sorar; onaylanırsa saklar.
  static Future<bool> confirm(String host) async {
    if (await isAllowed(host)) return true;
    final ask = prompt;
    if (ask == null || !await ask(host)) return false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = {...?prefs.getStringList(_pref), host.toLowerCase()};
      await prefs.setStringList(_pref, list.toList());
    } catch (_) {
      return true; // Bilinçli: saklanamazsa bu bağlantı için onay geçerli.
    }
    return true;
  }
}

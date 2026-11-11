import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/remote_connection.dart';
import 'key_vault.dart';

/// **Uzak sunucu parolalarının Keystore'la sarılı saklanması** (Güvenlik
/// Faz G2.1, B1 — 2026-11-11).
///
/// Önceden parola bağlantı JSON'unun içinde (`fm_remote_connections`) DÜZ
/// metin duruyordu. Artık bağlantı listesi PAROLASIZ yazılıyor; `{id: parola}`
/// haritası [KeyVault.seal] ile sarılıp [secretsKey] anahtarına konuyor.
///
/// **Göç:** yüklemede JSON'da `password` alanı bulunursa parola sırlara
/// taşınır ve liste parolasız yeniden yazılır. **Keystore yoksa** (sarma
/// null) eski düz yol sürer — parola kaybolmaz — ve [lastPersistProtected]
/// false olur; ekran "bu cihazda parola korumasız" uyarısı gösterir.
abstract final class RemoteSecrets {
  static const listKey = 'fm_remote_connections';
  static const secretsKey = 'fm_remote_secrets';

  /// Son yazımda parolalar korunabildi mi (Keystore çalıştı ya da yazılacak
  /// parola yoktu).
  static bool lastPersistProtected = true;

  /// Bağlantıları okur, parolaları sırlardan geri koyar; düz parola
  /// bulursa sarılı biçime göç ettirir.
  static Future<List<RemoteConnection>> load(SharedPreferences prefs) async {
    final raw = prefs.getStringList(listKey) ?? const <String>[];
    final list = raw
        .map(RemoteConnection.tryDecode)
        .whereType<RemoteConnection>()
        .toList();
    final secrets = await _openSecrets(prefs);
    var hasPlain = false;
    final restored = <RemoteConnection>[];
    for (final c in list) {
      if (c.password.isNotEmpty) hasPlain = true;
      final sealed = secrets[c.id];
      restored.add(sealed != null && c.password.isEmpty
          ? c.copyWith(password: sealed)
          : c);
    }
    if (hasPlain) {
      // Göç: düz parola JSON'dan sırlara (Keystore varsa). Yoksa aynen kalır.
      await persist(prefs, restored);
    } else {
      lastPersistProtected = true;
    }
    return restored;
  }

  /// Bağlantıları yazar: parolalar sarılı haritaya, liste parolasız.
  /// Keystore yoksa eski düz biçim (parola JSON'da) — bkz. sınıf açıklaması.
  static Future<void> persist(
      SharedPreferences prefs, List<RemoteConnection> remotes) async {
    final secrets = <String, String>{
      for (final r in remotes)
        if (r.savePassword && r.password.isNotEmpty) r.id: r.password,
    };
    if (secrets.isEmpty) {
      await prefs.remove(secretsKey);
      await prefs.setStringList(
          listKey, [for (final r in remotes) r.encode(withPassword: false)]);
      lastPersistProtected = true;
      return;
    }
    final sealed = await KeyVault.seal(jsonEncode(secrets));
    if (sealed != null) {
      await prefs.setString(secretsKey, sealed);
      await prefs.setStringList(
          listKey, [for (final r in remotes) r.encode(withPassword: false)]);
      lastPersistProtected = true;
      return;
    }
    await prefs.remove(secretsKey);
    await prefs.setStringList(listKey, [for (final r in remotes) r.encode()]);
    lastPersistProtected = false;
  }

  static Future<Map<String, String>> _openSecrets(
      SharedPreferences prefs) async {
    final sealed = prefs.getString(secretsKey);
    if (sealed == null || sealed.isEmpty) return const {};
    final json = await KeyVault.open(sealed);
    if (json == null) return const {};
    try {
      final map = jsonDecode(json);
      if (map is! Map) return const {};
      return {for (final e in map.entries) '${e.key}': '${e.value}'};
    } catch (_) {
      return const {};
    }
  }
}

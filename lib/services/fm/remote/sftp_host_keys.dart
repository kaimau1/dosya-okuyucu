import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Sunucu anahtarı onayı için bilgiler (G8.1).
class HostKeyPrompt {
  final String host;
  final int port;
  final String type;

  /// OpenSSH biçimi `SHA256:<base64>`.
  final String fingerprint;

  /// Daha önce kaydedilen parmak izi (değişmişse dolu).
  final String? previous;
  const HostKeyPrompt({
    required this.host,
    required this.port,
    required this.type,
    required this.fingerprint,
    this.previous,
  });

  bool get changed => previous != null;
}

/// **SFTP sunucu anahtarı — ilk kullanımda güven (TOFU)** (Güvenlik G8.1,
/// B16, 2026-11-12).
///
/// Önceden `SSHClient` anahtar denetimi olmadan kuruluyordu: aynı ağdaki
/// biri NAS'ın yerine geçip parolayı alabilirdi. Şimdi:
/// * ilk bağlantıda parmak izi gösterilir ve onaylanırsa kaydedilir;
/// * kayıtlı anahtar değiştiyse KIRMIZI uyarı, varsayılan RET (kullanıcı
///   bilerek "yeni anahtara güven" derse güncellenir);
/// * [prompt] bağlı değilse (test/arka plan) bilinmeyen anahtar kaydedilir,
///   değişen anahtar REDDEDİLİR.
///
/// Kayıt `sftp_known_hosts` (JSON: `host:port` → `tür parmakizi`). Parmak
/// izi sır değildir.
abstract final class SftpHostKeys {
  static const _pref = 'sftp_known_hosts';

  /// Arayüz kancası (`main` bağlar): true = güven.
  static Future<bool> Function(HostKeyPrompt prompt)? prompt;

  static String _key(String host, int port) => '${host.toLowerCase()}:$port';

  /// Saf karar: kayıtlı [known] (`tür parmakizi` ya da null) ile gelen anahtar.
  /// `accept` = sormadan kabul, `ask` = yeni, `changed` = değişti.
  @visibleForTesting
  static String decide(String? known, String type, String fingerprint) {
    if (known == null) return 'ask';
    return known == '$type $fingerprint' ? 'accept' : 'changed';
  }

  static Future<Map<String, String>> _load(SharedPreferences prefs) async {
    try {
      final raw = prefs.getString(_pref);
      if (raw == null) return {};
      final m = jsonDecode(raw);
      if (m is! Map) return {};
      return {for (final e in m.entries) '${e.key}': '${e.value}'};
    } catch (_) {
      // Bilinçli: bozuk kayıt = bilinen anahtar yok (yeniden sorulur).
      return {};
    }
  }

  /// `dartssh2` `onVerifyHostKey` için doğrulayıcı.
  static Future<bool> Function(String type, Uint8List fingerprint) verifier(
          String host, int port) =>
      (type, fp) => verify(host, port, type, utf8.decode(fp, allowMalformed: true));

  static Future<bool> verify(
      String host, int port, String type, String fingerprint) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _load(prefs);
    final key = _key(host, port);
    final known = all[key];
    final d = decide(known, type, fingerprint);
    if (d == 'accept') return true;
    final ask = prompt;
    final bool ok;
    if (ask == null) {
      ok = d == 'ask';
    } else {
      ok = await ask(HostKeyPrompt(
        host: host,
        port: port,
        type: type,
        fingerprint: fingerprint,
        previous: d == 'changed' ? known!.split(' ').last : null,
      ));
    }
    if (ok) {
      all[key] = '$type $fingerprint';
      await prefs.setString(_pref, jsonEncode(all));
    }
    return ok;
  }

  /// Bağlantı silinince kaydı da unut.
  static Future<void> forget(String host, int port) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await _load(prefs);
    if (all.remove(_key(host, port)) != null) {
      await prefs.setString(_pref, jsonEncode(all));
    }
  }
}

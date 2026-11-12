import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'sftp_host_keys.dart';

/// **FTPS sertifikası — ilk kullanımda güven (TOFU)** (Güvenlik G8.2,
/// 2026-11-12).
///
/// `ftpconnect` her TLS sertifikasını sessizce kabul ediyordu (aynı ağdaki
/// biri sunucunun yerine geçip parolayı alabilirdi). CA zinciri doğrulanan
/// sertifika buraya hiç gelmez; kendinden imzalı olanlar için:
/// * TLS el sıkışması senkron bir karar ister → [check] yalnız önceden
///   yüklenmiş kayda bakar; bilinmeyen/değişen sertifikayı REDDEDİP
///   bekleyenlere yazar;
/// * bağlantı düşünce çağıran [takePending] + [confirm] ile kullanıcıya
///   parmak izini gösterir (SFTP ile aynı pencere, `SftpHostKeys.prompt`);
///   onaylanırsa kaydedip bir kez yeniden dener.
///
/// Kayıt `ftps_known_certs` (JSON: `host:port` → `SHA256:<hex>`).
abstract final class FtpsTrust {
  static const _pref = 'ftps_known_certs';
  static final Map<String, String> _known = {};
  static final Map<String, String> _pending = {};

  static String _key(String host, int port) => '${host.toLowerCase()}:$port';

  @visibleForTesting
  static String fingerprintOf(List<int> der) =>
      'SHA256:${sha256.convert(der)}';

  /// Bağlanmadan önce kaydı belleğe alır.
  static Future<void> preload() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_pref);
      _known.clear();
      if (raw == null) return;
      final m = jsonDecode(raw);
      if (m is Map) {
        for (final e in m.entries) {
          _known['${e.key}'] = '${e.value}';
        }
      }
    } catch (_) {
      _known.clear(); // Bilinçli: bozuk kayıt = bilinen sertifika yok.
    }
  }

  /// `FtpTlsTrust.onBadCertificate` — senkron karar.
  static bool check(X509Certificate certificate, String host, int port) =>
      checkDer(certificate.der, host, port);

  @visibleForTesting
  static bool checkDer(List<int> der, String host, int port) {
    final key = _key(host, port);
    final fp = fingerprintOf(der);
    if (_known[key] == fp) return true;
    _pending[key] = fp;
    return false;
  }

  static bool hasPending(String host, int port) =>
      _pending.containsKey(_key(host, port));

  /// Son denemede reddedilen sertifikanın parmak izi (yoksa null).
  static String? takePending(String host, int port) =>
      _pending.remove(_key(host, port));

  /// Kullanıcıya sorar (kanca yoksa: hiç kayıt yoksa kabul, değiştiyse ret);
  /// kabul edilirse kaydeder.
  static Future<bool> confirm(String host, int port, String fingerprint) async {
    final key = _key(host, port);
    final previous = _known[key];
    final ask = SftpHostKeys.prompt;
    final ok = ask == null
        ? previous == null
        : await ask(HostKeyPrompt(
            host: host,
            port: port,
            type: 'TLS',
            fingerprint: fingerprint,
            previous: previous,
          ));
    if (!ok) return false;
    _known[key] = fingerprint;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_pref, jsonEncode(_known));
    } catch (_) {
      return true; // Bilinçli: saklanamazsa bu oturum için geçerli.
    }
    return true;
  }

  @visibleForTesting
  static void resetForTest() {
    _known.clear();
    _pending.clear();
  }
}

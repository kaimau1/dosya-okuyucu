import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'fm/native_extras.dart';

/// **Gizli değerleri Keystore'la şifreli saklama** (Faz 11a / madde 7,
/// 2026-10-22).
///
/// Gemini anahtarları SharedPreferences'ta DÜZ metindi: yedekten, root'lu
/// cihazdan ya da bir hata ayıklama dökümünden okunabiliyordu. Artık değer
/// cihaza bağlı AES-GCM anahtarıyla (Android Keystore, `Extras.wrap`) sarılıp
/// base64 olarak yazılıyor; açmak yalnız bu telefonda mümkün.
///
/// Kanal yoksa (test, Keystore arızası) [seal] null döner ve çağıran eski
/// düz yola düşer — anahtar hiçbir durumda kaybolmaz.
abstract final class KeyVault {
  /// Testler sahte şifreleyici takar.
  @visibleForTesting
  static Future<Uint8List?> Function(Uint8List plain) wrap =
      NativeExtras.wrapKey;
  @visibleForTesting
  static Future<Uint8List?> Function(Uint8List blob) unwrap =
      NativeExtras.unwrapKey;

  static Future<String?> seal(String value) async {
    try {
      final blob = await wrap(Uint8List.fromList(utf8.encode(value)));
      return blob == null || blob.isEmpty ? null : base64Encode(blob);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> open(String sealed) async {
    try {
      final plain = await unwrap(base64Decode(sealed));
      return plain == null ? null : utf8.decode(plain);
    } catch (_) {
      return null;
    }
  }

  @visibleForTesting
  static void reset() {
    wrap = NativeExtras.wrapKey;
    unwrap = NativeExtras.unwrapKey;
  }
}

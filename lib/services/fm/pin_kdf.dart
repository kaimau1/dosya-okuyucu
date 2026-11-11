import 'dart:isolate';
import 'dart:typed_data';

import 'native_extras.dart';
import 'vault_crypto.dart';

/// **PIN → anahtar türetme** (G3.1, 2026-11-11): PBKDF2-HMAC-SHA256.
///
/// ## Niye yerel kod
/// 600.000 tur saf Dart'ta (pointycastle) orta telefonda 10 sn'yi aşar —
/// 120.000 turda bile bir test yedi türetmede 30 sn'yi geçiyordu. Android'in
/// `PBKDF2WithHmacSHA256`ı (Android 8+) aynı turu ~1 sn altında yapar. İkisi
/// AYNI standart algoritma: çıktı bayt bayt eşit (RFC 7914 vektörü
/// `vault_crypto_kat_test`te). Yerel yol yalnız ASCII PIN'de kullanılır
/// (Java `char[]` → bayt dönüşümü sağlayıcıya göre değişebilir; rakam PIN'de
/// fark yok).
///
/// Yerel yol yoksa (Android 7, test) saf Dart: küçük tur sayısı yerinde
/// (widget testinin sahte saatinde de tamamlanır), büyüğü ayrı izolatta
/// (arayüz donmasın).
abstract final class PinKdf {
  /// Bu turun altı ayrı izolata değmez (ve testte yerinde koşar).
  static const inlineMaxIterations = 20000;

  static Future<Uint8List> derive(
      String pin, Uint8List salt, int iterations) async {
    final p = pin.trim();
    if (_ascii(p)) {
      final native = await NativeExtras.pbkdf2(p, salt, iterations);
      if (native != null && native.length == 32) return native;
    }
    if (iterations <= inlineMaxIterations) {
      return VaultCrypto.deriveKey(p, salt, iterations: iterations);
    }
    return Isolate.run(
        () => VaultCrypto.deriveKey(p, salt, iterations: iterations));
  }

  static bool _ascii(String s) => s.codeUnits.every((c) => c < 0x80);
}

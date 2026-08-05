import 'package:flutter/services.dart';

/// Kurulu APK'nın imza sertifikası bilgisi.
///
/// **Neden var (kullanıcı hatası 2026-08-05: "google drive girmiyorum"):**
/// Google, Android'de hesap girişini paket adı + imza SHA-1 ikilisi Cloud'da
/// "Android OAuth istemcisi" olarak kayıtlıysa veriyor. Kayıt için gereken
/// SHA-1'i kullanıcıya UYGULAMANIN İÇİNDE göstermek, "hangi APK kuruluysa onun
/// gerçek imzası" garantisini verir — belgede/CI logunda yazılı değer eski bir
/// anahtara ait olabilir. Drive ekranındaki kurulum kartı buradan okur.
abstract final class AppSignature {
  /// `app_storage` kanalı yeniden kullanılıyor: aynı MainActivity, ikinci bir
  /// kanal kaydı gereksiz.
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  /// OAuth kaydının istediği İKİ değerden biri (öbürü SHA-1). CI'daki
  /// `flutter create --org com.dosyaokuyucu --project-name dosya_okuyucu`
  /// ile sabit; oradan değişirse burası da güncellenmeli.
  static const packageName = 'com.dosyaokuyucu.dosya_okuyucu';

  /// CI'ın kalıcı imza anahtarının SHA-1'i (build 219 doğrulaması,
  /// `ANDROID_KEYSTORE_B64` secret'ı ekli olduğu için sabit). Kanal
  /// çalışmadığında (test, masaüstü, kanalı olmayan eski APK) buna düşülür —
  /// resmi sürümler hep bu anahtarla imzalandığından doğru değerdir.
  static const ciSha1Hex = 'f55d0c099f97713b7a1b8db7e86d6a0adaee9db5';

  /// Kurulu APK'nın imza SHA-1'i, `AA:BB:…` biçiminde (Google Cloud formu
  /// böyle bekler; düz onaltılık da kabul eder ama iki nokta hâli yaygın
  /// gösterim). Kanal yoksa CI anahtarının bilinen değeri döner.
  static Future<String> sha1Colonized() async {
    try {
      final raw = await _channel.invokeMethod<String>('appSignatureSha1');
      if (raw != null && raw.isNotEmpty) return colonize(raw);
    } catch (_) {
      // MissingPluginException (test/masaüstü) ya da eski APK: aşağı düş.
    }
    return colonize(ciSha1Hex);
  }

  /// `f55d0c…` → `F5:5D:0C:…`. Saf fonksiyon; birim testli.
  static String colonize(String hex) {
    final clean = hex.replaceAll(':', '').toUpperCase();
    final pairs = <String>[];
    for (var i = 0; i + 1 < clean.length; i += 2) {
      pairs.add(clean.substring(i, i + 2));
    }
    return pairs.join(':');
  }
}

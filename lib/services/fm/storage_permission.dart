import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

import '../../core/edition.dart';

/// Depolama izni yönetimi.
///
/// Android 11+ (API 30) bir dosya yöneticisinin `/storage/emulated/0`'ı
/// gezebilmesi için **MANAGE_EXTERNAL_STORAGE** ("tüm dosyalara erişim")
/// ister; klasik `READ_EXTERNAL_STORAGE` yalnızca medyaya yeter, SAF ise
/// kullanıcıya her klasörü tek tek seçtirir (dosya yöneticisinde kullanılamaz).
/// Bu izin ÖZEL bir sistem ayar sayfası açar — normal izin penceresi değildir.
///
/// **Tek istek kuralı (2026-11-07, izin sadeliği aşama 1):** bir dokunuş =
/// en çok BİR sistem penceresi. Eskiden "tüm dosyalar" reddedilince ardından
/// klasik depolama + üç medya izni daha soruluyordu ("izin yağmuru" — Play
/// yorumlarındaki başlıca şikâyet). Reddeden kullanıcı okuyucuyu "Birlikte
/// aç" / sistem seçicisiyle (SAF, izinsiz) kullanmaya devam eder.
abstract final class StoragePermission {
  /// Android 10 ve altı: `MANAGE_EXTERNAL_STORAGE` yok (eklenti `restricted`
  /// döner); tüm depolamaya erişimi klasik depolama izni verir.
  static Future<bool> _legacyDevice() async =>
      (await Permission.manageExternalStorage.status).isRestricted;

  /// Tüm dosyalara erişim verilmiş mi?
  /// **İzinsiz okuyucu derlemesi** (Play aşama 3, `--dart-define=DOSYA_OKUYUCU=true`):
  /// manifestte hassas izin yok (`ci/prepare_android.sh` §11) → izin hiç
  /// istenmez; kullanıcı "Klasör ekle" (SAF) ve "Dosya aç" ile çalışır.
  /// Sürüm kapısına bağlı (S1): Lite = izinsiz okuyucu.
  static const readerBuild = Edition.current == Edition.lite;

  static Future<bool> hasFullAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await _legacyDevice()) return await Permission.storage.isGranted;
      return false;
    } catch (_) {
      return false; // eklenti yok (test/masaüstü)
    }
  }

  /// İzni ister — cihaza göre TEK yol: Android 11+ "tüm dosyalara erişim"
  /// ayar sayfası, Android ≤10 klasik depolama penceresi.
  /// Kullanıcı reddederse `false` döner; uygulama kilitlenmez, ardından başka
  /// izin sorulmaz (çağıran "tek tek aç" yolunu gösterir).
  static Future<bool> request() async {
    if (!Platform.isAndroid) return true;
    if (readerBuild) return false;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;
      if (await _legacyDevice()) {
        return (await Permission.storage.request()).isGranted;
      }
      return (await Permission.manageExternalStorage.request()).isGranted;
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı izni kalıcı reddettiyse uygulama ayarlarını açar.
  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {
      // Bilinçli: sistem ekranı açılamadı (bu cihazda yok) — kullanıcı bulunduğu yerde kalır.
    }
  }
}

import 'dart:io';

import 'package:permission_handler/permission_handler.dart';

/// Depolama izni yönetimi.
///
/// Android 11+ (API 30) bir dosya yöneticisinin `/storage/emulated/0`'ı
/// gezebilmesi için **MANAGE_EXTERNAL_STORAGE** ("tüm dosyalara erişim")
/// ister; klasik `READ_EXTERNAL_STORAGE` yalnızca medyaya yeter, SAF ise
/// kullanıcıya her klasörü tek tek seçtirir (dosya yöneticisinde kullanılamaz).
/// Bu izin ÖZEL bir sistem ayar sayfası açar — normal izin penceresi değildir.
///
/// Not: Google Play bu izni gerekçe ister; uygulama GitHub Releases ile
/// dağıtıldığı için engel yok (bkz. HAFIZA).
abstract final class StoragePermission {
  /// Tüm dosyalara erişim verilmiş mi?
  static Future<bool> hasFullAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      return await Permission.manageExternalStorage.isGranted;
    } catch (_) {
      return false; // eklenti yok (test/masaüstü)
    }
  }

  /// En az medya (görsel/video/ses) okunabiliyor mu?
  static Future<bool> hasMediaAccess() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.storage.isGranted) return true;
      final photos = await Permission.photos.isGranted;
      final videos = await Permission.videos.isGranted;
      return photos || videos;
    } catch (_) {
      return false;
    }
  }

  /// İzin ister. Sırayla: klasik depolama izni (Android ≤12'de gerçek erişim
  /// verir) → tüm dosyalara erişim (Android 11+ ayar sayfası).
  /// Kullanıcı reddederse `false` döner; uygulama kilitlenmez, yalnızca
  /// gezilebilir alan (uygulama klasörü + medya) daralır.
  static Future<bool> request() async {
    if (!Platform.isAndroid) return true;
    try {
      if (await Permission.manageExternalStorage.isGranted) return true;

      final legacy = await Permission.storage.request();
      if (legacy.isGranted) return true;

      final full = await Permission.manageExternalStorage.request();
      if (full.isGranted) return true;

      // Son çare: yalnız medya izinleri (Android 13+ bölünmüş izinler).
      final media = await [
        Permission.photos,
        Permission.videos,
        Permission.audio,
      ].request();
      return media.values.any((s) => s.isGranted);
    } catch (_) {
      return false;
    }
  }

  /// Kullanıcı izni kalıcı reddettiyse uygulama ayarlarını açar.
  static Future<void> openSettings() async {
    try {
      await openAppSettings();
    } catch (_) {}
  }
}

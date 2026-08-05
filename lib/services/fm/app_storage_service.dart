import 'package:flutter/services.dart';

/// Bir uygulamanın kapladığı alan.
class AppStorageSize {
  /// APK + kütüphaneler (kaldırınca gider, temizlenemez).
  final int appBytes;

  /// Uygulama verisi — `cacheBytes` bunun İÇİNDEDİR (Android böyle raporluyor).
  final int dataBytes;

  /// Önbellek: silinmesi güvenli, uygulama yeniden üretir.
  final int cacheBytes;

  const AppStorageSize({
    required this.appBytes,
    required this.dataBytes,
    required this.cacheBytes,
  });

  int get totalBytes => appBytes + dataBytes;
}

/// Yüklü uygulamaların **kapladığı alanı** okur ve Android'in ayar sayfalarını
/// açar (`StorageStatsManager` köprüsü — bkz. `ci/MainActivity.kt`).
///
/// **Neden platform kanalı:** `installed_apps` eklentisi ad/sürüm/simge
/// veriyor ama boyut vermiyor; `df` de uygulama başına kırılım bilmiyor.
/// Android 11+ `Android/data` klasörünü başka uygulamalara kapattığı için
/// klasör ölçerek de bulunamıyor. Tek yol `StorageStatsManager`.
///
/// **İzin:** "Kullanım erişimi" (`PACKAGE_USAGE_STATS`) — son kullanım
/// tarihiyle AYNI izin, yani kullanıcı bir kez verince ikisi de açılıyor.
/// İzin yokken boyut sorgusu boş döner; arayüz sayı uydurmaz, "bilinmiyor"
/// gösterir.
///
/// Kanal yoksa (masaüstü, `flutter test`, eski APK) bütün çağrılar zarifçe
/// boş/false döner — çağıranın ayrıca platform kontrolü yapmasına gerek yok.
abstract final class AppStorageService {
  static const _channel = MethodChannel('dosya_okuyucu/app_storage');

  /// Kanal bu cihazda çalışıyor mu (bir kez ölçülür).
  static bool? _available;

  static Future<bool> hasUsageAccess() async {
    try {
      final ok = await _channel.invokeMethod<bool>('hasUsageAccess');
      _available = true;
      return ok ?? false;
    } catch (_) {
      _available = false;
      return false;
    }
  }

  /// Android'in "Kullanım erişimi" ayar sayfasını açar.
  static Future<void> openUsageAccessSettings() async {
    try {
      await _channel.invokeMethod<bool>('openUsageAccessSettings');
    } catch (_) {}
  }

  /// Uygulamanın **depolama / önbellek temizleme** sayfasını açar.
  static Future<bool> openAppStorageSettings(String packageName) async {
    try {
      final ok = await _channel.invokeMethod<bool>(
          'openAppStorageSettings', {'package': packageName});
      return ok ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Verilen paketlerin boyutları. Okunamayan paket sonuçta YER ALMAZ
  /// (sıfır yazmak "hiç yer kaplamıyor" demek olurdu, bu yanlış olurdu).
  static Future<Map<String, AppStorageSize>> sizesOf(
      List<String> packages) async {
    if (packages.isEmpty || _available == false) return const {};
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
          'appSizes', {'packages': packages});
      _available = true;
      if (raw == null) return const {};
      final out = <String, AppStorageSize>{};
      raw.forEach((pkg, value) {
        if (value is! List || value.length < 3) return;
        out[pkg] = AppStorageSize(
          appBytes: (value[0] as num).toInt(),
          dataBytes: (value[1] as num).toInt(),
          cacheBytes: (value[2] as num).toInt(),
        );
      });
      return out;
    } catch (_) {
      _available = false;
      return const {};
    }
  }

  /// Testlerde sahte kanal kurulduktan sonra "yok" damgasını temizler.
  static void resetForTest() => _available = null;
}

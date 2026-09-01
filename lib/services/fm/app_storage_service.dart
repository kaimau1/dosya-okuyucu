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

  /// Paket → **son açılma zamanı** (epoch ms). Hiç açılmamış paket sonuçta
  /// YER ALMAZ; kanal yoksa/izin yoksa boş harita döner.
  ///
  /// Kaynak `UsageStats.getLastTimeUsed()` (bkz. `ci/MainActivity.kt`).
  /// `app_usage` eklentisinin `lastForeground` alanı bu DEĞİLDİ — o, son
  /// **ön plan servisi** zamanıdır ve servis çalıştırmayan uygulamalarda 0
  /// döner (kullanıcı hatası 2026-08-28: "açtığım birçok şey 'hiç açılmadı'
  /// görünüyor").
  static Future<Map<String, int>> lastUsed({int days = 730}) async {
    if (_available == false) return const {};
    try {
      final raw = await _channel
          .invokeMapMethod<String, dynamic>('lastUsed', {'days': days});
      _available = true;
      if (raw == null) return const {};
      final out = <String, int>{};
      raw.forEach((pkg, value) {
        if (value is num && value > 0) out[pkg] = value.toInt();
      });
      return out;
    } catch (_) {
      // Eski APK'da bu yöntem yok (`notImplemented`) — kanalı ölü saymıyoruz,
      // boyut sorgusu hâlâ çalışabilir.
      return const {};
    }
  }

  /// Kurulu bir uygulamanın **APK dosyalarının yolu** (temel + parçalar).
  ///
  /// Kanal yoksa, paket bulunamazsa ya da yol okunamıyorsa `null` — arayüz
  /// "APK bulunamadı" der. Yolu uydurmak (`/data/app/<paket>/base.apk`)
  /// İMKÂNSIZ: gerçek yol iki rastgele parça içeriyor (bkz. ci/MainActivity.kt).
  static Future<ApkSource?> apkPathsOf(String packageName) async {
    try {
      final raw = await _channel.invokeMapMethod<String, dynamic>(
          'apkPaths', {'package': packageName});
      if (raw == null) return null;
      final source = raw['source'];
      if (source is! String || source.isEmpty) return null;
      return ApkSource(
        sourcePath: source,
        splitPaths: [
          for (final s in (raw['splits'] as List? ?? const []))
            if (s is String && s.isNotEmpty) s,
        ],
        label: raw['label'] is String ? raw['label'] as String : '',
        versionName:
            raw['versionName'] is String ? raw['versionName'] as String : '',
      );
    } catch (_) {
      // Eski APK'da bu yöntem yok (`notImplemented`) — kanalı ölü saymıyoruz,
      // boyut sorgusu hâlâ çalışabilir.
      return null;
    }
  }

  /// Uygulamayı **başlatan** intent'in eylemi; okununca temizlenir.
  ///
  /// Tek kullanıcısı USB akışı: Android, bellek takılınca "hangi uygulamayla
  /// açayım?" diye soruyor ve bizi seçince uygulama
  /// `android.hardware.usb.action.USB_DEVICE_ATTACHED` ile açılıyor. O eylemin
  /// verisi (URI) olmadığı için `receive_sharing_intent` hiçbir şey getirmiyor;
  /// bu köprü olmasa uygulama sıradan bir açılış gibi panoya düşerdi.
  ///
  /// Kanal yoksa (masaüstü, test, eski APK) null döner.
  static Future<String?> launchAction() async {
    try {
      return await _channel.invokeMethod<String>('launchAction');
    } catch (_) {
      return null;
    }
  }

  /// Uygulama bir **USB bellek takılması** yüzünden mi açıldı?
  static Future<bool> launchedByUsb() async =>
      await launchAction() == usbAttachedAction;

  /// Android'in USB takılma eylemi (manifest'teki intent filtresiyle aynı).
  static const usbAttachedAction =
      'android.hardware.usb.action.USB_DEVICE_ATTACHED';

  /// Testlerde sahte kanal kurulduktan sonra "yok" damgasını temizler.
  static void resetForTest() => _available = null;
}

/// Kurulu bir uygulamanın diskteki APK dosyaları.
class ApkSource {
  /// `base.apk` — uygulamanın kodu ve manifest'i.
  final String sourcePath;

  /// Bölünmüş parçalar (`split_config.arm64_v8a.apk`, `split_config.tr.apk`…).
  /// Play'den App Bundle olarak kurulan uygulamalarda dolu olur.
  final List<String> splitPaths;

  final String label;
  final String versionName;

  const ApkSource({
    required this.sourcePath,
    this.splitPaths = const [],
    this.label = '',
    this.versionName = '',
  });

  /// Uygulama parçalı mı kurulmuş? (Paylaşma akışının verdiği kararın girdisi:
  /// tek `base.apk` karşı tarafta kurulmayabilir.)
  bool get isSplit => splitPaths.isNotEmpty;

  /// Paylaşılacak bütün dosyalar (temel + parçalar).
  List<String> get allPaths => [sourcePath, ...splitPaths];
}

import 'dart:typed_data';

import 'package:app_usage/app_usage.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yüklü bir uygulama + son kullanım bilgisi.
class InstalledAppEntry {
  final String name;
  final String packageName;
  final String versionName;
  final Uint8List? icon;
  final int installedAtMs;

  /// Son ön plana geldiği an (ms). 0 = bilinmiyor (izin yok ya da hiç
  /// kullanılmamış).
  final int lastUsedMs;

  /// Kullanım verisi okunabildi mi (izin verilmiş mi)?
  final bool usageKnown;

  const InstalledAppEntry({
    required this.name,
    required this.packageName,
    required this.versionName,
    required this.icon,
    required this.installedAtMs,
    required this.lastUsedMs,
    required this.usageKnown,
  });

  /// Kaç gündür açılmadı? Bilinmiyorsa null.
  int? idleDays(int nowMs) {
    if (!usageKnown || lastUsedMs <= 0) return null;
    return ((nowMs - lastUsedMs) / 86400000).floor();
  }
}

/// Kullanılmama derecesi — listede renklendirme için.
enum AppIdleLevel {
  /// Son 7 gün içinde kullanıldı.
  active,

  /// 7–30 gün.
  quiet,

  /// 30–90 gün.
  stale,

  /// 90 günden fazla ya da hiç kullanılmamış.
  forgotten,

  /// Kullanım verisi yok (izin verilmemiş).
  unknown,
}

/// Saf karar fonksiyonu (birim testli): kaç gün boştaysa hangi seviye.
AppIdleLevel idleLevelFor(int? idleDays, {required bool usageKnown}) {
  if (!usageKnown) return AppIdleLevel.unknown;
  if (idleDays == null) return AppIdleLevel.forgotten; // hiç açılmamış
  if (idleDays < 7) return AppIdleLevel.active;
  if (idleDays < 30) return AppIdleLevel.quiet;
  if (idleDays < 90) return AppIdleLevel.stale;
  return AppIdleLevel.forgotten;
}

/// Telefonda yüklü uygulamaları ve son kullanım zamanlarını okur.
///
/// **İki ayrı kaynak:** uygulama listesi `installed_apps` (PackageManager),
/// son kullanım `app_usage` (UsageStatsManager). İkincisi Android'in ÖZEL
/// "Kullanım erişimi" iznini ister (normal izin penceresi değil, ayar sayfası).
/// İzin yoksa liste yine gelir, yalnız "son açılma" bilinmez.
///
/// **İzin sorgusu yok, bayrak var:** `app_usage` "izin verildi mi" diye
/// soracak bir API sunmuyor; izin yokken sorgu yapmak ayar sayfasını AÇIYOR.
/// Ekran her açılışta ayar sayfası fırlatmasın diye izin bir kez alındığında
/// bayrak kalıcı olarak saklanır; sorgu yalnız bayrak açıkken (ya da kullanıcı
/// "İzin ver" dediğinde) yapılır.
abstract final class InstalledAppsService {
  static const _kUsageGranted = 'fm_usage_access_granted';

  /// Daha önce kullanım verisi alabildik mi?
  static Future<bool> hasUsagePermission() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_kUsageGranted) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> _setGranted(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kUsageGranted, value);
    } catch (_) {}
  }

  /// Kullanım erişimi ister: sorgu denenir, izin yoksa eklenti Android'in
  /// "Kullanım erişimi" ayar sayfasını açar. Kullanıcı verip döndüğünde
  /// veri gelirse bayrak açılır.
  static Future<bool> requestUsagePermission() async {
    final data = await _lastUsedByPackage();
    final granted = data.isNotEmpty;
    if (granted) await _setGranted(true);
    return granted;
  }

  /// paket → son ön plana gelme (ms). İzin yoksa boş harita (ve ayar sayfası
  /// açılır — çağıran bunu bilerek çağırır).
  static Future<Map<String, int>> _lastUsedByPackage(
      {int windowDays = 365}) async {
    try {
      final now = DateTime.now();
      final usage = await AppUsage()
          .getAppUsage(now.subtract(Duration(days: windowDays)), now);
      return {
        for (final info in usage)
          info.packageName: lastUsedMs(info.lastForeground),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Yüklü uygulamalar (varsayılan: sistem uygulamaları hariç), son kullanım
  /// bilgisiyle birleştirilmiş.
  static Future<List<InstalledAppEntry>> list({
    bool includeSystemApps = false,
    int usageWindowDays = 365,
  }) async {
    List<AppInfo> apps;
    try {
      apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: !includeSystemApps,
        excludeNonLaunchableApps: !includeSystemApps,
        withIcon: true,
      );
    } catch (_) {
      return const [];
    }

    // İzin bayrağı kapalıysa sorgu YAPILMAZ (yoksa ayar sayfası açılırdı).
    var usageKnown = await hasUsagePermission();
    var usage = const <String, int>{};
    if (usageKnown) {
      usage = await _lastUsedByPackage(windowDays: usageWindowDays);
      if (usage.isEmpty) {
        // İzin geri alınmış olabilir.
        usageKnown = false;
        await _setGranted(false);
      }
    }

    return [
      for (final app in apps)
        InstalledAppEntry(
          name: app.name,
          packageName: app.packageName,
          versionName: app.versionName,
          icon: app.icon,
          installedAtMs: app.installedTimestamp,
          lastUsedMs: usage[app.packageName] ?? 0,
          usageKnown: usageKnown,
        ),
    ];
  }

  /// `lastForeground` → ms. Saf yardımcı (birim testli): veri yokken eklenti
  /// 1970 civarı bir tarih dönebiliyor; 2000 öncesini "bilinmiyor" sayarız.
  static int lastUsedMs(DateTime? date) {
    if (date == null) return 0;
    final ms = date.millisecondsSinceEpoch;
    return ms > 946684800000 ? ms : 0; // 2000-01-01
  }

  static Future<void> open(String packageName) async {
    try {
      await InstalledApps.startApp(packageName);
    } catch (_) {}
  }

  static void openSettings(String packageName) {
    try {
      InstalledApps.openSettings(packageName);
    } catch (_) {}
  }

  static Future<void> uninstall(String packageName) async {
    try {
      await InstalledApps.uninstallApp(packageName);
    } catch (_) {}
  }
}

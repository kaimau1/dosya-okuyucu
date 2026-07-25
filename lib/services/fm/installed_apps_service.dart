import 'dart:typed_data';

import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:usage_stats/usage_stats.dart';

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
/// son kullanım `usage_stats` (UsageStatsManager). İkincisi Android'in ÖZEL
/// "Kullanım erişimi" iznini ister (normal izin penceresi değil, ayar sayfası).
/// İzin yoksa liste yine gelir, yalnız "son açılma" bilinmez.
abstract final class InstalledAppsService {
  /// Kullanım erişimi verilmiş mi?
  static Future<bool> hasUsagePermission() async {
    try {
      return await UsageStats.checkUsagePermission() ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Kullanım erişimi ayar sayfasını açar (kullanıcı elle verir).
  static Future<void> requestUsagePermission() async {
    try {
      await UsageStats.grantUsagePermission();
    } catch (_) {}
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

    final usageKnown = await hasUsagePermission();
    var usage = <String, UsageInfo>{};
    if (usageKnown) {
      try {
        final now = DateTime.now();
        usage = await UsageStats.queryAndAggregateUsageStats(
          now.subtract(Duration(days: usageWindowDays)),
          now,
        );
      } catch (_) {
        usage = {};
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
          lastUsedMs: parseLastUsed(usage[app.packageName]?.lastTimeUsed),
          usageKnown: usageKnown,
        ),
    ];
  }

  /// UsageStats zaman damgalarını String olarak verir; saf ayrıştırıcı
  /// (birim testli) — bozuk/eksik değerde 0.
  static int parseLastUsed(String? raw) {
    if (raw == null || raw.isEmpty) return 0;
    final value = int.tryParse(raw);
    if (value == null || value <= 0) return 0;
    return value;
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

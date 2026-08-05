import 'dart:typed_data';

import 'package:app_usage/app_usage.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_storage_service.dart';

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

  /// Kapladığı alan — `null` ise ÖLÇÜLEMEDİ (izin yok ya da kanal yok).
  /// Sıfır yazmak "yer kaplamıyor" demek olurdu, bu yanlış olurdu.
  final AppStorageSize? size;

  const InstalledAppEntry({
    required this.name,
    required this.packageName,
    required this.versionName,
    required this.icon,
    required this.installedAtMs,
    required this.lastUsedMs,
    required this.usageKnown,
    this.size,
  });

  /// Uygulama + veri (önbellek dahil). Bilinmiyorsa 0 — SIRALAMA için.
  int get totalBytes => size?.totalBytes ?? 0;

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
    bool withSizes = true,
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

    // Boyutlar AYNI izne bağlı (Kullanım erişimi); izin yoksa kanal boş
    // döner ve liste boyutsuz gelir — ekran bunu "bilinmiyor" gösterir.
    final sizes = withSizes
        ? await AppStorageService.sizesOf(
            [for (final a in apps) a.packageName])
        : const <String, AppStorageSize>{};

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
          size: sizes[app.packageName],
        ),
    ];
  }

  /// Yüklü uygulamaların TOPLAM kapladığı alan + en büyükleri.
  ///
  /// Bellek analizi kartı bunu kullanıyor: simge yüklemeden (pahalı) yalnız
  /// ad + boyut isteniyor.
  /// Son özet + ölçüm anı. Analiz ekranı her açılışta 200+ binder çağrısı
  /// yapmasın diye kısa süre saklanır; boyutlar dakikalar içinde anlamlı
  /// ölçüde değişmiyor.
  static AppStorageSummary? _summaryCache;
  static DateTime? _summaryAt;
  static const _summaryTtl = Duration(minutes: 5);

  static Future<AppStorageSummary> summary({int top = 3}) async {
    final cached = _summaryCache;
    final at = _summaryAt;
    if (cached != null &&
        at != null &&
        DateTime.now().difference(at) < _summaryTtl) {
      return cached;
    }
    List<AppInfo> apps;
    try {
      apps = await InstalledApps.getInstalledApps(
        excludeSystemApps: true,
        excludeNonLaunchableApps: true,
        withIcon: false,
      );
    } catch (_) {
      return const AppStorageSummary(totalBytes: 0, cacheBytes: 0, top: []);
    }
    final sizes =
        await AppStorageService.sizesOf([for (final a in apps) a.packageName]);
    if (sizes.isEmpty) {
      // Önbelleğe ALINMAZ: izin yokken boş dönüyor olabilir, kullanıcı izni
      // verip döndüğünde beş dakika beklemesin.
      return const AppStorageSummary(totalBytes: 0, cacheBytes: 0, top: []);
    }
    var total = 0;
    var cache = 0;
    final ranked = <(String, int)>[];
    for (final app in apps) {
      final s = sizes[app.packageName];
      if (s == null) continue;
      total += s.totalBytes;
      cache += s.cacheBytes;
      ranked.add((app.name, s.totalBytes));
    }
    ranked.sort((a, b) => b.$2.compareTo(a.$2));
    final summary = AppStorageSummary(
      totalBytes: total,
      cacheBytes: cache,
      top: ranked.take(top).toList(growable: false),
    );
    _summaryCache = summary;
    _summaryAt = DateTime.now();
    return summary;
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

/// Bellek analizi "Uygulamalar" kartının özeti.
class AppStorageSummary {
  /// Tüm (sistem dışı) uygulamaların uygulama + veri toplamı.
  final int totalBytes;

  /// Silinmesi güvenli önbellek toplamı.
  final int cacheBytes;

  /// En büyükler: (uygulama adı, bayt).
  final List<(String, int)> top;

  const AppStorageSummary({
    required this.totalBytes,
    required this.cacheBytes,
    required this.top,
  });

  bool get hasData => totalBytes > 0;
}

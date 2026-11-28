import 'package:path_provider/path_provider.dart';

import 'storage_stats.dart';
import 'trash_service.dart';

/// Aynı dahili belleği gösteren Android takma yollarını (`/sdcard/…`,
/// `/storage/self/primary/…`) tek kanonik `/storage/emulated/0/…` yoluna
/// indirger — "Son dosyalar"da aynı belgenin çift görünmesini önler.
String canonicalAndroidPath(String path) {
  for (final alias in const ['/sdcard', '/storage/self/primary']) {
    if (path == alias) return StorageStats.primaryPath;
    if (path.startsWith('$alias/')) {
      return '${StorageStats.primaryPath}${path.substring(alias.length)}';
    }
  }
  return path;
}

/// Dosya yöneticisinin çalışma ortamı: birimler, kökler ve çöp kutusu.
///
/// Tek yerden kurulur ve ekranlar arasında paylaşılır — her ekranın `df`
/// çalıştırıp `/storage`'ı yeniden taraması gereksiz maliyet olurdu.
abstract final class FmEnv {
  static List<StorageVolume> volumes = const [];
  static String primaryRoot = StorageStats.primaryPath;
  static String appSupportDir = '';
  static bool _ready = false;
  static Future<String>? _supportFuture;
  static Future<void>? _initFuture;

  static bool get ready => _ready;

  /// Yalnız uygulama destek klasörünü hazırlar (depolama taraması/`df` yok).
  /// Okuma konumu ve yer imleri gibi hafif depolar soğuk açılışta buna
  /// dayanarak milisaniyede yüklenir.
  static Future<String> ensureAppSupportDir() {
    if (appSupportDir.isNotEmpty) return Future.value(appSupportDir);
    return _supportFuture ??=
        _loadAppSupportDir().whenComplete(() => _supportFuture = null);
  }

  static Future<String> _loadAppSupportDir() async {
    try {
      appSupportDir = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      appSupportDir = '';
    }
    return appSupportDir;
  }

  /// Bir kez kurulur; eşzamanlı çağrılar tek işi bekler. [force] ile (izin
  /// verildikten sonra) yenilenir.
  static Future<void> ensureInit({bool force = false}) {
    if (_ready && !force) return Future.value();
    if (!force && _initFuture != null) return _initFuture!;
    late final Future<void> run;
    run = _doInit().whenComplete(() {
      if (identical(_initFuture, run)) _initFuture = null;
    });
    _initFuture = run;
    return run;
  }

  static Future<void> _doInit() async {
    await ensureAppSupportDir();
    try {
      primaryRoot =
          await StorageStats.primaryRoot() ?? StorageStats.primaryPath;
    } catch (_) {
      primaryRoot = StorageStats.primaryPath;
    }
    // **Birim taraması dosya yöneticisini ASLA durduramaz** (kullanıcı çökmesi
    // 2026-09-02): burada bir istisna kaçtığında `ensureInit` yarıda kalıyor,
    // `_ready` false kalıyor ve pano sonsuza dek "Depolama taranıyor…"
    // gösteriyordu. Tarama en kötü ihtimalle eksik kalmalı, hiç açılmamak
    // değil — ana bellek yedeği aşağıda zaten var.
    try {
      volumes = await StorageStats.volumes();
    } catch (_) {
      volumes = const [];
    }
    if (volumes.isEmpty) {
      volumes = [
        StorageVolume(
            path: primaryRoot, labelKey: 'fm.vol_internal', isPrimary: true),
      ];
    }
    _ready = true;
  }

  static List<String> get volumeRoots => [
        for (final v in volumes) v.path,
        if (!volumes.any((v) => v.path == primaryRoot)) primaryRoot,
      ];

  /// Çıkarılabilir USB bellekler hariç cihaz kökleri (dahili + SD kart).
  ///
  /// USB takılıyken telefonun ana kategorileri (Belgeler/Videolar/Fotoğraflar),
  /// Yeniler listesi ve Arama dizini USB'deki dosyalarla karışmasın diye
  /// ayrıştırılır.
  static List<String> get phoneRoots => [
        for (final v in volumes)
          if (v.kind != StorageKind.usb) v.path,
        if (!volumes.any((v) => v.path == primaryRoot)) primaryRoot,
      ];

  static TrashService get trash => TrashService(
        volumeRoots: volumeRoots,
        fallbackRoot: appSupportDir,
      );
}

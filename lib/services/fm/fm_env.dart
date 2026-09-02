import 'package:path_provider/path_provider.dart';

import 'storage_stats.dart';
import 'trash_service.dart';

/// Dosya yöneticisinin çalışma ortamı: birimler, kökler ve çöp kutusu.
///
/// Tek yerden kurulur ve ekranlar arasında paylaşılır — her ekranın `df`
/// çalıştırıp `/storage`'ı yeniden taraması gereksiz maliyet olurdu.
abstract final class FmEnv {
  static List<StorageVolume> volumes = const [];
  static String primaryRoot = StorageStats.primaryPath;
  static String appSupportDir = '';
  static bool _ready = false;

  static bool get ready => _ready;

  /// Bir kez kurulur; [force] ile (izin verildikten sonra) yenilenir.
  static Future<void> ensureInit({bool force = false}) async {
    if (_ready && !force) return;
    try {
      appSupportDir = (await getApplicationSupportDirectory()).path;
    } catch (_) {
      appSupportDir = '';
    }
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

  static TrashService get trash => TrashService(
        volumeRoots: volumeRoots,
        fallbackRoot: appSupportDir,
      );
}

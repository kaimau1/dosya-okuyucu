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
    primaryRoot = await StorageStats.primaryRoot() ?? StorageStats.primaryPath;
    volumes = await StorageStats.volumes();
    if (volumes.isEmpty) {
      volumes = [
        StorageVolume(path: primaryRoot, label: 'Ana bellek', isPrimary: true),
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

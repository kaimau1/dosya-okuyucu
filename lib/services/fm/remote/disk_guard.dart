import 'dart:math';

import '../storage_stats.dart';

/// **Yüklemede boş disk denetimi** (Güvenlik G4.5, 2026-11-12).
///
/// Aynı ağdaki biri (ya da yanlışlıkla seçilen dev bir klasör) telefona
/// yükleme yaparak belleği sonuna kadar doldurabilir; dolu bellekte Android
/// uygulamaları çöker, veritabanları bozulur. Yükleme başlamadan önce hedef
/// klasörün bulunduğu bölümde en az [minFreeBytes] kalacağı denetlenir:
/// HTTP'de `507 Insufficient Storage`, FTP'de `452`.
///
/// Boş alan okunamazsa (df yok/izin yok) yükleme ENGELLENMEZ — denetim bir
/// emniyet kemeri, eski davranışı bozmamalı.
class DiskGuard {
  DiskGuard._();

  /// Yüklemeden sonra bölümde kalması gereken en az boş alan.
  static const minFreeBytes = 200 * 1024 * 1024;

  /// Boş bayt ölçer — testler değiştirir.
  static Future<int?> Function(String path) freeBytesOf = _df;

  static Future<int?> _df(String path) async =>
      (await StorageStats.usageOf(path))?.$2;

  /// [dir]e [incoming] bayt yazıldıktan sonra yeterli yer kalır mı?
  /// [incoming] bilinmiyorsa (`-1`, parçalı aktarım) 0 sayılır.
  static Future<bool> hasRoom(String dir, {int incoming = 0}) async {
    int? free;
    try {
      free = await freeBytesOf(dir);
    } catch (_) {
      // Bilinçli: ölçülemeyen boş alan engel sayılmaz (yukarıdaki not).
    }
    if (free == null) return true;
    return free - max(0, incoming) >= minFreeBytes;
  }
}

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fm/storage_stats.dart';

/// **Yeni belgelerin varsayılan evi:** taramalar, "Yeni belge", yazılamayan
/// yerdeki PDF'in kopyası.
///
/// KÖK NEDEN (2026-09-26, kullanıcı: *"uygulama 550 MB okuyor"* + *"harici
/// bellek okuma yazma ne durumda"*): üçü de `getApplicationDocumentsDirectory`
/// kullanıyordu — Android'de bu `/data/user/0/<paket>/app_flutter`, yani
/// uygulamanın GİZLİ klasörü. Sonuçları:
/// * kullanıcının taramaları Ayarlar > Uygulamalar'da "uygulama verisi"
///   görünüyor, uygulamanın boyutunu şişiriyordu;
/// * uygulama kaldırılınca ya da "verileri temizle" denince HEPSİ siliniyordu;
/// * bilgisayara USB ile bağlayınca, başka bir dosya yöneticisinde, Google
///   Drive yedeğinde görünmüyorlardı.
/// Artık ana bellekte `Documents/Dosya Okuyucu/`. Yazılamazsa (izin yok,
/// masaüstü, test) eski gizli klasöre düşülür — kayıt hiçbir koşulda
/// başarısız olmasın.
abstract final class DocsHome {
  /// Ana bellekteki klasörün adı.
  static const folderName = 'Dosya Okuyucu';

  /// Testte ana bellek yerine geçecek kök (null → gerçek cihaz yolu).
  static String? debugPublicRoot;

  /// Herkese açık klasörün yolu (var olup olmadığına bakmadan).
  static String publicPath(String root) =>
      p.join(root, 'Documents', folderName);

  static Future<Directory> resolve() async {
    final root = debugPublicRoot ??
        (Platform.isAndroid ? StorageStats.primaryPath : null);
    if (root != null) {
      final dir = Directory(publicPath(root));
      if (await _writable(dir)) return dir;
    }
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return await getApplicationSupportDirectory();
    }
  }

  /// Klasörü (gerekirse) kurar ve içine gerçekten yazılabildiğini ÖLÇER —
  /// Android'de izin durumu ancak böyle kesin bilinir.
  static Future<bool> _writable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(p.join(dir.path, '.dosyaokuyucu_yazma_denemesi'));
      await probe.writeAsString('x', flush: true);
      await probe.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}

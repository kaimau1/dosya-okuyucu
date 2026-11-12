import 'package:path/path.dart' as p;

/// **Gizli bölge** — kasa (Güvenlik G10.3 + G2.8, 2026-11-12).
///
/// Kasadan açılan dosyanın düz kopyası uygulamanın özel önbelleğinde
/// (`<cache>/vault_open/`) durur. Bu kopya:
/// * "Son açılanlar"a, açılış geçmişine ve başlatıcı kısayollarına YAZILMAZ
///   (önceden yazılıyordu: kasadaki dosyanın adı kasa kilitliyken ana sayfada
///   görünüyordu);
/// * kasa ekranından açılan görüntüleyici ekrandayken ([active]) hiçbir AI
///   isteği çıkmaz (`AiPool.run`), otomatik tur da kasa klasörlerine girmez.
abstract final class PrivateZone {
  /// `SecureVault.folderName` ile aynı (test denetler; çekirdek fm'e bağlanmasın).
  static const vaultFolder = '.DosyaOkuyucuKasa';

  /// `SecureVault._tempDir` alt klasör adı.
  static const vaultTemp = 'vault_open';

  static int _depth = 0;

  /// Kasa ekranından açılmış bir görüntüleyici ekranda mı?
  static bool get active => _depth > 0;

  /// [path] kasanın şifreli klasöründe ya da düz açma önbelleğinde mi?
  static bool isPrivatePath(String path) {
    for (final s in p.split(path)) {
      if (s == vaultTemp || s.toLowerCase() == vaultFolder.toLowerCase()) {
        return true;
      }
    }
    return false;
  }

  /// [body] süresince gizli bölge açık (iç içe güvenli).
  static Future<T> run<T>(Future<T> Function() body) async {
    _depth++;
    try {
      return await body();
    } finally {
      _depth--;
    }
  }
}

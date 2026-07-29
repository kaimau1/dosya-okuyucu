import 'fs_scan.dart';

/// **Klasör kilidi** — Önemli Dosyalar gibi klasörleri PIN arkasına alır.
///
/// ## Dürüst sınır (kullanıcıya da böyle yazılır)
/// Bu bir **gizlilik perdesi**, cihaz güvenliği değil: dosyalar şifrelenmez,
/// diskte oldukları yerde durur ve başka bir dosya yöneticisiyle ya da telefon
/// bilgisayara takılarak görülebilir. Amaç, telefonu eline alan birinin
/// galeride/listede o klasörü görmemesi. Gerçek şifreleme ayrı bir iş
/// (dosyaların kendisini şifrelemek gerekir) ve kullanıcıya bunu "güvenlik"
/// diye satmak yanlış olurdu.
///
/// PIN düz metin saklanmaz; tuzlanmış tekrarlı FNV-1a özeti tutulur. `crypto`
/// bağımlılığı eklemedik: paketin tamamı bu tek kullanım için APK'ya girerdi
/// ve tehdit modeli (meraklı göz) böyle bir maliyeti hak etmiyor.
abstract final class FolderLock {
  /// Özetin sürüm eki — ileride algoritma değişirse eski özet tanınsın.
  static const _prefix = 'v1';

  /// Tekrar sayısı: kaba kuvvet denemesini yavaşlatır, açılışta hissedilmez.
  static const _rounds = 20000;

  /// PIN'in saklanabilir özeti.
  static String hashPin(String pin, {String salt = 'dosya-okuyucu'}) {
    var hash = 0xcbf29ce484222325;
    void mix(String text) {
      for (final unit in text.codeUnits) {
        hash ^= unit;
        hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
      }
    }

    mix('$salt|${pin.trim()}');
    for (var i = 0; i < _rounds; i++) {
      mix(hash.toRadixString(16));
    }
    return '$_prefix:${hash.toRadixString(16)}';
  }

  static bool verify(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    return hashPin(pin) == storedHash;
  }

  /// [path] kilitli mi? Kilitli bir klasörün **altındaki her şey** kilitlidir.
  static bool isLocked(String path, Iterable<String> lockedFolders) {
    for (final locked in lockedFolders) {
      if (locked.isEmpty) continue;
      if (FsPaths.isInside(locked, path)) return true;
    }
    return false;
  }

  /// Listeden kilitli klasörlerin içindekileri ayıklar.
  ///
  /// Galeriler ve kategori listeleri tüm depolamayı tarar; kilitli klasördeki
  /// fotoğraf "Görüntüler" ızgarasında görünürse kilit hiçbir işe yaramaz.
  static List<T> filterOut<T>(
    Iterable<T> items,
    Iterable<String> lockedFolders,
    String Function(T) pathOf,
  ) {
    final locked = lockedFolders.where((l) => l.isNotEmpty).toList();
    if (locked.isEmpty) return items.toList();
    return [
      for (final item in items)
        if (!isLocked(pathOf(item), locked)) item,
    ];
  }
}

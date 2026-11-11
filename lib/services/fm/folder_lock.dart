import 'dart:convert';

import 'package:flutter/foundation.dart' show visibleForTesting;

import 'fs_scan.dart';
import 'pin_kdf.dart';
import 'vault_crypto.dart';

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
/// PIN düz metin saklanmaz. G3.3 (2026-11-11): özet `v2:<tur>:<tuz>:<özet>`
/// — rastgele 16 bayt tuz + PBKDF2-HMAC-SHA256 ([targetIterations] tur),
/// karşılaştırma sabit zamanlı ([verifyAsync]). Eski `v1:` (sabit tuzlu
/// tekrarlı FNV-1a — kriptografik değil, aynı PIN her telefonda aynı özet)
/// hâlâ doğrulanır; doğru PIN girilince v2'ye çevrilir ([needsUpgrade],
/// `AppState.verifyLockPin`). Aynı PIN kasanın anahtarını da açtığı için
/// özet, kasa kadar güçlü türetilir.
abstract final class FolderLock {
  /// Özetin sürüm eki — ileride algoritma değişirse eski özet tanınsın.
  static const _prefix = 'v1';

  /// Tekrar sayısı: kaba kuvvet denemesini yavaşlatır, açılışta hissedilmez.
  static const _rounds = 20000;

  /// Yeni özetin tur sayısı (testler küçültür; doğrulama özetteki turu kullanır).
  @visibleForTesting
  static int targetIterations = VaultCrypto.pinIterations;

  static const _v2 = 'v2';

  /// PIN'in saklanabilir özeti (v2, G3.3).
  static Future<String> hashPinSecure(String pin) async {
    final salt = VaultCrypto.randomBytes(16);
    final iter = targetIterations;
    final key = await PinKdf.derive(pin, salt, iter);
    return '$_v2:$iter:${base64Encode(salt)}:${base64Encode(key)}';
  }

  /// v1 ya da v2 özeti doğrular (v2 sabit zamanlı karşılaştırma).
  static Future<bool> verifyAsync(String pin, String? storedHash) async {
    if (storedHash == null || storedHash.isEmpty) return false;
    if (!storedHash.startsWith('$_v2:')) return verify(pin, storedHash);
    final parts = storedHash.split(':');
    if (parts.length != 4) return false;
    final iter = int.tryParse(parts[1]);
    if (iter == null || iter <= 0) return false;
    try {
      final salt = base64Decode(parts[2]);
      final want = base64Decode(parts[3]);
      final got = await PinKdf.derive(pin, salt, iter);
      return VaultCrypto.constantTimeEquals(got, want);
    } catch (_) {
      return false;
    }
  }

  /// Özet eski biçimde ya da hedeften az turlu mu (doğru PIN'de yenilenir)?
  static bool needsUpgrade(String storedHash) {
    if (storedHash.isEmpty) return false;
    if (!storedHash.startsWith('$_v2:')) return true;
    final iter = int.tryParse(storedHash.split(':').elementAtOrNull(1) ?? '');
    return iter == null || iter < targetIterations;
  }

  /// **Eski (v1)** özet — yalnız göç ve eski kayıtları doğrulamak için.
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

  /// Yalnız **v1** özeti (eşzamanlı) doğrular; v2 için [verifyAsync].
  static bool verify(String pin, String? storedHash) {
    if (storedHash == null || storedHash.isEmpty) return false;
    return VaultCrypto.constantTimeEquals(
        utf8.encode(hashPin(pin)), utf8.encode(storedHash));
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

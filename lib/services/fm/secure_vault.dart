import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'file_ops.dart';
import 'fm_env.dart';
import 'fs_events.dart';
import 'native_extras.dart';
import 'vault_crypto.dart';

/// Kasadaki bir dosya.
@immutable
class VaultItem {
  /// Kasadaki şifreli dosyanın adı (rastgele kimlik — gerçek ad sızmasın).
  final String id;
  final String name;
  final int size;
  final int addedMs;

  /// Kasaya alınmadan önceki klasörü (geri çıkarırken buraya döner).
  final String originalDir;

  const VaultItem({
    required this.id,
    required this.name,
    required this.size,
    required this.addedMs,
    required this.originalDir,
  });

  Map<String, Object> toJson() => {
        'id': id,
        'name': name,
        'size': size,
        'added': addedMs,
        'dir': originalDir,
      };

  static VaultItem? fromJson(Object? raw) {
    if (raw is! Map || raw['id'] is! String || raw['name'] is! String) {
      return null;
    }
    return VaultItem(
      id: raw['id'] as String,
      name: raw['name'] as String,
      size: (raw['size'] as num?)?.toInt() ?? 0,
      addedMs: (raw['added'] as num?)?.toInt() ?? 0,
      originalDir: raw['dir'] as String? ?? '',
    );
  }
}

/// **Şifreli kasa** (2026-10-18, kullanıcının onayladığı öneri: *"parmak
/// iziyle açılan şifreli klasör — kimlik ve tapu taramaları için"*).
///
/// Mevcut **gizleme**den ([HiddenVault]) farkı: orada dosya yalnız saklanır
/// (bilgisayara takınca görünür); burada içerik **şifrelenir** — telefon
/// başka bir cihaza bağlansa da dosyalar okunamaz. Kriptografi
/// [VaultCrypto]'da.
///
/// Anahtar düzeni:
/// - Rastgele 32 baytlık **ana anahtar**; dosyalar ve dizin onunla şifreli.
/// - Ana anahtar PIN'den türetilen anahtarla sarılı olarak kasanın kendi
///   klasöründe (`vault.json`): uygulama silinip kurulsa da PIN'le açılır.
/// - Parmak izi açıksa ana anahtarın Android Keystore ile sarılmış bir kopyası
///   ayarlarda: yalnız BU telefonda, biyometrik doğrulamadan sonra açılır.
///
/// Kilit açıkken ana anahtar yalnız bellekte; [lock] onu siler. Açılan
/// dosyanın düz kopyası uygulamanın önbelleğinde durur ve kilitlenince
/// silinir.
class SecureVault extends ChangeNotifier {
  SecureVault._();

  static final instance = SecureVault._();

  static const folderName = '.DosyaOkuyucuKasa';
  static const _kBio = 'vault_bio_key';
  static const _metaFile = 'vault.json';
  static const _indexFile = 'index.dvk';

  /// Testler kasayı geçici bir klasöre yönlendirir.
  @visibleForTesting
  static String? debugRoot;

  Uint8List? _master;
  List<VaultItem> _items = const [];

  bool get unlocked => _master != null;
  List<VaultItem> get items => List.unmodifiable(_items);

  String get dir => debugRoot ?? p.join(FmEnv.primaryRoot, folderName);

  File get _meta => File(p.join(dir, _metaFile));
  File get _index => File(p.join(dir, _indexFile));

  bool get exists => _meta.existsSync();

  /// Kasayı kurar ve açar.
  Future<void> create(String pin) async {
    final d = Directory(dir);
    await d.create(recursive: true);
    // Galeri uygulamaları kasa klasörünü taramasın.
    await File(p.join(dir, '.nomedia')).writeAsString('');
    final master = VaultCrypto.randomBytes(32);
    await _writeMeta(pin, master);
    _master = master;
    _items = const [];
    await _saveIndex();
    notifyListeners();
  }

  Future<void> _writeMeta(String pin, Uint8List master) async {
    final salt = VaultCrypto.randomBytes(16);
    final kek = await Isolate.run(() => VaultCrypto.deriveKey(pin, salt));
    await _meta.writeAsString(jsonEncode({
      'v': 1,
      'salt': base64Encode(salt),
      'iter': VaultCrypto.pinIterations,
      'key': base64Encode(VaultCrypto.seal(kek, master)),
    }));
  }

  /// PIN'le açar; PIN yanlışsa false.
  Future<bool> unlockWithPin(String pin) async {
    try {
      final meta = jsonDecode(await _meta.readAsString()) as Map;
      final salt = base64Decode(meta['salt'] as String);
      final iter = (meta['iter'] as num).toInt();
      final kek = await Isolate.run(
          () => VaultCrypto.deriveKey(pin, salt, iterations: iter));
      final master =
          VaultCrypto.open(kek, base64Decode(meta['key'] as String));
      if (master == null) return false;
      await _open(master);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> _open(Uint8List master) async {
    _master = master;
    await _loadIndex();
    notifyListeners();
  }

  /// Parmak izi bu telefonda kurulu mu?
  Future<bool> get biometricEnabled async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_kBio) != null;
    } catch (_) {
      return false;
    }
  }

  /// Kilit AÇIKKEN çağrılır: ana anahtarın Keystore sarılı kopyasını saklar.
  Future<bool> enableBiometric() async {
    final master = _master;
    if (master == null) return false;
    final wrapped = await NativeExtras.wrapKey(master);
    if (wrapped == null) return false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kBio, base64Encode(wrapped));
    notifyListeners();
    return true;
  }

  Future<void> disableBiometric() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kBio);
    notifyListeners();
  }

  /// Biyometrik doğrulama (çağıran yapar) SONRASI açma.
  Future<bool> unlockWithBiometricKey() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kBio);
      if (raw == null) return false;
      final master = await NativeExtras.unwrapKey(base64Decode(raw));
      if (master == null || master.length != 32) return false;
      await _open(master);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// PIN'i değiştirir (kilit açıkken).
  Future<bool> changePin(String newPin) async {
    final master = _master;
    if (master == null) return false;
    await _writeMeta(newPin, master);
    return true;
  }

  /// Kilitler: anahtar bellekten, açılmış düz kopyalar önbellekten silinir.
  Future<void> lock() async {
    _master = null;
    _items = const [];
    notifyListeners();
    await clearTemp();
  }

  static Future<Directory> _tempDir() async {
    final base = await getTemporaryDirectory();
    return Directory(p.join(base.path, 'vault_open'));
  }

  static Future<void> clearTemp() async {
    try {
      final d = await _tempDir();
      if (d.existsSync()) await d.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> _loadIndex() async {
    final master = _master;
    if (master == null) return;
    if (!_index.existsSync()) {
      _items = const [];
      return;
    }
    final plain = VaultCrypto.open(master, await _index.readAsBytes());
    if (plain == null) throw const VaultCorrupt();
    final list = jsonDecode(utf8.decode(plain));
    _items = [
      if (list is List)
        for (final e in list)
          if (VaultItem.fromJson(e) case final item?) item,
    ]..sort((a, b) => b.addedMs.compareTo(a.addedMs));
  }

  Future<void> _saveIndex() async {
    final master = _master;
    if (master == null) return;
    final plain = utf8.encode(jsonEncode([for (final i in _items) i.toJson()]));
    final tmp = File('${_index.path}.tmp');
    await tmp.writeAsBytes(VaultCrypto.seal(master, Uint8List.fromList(plain)),
        flush: true);
    await tmp.rename(_index.path);
  }

  /// Dosyaları kasaya ŞİFRELEYEREK taşır: önce şifreli kopya yazılır ve
  /// doğrulanır, ancak sonra aslı silinir.
  Future<FmOpResult> add(
    List<String> paths, {
    void Function(FmProgress)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final master = _master;
    if (master == null) return const FmOpResult(errors: ['locked']);
    var ok = 0;
    final errors = <String>[];
    final transfers = <FmTransfer>[];
    final files = [
      for (final path in paths)
        if (FileSystemEntity.isFileSync(path)) path,
    ];
    final skipped = paths.length - files.length;
    for (var i = 0; i < files.length; i++) {
      if (isCancelled?.call() ?? false) {
        return FmOpResult(
            succeeded: ok,
            skipped: skipped,
            errors: errors,
            cancelled: true,
            transfers: transfers);
      }
      final src = files[i];
      onProgress?.call(FmProgress(i, files.length, p.basename(src)));
      final id = base64Url
          .encode(VaultCrypto.randomBytes(12))
          .replaceAll('=', '');
      final dst = p.join(dir, '$id.dvk');
      try {
        final size = await File(src).length();
        await Isolate.run(() => VaultCrypto.encryptFile(src, dst, master));
        // Doğrulama: şifreli dosya beklenen boyda mı (başlık + içerik + mac).
        if (await File(dst).length() != size + 4 + 16 + 32) {
          throw const VaultCorrupt();
        }
        _items = [
          VaultItem(
            id: id,
            name: p.basename(src),
            size: size,
            addedMs: DateTime.now().millisecondsSinceEpoch,
            originalDir: p.dirname(src),
          ),
          ..._items,
        ];
        await _saveIndex();
        await File(src).delete();
        transfers.add(FmTransfer(src, dst));
        ok++;
      } catch (e) {
        errors.add('${p.basename(src)}: $e');
        try {
          if (File(dst).existsSync()) await File(dst).delete();
        } catch (_) {}
      }
    }
    onProgress?.call(FmProgress(files.length, files.length, ''));
    notifyListeners();
    FsEvents.changed();
    return FmOpResult(
        succeeded: ok, skipped: skipped, errors: errors, transfers: transfers);
  }

  /// Görüntülemek için geçici düz kopya (kilitlenince silinir).
  Future<String> openTemp(VaultItem item) async {
    final master = _master;
    if (master == null) throw StateError('locked');
    final tmp = await _tempDir();
    await tmp.create(recursive: true);
    final out = p.join(tmp.path, item.name);
    if (!File(out).existsSync()) {
      final src = p.join(dir, '${item.id}.dvk');
      await Isolate.run(() => VaultCrypto.decryptFile(src, out, master));
    }
    return out;
  }

  /// Kasadan çıkarır: düz dosya ilk klasörüne (yoksa İndirilenler'e) yazılır,
  /// şifreli kopya silinir. Yazılan yolu döner.
  Future<String> restore(VaultItem item) async {
    final master = _master;
    if (master == null) throw StateError('locked');
    var targetDir = item.originalDir;
    if (targetDir.isEmpty || !Directory(targetDir).existsSync()) {
      targetDir = p.join(FmEnv.primaryRoot, 'Download');
      await Directory(targetDir).create(recursive: true);
    }
    final out = FileOps.uniquePath(p.join(targetDir, item.name));
    final src = p.join(dir, '${item.id}.dvk');
    await Isolate.run(() => VaultCrypto.decryptFile(src, out, master));
    await _remove(item);
    FsEvents.changed();
    return out;
  }

  /// Kalıcı siler (şifreli kopya).
  Future<void> delete(VaultItem item) => _remove(item);

  Future<void> _remove(VaultItem item) async {
    try {
      await File(p.join(dir, '${item.id}.dvk')).delete();
    } catch (_) {}
    _items = [for (final i in _items) if (i.id != item.id) i];
    await _saveIndex();
    notifyListeners();
  }

  @visibleForTesting
  void debugReset() {
    _master = null;
    _items = const [];
  }
}

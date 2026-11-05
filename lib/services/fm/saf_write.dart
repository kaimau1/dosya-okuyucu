import 'dart:io';

import 'package:path/path.dart' as p;

import 'app_storage_service.dart';

/// **SD kart SAF yazma** (Faz 41 / madde 1 — A7.2, 2026-11-05).
///
/// Android 11+ çıkarılabilir SD karta doğrudan dosya yolu ile YAZDIRMAZ
/// (okuma serbest, yazma `EACCES`/`EROFS`). Tek yol Storage Access Framework:
/// kullanıcı kartın kökünü (ya da bir klasörünü) bir kez seçer, uygulama kalıcı
/// ağaç izni alır (`AppStorageService.safPickTree`). Bu sınıf yol tabanlı
/// hedefi (`/storage/1A2B-3C4D/DCIM/Tatil`) izinli ağaca ([SafRoot]) eşler ve
/// kopyalamayı SAF köprüsünden yapar. `FileOps` yalnız yol yazılamadığında
/// buraya düşer — iç bellekte ve yazılabilir kartta eski yol aynen çalışır.
abstract final class SafWrite {
  /// `/storage/<birim>/…` ise birim kimliği ve birim içi göreli parçalar;
  /// iç bellek (`/storage/emulated/…`) ya da başka yol → null. Saf, testli.
  static (String, List<String>)? splitVolumePath(String path) {
    final parts = p.split(p.normalize(path));
    if (parts.length < 3 || parts[0] != '/' || parts[1] != 'storage') {
      return null;
    }
    final id = parts[2];
    if (id == 'emulated' || id == 'self') return null;
    return (id, parts.sublist(3));
  }

  /// [destDir]'i izinli ağaçlardan birine eşler: (ağaç URI'si, ağacın İÇİNDE
  /// kalan klasör parçaları). Uygun izin yoksa null. Saf, testli.
  static (String, List<String>)? resolve(String destDir, List<SafRoot> roots) {
    final split = splitVolumePath(destDir);
    if (split == null) return null;
    final (volume, rel) = split;
    (String, List<String>)? best;
    var bestDepth = -1;
    for (final r in roots) {
      if (!r.writable || r.volumeId != volume) continue;
      final treeRel = _treeRelative(r.uri);
      if (treeRel == null) continue;
      if (treeRel.length > rel.length) continue;
      var match = true;
      for (var i = 0; i < treeRel.length; i++) {
        if (treeRel[i] != rel[i]) {
          match = false;
          break;
        }
      }
      // En derin (en dar) izinli ağaç seçilir: daha az klasör yürünür.
      if (match && treeRel.length > bestDepth) {
        bestDepth = treeRel.length;
        best = (r.uri, rel.sublist(treeRel.length));
      }
    }
    return best;
  }

  /// Ağaç URI'sinin birim içindeki klasör yolu (`…/tree/1A2B%3ADCIM%2FTatil`
  /// → `[DCIM, Tatil]`, kök → `[]`).
  static List<String>? _treeRelative(String uri) {
    const marker = '/tree/';
    final at = uri.indexOf(marker);
    if (at < 0) return null;
    var id = uri.substring(at + marker.length);
    final slash = id.indexOf('/');
    if (slash >= 0) id = id.substring(0, slash);
    id = Uri.decodeComponent(id);
    final colon = id.indexOf(':');
    if (colon < 0) return null;
    final rest = id.substring(colon + 1);
    return rest.isEmpty
        ? const []
        : rest.split('/').where((s) => s.isNotEmpty).toList();
  }

  /// Yazılabilirlik oturum önbelleği (birim → yazılabilir mi).
  static final Map<String, bool> _writable = {};

  /// Bu hedef SAF gerektiriyor mu? Çıkarılabilir birimde ve yol ile küçük bir
  /// deneme dosyası yazılamıyorsa evet. Sonuç birim başına bir kez ölçülür.
  static Future<bool> needsSaf(String destDir) async {
    final split = splitVolumePath(destDir);
    if (split == null) return false;
    final volume = split.$1;
    final known = _writable[volume];
    if (known != null) return !known;
    var ok = false;
    try {
      final probe = File(p.join(destDir, '.dosya_yazma_denemesi'));
      await probe.writeAsBytes(const [0], flush: true);
      await probe.delete();
      ok = true;
    } catch (_) {
      ok = false;
    }
    _writable[volume] = ok;
    return !ok;
  }

  /// Testler için önbelleği sıfırla.
  static void resetForTest() => _writable.clear();

  /// [sources]'u (dosya ya da klasör) SAF ile [destDir]'e kopyalar; [move]
  /// ise başarıyla kopyalanan kaynak silinir. Dönen: (başarılı kaynaklar,
  /// hata iletileri). İzin yoksa tek hata: [noGrant].
  static const noGrant = 'sd_needs_grant';

  static Future<(List<String>, List<String>)> transfer(
    List<String> sources,
    String destDir, {
    required bool move,
    bool Function()? isCancelled,
  }) async {
    final target = resolve(destDir, await AppStorageService.safRoots());
    if (target == null) return (const <String>[], const [noGrant]);
    var parent = target.$1;
    for (final seg in target.$2) {
      final next = await _childDir(parent, seg);
      if (next == null) return (const <String>[], ['$seg: mkdir']);
      parent = next;
    }
    final done = <String>[];
    final errors = <String>[];
    for (final src in sources) {
      if (isCancelled?.call() ?? false) break;
      final ok = await _copyInto(parent, src);
      if (ok) {
        done.add(src);
        if (move) {
          try {
            if (await FileSystemEntity.isDirectory(src)) {
              await Directory(src).delete(recursive: true);
            } else {
              await File(src).delete();
            }
          } catch (_) {
            errors.add('${p.basename(src)}: delete');
          }
        }
      } else {
        errors.add('${p.basename(src)}: saf');
      }
    }
    return (done, errors);
  }

  static Future<String?> _childDir(String parentUri, String name) async {
    for (final e in await AppStorageService.safList(parentUri)) {
      if (e.isDir && e.name == name) return e.uri;
    }
    return AppStorageService.safMkdir(parentUri, name);
  }

  static Future<bool> _copyInto(String parentUri, String src) async {
    final type = await FileSystemEntity.type(src);
    final name = p.basename(src);
    if (type == FileSystemEntityType.directory) {
      final dir = await _childDir(parentUri, name);
      if (dir == null) return false;
      var ok = true;
      await for (final child in Directory(src).list(followLinks: false)) {
        ok = await _copyInto(dir, child.path) && ok;
      }
      return ok;
    }
    if (type != FileSystemEntityType.file) return false;
    return await AppStorageService.safCopyFromFile(parentUri, src, name) !=
        null;
  }
}

import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Video küçük resimlerini üretir ve **diskte** önbelleğe alır.
///
/// *Niye disk önbelleği:* küçük resim çıkarmak (native MediaMetadataRetriever)
/// dosya başına onlarca ms sürer; her kaydırmada yeniden üretmek listeyi
/// kastırır. Anahtar = yol + değişiklik zamanı + boy → dosya değişirse
/// küçük resim kendiliğinden tazelenir.
abstract final class ThumbnailCache {
  static final _plugin = FcNativeVideoThumbnail();

  /// Aynı dosya için paralel istekleri tek işe indirger.
  static final Map<String, Future<String?>> _inFlight = {};

  /// Üretilemeyen dosyalar (bozuk/desteklenmeyen codec) — tekrar denenmez.
  ///
  /// **Sınırlı (2026-08-07):** liste sınırsızdı; on binlerce videosu olan bir
  /// telefonda kaydırdıkça büyüyor ve süreç boyunca hiç boşalmıyordu (her
  /// kayıt bir tam dosya yolu = yüzlerce bayt). Sınıra gelince en eski yarısı
  /// düşürülür — en kötü ihtimalle o dosyalar için küçük resim bir kez daha
  /// denenir, ki bu zaten hızlıca başarısız olan bir çağrıdır.
  static const _failedLimit = 512;
  static final Set<String> _failed = <String>{};

  static void _markFailed(String path) {
    if (_failed.length >= _failedLimit) {
      // `Set` ekleme sırasını korur → ilk yarısı en eskiler.
      for (final old in _failed.take(_failedLimit ~/ 2).toList()) {
        _failed.remove(old);
      }
    }
    _failed.add(path);
  }

  static Directory? _dir;
  static bool _pruned = false;

  /// Küçük resim dosya adı (saf fonksiyon → birim testli).
  /// FNV-1a: `crypto` bağımlılığı eklemeye değmez.
  static String cacheName(String path, int modifiedMs, int size) {
    var hash = 0xcbf29ce484222325;
    for (final unit in '$path|$modifiedMs|$size'.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${hash.toRadixString(16)}.jpg';
  }

  static Future<Directory> _cacheDir() async {
    final cached = _dir;
    if (cached != null) return cached;
    final base = await getTemporaryDirectory();
    final dir = Directory(p.join(base.path, 'video_thumbs'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    _dir = dir;
    unawaited(_prune(dir));
    return dir;
  }

  /// [path] videosunun küçük resmini döndürür (yoksa üretir). Üretilemezse
  /// null — çağıran ikonu gösterir.
  static Future<String?> forVideo(
    String path, {
    int size = 256,
  }) {
    if (_failed.contains(path)) return Future.value(null);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _generate(path, size);
    _inFlight[path] = future;
    // Bellek sızmasın: iş bitince kaydı düşür.
    future.whenComplete(() => _inFlight.remove(path));
    return future;
  }

  static Future<String?> _generate(String path, int size) async {
    try {
      final stat = File(path).statSync();
      final dir = await _cacheDir();
      final dest = p.join(
        dir.path,
        cacheName(path, stat.modified.millisecondsSinceEpoch, size),
      );
      if (File(dest).existsSync()) return dest;

      final ok = await _plugin.saveThumbnailToFile(
        srcFile: path,
        destFile: dest,
        width: size,
        height: size,
        format: 'jpeg',
        quality: 80,
      );
      if (!ok || !File(dest).existsSync()) {
        _markFailed(path);
        return null;
      }
      return dest;
    } catch (_) {
      _markFailed(path);
      return null;
    }
  }

  /// Önbellek sınırı: 600 dosyayı aşınca en eskiler silinir (oturumda bir kez).
  static Future<void> _prune(Directory dir) async {
    if (_pruned) return;
    _pruned = true;
    try {
      final files = dir.listSync().whereType<File>().toList();
      if (files.length <= 600) return;
      files.sort((a, b) =>
          a.statSync().modified.compareTo(b.statSync().modified));
      for (final f in files.take(files.length - 600)) {
        try {
          f.deleteSync();
        } catch (_) {}
      }
    } catch (_) {}
  }
}

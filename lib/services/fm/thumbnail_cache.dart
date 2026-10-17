import 'dart:async';
import 'dart:io';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'disk_housekeeping.dart';

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

  /// Aynı anda en çok kaç küçük resim ÜRETİLİR (2026-10-17 başarım turu).
  ///
  /// Eklenti her isteği `Dispatchers.Default`a atıyor: çekirdek sayısı kadar
  /// (8) `MediaMetadataRetriever` aynı anda video karesi çözüyordu. Izgara
  /// kaydırılırken bütün çekirdekler kare çözmeye gidiyor, çizim izleği
  /// sıkışıp kaydırma takılıyordu; her çözücü de kendi belleğini (onlarca
  /// MB) ayırıyordu. Artık en çok [maxParallel] üretim, gerisi sırada.
  static const maxParallel = 2;
  static int _running = 0;

  /// Sırada bekleyen üretimler — SONDAN alınır (en yeni istek önce): parmak
  /// durduğunda EKRANDAKİ hücreler, kaydırırken geçilenlerden önce gelir.
  /// Eskiden ilk istenen ilk üretiliyordu ve durduğun yerdeki videolar en
  /// son geliyordu.
  static final List<(String, Completer<bool>)> _pending = [];

  /// Yol başına "hâlâ isteniyor mu?" yoklamaları. Hücre ekrandan çıkmışsa
  /// (yoklama false) sırası gelen iş hiç başlamaz — boşa kare çözülmez.
  static final Map<String, List<bool Function()>> _wanted = {};

  /// [path] videosunun küçük resmini döndürür (yoksa üretir). Üretilemezse
  /// null — çağıran ikonu gösterir.
  ///
  /// [wanted] verilirse ve sıra geldiğinde false dönüyorsa üretim atlanır
  /// (null döner, "bozuk dosya" sayılmaz). Liste hücreleri `() => mounted`
  /// verir; arka plan işleri (benzer bulma, oynatıcı kapağı) vermez.
  static Future<String?> forVideo(
    String path, {
    int size = 256,
    bool Function()? wanted,
  }) {
    if (_failed.contains(path)) return Future.value(null);
    (_wanted[path] ??= []).add(wanted ?? _always);
    final existing = _inFlight[path];
    if (existing != null) return existing;
    final future = _generate(path, size);
    _inFlight[path] = future;
    // Bellek sızmasın: iş bitince kayıtları düşür.
    future.whenComplete(() {
      _inFlight.remove(path);
      _wanted.remove(path);
    });
    return future;
  }

  static bool _always() => true;

  static bool _isWanted(String path) =>
      (_wanted[path] ?? const []).any((check) => check());

  /// Üretim izni: boş yer varsa hemen, yoksa sıraya. false = vazgeçildi.
  static Future<bool> _acquire(String path) {
    if (_running < maxParallel) {
      _running++;
      return Future.value(true);
    }
    final ticket = Completer<bool>();
    _pending.add((path, ticket));
    return ticket.future;
  }

  /// Bir üretim bitti: sıradaki İSTENEN işe yer devredilir.
  static void _release() {
    while (_pending.isNotEmpty) {
      final (path, ticket) = _pending.removeLast();
      if (!_isWanted(path)) {
        ticket.complete(false);
        continue;
      }
      ticket.complete(true); // yer devredildi, sayaç değişmez
      return;
    }
    _running--;
  }

  /// Test kancası: sıranın durumu.
  @visibleForTesting
  static ({int running, int pending}) get debugQueue =>
      (running: _running, pending: _pending.length);

  /// Test kancası: önbellek klasörü (`path_provider` testte yok) ve sıfırlama.
  @visibleForTesting
  static void debugReset({Directory? cacheDir}) {
    _dir = cacheDir;
    _pruned = cacheDir != null;
    _running = 0;
    _pending.clear();
    _wanted.clear();
    _inFlight.clear();
    _failed.clear();
  }

  /// Test kancası: üretimi yapan çağrı (eklenti yerine).
  @visibleForTesting
  static Future<bool> Function(String src, String dest, int size)? debugExtract;

  static Future<String?> _generate(String path, int size) async {
    String dest;
    try {
      final stat = File(path).statSync();
      final dir = await _cacheDir();
      dest = p.join(
        dir.path,
        cacheName(path, stat.modified.millisecondsSinceEpoch, size),
      );
      // Diskte varsa sıra beklemeden (üretim yok).
      if (File(dest).existsSync()) return dest;
    } catch (_) {
      _markFailed(path);
      return null;
    }
    if (!await _acquire(path)) return null; // hücre gitti — vazgeçildi
    try {
      final extract = debugExtract;
      final ok = extract != null
          ? await extract(path, dest, size)
          : await _plugin.saveThumbnailToFile(
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
    } finally {
      _release();
    }
  }

  /// Önbellek sınırı: 600 dosyayı aşınca en eskiler silinir (oturumda bir
  /// kez, izolatta — bkz. [DiskCache]).
  static const cacheLimit = 600;

  static Future<void> _prune(Directory dir) async {
    if (_pruned) return;
    _pruned = true;
    await DiskCache.prune(dir.path, cacheLimit);
  }
}

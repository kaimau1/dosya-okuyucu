import 'dart:async';

import '../../models/fs_entry.dart';
import '../../models/media_resize.dart';
import 'resize_memory.dart';
import 'video_transcode.dart';

/// **Videoyu küçültünce tahmini boyut** — liste satırı ve Yer aç kartındaki
/// "Boyut düşür" kısayolları için (2026-11-25, kullanıcı: *"büyük dosyalarda
/// videolara boyut düşür seçeneği koyalım ve tahmini boyutu yazalım"*).
///
/// Tahmin, ayar sayfasının kullandığı AYNI hesaptır
/// ([MediaSourceInfo.estimatedBytes]) ve son kullanılan boyut düşürme
/// ayarıyla (yoksa varsayılan) yapılır — kısayolun yazdığı sayı ile ayar
/// sayfasının açılışta yazdığı sayı aynı olsun.
///
/// Ölçüm (`VideoTranscoder.probe`, yerel çağrı) dosya başına BİR kez yapılır
/// ve SIRAYLA yürür: liste kaydırılırken onlarca satır aynı anda ölçüm
/// istemesin. Sonuçlar bellekte (yol + boyut + değişim anı).
abstract final class VideoShrinkEstimate {
  static const _maxCache = 400;
  static final Map<String, Future<int?>> _cache = {};
  static Future<void> _tail = Future<void>.value();

  /// [e] küçültülünce tahmini boyut (bayt); ölçülemezse ya da video değilse
  /// null.
  static Future<int?> of(FsEntry e) {
    if (e.isDir || e.category != FmCategory.video) return Future.value();
    final key = '${e.path}|${e.sizeBytes}|${e.modifiedMs}';
    final hit = _cache[key];
    if (hit != null) return hit;
    if (_cache.length >= _maxCache) _cache.clear();
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    final f = previous
        .then((_) => _compute(e))
        .catchError((Object _) => null)
        .whenComplete(done.complete);
    return _cache[key] = f;
  }

  /// Birden çok videonun toplamı: (önce, sonra). Hiçbiri ölçülemezse null.
  static Future<({int before, int after})?> total(List<FsEntry> videos) async {
    var before = 0;
    var after = 0;
    var known = 0;
    for (final e in videos) {
      final est = await of(e);
      if (est == null) continue;
      known++;
      before += e.sizeBytes;
      after += est;
    }
    return known == 0 ? null : (before: before, after: after);
  }

  static Future<int?> _compute(FsEntry e) async {
    final VideoProbe? probe;
    try {
      probe = await VideoTranscoder.probe(e.path);
    } catch (_) {
      return null;
    }
    if (probe == null) return null;
    final options = await ResizeMemory.load() ?? const MediaResizeOptions();
    final info = MediaSourceInfo(
      name: e.name,
      path: e.path,
      sizeBytes: e.sizeBytes,
      isVideo: true,
      width: probe.width,
      height: probe.height,
      fps: probe.fps,
      durationMs: probe.durationMs,
    );
    return info.estimatedBytes(options);
  }

  /// Testler için.
  static void resetForTest() {
    _cache.clear();
    _tail = Future<void>.value();
  }
}

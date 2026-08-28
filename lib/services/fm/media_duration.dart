import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart';

import 'fm_env.dart';

/// **Video süresi** — küçük resmin köşesinde yazan `12:34`.
///
/// Kullanıcı isteği (2026-08-28): *"videolarda dk ve sn'si önizlemedeyken sağ
/// alt köşesinde yazmalı"*. Bir video listesinde en çok sorulan soru "bu ne
/// kadar sürüyor"; açmadan görebilmek gerekiyor.
///
/// ## Niçin ayrı bir önbellek
/// Süreyi okumak native `MediaMetadataRetriever` çağrısı (dosya başına
/// onlarca ms). Küçük resim önbelleğine (`ThumbnailCache`) yazılamazdı: o,
/// diskte JPEG tutuyor ve anahtarı boyutu da içeriyor; süre ise boydan
/// bağımsız. Bu yüzden aynı desende AYRI ve küçük bir kayıt: yol+değişiklik
/// zamanı → saniye.
///
/// Kayıt JSON olarak uygulamanın kendi dizinindedir; dosya değişirse
/// (değişiklik zamanı) kendiliğinden tazelenir.
abstract final class MediaDuration {
  static const _fileName = 'media_durations.json';

  /// Kayıt sınırı. On binlerce videosu olan telefonda dosya şişmesin; sınıra
  /// gelince en eski yarısı düşer (yeniden ölçmek yalnız bir çağrı).
  static const maxEntries = 4000;

  /// `yol|mtime` → saniye. Bellekte tutulur, disk yalnız kalıcılık için.
  static final Map<String, int> _cache = {};

  /// Aynı dosya için paralel istekleri tek işe indirger (ızgarada aynı hücre
  /// birkaç kez çizilebiliyor).
  static final Map<String, Future<Duration?>> _inFlight = {};

  static Future<void>? _loadFuture;
  static bool _dirty = false;
  static Timer? _saveTimer;

  /// Saf fonksiyon (testli): önbellek anahtarı.
  static String keyFor(String path, int modifiedMs) => '$path|$modifiedMs';

  /// Saf fonksiyon (testli): `12:34` / `1:02:03`.
  ///
  /// Saat YALNIZ gerekiyorsa yazılır — kısa videoların yanında `00:12:34`
  /// gürültü olurdu. Dakika saatle birlikte iki hane olur (`1:02:03`).
  static String format(Duration duration) {
    final total = duration.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final ss = seconds.toString().padLeft(2, '0');
    if (hours == 0) return '$minutes:$ss';
    return '$hours:${minutes.toString().padLeft(2, '0')}:$ss';
  }

  /// [path] videosunun süresi; okunamıyorsa null (arayüz rozet çizmez —
  /// "0:00" yazmak yanlış bilgi olurdu).
  static Future<Duration?> forVideo(String path) async {
    await _ensureLoaded();
    final modifiedMs = _modifiedMs(path);
    if (modifiedMs == null) return null;
    final key = keyFor(path, modifiedMs);
    final cached = _cache[key];
    if (cached != null) return Duration(seconds: cached);
    return _inFlight[key] ??= _measure(path, key)
      ..whenComplete(() => _inFlight.remove(key));
  }

  static Future<Duration?> _measure(String path, String key) async {
    try {
      final info = await VideoCompress.getMediaInfo(path);
      final ms = info.duration;
      if (ms == null || ms <= 0) return null;
      final seconds = (ms / 1000).round();
      _remember(key, seconds);
      return Duration(seconds: seconds);
    } catch (_) {
      // Bozuk/desteklenmeyen dosya: rozet çizilmez, liste bozulmaz.
      return null;
    }
  }

  static void _remember(String key, int seconds) {
    if (_cache.length >= maxEntries) {
      for (final old in _cache.keys.take(maxEntries ~/ 2).toList()) {
        _cache.remove(old);
      }
    }
    _cache[key] = seconds;
    _dirty = true;
    // Yazma toplanır: bir ızgara dolusu video arka arkaya ölçülürken her
    // ölçümde diske yazmak gereksiz G/Ç olurdu.
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(seconds: 2), () => unawaited(save()));
  }

  static int? _modifiedMs(String path) {
    try {
      final stat = File(path).statSync();
      if (stat.type == FileSystemEntityType.notFound) return null;
      return stat.modified.millisecondsSinceEpoch;
    } catch (_) {
      return null;
    }
  }

  static Future<void> _ensureLoaded() {
    if (FmEnv.appSupportDir.isEmpty) return Future<void>.value();
    return _loadFuture ??= _load();
  }

  static Future<void> _load() async {
    try {
      final file = File(p.join(FmEnv.appSupportDir, _fileName));
      if (!await file.exists()) return;
      final data = jsonDecode(await file.readAsString());
      if (data is! Map) return;
      data.forEach((key, value) {
        if (key is String && value is int) _cache[key] = value;
      });
    } catch (_) {
      // Bozuk kayıt: boş önbellekle devam, süreler yeniden ölçülür.
    }
  }

  static Future<void> save() async {
    if (!_dirty || FmEnv.appSupportDir.isEmpty) return;
    _dirty = false;
    try {
      await File(p.join(FmEnv.appSupportDir, _fileName))
          .writeAsString(jsonEncode(_cache), flush: true);
    } catch (_) {
      // Kalıcılık bir kolaylık; yazılamazsa süreler oturum boyu bellekte.
    }
  }

  @visibleForTesting
  static void resetForTest() {
    _cache.clear();
    _inFlight.clear();
    _loadFuture = null;
    _saveTimer?.cancel();
    _dirty = false;
  }

  /// Testler için: ölçüm yapmadan önbelleğe süre koyar.
  @visibleForTesting
  static void seed(String key, int seconds) => _cache[key] = seconds;
}

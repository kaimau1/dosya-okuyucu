import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../../core/l10n/app_strings.dart';
import '../../models/media_resize.dart';
import 'file_ops.dart';
import 'image_resize.dart' show ResizeResult;
import 'job_queue.dart';

/// Videonun **gösterim** ölçüsü (döndürme verisi uygulanmış: dikey videoda
/// kodlanmış 1920x1080, ekranda 1080x1920), süresi ve kare hızı.
class VideoProbe {
  final int width;
  final int height;
  final int durationMs;
  final double? fps;

  const VideoProbe({
    required this.width,
    required this.height,
    required this.durationMs,
    this.fps,
  });
}

/// Hedef ölçünün kaynağa nasıl uygulanacağı.
enum VideoScaleMode {
  /// Kaynağın oranı korunarak hedef kutuya sığdırılır (kademe, yüzde).
  fit,

  /// Kullanıcı hem en hem boy yazdı → birebir (oran bozulabilir).
  exactBoth,

  /// Yalnız en yazıldı → boy orandan.
  exactWidth,

  /// Yalnız boy yazıldı → en orandan.
  exactHeight,
}

/// **Video boyut düşürme — Media3 Transformer** (Faz 10, K2 (b)).
///
/// Eskiden iki motor vardı: FFmpeg (LGPL, ~15 MB, donanım → yazılım kodlayıcı
/// sırası) ve yedek `video_compress` (MediaCodec kademeleri). İkisi de kalktı:
/// `ci/MediaTranscode.kt` Android'in Media3 Transformer'ını sürüyor — donanım
/// H.264 kodlayıcı, birebir ölçü (`Presentation`), kare düşürme
/// (`FrameDropEffect`), sesi atma. Oynatıcı da Media3 olduğu için kodek
/// kümesi tek. Kodlayıcı istenen ayarı veremezse Transformer'ın kendi geri
/// çekilmesi (`setEnableFallback`) en yakın desteklenene iner.
///
/// ## Dürüst sınır — arka plan
/// Kodlama uygulama süreci içinde: görev listesinden kapatılırsa düşer
/// (bkz. `JobQueue`). Yarım kalan çıktı silinir, özgün dosyaya dokunulmaz.
abstract final class VideoTranscoder {
  static const _channel = MethodChannel('dosya_okuyucu/transcode');
  static Completer<void>? _running;
  static void Function(int percent)? _onProgress;
  static bool _wired = false;

  static void _wire() {
    if (_wired) return;
    _wired = true;
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments;
      switch (call.method) {
        case 'progress':
          if (args is int) _onProgress?.call(args);
        case 'done':
          _running?.complete();
        case 'failed':
          final m = args is Map ? args : const {};
          _running?.completeError(VideoTranscodeException(
              AppStrings.current.t('vt.failed', {
            'error': '${m['code'] ?? ''} ${m['message'] ?? ''}'.trim(),
          })));
      }
      return null;
    });
  }

  /// Kaynağın gösterim ölçüsü, süresi, kare hızı. Okunamazsa null.
  static Future<VideoProbe?> probe(String path) async {
    try {
      final m = await _channel.invokeMapMethod<String, dynamic>(
          'probe', {'path': path});
      if (m == null) return null;
      final w = (m['width'] as num?)?.toInt() ?? 0;
      final h = (m['height'] as num?)?.toInt() ?? 0;
      if (w <= 0 || h <= 0) return null;
      return VideoProbe(
        width: w,
        height: h,
        durationMs: (m['durationMs'] as num?)?.toInt() ?? 0,
        fps: (m['fps'] as num?)?.toDouble(),
      );
    } catch (_) {
      return null;
    }
  }

  static VideoScaleMode scaleModeFor(MediaResizeOptions options) {
    if (options.resolution != ResolutionChoice.custom) return VideoScaleMode.fit;
    final w = options.customWidth;
    final h = options.customHeight;
    if (w != null && h != null) return VideoScaleMode.exactBoth;
    if (w != null) return VideoScaleMode.exactWidth;
    if (h != null) return VideoScaleMode.exactHeight;
    return VideoScaleMode.fit;
  }

  /// Kaynaktan YÜKSEK kare sayısı istenmez: kodlayıcı kare kopyalar, dosya
  /// şişer, kalite artmaz ("büyütme yok" kuralının kare karşılığı).
  static int? cappedFps(int? wanted, double? sourceFps) {
    if (wanted == null) return null;
    if (sourceFps == null || sourceFps <= 0) return wanted;
    final cap = sourceFps.floor();
    return wanted > cap ? cap : wanted;
  }

  /// Donanım kodlayıcıya verilen bit hızı (bit/sn): piksel × kare ×
  /// kalite katsayısı ([videoBitsPerPixel] — tahmini boyut da AYNI sayıyı
  /// kullanıyor, yoksa tahmin ile çıkan dosya sistematik ayrışırdı).
  /// [fps] yoksa 30 varsayılır.
  static int bitrateFor(
      int width, int height, VideoQualityChoice quality, [int? fps]) {
    final rate = (fps != null && fps > 0) ? fps : 30;
    final kbps =
        (width * height * rate * videoBitsPerPixel(quality) / 1000).round();
    return kbps.clamp(300, 20000) * 1000;
  }

  static Future<ResizeResult> run(
    String path,
    MediaResizeOptions options, {
    JobHandle? handle,
    String? progressPrefix,
  }) async {
    final before = File(path).lengthSync();
    final base = p.basenameWithoutExtension(path);
    // Çıktı her zaman MP4/H.264; uzantıyı korumak (ör. .mkv) oynatıcıları
    // yanıltırdı.
    final target = FileOps.uniquePath(
      p.join(p.dirname(path), '${base}_${options.suffix}.mp4'),
    );
    final probe = await VideoTranscoder.probe(path);
    if (probe == null) {
      throw VideoTranscodeException(AppStrings.current.t('vt.unsupported'));
    }
    final wanted = targetSize(
      sourceWidth: probe.width,
      sourceHeight: probe.height,
      options: options,
    );
    final fps = cappedFps(options.frameRate, probe.fps);
    handle?.report(
        detail: _line(progressPrefix, [
      AppStrings.current
          .t('vt.engine_preparing', {'engine': AppStrings.current.t('vt.hw_encoder')})
    ]));

    _wire();
    final done = _running = Completer<void>();
    // İptal: iş kuyruğundaki düğme `handle.cancelled`ı açar; yerel işi
    // durdurup yarım dosyayı siliyoruz.
    final cancelWatch = Timer.periodic(const Duration(milliseconds: 400), (_) {
      if ((handle?.cancelled ?? false) && !done.isCompleted) {
        unawaited(cancel());
        done.completeError(const JobCancelled());
      }
    });
    _onProgress = (percent) => handle?.report(
          unit: percent / 100,
          detail: _line(progressPrefix, [
            '${wanted.width}×${wanted.height}',
            if (progressPrefix != null) '%$percent',
            AppStrings.current.t('vt.hw_encoder'),
          ]),
        );
    try {
      final started = await _channel.invokeMethod<bool>('start', {
        'path': path,
        'target': target,
        'width': wanted.width,
        'height': wanted.height,
        if (fps != null) 'fps': fps,
        'bitrate': bitrateFor(
            wanted.width, wanted.height, options.videoQuality, fps),
        'removeAudio': options.removeAudio,
      });
      if (started != true) {
        throw VideoTranscodeException(AppStrings.current.t('vt.unsupported'));
      }
      await done.future;
    } catch (_) {
      _cleanup(target);
      rethrow;
    } finally {
      cancelWatch.cancel();
      _onProgress = null;
      _running = null;
    }
    final produced = await _verifyOutput(target, probe.durationMs);
    return ResizeResult(
      sourcePath: path,
      outputPath: target,
      beforeBytes: before,
      afterBytes: File(target).lengthSync(),
      width: produced.width,
      height: produced.height,
    );
  }

  /// İlerleme satırı: boş parçalar atılır (yarım tahmin yazılmaz).
  static String _line(String? prefix, List<String> parts) => [
        if (prefix != null && prefix.isNotEmpty) prefix,
        ...parts.where((s) => s.isNotEmpty),
      ].join(' · ');

  /// Üretilen videonun **eksiksiz** olduğunu doğrular (2026-07-29 sadakat
  /// denetimi): kaydı yarıda kesilmiş bir kaynakta kodlayıcı ilk saniyeleri
  /// yazıp "bitti" diyebilir; "özgünü çöpe at" açıksa 10 dakikalık asıl
  /// giderdi. Ölçüt süre (%10 pay) — kırpma yapmıyoruz.
  static Future<({int width, int height})> _verifyOutput(
      String output, int sourceDurationMs) async {
    final probe = await VideoTranscoder.probe(output);
    if (probe == null) {
      _cleanup(output);
      throw VideoTranscodeException(
          AppStrings.current.t('vt.unreadable_output'));
    }
    if (sourceDurationMs > 0 &&
        probe.durationMs < (sourceDurationMs * 0.9).round()) {
      _cleanup(output);
      throw VideoTranscodeException(AppStrings.current.t('vt.truncated', {
        'out': (probe.durationMs / 1000).round(),
        'src': (sourceDurationMs / 1000).round(),
      }));
    }
    return (width: probe.width, height: probe.height);
  }

  static void _cleanup(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  /// Süren kodlamayı iptal eder (iş kuyruğundaki iptal düğmesi çağırır).
  static Future<void> cancel() async {
    try {
      await _channel.invokeMethod<bool>('cancel');
    } catch (_) {}
  }
}

class VideoTranscodeException implements Exception {
  final String message;
  const VideoTranscodeException(this.message);
  @override
  String toString() => message;
}

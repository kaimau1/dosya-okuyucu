import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart' as vc;

import '../../models/media_resize.dart';
import 'ffmpeg_video.dart';
import 'file_ops.dart';
import 'image_resize.dart' show ResizeResult;
import 'job_queue.dart';

/// **Video boyut düşürme** — birincil motor FFmpeg, yedek motor MediaCodec.
///
/// ## İki motor, biri yedek
/// - **FFmpeg** (`ffmpeg_kit_flutter_new_min_gpl`): istenen **birebir**
///   çözünürlük + kare sayısı, tek geçişte. Kullanıcı isteği 2026-07-29:
///   kademeler yetmiyor, "1234x568" de verilebilmeli.
/// - **video_compress** (native MediaCodec): FFmpeg herhangi bir nedenle
///   çalışmazsa (bilinmeyen kodek, cihaz kısıtı, kütüphane yüklenmemesi)
///   kademeli yola düşülür. Böylece en kötü durumda özellik yaklaşık çalışır,
///   "hiç çalışmaz" olmaz — ve hangisinin kullanıldığı iş ayrıntısında yazar.
///
/// Neden yedeği silmedik: FFmpeg yolu bu ortamda **cihazda doğrulanamıyor**
/// (Android SDK/telefon yok). Yedek olmadan olası bir aksaklık özelliği
/// tamamen kullanılamaz yapardı.
///
/// ## Dürüst sınır — arka plan
/// Kodlama native tarafta koşar ama uygulama süreci içinde: uygulama arka
/// planda kalabilir, görev listesinden **kapatılırsa** kodlama düşer
/// (bkz. `JobQueue`). Yarım kalan çıktı silinir, özgün dosyaya dokunulmaz.
abstract final class VideoTranscoder {
  /// Kaynağın **gösterim** ölçüsü. Önce ffprobe (döndürme verisini de okur),
  /// olmazsa video_compress.
  static Future<({int width, int height})?> sourceSize(String path) async {
    final probe = await FfmpegVideo.probe(path);
    if (probe != null) return (width: probe.width, height: probe.height);
    try {
      final info = await vc.VideoCompress.getMediaInfo(path);
      final w = info.width;
      final h = info.height;
      if (w == null || h == null || w <= 0 || h <= 0) return null;
      return (width: w, height: h);
    } catch (_) {
      return null;
    }
  }

  /// Hedef kısa kenarı, YEDEK motorun desteklediği kademeye eşler.
  ///
  /// **Aşağı** yuvarlanır: kullanıcı küçültmek istedi, 500 piksel hedefe 540p
  /// vermek istediğinden büyük bir dosya üretmek olurdu.
  static vc.VideoQuality qualityForShortEdge(int shortEdge) {
    if (shortEdge >= 1080) return vc.VideoQuality.Res1920x1080Quality;
    if (shortEdge >= 720) return vc.VideoQuality.Res1280x720Quality;
    if (shortEdge >= 540) return vc.VideoQuality.Res960x540Quality;
    return vc.VideoQuality.Res640x480Quality;
  }

  /// [path] videosunu [options]'a göre yeniden kodlar.
  static Future<ResizeResult> run(
    String path,
    MediaResizeOptions options, {
    JobHandle? handle,
  }) async {
    final before = File(path).lengthSync();
    final base = p.basenameWithoutExtension(path);
    // Çıktı her zaman MP4/H.264: iki motor da bunu üretiyor, uzantıyı korumak
    // (ör. .mkv) oynatıcıları yanıltırdı.
    final target = FileOps.uniquePath(
      p.join(p.dirname(path), '${base}_${options.suffix}.mp4'),
    );

    final probe = await FfmpegVideo.probe(path);
    final size = probe != null
        ? (width: probe.width, height: probe.height)
        : await sourceSize(path);

    // ── 1) FFmpeg: birebir ölçü + kare sayısı ────────────────────────────────
    if (size != null) {
      final wanted = targetSize(
        sourceWidth: size.width,
        sourceHeight: size.height,
        options: options,
      );
      try {
        handle?.report(detail: 'Dönüştürülüyor (FFmpeg)…');
        await FfmpegVideo.transcode(
          source: path,
          output: target,
          width: wanted.width,
          height: wanted.height,
          fps: options.frameRate,
          quality: options.videoQuality,
          removeAudio: options.removeAudio,
          durationMs: probe?.durationMs ?? 0,
          onProgress: (ratio) => handle?.report(
              detail: '${wanted.width}×${wanted.height} · '
                  '%${(ratio * 100).round()}'),
          isCancelled: () => handle?.cancelled ?? false,
        );
        return ResizeResult(
          sourcePath: path,
          outputPath: target,
          beforeBytes: before,
          afterBytes: File(target).existsSync() ? File(target).lengthSync() : 0,
          width: wanted.width,
          height: wanted.height,
        );
      } on FfmpegCancelled {
        _cleanup(target);
        throw const JobCancelled();
      } catch (_) {
        // Yarım kalan çıktı kalmasın; yedek motor kendi dosyasını üretecek.
        _cleanup(target);
      }
    }

    // ── 2) Yedek: MediaCodec kademesi ────────────────────────────────────────
    handle?.report(detail: 'Dönüştürülüyor (yedek motor)…');
    return _presetPass(path, options, target, before, size, handle);
  }

  static void _cleanup(String path) {
    try {
      final file = File(path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }

  static Future<ResizeResult> _presetPass(
    String path,
    MediaResizeOptions options,
    String target,
    int before,
    ({int width, int height})? size,
    JobHandle? handle,
  ) async {
    final subscription = handle == null
        ? null
        : vc.VideoCompress.compressProgress$.subscribe((value) {
            // Yalnız AYRINTI satırı yazılır: `done/total` toplu işin dosya
            // sayacı (çağıranın) — buraya yüzde yazmak ilerleme çubuğunu her
            // dosyada 0-100 arasında zıplatırdı.
            handle.report(
                detail: 'Yedek motor: %${value.toStringAsFixed(0)}');
            if (handle.cancelled) unawaited(cancel());
          });
    String? produced;
    try {
      final info = await vc.VideoCompress.compressVideo(
        path,
        quality: _presetQuality(options, size),
        deleteOrigin: false,
        includeAudio: !options.removeAudio,
        // `frameRate` zorunlu (varsayılan 30). "Değiştirme" seçilirse yüksek
        // bir değer verilir — motor kaynaktan fazlasını üretmez.
        frameRate: options.frameRate ?? 60,
      );
      if (info?.isCancel ?? false) throw const JobCancelled();
      produced = info?.path;
      if (produced == null || !File(produced).existsSync()) {
        throw const VideoTranscodeException(
            'Video sıkıştırılamadı (biçim desteklenmiyor olabilir).');
      }
      await File(produced).copy(target);
      // Ölçü ÇIKTIDAN okunur, kaynaktan değil: yedek motor istenen ölçüyü değil
      // kendi kademesini uygular (1234x568 istenirken 1280x720 üretebilir).
      // Okunamazsa null bırakılır — kaynağın ölçüsünü çıktının ölçüsü gibi
      // yazmak kullanıcıya yanlış bilgi vermekti (2026-07-29 sadakat denetimi).
      final produce = await sourceSize(target);
      return ResizeResult(
        sourcePath: path,
        outputPath: target,
        beforeBytes: before,
        afterBytes: File(target).lengthSync(),
        width: produce?.width,
        height: produce?.height,
      );
    } finally {
      subscription?.unsubscribe();
      if (produced != null && produced != path) _cleanup(produced);
    }
  }

  static vc.VideoQuality _presetQuality(
    MediaResizeOptions options,
    ({int width, int height})? size,
  ) {
    if (!options.changesResolution) {
      return switch (options.videoQuality) {
        VideoQualityChoice.veryLow => vc.VideoQuality.LowQuality,
        VideoQualityChoice.low => vc.VideoQuality.LowQuality,
        VideoQualityChoice.medium => vc.VideoQuality.MediumQuality,
        VideoQualityChoice.high => vc.VideoQuality.HighestQuality,
      };
    }
    final edge = options.resolution.shortEdge;
    if (size == null) {
      return edge != null
          ? qualityForShortEdge(edge)
          : vc.VideoQuality.MediumQuality;
    }
    final target = targetSize(
      sourceWidth: size.width,
      sourceHeight: size.height,
      options: options,
    );
    final shortEdge =
        target.width < target.height ? target.width : target.height;
    return qualityForShortEdge(shortEdge);
  }

  /// Süren kodlamayı iptal eder (iş kuyruğundaki iptal düğmesi çağırır).
  static Future<void> cancel() async {
    await FfmpegVideo.cancel();
    try {
      await vc.VideoCompress.cancelCompression();
    } catch (_) {}
  }
}

class VideoTranscodeException implements Exception {
  final String message;
  const VideoTranscodeException(this.message);
  @override
  String toString() => message;
}

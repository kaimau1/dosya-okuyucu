import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:video_compress/video_compress.dart' as vc;

import '../../models/media_resize.dart';
import 'file_ops.dart';
import 'image_resize.dart' show ResizeResult;
import 'job_queue.dart';

/// **Video boyut düşürme** — native `MediaCodec` (video_compress).
///
/// ## Niye ffmpeg YOK
/// `ffmpeg_kit_flutter` dağıtımdan kaldırıldı: ikili dosyaları artık
/// barındırılmadığı için paketi eklemek derlemeyi indirme hatasıyla kırar.
///
/// ## Niye SERBEST en×boy yok (dürüst sınır — 2026-07-29)
/// Kullanıcı serbest çözünürlük istedi; bunu verebilen paket
/// `light_compressor` 2.2.0'dı ve **denenmeden önce** derleme zincirine
/// bakıldığında üç bağımsız kırıcı bulundu (bkz. HAFIZA):
/// 1. Android modülünde `namespace` yok, manifestte hâlâ `package=` var →
///    AGP 8 bunu **hata** sayıyor ("Namespace not specified").
/// 2. Native bağımlılığı JitPack'te (`com.github.AbedElazizShe:LightCompressor`)
///    ve paket bu deposu tüketen uygulamaya tanıtmıyor → çözümleme çöker.
/// 3. Kendi `buildscript`inde AGP 4.2.2 classpath'i bildiriyor → kökteki
///    AGP 8.7 ile çakışır.
/// Üçünü de yamayla zorlamak, HAFIZA'da zaten reddedilmiş olan "tek bir paket
/// için tüm derleme zincirini oynatma" yoluna girmek olurdu.
///
/// **Bunun yerine:** hangi seçim yapılırsa yapılsın (yüzde, serbest en×boy,
/// kademe) hedef ölçü hesaplanır ve **en yakın alt kademeye** eşlenir. Yani
/// "%50" ya da "1000x562" seçildiğinde video 540p'ye iner; birebir istenen
/// piksel değil ama istenen küçültme gerçekleşir ve arayüz bunu yazar.
/// Fotoğraflarda serbest ölçü **tam olarak** uygulanır (saf Dart, bkz.
/// `ImageResizer`).
///
/// ## Dürüst sınır — arka plan
/// Kodlama native tarafta koşar ama uygulama süreci içinde: uygulama arka
/// planda kalabilir, görev listesinden **kapatılırsa** kodlama düşer
/// (bkz. `JobQueue`). Yarım kalan çıktı silinir, özgün dosyaya dokunulmaz.
abstract final class VideoTranscoder {
  /// Kaynağın gerçek ölçüsü (yüzdeyle küçültme ve "büyütme yapma" kuralı için).
  static Future<({int width, int height})?> sourceSize(String path) async {
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

  /// Hedef kısa kenarı, motorun desteklediği kademeye eşler.
  ///
  /// **Aşağı** yuvarlanır: kullanıcı küçültmek istedi, 500 piksel hedefe 540p
  /// vermek istediğinden büyük bir dosya üretmek olurdu. Hedef en küçük
  /// kademenin de altındaysa en küçüğü seçilir (motorun altı yok).
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
    // Çıktı her zaman MP4: motor MP4/H.264 üretiyor, uzantıyı korumak
    // (ör. .mkv) oynatıcıları yanıltırdı.
    final target = FileOps.uniquePath(
      p.join(p.dirname(path), '${base}_${options.suffix}.mp4'),
    );

    final size = await sourceSize(path);
    final quality = _quality(options, size);

    final subscription = handle == null
        ? null
        : vc.VideoCompress.compressProgress$.subscribe((value) {
            // Yalnız AYRINTI satırı yazılır: `done/total` toplu işin dosya
            // sayacı (çağıranın) — buraya yüzde yazmak ilerleme çubuğunu her
            // dosyada 0-100 arasında zıplatırdı.
            handle.report(detail: 'Sıkıştırma: %${value.toStringAsFixed(0)}');
            // Uzun bir kodlamada iptal düğmesinin işe yaraması için tek
            // yoklama noktası bu akış (döngü yok).
            if (handle.cancelled) unawaited(cancel());
          });
    String? produced;
    try {
      final info = await vc.VideoCompress.compressVideo(
        path,
        quality: quality,
        deleteOrigin: false,
        includeAudio: !options.removeAudio,
        // `frameRate` zorunlu (varsayılan 30). "Değiştirme" seçilirse yüksek
        // bir değer verilir — motor kaynaktan fazlasını üretmez, yani kaynağın
        // kare sayısı korunur.
        frameRate: options.frameRate ?? 60,
      );
      if (info?.isCancel ?? false) throw const JobCancelled();
      produced = info?.path;
      if (produced == null || !File(produced).existsSync()) {
        throw const VideoTranscodeException(
            'Video sıkıştırılamadı (biçim desteklenmiyor olabilir).');
      }
      await File(produced).copy(target);
      return ResizeResult(
        sourcePath: path,
        outputPath: target,
        beforeBytes: before,
        afterBytes: File(target).lengthSync(),
        width: size?.width ?? 0,
        height: size?.height ?? 0,
      );
    } finally {
      subscription?.unsubscribe();
      // Motorun önbelleğindeki ara dosya birikirse depolamayı kendimiz
      // doldururuz.
      if (produced != null && produced != path) {
        try {
          final f = File(produced);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
  }

  static vc.VideoQuality _quality(
    MediaResizeOptions options,
    ({int width, int height})? size,
  ) {
    if (!options.changesResolution) {
      // Çözünürlüğe dokunulmuyor → yalnız sıkıştırma sertliği.
      return switch (options.videoQuality) {
        VideoQualityChoice.veryLow => vc.VideoQuality.LowQuality,
        VideoQualityChoice.low => vc.VideoQuality.LowQuality,
        VideoQualityChoice.medium => vc.VideoQuality.MediumQuality,
        VideoQualityChoice.high => vc.VideoQuality.HighestQuality,
      };
    }
    // Kademe seçildi ve kaynağı bilmiyoruz → kademeyi doğrudan kullan.
    final edge = options.resolution.shortEdge;
    if (size == null) {
      return edge != null
          ? qualityForShortEdge(edge)
          : vc.VideoQuality.MediumQuality;
    }
    // Yüzde/serbest ölçü dahil her seçim hedef ölçüye çevrilir, oradan
    // en yakın alt kademeye eşlenir.
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

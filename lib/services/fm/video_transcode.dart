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
/// ## Motor sırası (2026-07-30 — "çok yavaş" şikâyetinin cevabı)
/// `donanım kodlayıcı → yedek motor (o da donanım) → yazılım kodlayıcı`.
/// Yazılım kodlama (mpeg4) en sona alındı: telefonda dakikalar sürüyor, oysa
/// yedek motor native MediaCodec ile donanımı kullanıyor. Serbest ölçü
/// istendiğinde sıra değişir (yedek motor birebir ölçü veremez). Ayrıntı:
/// [run] gövdesindeki "MOTOR SIRASI" notu. Hangi motorun koştuğu ilerleme
/// satırına yazılır — kullanıcı yavaşlığın nedenini görebilsin.
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
    return _sizeViaPlugin(path);
  }

  /// Yalnız eklentiyle ölçü okur (ffprobe'u TEKRAR çalıştırmadan).
  ///
  /// [run] zaten `probe` çağırıyor; oradan `sourceSize`a düşmek aynı dosyada
  /// ikinci bir ffprobe koşturuyordu — zor okunan her videoda boşa geçen saniye.
  static Future<({int width, int height})?> _sizeViaPlugin(String path) async {
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

  /// İstenen kare sayısını kaynağın kare sayısıyla **sınırlar**.
  ///
  /// Saf fonksiyon → birim testli. 30 fps bir videoya "60" seçmek ffmpeg'e her
  /// kareyi ikiye kopyalatır: dosya büyür, görüntü aynı kalır ve çıktı
  /// kaynaktan büyük çıktığı için iş "küçültülemedi" diye biter — kullanıcı
  /// dakikalarca bekleyip hiçbir şey kazanmaz. Kaynağın hızı bilinmiyorsa
  /// istenen değer olduğu gibi geçer (uydurma yapmıyoruz).
  static int? cappedFps(int? wanted, double? sourceFps) {
    if (wanted == null) return null;
    if (sourceFps == null || sourceFps <= 0) return wanted;
    final source = sourceFps.floor();
    return wanted > source ? (source < 1 ? 1 : source) : wanted;
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
  ///
  /// [progressPrefix] toplu işte "3/10" gibi sayaç — ilerleme satırının başına
  /// yazılır ki kullanıcı hangi dosyada olduğunu da görsün.
  static Future<ResizeResult> run(
    String path,
    MediaResizeOptions options, {
    JobHandle? handle,
    String? progressPrefix,
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
        : await _sizeViaPlugin(path);
    final sourceDurationMs = probe?.durationMs ?? 0;

    // Ölçü hiç okunamadıysa FFmpeg'e verilecek hedef de yok → tek seçenek
    // kademeli yedek motor.
    if (size == null) {
      handle?.report(detail: _line(progressPrefix, ['yedek motor hazırlanıyor…']));
      return _presetPass(
        path,
        options,
        target,
        before,
        size,
        handle,
        sourceDurationMs,
        progressPrefix,
      );
    }

    final wanted = targetSize(
      sourceWidth: size.width,
      sourceHeight: size.height,
      options: options,
    );
    // Kaynaktan YÜKSEK kare sayısı istenmez: ffmpeg aradaki kareleri kopyalar,
    // dosya şişer, kalite artmaz. Çözünürlükte "büyütme yok" kuralının kare
    // sayısındaki karşılığı (2026-07-29 denetimi, 2. tur).
    final fps = cappedFps(options.frameRate, probe?.fps);

    // ── MOTOR SIRASI ─────────────────────────────────────────────────────────
    // 1. FFmpeg + **donanım** kodlayıcı (h264_mediacodec): hızlı ve istenen
    //    ölçüyü birebir uygular. Normalde iş burada biter.
    // 2. Serbest ölçü İSTENMEDİYSE yedek motor (native MediaCodec): o da
    //    DONANIM kullanır, yani yazılım kodlamadan kat kat hızlı — yalnız
    //    kademeli ölçü verir (720p/1080p…), ki kademe zaten istenmişti.
    // 3. FFmpeg + **yazılım** kodlayıcı (mpeg4): en son çare. Telefonda
    //    dakikalar sürüyor ve kalitesi H.264'ün gerisinde; eskiden 2. sıradaydı
    //    ve donanım kodlayıcı bulunamayan cihazlarda kullanıcı sürekli bunu
    //    yiyordu → "video boyutu küçültme çok yavaş" (kullanıcı hatası
    //    2026-07-30). Serbest ölçüde sırası öne alınır: orada kademeli motor
    //    istenen ölçüyü veremez, yazılım kodlayıcı verir.
    final attempts = <({String label, Future<ResizeResult> Function() run})>[
      (
        label: 'donanım kodlayıcı',
        run: () => _ffmpegPass(
              path: path,
              options: options,
              target: target,
              before: before,
              wanted: wanted,
              fps: fps,
              handle: handle,
              sourceDurationMs: sourceDurationMs,
              encoders: const ['h264_mediacodec'],
              engineLabel: 'donanım kodlayıcı',
              progressPrefix: progressPrefix,
            ),
      ),
      if (!options.needsExactSize) _presetAttempt(
          path, options, target, before, size, handle, sourceDurationMs,
          progressPrefix),
      (
        label: 'yazılım kodlayıcı',
        run: () => _ffmpegPass(
              path: path,
              options: options,
              target: target,
              before: before,
              wanted: wanted,
              fps: fps,
              handle: handle,
              sourceDurationMs: sourceDurationMs,
              encoders: const ['mpeg4'],
              engineLabel: 'yazılım kodlayıcı (yavaş)',
              progressPrefix: progressPrefix,
            ),
      ),
      if (options.needsExactSize) _presetAttempt(
          path, options, target, before, size, handle, sourceDurationMs,
          progressPrefix),
    ];

    Object? lastError;
    for (final attempt in attempts) {
      try {
        return await attempt.run();
      } on JobCancelled {
        _cleanup(target);
        rethrow;
      } on VideoTranscodeException catch (e) {
        // ÇIKTI DOĞRULAMASI başarısızsa BAŞKA MOTOR DENENMEZ: kaynak bozuksa
        // (yarıda kesilmiş kayıt, hasarlı moov) her motor yarım üretir,
        // kullanıcı dakikalarca bekleyip aynı yere varır. Hata yukarı çıkar,
        // dosya "küçültülemedi" sayılır, özgün dosyaya DOKUNULMAZ.
        _cleanup(target);
        if (e.fatal) rethrow;
        lastError = e;
      } catch (e) {
        _cleanup(target);
        lastError = e;
      }
    }
    throw VideoTranscodeException('Video dönüştürülemedi: $lastError');
  }

  /// Kademeli yedek motor denemesi (liste içinde okunur dursun diye ayrıldı).
  static ({String label, Future<ResizeResult> Function() run}) _presetAttempt(
    String path,
    MediaResizeOptions options,
    String target,
    int before,
    ({int width, int height})? size,
    JobHandle? handle,
    int sourceDurationMs,
    String? progressPrefix,
  ) =>
      (
        label: 'yedek motor',
        run: () => _presetPass(path, options, target, before, size, handle,
            sourceDurationMs, progressPrefix),
      );

  /// Tek bir FFmpeg denemesi (verilen kodlayıcılarla) + çıktı doğrulaması.
  static Future<ResizeResult> _ffmpegPass({
    required String path,
    required MediaResizeOptions options,
    required String target,
    required int before,
    required ({int width, int height}) wanted,
    required int? fps,
    required JobHandle? handle,
    required int sourceDurationMs,
    required List<String> encoders,
    required String engineLabel,
    required String? progressPrefix,
  }) async {
    handle?.report(detail: _line(progressPrefix, ['$engineLabel hazırlanıyor…']));
    final clock = Stopwatch()..start();
    try {
      await FfmpegVideo.transcode(
        source: path,
        output: target,
        width: wanted.width,
        height: wanted.height,
        mode: FfmpegVideo.scaleModeFor(options),
        fps: fps,
        quality: options.videoQuality,
        removeAudio: options.removeAudio,
        durationMs: sourceDurationMs,
        encoders: encoders,
        // İlerleme satırı üç şeyi birlikte söyler: nereye gidiyor (%), ne kadar
        // kaldı, HANGİ motorla. Üçüncüsü şart: yavaşlığın nedeni neredeyse her
        // zaman motor (donanım mı, yazılım mı) ve kullanıcı bunu görmeden
        // "uygulama takıldı mı?" diye bakıyordu (istek 2026-07-30).
        onProgress: (ratio) => handle?.report(
          detail: _line(progressPrefix, [
            '${wanted.width}×${wanted.height}',
            '%${(ratio * 100).round()}',
            FfmpegVideo.remainingText(clock.elapsed, ratio),
            engineLabel,
          ]),
        ),
        isCancelled: () => handle?.cancelled ?? false,
      );
    } on FfmpegCancelled {
      throw const JobCancelled();
    }
    final produced = await _verifyOutput(
      output: target,
      sourceDurationMs: sourceDurationMs,
    );
    return ResizeResult(
      sourcePath: path,
      outputPath: target,
      beforeBytes: before,
      afterBytes: File(target).existsSync() ? File(target).lengthSync() : 0,
      width: produced?.width ?? wanted.width,
      height: produced?.height ?? wanted.height,
    );
  }

  /// İlerleme satırı: boş parçalar atılır (yarım tahmin yazılmaz).
  static String _line(String? prefix, List<String> parts) => [
        if (prefix != null && prefix.isNotEmpty) prefix,
        ...parts.where((s) => s.isNotEmpty),
      ].join(' · ');

  /// Üretilen videonun **eksiksiz** olduğunu doğrular; değilse hata atar.
  ///
  /// ## Niye gerekli (2026-07-29 sadakat denetimi, 2. tur — veri kaybı)
  /// "Çıktı kaynaktan küçük" tek başına başarı ölçütü DEĞİL. Kaydı yarıda
  /// kesilmiş bir videoda (bozuk `moov`, hasarlı son GOP — telefonlarda çok
  /// yaygın) ffmpeg ilk saniyeleri çözüp **0 dönüş koduyla** çıkabiliyor: 200
  /// MB'lık 10 dakikalık videodan 900 KB'lık 3 saniyelik dosya kalıyor. Eski
  /// kod bunu "199 MB kazanıldı" diye kutluyor ve "Özgün dosyayı çöp kutusuna
  /// at" açıkken 10 dakikalık aslı çöpe atıyordu.
  ///
  /// Ölçüt **süre**: kırpma yapmıyoruz, kare sayısını değiştirmek süreyi
  /// değiştirmez → çıktının süresi kaynağın süresine yakın olmak zorunda.
  /// %10 pay bırakılıyor (son GOP'un yuvarlanması normal).
  ///
  /// Çıktı hiç okunamıyorsa: **kaynak okunabildiyse** bu cihazda ffprobe
  /// çalışıyor demektir, o hâlde okunamayan çıktı bozuktur → reddedilir.
  /// Kaynak da okunamıyorsa ölçemediğimiz için karışmıyoruz (yalnız boyut
  /// kontrolü kalır; `resize_actions` sıfır baytı ayrıca eliyor).
  static Future<({int width, int height})?> _verifyOutput({
    required String output,
    required int sourceDurationMs,
  }) async {
    final probe = await FfmpegVideo.probe(output);
    if (probe == null) {
      if (sourceDurationMs > 0) {
        throw const VideoTranscodeException(
            'Dönüştürülen video okunamadı (bozuk çıktı) — özgün dosyaya '
            'dokunulmadı.',
            fatal: true);
      }
      return null;
    }
    if (sourceDurationMs > 0 &&
        probe.durationMs < (sourceDurationMs * 0.9).round()) {
      throw VideoTranscodeException(
          'Dönüştürme yarıda kalmış: çıktı ${_seconds(probe.durationMs)} sn, '
          'kaynak ${_seconds(sourceDurationMs)} sn. Özgün dosyaya '
          'dokunulmadı.',
          fatal: true);
    }
    return (width: probe.width, height: probe.height);
  }

  static int _seconds(int ms) => (ms / 1000).round();

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
    int sourceDurationMs,
    String? progressPrefix,
  ) async {
    final clock = Stopwatch()..start();
    final subscription = handle == null
        ? null
        : vc.VideoCompress.compressProgress$.subscribe((value) {
            // Yalnız AYRINTI satırı yazılır: `done/total` toplu işin dosya
            // sayacı (çağıranın) — buraya yüzde yazmak ilerleme çubuğunu her
            // dosyada 0-100 arasında zıplatırdı.
            handle.report(
              detail: _line(progressPrefix, [
                '%${value.toStringAsFixed(0)}',
                FfmpegVideo.remainingText(clock.elapsed, value / 100),
                'yedek motor (kademeli ölçü)',
              ]),
            );
          });
    // İptal, ilerleme akışından BAĞIMSIZ yoklanır (FFmpeg yolundaki desenin
    // aynısı): MediaCodec ilk `updateProgress`i yayımlamadan takılırsa "Durdur"
    // hiçbir şey yapmıyordu ve 20 dakikalık kodlama sonuna kadar sürüyordu
    // (2026-07-29 sadakat denetimi, 2. tur).
    Timer? poll;
    if (handle != null) {
      poll = Timer.periodic(const Duration(milliseconds: 400), (timer) {
        if (handle.cancelled) {
          timer.cancel();
          unawaited(cancel());
        }
      });
    }
    String? produced;
    try {
      final info = await vc.VideoCompress.compressVideo(
        path,
        quality: _presetQuality(options, size),
        deleteOrigin: false,
        includeAudio: !options.removeAudio,
        // `frameRate` zorunlu (varsayılan 30).
        //
        // DÜRÜST SINIR: eklenti bu değeri yalnız `HighestQuality` kademesinde
        // kullanıyor (Android tarafında diğer kademeler `atMost(...)` kurup
        // `frameRate`e hiç dokunmuyor) → kademeli yolda kare sayısı seçimi
        // uygulanamaz. Arayüzdeki yedek motor uyarısında bu yazılı.
        frameRate: options.frameRate ?? 60,
      );
      // İPTAL: eklenti iptalde de hatada da `null` döndürüyor (Android tarafında
      // `onTranscodeCanceled` ve `onTranscodeFailed` ikisi de
      // `result.success(null)` çağırıyor) — yani `info.isCancel` buraya ASLA
      // ulaşmaz. Bu yüzden iptal isteği bizim tarafta kontrol edilir; yoksa
      // kullanıcının kendi bastığı "Durdur" ona "biçim desteklenmiyor olabilir"
      // diye rapor ediliyordu (2026-07-29 sadakat denetimi, 2. tur).
      if (info == null && (handle?.cancelled ?? false)) {
        throw const JobCancelled();
      }
      if (info?.isCancel ?? false) throw const JobCancelled();
      produced = info?.path;
      if (produced == null || !File(produced).existsSync()) {
        // Yarım kalan geçici çıktının yolunu eklenti söylemiyor; uygulamanın
        // kendi önbelleğinde kalmasın (art arda iptallerde gigabaytlar birikir).
        await _clearPluginCache();
        throw const VideoTranscodeException(
            'Video sıkıştırılamadı (biçim desteklenmiyor olabilir).');
      }
      await File(produced).copy(target);
      // Ölçü ÇIKTIDAN okunur, kaynaktan değil: yedek motor istenen ölçüyü değil
      // kendi kademesini uygular (1234x568 istenirken 1280x720 üretebilir).
      // Okunamazsa null bırakılır — kaynağın ölçüsünü çıktının ölçüsü gibi
      // yazmak kullanıcıya yanlış bilgi vermekti (2026-07-29 sadakat denetimi).
      //
      // Aynı çağrı çıktının EKSİKSİZ olduğunu da doğrular (süre karşılaştırması,
      // bkz. [_verifyOutput]); yarım çıktıda hata atar ve dosya silinir, böylece
      // "özgünü çöpe at" yarım bir kopya için çalışmaz.
      // Doğrulama hatasında çıktıyı ÇAĞIRAN siler (bkz. `run`'daki döngü) —
      // orada "başka motor denenmesin" kararı da veriliyor.
      final produce = await _verifyOutput(
        output: target,
        sourceDurationMs: sourceDurationMs,
      );
      return ResizeResult(
        sourcePath: path,
        outputPath: target,
        beforeBytes: before,
        afterBytes: File(target).existsSync() ? File(target).lengthSync() : 0,
        width: produce?.width,
        height: produce?.height,
      );
    } on JobCancelled {
      // İptalde de eklentinin önbelleğinde yarım dosya kalır.
      await _clearPluginCache();
      rethrow;
    } finally {
      poll?.cancel();
      subscription?.unsubscribe();
      if (produced != null && produced != path) _cleanup(produced);
    }
  }

  /// Yedek motorun kendi önbelleğini boşaltır (`.../video_compress/VID_*.mp4`).
  ///
  /// Eklenti iptalde/hatada ürettiği yarım dosyanın yolunu SÖYLEMİYOR, yani tek
  /// tek silinemiyor. Temizlenmezse 1,5 GB'lık bir videoyu üç kez iptal etmek
  /// uygulama deposunda gigabaytlar bırakıyor ve kullanıcı ona ancak "uygulama
  /// verilerini sil" ile ulaşabiliyor (2026-07-29 sadakat denetimi, 2. tur).
  /// Başarılı yolda çağrılmaz: çıktı önce hedefe kopyalanıyor.
  static Future<void> _clearPluginCache() async {
    try {
      await vc.VideoCompress.deleteAllCache();
    } catch (_) {}
  }

  static vc.VideoQuality _presetQuality(
    MediaResizeOptions options,
    ({int width, int height})? size,
  ) {
    // "Çözünürlük: Değiştirme" → çözünürlüğü DEĞİŞTİRMEYEN tek kademe.
    //
    // KRİTİK (2026-07-29 sadakat denetimi, 2. tur — veri kaybı): eskiden
    // sıkıştırma sertliği kademeye eşlenirdi (`veryLow`/`low` → LowQuality,
    // `medium` → MediumQuality). Eklentinin Android tarafında bu kademeler
    // `DefaultVideoStrategy.atMost(360)` ve `atMost(640)` demek — yani KISA
    // KENARI zorla düşürüyor. Kullanıcı "çözünürlüğü değiştirme" derken 1080p
    // aslı çöpe atılıp elinde 640 piksellik bir dosya kalıyordu. Üstelik bu yol
    // yalnız ffprobe başarısız olduğunda çalıştığı için arayüzdeki "yedek
    // motora düşülebilir" uyarısı da (`changesResolution`e bağlı) hiç
    // görünmüyordu: söz verilmemiş, sorulmamış, geri alınamaz bir kayıp.
    //
    // `HighestQuality` eklentide ölçü kısıtı KOYMAYAN tek kademe. Bedeli dürüst
    // biçimde kabul ediliyor: yedek motorda "sıkıştırma sertliği" uygulanamaz
    // (yeniden kodlama yine küçültür). Çözünürlüğü korumak, sertlikten önemli.
    if (!options.changesResolution) return vc.VideoQuality.HighestQuality;
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

  /// **Başka motor denenmemeli mi?** Çıktı doğrulaması (süre/okunabilirlik)
  /// başarısızsa true: sorun motorlarda değil kaynakta, sıradaki motor da
  /// yarım üretir ve kullanıcı dakikalarca boşa bekler.
  final bool fatal;

  const VideoTranscodeException(this.message, {this.fatal = false});
  @override
  String toString() => message;
}

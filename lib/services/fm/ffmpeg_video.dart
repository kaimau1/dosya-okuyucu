import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffprobe_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';

import '../../models/media_resize.dart';

/// Videonun gerçek ölçüsü ve süresi.
class VideoProbe {
  /// **Gösterim** ölçüsü: döndürme verisi uygulanmış hâli (dikey videoda
  /// kodlanmış ölçü 1920x1080'dir ama ekranda 1080x1920 görünür).
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

/// Hedef ölçünün uygulanma biçimi (bkz. [FfmpegVideo.scaleFilter]).
enum VideoScaleMode {
  /// Kaynağın kendi en/boy oranı korunarak hedef kutuya sığdırılır (kademe,
  /// yüzde, "değiştirme"). Yön bilgisine ihtiyaç duymaz.
  fit,

  /// Kullanıcı hem en hem boy yazdı → birebir uygulanır (oran bozulabilir).
  exactBoth,

  /// Yalnız en yazıldı → boy orandan hesaplanır.
  exactWidth,

  /// Yalnız boy yazıldı → en orandan hesaplanır.
  exactHeight,
}

/// **FFmpeg tabanlı video dönüştürücü** — birebir çözünürlük + kare sayısı.
///
/// ## Niye bu paket (ve niye öncekiler olmadı)
/// - `ffmpeg_kit_flutter` (özgün) **dağıtımdan kaldırıldı**: ikilileri artık
///   barındırılmıyor, eklemek derlemeyi indirme hatasıyla kırar.
/// - `light_compressor` serbest en×boy veriyordu ama Android modülünde
///   `namespace` yok (AGP 8 hatası), native bağımlılığı tanıtılmayan bir
///   JitPack deposunda ve kendi buildscript'i AGP 4.2.2 bildiriyor → üç
///   bağımsız derleme kırıcısı (2026-07-29'da denendi, eklenmedi).
/// - `ffmpeg_kit_flutter_new_min` bu üç sorunun hiçbirini taşımıyor:
///   `namespace` var, compileSdk 35, minSdk 24 (bizimkiyle aynı) ve native
///   kütüphane **Maven Central**'da (`com.antonkarpenko:ffmpeg-kit-min`).
///   Tek gereken CI'daki Kotlin eklentisini 2.2.0'a çekmek (paket
///   kotlin-stdlib 2.2.0 taşıyor; yeni derleyici eski metadata'yı okur, ters
///   yön kırılır — bkz. HAFIZA build 119).
///
/// ## LİSANS — niye `min` (LGPL), `min_gpl` (GPL) değil
/// İlk sürümde `min_gpl` kullanılmıştı (x264 ile H.264 yazmak için). Kullanıcı
/// isteği üzerine değiştirildi: *"lisans kısmını hallet, Google Play'de sorun
/// yaşamayalım"*. x264/x265/xvid **GPL v3**; onları dağıtmak uygulamanın
/// TAMAMINI GPL v3'e sokar (tüm kaynağı bu lisansla yayımlama zorunluluğu) ve
/// GPL v3'ün "ek kısıtlama koyulamaz" maddesinin mağaza dağıtım şartlarıyla
/// çakışması bilinen bir sorundur. `min` varyantı **LGPL v3**: dinamik bağlı
/// `.so` olarak dağıtıldığı için yükümlülük atıf + kütüphane kaynağını sunma +
/// yeniden bağlamaya izin vermekle sınırlı, uygulamanın kendi kodu etkilenmez
/// (bkz. depo kökündeki `LICENSES.md` ve Ayarlar > Açık kaynak bileşenler).
///
/// **Birebir çözünürlük kaybedilmedi:** ölçekleme (`scale`) ve kare sayısı
/// (`fps`) süzgeçleri FFmpeg'in çekirdeğinde, GPL kütüphanelerde değil.
///
/// ## Kalite kararları
/// - **Kodlayıcı `h264_mediacodec` (cihazın donanım kodlayıcısı).** Paket
///   FFmpeg 8.1.2 taşıyor, MediaCodec kodlayıcıları 6.1'den beri var. Üç
///   faydası: GPL'li x264 gerekmiyor, kodlama yazılım kodlamadan kat kat hızlı
///   ve H.264 patent lisansı cihaz üreticisinde kalıyor.
/// - Donanım kodlayıcı bulunamazsa **`mpeg4`**'e düşülür (FFmpeg'in kendi
///   kodlayıcısı, LGPL kapsamında): kalitesi H.264'ün gerisinde ama istenen
///   çözünürlük yine birebir uygulanır. İkisi de olmazsa çağıran katman
///   (`VideoTranscoder`) kademeli MediaCodec motoruna düşer.
/// - Ses **yeniden kodlanır** (AAC 128k), kopyalanmaz: kaynak sesi MP4'e
///   girmeyen bir biçimde (ör. WebM/Opus) olabilir ve `-c:a copy` o dosyada
///   sessizce çöker.
/// - `-map_metadata 0`: çekim tarihi korunur, yoksa küçültülmüş video
///   galeride "bugün çekildi" gibi görünür.
abstract final class FfmpegVideo {
  /// Süren oturumun kimliği (iptal için).
  static int? _sessionId;

  /// Videonun gösterim ölçüsünü ve süresini okur. Okunamazsa null.
  static Future<VideoProbe?> probe(String path) async {
    try {
      final session = await FFprobeKit.getMediaInformation(path);
      final info = session.getMediaInformation();
      if (info == null) return null;
      final durationMs =
          ((double.tryParse(info.getDuration() ?? '') ?? 0) * 1000).round();
      for (final stream in info.getStreams()) {
        if (stream.getType() != 'video') continue;
        final w = stream.getWidth();
        final h = stream.getHeight();
        if (w == null || h == null || w <= 0 || h <= 0) continue;
        final rotation = rotationOf(stream.getAllProperties());
        final swap = rotationSwapsAxes(rotation);
        return VideoProbe(
          width: swap ? h : w,
          height: swap ? w : h,
          durationMs: durationMs,
          fps: _parseRate(stream.getRealFrameRate()) ??
              _parseRate(stream.getAverageFrameRate()),
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// ffprobe çıktısındaki döndürme açısı (derece). Bulunamazsa 0.
  ///
  /// Telefon videoları neredeyse her zaman yatay kodlanır ve "90° döndür"
  /// verisiyle saklanır. Bu açı okunmazsa dikey bir videoyu 720p'ye indirmek
  /// istediğinde ölçüler ters hesaplanır ve video yan yatar/ezilir.
  /// Saf fonksiyon → birim testli (ffprobe bu bilgiyi iki ayrı yerde
  /// veriyor: `side_data_list` ve `tags.rotate`).
  static int rotationOf(Map<dynamic, dynamic>? properties) {
    if (properties == null) return 0;
    num? raw;
    final sideData = properties['side_data_list'];
    if (sideData is List) {
      for (final entry in sideData) {
        if (entry is Map && entry['rotation'] is num) {
          raw = entry['rotation'] as num;
          break;
        }
      }
    }
    if (raw == null) {
      final tags = properties['tags'];
      if (tags is Map) {
        final rotate = tags['rotate'] ?? tags['Rotate'];
        if (rotate != null) raw = num.tryParse('$rotate');
      }
    }
    if (raw == null) return 0;
    // -90 ve 270 aynı şey; 0..359 aralığına indir.
    final normalized = (raw.round() % 360 + 360) % 360;
    return normalized;
  }

  /// Açı en/boy eksenlerini takas ediyor mu?
  static bool rotationSwapsAxes(int rotation) =>
      rotation == 90 || rotation == 270;

  static double? _parseRate(String? value) {
    if (value == null || value.isEmpty) return null;
    // ffprobe kesir verir: "30000/1001".
    final parts = value.split('/');
    if (parts.length == 2) {
      final a = double.tryParse(parts[0]);
      final b = double.tryParse(parts[1]);
      if (a == null || b == null || b == 0) return null;
      return a / b;
    }
    return double.tryParse(value);
  }

  /// Kalan süre metni ("~2 dk kaldı"). Boş dönerse tahmin **güvenilir değil**.
  ///
  /// Kullanıcı isteği 2026-07-30: *"nerede ne oluyor göremiyorum"* + *"çok
  /// yavaş"*. Yavaşlığı bilmek ile ne kadar süreceğini bilmemek ayrı şeyler:
  /// kodlama gerçekten uzun sürüyorsa kullanıcı en azından ne kadar
  /// beklediğini görmeli. Tahmin **ölçülen** hızdan çıkar (geçen süre / oran),
  /// uydurma yok; ilk saniyelerde (kodlayıcı ısınırken) ölçüm yanıltıcı olduğu
  /// için boş dönülür — yanlış süre yazmak hiç yazmamaktan kötü.
  /// Saf fonksiyon → birim testli.
  static String remainingText(Duration elapsed, double ratio) {
    if (ratio <= 0.02 || ratio >= 1) return '';
    if (elapsed.inSeconds < 3) return '';
    final totalMs = elapsed.inMilliseconds / ratio;
    final leftMs = (totalMs - elapsed.inMilliseconds).round();
    if (leftMs <= 0) return '';
    final seconds = (leftMs / 1000).round();
    if (seconds < 60) return '~$seconds sn kaldı';
    final minutes = (seconds / 60).round();
    if (minutes < 60) return '~$minutes dk kaldı';
    return '~${(minutes / 60).round()} sa kaldı';
  }

  /// Sıkıştırma sertliğinin CRF karşılığı (x264: küçük = daha iyi kalite).
  ///
  /// CRF seçildi, sabit bit hızı değil: aynı bit hızı hareketli bir videoda
  /// bulanık, durgun bir videoda gereksiz büyük dosya üretir. CRF ikisinde de
  /// benzer görsel kaliteyi tutar.
  static int crfFor(VideoQualityChoice quality) => switch (quality) {
        VideoQualityChoice.veryLow => 32,
        VideoQualityChoice.low => 28,
        VideoQualityChoice.medium => 24,
        VideoQualityChoice.high => 20,
      };

  /// Hedef ölçünün kaynağa **nasıl** uygulanacağı.
  ///
  /// Ayrımın nedeni tek bir kullanıcı hatası (2026-07-30): *"dikey videonun
  /// boyutu küçültülünce yatay gibi genişletmiş garip olmuş"*. Bkz.
  /// [scaleFilter] — kademe/yüzde seçimlerinde ölçü artık kaynağın kendi
  /// yönüne uydurulur, serbest en×boy ise kullanıcının yazdığı gibi kalır.
  static VideoScaleMode scaleModeFor(MediaResizeOptions options) {
    if (options.resolution != ResolutionChoice.custom) return VideoScaleMode.fit;
    final w = options.customWidth;
    final h = options.customHeight;
    if (w != null && h != null) return VideoScaleMode.exactBoth;
    if (w != null) return VideoScaleMode.exactWidth;
    if (h != null) return VideoScaleMode.exactHeight;
    return VideoScaleMode.fit;
  }

  /// Ölçekleme süzgeci. **Saf fonksiyon → birim testli.**
  ///
  /// ## KÖK NEDEN — dikey video yatay çıkıyordu (kullanıcı hatası 2026-07-30)
  /// Telefon videoları neredeyse her zaman **yatay kodlanıp** "90° döndür"
  /// verisiyle saklanır. Eski kod hedef ölçüyü mutlak sayı olarak yazıyordu
  /// (`scale=1280:720`) ve o sayılar `probe`un okuduğu ölçüden geliyordu:
  /// döndürme verisi herhangi bir nedenle okunamazsa (ffprobe düşer ve ölçü
  /// yedek eklentiden gelir — `MediaMetadataRetriever` döndürmeyi ölçüye
  /// KATMAZ) hedef "1280x720" hesaplanıyordu. Oysa ffmpeg süzgece giren kareyi
  /// kendi döndürme verisiyle ÇEVİRİYOR (autorotate) → dikey kare zorla yatay
  /// çerçeveye basılıyor: video enine yayılıyordu.
  ///
  /// ## Çözüm: mutlak sayı yerine **kutuya sığdır**
  /// `force_original_aspect_ratio=decrease` ile hedef, uzun kenarı [longEdge]
  /// olan bir kareye *sığdırılır*: çıktı oranı **kaynağın kendi karesinden**
  /// çıkar, yön bilgisine hiç ihtiyaç kalmaz. Sığdırma asla büyütmez çünkü
  /// `targetSize` hedefi zaten kaynakla sınırlıyor (kutu ≤ kaynağın uzun
  /// kenarı → ölçek katsayısı ≤ 1). `force_divisible_by=2` çift ölçüyü garanti
  /// eder (H.264 tek sayı kabul etmez); `decrease` ile aşağı yuvarlar.
  ///
  /// İfade (`if/min`) yerine bu seçenekler bilinçli: filtre ifadeleri virgül
  /// içerir, virgül filtre zincirinin ayırıcısıdır ve kaçırma/tırnak hatası
  /// burada "video hiç dönüşmüyor" demek olurdu — bu ortamda cihazda
  /// doğrulanamaz.
  ///
  /// **Serbest en×boy** (kullanıcı iki sayıyı da yazdı) birebir uygulanır:
  /// "1234x568" isteyen kişiye başka ölçü vermek sözden dönmek olurdu. Tek
  /// kenar yazıldıysa diğeri `-2` ile orandan hesaplanır — bu da yönden
  /// bağımsızdır.
  static String scaleFilter({
    required int width,
    required int height,
    required VideoScaleMode mode,
  }) =>
      switch (mode) {
        VideoScaleMode.exactBoth => 'scale=w=$width:h=$height:flags=bicubic',
        VideoScaleMode.exactWidth => 'scale=w=$width:h=-2:flags=bicubic',
        VideoScaleMode.exactHeight => 'scale=w=-2:h=$height:flags=bicubic',
        VideoScaleMode.fit => () {
            final longEdge = width > height ? width : height;
            return 'scale=w=$longEdge:h=$longEdge'
                ':force_original_aspect_ratio=decrease'
                ':force_divisible_by=2'
                ':flags=bicubic';
          }(),
      };

  /// FFmpeg argümanlarını kurar. **Saf fonksiyon → birim testli**: burada tek
  /// bir yazım hatası "video hiç dönüşmüyor" demektir ve cihazda görülür.
  static List<String> buildArgs({
    required String source,
    required String output,
    required int width,
    required int height,
    VideoScaleMode mode = VideoScaleMode.fit,
    int? fps,
    required int crf,
    required bool removeAudio,
    required String encoder,
  }) {
    final filters = <String>[
      // SIRA ÖNEMLİ — kare atma ÖLÇEKLEMEDEN ÖNCE. Tersi (eski hâli) atılacak
      // kareleri de ölçekliyordu: 60 fps videoyu 30 fps'e indirirken
      // ölçekleyicinin işinin YARISI çöpe gidiyordu. Kullanıcı hatası
      // 2026-07-30: "video boyutu küçültme çok yavaş yapılıyor".
      if (fps != null) 'fps=$fps',
      scaleFilter(width: width, height: height, mode: mode),
    ];
    return <String>[
      '-y', // çıktı yolunu biz üretiyoruz; sorulmadan yazsın
      '-i', source,
      '-vf', filters.join(','),
      '-c:v', encoder,
      // Yazılım kodlayıcıda tüm çekirdekler kullanılsın (`0` = otomatik).
      // mpeg4 dilim (slice) çoklu izleğini destekliyor; tek izlekte 1080p
      // kodlamak telefonda dakikalar sürüyor. Donanım kodlayıcıda bu değer
      // yoksayılır, zararı yok.
      if (encoder == 'mpeg4') ...['-threads', '0'],
      // Kalite ayarı kodlayıcıya göre değişir:
      //  • donanım (h264_mediacodec) CRF anlamaz → bit hızı,
      //  • mpeg4 CRF anlamaz → 2..31 arası nicemleyici (-q:v; küçük = iyi).
      if (encoder == 'mpeg4')
        ...['-q:v', '${_mpeg4QualityFor(crf)}']
      else
        ...['-b:v', '${_bitrateFor(width, height, crf, fps)}k'],
      '-pix_fmt', 'yuv420p', // eski oynatıcılar 4:2:0 dışını açmaz
      if (removeAudio) '-an' else ...['-c:a', 'aac', '-b:a', '128k'],
      '-map_metadata', '0', // çekim tarihi korunsun
      '-movflags', '+faststart',
      output,
    ];
  }

  /// `mpeg4` kodlayıcısının nicemleyicisi (2..31; küçük = daha iyi kalite).
  ///
  /// CRF ölçeği (20..32) bu aralığa doğrusal değil **kaba** eşlenir: mpeg4
  /// zaten yedek yol, buradaki amaç "yüksek kalite seçince gözle görülür daha
  /// iyi" davranışını korumak.
  static int _mpeg4QualityFor(int crf) => switch (crf) {
        <= 20 => 3,
        <= 24 => 5,
        <= 28 => 8,
        _ => 12,
      };

  /// Donanım kodlayıcı için kaba bit hızı (kbit/s): piksel sayısı × kare sayısı
  /// × CRF'den türetilmiş kalite katsayısı.
  ///
  /// [fps] verilirse hesaba KATILIR (yoksa 30 varsayılır). Sabit 30 varsayımı,
  /// "15 fps" seçen kullanıcıya gereğinin iki katı bit hızı ayırıyordu — yani
  /// kare sayısını yarıya indirmek dosyayı beklendiği kadar küçültmüyordu
  /// (2026-07-29 sadakat denetimi, 2. tur).
  static int _bitrateFor(int width, int height, int crf, [int? fps]) {
    final pixels = width * height;
    // CRF 20 → ~0.11 bit/piksel/kare, CRF 32 → ~0.04.
    final bitsPerPixel = switch (crf) {
      <= 20 => 0.11,
      <= 24 => 0.08,
      <= 28 => 0.055,
      _ => 0.04,
    };
    final rate = (fps != null && fps > 0) ? fps : 30;
    final kbps = (pixels * rate * bitsPerPixel / 1000).round();
    return kbps.clamp(300, 20000);
  }

  /// Videoyu [width]x[height] ölçüsüne ve (verilirse) [fps] kare sayısına
  /// dönüştürür. Başarısızlıkta [FfmpegFailure] atar.
  ///
  /// [onProgress] 0..1 arası oran alır (süre bilinmiyorsa çağrılmaz).
  static Future<void> transcode({
    required String source,
    required String output,
    required int width,
    required int height,
    VideoScaleMode mode = VideoScaleMode.fit,
    int? fps,
    required VideoQualityChoice quality,
    required bool removeAudio,
    int durationMs = 0,
    void Function(double ratio)? onProgress,
    bool Function()? isCancelled,
    /// Denenecek kodlayıcılar, sırayla. Çağıran bunu **bilerek** ayırıyor:
    /// donanım denemesi ile yazılım denemesi arasında yedek (native
    /// MediaCodec) motorun sırası var — yazılım kodlama en son çare, çünkü
    /// telefonda dakikalar sürüyor (bkz. `VideoTranscoder.run`).
    List<String> encoders = const ['h264_mediacodec', 'mpeg4'],
  }) async {
    final crf = crfFor(quality);
    // GPL'li libx264 BİLİNÇLİ olarak yok (lisans; bkz. sınıf notu). Donanım
    // kodlayıcı yoksa ffmpeg saniyenin altında "Unknown encoder" ile döndüğü
    // için o deneme pahalı değil.
    Object? lastError;
    for (final encoder in encoders) {
      // İptal HER denemeden önce yoklanır. Eskiden yalnız oturumun içinde
      // bakılıyordu: kullanıcı ilk kodlayıcı hata verdiği anda "Durdur"a
      // bastıysa (ya da iptal, iptal dönüş kodu yerine hata olarak döndüyse)
      // İKİNCİ kodlayıcı sıfırdan başlıyor ve dakikalarca sürüyordu — düğme
      // çalışmıyor görünürdü (2026-07-29 sadakat denetimi).
      if (isCancelled?.call() ?? false) throw const FfmpegCancelled();
      try {
        await _run(
          buildArgs(
            source: source,
            output: output,
            width: width,
            height: height,
            mode: mode,
            fps: fps,
            crf: crf,
            removeAudio: removeAudio,
            encoder: encoder,
          ),
          durationMs: durationMs,
          onProgress: onProgress,
          isCancelled: isCancelled,
        );
        return;
      } on FfmpegCancelled {
        rethrow;
      } catch (e) {
        lastError = e;
      }
    }
    throw FfmpegFailure('$lastError');
  }

  static Future<void> _run(
    List<String> args, {
    required int durationMs,
    void Function(double ratio)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final done = Completer<void>();
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        if (done.isCompleted) return;
        final code = await session.getReturnCode();
        if (ReturnCode.isCancel(code)) {
          done.completeError(const FfmpegCancelled());
        } else if (ReturnCode.isSuccess(code)) {
          done.complete();
        } else {
          // Günlüğün SONU işe yarar (hata orada); tamamı megabaytlar olabilir.
          final log = await session.getAllLogsAsString() ?? '';
          final tail = log.length > 400 ? log.substring(log.length - 400) : log;
          done.completeError(FfmpegFailure(
              'ffmpeg ${code?.getValue()} · ${tail.trim()}'));
        }
      },
      null,
      (Statistics stats) {
        if (isCancelled?.call() ?? false) {
          unawaited(cancel());
          return;
        }
        if (durationMs > 0 && onProgress != null) {
          onProgress((stats.getTime() / durationMs).clamp(0.0, 1.0));
        }
      },
    );
    _sessionId = session.getSessionId();
    // İptal, istatistik geri çağrısından BAĞIMSIZ olarak da yoklanır.
    // İstatistik yalnız kodlanan kare oldukça gelir: ses akışı çözülürken,
    // uzun bir dosyanın başında ya da kodlayıcı bir şeyi beklerken hiç
    // gelmeyebilir. Tek yoklama yeri orası olduğu için "Durdur" bu aralıklarda
    // hiçbir şey yapmıyordu (2026-07-29 sadakat denetimi).
    final poll = isCancelled == null
        ? null
        : Timer.periodic(const Duration(milliseconds: 400), (timer) {
            if (done.isCompleted) {
              timer.cancel();
            } else if (isCancelled()) {
              timer.cancel();
              unawaited(cancel());
            }
          });
    try {
      await done.future;
    } finally {
      poll?.cancel();
      _sessionId = null;
    }
  }

  /// Süren dönüştürmeyi iptal eder.
  static Future<void> cancel() async {
    try {
      await FFmpegKit.cancel(_sessionId);
    } catch (_) {}
  }
}

class FfmpegFailure implements Exception {
  final String message;
  const FfmpegFailure(this.message);
  @override
  String toString() => message;
}

class FfmpegCancelled implements Exception {
  const FfmpegCancelled();
  @override
  String toString() => 'Dönüştürme iptal edildi';
}

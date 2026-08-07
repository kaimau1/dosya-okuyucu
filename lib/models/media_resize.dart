/// **Boyut düşürme ayarları** — fotoğraf ve video için tek model.
///
/// Kullanıcı isteği (2026-07-29): *"video fotoğraf boyut düşürme çözünürlük ve
/// kare sayısı değiştirme gibi işlemler"*.
///
/// Saf Dart (Flutter importu yok): çözünürlük hesabı ve dosya adı üretimi
/// birim testiyle sabitlensin diye — "1920x1080 videoyu %60'a indir" gibi
/// hesaplarda tek pikselli yanlışlar gözle görülmez ama en/boy oranını bozar.
library;

/// Hedef çözünürlük seçimi.
enum ResolutionChoice { keep, p480, p540, p720, p1080, percent, custom }

extension ResolutionChoiceLabel on ResolutionChoice {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ResolutionChoice.keep => 'enum.res_keep',
        ResolutionChoice.p480 => 'enum.res_480',
        ResolutionChoice.p540 => 'enum.res_540',
        ResolutionChoice.p720 => 'enum.res_720',
        ResolutionChoice.p1080 => 'enum.res_1080',
        ResolutionChoice.percent => 'enum.res_percent',
        ResolutionChoice.custom => 'enum.res_custom',
      };

  String get label => switch (this) {
        ResolutionChoice.keep => 'Değiştirme',
        ResolutionChoice.p480 => '480p',
        ResolutionChoice.p540 => '540p',
        ResolutionChoice.p720 => '720p (HD)',
        ResolutionChoice.p1080 => '1080p (Full HD)',
        ResolutionChoice.percent => 'Yüzdeyle küçült',
        ResolutionChoice.custom => 'Serbest en × boy',
      };

  /// Kademenin kısa kenarı (piksel); kademe değilse null.
  int? get shortEdge => switch (this) {
        ResolutionChoice.p480 => 480,
        ResolutionChoice.p540 => 540,
        ResolutionChoice.p720 => 720,
        ResolutionChoice.p1080 => 1080,
        _ => null,
      };
}

/// Görüntü çıktı biçimi. WebP yok: `image` paketi WebP **yazamıyor** (yalnız
/// okuyor); seçeneği göstermek dokunulduğunda hata veren bir düğme olurdu.
enum ImageOutputFormat { keep, jpeg, png }

extension ImageOutputFormatLabel on ImageOutputFormat {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        ImageOutputFormat.keep => 'enum.imgfmt_keep',
        ImageOutputFormat.jpeg => 'enum.imgfmt_jpeg',
        ImageOutputFormat.png => 'enum.imgfmt_png',
      };

  String get label => switch (this) {
        ImageOutputFormat.keep => 'Aynı kalsın',
        ImageOutputFormat.jpeg => 'JPEG (küçük)',
        ImageOutputFormat.png => 'PNG (kayıpsız)',
      };

  String? get extension => switch (this) {
        ImageOutputFormat.keep => null,
        ImageOutputFormat.jpeg => 'jpg',
        ImageOutputFormat.png => 'png',
      };
}

/// Video sıkıştırma sertliği (bit hızına eşlenir).
enum VideoQualityChoice { veryLow, low, medium, high }

extension VideoQualityChoiceLabel on VideoQualityChoice {
  /// Çeviri anahtarı (bkz. `FmCategoryLabel.labelKey`).
  String get labelKey => switch (this) {
        VideoQualityChoice.veryLow => 'enum.vq_very_low',
        VideoQualityChoice.low => 'enum.vq_low',
        VideoQualityChoice.medium => 'enum.vq_medium',
        VideoQualityChoice.high => 'enum.vq_high',
      };

  String get label => switch (this) {
        VideoQualityChoice.veryLow => 'En küçük dosya',
        VideoQualityChoice.low => 'Küçük',
        VideoQualityChoice.medium => 'Dengeli',
        VideoQualityChoice.high => 'Yüksek kalite',
      };
}

/// Kare sayısı seçenekleri. null = dokunma.
const List<int?> frameRateChoices = [null, 60, 30, 24, 15];

class MediaResizeOptions {
  final ResolutionChoice resolution;

  /// [ResolutionChoice.percent] için 10..95.
  final int percent;

  /// [ResolutionChoice.custom] için hedef ölçüler (biri verilirse diğeri
  /// en/boy oranından hesaplanır).
  final int? customWidth;
  final int? customHeight;

  /// JPEG kalitesi 1..100 (yalnız görüntü).
  final int imageQuality;
  final ImageOutputFormat imageFormat;

  final VideoQualityChoice videoQuality;

  /// Hedef kare sayısı; null = değiştirme.
  final int? frameRate;
  final bool removeAudio;

  /// Özgün dosya çöp kutusuna gönderilsin mi? **Varsayılan hayır** — boyut
  /// düşürmek geri alınamaz bir kayıptır, kullanıcı açıkça istemeli.
  final bool replaceOriginal;

  const MediaResizeOptions({
    this.resolution = ResolutionChoice.p1080,
    this.percent = 50,
    this.customWidth,
    this.customHeight,
    this.imageQuality = 80,
    this.imageFormat = ImageOutputFormat.keep,
    this.videoQuality = VideoQualityChoice.medium,
    this.frameRate,
    this.removeAudio = false,
    this.replaceOriginal = false,
  });

  /// Diske yazılabilir hâli — **yarıda kalan işi yeniden başlatmak** için
  /// (bkz. `JobRecipe`). Kuyruktaki işin gövdesi bir closure ve kaydedilemez;
  /// kaydedilen şey işin tarifi: hangi dosyalara hangi ayarlar.
  Map<String, Object?> toJson() => {
        'resolution': resolution.name,
        'percent': percent,
        if (customWidth != null) 'customWidth': customWidth,
        if (customHeight != null) 'customHeight': customHeight,
        'imageQuality': imageQuality,
        'imageFormat': imageFormat.name,
        'videoQuality': videoQuality.name,
        if (frameRate != null) 'frameRate': frameRate,
        'removeAudio': removeAudio,
        'replaceOriginal': replaceOriginal,
      };

  /// Kayıttan okur; tanınmayan/eksik alanlar varsayılana düşer (eski sürümün
  /// yazdığı kayıt yeni sürümde de açılabilsin).
  static MediaResizeOptions fromJson(Object? raw) {
    if (raw is! Map) return const MediaResizeOptions();
    T pick<T extends Enum>(List<T> values, Object? name, T fallback) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return fallback;
    }

    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return MediaResizeOptions(
      resolution:
          pick(ResolutionChoice.values, raw['resolution'], ResolutionChoice.p1080),
      percent: asInt(raw['percent']) ?? 50,
      customWidth: asInt(raw['customWidth']),
      customHeight: asInt(raw['customHeight']),
      imageQuality: asInt(raw['imageQuality']) ?? 80,
      imageFormat:
          pick(ImageOutputFormat.values, raw['imageFormat'], ImageOutputFormat.keep),
      videoQuality: pick(
          VideoQualityChoice.values, raw['videoQuality'], VideoQualityChoice.medium),
      frameRate: asInt(raw['frameRate']),
      removeAudio: raw['removeAudio'] == true,
      replaceOriginal: raw['replaceOriginal'] == true,
    );
  }

  MediaResizeOptions copyWith({
    ResolutionChoice? resolution,
    int? percent,
    int? customWidth,
    int? customHeight,
    bool clearCustom = false,
    int? imageQuality,
    ImageOutputFormat? imageFormat,
    VideoQualityChoice? videoQuality,
    int? frameRate,
    bool clearFrameRate = false,
    bool? removeAudio,
    bool? replaceOriginal,
  }) =>
      MediaResizeOptions(
        resolution: resolution ?? this.resolution,
        percent: percent ?? this.percent,
        customWidth: clearCustom ? null : (customWidth ?? this.customWidth),
        customHeight: clearCustom ? null : (customHeight ?? this.customHeight),
        imageQuality: imageQuality ?? this.imageQuality,
        imageFormat: imageFormat ?? this.imageFormat,
        videoQuality: videoQuality ?? this.videoQuality,
        frameRate: clearFrameRate ? null : (frameRate ?? this.frameRate),
        removeAudio: removeAudio ?? this.removeAudio,
        replaceOriginal: replaceOriginal ?? this.replaceOriginal,
      );

  /// Çözünürlük gerçekten değişiyor mu? (Yalnız kalite/fps değişiyorsa video
  /// motoru seçimi farklı olur.)
  bool get changesResolution => resolution != ResolutionChoice.keep;

  /// **Serbest** ölçü mü isteniyor? (Kademe değil.)
  ///
  /// Fotoğrafta birebir uygulanır. Videoda motor birebir piksel almadığı için
  /// hedef en yakın alt kademeye eşlenir ve arayüz bunu yazar — bu bayrak o
  /// uyarıyı tetikler (gerekçe: `services/fm/video_transcode.dart`).
  bool get needsExactSize =>
      resolution == ResolutionChoice.custom ||
      resolution == ResolutionChoice.percent;

  /// Ayarların **kararlı özeti** — kuyruk kimliğinin bir parçası.
  ///
  /// Niye: kimlik yalnız dosya sayısı + ilk yola bakıyordu; aynı seçimi önce
  /// 720p sonra 480p için başlatmak aynı kimliği üretiyor, kuyruk "bu iş zaten
  /// sürüyor" deyip İKİNCİSİNİ SESSİZCE YUTUYORDU — arayüz "arka planda
  /// başladı" diyor, hiçbir şey olmuyordu (2026-07-29 sadakat denetimi).
  String get signature => [
        resolution.name,
        percent,
        customWidth ?? '-',
        customHeight ?? '-',
        imageQuality,
        imageFormat.name,
        videoQuality.name,
        frameRate ?? '-',
        removeAudio ? 'sessiz' : 'sesli',
        replaceOriginal ? 'degistir' : 'kopya',
      ].join('/');

  /// Dosya adına eklenecek ek ("_720p", "_1280x720", "_%50", "_kucuk").
  String get suffix {
    if (resolution == ResolutionChoice.percent) return '%$percent';
    if (resolution == ResolutionChoice.custom) {
      final w = customWidth;
      final h = customHeight;
      if (w != null && h != null) return '${w}x$h';
      if (w != null) return 'g$w';
      if (h != null) return 'y$h';
      return 'kucuk';
    }
    final edge = resolution.shortEdge;
    return edge != null ? '${edge}p' : 'kucuk';
  }
}

/// JPEG'in bir piksele ayırdığı **kabaca** bayt sayısı, kaliteye göre.
///
/// Fotoğraf gibi (gürültülü, geniş tonlu) içerikte ölçülen tipik değerler.
/// Ara değerler doğrusal geçişle bulunur. Tahminin tamamı bu tabloya dayanır;
/// arayüz de sonucu "≈" ile yazar — kesin boyut ancak kodlandıktan sonra
/// bilinir.
double jpegBytesPerPixel(int quality) {
  const table = <int, double>{
    40: 0.08, 50: 0.10, 60: 0.13, 70: 0.16, 75: 0.19,
    80: 0.22, 85: 0.28, 90: 0.38, 95: 0.55, 100: 1.00,
  };
  final q = quality.clamp(40, 100);
  final keys = table.keys.toList()..sort();
  if (q <= keys.first) return table[keys.first]!;
  for (var i = 1; i < keys.length; i++) {
    if (q > keys[i]) continue;
    final lo = keys[i - 1], hi = keys[i];
    final t = (q - lo) / (hi - lo);
    return table[lo]! + (table[hi]! - table[lo]!) * t;
  }
  return table[keys.last]!;
}

/// Video sıkıştırma sertliğinin **piksel başına bit** karşılığı.
///
/// `FfmpegVideo` donanım kodlayıcıya bit hızını bu katsayıyla veriyor
/// (CRF 20 → 0.11, CRF 32 → 0.04); tahmin de aynı sayıları kullanmalı, yoksa
/// "tahmini boyut" ile çıkan dosya sistematik olarak ayrışır.
double videoBitsPerPixel(VideoQualityChoice quality) => switch (quality) {
      VideoQualityChoice.high => 0.11,
      VideoQualityChoice.medium => 0.08,
      VideoQualityChoice.low => 0.055,
      VideoQualityChoice.veryLow => 0.04,
    };

/// Sesin kapladığı yer (bit/sn) — ses atılmadıysa tahmine eklenir.
const int _audioBitrate = 128000;

/// Seçilen bir medya dosyasının **şu anki** özellikleri.
///
/// KÖK NEDEN (kullanıcı 2026-08-07: *"video boyut düşürmede şu anki durum
/// görülmeli, her alanda çözünürlük kare sayısı vs görülmeli ki ne yapacağımızı
/// bilelim"*): ayar sayfası "1080p / 720p" gibi hedefler sunuyordu ama kaynağın
/// NE OLDUĞUNU söylemiyordu. 720p bir videoya 1080p seçmek hiçbir şey
/// kazandırmaz; kullanıcı bunu ancak dakikalarca bekleyip "küçülmedi" yazısını
/// gördükten sonra anlıyordu.
class MediaSourceInfo {
  final String name;
  final int sizeBytes;
  final bool isVideo;

  /// Video/görüntü ölçüsü (bilinmiyorsa 0).
  final int width;
  final int height;

  /// Videonun kare sayısı ve süresi (görüntüde null/0).
  final double? fps;
  final int durationMs;

  const MediaSourceInfo({
    required this.name,
    required this.sizeBytes,
    required this.isVideo,
    this.width = 0,
    this.height = 0,
    this.fps,
    this.durationMs = 0,
  });

  bool get hasSize => width > 0 && height > 0;

  /// Ortalama bit hızı (bit/sn). Süre ya da boyut bilinmiyorsa null —
  /// uydurma değer yazmak "ne yapacağımızı bilelim"in tam tersi olurdu.
  int? get bitrate => durationMs > 0 && sizeBytes > 0
      ? (sizeBytes * 8 / (durationMs / 1000)).round()
      : null;

  /// Bu ayarlarla çıkacak ölçü (kaynak bilinmiyorsa null).
  ({int width, int height})? targetFor(MediaResizeOptions options) => hasSize
      ? targetSize(
          sourceWidth: width, sourceHeight: height, options: options)
      : null;

  /// Bu ayarlarla çıkacak kare sayısı. Kaynaktan yüksek istenirse kaynağınki
  /// geçerlidir (ffmpeg kare kopyalar, dosya şişer — bkz.
  /// `VideoTranscoder.cappedFps`).
  int? targetFps(MediaResizeOptions options) {
    final wanted = options.frameRate;
    if (wanted == null) return fps?.round();
    final source = fps;
    if (source == null || source <= 0) return wanted;
    return wanted > source.floor() ? source.floor() : wanted;
  }

  /// Dosya uzantısı (küçük harf, noktasız). Çıktı biçimi "Aynı kalsın"
  /// seçildiğinde tahmin bunu bilmek zorunda: PNG kayıpsızdır, JPEG değil.
  String get extension {
    final dot = name.lastIndexOf('.');
    return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  /// Bu ayarlarla çıkacak **tahmini** boyut (bayt); kestirilemiyorsa null.
  ///
  /// KÖK NEDEN (kullanıcı 2026-08-07: *"boyut düşürmede tahmini boyut
  /// yazmalı"*): sayfa "480p / Küçük / 30 fps" gibi seçenekler sunuyor ama
  /// bunların 200 MB'lık bir videoyu 20 MB'a mı 120 MB'a mı indireceğini
  /// söylemiyordu. Kullanıcı ancak dakikalarca süren kodlamadan SONRA
  /// öğreniyordu — yani seçimi bilerek yapamıyordu.
  ///
  /// Tahmin **kaynağın kendi boyutunu aşmaz**: iş zaten büyüyen çıktıyı siler
  /// ("kazanç yok" der), daha büyük bir sayı yazmak yanıltıcı olurdu.
  int? estimatedBytes(MediaResizeOptions options) {
    final estimate = isVideo ? _videoEstimate(options) : _imageEstimate(options);
    if (estimate == null || estimate <= 0) return null;
    if (sizeBytes > 0 && estimate > sizeBytes) return sizeBytes;
    return estimate;
  }

  int? _videoEstimate(MediaResizeOptions options) {
    final target = targetFor(options);
    if (target == null || durationMs <= 0) return null;
    final fpsOut = targetFps(options) ?? 30;
    if (fpsOut <= 0) return null;
    final seconds = durationMs / 1000;
    final raw = target.width * target.height * fpsOut *
        videoBitsPerPixel(options.videoQuality);
    // Kodlayıcıyla aynı sınırlar (300 kbit/s .. 20 Mbit/s).
    final bitrate = raw.clamp(300000.0, 20000000.0);
    final audio = options.removeAudio ? 0.0 : _audioBitrate.toDouble();
    return ((bitrate + audio) * seconds / 8).round();
  }

  int? _imageEstimate(MediaResizeOptions options) {
    // Ölçü oranı: piksel sayısı ne kadar azalıyor?
    final double? ratio;
    if (hasSize) {
      final t = targetFor(options);
      if (t == null) return null;
      ratio = (t.width * t.height) / (width * height);
    } else if (options.resolution == ResolutionChoice.keep) {
      ratio = 1;
    } else if (options.resolution == ResolutionChoice.percent) {
      final s = options.percent.clamp(10, 100) / 100;
      ratio = s * s;
    } else {
      // Kaynağın ölçüsü bilinmeden "480p'ye inince ne olur" denemez.
      return null;
    }

    final outExt = options.imageFormat.extension ?? extension;
    const lossless = {'png', 'bmp', 'tga', 'tif', 'tiff'};
    if (lossless.contains(outExt)) {
      // Kayıpsız çıktıda dosya boyutu piksel sayısına bağlı; kaynağın kendi
      // sıkıştırması hiçbir şey söylemez.
      if (!hasSize) return null;
      final pixels = width * height * ratio;
      return (pixels * (outExt == 'png' ? 2.2 : 3.0)).round();
    }

    final sourceLossless = lossless.contains(extension);
    if (sourceLossless) {
      if (!hasSize) return null;
      final pixels = width * height * ratio;
      return (pixels * jpegBytesPerPixel(options.imageQuality)).round();
    }
    if (sizeBytes <= 0) return null;
    // JPEG → JPEG: kaynağın boyutu ~85 kalitede sayılır, seçilen kaliteye göre
    // ölçeklenir. Kaynağın kendi sıkıştırmasını bilmediğimiz için en sağlam
    // dayanak yine kendi boyutu.
    final factor = jpegBytesPerPixel(options.imageQuality) /
        jpegBytesPerPixel(85);
    return (sizeBytes * ratio * factor).round();
  }

  /// Ayarlar bu dosyada **hiçbir şeyi küçültmüyor** mu? (Çözünürlük aynı
  /// kalıyor ve kare sayısı düşmüyor.) Görüntülerde kalite/format da
  /// değiştiği için yalnız videoda anlamlı.
  bool noVisualChangeWith(MediaResizeOptions options) {
    if (!isVideo || !hasSize) return false;
    final target = targetFor(options);
    if (target == null) return false;
    final sameSize = target.width >= width && target.height >= height;
    final tFps = targetFps(options);
    final sameFps = fps == null || tFps == null || tFps >= fps!.floor();
    return sameSize && sameFps;
  }
}

/// Seçimin **tamamı** için tahmini boyut (önce → sonra).
///
/// Ölçülemeyen dosyalar (ayar sayfası hız için yalnız ilk birkaçını ölçüyor)
/// aynı türden ölçülebilenlerin **ortalama küçülme oranıyla** hesaba katılır:
/// 200 fotoğraflık bir seçimde yalnız 5'ini yazmak "toplam ne kazanacağım"
/// sorusunu cevapsız bırakırdı. Hiçbir dosya için tahmin üretilemiyorsa null.
({int before, int after})? estimateResizeTotal(
  List<MediaSourceInfo> sources,
  MediaResizeOptions options,
) {
  if (sources.isEmpty) return null;
  var before = 0;
  var after = 0.0;
  final ratios = <bool, List<double>>{true: [], false: []};
  final unknown = <MediaSourceInfo>[];

  for (final s in sources) {
    before += s.sizeBytes;
    final est = s.estimatedBytes(options);
    if (est == null || s.sizeBytes <= 0) {
      unknown.add(s);
      continue;
    }
    after += est;
    ratios[s.isVideo]!.add(est / s.sizeBytes);
  }
  double? average(List<double> list) => list.isEmpty
      ? null
      : list.reduce((a, b) => a + b) / list.length;
  final all = [...ratios[true]!, ...ratios[false]!];
  if (all.isEmpty) return null;
  for (final s in unknown) {
    final ratio = average(ratios[s.isVideo]!) ?? average(all)!;
    after += s.sizeBytes * ratio;
  }
  return (before: before, after: after.round());
}

/// Kaynak ölçüden hedef ölçüyü hesaplar (en/boy oranı korunur, çift sayıya
/// yuvarlanır).
///
/// Çift sayı şart: H.264 kodlayıcıları tek sayılı en/boy ile ya hata verir ya
/// da sessizce yuvarlar (video kayar). Görüntülerde de zararsız.
/// Kaynaktan **büyütme yapılmaz**: 720p bir videoyu "1080p" seçilse bile
/// büyütmek dosyayı şişirir, kalite katmaz.
({int width, int height}) targetSize({
  required int sourceWidth,
  required int sourceHeight,
  required MediaResizeOptions options,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    return (width: sourceWidth, height: sourceHeight);
  }
  int even(int v) => v < 2 ? 2 : (v - (v % 2));

  switch (options.resolution) {
    case ResolutionChoice.keep:
      return (width: even(sourceWidth), height: even(sourceHeight));
    case ResolutionChoice.percent:
      final scale = options.percent.clamp(10, 100) / 100;
      return (
        width: even((sourceWidth * scale).round()),
        height: even((sourceHeight * scale).round()),
      );
    case ResolutionChoice.custom:
      // "Kaynaktan büyütme yapılmaz" kuralı BURADA da geçerli — arayüz bunu
      // tam bu alanların altında yazıyor, oysa serbest ölçüde hiç
      // uygulanmıyordu: 1000x750 bir fotoğrafa 2000 yazmak dosyayı büyütüyor,
      // çıktı kaynaktan büyük çıkıyor ve iş "küçültülemedi" diye bitiyordu —
      // kullanıcı nedenini hiç öğrenmiyordu (2026-07-29 denetimi, 2. tur).
      final w = options.customWidth == null
          ? null
          : (options.customWidth! > sourceWidth
              ? sourceWidth
              : options.customWidth!);
      final h = options.customHeight == null
          ? null
          : (options.customHeight! > sourceHeight
              ? sourceHeight
              : options.customHeight!);
      if (w != null && h != null) return (width: even(w), height: even(h));
      if (w != null) {
        return (
          width: even(w),
          height: even((w * sourceHeight / sourceWidth).round()),
        );
      }
      if (h != null) {
        return (
          width: even((h * sourceWidth / sourceHeight).round()),
          height: even(h),
        );
      }
      return (width: even(sourceWidth), height: even(sourceHeight));
    case ResolutionChoice.p480:
    case ResolutionChoice.p540:
    case ResolutionChoice.p720:
    case ResolutionChoice.p1080:
      final edge = options.resolution.shortEdge!;
      final shortSide =
          sourceWidth < sourceHeight ? sourceWidth : sourceHeight;
      // Kaynak zaten hedeften küçükse dokunma (büyütme yok).
      if (shortSide <= edge) {
        return (width: even(sourceWidth), height: even(sourceHeight));
      }
      final scale = edge / shortSide;
      return (
        width: even((sourceWidth * scale).round()),
        height: even((sourceHeight * scale).round()),
      );
  }
}

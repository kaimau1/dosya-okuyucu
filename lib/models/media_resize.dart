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
///
/// Faz 14 (2026-10-22) — kullanıcı: *"kolay biçimde ve istediğim oranda
/// görüntü boyutlarını değiştiremiyorum"*. Fotoğrafa özel üç kip eklendi:
/// [longEdge] (fotoğrafın doğal dili: "uzun kenar 1600 px" — 480p/720p video
/// kademeleri fotoğrafta anlamsızdı), [aspect] (1:1, 4:5, 16:9… kırp ya da
/// kenar boşluğu ekle) ve [fileSize] ("en çok 200 KB" — resmî başvuru
/// formlarının tipik şartı). Kademeler ve [percent]/[custom] videoda da geçer.
enum ResolutionChoice {
  keep,
  p480,
  p540,
  p720,
  p1080,
  percent,
  custom,
  longEdge,
  aspect,
  fileSize,
}

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
        ResolutionChoice.longEdge => 'enum.res_long_edge',
        ResolutionChoice.aspect => 'enum.res_aspect',
        ResolutionChoice.fileSize => 'enum.res_file_size',
      };

  /// Yalnız fotoğrafta uygulanabilen kip mi? (Video motoru bunları
  /// yapmıyor; seçimde video varsa levha bunları göstermez.)
  bool get photoOnly => switch (this) {
        ResolutionChoice.longEdge ||
        ResolutionChoice.aspect ||
        ResolutionChoice.fileSize =>
          true,
        _ => false,
      };

  String get label => switch (this) {
        ResolutionChoice.keep => 'Değiştirme',
        ResolutionChoice.p480 => '480p',
        ResolutionChoice.p540 => '540p',
        ResolutionChoice.p720 => '720p (HD)',
        ResolutionChoice.p1080 => '1080p (Full HD)',
        ResolutionChoice.percent => 'Yüzdeyle küçült',
        ResolutionChoice.custom => 'Serbest en × boy',
        ResolutionChoice.longEdge => 'Uzun kenar',
        ResolutionChoice.aspect => 'En-boy oranı',
        ResolutionChoice.fileSize => 'Dosya boyutu',
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

/// Serbest en × boy'da (oran kilidi KAPALIYKEN) ve en-boy oranı kipinde
/// görüntünün kutuya nasıl yerleşeceği.
///
/// KÖK NEDEN (G4b): iki alan birden yazılınca görüntü sessizce **esniyordu**.
/// Artık esnetmek açık etiketli bir seçim; varsayılan oranı korur.
enum ResizeFit {
  /// Oran korunur, görüntü kutunun İÇİNE sığar (çıktı kutudan küçük olabilir).
  contain,

  /// Kutuyu doldurur, taşan kısım ortadan kırpılır (çıktı tam kutu).
  cover,

  /// Oran korunur, kalan yer kenar boşluğuyla doldurulur (çıktı tam kutu).
  pad,

  /// Oranı bilerek bozar (çıktı tam kutu).
  stretch,
}

extension ResizeFitLabel on ResizeFit {
  String get labelKey => 'rs.fit_$name';
}

/// Kenar boşluğu rengi ([ResizeFit.pad]).
enum PadColor { white, black, blur, transparent }

extension PadColorLabel on PadColor {
  String get labelKey => 'rs.pad_$name';
}

/// Fotoğrafa uygun **uzun kenar** kademeleri (px).
const List<int> longEdgeChoices = [720, 1080, 1280, 1600, 2048, 3840];

/// Hazır **en-boy oranları** (genişlik, yükseklik). A4 = 1:√2 (210×297).
const List<(String, double, double)> aspectChoices = [
  ('1:1', 1, 1),
  ('4:5', 4, 5),
  ('5:4', 5, 4),
  ('3:2', 3, 2),
  ('2:3', 2, 3),
  ('4:3', 4, 3),
  ('3:4', 3, 4),
  ('16:9', 16, 9),
  ('9:16', 9, 16),
  ('21:9', 21, 9),
  ('A4', 210, 297),
];

/// Hazır **dosya boyutu** hedefleri (KB).
const List<int> fileSizeChoicesKb = [100, 200, 500, 1024, 2048];

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

  /// [ResolutionChoice.percent] için 1..400 (fotoğraf; %100 üstü büyütür —
  /// K14) ya da 10..100 (video).
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

  /// Serbest en × boy'da **oran kilidi** (varsayılan AÇIK): iki alan birden
  /// dolu olsa da oran korunur ([ResizeFit.contain]). Kapalıyken [fit] geçer.
  final bool lockAspect;

  /// Kilit kapalı serbest ölçüde ve [ResolutionChoice.aspect]'te yerleşim
  /// (oran kipinde yalnız [ResizeFit.cover] = kırp ve [ResizeFit.pad]).
  final ResizeFit fit;
  final PadColor padColor;

  /// [ResolutionChoice.longEdge] hedefi (px).
  final int longEdgePx;

  /// [ResolutionChoice.aspect] oranı (genişlik : yükseklik).
  final double aspectW;
  final double aspectH;

  /// [ResolutionChoice.fileSize] hedefi (KB, 1 KB = 1024 bayt).
  final int targetKb;

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
    this.lockAspect = true,
    this.fit = ResizeFit.contain,
    this.padColor = PadColor.white,
    this.longEdgePx = 1600,
    this.aspectW = 1,
    this.aspectH = 1,
    this.targetKb = 200,
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
        'lockAspect': lockAspect,
        'fit': fit.name,
        'padColor': padColor.name,
        'longEdgePx': longEdgePx,
        'aspectW': aspectW,
        'aspectH': aspectH,
        'targetKb': targetKb,
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
    double? asDouble(Object? v) => v is num ? v.toDouble() : null;
    // **Eski tarif göçü (Faz 14):** `lockAspect` alanı yokken iki ölçü birden
    // verilmişse eski davranış ESNETMEKTİ — yarıda kalan eski bir iş devam
    // ettirildiğinde aynı çıktıyı üretsin.
    final legacyBoth = !raw.containsKey('lockAspect') &&
        raw['customWidth'] is num &&
        raw['customHeight'] is num;
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
      lockAspect: legacyBoth ? false : raw['lockAspect'] != false,
      fit: legacyBoth
          ? ResizeFit.stretch
          : pick(ResizeFit.values, raw['fit'], ResizeFit.contain),
      padColor: pick(PadColor.values, raw['padColor'], PadColor.white),
      longEdgePx: asInt(raw['longEdgePx']) ?? 1600,
      aspectW: asDouble(raw['aspectW']) ?? 1,
      aspectH: asDouble(raw['aspectH']) ?? 1,
      targetKb: asInt(raw['targetKb']) ?? 200,
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
    bool? lockAspect,
    ResizeFit? fit,
    PadColor? padColor,
    int? longEdgePx,
    double? aspectW,
    double? aspectH,
    int? targetKb,
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
        lockAspect: lockAspect ?? this.lockAspect,
        fit: fit ?? this.fit,
        padColor: padColor ?? this.padColor,
        longEdgePx: longEdgePx ?? this.longEdgePx,
        aspectW: aspectW ?? this.aspectW,
        aspectH: aspectH ?? this.aspectH,
        targetKb: targetKb ?? this.targetKb,
      );

  /// Serbest ölçüde GERÇEKTE uygulanan yerleşim: kilit açıkken hep
  /// [ResizeFit.contain] (oran korunur).
  ResizeFit get effectiveFit => lockAspect ? ResizeFit.contain : fit;

  /// Fotoğrafta istenen şey bir **ölçü/oran** mı (küçültme değil)? O zaman
  /// kaynaktan büyük çıktı da geçerli sonuçtur (bkz. `resize_actions._run`).
  bool get dimensionsAreGoal =>
      resolution == ResolutionChoice.custom ||
      resolution == ResolutionChoice.aspect ||
      (resolution == ResolutionChoice.percent && percent > 100);

  /// Seçilen ayar fotoğrafı **büyütüyor** mu (K14: izinli ama uyarılı)?
  /// Kaynak ölçüsü bilinmiyorsa yalnız yüzdeye bakılır.
  bool upscales({int? sourceWidth, int? sourceHeight}) {
    if (resolution == ResolutionChoice.percent) return percent > 100;
    if (resolution != ResolutionChoice.custom) return false;
    if (sourceWidth == null || sourceHeight == null) return false;
    return (customWidth ?? 0) > sourceWidth ||
        (customHeight ?? 0) > sourceHeight;
  }

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
        lockAspect ? 'kilit' : fit.name,
        padColor.name,
        longEdgePx,
        '${aspectW}x$aspectH',
        targetKb,
      ].join('/');

  /// Oran etiketi ("4:5", "A4" ya da "3.5:2").
  String get aspectLabel {
    for (final (label, w, h) in aspectChoices) {
      if (w == aspectW && h == aspectH) return label;
    }
    String n(double v) =>
        v == v.roundToDouble() ? '${v.round()}' : v.toStringAsFixed(1);
    return '${n(aspectW)}:${n(aspectH)}';
  }

  /// Dosya adına eklenecek ek ("_720p", "_1280x720", "_%50", "_kucuk").
  String get suffix {
    if (resolution == ResolutionChoice.percent) return '%$percent';
    if (resolution == ResolutionChoice.longEdge) return '${longEdgePx}px';
    if (resolution == ResolutionChoice.fileSize) {
      return targetKb >= 1024 && targetKb % 1024 == 0
          ? '${targetKb ~/ 1024}mb'
          : '${targetKb}kb';
    }
    if (resolution == ResolutionChoice.aspect) {
      return aspectLabel.replaceAll(':', '-').replaceAll('.', '_');
    }
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
/// `VideoTranscoder.bitrateFor` donanım kodlayıcıya bit hızını bu katsayıyla
/// veriyor; tahmin de aynı sayıları kullanır, yoksa "tahmini boyut" ile
/// çıkan dosya sistematik olarak ayrışır.
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
          sourceWidth: width,
          sourceHeight: height,
          options: options,
          video: isVideo)
      : null;

  /// Bu ayarlarla çıkacak kare sayısı. Kaynaktan yüksek istenirse kaynağınki
  /// geçerlidir (kodlayıcı kare kopyalar, dosya şişer — bkz.
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
    // Büyütmede (K14) çıktı kaynaktan büyük olur — o zaman tavan yok.
    final growing =
        options.upscales(sourceWidth: width, sourceHeight: height) ||
            (options.resolution == ResolutionChoice.aspect &&
                options.fit == ResizeFit.pad);
    if (sizeBytes > 0 && estimate > sizeBytes && !growing) return sizeBytes;
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
    // Dosya boyutu hedefi: motor hedefin ALTINA iner (ulaşamazsa en yakını
    // raporlar) — tahmin hedefin kendisi.
    if (options.resolution == ResolutionChoice.fileSize) {
      return options.targetKb * 1024;
    }
    // Ölçü oranı: piksel sayısı ne kadar azalıyor?
    final double? ratio;
    if (hasSize) {
      final t = targetFor(options);
      if (t == null) return null;
      ratio = (t.width * t.height) / (width * height);
    } else if (options.resolution == ResolutionChoice.keep) {
      ratio = 1;
    } else if (options.resolution == ResolutionChoice.percent) {
      final s = options.percent.clamp(1, 400) / 100;
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

/// Kaynak ölçüden hedef ölçüyü hesaplar.
///
/// [video] (varsayılan `true` — eski çağıranlar video yolundaydı):
/// * **Çift sayı** yalnız videoda: H.264 kodlayıcıları tek sayılı en/boy ile
///   ya hata verir ya da sessizce yuvarlar (video kayar). Fotoğrafta bu kural
///   yanlıştı — 1081 yazan 1080 alıyordu (G4k, Faz 14).
/// * **Büyütme** videoda yok (dosya şişer, kalite katmaz). Fotoğrafta yüzde
///   (%100 üstü) ve serbest ölçüde İZİNLİ (K14 (b), Faz 14: kullanıcı
///   "istediğim oranda" diyor; levha "büyütmek netlik eklemez" diye uyarır).
///   Eskiden fazlası sessizce kaynağa kırpılıyordu (G4c). Kademeler ve uzun
///   kenar "en çok" anlamındadır — onlarda büyütme yok.
///
/// Fotoğraf ölçüleri **görünen yönde** verilmelidir (EXIF yönü uygulanmış —
/// `ImageResizer.probeSize` ve çözücü bunu yapıyor; B11, Faz 10b).
({int width, int height}) targetSize({
  required int sourceWidth,
  required int sourceHeight,
  required MediaResizeOptions options,
  bool video = true,
}) {
  if (sourceWidth <= 0 || sourceHeight <= 0) {
    return (width: sourceWidth, height: sourceHeight);
  }
  int fix(num v) {
    final r = v.round();
    if (!video) return r < 1 ? 1 : r;
    return r < 2 ? 2 : (r - (r % 2));
  }

  ({int width, int height}) scaled(double scale) =>
      (width: fix(sourceWidth * scale), height: fix(sourceHeight * scale));

  switch (options.resolution) {
    case ResolutionChoice.keep:
    case ResolutionChoice.fileSize:
      // Dosya boyutu hedefi ölçüyü motor içinde (kalite yetmezse) düşürür;
      // tahmin için başlangıç ölçüsü kaynağınki.
      return (width: fix(sourceWidth), height: fix(sourceHeight));
    case ResolutionChoice.percent:
      final max = video ? 100 : 400;
      return scaled(options.percent.clamp(1, max) / 100);
    case ResolutionChoice.longEdge:
      final long = sourceWidth > sourceHeight ? sourceWidth : sourceHeight;
      if (long <= options.longEdgePx) return scaled(1);
      return scaled(options.longEdgePx / long);
    case ResolutionChoice.aspect:
      final ratio = options.aspectW / options.aspectH;
      if (ratio <= 0 || ratio.isNaN || ratio.isInfinite) return scaled(1);
      final srcRatio = sourceWidth / sourceHeight;
      final crop = options.fit != ResizeFit.pad;
      // Kırp: kaynağın İÇİNDEKİ en büyük oranlı dikdörtgen. Boşluk: kaynağı
      // İÇİNE alan en küçük oranlı dikdörtgen.
      final wider = srcRatio > ratio;
      if (crop == wider) {
        return (width: fix(sourceHeight * ratio), height: fix(sourceHeight));
      }
      return (width: fix(sourceWidth), height: fix(sourceWidth / ratio));
    case ResolutionChoice.custom:
      var w = options.customWidth;
      var h = options.customHeight;
      if (video) {
        // Videoda büyütme yok (yukarıdaki not).
        if (w != null && w > sourceWidth) w = sourceWidth;
        if (h != null && h > sourceHeight) h = sourceHeight;
      }
      if (w != null && h != null) {
        return switch (options.effectiveFit) {
          ResizeFit.contain => scaled(
              (w / sourceWidth) < (h / sourceHeight)
                  ? w / sourceWidth
                  : h / sourceHeight),
          _ => (width: fix(w), height: fix(h)),
        };
      }
      if (w != null) return (width: fix(w), height: fix(w * sourceHeight / sourceWidth));
      if (h != null) return (width: fix(h * sourceWidth / sourceHeight), height: fix(h));
      return scaled(1);
    case ResolutionChoice.p480:
    case ResolutionChoice.p540:
    case ResolutionChoice.p720:
    case ResolutionChoice.p1080:
      final edge = options.resolution.shortEdge!;
      final shortSide =
          sourceWidth < sourceHeight ? sourceWidth : sourceHeight;
      // Kaynak zaten hedeften küçükse dokunma (büyütme yok).
      if (shortSide <= edge) return scaled(1);
      return scaled(edge / shortSide);
  }
}

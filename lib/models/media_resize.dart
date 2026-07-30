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

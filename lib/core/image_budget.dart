import 'dart:math' as math;

/// Görsel çözme (decode) bütçesi — **bellek ve pil** koruması.
///
/// **Sorun (2026-08-07 denetimi):** galeri ve görüntüleyici `Image.file`ı
/// `cacheWidth` VERMEDEN kullanıyordu. Flutter o zaman dosyayı TAM
/// çözünürlükte bitmap'e açar: 12 MP'lik sıradan bir telefon fotoğrafı
/// (4000×3000) bellekte **48 MB** eder — dosyanın kendisi 3 MB olsa bile,
/// çünkü JPEG sıkıştırması çözülünce piksel başına 4 bayt kalır.
/// `PageView` komşu sayfayı da canlı tuttuğu için aynı anda iki-üç görsel
/// açılıyordu → 100 MB+ bitmap, sürekli çöp toplama, kaydırmada takılma ve
/// düşük bellekli telefonlarda sistemin uygulamayı öldürmesi. Sürekli
/// çöz-at döngüsü CPU'yu meşgul ettiği için **pil** de buna gidiyordu.
///
/// **Çözüm:** ekranda kaç piksel görüneceği kadar çöz. 1080 piksel geniş bir
/// telefonda tam sayfa görsel için 1024–1536 piksel yeter; kalanı gözle
/// görülmeyen bellek israfıdır.
///
/// **Yakınlaştırma:** kullanıcı 3 kat yakınlaştırınca gerçekten daha çok
/// piksel gerekir, yoksa görüntü bulanıklaşırdı. Bu yüzden ölçek hesaba
/// katılır — ama [maxWidth] tavanıyla: 6 kat yakınlaştırmada tam çözünürlüğe
/// dönmek ilk baştaki sorunu geri getirirdi.
///
/// **Kademe (`step`) niye var:** `cacheWidth` değiştikçe Flutter görseli
/// YENİDEN çözer ve önbellekte AYRI bir kayıt tutar. Ölçek sürekli değiştiği
/// için (parmak hareketi) her karede yeni bir genişlik istenirse saniyede
/// onlarca çözme yapılırdı — kademeye yuvarlamak yeniden çözmeyi elle
/// sayılabilecek kadar seyrekleştirir.
abstract final class ImageBudget {
  /// Çözme genişliği bu kadarlık kademelere yuvarlanır (piksel).
  static const step = 512;

  /// En düşük çözme genişliği — küçük ekranda bile bu kadarı istenir.
  static const minWidth = 512;

  /// Tavan. 3072×2304 ≈ 28 MB bitmap; tam çözünürlüğün (48 MB+) yarısından az
  /// ama 1080p ekranda 2,8 kat yakınlaştırmaya kadar keskin.
  static const maxWidth = 3072;

  /// [logicalWidth] mantıksal piksel genişliğindeki bir alanda, [devicePixelRatio]
  /// yoğunluğunda ve [zoom] kat yakınlaştırmayla gösterilecek görselin kaç
  /// piksel genişlikte çözülmesi gerektiğini söyler.
  ///
  /// Dönen değer daima [minWidth]–[maxWidth] arasında ve [step] katıdır.
  /// `Image.file(cacheWidth:)` kaynaktan BÜYÜK bir değeri kendiliğinden
  /// kaynağın boyutuna kısar (`allowUpscaling: false`), yani küçük bir görsel
  /// bu yüzden büyütülüp bellekte şişmez.
  static int decodeWidth({
    required double logicalWidth,
    required double devicePixelRatio,
    double zoom = 1,
  }) {
    final safeWidth = logicalWidth.isFinite && logicalWidth > 0
        ? logicalWidth
        : minWidth.toDouble();
    final safeRatio =
        devicePixelRatio.isFinite && devicePixelRatio > 0 ? devicePixelRatio : 1.0;
    final safeZoom = zoom.isFinite && zoom > 1 ? zoom : 1.0;
    final wanted = safeWidth * safeRatio * safeZoom;
    // Yukarı yuvarla: aşağı yuvarlamak istenen çözünürlüğün altında kalır ve
    // sınırdaki her görsel bir kademe bulanık çıkardı.
    final stepped = (wanted / step).ceil() * step;
    return stepped.clamp(minWidth, maxWidth);
  }

  /// Yakınlaştırma matrisinin ölçeğinden çözme genişliği (yaygın kullanım).
  ///
  /// Ölçek 1'in altındaysa (uzaklaştırma) 1 sayılır — daha az piksel çözmek
  /// bellekten bir şey kazandırmaz, yalnız uzaklaştırıp yaklaştıran kullanıcıya
  /// gereksiz bir yeniden çözme yaşatırdı.
  static int forViewport({
    required double logicalWidth,
    required double devicePixelRatio,
    required double scale,
  }) =>
      decodeWidth(
        logicalWidth: logicalWidth,
        devicePixelRatio: devicePixelRatio,
        zoom: math.max(1, scale),
      );
}

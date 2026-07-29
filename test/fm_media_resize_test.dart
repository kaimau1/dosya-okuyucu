import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/video_transcode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_compress/video_compress.dart';

/// **Niye bu test var:** boyut düşürmede en/boy oranı ve çift sayı kuralı
/// gözle görülmez ama bozulduğunda video kayar (H.264 tek sayılı ölçüyü
/// sevmez) ya da fotoğraf ezilir. "Kaynaktan büyütme yapma" kuralı da burada
/// kilitli: 720p bir videoyu 1080p'ye çıkarmak dosyayı şişirir, kalite katmaz.
void main() {
  ({int width, int height}) size(
    int w,
    int h,
    MediaResizeOptions options,
  ) =>
      targetSize(sourceWidth: w, sourceHeight: h, options: options);

  group('kademeler', () {
    test('1080p: 4K yatay video oranı korunarak inecek', () {
      final r = size(3840, 2160,
          const MediaResizeOptions(resolution: ResolutionChoice.p1080));
      expect(r.height, 1080);
      expect(r.width, 1920);
    });

    test('720p: DİKEY videoda kısa kenar (genişlik) hedefe iner', () {
      final r = size(1080, 1920,
          const MediaResizeOptions(resolution: ResolutionChoice.p720));
      expect(r.width, 720);
      expect(r.height, 1280);
    });

    test('kaynak hedeften küçükse BÜYÜTME yapılmaz', () {
      final r = size(640, 480,
          const MediaResizeOptions(resolution: ResolutionChoice.p1080));
      expect(r.width, 640);
      expect(r.height, 480);
    });

    test('“değiştirme” ölçüyü korur (yalnız çift sayıya yuvarlar)', () {
      final r = size(1921, 1081,
          const MediaResizeOptions(resolution: ResolutionChoice.keep));
      expect(r.width, 1920);
      expect(r.height, 1080);
    });
  });

  group('yüzde', () {
    test('%50 her iki kenarı yarıya indirir', () {
      final r = size(
          1920,
          1080,
          const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 50));
      expect(r.width, 960);
      expect(r.height, 540);
    });

    test('tek sayı üreten yüzde çift sayıya yuvarlanır', () {
      final r = size(
          1000,
          1000,
          const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 33));
      expect(r.width.isEven, isTrue);
      expect(r.height.isEven, isTrue);
      expect(r.width, 330);
    });
  });

  group('serbest ölçü', () {
    test('yalnız genişlik verilirse yükseklik orandan hesaplanır', () {
      final r = size(
          1920,
          1080,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customWidth: 1280));
      expect(r.width, 1280);
      expect(r.height, 720);
    });

    test('yalnız yükseklik verilirse genişlik orandan hesaplanır', () {
      final r = size(
          1920,
          1080,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customHeight: 540));
      expect(r.height, 540);
      expect(r.width, 960);
    });

    test('ikisi de verilirse oran KORUNMAZ (kullanıcı açıkça istedi)', () {
      final r = size(
          1920,
          1080,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom,
              customWidth: 800,
              customHeight: 800));
      expect(r.width, 800);
      expect(r.height, 800);
    });

    test('hiçbiri verilmezse kaynak korunur (bölme hatası yok)', () {
      final r = size(1920, 1080,
          const MediaResizeOptions(resolution: ResolutionChoice.custom));
      expect(r.width, 1920);
    });
  });

  group('bozuk girdi', () {
    test('sıfır ölçü çökertmez', () {
      final r = size(0, 0,
          const MediaResizeOptions(resolution: ResolutionChoice.p720));
      expect(r.width, 0);
      expect(r.height, 0);
    });

    test('2 pikselin altına düşülmez', () {
      final r = size(
          4,
          4,
          const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 10));
      expect(r.width, greaterThanOrEqualTo(2));
    });
  });

  group('dosya adı eki', () {
    test('kademe adı yazılır', () {
      expect(
          const MediaResizeOptions(resolution: ResolutionChoice.p720).suffix,
          '720p');
    });

    test('yüzde ve serbest ölçü okunur biçimde yazılır', () {
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.percent, percent: 40)
              .suffix,
          '%40');
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.custom,
                  customWidth: 800,
                  customHeight: 600)
              .suffix,
          '800x600');
      expect(
          const MediaResizeOptions(
                  resolution: ResolutionChoice.custom, customWidth: 800)
              .suffix,
          'g800');
    });
  });

  group('serbest ölçü bayrağı', () {
    test('kademe serbest ölçü İSTEMEZ', () {
      expect(
          const MediaResizeOptions(resolution: ResolutionChoice.p720)
              .needsExactSize,
          isFalse);
    });

    test('yüzde ve serbest ölçü “birebir” ister (videoda uyarı tetikler)', () {
      expect(
          const MediaResizeOptions(resolution: ResolutionChoice.percent)
              .needsExactSize,
          isTrue);
      expect(
          const MediaResizeOptions(resolution: ResolutionChoice.custom)
              .needsExactSize,
          isTrue);
    });

    test('“değiştirme” çözünürlüğü değiştirmiyor sayılır', () {
      expect(
          const MediaResizeOptions(resolution: ResolutionChoice.keep)
              .changesResolution,
          isFalse);
    });
  });

  group('copyWith', () {
    test('kare sayısı temizlenebilir (null “dokunma” demek)', () {
      const base = MediaResizeOptions(frameRate: 30);
      expect(base.copyWith(clearFrameRate: true).frameRate, isNull);
      expect(base.copyWith(frameRate: 60).frameRate, 60);
    });

    test('serbest ölçü temizlenebilir', () {
      const base = MediaResizeOptions(customWidth: 800, customHeight: 600);
      final cleared = base.copyWith(clearCustom: true);
      expect(cleared.customWidth, isNull);
      expect(cleared.customHeight, isNull);
    });

    test('özgün dosya varsayılan olarak KORUNUR', () {
      expect(const MediaResizeOptions().replaceOriginal, isFalse);
    });
  });

  group('YEDEK video motorunun kademe eşlemesi', () {
    // Birincil motor (FFmpeg) birebir ölçü veriyor; bu eşleme yalnız FFmpeg
    // çalışmadığında devreye giren yedek motor (MediaCodec) için. Hedef ölçü
    // en yakın ALT kademeye iner: yukarı yuvarlamak "küçült" isteğine rağmen
    // daha büyük dosya üretirdi — bu testin tek işi o yönü kilitlemek.
    test('hedef kısa kenar kademeye AŞAĞI yuvarlanır', () {
      expect(VideoTranscoder.qualityForShortEdge(1080),
          VideoQuality.Res1920x1080Quality);
      expect(VideoTranscoder.qualityForShortEdge(900),
          VideoQuality.Res1280x720Quality);
      expect(VideoTranscoder.qualityForShortEdge(720),
          VideoQuality.Res1280x720Quality);
      expect(VideoTranscoder.qualityForShortEdge(700),
          VideoQuality.Res960x540Quality);
      expect(VideoTranscoder.qualityForShortEdge(540),
          VideoQuality.Res960x540Quality);
    });

    test('en küçük kademenin altı yine en küçük kademedir', () {
      expect(VideoTranscoder.qualityForShortEdge(120),
          VideoQuality.Res640x480Quality);
    });

    test('4K kaynak 1080p’nin üstünde kalmaz', () {
      expect(VideoTranscoder.qualityForShortEdge(2160),
          VideoQuality.Res1920x1080Quality);
    });
  });
}

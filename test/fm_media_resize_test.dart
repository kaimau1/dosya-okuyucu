import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/image_resize.dart';
import 'package:dosya_okuyucu/services/fm/similar_finder.dart';
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

  // ── "Aynı kalsın" biçiminde çıktının UZANTISI ───────────────────────────────
  // Kök neden (2026-07-29 sadakat denetimi): kaynağın uzantısı körü körüne
  // korunuyordu ama `ImageResizer` yalnız JPEG/PNG/BMP/TGA yazabiliyor. Sonuç
  // `.webp` adlı, İÇİ JPEG olan dosyalardı — galeride açılmaz, paylaşımda bozuk
  // görünür. "Özgün dosyayı çöp kutusuna at" açıkken kaybı geri almak da güç.
  group('keepExtension (Aynı kalsın)', () {
    test('yazabildiğimiz biçimler korunur', () {
      expect(ImageResizer.keepExtension('/a/b/foto.png'), 'png');
      expect(ImageResizer.keepExtension('/a/b/foto.JPG'), 'jpg');
      expect(ImageResizer.keepExtension('/a/b/foto.jpeg'), 'jpeg');
      expect(ImageResizer.keepExtension('/a/b/tarama.bmp'), 'bmp');
    });

    test('YAZAMADIĞIMIZ biçimler jpg olur (içerik JPEG çünkü)', () {
      expect(ImageResizer.keepExtension('/a/b/foto.webp'), 'jpg');
      expect(ImageResizer.keepExtension('/a/b/foto.gif'), 'jpg');
      expect(ImageResizer.keepExtension('/a/b/IMG_1.heic'), 'jpg');
      expect(ImageResizer.keepExtension('/a/b/tarama.tiff'), 'jpg');
    });

    test('uzantısız kaynak jpg olur ("foto_720p." hiçbir yerde açılmaz)', () {
      expect(ImageResizer.keepExtension('/a/b/whatsapp-gecici'), 'jpg');
    });

    test('encodableExtensions kümesi jpg’yi de içerir (tutarlılık)', () {
      for (final ext in ImageResizer.encodableExtensions) {
        expect(ImageResizer.keepExtension('/a/b/x.$ext'), ext);
      }
    });
  });

  // ── Kuyruk kimlikleri ──────────────────────────────────────────────────────
  // İkisi de aynı hatanın iki yüzü: kimlik işi TAM olarak tanımlamazsa kuyruk
  // farklı işleri aynı iş sanıyor. Boyut düşürmede bu "başlattım ama hiçbir şey
  // olmadı", benzer taramada "başka kapsamın sonucunu kendi sonucu sanma".
  group('ayar imzası (kuyruk kimliği)', () {
    test('aynı ayarlar aynı imzayı verir', () {
      expect(const MediaResizeOptions().signature,
          const MediaResizeOptions().signature);
    });

    test('her ayar alanı imzayı DEĞİŞTİRİR', () {
      const base = MediaResizeOptions();
      final others = [
        base.copyWith(resolution: ResolutionChoice.p480),
        base.copyWith(percent: 33),
        base.copyWith(customWidth: 1234),
        base.copyWith(customHeight: 568),
        base.copyWith(imageQuality: 55),
        base.copyWith(imageFormat: ImageOutputFormat.png),
        base.copyWith(videoQuality: VideoQualityChoice.high),
        base.copyWith(frameRate: 24),
        base.copyWith(removeAudio: true),
        base.copyWith(replaceOriginal: true),
      ];
      for (final o in others) {
        expect(o.signature, isNot(base.signature),
            reason: 'imza bu ayarı yansıtmıyor → kuyruk işi yutar');
      }
      // Hepsi birbirinden de farklı olmalı (çakışma yok).
      expect(others.map((o) => o.signature).toSet().length, others.length);
    });
  });

  // ── Serbest ölçüde "büyütme yok" ───────────────────────────────────────────
  // Arayüz bu kuralı tam serbest ölçü alanlarının ALTINDA yazıyor, oysa kural
  // yalnız kademelerde uygulanıyordu: 1000 px bir fotoğrafa 2000 yazmak dosyayı
  // büyütüyor, çıktı kaynaktan büyük çıkıyor ve iş "küçültülemedi" diye bitiyor.
  group('serbest ölçü kaynaktan büyütmez', () {
    test('genişlik kaynaktan büyükse kaynağa çekilir', () {
      final r = size(
          1000,
          750,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customWidth: 2000));
      expect(r.width, 1000);
      expect(r.height, 750);
    });

    test('yükseklik kaynaktan büyükse kaynağa çekilir', () {
      final r = size(
          1000,
          750,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customHeight: 3000));
      expect(r.height, 750);
      expect(r.width, 1000);
    });

    test('ikisi de büyükse ikisi de kaynağa çekilir', () {
      final r = size(
          1024,
          768,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom,
              customWidth: 4000,
              customHeight: 3000));
      expect(r.width, 1024);
      expect(r.height, 768);
    });

    test('kaynaktan KÜÇÜK istenen ölçü aynen uygulanır (kırpma yok)', () {
      final r = size(
          4000,
          3000,
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom,
              customWidth: 1234,
              customHeight: 568));
      expect(r.width, 1234);
      expect(r.height, 568);
    });
  });

  // ── Kare sayısı da büyütülmez ──────────────────────────────────────────────
  group('cappedFps', () {
    test('kaynaktan yüksek istek kaynağa çekilir', () {
      expect(VideoTranscoder.cappedFps(60, 30.0), 30);
      expect(VideoTranscoder.cappedFps(30, 23.976), 23);
    });

    test('kaynaktan düşük istek aynen geçer', () {
      expect(VideoTranscoder.cappedFps(15, 30.0), 15);
      expect(VideoTranscoder.cappedFps(24, 29.97), 24);
    });

    test('"Değiştirme" (null) null kalır', () {
      expect(VideoTranscoder.cappedFps(null, 30.0), isNull);
    });

    test('kaynağın hızı bilinmiyorsa istek olduğu gibi geçer', () {
      expect(VideoTranscoder.cappedFps(60, null), 60);
      expect(VideoTranscoder.cappedFps(60, 0), 60);
    });
  });

  // ── Hareketli / çok sayfalı kaynaklar ──────────────────────────────────────
  // Tek kareye inen çıktı aslın yerini TUTMAZ; bu biçimlerde "özgünü çöpe at"
  // uygulanmaz (bkz. resize_actions.dart).
  group('mayLoseFrames', () {
    test('hareketli/çok kareli olabilen biçimler işaretlenir', () {
      for (final path in [
        '/a/meme.gif',
        '/a/x.APNG',
        '/a/foto.webp',
        '/a/tarama.tif',
        '/a/tarama.tiff',
        '/a/kapak.psd',
        '/a/cizim.xcf',
      ]) {
        expect(ImageResizer.mayLoseFrames(path), isTrue, reason: path);
      }
    });

    test('tek kareli biçimler işaretlenmez', () {
      for (final path in ['/a/f.jpg', '/a/f.jpeg', '/a/f.png', '/a/f.bmp']) {
        expect(ImageResizer.mayLoseFrames(path), isFalse, reason: path);
      }
    });
  });

  group('benzer tarama kapsam kimliği', () {
    test('kapsamlar ayrı kimlik alır', () {
      expect(SimilarFinder.jobIdFor('Görüntüler'),
          isNot(SimilarFinder.jobIdFor('Videolar')));
      expect(SimilarFinder.jobIdFor('tum-medya'),
          isNot(SimilarFinder.jobIdFor('Görüntüler')));
    });

    test('aynı kapsam aynı kimliği alır (geri dönünce sonuç bulunur)', () {
      expect(SimilarFinder.jobIdFor('Videolar'),
          SimilarFinder.jobIdFor('Videolar'));
    });
  });
}

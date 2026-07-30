import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/ffmpeg_video.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var:** FFmpeg komut satırıyla sürülüyor; tek bir yazım hatası
/// ("-vf" yerine "-vs", filtreleri virgülle birleştirmeyi unutmak, tek sayılı
/// ölçü) cihazda "video hiç dönüşmüyor" olarak görünür ve bu ortamda telefon
/// olmadığı için başka türlü yakalanamaz. Döndürme okuması da burada kilitli:
/// telefon videoları yatay kodlanıp "90° döndür" verisiyle saklanıyor, bu açı
/// kaçırılırsa dikey video ezilir.
void main() {
  group('argümanlar', () {
    final args = FfmpegVideo.buildArgs(
      source: '/depo/VID_0001.mp4',
      output: '/depo/VID_0001_720p.mp4',
      width: 1280,
      height: 720,
      fps: 30,
      crf: 24,
      removeAudio: false,
      encoder: 'h264_mediacodec',
    );

    test('kaynak ve çıktı doğru yerlerde', () {
      expect(args.first, '-y');
      expect(args[args.indexOf('-i') + 1], '/depo/VID_0001.mp4');
      expect(args.last, '/depo/VID_0001_720p.mp4');
    });

    test('kare atma ÖLÇEKLEMEDEN ÖNCE zincirlenir (hız)', () {
      // Tersi (eski hâli) atılacak kareleri de ölçekliyordu: 60→30 fps'te
      // ölçekleyicinin işinin yarısı çöpe gidiyordu ("çok yavaş", 2026-07-30).
      final vf = args[args.indexOf('-vf') + 1];
      expect(vf, startsWith('fps=30,'));
      expect(vf.indexOf('fps='), lessThan(vf.indexOf('scale=')));
    });

    test('kare sayısı verilmezse fps filtresi HİÇ yazılmaz', () {
      final noFps = FfmpegVideo.buildArgs(
        source: 'a.mp4',
        output: 'b.mp4',
        width: 640,
        height: 480,
        crf: 24,
        removeAudio: false,
        encoder: 'h264_mediacodec',
      );
      final vf = noFps[noFps.indexOf('-vf') + 1];
      expect(vf.contains('fps='), isFalse);
      expect(vf, startsWith('scale='));
    });

    test('yazılım kodlayıcı tüm çekirdekleri kullanır, donanım gerektirmez', () {
      final sw = FfmpegVideo.buildArgs(
        source: 'a.mp4',
        output: 'b.mp4',
        width: 1280,
        height: 720,
        crf: 24,
        removeAudio: false,
        encoder: 'mpeg4',
      );
      expect(sw, containsAllInOrder(['-threads', '0']));
      expect(args.contains('-threads'), isFalse);
    });

    test('donanım kodlayıcı bit hızıyla sürülür (CRF anlamıyor)', () {
      expect(args.contains('-crf'), isFalse);
      final bitrate = args[args.indexOf('-b:v') + 1];
      expect(bitrate, endsWith('k'));
      expect(int.parse(bitrate.replaceAll('k', '')), greaterThan(300));
    });

    test('GPL’li libx264 argümanları HİÇ üretilmiyor', () {
      // Lisans kararı (kullanıcı isteği: "Google Play'de sorun yaşamayalım"):
      // x264 dağıtılmıyor, çünkü GPL v3 uygulamanın tamamını kapsardı. Bu test
      // o kararın kodda sessizce geri gelmesini engelliyor.
      expect(args.contains('-preset'), isFalse);
      expect(args.join(' ').contains('libx264'), isFalse);
    });

    test('mpeg4 yedeği CRF yerine -q:v alır', () {
      final sw = FfmpegVideo.buildArgs(
        source: 'a.mp4',
        output: 'b.mp4',
        width: 1280,
        height: 720,
        crf: 24,
        removeAudio: false,
        encoder: 'mpeg4',
      );
      expect(sw.contains('-crf'), isFalse);
      expect(sw.contains('-b:v'), isFalse);
      final q = int.parse(sw[sw.indexOf('-q:v') + 1]);
      expect(q, inInclusiveRange(2, 31));
    });

    test('yüksek kalite seçimi mpeg4’te daha küçük -q:v demek', () {
      int qFor(int crf) {
        final a = FfmpegVideo.buildArgs(
          source: 'a.mp4',
          output: 'b.mp4',
          width: 640,
          height: 480,
          crf: crf,
          removeAudio: false,
          encoder: 'mpeg4',
        );
        return int.parse(a[a.indexOf('-q:v') + 1]);
      }

      expect(qFor(20), lessThan(qFor(32)));
    });

    test('ses korunurken AAC ile YENİDEN kodlanır (copy değil)', () {
      // `-c:a copy` kaynak sesi MP4'e girmeyen bir biçimdeyse (WebM/Opus)
      // sessizce çöker; bu yüzden bilinçli olarak yeniden kodlanıyor.
      expect(args, containsAllInOrder(['-c:a', 'aac']));
      expect(args.contains('-an'), isFalse);
    });

    test('“sesi çıkar” seçilince -an yazılır ve ses kodlayıcı yazılmaz', () {
      final muted = FfmpegVideo.buildArgs(
        source: 'a.mp4',
        output: 'b.mp4',
        width: 640,
        height: 480,
        crf: 24,
        removeAudio: true,
        encoder: 'h264_mediacodec',
      );
      expect(muted.contains('-an'), isTrue);
      expect(muted.contains('-c:a'), isFalse);
    });

    test('uyumluluk ve üstveri bayrakları var', () {
      // yuv420p: eski oynatıcılar 4:2:0 dışını açmaz.
      expect(args, containsAllInOrder(['-pix_fmt', 'yuv420p']));
      // map_metadata: çekim tarihi korunsun, galeride "bugün" görünmesin.
      expect(args, containsAllInOrder(['-map_metadata', '0']));
      // faststart: video baştan oynamaya başlasın.
      expect(args, containsAllInOrder(['-movflags', '+faststart']));
    });

    test('yollar argüman olarak AYRI geçer (boşluklu ad bozulmaz)', () {
      final spaced = FfmpegVideo.buildArgs(
        source: '/depo/Tatil 2026/VID 01.mp4',
        output: '/depo/Tatil 2026/VID 01_720p.mp4',
        width: 1280,
        height: 720,
        crf: 24,
        removeAudio: false,
        encoder: 'h264_mediacodec',
      );
      expect(spaced, contains('/depo/Tatil 2026/VID 01.mp4'));
      expect(spaced.last, '/depo/Tatil 2026/VID 01_720p.mp4');
    });
  });

  group('ölçek süzgeci — dikey video yatay çıkmasın (hata 2026-07-30)', () {
    // KÖK NEDEN: hedef ölçü mutlak sayı olarak yazılıyordu (`scale=1280:720`)
    // ve o sayılar döndürme verisi okunamadığında YATAY çıkıyordu; ffmpeg ise
    // kareyi kendi döndürme verisiyle çevirip (autorotate) dikey kareyi yatay
    // çerçeveye basıyordu → video enine yayılıyordu. Çözüm: kutuya sığdırma,
    // yani çıktı oranını KAYNAĞIN karesinden aldırmak.
    String fitFilter(int w, int h) => FfmpegVideo.scaleFilter(
        width: w, height: h, mode: VideoScaleMode.fit);

    test('kademe/yüzde: oran kaynaktan alınır, mutlak ölçü YAZILMAZ', () {
      final filter = fitFilter(1280, 720);
      expect(filter, contains('force_original_aspect_ratio=decrease'));
      // Kutu = uzun kenar; kısa kenar mutlak olarak DAYATILMAZ.
      expect(filter, contains('w=1280:h=1280'));
      expect(filter.contains(':h=720'), isFalse);
    });

    test('dikey hedef de aynı kutuyu üretir (yön bilgisine bağlı değil)', () {
      // Aynı videonun dikey ve yatay okunmuş hâli AYNI süzgeci vermeli:
      // sonucu artık kaynağın kendi karesi belirliyor.
      expect(fitFilter(720, 1280), fitFilter(1280, 720));
    });

    test('çift ölçü garanti (H.264 tek sayı kabul etmez)', () {
      expect(fitFilter(1280, 720), contains('force_divisible_by=2'));
    });

    test('serbest en×boy BİREBİR uygulanır (kullanıcı iki sayıyı da yazdı)', () {
      final filter = FfmpegVideo.scaleFilter(
          width: 1234, height: 568, mode: VideoScaleMode.exactBoth);
      expect(filter, 'scale=w=1234:h=568:flags=bicubic');
      expect(filter.contains('force_original_aspect_ratio'), isFalse);
    });

    test('tek kenar yazıldıysa diğeri orandan (-2) hesaplanır', () {
      expect(
          FfmpegVideo.scaleFilter(
              width: 1000, height: 562, mode: VideoScaleMode.exactWidth),
          'scale=w=1000:h=-2:flags=bicubic');
      expect(
          FfmpegVideo.scaleFilter(
              width: 1000, height: 562, mode: VideoScaleMode.exactHeight),
          'scale=w=-2:h=562:flags=bicubic');
    });

    test('süzgeç ifade (virgül) İÇERMEZ — zincir ayırıcısıyla çakışmasın', () {
      // `if(gt(iw\,ih)\,…)` yolu bilinçli olarak seçilmedi: virgül filtre
      // zincirini ayırıyor, tek bir kaçırma hatası "video hiç dönüşmüyor"
      // demek ve bu ortamda cihazda doğrulanamaz.
      expect(fitFilter(1280, 720).contains(','), isFalse);
    });

    group('ölçek kipi seçimi', () {
      test('kademe ve yüzde → sığdırma', () {
        expect(
            FfmpegVideo.scaleModeFor(
                const MediaResizeOptions(resolution: ResolutionChoice.p720)),
            VideoScaleMode.fit);
        expect(
            FfmpegVideo.scaleModeFor(const MediaResizeOptions(
                resolution: ResolutionChoice.percent, percent: 50)),
            VideoScaleMode.fit);
        expect(
            FfmpegVideo.scaleModeFor(
                const MediaResizeOptions(resolution: ResolutionChoice.keep)),
            VideoScaleMode.fit);
      });

      test('serbest ölçüde yazılan alan(lar)a göre kip', () {
        expect(
            FfmpegVideo.scaleModeFor(const MediaResizeOptions(
                resolution: ResolutionChoice.custom,
                customWidth: 1234,
                customHeight: 568)),
            VideoScaleMode.exactBoth);
        expect(
            FfmpegVideo.scaleModeFor(const MediaResizeOptions(
                resolution: ResolutionChoice.custom, customWidth: 1234)),
            VideoScaleMode.exactWidth);
        expect(
            FfmpegVideo.scaleModeFor(const MediaResizeOptions(
                resolution: ResolutionChoice.custom, customHeight: 568)),
            VideoScaleMode.exactHeight);
        // Hiçbir alan yazılmadıysa sığdırmaya düşer (ölçü değişmez).
        expect(
            FfmpegVideo.scaleModeFor(
                const MediaResizeOptions(resolution: ResolutionChoice.custom)),
            VideoScaleMode.fit);
      });
    });
  });

  group('kalan süre tahmini', () {
    test('ilk saniyelerde tahmin YAZILMAZ (yanlış süre yazmaktansa hiç)', () {
      expect(FfmpegVideo.remainingText(const Duration(seconds: 1), 0.5), '');
      expect(FfmpegVideo.remainingText(const Duration(seconds: 30), 0.0), '');
      expect(FfmpegVideo.remainingText(const Duration(seconds: 30), 1.0), '');
    });

    test('ölçülen hızdan saniye/dakika/saat', () {
      // 10 sn'de %50 → ~10 sn kaldı.
      expect(FfmpegVideo.remainingText(const Duration(seconds: 10), 0.5),
          '~10 sn kaldı');
      // 60 sn'de %25 → 180 sn kaldı → ~3 dk.
      expect(FfmpegVideo.remainingText(const Duration(seconds: 60), 0.25),
          '~3 dk kaldı');
      // 60 dk'da %10 → 9 saat kaldı.
      expect(FfmpegVideo.remainingText(const Duration(minutes: 60), 0.1),
          '~9 sa kaldı');
    });
  });

  group('kalite eşlemesi', () {
    test('sert sıkıştırma daha büyük CRF (daha düşük kalite) demek', () {
      expect(FfmpegVideo.crfFor(VideoQualityChoice.high),
          lessThan(FfmpegVideo.crfFor(VideoQualityChoice.medium)));
      expect(FfmpegVideo.crfFor(VideoQualityChoice.medium),
          lessThan(FfmpegVideo.crfFor(VideoQualityChoice.low)));
      expect(FfmpegVideo.crfFor(VideoQualityChoice.low),
          lessThan(FfmpegVideo.crfFor(VideoQualityChoice.veryLow)));
    });
  });

  group('döndürme (dikey telefon videoları)', () {
    test('side_data_list içindeki açı okunur', () {
      final rotation = FfmpegVideo.rotationOf({
        'side_data_list': [
          {'side_data_type': 'Display Matrix', 'rotation': -90}
        ],
      });
      expect(rotation, 270); // -90 ≡ 270
      expect(FfmpegVideo.rotationSwapsAxes(rotation), isTrue);
    });

    test('eski dosyalarda tags.rotate okunur', () {
      final rotation = FfmpegVideo.rotationOf({
        'tags': {'rotate': '90'},
      });
      expect(rotation, 90);
      expect(FfmpegVideo.rotationSwapsAxes(rotation), isTrue);
    });

    test('180° eksenleri TAKAS ETMEZ (baş aşağı ama yatay yine yatay)', () {
      expect(FfmpegVideo.rotationSwapsAxes(180), isFalse);
    });

    test('döndürme yoksa 0 ve takas yok', () {
      expect(FfmpegVideo.rotationOf(null), 0);
      expect(FfmpegVideo.rotationOf(const {}), 0);
      expect(FfmpegVideo.rotationSwapsAxes(0), isFalse);
    });

    test('bozuk/beklenmedik veri çökertmez', () {
      expect(FfmpegVideo.rotationOf({'side_data_list': 'saçma'}), 0);
      expect(FfmpegVideo.rotationOf({'tags': {'rotate': 'abc'}}), 0);
      expect(
          FfmpegVideo.rotationOf({
            'side_data_list': [
              {'side_data_type': 'başka bir şey'}
            ]
          }),
          0);
    });
  });

  group('dikey video ölçüsü', () {
    test('90° döndürülmüş 1920x1080 kaynak 720p’ye doğru iner', () {
      // Kodlanmış ölçü 1920x1080, gösterim 1080x1920. FfmpegVideo.probe
      // eksenleri takas ettiği için hedef hesabı dikey videoya göre yapılır.
      const rotation = 90;
      final swap = FfmpegVideo.rotationSwapsAxes(rotation);
      final displayWidth = swap ? 1080 : 1920;
      final displayHeight = swap ? 1920 : 1080;
      final target = targetSize(
        sourceWidth: displayWidth,
        sourceHeight: displayHeight,
        options: const MediaResizeOptions(resolution: ResolutionChoice.p720),
      );
      // Kısa kenar (genişlik) 720 olmalı — 1280 olursa video yan yatmış demek.
      expect(target.width, 720);
      expect(target.height, 1280);
    });
  });
}

import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/job_queue.dart' show etaText;
import 'package:dosya_okuyucu/services/fm/video_transcode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Video küçültmenin motordan bağımsız kuralları (Faz 10: FFmpeg → Media3).
/// FFmpeg komut satırı testleri motorla birlikte kalktı; ölçek kipi, bit
/// hızı, kalan süre ve dikey video ölçüsü burada kilitli.
void main() {
  group('ölçek kipi seçimi', () {
    test('kademe ve yüzde → sığdırma', () {
      expect(
          VideoTranscoder.scaleModeFor(
              const MediaResizeOptions(resolution: ResolutionChoice.p720)),
          VideoScaleMode.fit);
      expect(
          VideoTranscoder.scaleModeFor(const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 50)),
          VideoScaleMode.fit);
      expect(
          VideoTranscoder.scaleModeFor(
              const MediaResizeOptions(resolution: ResolutionChoice.keep)),
          VideoScaleMode.fit);
    });

    test('serbest ölçüde yazılan alan(lar)a göre kip', () {
      expect(
          VideoTranscoder.scaleModeFor(const MediaResizeOptions(
              resolution: ResolutionChoice.custom,
              customWidth: 1234,
              customHeight: 568)),
          VideoScaleMode.exactBoth);
      expect(
          VideoTranscoder.scaleModeFor(const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customWidth: 1234)),
          VideoScaleMode.exactWidth);
      expect(
          VideoTranscoder.scaleModeFor(const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customHeight: 568)),
          VideoScaleMode.exactHeight);
      // Hiçbir alan yazılmadıysa sığdırmaya düşer (ölçü değişmez).
      expect(
          VideoTranscoder.scaleModeFor(
              const MediaResizeOptions(resolution: ResolutionChoice.custom)),
          VideoScaleMode.fit);
    });
  });

  group('bit hızı', () {
    test('daha yüksek kalite daha yüksek bit hızı', () {
      int b(VideoQualityChoice q) => VideoTranscoder.bitrateFor(1280, 720, q);
      expect(b(VideoQualityChoice.high),
          greaterThan(b(VideoQualityChoice.medium)));
      expect(
          b(VideoQualityChoice.medium), greaterThan(b(VideoQualityChoice.low)));
      expect(b(VideoQualityChoice.low),
          greaterThan(b(VideoQualityChoice.veryLow)));
    });

    test('kare sayısı yarıya inince bit hızı da iner', () {
      expect(
          VideoTranscoder.bitrateFor(1280, 720, VideoQualityChoice.medium, 15),
          lessThan(VideoTranscoder.bitrateFor(
              1280, 720, VideoQualityChoice.medium, 30)));
    });

    test('alt/üst sınır (300 kbps … 20 Mbps), bit/sn döner', () {
      expect(VideoTranscoder.bitrateFor(16, 16, VideoQualityChoice.veryLow),
          300000);
      expect(
          VideoTranscoder.bitrateFor(7680, 4320, VideoQualityChoice.high, 60),
          20000000);
    });
  });

  group('kalan süre tahmini', () {
    test('ilk saniyelerde tahmin YAZILMAZ (yanlış süre yazmaktansa hiç)', () {
      expect(etaText(const Duration(seconds: 1), 0.5), '');
      expect(etaText(const Duration(seconds: 30), 0.0), '');
      expect(etaText(const Duration(seconds: 30), 1.0), '');
    });

    test('ölçülen hızdan saniye/dakika/saat', () {
      // 10 sn'de %50 → ~10 sn kaldı.
      expect(etaText(const Duration(seconds: 10), 0.5), '~10 sn kaldı');
      // 60 sn'de %25 → 180 sn kaldı → ~3 dk.
      expect(etaText(const Duration(seconds: 60), 0.25), '~3 dk kaldı');
      // 60 dk'da %10 → 9 saat kaldı.
      expect(etaText(const Duration(minutes: 60), 0.1), '~9 sa kaldı');
    });
  });

  group('dikey video ölçüsü', () {
    test('90° döndürülmüş 1920x1080 kaynak 720p’ye doğru iner', () {
      // Kodlanmış ölçü 1920x1080, gösterim 1080x1920: yerel probe
      // (MediaTranscode.kt) 90/270°'de eksenleri takas edip GÖSTERİM ölçüsünü
      // veriyor; hedef hesabı ona göre.
      const displayWidth = 1080, displayHeight = 1920;
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

import 'dart:io';

import 'package:dosya_okuyucu/models/media_resize.dart';
import 'package:dosya_okuyucu/services/fm/audio_tags.dart';
import 'package:dosya_okuyucu/services/fm/exif_reader.dart';
import 'package:dosya_okuyucu/services/fm/image_resize.dart';
import 'package:dosya_okuyucu/services/fm/subtitles.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;

/// **Faz 10b — örnek medya seti duman testleri.** Set
/// `tool/make_media_fixtures.py` ile üretilir (`test/fixtures/media/`).
///
/// `orient_{1,3,6,8}.jpg` AYNI sahnedir: görünen (yönü uygulanmış) hâl hep
/// 300×400 DİKEY, sol üstte KIRMIZI kare. Depolanan pikseller yöne göre
/// döndürülmüş — telefon kamerasının dikey fotoğrafı böyle yazılır.
const _dir = 'test/fixtures/media';

String _f(String name) => p.join(_dir, name);

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('media_smoke'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Kaynağı geçici klasöre kopyalar (çıktı kaynağın yanına yazılır).
  String copy(String name) =>
      File(_f(name)).copySync(p.join(tmp.path, name)).path;

  group('EXIF yönü', () {
    test('okuyucu 1/3/6/8 kodlarını okur', () async {
      for (final o in [1, 3, 6, 8]) {
        final exif = await ExifReader.read(_f('orient_$o.jpg'));
        expect(exif.orientation, o, reason: 'orient_$o');
      }
    });

    // B11 (FAZ_PLANI §3.14 G4l): `image` paketi yönü uygulamadan ölçüyorsa
    // dikey fotoğrafta "genişlik 150" HAM (yatay) kenara gider ve çıktı yan
    // yatar. Düzeltme: çözünce `bakeOrientation` — ölçüler görünen yönde.
    for (final o in [1, 3, 6, 8]) {
      test('B11: orient_$o.jpg → genişlik 150 GÖRÜNEN kenara uygulanır',
          () async {
        final result = await ImageResizer.run(
          copy('orient_$o.jpg'),
          const MediaResizeOptions(
              resolution: ResolutionChoice.custom, customWidth: 150),
        );
        expect((result.width, result.height), (150, 200));
        final out = img.decodeJpg(File(result.outputPath).readAsBytesSync())!;
        // Pikseller döndürülmüş, yön etiketi düz (yoksa görüntüleyici bir
        // kez daha döndürürdü).
        expect((out.width, out.height), (150, 200));
        expect(out.exif.imageIfd.orientation ?? 1, 1);
        // Sol üst KIRMIZI, sağ alt MAVİ — sahne görünen yönde.
        final tl = out.getPixel(10, 10);
        final br = out.getPixel(140, 190);
        expect(tl.r, greaterThan(150), reason: 'sol üst kırmızı olmalı');
        expect(tl.b, lessThan(100));
        expect(br.b, greaterThan(150), reason: 'sağ alt mavi olmalı');
        expect(br.r, lessThan(100));
      });
    }

    test('probeSize da görünen yönü verir (ayar sayfası ve tahmin)', () async {
      expect(await ImageResizer.probeSize(_f('orient_6.jpg')),
          (width: 300, height: 400));
      expect(await ImageResizer.probeSize(_f('orient_1.jpg')),
          (width: 300, height: 400));
    });
  });

  group('her biçimde boyutlandırma çıktısı açılır', () {
    for (final name in ['transparent.png', 'photo.webp', 'anim.gif']) {
      test(name, () async {
        final result = await ImageResizer.run(
          copy(name),
          const MediaResizeOptions(
              resolution: ResolutionChoice.percent, percent: 50),
        );
        final bytes = File(result.outputPath).readAsBytesSync();
        expect(img.decodeImage(bytes), isNotNull);
        // WebP/GIF yazılamaz → JPEG; PNG kendi biçiminde (saydamlık korunur).
        expect(p.extension(result.outputPath),
            name.endsWith('.png') ? '.png' : '.jpg');
      });
    }
  });

  group('ses etiketleri', () {
    for (final name in ['tagged.mp3', 'tagged.m4a', 'tagged.flac']) {
      test(name, () async {
        final tags = await AudioTagReader.read(_f(name));
        expect(tags.title, 'Örnek Şarkı');
        expect(tags.artist, 'Dosya Okuyucu');
        expect(tags.album, 'Faz 10b');
        expect(tags.cover, isNotNull);
        expect(img.decodeImage(tags.cover!), isNotNull, reason: 'kapak');
      });
    }
  });

  test('altyazı: Türkçe karakterli SRT', () async {
    final cues = await Subtitles.load(_f('clip.srt'));
    expect(cues, hasLength(2));
    expect(cues.first.text, 'Merhaba dünya');
    expect(cues.last.text, contains('ğüşıöç'));
    expect(cues.last.start, const Duration(milliseconds: 1500));
  });

  test('altyazı videonun yanında bulunur', () {
    final tracks = Subtitles.findFor(_f('clip.mp4'));
    expect(tracks.map((t) => p.basename(t.path)), contains('clip.srt'));
  });
}

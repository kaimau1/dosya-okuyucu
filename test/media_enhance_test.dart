import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/opensubtitles.dart';
import 'package:dosya_okuyucu/services/fm/player_engine.dart';
import 'package:dosya_okuyucu/services/image_enhance.dart';
import 'package:dosya_okuyucu/services/image_repair.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:video_player/video_player.dart';

/// 2026-11-02 "VLC gibi oynatıcı + görsel iyileştirme" turunun saf mantığı.
void main() {
  group('PlayerEngine.needsMpv', () {
    const ac3 = VideoAudioTrack(id: '0_0', isSelected: false, codec: 'audio/ac3');
    const aac = VideoAudioTrack(id: '0_0', isSelected: true, codec: 'audio/mp4a');

    test('ses parçası var ama hiçbiri seçilemedi → mpv (sessiz AC3/DTS)', () {
      expect(
          PlayerEngine.needsMpv(
              audioTracks: [ac3], expectVideo: true, hasPicture: true),
          isTrue);
    });
    test('görüntü bekleniyor ama boyut yok → mpv', () {
      expect(
          PlayerEngine.needsMpv(
              audioTracks: [aac], expectVideo: true, hasPicture: false),
          isTrue);
    });
    test('çalınabilen dosya ExoPlayer\'da kalır; sessiz video da', () {
      expect(
          PlayerEngine.needsMpv(
              audioTracks: [aac], expectVideo: true, hasPicture: true),
          isFalse);
      expect(
          PlayerEngine.needsMpv(
              audioTracks: const [], expectVideo: true, hasPicture: true),
          isFalse);
    });
  });

  group('OpenSubtitles', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('osub'));
    tearDown(() => dir.deleteSync(recursive: true));

    test('özet = boy + ilk/son 64 KB sözcük toplamı', () async {
      final f = File('${dir.path}/a.mkv');
      final bytes = Uint8List(200000);
      bytes[0] = 1; // ilk sözcük = 1
      bytes[200000 - 8] = 2; // son 64 KB'ın son sözcüğü = 2
      f.writeAsBytesSync(bytes);
      expect(await OpenSubtitles.movieHash(f.path),
          (200000 + 3).toRadixString(16).padLeft(16, '0'));
    });

    test('arama yanıtı: özet eşleşen önce, sonra indirme sayısı', () {
      const body = '{"data":['
          '{"attributes":{"language":"en","download_count":900,'
          '"files":[{"file_id":1,"file_name":"a.srt"}]}},'
          '{"attributes":{"language":"tr","download_count":5,'
          '"moviehash_match":true,"files":[{"file_id":2,"file_name":"b.srt"}]}},'
          '{"attributes":{"language":"tr","files":[]}}]}';
      final hits = OpenSubtitles.parseSearch(body);
      expect(hits.map((h) => h.fileId), [2, 1]);
      expect(hits.first.hashMatch, isTrue);
    });
  });

  group('ImageRepair', () {
    final jpeg = img.encodeJpg(img.Image(width: 16, height: 16), quality: 90);

    test('başındaki çöp atılır', () {
      final broken = Uint8List.fromList([1, 2, 3, 4, 5, ...jpeg]);
      expect(img.decodeImage(broken), isNull);
      final fixed = ImageRepair.repair(broken)!;
      expect(img.decodeImage(fixed)?.width, 16);
    });

    test('yarım JPEG\'e son işareti eklenir', () {
      final cut = Uint8List.fromList(jpeg.sublist(0, jpeg.length - 40));
      final fixed = ImageRepair.repair(cut)!;
      expect(fixed.sublist(0, 2), [0xFF, 0xD8]);
    });

    test('görsel olmayan veri → null', () {
      expect(ImageRepair.repair(Uint8List.fromList(List.filled(100, 7))),
          isNull);
    });
  });

  group('ImageEnhance', () {
    test('parçalı büyütme ek yeri bırakmadan tüm alanı doldurur', () {
      final src = img.Image(width: 73, height: 41);
      for (final px in src) {
        px
          ..r = px.x * 3
          ..g = px.y * 5
          ..b = 100;
      }
      // Sahte model: en yakın komşu 2×.
      final out = ImageEnhance.tileUpscale(src, 20, 2, (tile) {
        final res = Float32List(40 * 40 * 3);
        for (var y = 0; y < 40; y++) {
          for (var x = 0; x < 40; x++) {
            final k = ((y ~/ 2) * 20 + x ~/ 2) * 3;
            final o = (y * 40 + x) * 3;
            res[o] = tile[k];
            res[o + 1] = tile[k + 1];
            res[o + 2] = tile[k + 2];
          }
        }
        return res;
      });
      expect(out.width, 146);
      expect(out.height, 82);
      for (final (x, y) in [(0, 0), (145, 81), (77, 33), (31, 64)]) {
        final o = out.getPixel(x, y);
        final s = src.getPixel(x ~/ 2, y ~/ 2);
        expect([o.r, o.g, o.b], [s.r, s.g, s.b], reason: '($x,$y)');
      }
    });

    test('otomatik düzey soluk aralığı 0–255\'e yayar', () {
      final src = img.Image(width: 10, height: 10);
      for (final px in src) {
        final v = 100 + px.x * 5; // 100..145
        px
          ..r = v
          ..g = v
          ..b = v;
      }
      final out = ImageEnhance.autoLevels(src);
      expect(out.getPixel(0, 0).r, lessThan(10));
      expect(out.getPixel(9, 0).r, greaterThan(245));
    });
  });
}

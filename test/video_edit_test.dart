import 'package:dosya_okuyucu/models/video_edit.dart';
import 'package:dosya_okuyucu/models/video_trim.dart';
import 'package:dosya_okuyucu/services/fm/video_transcode.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-11-14: video düzenleme — aradan silme, sessiz bölge, eklenen ses
/// planı (kaynak → çıktı zamanı) ve yerel kanala giden argümanlar.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('VideoEdit', () {
    final base = VideoEdit.whole(60000);

    test('aradan iki bölüm silinir; kalanlar ve süre doğru', () {
      final e = base
          .addCut(const TrimRange(10000, 20000))
          .addCut(const TrimRange(30000, 35000));
      expect(e.keptRanges, const [
        TrimRange(0, 10000),
        TrimRange(20000, 30000),
        TrimRange(35000, 60000),
      ]);
      expect(e.outputMs, 45000);
      expect(e.isSimpleTrim, isFalse);
    });

    test('çakışan silmeler birleşir', () {
      final e = base
          .addCut(const TrimRange(10000, 20000))
          .addCut(const TrimRange(15000, 25000));
      expect(e.cuts, const [TrimRange(10000, 25000)]);
    });

    test('videonun tamamı silinemez', () {
      final e = base.addCut(const TrimRange(0, 60000));
      expect(identical(e, base), isTrue);
    });

    test('kaynak → çıktı zamanı; silinen yerden sonraki kalan nokta', () {
      final e = base
          .copyWith(keep: const TrimRange(5000, 60000))
          .addCut(const TrimRange(10000, 20000));
      expect(e.toOutput(5000), 0);
      expect(e.toOutput(9000), 4000);
      expect(e.toOutput(15000), 5000); // silinen bölümün içi
      expect(e.toOutput(25000), 10000);
      expect(e.nextKeptFrom(0), 5000);
      expect(e.nextKeptFrom(12000), 20000);
      expect(e.nextKeptFrom(30000), 30000);
      expect(e.nextKeptFrom(60000), isNull);
    });

    test('sessiz bölge parçaları böler; komşu aynı tür birleşir', () {
      final e = base
          .addCut(const TrimRange(40000, 50000))
          .addMute(const TrimRange(5000, 15000))
          .addMute(const TrimRange(35000, 45000));
      expect(e.pieces, const [
        VideoPiece(0, 5000),
        VideoPiece(5000, 15000, mute: true),
        VideoPiece(15000, 35000),
        VideoPiece(35000, 40000, mute: true),
        VideoPiece(50000, 60000),
      ]);
      expect(e.originalAudibleAt(6000), isFalse);
      expect(e.originalAudibleAt(20000), isTrue);
    });

    test('eklenen ses: çıktı zamanında boşluk + uzunluk, özgün kısılır', () {
      final e = base.addCut(const TrimRange(0, 10000)).addInsert(
          const AudioInsert(
              path: '/m/a.mp3', at: TrimRange(20000, 30000), audioMs: 60000));
      expect(e.audioTrack.single.gapMs, 10000);
      expect(e.audioTrack.single.lengthMs, 10000);
      expect(e.pieces, const [
        VideoPiece(10000, 20000),
        VideoPiece(20000, 30000, mute: true),
        VideoPiece(30000, 60000),
      ]);
      // Karışık kipte özgün ses kalır.
      final mixed = e.toggleReplace(0);
      expect(mixed.pieces, const [VideoPiece(10000, 60000)]);
    });

    test('ses dosyasından uzun bölge sesin süresine kısalır; çakışma kırpılır',
        () {
      final e = base.addInsert(const AudioInsert(
          path: '/m/a.mp3', at: TrimRange(0, 30000), audioMs: 8000));
      expect(e.inserts.single.at, const TrimRange(0, 8000));
      final e2 = e.addInsert(const AudioInsert(
          path: '/m/b.mp3', at: TrimRange(5000, 20000), audioMs: 60000));
      expect(e2.inserts.last.at, const TrimRange(8000, 20000));
      expect(e2.audioTrack.map((a) => a.gapMs), [0, 0]);
    });

    test('düzenleme yoksa değişmemiş; yalnız baş/son kırpma basit yol', () {
      expect(base.isUnchanged, isTrue);
      final t = base.copyWith(keep: const TrimRange(1000, 50000));
      expect(t.isUnchanged, isFalse);
      expect(t.isSimpleTrim, isTrue);
    });

    test('döndür (H8.5): saat yönünde çeyrek, dördüncüde başa; hızlı yol kapanır', () {
      final r = base.rotated();
      expect(r.rotationDegrees, 90);
      expect(r.isUnchanged, isFalse);
      expect(r.isSimpleTrim, isFalse);
      expect(r.rotated().rotated().rotationDegrees, 270);
      final full = r.rotated().rotated().rotated();
      expect(full.rotationDegrees, 0);
      expect(full.isUnchanged, isTrue);
    });
  });

  group('VideoTranscoder.edit (sahte kanal)', () {
    const channel = MethodChannel('dosya_okuyucu/transcode');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    Future<void> nativeSends(String method, Object? args) =>
        messenger.handlePlatformMessage(channel.name,
            channel.codec.encodeMethodCall(MethodCall(method, args)), (_) {});

    setUp(() {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'edit':
          case 'trim':
            Future(() =>
                nativeSends('done', {'target': call.arguments['target']}));
            return true;
          case 'probe':
            return {'width': 1080, 'height': 1920, 'durationMs': 40000};
        }
        return null;
      });
    });
    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('parçalar ve ses yerleşimi yerel tarafa gider', () async {
      final e = VideoEdit.whole(60000)
          .addCut(const TrimRange(10000, 20000))
          .addInsert(const AudioInsert(
              path: '/m/a.mp3', at: TrimRange(30000, 40000), audioMs: 60000));
      final out = await VideoTranscoder.edit('/yok/klasor/film.mp4', e);
      expect(out, '/yok/klasor/film_kesit.mp4');
      final call = calls.firstWhere((c) => c.method == 'edit');
      final pieces = call.arguments['pieces'] as List;
      expect(pieces.length, 4);
      expect(pieces[2], {'startMs': 30000, 'endMs': 40000, 'mute': true});
      final audio = call.arguments['audio'] as List;
      expect(audio.single, {'path': '/m/a.mp3', 'gapMs': 20000, 'lengthMs': 10000});
      expect(call.arguments['removeAudio'], isFalse);
    });

    test('döndürülen video düzenleme yoluna dönüşle gider', () async {
      final e = VideoEdit.whole(40000) // sahte probe 40 sn döner
          .rotated();
      await VideoTranscoder.edit('/yok/a.mp4', e);
      final call = calls.firstWhere((c) => c.method == 'edit');
      expect(call.arguments['rotation'], 90);
      expect(call.arguments['pieces'],
          [{'startMs': 0, 'endMs': 40000, 'mute': false}]);
      expect(calls.any((c) => c.method == 'trim'), isFalse);
    });

    test('kareyi fotoğraf kaydet: yol, an ve dönüş yerel tarafa gider', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        return call.method == 'frame';
      });
      final out = await VideoTranscoder.saveFrame('/yok/klasor/film.mp4', 83000,
          rotationDegrees: 180);
      expect(out, '/yok/klasor/film_kare_01-23.jpg');
      final call = calls.single;
      expect(call.method, 'frame');
      expect(call.arguments['ms'], 83000);
      expect(call.arguments['rotation'], 180);
      expect(call.arguments['target'], out);
    });

    test('kare okunamazsa null', () async {
      messenger.setMockMethodCallHandler(channel, (_) async => false);
      expect(await VideoTranscoder.saveFrame('/yok/a.mp4', 0), isNull);
    });

    test('yalnız baş/son kırpma hızlı kesim yolunu kullanır', () async {
      final e = VideoEdit.whole(60000)
          .copyWith(keep: const TrimRange(5000, 50000), muteAll: true);
      await VideoTranscoder.edit('/yok/a.mp4', e);
      expect(calls.any((c) => c.method == 'trim'), isTrue);
      expect(calls.any((c) => c.method == 'edit'), isFalse);
    });
  });
}

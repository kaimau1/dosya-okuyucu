import 'package:dosya_okuyucu/models/video_trim.dart';
import 'package:dosya_okuyucu/services/fm/video_transcode.dart';
import 'package:dosya_okuyucu/widgets/fm/video_trim_timeline.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Ferrari H8 (2026-11-14): video kesme — aralık kuralları, yerel kanal akışı
/// (sahte kanal) ve zaman çizelgesinin tutamaçları.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TrimRange', () {
    test('başlangıç bitişe en çok 1 sn yaklaşır, 0\'ın altına inmez', () {
      const r = TrimRange(0, 10000);
      expect(r.withStart(4000, 10000), const TrimRange(4000, 10000));
      expect(r.withStart(9800, 10000), const TrimRange(9000, 10000));
      expect(r.withStart(-50, 10000), const TrimRange(0, 10000));
    });

    test('bitiş başlangıçtan en az 1 sn sonra, süreyi aşmaz', () {
      const r = TrimRange(3000, 10000);
      expect(r.withEnd(7000, 10000), const TrimRange(3000, 7000));
      expect(r.withEnd(3200, 10000), const TrimRange(3000, 4000));
      expect(r.withEnd(99999, 10000), const TrimRange(3000, 10000));
    });

    test('1 sn\'den kısa videoda asgari uzunluk videonun kendisi', () {
      const r = TrimRange(0, 600);
      expect(r.withStart(300, 600), const TrimRange(0, 600));
      expect(r.withEnd(100, 600), const TrimRange(0, 600));
    });

    test('tamamı / uzunluk / saniye', () {
      expect(const TrimRange(0, 5000).isWhole(5000), isTrue);
      expect(const TrimRange(1, 5000).isWhole(5000), isFalse);
      expect(trimSeconds(const TrimRange(12000, 64900)), 52);
    });

    test('saat biçimi', () {
      expect(formatClock(0), '00:00');
      expect(formatClock(65000), '01:05');
      expect(formatClock(3725000), '1:02:05');
      expect(formatClock(-5), '00:00');
    });
  });

  group('VideoTranscoder.trim (sahte kanal)', () {
    const channel = MethodChannel('dosya_okuyucu/transcode');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;

    Future<void> nativeSends(String method, Object? args) =>
        messenger.handlePlatformMessage(channel.name,
            channel.codec.encodeMethodCall(MethodCall(method, args)), (_) {});

    void fake({bool start = true, int outMs = 53000, bool fail = false}) {
      calls = [];
      messenger.setMockMethodCallHandler(channel, (call) async {
        calls.add(call);
        switch (call.method) {
          case 'trim':
            if (start) {
              Future(() => fail
                  ? nativeSends('failed', {'code': 'X', 'message': 'kodlayıcı'})
                  : nativeSends('done', {'target': call.arguments['target']}));
            }
            return start;
          case 'probe':
            return {'width': 1080, 'height': 1920, 'durationMs': outMs};
        }
        return null;
      });
    }

    tearDown(() => messenger.setMockMethodCallHandler(channel, null));

    test('aralığı yerel tarafa verir, özgünün yanına _kesit.mp4 üretir',
        () async {
      fake();
      final out = await VideoTranscoder.trim(
          '/yok/klasor/film.mov', const TrimRange(12000, 65000),
          removeAudio: true);
      expect(out, '/yok/klasor/film_kesit.mp4');
      final trim = calls.firstWhere((c) => c.method == 'trim');
      expect(trim.arguments['startMs'], 12000);
      expect(trim.arguments['endMs'], 65000);
      expect(trim.arguments['removeAudio'], isTrue);
      expect(trim.arguments['path'], '/yok/klasor/film.mov');
    });

    test('yerel taraf başlatamazsa hata', () async {
      fake(start: false);
      await expectLater(
          VideoTranscoder.trim('/yok/a.mp4', const TrimRange(0, 5000)),
          throwsA(isA<VideoTranscodeException>()));
    });

    test('kodlayıcı hatası iletilir', () async {
      fake(fail: true);
      await expectLater(
          VideoTranscoder.trim('/yok/a.mp4', const TrimRange(0, 5000)),
          throwsA(isA<VideoTranscodeException>()));
    });

    test('çıktı istenenden çok kısaysa (yarım) kabul edilmez', () async {
      fake(outMs: 2000);
      await expectLater(
          VideoTranscoder.trim('/yok/a.mp4', const TrimRange(0, 10000)),
          throwsA(isA<VideoTranscodeException>()));
    });

    test('kare şeridi: yerel taraf yoksa boş liste', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        throw PlatformException(code: 'yok');
      });
      expect(await VideoTranscoder.frames('/yok/a.mp4', dir: '/yok/kareler'),
          isEmpty);
    });
  });

  group('VideoTrimTimeline', () {
    Future<TrimRange> drag(WidgetTester tester, TrimRange start, Key handle,
        double dx) async {
      var range = start;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 328,
              child: StatefulBuilder(
                builder: (context, setState) => VideoTrimTimeline(
                  durationMs: 30000,
                  range: range,
                  onChanged: (r) => setState(() => range = r),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.drag(find.byKey(handle), Offset(dx, 0));
      await tester.pump();
      return range;
    }

    testWidgets('başlangıç tutamacı sağa çekilince aralık başı ilerler',
        (tester) async {
      final r = await drag(
          tester, const TrimRange(0, 30000), const ValueKey('trim-start'), 150);
      expect(r.startMs, greaterThan(5000));
      expect(r.endMs, 30000);
    });

    testWidgets('bitiş tutamacı sola çekilince aralık sonu geri gelir',
        (tester) async {
      final r = await drag(
          tester, const TrimRange(0, 30000), const ValueKey('trim-end'), -150);
      expect(r.endMs, lessThan(25000));
      expect(r.startMs, 0);
    });

    // Kullanıcı isteği 2026-11-14: şeritte kaydırınca kare kare görmek.
    testWidgets('tutamaçtan uzakta sürükleme TARAR: aralık değişmez, önizleme izler',
        (tester) async {
      var range = const TrimRange(0, 30000);
      final seeks = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 328,
              child: StatefulBuilder(
                builder: (context, setState) => VideoTrimTimeline(
                  durationMs: 30000,
                  range: range,
                  onChanged: (r) => setState(() => range = r),
                  onSeek: seeks.add,
                ),
              ),
            ),
          ),
        ),
      ));
      final box = tester.getRect(find.byType(VideoTrimTimeline));
      await tester.dragFrom(box.center, const Offset(80, 0));
      await tester.pump();
      expect(range, const TrimRange(0, 30000));
      expect(seeks.length, greaterThan(1));
      expect(seeks.last, greaterThan(seeks.first));
      // Tutamaçtan başlayan sürükleme yine aralığı değiştirir.
      await tester.drag(find.byKey(const ValueKey('trim-start')),
          const Offset(100, 0));
      await tester.pump();
      expect(range.startMs, greaterThan(0));
    });

    testWidgets('tutamaçlar birbirini geçemez (en az 1 sn)', (tester) async {
      final r = await drag(tester, const TrimRange(10000, 12000),
          const ValueKey('trim-start'), 300);
      expect(r.lengthMs, greaterThanOrEqualTo(TrimRange.minLengthMs));
    });
  });
}

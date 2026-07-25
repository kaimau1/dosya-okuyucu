import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/screens/fm/media_player_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

/// **Niye bu test var:** oynatıcıda ekrana dokununca görüntü kayıyordu
/// (2026-07-25 hata raporu). Sebep: üst bar `Scaffold.appBar` slotuna
/// veriliyordu → kontroller açılıp kapandıkça body'nin yüksekliği değişiyor,
/// ortalanmış video her dokunuşta küçülüp yer değiştiriyordu. Bu test
/// kontrollerin açık/kapalı halinde video dikdörtgeninin **birebir aynı**
/// kaldığını doğrular; bar tekrar Scaffold slotuna taşınırsa kırmızı yanar.
void main() {
  late Directory dir;
  late File video;

  setUpAll(() {
    // TUZAK (HAFIZA 2026-07-25 §F): geçici dosya `testWidgets` gövdesinde
    // oluşturulursa sahte saat yüzünden test asılı kalır → setUp'ta yapılır.
    dir = Directory.systemTemp.createTempSync('media_player_layout');
    video = File('${dir.path}/ornek.mp4')..writeAsBytesSync(<int>[0, 1, 2, 3]);
  });

  tearDownAll(() => dir.deleteSync(recursive: true));

  setUp(() => VideoPlayerPlatform.instance = _FakeVideoPlayerPlatform());

  testWidgets('kontroller açılıp kapanınca görüntü yerinden oynamaz',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(top: 90, bottom: 48);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: MediaPlayerScreen(path: video.path)),
    );
    // initialize() + ilk kare.
    await tester.pump();
    await tester.pump();

    expect(find.byType(VideoPlayer), findsOneWidget,
        reason: 'sahte platform ile video yüzeyi çizilmeli');

    // Kontroller açık (başlangıç durumu): üst bar ve alt kontroller görünür.
    expect(find.byType(AppBar), findsOneWidget);
    final withControls = tester.getRect(find.byType(VideoPlayer));

    // 3 sn sonra kontroller kendiliğinden gizlenir.
    await tester.pump(const Duration(seconds: 4));
    expect(find.byType(AppBar), findsNothing);
    final withoutControls = tester.getRect(find.byType(VideoPlayer));

    expect(withoutControls, withControls,
        reason: 'kontroller videonun ÜSTÜNDE yüzmeli, yerini daraltmamalı');

    // Dokunup geri açınca da aynı yerde durmalı.
    await tester.tap(find.byType(VideoPlayer), warnIfMissed: false);
    await tester.pump();
    expect(find.byType(AppBar), findsOneWidget);
    expect(tester.getRect(find.byType(VideoPlayer)), withControls);

    // Ekranı kaldır: controller'ın periyodik konum zamanlayıcısı iptal olsun.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

/// Gerçek ExoPlayer yerine testte kullanılan sahte oynatma motoru:
/// `initialized` olayını hemen gönderir, görüntü olarak boş bir kutu çizer.
class _FakeVideoPlayerPlatform extends VideoPlayerPlatform {
  final Map<int, StreamController<VideoEvent>> _events =
      <int, StreamController<VideoEvent>>{};
  int _next = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int?> create(DataSource dataSource) async => _next++;

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => _next++;

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) {
    final controller = _events.putIfAbsent(
        playerId, () => StreamController<VideoEvent>.broadcast());
    scheduleMicrotask(() {
      if (controller.isClosed) return;
      controller.add(VideoEvent(
        eventType: VideoEventType.initialized,
        duration: const Duration(seconds: 30),
        size: const Size(1280, 720),
      ));
    });
    return controller.stream;
  }

  @override
  Future<void> dispose(int playerId) async {
    await _events.remove(playerId)?.close();
  }

  @override
  Future<void> setLooping(int playerId, bool looping) async {}

  @override
  Future<void> play(int playerId) async {}

  @override
  Future<void> pause(int playerId) async {}

  @override
  Future<void> setVolume(int playerId, double volume) async {}

  @override
  Future<void> seekTo(int playerId, Duration position) async {}

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> setMixWithOthers(bool mixWithOthers) async {}

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();

  @override
  Widget buildViewWithOptions(VideoViewOptions options) =>
      const SizedBox.expand();
}

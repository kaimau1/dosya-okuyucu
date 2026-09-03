import 'dart:async';
import 'dart:io';

import 'package:dosya_okuyucu/screens/fm/media_player_screen.dart';
import 'package:dosya_okuyucu/services/fm/video_playback.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'support/temp_dir.dart';

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

  tearDownAll(() => removeTempDir(dir));

  late _FakeVideoPlayerPlatform platform;

  setUp(() {
    // Oynatıcı artık ekranda değil SERVİSTE (`VideoPlayback`) ve servis bir
    // tekil nesne: bir önceki testten kalan denetleyici bu testin sahte
    // platformuna ait olmadığı için "açılışta oynamıyor" gibi görünürdü.
    VideoPlayback.notificationsEnabled = false; // testte bildirim/oturum yok
    platform = _FakeVideoPlayerPlatform();
    VideoPlayerPlatform.instance = platform;
  });

  tearDown(() {
    // Sıfırlama TESTİN SONUNDA: denetleyiciyi kapatan çağrı hâlâ bu testin
    // sahte platformuna gitmeli.
    VideoPlayback.instance.debugReset();
  });

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
    // **Oynatıcı ekrandan uzun yaşıyor** (ekran altı mini çubuk onu
    // sürdürüyor): test bitmeden AÇIKÇA kapatılmalı, yoksa denetleyicinin
    // konum zamanlayıcısı asılı kalır ve flutter_test haklı olarak yakınır.
    VideoPlayback.instance.debugReset();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('uygulama arkaya alınınca video DURUR, dönünce devam eder',
      (tester) async {
    // PİL: `video_player` Android'de arka planda oynatmaya devam eder —
    // ekran kapalıyken bile tam güçte video kod çözme. Telefon cepteyken
    // süren bu iş uygulamanın en pahalı pil kaçağıydı.
    await tester.pumpWidget(
      MaterialApp(home: MediaPlayerScreen(path: video.path)),
    );
    await tester.pump();
    await tester.pump();
    expect(platform.playing, isTrue, reason: 'açılışta oynamaya başlar');

    tester.binding
        .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(platform.playing, isTrue,
        reason: 'inactive geçici (bildirim gölgesi) — duraklatmamalı');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(platform.playing, isFalse, reason: 'arka planda kod çözme sürmemeli');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.playing, isTrue, reason: 'dönünce kaldığı yerden sürer');

    // **Oynatıcı ekrandan uzun yaşıyor** (ekran altı mini çubuk onu
    // sürdürüyor): test bitmeden AÇIKÇA kapatılmalı, yoksa denetleyicinin
    // konum zamanlayıcısı asılı kalır ve flutter_test haklı olarak yakınır.
    VideoPlayback.instance.debugReset();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('kullanıcı duraklattıysa arka plandan dönüşte KENDİ BAŞINA '
      'başlamaz', (tester) async {
    await tester.pumpWidget(
      MaterialApp(home: MediaPlayerScreen(path: video.path)),
    );
    await tester.pump();
    await tester.pump();

    // Kullanıcı duraklatır.
    await tester.tap(find.byIcon(Icons.pause_circle), warnIfMissed: false);
    await tester.pump();
    expect(platform.playing, isFalse);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(platform.playing, isFalse,
        reason: 'duraklatılmış videoyu dönüşte başlatmak kullanıcıyı şaşırtır');

    // **Oynatıcı ekrandan uzun yaşıyor** (ekran altı mini çubuk onu
    // sürdürüyor): test bitmeden AÇIKÇA kapatılmalı, yoksa denetleyicinin
    // konum zamanlayıcısı asılı kalır ve flutter_test haklı olarak yakınır.
    VideoPlayback.instance.debugReset();
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

  /// Motor şu an oynatıyor mu? Yaşam döngüsü testleri buna bakar — asıl
  /// soru "ekranda ne yazıyor" değil, **motora dur denildi mi**.
  bool playing = false;

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
  Future<void> play(int playerId) async => playing = true;

  @override
  Future<void> pause(int playerId) async => playing = false;

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

import 'package:dosya_okuyucu/services/fm/audio_playback.dart';
import 'package:dosya_okuyucu/services/fm/media_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Medya oturumu köprüsü** (kullanıcı isteği 2026-09-03: *"MediaSession
/// yapalım … Spotify YouTube Music gibi"*).
///
/// Bildirimdeki sürüklenebilir çubuğu, kilit ekranını ve kulaklık düğmelerini
/// Android'in medya denetleyicisi çiziyor ve o ancak bir `MediaSession`
/// tokenıyla devreye giriyor. Native taraf CI'da derleniyor
/// (`tool/check_kotlin.sh` tür denetimi yapıyor); burada **Dart tarafının
/// sözleşmesi** sınanıyor: hangi alanlar gidiyor, hangi eylem hangi çalara
/// düşüyor, kanal yoksa ne oluyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('dosya_okuyucu/media_session');
  final calls = <MethodCall>[];

  void mockChannel({bool missing = false}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (missing) throw MissingPluginException('yok');
      return true;
    });
  }

  setUp(() {
    calls.clear();
    MediaSession.debugReset();
    MediaSession.debugForceSupported = true;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    MediaSession.debugReset();
  });

  test('durum native tarafa eksiksiz iletilir', () async {
    mockChannel();
    final ok = await MediaSession.update(
      title: 'Parça',
      subtitle: 'Sanatçı',
      album: 'Albüm',
      position: const Duration(seconds: 112),
      duration: const Duration(seconds: 215),
      playing: true,
      speed: 1.5,
      hasNext: true,
      hasPrevious: false,
      cover: '/tmp/kapak.jpg',
      payload: 'audio:/depo/parca.mp3',
      owner: 'audio',
      labels: const {'play': 'Çal'},
    );
    expect(ok, isTrue);
    expect(calls.single.method, 'update');
    final args = calls.single.arguments as Map;
    expect(args['title'], 'Parça');
    expect(args['subtitle'], 'Sanatçı');
    // **Süre ŞART:** bildirimdeki çubuğun sağ ucu buradan geliyor; verilmezse
    // sistem belirsiz bir çubuk çiziyor.
    expect(args['duration'], 215000);
    expect(args['position'], 112000);
    expect(args['playing'], isTrue);
    expect(args['speed'], 1.5);
    expect(args['hasNext'], isTrue);
    expect(args['hasPrevious'], isFalse);
    expect(args['cover'], '/tmp/kapak.jpg');
    expect(args['payload'], 'audio:/depo/parca.mp3');
    expect(MediaSession.owner, 'audio');
  });

  test('kanal yoksa bir kez denenir, sonra sessizce kapanır', () async {
    mockChannel(missing: true);
    expect(
        await MediaSession.update(
          title: 'a',
          subtitle: 'b',
          position: Duration.zero,
          duration: Duration.zero,
          playing: false,
        ),
        isFalse);
    expect(MediaSession.supported, isFalse,
        reason: 'eksik eklenti bir daha denenmemeli');
    // İkinci çağrı kanala hiç gitmez.
    await MediaSession.update(
      title: 'a',
      subtitle: 'b',
      position: Duration.zero,
      duration: Duration.zero,
      playing: false,
    );
    expect(calls.length, 1);
  });

  test('temizleme yalnız oturumun SAHİBİNDEN gelirse iş görür', () async {
    mockChannel();
    await MediaSession.update(
      title: 'video',
      subtitle: '',
      position: Duration.zero,
      duration: Duration.zero,
      playing: true,
      owner: 'video',
    );
    calls.clear();
    // Duran ses çalar, çalan videonun bildirimini KAPATMAMALI.
    await MediaSession.clear(owner: 'audio');
    expect(calls, isEmpty);
    expect(MediaSession.owner, 'video');
    await MediaSession.clear(owner: 'video');
    expect(calls.single.method, 'clear');
    expect(MediaSession.owner, '');
  });

  group('bildirim eylemleri ses çalara düşer', () {
    setUp(() {
      AudioPlayback.notificationsEnabled = false;
      AudioPlayback.engineEnabled = false;
      AudioPlayback.instance
        ..playlist = ['a.mp3', 'b.mp3', 'c.mp3']
        ..index = 1
        ..position = const Duration(seconds: 30)
        ..playing = false;
    });

    test('play/pause duraklatmayı çevirir', () async {
      await AudioPlayback.instance.handleAction('play');
      expect(AudioPlayback.instance.playing, isTrue);
      await AudioPlayback.instance.handleAction('pause');
      expect(AudioPlayback.instance.playing, isFalse);
    });

    test('next/previous listede gezinir', () async {
      await AudioPlayback.instance.handleAction('next');
      expect(AudioPlayback.instance.index, 2);
      // Parçanın başında değilsek "önceki" başa sarar (müzik uygulaması
      // davranışı); index değişmez.
      AudioPlayback.instance.position = const Duration(seconds: 30);
      await AudioPlayback.instance.handleAction('previous');
      expect(AudioPlayback.instance.index, 2);
      expect(AudioPlayback.instance.position, Duration.zero);
      await AudioPlayback.instance.handleAction('previous');
      expect(AudioPlayback.instance.index, 1);
    });

    /// **Asıl kazanım:** bildirimdeki çubuğu sürüklemek `seek` gönderiyor.
    test('seek hedef milisaniyeye atlar', () async {
      await AudioPlayback.instance.handleAction('seek', 65000);
      expect(AudioPlayback.instance.position, const Duration(seconds: 65));
    });

    test('stop çalmayı bitirir', () async {
      await AudioPlayback.instance.handleAction('stop');
      expect(AudioPlayback.instance.hasTrack, isFalse);
    });
  });
}

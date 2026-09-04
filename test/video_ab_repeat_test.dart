import 'package:dosya_okuyucu/services/fm/video_playback.dart';
import 'package:flutter_test/flutter_test.dart';

/// **A-B tekrar** (2026-09-04): bir dersin/hareketin aynı yerini defalarca
/// izlemek elle geri sarmakla yapılıyordu. Buradaki ölçüt işaretlerin
/// sırası ve ters aralığın düzeltilmesi — döngünün kendisi oynatıcı
/// dinleyicisinde, sahte platform olmadan sınanamaz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late VideoPlayback player;

  setUp(() {
    VideoPlayback.notificationsEnabled = false;
    player = VideoPlayback.instance..debugReset();
  });

  tearDown(() => VideoPlayback.instance.debugReset());

  test('A → B → kapat sırası', () {
    expect(player.loopStage, 0);

    player.markLoopPoint(); // A (konum 0)
    expect(player.loopStage, 1);
    expect(player.loopStart, Duration.zero);
    expect(player.loopEnd, isNull);

    player.markLoopPoint(); // B (yine 0 — oynatıcı yok)
    expect(player.loopStage, 2);
    expect(player.loopEnd, isNotNull);

    player.markLoopPoint(); // kapat
    expect(player.loopStage, 0);
    expect(player.loopStart, isNull);
    expect(player.loopEnd, isNull);
  });

  test('ters aralık düzeltilir (B, A\'dan önceyse yer değişir)', () {
    player.loopStart = const Duration(seconds: 90);
    // İkinci dokunuş: konum 0 (oynatıcı yok) → aralık ters kuruluyor.
    player.markLoopPoint();
    expect(player.loopStart, Duration.zero);
    expect(player.loopEnd, const Duration(seconds: 90));
  });
}

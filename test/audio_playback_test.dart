import 'package:dosya_okuyucu/services/fm/audio_playback.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Arka planda çalma** — kullanıcı isteği 2026-09-02: *"müziklerde arka
/// planda oynat seçeneği olmalı, müzik programları gibi."*
///
/// Kök neden: bütün oynatıcı durumu EKRANIN state'indeydi ve `dispose`ta
/// oynatıcı kapatılıyordu; ekrandan çıkan kullanıcı müziği de kapatmış
/// oluyordu. Durum artık servistte. Burada sıra/tekrar/karışık mantığı
/// sınanıyor — ses donanımı olmadan çalışabilen kısım budur.
void main() {
  // `AudioPlayer` kurucusu platform kanalına dokunuyor; bağlama olmadan
  // singleton'a erişmek bile patlıyor.
  TestWidgetsFlutterBinding.ensureInitialized();

  late AudioPlayback player;

  setUp(() {
    AudioPlayback.notificationsEnabled = false; // testte bildirim kurma
    AudioPlayback.engineEnabled = false; // ses donanımına dokunma
    player = AudioPlayback.instance
      ..playlist = ['a.mp3', 'b.mp3', 'c.mp3']
      ..index = 0
      ..repeat = RepeatMode.off
      ..shuffle = false
      ..position = Duration.zero;
  });

  test('listedeki sıradaki parçaya geçer', () async {
    player.index = 0;
    await player.skipTo(1);
    expect(player.index, 1);
    expect(player.current, 'b.mp3');
  });

  test('liste dışına çıkılmaz', () async {
    player.index = 2;
    await player.skipTo(5);
    expect(player.index, 2, reason: 'geçersiz indis yok sayılır');
    await player.skipTo(-1);
    expect(player.index, 2);
  });

  test('"önceki" parçanın ORTASINDAYSA başa sarar', () async {
    player
      ..index = 1
      ..position = const Duration(seconds: 30);
    await player.previous();
    expect(player.index, 1, reason: 'başa sarmalı, parça değiştirmemeli');
  });

  test('"önceki" parçanın BAŞINDAYSA öncekine geçer', () async {
    player
      ..index = 1
      ..position = const Duration(seconds: 1);
    await player.previous();
    expect(player.index, 0);
  });

  test('tekrar KAPALI iken son parçadan sonra durur', () async {
    player
      ..index = 2
      ..repeat = RepeatMode.off;
    await player.onComplete();
    expect(player.playing, isFalse);
    expect(player.playlist, isEmpty, reason: 'liste bitti, oynatıcı bırakıldı');
  });

  test('tekrar TÜMÜ iken son parçadan başa döner', () async {
    player
      ..index = 2
      ..repeat = RepeatMode.all;
    await player.onComplete();
    expect(player.index, 0);
  });

  test('bildirim eylemleri tanınır', () {
    // Kimlikler `main`de bildirime bağlanıyor; adları değişirse düğmeler
    // sessizce çalışmaz olurdu.
    expect(AudioPlayback.actionToggle, 'audio_toggle');
    expect(AudioPlayback.actionNext, 'audio_next');
    expect(AudioPlayback.actionStop, 'audio_stop');
  });
}

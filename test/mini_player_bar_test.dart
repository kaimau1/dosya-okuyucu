import 'package:dosya_okuyucu/core/app_navigator.dart';
import 'package:dosya_okuyucu/screens/fm/audio_player_screen.dart';
import 'package:dosya_okuyucu/services/fm/audio_playback.dart';
import 'package:dosya_okuyucu/services/fm/media_session.dart';
import 'package:dosya_okuyucu/widgets/mini_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Ekran altı mini oynatma çubuğu** (kullanıcı isteği 2026-09-03:
/// *"çalarken uygulama ekran altında oynatma çubuğu görülsün"*).
///
/// Çubuk `MaterialApp.builder`da, yani gezinti ağacının DIŞINDA duruyor:
/// hangi ekranda olursak olalım görünür. Buradaki testler onun üç kuralını
/// koruyor — çalan varken görünür, tam oynatıcı açıkken gizlenir, içeriği
/// örtmez (üstüne binmez, altına eklenir).
void main() {
  Widget harness() => MaterialApp(
        home: MiniPlayerBar.wrap(
          const Scaffold(body: Center(child: Text('içerik'))),
        ),
      );

  /// **Üretimdeki gerçek yerleşim**: çubuk `MaterialApp.builder`da, yani
  /// `Navigator`ın DIŞINDA (bkz. `main.dart`). Yukarıdaki [harness] onu
  /// `home:` içine koyuyor — orada bir `Navigator` VAR, bu yüzden
  /// `Navigator.of(context)` hatası testlere hiç yansımıyordu (kullanıcı
  /// çökmesi 2026-09-04).
  Widget appLikeHarness() => MaterialApp(
        navigatorKey: navigatorKey,
        builder: (context, child) =>
            MiniPlayerBar.wrap(child ?? const SizedBox.shrink()),
        home: const Scaffold(body: Center(child: Text('içerik'))),
      );

  setUp(() {
    AudioPlayback.notificationsEnabled = false;
    AudioPlayback.engineEnabled = false;
    MediaSession.debugReset();
    MiniPlayerBar.hidden.value = 0;
    AudioPlayback.instance
      ..playlist = const []
      ..index = 0
      ..playing = false
      ..position = Duration.zero
      ..duration = Duration.zero;
  });

  testWidgets('çalan yokken çubuk hiç çizilmez', (tester) async {
    await tester.pumpWidget(harness());
    expect(find.byType(MiniPlayerBar), findsNothing);
    expect(find.text('içerik'), findsOneWidget);
  });

  testWidgets('çalan parça varken ad ve düğmeler görünür', (tester) async {
    AudioPlayback.instance
      ..playlist = ['/depo/Müzik/parca.mp3']
      ..index = 0
      ..playing = true
      ..duration = const Duration(minutes: 3);
    await tester.pumpWidget(harness());
    expect(find.byType(MiniPlayerBar), findsOneWidget);
    expect(find.text('parca'), findsOneWidget);
    expect(find.byIcon(Icons.pause), findsOneWidget);
    // İçerik hâlâ ekranda: çubuk üstüne binmiyor, altına ekleniyor.
    expect(find.text('içerik'), findsOneWidget);
  });

  testWidgets('duraklat/çal düğmesi servisi sürer', (tester) async {
    AudioPlayback.instance
      ..playlist = ['/depo/Müzik/parca.mp3']
      ..playing = true;
    await tester.pumpWidget(harness());
    await tester.tap(find.byIcon(Icons.pause));
    await tester.pump();
    expect(AudioPlayback.instance.playing, isFalse);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
  });

  testWidgets('kapat düğmesi çalmayı bitirir ve çubuk kalkar', (tester) async {
    AudioPlayback.instance
      ..playlist = ['/depo/Müzik/parca.mp3']
      ..playing = true;
    await tester.pumpWidget(harness());
    await tester.tap(find.byIcon(Icons.close));
    await tester.pump();
    expect(AudioPlayback.instance.hasTrack, isFalse);
    expect(find.byType(MiniPlayerBar), findsNothing);
  });

  /// Tam oynatıcı ekrandayken çubuk aynı şeyin ikinci kopyası olurdu.
  testWidgets('tam oynatıcı açıkken çubuk gizlenir', (tester) async {
    AudioPlayback.instance
      ..playlist = ['/depo/Müzik/parca.mp3']
      ..playing = true;
    await tester.pumpWidget(harness());
    expect(find.byType(MiniPlayerBar), findsOneWidget);

    final release = MiniPlayerBar.hide();
    await tester.pump();
    expect(find.byType(MiniPlayerBar), findsNothing);

    release();
    await tester.pump();
    expect(find.byType(MiniPlayerBar), findsOneWidget);
  });

  /// İki oynatıcı ekranı üst üste açılabiliyor (ses çalarken video açmak);
  /// sayaç yerine `bool` olsaydı içteki kapanınca çubuk erken geri gelirdi.
  testWidgets('gizleme SAYAÇLA yönetilir', (tester) async {
    AudioPlayback.instance
      ..playlist = ['/depo/Müzik/parca.mp3']
      ..playing = true;
    await tester.pumpWidget(harness());
    final first = MiniPlayerBar.hide();
    final second = MiniPlayerBar.hide();
    await tester.pump();
    expect(find.byType(MiniPlayerBar), findsNothing);
    first();
    await tester.pump();
    expect(find.byType(MiniPlayerBar), findsNothing,
        reason: 'ikinci oynatıcı hâlâ açık');
    second();
    await tester.pump();
    expect(find.byType(MiniPlayerBar), findsOneWidget);
  });

  group('Navigator ağacın DIŞINDAyken (üretimdeki yerleşim)', () {
    testWidgets('çubuğa dokunmak ÇÖKMEZ ve tam oynatıcıyı açar',
        (tester) async {
      AudioPlayback.instance
        ..playlist = ['/depo/Müzik/parca.mp3']
        ..index = 0
        ..playing = true;
      await tester.pumpWidget(appLikeHarness());
      expect(find.text('parca'), findsOneWidget);

      // Eskiden burada `Null check operator used on a null value` fırlıyordu:
      // çubuğun kendi `context`inde Navigator yok, `Navigator.of` çöküyordu.
      await tester.tap(find.text('parca'));
      await tester.pump();
      expect(tester.takeException(), isNull);
      // Kök gezgin gerçekten yeni bir ekran açtı.
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byType(AudioPlayerScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('gezgin anahtarı bağlı değilse sessizce hiçbir şey yapmaz',
        (tester) async {
      AudioPlayback.instance
        ..playlist = ['/depo/Müzik/parca.mp3']
        ..playing = true;
      // `navigatorKey` hiçbir MaterialApp'a verilmedi (seçici kipi/test).
      await tester.pumpWidget(harness());
      await tester.tap(find.text('parca'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}

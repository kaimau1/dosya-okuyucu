import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/screens/fm/image_gallery_screen.dart';
import 'package:dosya_okuyucu/services/fm/entry_opener.dart';
import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/open_history.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// U1 (2026-11-19, kullanıcı: "Geçmiş'te görsele dokununca donarak kasıyor").
///
/// Galeri saydam rota: altındaki Geçmiş listesi sahnede kalır. Açılış kaydı
/// galeri açıkken yapılırsa `OpenHistory.changes` listeyi galerinin altında
/// yeniden yükletip sıralatır (tam boy çözümle aynı karelerde). Bekçi: galeri
/// açıkken geçmiş bildirimi YOK; kapanınca kayıt düşer.
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('gallery_history');
    FmEnv.appSupportDir = '';
    OpenHistory.resetForTest();
  });

  tearDown(() {
    try {
      dir.deleteSync(recursive: true);
    } catch (_) {}
  });

  testWidgets('galeri açıkken geçmiş bildirimi yok, kapanınca kayıt',
      (tester) async {
    final a = File('${dir.path}/a.jpg')..writeAsBytesSync([0]);
    final b = File('${dir.path}/b.jpg')..writeAsBytesSync([0]);
    SharedPreferences.setMockInitialValues({'fm_media_open_with': 'inApp'});
    final state = AppState();
    await tester.runAsync(state.init);

    var notified = 0;
    void onChange() => notified++;
    OpenHistory.changes.addListener(onChange);
    addTearDown(() => OpenHistory.changes.removeListener(onChange));

    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => EntryOpener.open(context, a.path,
                  siblings: [a.path, b.path]),
              child: const Text('aç'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('aç'));
    // EntryOpener.open eşzamansız File.exists() ile gerçek dosya G/Ç yapar;
    // FakeAsync sahte saatinde tamamlanması için runAsync ile bekle.
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryScreen), findsOneWidget);
    expect(notified, 0,
        reason: 'saydam galerinin altındaki liste yeniden yüklenmemeli');

    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byType(ImageGalleryScreen), findsNothing);
    expect(notified, greaterThan(0));
    expect(OpenHistory.forPath(a.path), isNotNull);
  });
}

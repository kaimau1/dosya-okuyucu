import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/state/appearance_state.dart';
import 'package:dosya_okuyucu/main.dart' show AppProviders;
import 'package:dosya_okuyucu/models/recent_file.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Faz 3 (P3): kök `MaterialApp` yalnız [AppearanceState]i izler. Dosya açmak
/// (`addRecent`), panoya kopyalamak, uzak bağlantı kaydetmek kökü yeniden
/// KURMAMALI; tema/dil/yazı değişimi kurmalı.
void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    appState = AppState();
    await appState.init();
  });

  Future<int Function()> pumpRoot(WidgetTester tester) async {
    var builds = 0;
    await tester.pumpWidget(AppProviders(
      appState: appState,
      child: Builder(builder: (context) {
        // Kökle AYNI izleme: `DosyaOkuyucuApp.build`.
        context.watch<AppearanceState>();
        builds++;
        return const SizedBox();
      }),
    ));
    return () => builds;
  }

  testWidgets('dosya açmak / pano / tercih kökü yeniden kurmaz',
      (tester) async {
    final builds = await pumpRoot(tester);
    final before = builds();
    await tester.runAsync(() async {
      await appState.addRecent(RecentFile(
        path: '/x/a.pdf',
        name: 'a.pdf',
        sizeBytes: 10,
        openedAtMs: 1,
      ));
      appState.setClipboard(['/x/a.pdf'], cut: false);
      await appState.setFmShowHidden(true);
      await appState.removeRecent('/x/a.pdf');
    });
    await tester.pump();
    expect(builds(), before);
  });

  testWidgets('tema / dil / yazı ölçeği kökü yeniden kurar', (tester) async {
    final builds = await pumpRoot(tester);
    final before = builds();
    await tester.runAsync(() => appState.setThemeMode(ThemeMode.dark));
    await tester.pump();
    expect(builds(), before + 1);
    await tester.runAsync(() => appState.setAppSkin(AppSkin.values.last));
    await tester.runAsync(() => appState.setUiTextScale(1.2));
    await tester.pump();
    expect(builds(), before + 2);
    expect(appState.appearance.uiTextScale, 1.2);
    expect(appState.appearance.themeMode, ThemeMode.dark);
  });

  test('aynı değeri yeniden yazmak bildirmez', () async {
    var n = 0;
    appState.appearance.addListener(() => n++);
    await appState.setThemeMode(appState.themeMode);
    expect(n, 0);
  });

  test('son belgeler yalnız RecentsState i uyandırır', () async {
    var app = 0, recents = 0;
    appState.addListener(() => app++);
    appState.recentsState.addListener(() => recents++);
    await appState.addRecent(RecentFile(
        path: '/x/b.txt', name: 'b.txt', sizeBytes: 1, openedAtMs: 2));
    expect(recents, 1);
    expect(app, 0);
    expect(appState.recents.first.path, '/x/b.txt');
  });

  test('kök kaynakta AppState izlenmiyor', () {
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('class _DosyaOkuyucuAppState');
    final body = src.substring(start);
    expect(body.contains('watch<AppState>'), isFalse);
    expect(body.contains('watch<AppearanceState>'), isTrue);
  });
}

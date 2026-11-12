import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/state/appearance_state.dart';
import 'package:dosya_okuyucu/core/state/focused_states.dart';
import 'package:dosya_okuyucu/models/remote_connection.dart';
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

  test('A4.2: pano / uzak bağlantı / AI hafızası AppState i uyandırmaz',
      () async {
    var app = 0, clip = 0, remotes = 0, memory = 0;
    appState.addListener(() => app++);
    appState.clipboardState.addListener(() => clip++);
    appState.remotesState.addListener(() => remotes++);
    appState.memoryState.addListener(() => memory++);

    appState.setClipboard(['/x/a.pdf', '/x/b.pdf'], cut: true);
    expect(clip, 1);
    expect(appState.hasClipboard, isTrue);
    expect(appState.clipboardCut, isTrue);
    expect(appState.clipboard, ['/x/a.pdf', '/x/b.pdf']);
    appState.clearClipboard();
    appState.clearClipboard(); // boşken bildirmez
    expect(clip, 2);
    expect(appState.hasClipboard, isFalse);

    await appState.saveRemote(const RemoteConnection(
        id: 'r1',
        name: 'NAS',
        protocol: RemoteProtocol.sftp,
        host: 'nas',
        port: 22));
    expect(remotes, 1);
    expect(appState.remotes.single.id, 'r1');
    await appState.removeRemote('r1');
    expect(remotes, 2);
    expect(appState.remotes, isEmpty);

    await appState.addMemory('not');
    await appState.removeMemory(0);
    expect(memory, 2);
    expect(appState.memory, isEmpty);

    expect(app, 0);
  });

  testWidgets('A4.2: kopyalamak gezgin gövdesini değil yalnız düğmeyi kurar',
      (tester) async {
    var body = 0, fab = 0;
    await tester.pumpWidget(AppProviders(
      appState: appState,
      child: Builder(builder: (context) {
        final s = context.watch<AppState>();
        body++;
        return ListenableBuilder(
            listenable: s.clipboardState,
            builder: (context, _) {
              fab++;
              return const SizedBox();
            });
      }),
    ));
    final b0 = body, f0 = fab;
    appState.setClipboard(['/x/a.pdf'], cut: false);
    await tester.pump();
    expect(body, b0);
    expect(fab, f0 + 1);
    expect(tester.element(find.byType(SizedBox)).read<ClipboardState>().length,
        1);
  });

  test('A4.2: göz atma / AI tercihi dinlenen dilimi uyandırır, AppState i değil',
      () async {
    var app = 0, browse = 0, ai = 0;
    appState.addListener(() => app++);
    appState.browseState.addListener(() => browse++);
    appState.aiState.addListener(() => ai++);

    await appState.setFmShowHidden(true);
    await appState.setFmSort(appState.fmSort, descending: true);
    await appState.toggleBookmark('/x');
    expect(browse, 3);
    expect(appState.fmShowHidden, isTrue);
    expect(appState.isBookmarked('/x'), isTrue);

    await appState.setAiSendConsent(true);
    await appState.setAiModels(['m1']);
    expect(ai, 2);

    await appState.toggleLockedFolder('/kilit'); // ikisi de
    expect(browse, 4);
    expect(ai, 3);
    expect(app, 0);
  });

  test('A4.2: dilimi dinleyen yoksa AppState yine bildirir (eski ağaç)',
      () async {
    var app = 0;
    appState.addListener(() => app++);
    await appState.setFmShowHidden(true);
    await appState.setAiSendConsent(true);
    expect(app, 2);
  });

  testWidgets('A4.2: watchBrowse dilim değişiminde yeniden kurar, AI de değil',
      (tester) async {
    var builds = 0;
    await tester.pumpWidget(AppProviders(
      appState: appState,
      child: Builder(builder: (context) {
        context.watchBrowse();
        builds++;
        return const SizedBox();
      }),
    ));
    final b0 = builds;
    await tester.runAsync(() => appState.setFmShowHidden(true));
    await tester.pump();
    expect(builds, b0 + 1);
    await tester.runAsync(() => appState.setAiSendConsent(true));
    await tester.pump();
    expect(builds, b0 + 1);
  });

  test('kök kaynakta AppState izlenmiyor', () {
    final src = File('lib/main.dart').readAsStringSync();
    final start = src.indexOf('class _DosyaOkuyucuAppState');
    final body = src.substring(start);
    expect(body.contains('watch<AppState>'), isFalse);
    expect(body.contains('watch<AppearanceState>'), isTrue);
  });
}

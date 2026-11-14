import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/tablet.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_file_list_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/temp_dir.dart';

/// **Ferrari H9 — tablet** (2026-11-14). Tablet yok: geniş ekran widget
/// testiyle (1280 × 800 dp yatay ↔ 800 × 1280 dikey) kanıtlanır; telefonun
/// (dar ekran) eski düzeni aynı kalır.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _tabletLand = Size(1280, 800);
const _tabletPort = Size(800, 1280);

void setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pump(const Duration(milliseconds: 400));
}

Future<AppState> appState(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.runAsync(state.init);
  return state;
}

Widget app(AppState state, Widget home) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: home,
      ),
    );

void main() {
  test('tablet ölçütü: telefon yatayda da dar sayılır', () {
    expect(isTabletWide(_tabletLand), isTrue);
    expect(isTabletWide(_tabletPort), isFalse); // < 840 dp
    expect(isTabletWide(const Size(360, 780)), isFalse);
    expect(isTabletWide(const Size(870, 392)), isFalse); // telefon yatay
  });

  group('H9.2 döndürme', () {
    late Directory dir;
    setUp(() {
      dir = Directory.systemTemp.createTempSync('tablet_h9');
      for (var i = 0; i < 80; i++) {
        File('${dir.path}/dosya_${i.toString().padLeft(2, '0')}.txt')
            .writeAsStringSync('x');
      }
    });
    tearDown(() => removeTempDir(dir));

    ScrollPosition listPosition(WidgetTester tester) => tester
        .state<ScrollableState>(find
            .descendant(
                of: find.byType(FmFileListView),
                matching: find.byType(Scrollable))
            .first)
        .position;

    testWidgets('gezgin: yatay ↔ dikey dönüşte kaydırma konumu korunur',
        (tester) async {
      final state = await appState(tester);
      setSize(tester, _tabletLand);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(state, BrowserScreen(path: dir.path)));
      await settle(tester);
      expect(find.text('Konumlar'), findsOneWidget,
          reason: '≥ 840 dp: solda birimler bölmesi');

      listPosition(tester).jumpTo(600);
      await tester.pump();
      expect(listPosition(tester).pixels, 600);

      setSize(tester, _tabletPort);
      await tester.pump();
      await tester.pump();
      expect(find.text('Konumlar'), findsNothing);
      expect(listPosition(tester).pixels, 600,
          reason: 'dikeye dönünce liste başa atlamamalı');

      setSize(tester, _tabletLand);
      await tester.pump();
      await tester.pump();
      expect(find.text('Konumlar'), findsOneWidget);
      expect(listPosition(tester).pixels, 600);
    });
  });
}

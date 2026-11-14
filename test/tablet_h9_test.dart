import 'dart:io';

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/tablet.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/dual_pane_screen.dart';
import 'package:dosya_okuyucu/screens/fm/open_history_screen.dart';
import 'package:dosya_okuyucu/screens/home_screen.dart';
import 'package:dosya_okuyucu/services/large_text.dart';
import 'package:dosya_okuyucu/widgets/fm/home_nav_column.dart';
import 'package:dosya_okuyucu/widgets/large_text_view.dart';
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

  group('H9.1 gezinme sütunu', () {
    setUp(HomeScreen.debugResetStartFolder);
    tearDown(HomeScreen.debugResetStartFolder);
    final column = find.byKey(const ValueKey('home-nav-column'));

    testWidgets('telefonda sütun KURULMAZ', (tester) async {
      final state = await appState(tester);
      addTearDown(tester.view.reset);
      // Varsayılan test görünümü (800 × 600 dp — dar sayılır); 360 dp'lik
      // telefonda pano karoları test yazı tipiyle (Ahem) taşıyor, konu dışı.
      // Telefon boyları `isTabletWide` birim testinde.
      expect(
          isTabletWide(
              tester.view.physicalSize / tester.view.devicePixelRatio),
          isFalse);
      await tester.pumpWidget(app(state, const HomeScreen()));
      await tester.pump();
      expect(find.byType(HomeNavColumn), findsNothing);
    });

    testWidgets('tablette sütun: seç → sağda açılır, daralt, döndür',
        (tester) async {
      final state = await appState(tester);
      setSize(tester, _tabletLand);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(app(state, const HomeScreen()));
      await tester.pump();
      expect(column, findsOneWidget);
      expect(tester.getSize(column).width, HomeNavColumn.expandedWidth);

      await tester.tap(find.descendant(
          of: column, matching: find.text('Son açılanlar')));
      await tester.pump();
      expect(find.byType(OpenHistoryScreen), findsOneWidget);
      expect(column, findsOneWidget, reason: 'sütun yerinde kalır');

      await tester.tap(find.byKey(const ValueKey('home-nav-toggle')));
      await tester.pump();
      expect(tester.getSize(column).width, HomeNavColumn.collapsedWidth);

      // Dikeye dön: sütun kalkar, açık sekme ve durumu korunur.
      final before = tester.state(find.byType(OpenHistoryScreen));
      setSize(tester, _tabletPort);
      await tester.pump();
      expect(column, findsNothing);
      expect(tester.state(find.byType(OpenHistoryScreen)), same(before),
          reason: 'döndürünce sekme yeniden kurulmamalı');
      setSize(tester, _tabletLand);
      await tester.pump();
      expect(column, findsOneWidget);
      expect(tester.state(find.byType(OpenHistoryScreen)), same(before));
    });
  });

  group('H9.4 satır sınırı', () {
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('tablet_h94'));
    tearDown(() => removeTempDir(dir));

    EdgeInsetsGeometry? padding(WidgetTester tester) =>
        tester.widget<ListView>(find.byType(ListView)).padding;

    testWidgets('dev metin tablette ortalanır, telefonda dolgu aynı',
        (tester) async {
      final path = '${dir.path}/dev.txt';
      File(path).writeAsStringSync(List.filled(50, 'satır').join('\n'));
      final file = LargeTextFile.openSync(path);
      final state = await appState(tester);
      addTearDown(tester.view.reset);
      Widget view() => app(
          state,
          Scaffold(
              body: LargeTextView(path: path, fontSize: 14, file: file)));

      setSize(tester, const Size(360, 780));
      await tester.pumpWidget(view());
      await tester.pump();
      expect(padding(tester),
          const EdgeInsetsDirectional.fromSTEB(12, 8, 16, 24));

      setSize(tester, _tabletLand);
      await tester.pump();
      expect(padding(tester),
          const EdgeInsetsDirectional.fromSTEB(242, 8, 246, 24));
    });
  });

  group('H9.5 sürükle-bırak', () {
    late Directory left, right;
    setUp(() {
      left = Directory.systemTemp.createTempSync('tablet_h95a');
      right = Directory.systemTemp.createTempSync('tablet_h95b');
      File('${left.path}/a.txt').writeAsStringSync('x');
    });
    tearDown(() {
      removeTempDir(left);
      removeTempDir(right);
    });

    testWidgets('tablette seçili satır karşı bölmeye bırakılınca kopyalanır',
        (tester) async {
      final state = await appState(tester);
      setSize(tester, _tabletLand);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          app(state, DualPaneScreen(left: left.path, right: right.path)));
      await settle(tester);
      await tester.longPress(find.text('a.txt'));
      await tester.pump();
      final handle = find.byKey(ValueKey('dp-drag-${left.path}/a.txt'));
      expect(handle, findsOneWidget);

      final g = await tester.startGesture(tester.getCenter(handle));
      final to = tester.getCenter(find.byKey(const ValueKey('dp-pane-1')));
      final from = tester.getCenter(handle);
      for (var i = 1; i <= 10; i++) {
        await g.moveTo(Offset.lerp(from, to, i / 10)!);
        await tester.pump();
      }
      await g.up();
      await settle(tester);
      expect(File('${right.path}/a.txt').existsSync(), isTrue);
      expect(File('${left.path}/a.txt').existsSync(), isTrue,
          reason: 'bırakma kopyalar, taşımaz');
    });

    testWidgets('telefonda tutamaç yok (seçim işareti aynı)', (tester) async {
      final state = await appState(tester);
      setSize(tester, const Size(360, 780));
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
          app(state, DualPaneScreen(left: left.path, right: right.path)));
      await settle(tester);
      await tester.longPress(find.text('a.txt'));
      await tester.pump();
      expect(find.byType(Draggable<int>), findsNothing);
      expect(find.byType(DragTarget<int>), findsNothing);
    });
  });
}

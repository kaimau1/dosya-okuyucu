import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/fm/audio_player_screen.dart';
import 'package:dosya_okuyucu/screens/fm/dashboard_screen.dart';
import 'package:dosya_okuyucu/screens/fm/operations_screen.dart';
import 'package:dosya_okuyucu/screens/image_edit_screen.dart';
import 'package:dosya_okuyucu/screens/settings/settings_category_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:dosya_okuyucu/screens/viewer_screen.dart';
import 'package:dosya_okuyucu/services/fm/audio_playback.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/media_session.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:dosya_okuyucu/widgets/mini_player_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app(AppState state, Widget home) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: home,
      ),
    );

Future<AppState> _initState(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.runAsync(state.init);
  return state;
}

void main() {
  test('FsScan atlanacak sistem klasörleri ve geçici medya dosyalarını süzer',
      () {
    expect(FsScan.skipDirNames, containsAll(['.hwthumbnails', '.Gallery2']));
    expect(FsScan.isTransientMediaName('.pending-1723106006425-VID.mp4'),
        isTrue);
    expect(FsScan.isTransientMediaName('.trashed-1723-foto.jpg'), isTrue);
    expect(FsScan.isTransientMediaName('VID_20240801_113326.mp4'), isFalse);
  });

  test('FmCategoryGrid.balancedColumns öksüz satırları önler ve columnsFor korunur',
      () {
    expect(FmCategoryGrid.columnsFor(411), 4);
    expect(FmCategoryGrid.columnsFor(500), 4);
    expect(FmCategoryGrid.columnsFor(900), 8);

    expect(FmCategoryGrid.balancedColumns(600, 12), 4);
    expect(FmCategoryGrid.balancedColumns(700, 12), 4);
    expect(FmCategoryGrid.balancedColumns(600, 8), 4);
    expect(FmCategoryGrid.balancedColumns(300, 6), 3);
    expect(FmCategoryGrid.balancedColumns(600, 6), 3);
    expect(FmCategoryGrid.balancedColumns(700, 6), 6);
  });

  test('pdfCenterYBelowChrome açılışta ilk sayfayı üst çubuk altına çeker',
      () {
    expect(pdfCenterYBelowChrome(500, 88, 1.0), 412);
    expect(pdfCenterYBelowChrome(500, 88, 0.8), 390);
    expect(pdfCenterYBelowChrome(500, 0, 1.0), 500);
    expect(pdfCenterYBelowChrome(500, 88, 0), 500);
  });

  group('Tablet düzen iyileştirmeleri', () {
    testWidgets('yatay tablet panosunda araçlar sol sütunda dengelenir',
        (tester) async {
      final state = await _initState(tester);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(state, const DashboardScreen()));
      await tester.pump();

      final rowFinder = find.byKey(const ValueKey('dash-two-columns'));
      expect(rowFinder, findsOneWidget);
      final leftCol =
          tester.widget<Row>(rowFinder).children.first as SizedBox;
      expect(
        find.descendant(
          of: find.byWidget(leftCol),
          matching: find.byType(FmToolGrid),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('dikey tablet panosunda iki sütun ve taşmasız alt araçlar',
        (tester) async {
      final state = await _initState(tester);
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(state, const DashboardScreen()));
      await tester.pump();

      final rowFinder = find.byKey(const ValueKey('dash-two-columns'));
      expect(rowFinder, findsOneWidget);
      expect(find.byType(FmToolGrid), findsOneWidget);
      expect(
        find.descendant(of: rowFinder, matching: find.byType(FmToolGrid)),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('geniş ayarlarda tek tema galerisi ve gömülü sağ başlık',
        (tester) async {
      final state = await _initState(tester);
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(state, const SettingsScreen()));
      await tester.pump();

      expect(find.byKey(const ValueKey('settings-list-detail')), findsOneWidget);
      expect(find.byKey(const ValueKey('theme-gallery-strip')), findsOneWidget);
      final detail = tester.widget<SettingsCategoryScreen>(
          find.byType(SettingsCategoryScreen));
      expect(detail.embedded, isTrue);
      expect(
        find.descendant(
          of: find.byType(SettingsCategoryScreen),
          matching: find.byIcon(AppIcons.back),
        ),
        findsNothing,
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('OperationsScreen başlığı etkin sekmeyi yansıtır',
        (tester) async {
      final state = await _initState(tester);
      await tester.pumpWidget(_app(
        state,
        const OperationsScreen(
            initial: OpsTab.cleanup, index: StorageIndex.empty),
      ));
      await tester.pump();

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(
        find.descendant(
          of: find.byWidget(appBar),
          matching: find.text('Yer aç'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byWidget(appBar),
          matching: find.text('İşlemler'),
        ),
        findsNothing,
      );
    });

    testWidgets('AudioPlayerScreen geniş ekranda iki bölmeli açılır ve taşmaz',
        (tester) async {
      final state = await _initState(tester);
      AudioPlayback.notificationsEnabled = false;
      AudioPlayback.engineEnabled = false;
      MediaSession.debugReset();
      MiniPlayerBar.hidden.value = 0;
      AudioPlayback.instance
        ..playlist = ['/tmp/a.mp3', '/tmp/b.mp3']
        ..index = 0
        ..playing = false
        ..position = Duration.zero
        ..duration = Duration.zero;
      addTearDown(() {
        AudioPlayback.instance
          ..playlist = const []
          ..index = 0
          ..playing = false;
        MediaSession.debugReset();
        MiniPlayerBar.hidden.value = 0;
      });
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(
        state,
        const AudioPlayerScreen(
          path: '/tmp/a.mp3',
          playlist: ['/tmp/a.mp3', '/tmp/b.mp3'],
        ),
      ));
      await tester.pump();

      expect(find.byType(VerticalDivider), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ImageEditScreen koyu stüdyo temasıyla kurulur', (tester) async {
      final state = await _initState(tester);
      await tester.pumpWidget(
        _app(state, const ImageEditScreen(path: '/tmp/nonexistent.png')),
      );
      await tester.pump();

      final scaffoldCtx = tester.element(find.byType(Scaffold).last);
      expect(Theme.of(scaffoldCtx).brightness, Brightness.dark);
      expect(tester.takeException(), isNull);
    });
  });
}

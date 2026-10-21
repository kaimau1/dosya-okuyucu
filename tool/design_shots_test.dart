// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 6 tasarım görüntüleri: `flutter test tool/design_shots_test.dart`
// → docs/design/*.png. Normal test takımında KOŞMAZ (test/ altında değil).
//
// Yöntem HAFIZA 2026-10-17 (3) D: FontLoader ile Carlito + SDK'nın
// MaterialIcons'u yüklenir (setUpAll'da — testWidgets gövdesinde sahte saatte
// asılı kalır), ekran `RepaintBoundary.toImage` ile PNG'ye yazılır.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_entry_tiles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

Future<void> _font(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final f in files) {
    final bytes = File(f).readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

void main() {
  late Directory root;
  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    root = Directory.systemTemp.createTempSync('design');
    final base = '${root.path}/Belgeler';
    Directory('$base/Faturalar').createSync(recursive: true);
    Directory('$base/Projeler').createSync(recursive: true);
    Directory('$base/Boş klasör').createSync(recursive: true);
    final now = DateTime.now();
    final files = {
      'Kira sözleşmesi.pdf': (120000, 0),
      'Toplantı notları.docx': (34000, 0),
      'Bütçe 2026.xlsx': (56000, 2),
      'Sunum taslağı.pptx': (980000, 3),
      'Tatil.jpg': (2400000, 9),
      'Röportaj.mp3': (5200000, 12),
      'Yedek.zip': (15000000, 40),
      'okuma-listesi.txt': (1200, 60),
    };
    files.forEach((name, v) {
      final f = File('$base/$name')..writeAsBytesSync(List.filled(v.$1, 32));
      f.setLastModifiedSync(now.subtract(Duration(days: v.$2, hours: 1)));
    });
  });

  Future<void> shot(WidgetTester tester, String name,
      {Brightness brightness = Brightness.light,
      Size size = const Size(400, 820),
      FmLayout layout = FmLayout.list,
      String sub = 'Belgeler',
      Future<void> Function(WidgetTester)? act}) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    await tester.runAsync(() => state.setFmLayout(layout));
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          navigatorKey: nav,
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: _delegates,
          home: const Scaffold(),
        ),
      ),
    ));
    nav.currentState!
        .push(browserRoute(BrowserScreen(path: '${root.path}/$sub')));
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 40)));
        await tester.pump(const Duration(milliseconds: 60));
      }
      await tester.pump(const Duration(seconds: 1));
    }

    await settle();
    if (act != null) {
      await act(tester);
      await settle();
    }
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('docs/design/$name.png').writeAsBytesSync(bytes!);
  }

  testWidgets('liste açık', (t) => shot(t, 'liste_acik'));
  testWidgets('liste koyu',
      (t) => shot(t, 'liste_koyu', brightness: Brightness.dark));
  testWidgets('ızgara açık',
      (t) => shot(t, 'izgara_acik', layout: FmLayout.grid3));
  testWidgets('ızgara koyu',
      (t) => shot(t, 'izgara_koyu',
          layout: FmLayout.grid3, brightness: Brightness.dark));
  testWidgets('seçim', (t) => shot(t, 'secim_acik', act: (t) async {
        await t.longPress(find.byType(FmEntryRow).at(3));
        await t.pump(const Duration(milliseconds: 300));
        await t.tap(find.byType(FmEntryRow).at(4));
      }));
  testWidgets('filtre', (t) => shot(t, 'filtre_acik', act: (t) async {
        await t.tap(find.byTooltip('Filtre'));
      }));
  testWidgets('boş', (t) => shot(t, 'bos_koyu',
      sub: 'Belgeler/Boş klasör', brightness: Brightness.dark));
  testWidgets('tablet', (t) => shot(t, 'tablet_acik',
      size: const Size(1100, 700)));
}

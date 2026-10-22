// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 15/16 tasarım görüntüleri — ana ekranlar açık/koyu (+ Arapça):
//
//   SHOT_DIR=faz15/once flutter test tool/design_shots_faz15_test.dart
//   SHOT_DIR=faz16/ar SHOT_LOCALE=ar flutter test tool/design_shots_faz15_test.dart
//
// → docs/design/$SHOT_DIR/*.png. Normal test takımında KOŞMAZ (test/ altında
// değil). Yöntem `tool/design_shots_test.dart` ile aynı (FontLoader + toImage).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/browser_screen.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/open_history_screen.dart';
import 'package:dosya_okuyucu/screens/fm/search_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:dosya_okuyucu/services/fm/list_memory.dart';
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

ThemeData _withArabic(ThemeData t) => t.copyWith(
      textTheme:
          t.textTheme.apply(fontFamilyFallback: const ['NotoNaskhArabic']));

void main() {
  final out = 'docs/design/${Platform.environment['SHOT_DIR'] ?? 'faz15'}';
  final locale = Locale(Platform.environment['SHOT_LOCALE'] ?? 'tr');
  final now = DateTime.now();
  final dir = Directory.systemTemp.createTempSync('faz15');
  final base = '${dir.path}/Belgeler';
  Directory('$base/Faturalar').createSync(recursive: true);
  Directory('$base/Projeler').createSync(recursive: true);
  final spec = {
    'Kira sözleşmesi.pdf': (120000, 0),
    'Toplantı notları.docx': (34000, 0),
    'Fatura Ekim.pdf': (88000, 1),
    'Bütçe 2026.xlsx': (56000, 2),
    'Sunum taslağı.pptx': (980000, 3),
    'Tatil.jpg': (2400000, 5),
    'Röportaj.mp3': (5200000, 9),
    'Yedek.zip': (15000000, 40),
    'okuma-listesi.txt': (1200, 60),
  };
  final files = <FsEntry>[];
  spec.forEach((name, v) {
    final f = File('$base/$name')..writeAsBytesSync(List.filled(v.$1, 32));
    final at = now.subtract(Duration(days: v.$2, hours: 1));
    f.setLastModifiedSync(at);
    files.add(FsEntry(
        path: f.path,
        name: name,
        isDir: false,
        sizeBytes: v.$1,
        modifiedMs: at.millisecondsSinceEpoch));
  });
  final history = [
    for (final e in files) (entry: e, openedAtMs: e.modifiedMs),
  ];

  setUpAll(() async {
    final sdk =
        Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    // Arapça glifler: cihazda sistem yazı tipine düşer; testte düşüş yok →
    // SDK'nın Noto Naskh Arabic'i yedek aile olarak yüklenir.
    await _font('NotoNaskhArabic', [
      '$sdk/engine/src/flutter/txt/third_party/fonts/NotoNaskhArabic-Regular.ttf'
    ]);
    Directory(out).createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name, Widget Function() screen,
      {Brightness brightness = Brightness.light,
      bool push = false,
      double textScale = 1}) async {
    SharedPreferences.setMockInitialValues({});
    ListMemory.resetForTest();
    final state = AppState();
    await tester.runAsync(state.init);
    const size = Size(400, 820);
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
          theme: _withArabic(brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark()),
          locale: locale,
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: _delegates,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: push ? const Scaffold() : screen(),
        ),
      ),
    ));
    if (push) nav.currentState!.push(browserRoute(screen()));
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 40)));
      await tester.pump(const Duration(milliseconds: 60));
    }
    await tester.pump(const Duration(seconds: 1));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    File('$out/$name.png').writeAsBytesSync(bytes!);
  }

  final screens = <String, (Widget Function(), bool)>{
    'gezgin': (() => BrowserScreen(path: base), true),
    'kategori': (
      () => CategoryScreen(
          title: 'Belgeler', files: files, memoryId: 'shots_docs'),
      false
    ),
    'son_acilanlar': (() => OpenHistoryScreen(entriesForTest: history), false),
    'arama': (() => const SearchScreen(), false),
    'ayarlar': (() => const SettingsScreen(), false),
  };
  for (final b in Brightness.values) {
    final suffix = b == Brightness.light ? 'acik' : 'koyu';
    screens.forEach((name, s) {
      testWidgets('$name $suffix',
          (t) => shot(t, '${name}_$suffix', s.$1, brightness: b, push: s.$2));
    });
  }
  // Büyük yazı (Faz 16): uygulama içi ölçeğin üst ucu.
  screens.forEach((name, s) {
    testWidgets('$name 2x',
        (t) => shot(t, '${name}_2x', s.$1, push: s.$2, textScale: 2));
  });
}

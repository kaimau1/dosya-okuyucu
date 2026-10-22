// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 13 tasarım görüntüleri: `flutter test tool/design_shots_faz13_test.dart`
// → docs/design/faz13/*.png. Normal test takımında KOŞMAZ (test/ altında değil).
// Yöntem `tool/design_shots_test.dart` ile aynı (FontLoader + toImage).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/screens/fm/category_screen.dart';
import 'package:dosya_okuyucu/screens/fm/open_history_screen.dart';
import 'package:dosya_okuyucu/services/fm/list_memory.dart';
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
  final now = DateTime.now().millisecondsSinceEpoch;
  const day = 24 * 60 * 60 * 1000;
  // Ekranlar diskte olmayan girdiyi ayıklıyor (`FsScan.pruneMissing`) →
  // dosyalar gerçekten yazılır (içerik boş).
  final dir = Directory.systemTemp.createTempSync('faz13').path;
  FsEntry f(String name, int size, int agoDays) => FsEntry(
        path: (File('$dir/$name')..writeAsStringSync('')).path,
        name: name,
        isDir: false,
        sizeBytes: size,
        modifiedMs: now - agoDays * day,
      );
  final files = [
    f('Kira sözleşmesi.pdf', 120000, 0),
    f('Toplantı notları.docx', 34000, 0),
    f('Fatura Ekim.pdf', 88000, 1),
    f('Bütçe 2026.xlsx', 56000, 2),
    f('Sunum taslağı.pptx', 980000, 3),
    f('Tatil.jpg', 2400000, 5),
    f('Röportaj.mp3', 5200000, 9),
    f('Dilekçe.pdf', 41000, 12),
    f('Yedek.zip', 15000000, 40),
    f('okuma-listesi.txt', 1200, 60),
  ];
  final history = [
    for (var i = 0; i < files.length; i++)
      (entry: files[i], openedAtMs: now - [0, 0, 1, 2, 3, 5, 9, 12, 40, 60][i] * day),
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
    Directory('docs/design/faz13').createSync(recursive: true);
  });

  Future<void> shot(WidgetTester tester, String name, Widget screen,
      {Brightness brightness = Brightness.light,
      Future<void> Function(WidgetTester)? act}) async {
    SharedPreferences.setMockInitialValues({});
    ListMemory.resetForTest();
    final state = AppState();
    await tester.runAsync(state.init);
    const size = Size(400, 820);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: brightness == Brightness.light
              ? AppTheme.light()
              : AppTheme.dark(),
          locale: const Locale('tr'),
          supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
          localizationsDelegates: _delegates,
          home: screen,
        ),
      ),
    ));
    Future<void> settle() async {
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 30)));
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
    File('docs/design/faz13/$name.png').writeAsBytesSync(bytes!);
  }

  Widget recent() => OpenHistoryScreen(entriesForTest: history);
  Widget fresh() => CategoryScreen(
      title: 'Yeni gelenler', files: files, memoryId: 'new_files');
  Future<void> pickPdf(WidgetTester t) =>
      t.tap(find.textContaining('PDF ·').first);

  for (final b in Brightness.values) {
    final suffix = b == Brightness.light ? 'acik' : 'koyu';
    testWidgets('son açılanlar $suffix',
        (t) => shot(t, 'son_acilanlar_$suffix', recent(), brightness: b));
    testWidgets('son açılanlar PDF $suffix',
        (t) => shot(t, 'son_acilanlar_pdf_$suffix', recent(),
            brightness: b, act: pickPdf));
    testWidgets('son açılanlar seçim $suffix',
        (t) => shot(t, 'son_acilanlar_secim_$suffix', recent(),
            brightness: b, act: (t) async {
          await t.longPress(find.byType(FmEntryRow).at(0));
          await t.pump(const Duration(milliseconds: 300));
          await t.tap(find.byType(FmEntryRow).at(2));
        }));
    testWidgets('yeni gelenler $suffix',
        (t) => shot(t, 'yeni_gelenler_$suffix', fresh(), brightness: b));
    testWidgets('yeni gelenler PDF $suffix',
        (t) => shot(t, 'yeni_gelenler_pdf_$suffix', fresh(),
            brightness: b, act: pickPdf));
  }
}

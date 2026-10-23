// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 25 tasarım görüntüleri — Excel mobil gibi veri girişi:
//
//   flutter test tool/design_shots_faz25_test.dart
//   SHOT_LOCALE=ar flutter test tool/design_shots_faz25_test.dart
//
// → docs/design/faz25/*.png (hücre içi editör + klavye üstü çubuk, uygulama
// tuş takımı, işaret kipi, seçim tutamakları, bağlam menüsü; açık/koyu).
// Gerçek [SpreadsheetEditorScreen] çizilir. Normal test takımında KOŞMAZ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/sheet_cell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import '../test/support/xlsx_fixture.dart';

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

ThemeData _withArabic(ThemeData t) {
  TextStyle? fb(TextStyle? s) =>
      s?.copyWith(fontFamilyFallback: const ['NotoNaskhArabic']);
  return t.copyWith(
      textTheme:
          t.textTheme.apply(fontFamilyFallback: const ['NotoNaskhArabic']),
      listTileTheme: t.listTileTheme.copyWith(
          titleTextStyle: fb(t.listTileTheme.titleTextStyle ?? t.textTheme.bodyLarge),
          subtitleTextStyle:
              fb(t.listTileTheme.subtitleTextStyle ?? t.textTheme.bodyMedium)));
}

const _keyboard = 290.0;

class _FakeKeyboard extends StatelessWidget {
  const _FakeKeyboard();
  @override
  Widget build(BuildContext context) => Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Container(
        height: _keyboard,
        alignment: Alignment.center,
        child: Text('[ Android klavyesi ]',
            style: TextStyle(color: Theme.of(context).colorScheme.outline)),
      ));
}

void main() {
  const out = 'docs/design/faz25';
  final locale = Locale(Platform.environment['SHOT_LOCALE'] ?? 'tr');
  final suffixLocale = locale.languageCode == 'tr' ? '' : '_${locale.languageCode}';
  late String path;

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flt/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('NotoNaskhArabic', [
      '$sdk/engine/src/flutter/txt/third_party/fonts/NotoNaskhArabic-Regular.ttf'
    ]);
    Directory(out).createSync(recursive: true);
    SpreadsheetEditorScreen.parseInIsolate = false;
    EditPrefs.autoSave = false;
    final dir = Directory.systemTemp.createTempSync('faz25_shots');
    path = '${dir.path}/butce.xlsx';
    File(path).writeAsBytesSync(xlsxFrom({
      'A1': 'Kalem', 'B1': 'Ocak', 'C1': 'Şubat', 'D1': 'Toplam',
      'A2': 'Kira', 'B2': 12500, 'C2': 12500, 'D2': '=SUM(B2:C2)',
      'A3': 'Market', 'B3': 4310, 'C3': 3975, 'D3': '=SUM(B3:C3)',
      'A4': 'Fatura', 'B4': 1840, 'C4': 2115, 'D4': '=SUM(B4:C4)',
      'A5': 'Ulaşım', 'B5': 950, 'C5': 1020, 'D5': '=SUM(B5:C5)',
    }));
  });

  Finder cell(String s) =>
      find.ancestor(of: find.text(s), matching: find.byType(SheetCell)).first;

  Future<void> tap(WidgetTester t, Finder f) async {
    await t.tap(f);
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> shot(WidgetTester tester, String name,
      {Brightness brightness = Brightness.light,
      bool keyboard = false,
      required Future<void> Function(WidgetTester) after}) async {
    const size = Size(400, 820);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 2);
    }
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    // flutter_test gölgeleri düz siyah çizer; görüntüde gerçek gölge olsun
    // (gövde bitmeden geri alınır — test değişmez denetimi).
    debugDisableShadows = false;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withArabic(brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark()),
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        builder: (context, child) => Stack(children: [
          child!,
          if (keyboard)
            const Positioned(left: 0, right: 0, bottom: 0, child: _FakeKeyboard()),
        ]),
        home: SpreadsheetEditorScreen(path: path, name: 'butce.xlsx', plainText: ''),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await after(tester);
    await tester.pump(const Duration(seconds: 1));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    debugDisableShadows = true;
    final suffix = brightness == Brightness.light ? 'acik' : 'koyu';
    File('$out/$name${suffixLocale}_$suffix.png').writeAsBytesSync(bytes!);
  }

  for (final b in Brightness.values) {
    testWidgets('hücre içi editör $b', (t) => shot(t, 'hucre_editoru',
        brightness: b, keyboard: true, after: (t) async {
          await tap(t, cell('Market'));
          await tap(t, cell('Market'));
        }));
    testWidgets('tuş takımı $b', (t) => shot(t, 'tus_takimi',
        brightness: b, after: (t) async {
          await tap(t, cell('4310'));
          await tap(t, cell('4310'));
        }));
    testWidgets('işaret kipi $b', (t) => shot(t, 'isaret_kipi',
        brightness: b, keyboard: true, after: (t) async {
          await tap(t, cell('Ulaşım'));
          await tap(t, cell('Ulaşım'));
          final field = find.descendant(
              of: find.byKey(const ValueKey('floating-cell-editor')),
              matching: find.byType(TextField));
          await t.enterText(field, '=');
          await t.pump();
          await tap(t, cell('12500'));
          await t.enterText(field, '${t.widget<TextField>(field).controller!.text}+');
          await t.pump();
          await tap(t, cell('950'));
        }));
    testWidgets('tutamaklar $b', (t) => shot(t, 'tutamaklar',
        brightness: b, after: (t) async {
          await tap(t, cell('4310'));
        }));
    testWidgets('bağlam menüsü $b', (t) => shot(t, 'baglam_menusu',
        brightness: b, after: (t) async {
          await t.longPress(cell('Fatura'));
          await t.pump();
          await t.pump(const Duration(milliseconds: 500));
        }));
  }
}

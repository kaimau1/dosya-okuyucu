// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 23 tasarım görüntüleri — Word biçimlendirme:
//
//   flutter test tool/design_shots_faz23_test.dart
//
// → docs/design/faz23/*.png (Giriş şeridi, stil galerisi, klavye üstü
// çubuk, Aa paneli üç sekme, koyu tema, Arapça). Gerçek
// [WordMobileEditorScreen] çizilir. Normal test takımında KOŞMAZ.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
  const out = 'docs/design/faz23';
  late String path;
  late String arPath;

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
    await _font('Carlito', [
      'assets/fonts/Carlito-Regular.ttf',
      'assets/fonts/Carlito-Bold.ttf',
    ]);
    for (final fam in const ['Tinos', 'Arimo']) {
      await _font(fam, [
        for (final f in Directory('assets/fonts').listSync())
          if (f.path.split('/').last.startsWith(fam)) f.path,
      ]);
    }
    await _font('MaterialIcons',
        ['$sdk/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf']);
    await _font('NotoNaskhArabic', [
      '$sdk/engine/src/flutter/txt/third_party/fonts/NotoNaskhArabic-Regular.ttf'
    ]);
    Directory(out).createSync(recursive: true);
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    final dir = Directory.systemTemp.createTempSync('faz23_shots');
    path = '${dir.path}/rapor.docx';
    File(path).writeAsBytesSync(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
    arPath = '${dir.path}/arapca.docx';
    File(arPath).writeAsBytesSync(
        File('test/fixtures/office/arapca_rtl.docx').readAsBytesSync());
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 200));
  }

  Future<void> shot(WidgetTester tester, String name,
      {Brightness brightness = Brightness.light,
      bool keyboard = false,
      String locale = 'tr',
      String? file,
      Future<void> Function(WidgetTester, DocxEditController)? after}) async {
    const size = Size(400, 820);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    if (keyboard) {
      tester.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 2);
    }
    addTearDown(tester.view.reset);
    final key = GlobalKey();
    debugDisableShadows = false;
    await tester.pumpWidget(RepaintBoundary(
      key: key,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: _withArabic(brightness == Brightness.light
            ? AppTheme.light()
            : AppTheme.dark()),
        locale: Locale(locale),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        builder: (context, child) => Stack(children: [
          child!,
          if (keyboard)
            const Positioned(left: 0, right: 0, bottom: 0, child: _FakeKeyboard()),
        ]),
        home: WordMobileEditorScreen(path: file ?? path, name: 'rapor.docx'),
      ),
    ));
    for (var i = 0; i < 30 && find.byType(DocxEditorView).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await settle(tester);
    final c = tester.widget<DocxEditorView>(find.byType(DocxEditorView)).controller;
    if (after != null) await after(tester, c);
    await tester.pump(const Duration(milliseconds: 500));
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final bytes = await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data!.buffer.asUint8List();
    });
    debugDisableShadows = true;
    final suffix = brightness == Brightness.light ? 'acik' : 'koyu';
    File('$out/${name}_$suffix.png').writeAsBytesSync(bytes!);
  }

  int find0(DocxEditController c, String s) =>
      c.paras.indexWhere((p) => p.text.startsWith(s));

  /// Klavye açıkken Aa → panel (klavye iner) → [tab] sekmesi.
  Future<void> panel(WidgetTester t, String tab) async {
    t.view.viewInsets = const FakeViewPadding(bottom: _keyboard * 2);
    await t.pump();
    await t.pump();
    await t.tap(find.byKey(const ValueKey('accessory-format')));
    t.view.viewInsets = FakeViewPadding.zero;
    await t.pump();
    await t.pump();
    final f = find.descendant(
        of: find.byKey(const ValueKey('format-panel')),
        matching: find.text(tab));
    await t.tap(f.first);
    await t.pump();
  }

  for (final b in Brightness.values) {
    testWidgets('giriş şeridi $b', (t) => shot(t, 'giris_seridi', brightness: b,
        after: (t, c) async {
          final i = find0(c, 'Bu belge');
          final k = c.paras[i].text.indexOf('kalın');
          c.select(DocPos(i, k), DocPos(i, k + 5));
          await t.pump();
        }));
    testWidgets('klavye üstü çubuk $b', (t) => shot(t, 'klavye_ustu',
        brightness: b, keyboard: true, after: (t, c) async {
          final i = find0(c, 'Birinci madde');
          c.select(DocPos(i, 3), DocPos(i, 3));
          c.attach();
          await t.pump();
        }));
    testWidgets('Aa yazı $b', (t) => shot(t, 'aa_yazi', brightness: b,
        after: (t, c) async {
          final i = find0(c, 'Bu belge');
          c.select(DocPos(i, 0), DocPos(i, 4));
          c.setColor(0xFFC00000);
          await panel(t, 'Yazı');
        }));
  }
  testWidgets('stil galerisi', (t) => shot(t, 'stil_galerisi',
      after: (t, c) async {
        c.select(DocPos(find0(c, 'Giriş'), 0), DocPos(find0(c, 'Giriş'), 0));
        await t.pump();
        await t.scrollUntilVisible(
            find.byKey(const ValueKey('word-style-heading 2')), 120,
            scrollable: find
                .ancestor(
                    of: find.byKey(const ValueKey('word-style-Normal')),
                    matching: find.byType(Scrollable))
                .first);
        await t.pump();
      }));
  testWidgets('Aa paragraf', (t) => shot(t, 'aa_paragraf',
      after: (t, c) async {
        final i = find0(c, 'Ortalanmış');
        c.select(DocPos(i, 0), DocPos(i, 0));
        await panel(t, 'Paragraf');
      }));
  testWidgets('Aa stiller', (t) => shot(t, 'aa_stiller',
      after: (t, c) async {
        final i = find0(c, 'Giriş');
        c.select(DocPos(i, 0), DocPos(i, 0));
        await panel(t, 'Stiller');
      }));
  testWidgets('arapça', (t) => shot(t, 'arapca', locale: 'ar', file: arPath,
      after: (t, c) async {
        final i = c.paras.indexWhere((p) => p.look.bidi);
        c.select(DocPos(i < 0 ? 0 : i, 0), DocPos(i < 0 ? 0 : i, 0));
        await t.pump();
      }));
}

// ignore_for_file: invalid_use_of_visible_for_testing_member
// Faz 28 tasarım görüntüleri — slaytta yerinde metin düzenleme:
//
//   flutter test tool/design_shots_faz28_test.dart
//   SHOT_LOCALE=ar flutter test tool/design_shots_faz28_test.dart
//
// → docs/design/faz28/*.png (şekil seçimi + bağlam çubuğu, boş yer tutucu
// istemi, kutuya yakınlaşmış editör + klavye üstü çubuk, Aa paneli, şerit,
// anahat; açık/koyu). Gerçek [SlidesEditorScreen] çizilir. Normal test
// takımında KOŞMAZ. Yöntem `tool/design_shots_faz25_test.dart` ile aynı.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/editors/slides_editor_screen.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:dosya_okuyucu/widgets/slide_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

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

/// İki slayt; ikincinin gövde yer tutucusu boş (istem görünsün).
Uint8List _deck() {
  final raw = PptxWriter.build(const [
    SlideDraft('2026 Yol Haritası', [
      'Mobil uygulamada yeni düzenleyici',
      'Yazı kutusuna yakınlaşarak rahat yazma',
      'Seçime göre kalın, renk, punto',
    ]),
    SlideDraft('Sonraki adımlar', ['x']),
  ]);
  final arc = ZipDecoder().decodeBytes(raw);
  final out = Archive();
  for (final f in arc.files) {
    if (f.name == 'ppt/slides/slide2.xml') {
      final doc = XmlDocument.parse(utf8.decode(f.content as List<int>));
      for (final sp in doc.findAllElements('p:sp').toList()) {
        if (sp.findAllElements('p:ph').first.getAttribute('type') == 'body') {
          sp.children.remove(sp.findElements('p:txBody').first);
        }
      }
      final data = utf8.encode(doc.toXmlString());
      out.addFile(ArchiveFile(f.name, data.length, data));
    } else {
      out.addFile(f);
    }
  }
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

void main() {
  const out = 'docs/design/faz28';
  final locale = Locale(Platform.environment['SHOT_LOCALE'] ?? 'tr');
  final suffixLocale =
      locale.languageCode == 'tr' ? '' : '_${locale.languageCode}';
  late String path;

  setUpAll(() async {
    final sdk = Platform.environment['FLUTTER_ROOT'] ?? '/opt/flutter-sdk/flutter';
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
    SlidesEditorScreen.parseInIsolate = false;
    EditPrefs.autoSave = false;
    final dir = Directory.systemTemp.createTempSync('faz28_shots');
    path = '${dir.path}/yol_haritasi.pptx';
    File(path).writeAsBytesSync(_deck());
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 120)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 400));
  }

  Future<void> tapText(WidgetTester t, String s) async {
    await t.tap(find.text(s).first, warnIfMissed: false);
    await t.pump(const Duration(milliseconds: 50));
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
        home: SlidesEditorScreen(
            path: path, name: 'yol_haritasi.pptx', plainText: ''),
      ),
    ));
    await tester.pump();
    // Dosya okuma gerçek G/Ç: deste çizilene dek bekle.
    for (var i = 0; i < 30 && find.byType(SlideCanvas).evaluate().isEmpty; i++) {
      await settle(tester);
    }
    await settle(tester);
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
    testWidgets('seçim $b', (t) => shot(t, 'secim', brightness: b,
        after: (t) => tapText(t, 'Yazı kutusuna yakınlaşarak rahat yazma')));
    testWidgets('yer tutucu $b', (t) => shot(t, 'bos_yer_tutucu', brightness: b,
        after: (t) async {
          await t.scrollUntilVisible(find.text('Metin eklemek için dokunun'), 300,
              scrollable: find
                  .byWidgetPredicate((w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.down)
                  .first);
        }));
    testWidgets('düzenleme $b', (t) => shot(t, 'duzenleme', brightness: b,
        keyboard: true, after: (t) async {
          const s = 'Yazı kutusuna yakınlaşarak rahat yazma';
          await tapText(t, s);
          await tapText(t, s);
          final ed = t.widget<EditableText>(find.byType(EditableText).last);
          ed.controller.selection =
              const TextSelection(baseOffset: 0, extentOffset: 34);
          await t.pump();
          await t.tap(find.byKey(const ValueKey('sl-acc-bold')));
          await t.pump();
        }));
    testWidgets('şerit $b', (t) => shot(t, 'serit', brightness: b,
        after: (t) async {
          await tapText(t, '2026 Yol Haritası');
          await tapText(t, '2026 Yol Haritası');
        }));
    testWidgets('anahat $b', (t) => shot(t, 'anahat', brightness: b,
        after: (t) async {
          await t.tap(find.byKey(const ValueKey('sl-outline')));
          await settle(t);
        }));
  }
}

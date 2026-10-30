import 'dart:io';
import 'dart:ui' show Tristate;

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:dosya_okuyucu/widgets/office_ribbon.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';
import 'support/xlsx_fixture.dart';

/// Faz 33 / madde 3–4 — editörlerde erişilebilirlik ve RTL:
/// * Excel hücresi TalkBack'te "adres, değer" okunur; imleç "seçili";
/// * şeritteki aç/kapa düğmeleri durumlarını bildirir ("Kalın, açık");
/// * her dokunulabilir öğenin adı var (`labeledTapTargetGuideline`);
/// * Arapça (RTL) ve 2,0× yazıda Word ve Excel taşma hatası vermeden açılır.
void main() {
  late Directory dir;

  setUp(() async {
    SpreadsheetEditorScreen.parseInIsolate = false;
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('editor_a11y');
    await File('${dir.path}/t.xlsx')
        .writeAsBytes(xlsxFrom({'A1': 11, 'B2': 'Armut'}));
    await File('${dir.path}/r.docx').writeAsBytes(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
  });

  tearDown(() {
    SpreadsheetEditorScreen.parseInIsolate = true;
    WordMobileEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Widget app(Widget home, {Locale locale = const Locale('tr'), double scale = 1}) =>
      MaterialApp(
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: locale,
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: home,
      );

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<void> phone(WidgetTester t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
  }

  Widget excel() => SpreadsheetEditorScreen(
      path: '${dir.path}/t.xlsx', name: 't.xlsx', plainText: '');
  Widget word() =>
      WordMobileEditorScreen(path: '${dir.path}/r.docx', name: 'r.docx');

  testWidgets('Excel hücresi TalkBack: adres + değer, imleç seçili',
      (t) async {
    final handle = t.ensureSemantics();
    await phone(t);
    await t.pumpWidget(app(excel()));
    await settle(t);
    expect(find.bySemanticsLabel('B2, Armut'), findsOneWidget);
    final a1 = t.getSemantics(find.bySemanticsLabel('A1, 11'));
    expect(a1.flagsCollection.isSelected, Tristate.isTrue);
    await expectLater(t, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  testWidgets('şeritte aç/kapa düğmesi durumunu bildirir', (t) async {
    final handle = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Row(children: [
          RibbonButton(Icons.format_bold, 'Kalın', active: true, onTap: () {}),
          RibbonButton(Icons.format_italic, 'İtalik', active: false, onTap: () {}),
          RibbonButton(Icons.save, 'Kaydet', onTap: () {}),
        ]),
      ),
    ));
    SemanticsNode node(String label) => t.getSemantics(find.bySemanticsLabel(label));
    expect(node('Kalın').flagsCollection.isToggled, Tristate.isTrue);
    expect(node('İtalik').flagsCollection.isToggled, Tristate.isFalse);
    expect(node('Kaydet').flagsCollection.isToggled, Tristate.none,
        reason: 'düz eylem "kapalı" diye okunmamalı');
    handle.dispose();
  });

  for (final (name, locale, scale) in [
    ('Arapça', const Locale('ar'), 1.0),
    ('2,0× yazı', const Locale('tr'), 2.0),
  ]) {
    testWidgets('Excel $name: taşmadan açılır', (t) async {
      await phone(t);
      await t.pumpWidget(app(excel(), locale: locale, scale: scale));
      await settle(t);
      expect(t.takeException(), isNull);
      expect(find.byType(SpreadsheetEditorScreen), findsOneWidget);
    });

    testWidgets('Word $name: taşmadan açılır, yazılabilir', (t) async {
      await phone(t);
      await t.pumpWidget(app(word(), locale: locale, scale: scale));
      for (var i = 0;
          i < 20 && find.byType(DocxEditorView).evaluate().isEmpty;
          i++) {
        await settle(t);
      }
      expect(find.byType(DocxEditorView), findsOneWidget);
      expect(t.takeException(), isNull);
    });
  }
}

import 'dart:io';

import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// Faz 23 — Word Mobil görünüm: Giriş şeridi ↔ klavye üstü çubuk, Aa paneli
/// (Yazı · Paragraf · Stiller), biçim boyacısı, gezinti, 2,0× yazı ölçeği.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

const _dpr = 2.75;
const _keyboard = 300.0;
const _ribbonTabs = ['Giriş', 'Görünüm', 'Gözden Geçir'];
const _panelTabs = ['Yazı', 'Paragraf', 'Stiller'];

void main() {
  late Directory dir;
  late String path;

  setUp(() async {
    WordMobileEditorScreen.parseInIsolate = false;
    SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
    EditPrefs.autoSave = false;
    dir = await Directory.systemTemp.createTemp('word_format');
    path = '${dir.path}/rapor.docx';
    await File(path).writeAsBytes(
        File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());
  });

  tearDown(() {
    WordMobileEditorScreen.parseInIsolate = true;
    EditPrefs.autoSave = true;
    removeTempDir(dir);
  });

  Future<void> settle(WidgetTester t) async {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 80)));
    await t.pump();
    await t.pump(const Duration(milliseconds: 100));
  }

  Future<DocxEditController> open(WidgetTester t, {double textScale = 1}) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = _dpr;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: _delegates,
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: WordMobileEditorScreen(path: path, name: 'rapor.docx'),
    ));
    for (var i = 0; i < 20 && find.byType(DocxEditorView).evaluate().isEmpty; i++) {
      await settle(t);
    }
    await settle(t);
    return t.widget<DocxEditorView>(find.byType(DocxEditorView)).controller;
  }

  Future<void> keyboard(WidgetTester t, bool up) async {
    t.view.viewInsets =
        up ? const FakeViewPadding(bottom: _keyboard * _dpr) : FakeViewPadding.zero;
    await t.pump();
    await t.pump();
  }

  /// Yatay kayan sekme sırasında [label]'a dokunur (2,0× yazıda ekran
  /// dışında kalabilir — önce kaydırılır).
  Future<void> tapIn(WidgetTester t, List<String> labels, String label) async {
    if (find.text(label).evaluate().isEmpty) {
      final seen = labels.firstWhere((l) => find.text(l).evaluate().isNotEmpty);
      final sc = find
          .ancestor(of: find.text(seen).last, matching: find.byType(Scrollable))
          .first;
      final forward = labels.indexOf(label) > labels.indexOf(seen);
      await t.scrollUntilVisible(find.text(label), forward ? 60 : -60,
          scrollable: sc);
    }
    await t.ensureVisible(find.text(label).last);
    await t.pump();
    await t.tap(find.text(label).last);
  }

  int find0(DocxEditController c, String s) =>
      c.paras.indexWhere((p) => p.text.startsWith(s));

  testWidgets('klavye kapalı: Giriş şeridi + stil galerisi; açık: hızlı çubuk',
      (t) async {
    final c = await open(t);
    expect(find.byKey(const ValueKey('word-style-heading 1')), findsOneWidget);
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsNothing);
    expect(find.byKey(const ValueKey('word-size')), findsOneWidget);

    await keyboard(t, true);
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsOneWidget);
    expect(find.byKey(const ValueKey('word-style-heading 1')), findsNothing);

    // Hızlı çubuk seçime uygular ve durumu yansıtır.
    final i = find0(c, 'Ortalanmış');
    c.select(DocPos(i, 0), DocPos(i, 5));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('word-acc-bold')));
    await t.pump();
    expect(c.isBold, isTrue);
    await t.tap(find.byKey(const ValueKey('word-acc-bullets')));
    await t.pump();
    expect(c.listKind, 'bullet');
    final before = c.paraLook.align;
    await t.scrollUntilVisible(find.byKey(const ValueKey('word-acc-align')), 80,
        scrollable: find
            .descendant(
                of: find.byKey(const ValueKey('keyboard-accessory')),
                matching: find.byType(Scrollable))
            .first);
    await t.tap(find.byKey(const ValueKey('word-acc-align')));
    await t.pump();
    expect(c.paraLook.align, isNot(before));
    await keyboard(t, false);
    expect(find.byKey(const ValueKey('keyboard-accessory')), findsNothing);
  });

  testWidgets('Aa paneli klavyenin yerinde açılır, belge alanı kıpırdamaz',
      (t) async {
    final c = await open(t);
    final i = find0(c, 'Ortalanmış');
    c.select(DocPos(i, 0), DocPos(i, 5));
    await keyboard(t, true);
    final docH = t.getSize(find.byType(DocxEditorView)).height;
    await t.tap(find.byKey(const ValueKey('accessory-format')));
    await keyboard(t, false); // panel açılınca klavye iner
    expect(find.byKey(const ValueKey('format-panel')), findsOneWidget);
    expect(t.getSize(find.byType(DocxEditorView)).height, closeTo(docH, 1));

    // Yazı sekmesi: punto + yansıtma.
    await t.tap(find.byTooltip('Yazı tipini büyüt').last);
    await t.pump();
    final size = c.fontSize!;
    expect(t.widget<Text>(find.byKey(const ValueKey('word-panel-size'))).data,
        size.round().toString());

    // Stiller sekmesi: Başlık 2 uygula.
    await tapIn(t, _panelTabs, 'Stiller');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('word-panel-style-heading 2')));
    await t.pump();
    expect(c.paraLook.headingLevel, 2);

    // Paragraf sekmesi: satır aralığı.
    await tapIn(t, _panelTabs, 'Paragraf');
    await t.pump();
    await t.tap(find.text('1,5').evaluate().isEmpty ? find.text('1.5') : find.text('1,5'));
    await t.pump();
    expect(c.paraLook.lineMultiple, 1.5);

    // ⌨ ile panel kapanır.
    await t.tap(find.byKey(const ValueKey('format-panel-keyboard')));
    await t.pump();
    expect(find.byKey(const ValueKey('format-panel')), findsNothing);
  });

  testWidgets('biçim boyacısı: şerit görünür, kilitliyse ✕ ile biter',
      (t) async {
    final c = await open(t);
    final i = find0(c, 'Bu belge');
    final k = c.paras[i].text.indexOf('kalın');
    c.select(DocPos(i, k), DocPos(i, k + 5));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('word-painter')).first);
    await t.pump(const Duration(milliseconds: 400));
    expect(c.painterActive, isTrue);
    expect(find.byKey(const ValueKey('word-painter-banner')), findsOneWidget);
    c.select(DocPos(i, 0), DocPos(i, 2));
    c.selectionFinished();
    await t.pump();
    expect(c.paras[i].styles[0].effective.bold, isTrue);
    expect(find.byKey(const ValueKey('word-painter-banner')), findsNothing);

    // Çift dokunuş: kilitli.
    await t.tap(find.byKey(const ValueKey('word-painter')).first);
    await t.pump(const Duration(milliseconds: 50));
    await t.tap(find.byKey(const ValueKey('word-painter')).first);
    await t.pump(const Duration(milliseconds: 400));
    expect(c.painterLocked, isTrue);
    await t.tap(find.descendant(
        of: find.byKey(const ValueKey('word-painter-banner')),
        matching: find.byType(IconButton)));
    await t.pump();
    expect(c.painterActive, isFalse);
  });

  testWidgets('Görünüm > Gezinti başlığa atlar; Gözden Geçir > sözcük sayısı',
      (t) async {
    final c = await open(t);
    await tapIn(t, _ribbonTabs, 'Görünüm');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('word-nav')));
    await t.pumpAndSettle();
    final hs = c.headings();
    expect(hs, isNotEmpty);
    final (target, _, title) = hs.last;
    await t.tap(find.byKey(ValueKey('word-nav-$target')));
    await t.pumpAndSettle();
    expect(c.extent.para, target);
    expect(find.textContaining(title, findRichText: true), findsWidgets);

    await tapIn(t, _ribbonTabs, 'Gözden Geçir');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('word-count')));
    await t.pumpAndSettle();
    expect(find.text('${c.counts().words}'), findsOneWidget);
  });

  testWidgets('2,0× yazı ölçeğinde şerit ve panel taşmaz', (t) async {
    final c = await open(t, textScale: 2.0);
    expect(t.takeException(), isNull);
    for (final tab in ['Görünüm', 'Gözden Geçir', 'Giriş']) {
      await tapIn(t, _ribbonTabs, tab);
      await t.pump();
      expect(t.takeException(), isNull, reason: tab);
    }
    final i = find0(c, 'Ortalanmış');
    c.select(DocPos(i, 0), DocPos(i, 0));
    await keyboard(t, true);
    expect(t.takeException(), isNull);
    await t.tap(find.byKey(const ValueKey('accessory-format')));
    await keyboard(t, false);
    for (final tab in ['Paragraf', 'Stiller', 'Yazı']) {
      await tapIn(t, _panelTabs, tab);
      await t.pump();
      expect(t.takeException(), isNull, reason: tab);
    }
  });
}

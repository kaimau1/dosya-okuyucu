import 'dart:io';

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/edit/edit_session.dart';
import 'package:dosya_okuyucu/core/edit/save_coordinator.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/models/document.dart';
import 'package:dosya_okuyucu/screens/editors/spreadsheet_editor_screen.dart';
import 'package:dosya_okuyucu/screens/editors/word_mobile_editor_screen.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:dosya_okuyucu/widgets/office_ribbon.dart';
import 'package:dosya_okuyucu/widgets/office_shell.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_bars.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _app(Widget home) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: _delegates,
      home: home,
    );

void main() {
  testWidgets('OfficeShell hideKindPrefix ve hideBottomBar beklendiği gibi çalışır',
      (tester) async {
    await tester.pumpWidget(_app(const OfficeShell(
      kind: DocKind.pdf,
      title: '19.11.2026.pdf',
      subtitle: 'Düzenleniyor',
      hideKindPrefix: true,
      hideBottomBar: true,
      body: SizedBox.expand(),
      bottomBar: SizedBox(height: 56, child: Text('Alt Çubuk')),
    )));
    expect(find.text('Düzenleniyor'), findsOneWidget);
    expect(find.textContaining('PDF ·'), findsNothing);
    expect(find.text('Alt Çubuk'), findsNothing);
  });

  test('PdfProBlockLayer tutamaçları küçük blok metninin dışında kalır', () {
    const page = Size(360, 640);
    // "BASO%" benzeri küçük tablo hücresi
    const baso = Rect.fromLTWH(80, 120, 48, 16);
    final move = PdfProBlockLayer.blockMoveAnchor(baso, page);
    final width = PdfProBlockLayer.blockWidthAnchor(baso, page);
    expect(move.dy, lessThan(baso.top));
    expect(width.dx, greaterThan(baso.right));
    expect(baso.contains(move), isFalse);
    expect(baso.contains(width), isFalse);

    // Üst kenara yapışık blokta taşıma tutamacı alta geçer.
    const topBlock = Rect.fromLTWH(80, 10, 48, 16);
    final flipped = PdfProBlockLayer.blockMoveAnchor(topBlock, page);
    expect(flipped.dy, greaterThan(topBlock.bottom));
  });

  testWidgets('PdfProContextBar primary ve swatch yongalarını çizer',
      (tester) async {
    var tapped = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: PdfProContextBar(
        label: 'Bağlam',
        chips: [
          PdfProChip(AppIcons.edit, 'Metni düzenle', () => tapped++,
              primary: true, tapKey: const ValueKey('primary-chip')),
          PdfProChip(AppIcons.lineWeight, 'Renk ve kalınlık', () => tapped += 10,
              swatch: const Color(0xFFD32F2F),
              tapKey: const ValueKey('swatch-chip')),
        ],
      ),
    )));
    await tester.tap(find.byKey(const ValueKey('primary-chip')));
    await tester.tap(find.byKey(const ValueKey('swatch-chip')));
    expect(tapped, 11);
  });

  testWidgets('showPdfBlockStyleSheet ve showPdfStrokeSheet eylemleri tetikler',
      (tester) async {
    final block = groupTextBlocks([
      const PdfTextObjectInfo(
        index: 0,
        text: 'BASO%',
        left: 10,
        bottom: 100,
        right: 60,
        top: 112,
        tfSize: 12,
        fontName: 'Helvetica',
        matrix: [1, 0, 0, 1, 10, 100],
        renderMode: 0,
      ),
    ]).first;

    String? pickedAction;
    int? pickedColor;
    double? pickedWidth;

    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Column(
          children: [
            TextButton(
              onPressed: () => showPdfBlockStyleSheet(
                context,
                block: block,
                hasStyleClip: false,
                onAction: (a) => pickedAction = a,
              ),
              child: const Text('style'),
            ),
            TextButton(
              onPressed: () => showPdfStrokeSheet(
                context,
                color: 0xFFD32F2F,
                width: 2.5,
                onColor: (c) => pickedColor = c,
                onWidth: (w) => pickedWidth = w,
              ),
              child: const Text('stroke'),
            ),
          ],
        ),
      ),
    )));

    await tester.tap(find.text('style'));
    await tester.pumpAndSettle();
    expect(find.text('12 pt'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('pse-sheet-bigger')));
    await tester.pumpAndSettle();
    expect(pickedAction, 'bigger');

    await tester.tap(find.text('stroke'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('#1565c0'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('pse-stroke-4.0')));
    await tester.pump();
    expect(pickedColor, 0xFF1565C0);
    expect(pickedWidth, 4.0);
  });

  group('Word ve Excel UX düzenlemeleri', () {
    late Directory dir;

    setUp(() async {
      WordMobileEditorScreen.parseInIsolate = false;
      SpreadsheetEditorScreen.parseInIsolate = false;
      SaveIsolate.runner = <M, R>(cb, m) async => cb(m);
      EditPrefs.autoSave = false;
      dir = await Directory.systemTemp.createTemp('editors_ux');
    });

    tearDown(() {
      WordMobileEditorScreen.parseInIsolate = true;
      SpreadsheetEditorScreen.parseInIsolate = true;
      EditPrefs.autoSave = true;
      removeTempDir(dir);
    });

    testWidgets('Word Mobil: üst Bul, sözcük sayacı ve renk seçici levhası',
        (tester) async {
      final path = '${dir.path}/doc.docx';
      await File(path).writeAsBytes(
          File('test/fixtures/office/stiller_basliklar.docx').readAsBytesSync());

      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(WordMobileEditorScreen(
        path: path,
        name: 'doc.docx',
      )));
      for (var i = 0;
          i < 20 && find.byType(DocxEditorView).evaluate().isEmpty;
          i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();

      // Canlı sözcük sayısı alt başlıkta, tür öneki ("Word ·") gizli.
      expect(find.textContaining('sözcük'), findsOneWidget);
      expect(find.textContaining('Word ·'), findsNothing);

      // Üst çubuktan Bul açılır/kapanır.
      await tester.tap(find.byKey(const ValueKey('word-top-find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-find-bar')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('word-top-find')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('word-find-bar')), findsNothing);

      // Görsel renk levhası açılır, ham hex kodu metin olarak gösterilmez.
      await tester.ensureVisible(find.byKey(const ValueKey('word-color')));
      await tester.tap(find.byKey(const ValueKey('word-color')));
      await tester.pumpAndSettle();
      expect(find.text('Yazı rengi'), findsOneWidget);
      expect(find.text('#C00000'), findsNothing);
    });

    testWidgets('Excel: alt çizgi, fx çubuğu, hücre menüsü ve Formüller yongaları',
        (tester) async {
      final path = '${dir.path}/sheet.xlsx';
      await File(path).writeAsBytes(
          File('test/fixtures/rich_sheet.xlsx').readAsBytesSync());

      await tester.pumpWidget(_app(SpreadsheetEditorScreen(
        path: path,
        name: 'sheet.xlsx',
        plainText: '',
      )));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      expect(find.byKey(const ValueKey('xl-underline')), findsOneWidget);
      expect(find.byKey(const ValueKey('xl-bar-fx')), findsOneWidget);
      expect(find.byKey(const ValueKey('xl-status-menu')), findsOneWidget);

      // Alt çizgi düğmesi etkinleşir ve biçimi uygular.
      await tester.tap(find.byKey(const ValueKey('xl-underline')));
      await tester.pump();
      expect(
        tester
            .widget<RibbonButton>(find.byKey(const ValueKey('xl-underline')))
            .active,
        isTrue,
      );

      // Durum çubuğundan hücre menüsü açılır.
      await tester.tap(find.byKey(const ValueKey('xl-status-menu')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cellmenu-copy')), findsOneWidget);
      Navigator.of(tester.element(find.byKey(const ValueKey('cellmenu-copy'))))
          .pop();
      await tester.pumpAndSettle();

      // Formüller sekmesinde etiketli RibbonChip yongaları görünür.
      await tester.tap(find.descendant(
          of: find.byType(OfficeRibbon), matching: find.text('Formüller')));
      await tester.pumpAndSettle();
      for (final key in const [
        'xl-fn-SUM',
        'xl-fn-AVERAGE',
        'xl-fn-COUNT',
        'xl-fn-MAX',
        'xl-fn-MIN',
        'xl-fx-lib',
      ]) {
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      }
    });
  });
}

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_text_blocks.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/widgets/doc_action_bar.dart';
import 'package:dosya_okuyucu/widgets/menu_kit.dart';
import 'package:dosya_okuyucu/widgets/pdf_page_navigator.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_panels.dart';
import 'package:dosya_okuyucu/widgets/slide_frame_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

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
  testWidgets('DocActionBar primary CTA ve normal eylemleri birlikte çizer',
      (tester) async {
    var edited = 0;
    var shared = 0;
    await tester.pumpWidget(_app(Scaffold(
      bottomNavigationBar: DocActionBar([
        DocAction(AppIcons.edit, 'Düzenle', () => edited++, primary: true),
        DocAction(AppIcons.share, 'Paylaş', () => shared++),
      ]),
    )));
    await tester.tap(find.text('Düzenle'));
    await tester.tap(find.text('Paylaş'));
    expect(edited, 1);
    expect(shared, 1);
  });

  testWidgets('MenuSearchField canlı sonuç sayısı rozetini gösterir',
      (tester) async {
    final ctrl = TextEditingController(text: 'pdf');
    addTearDown(ctrl.dispose);
    await tester.pumpWidget(_app(Scaffold(
      body: MenuSearchField(
        controller: ctrl,
        hitCount: 4,
        onChanged: (_) {},
      ),
    )));
    expect(find.text('4 sonuç'), findsOneWidget);
  });

  testWidgets('PdfPageChip tek dokunuşla önceki/sonraki sayfa adımını çalıştırır',
      (tester) async {
    var prevs = 0;
    var nexts = 0;
    var opened = 0;
    await tester.pumpWidget(_app(Scaffold(
      body: Center(
        child: PdfPageChip(
          page: 5,
          count: 20,
          onTap: () => opened++,
          onPrev: () => prevs++,
          onNext: () => nexts++,
        ),
      ),
    )));
    await tester.tap(find.byTooltip('Önceki sayfa'));
    await tester.tap(find.byTooltip('Sonraki sayfa'));
    await tester.tap(find.byKey(const ValueKey('pdf-page-chip')));
    expect([prevs, nexts, opened], [1, 1, 1]);
  });

  testWidgets('PdfPageNavigator yüzde kısayollarıyla ilgili sayfaya atlar',
      (tester) async {
    int? chosen;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              chosen = await PdfPageNavigator.show(
                context,
                document: null,
                current: 1,
                count: 100,
                bookmarks: const [],
                onToggleBookmark: (_) async => true,
              );
            },
            child: const Text('aç'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('%50'), findsOneWidget);
    await tester.ensureVisible(find.text('%50'));
    await tester.tap(find.text('%50'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(const ValueKey('pn-field')));
    expect(field.controller?.text, '50');
    await tester.ensureVisible(find.byKey(const ValueKey('pn-go')));
    await tester.tap(find.byKey(const ValueKey('pn-go')));
    await tester.pumpAndSettle();
    expect(chosen, 50);
  });

  testWidgets('showPdfImageSizeSheet hazır boyutları ve ölçek döndürmeyi uygular',
      (tester) async {
    const item = PdfPageItem(
      index: 0,
      type: 3,
      left: 50,
      bottom: 100,
      right: 250,
      top: 250,
      pixelWidth: 400,
      pixelHeight: 300,
    );
    double? chosenScale;
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () async {
              chosenScale = await showPdfImageSizeSheet(
                context,
                item: item,
                pageWidth: 595,
                pageHeight: 842,
              );
            },
            child: const Text('boyut'),
          ),
        ),
      ),
    )));
    await tester.tap(find.text('boyut'));
    await tester.pumpAndSettle();

    expect(find.text('Ölçek: %100'), findsOneWidget);
    expect(find.text('200 × 150 pt'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pse-size-large')));
    await tester.pump();
    expect(find.text('Ölçek: %140'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('pse-resize-apply')));
    await tester.pumpAndSettle();
    expect(chosenScale, closeTo(1.4, 0.01));
  });

  testWidgets('SlideFrameEditor tutamakları ve döndürme düğmesi taşmadan çizilir',
      (tester) async {
    const shape = ShapeVM(
      id: 1,
      x: 40,
      y: 40,
      w: 180,
      h: 90,
      paragraphs: [],
    );
    Rect? committed;
    await tester.pumpWidget(_app(Scaffold(
      body: SizedBox(
        width: 400,
        height: 300,
        child: Stack(
          children: [
            SlideFrameEditor(
              shape: shape,
              unit: 1.0,
              slideW: 400,
              slideH: 300,
              onCommit: (r, _) => committed = r,
              child: const SizedBox.expand(),
            ),
          ],
        ),
      ),
    )));
    expect(find.byIcon(AppIcons.rotateRight), findsOneWidget);
    expect(committed, isNull);
    expect(tester.takeException(), isNull);
  });
}

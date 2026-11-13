// PDF Pro Faz 57: sayfa katmanı + biçim çubuğu + gizli giriş — gerçek PDFium
// ile uçtan uca (dokun → seç → yaz → biçimle → uygula). CI: PDFIUM_PATH.
import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_bars.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

const _labels = PdfProFormatLabels(
  done: 'Bitti',
  cancel: 'Vazgeç',
  bold: 'Kalın',
  italic: 'İtalik',
  underline: 'Altı çizili',
  strike: 'Üstü çizili',
  color: 'Renk',
  highlight: 'Vurgu',
  align: 'Hizalama',
  smaller: 'Küçült',
  larger: 'Büyüt',
  selectAll: 'Tümünü seç',
  copy: 'Kopyala',
  cut: 'Kes',
  paste: 'Yapıştır',
  docFont: 'belge',
  fallbackFont: 'yedek',
  glyphError: 'glif yok',
  error: 'yazılamadı',
  size: 'Punto',
);

void main() {
  late Directory tmp;

  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_layer_test');
    PdfVersionHistory.rootOverride = p.join(tmp.path, 'gecmis');
    PdfEditRecovery.rootOverride = p.join(tmp.path, 'kurtarma');
    PdfEditRecovery.debugForgetLive();
  });

  tearDown(() {
    PdfVersionHistory.rootOverride = null;
    PdfEditRecovery.rootOverride = null;
    PdfEditRecovery.debugForgetLive();
    tmp.deleteSync(recursive: true);
  });

  testWidgets('dokun → seç → dokun → yaz → kalın → Bitti: tek adım',
      (tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final path = p.join(tmp.path, 'belge.pdf');
    late PdfDocument doc;
    late PdfProEditController c;
    late List<PdfTextBlock> blocks;
    await tester.runAsync(() async {
      File(path).writeAsBytesSync(
          File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync());
      doc = await PdfDocument.openFile(path);
      c = PdfProEditController(
          document: doc, path: path, snapshotEvery: const Duration(hours: 1));
      for (var i = 0; i < 200 && c.blocksOf(0) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      blocks = c.blocksOf(0)!;
    });
    addTearDown(() async {
      var closed = false;
      c.close().then((_) => doc.dispose()).then((_) => closed = true);
      for (var i = 0; i < 400 && !closed; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump();
      }
    });

    final page = doc.pages[0];
    final size = Size(page.width, page.height);
    final edits = <(int, PdfTextBlock, int?)>[];
    final input = TextEditingController();
    final focus = FocusNode();
    addTearDown(input.dispose);
    addTearDown(focus.dispose);
    var committed = 0;

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: ListenableBuilder(
          listenable: c,
          builder: (context, _) => Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: PdfProBlockLayer(
                  key: const ValueKey('katman'),
                  page: page,
                  pageSize: size,
                  controller: c,
                  events: PdfProLayerEvents(
                    onEdit: (pi, b, {offset, selection}) =>
                        edits.add((pi, b, offset)),
                    onLocked: (_, _) {},
                    onBlockMenu: (_, _) {},
                    onCommit: () => committed++,
                    onRefused: (e) => fail('reddedildi: $e'),
                    onNote: (_, _, _) {},
                    onAnnotTap: (_, _) {},
                    onTextBox: (_, _, _) {},
                  ),
                ),
              ),
              if (c.live != null) ...[
                Positioned(
                  left: 0,
                  top: 0,
                  child: PdfProTextInput(
                    controller: c,
                    input: input,
                    focusNode: focus,
                    onEscape: () {},
                    onUndo: () {},
                    onRedo: () {},
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: PdfProFormatBar(
                    controller: c,
                    labels: _labels,
                    input: input,
                    onDone: () {},
                    onCancel: () {},
                    onPickColor: () {},
                    onPickHighlight: () {},
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    ));

    // Paragrafın ortasına dokun: seçilir.
    final bi = blocks.indexWhere((b) => b.lines.length >= 3);
    final b = blocks[bi];
    final at = Offset((b.left + b.right) / 2, page.height - (b.top + b.bottom) / 2);
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.selectedBlock, bi);
    expect(edits, isEmpty);

    // Seçili bloğa yeniden dokun: yazma, imleç dokunulan harfte.
    await tester.tapAt(at);
    await tester.pump(const Duration(milliseconds: 400));
    expect(edits, hasLength(1));
    expect(edits.single.$3, inInclusiveRange(1, b.map.length - 1));

    // PDFium yanıtı gerçek zamanda gelir, devamı sahte zaman bölgesinde koşar:
    // ikisi dönüşümlü pompalanır.
    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 400 && !done(); i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump();
      }
      expect(done(), isTrue, reason: 'işlem zamanında bitmedi');
    }

    var began = false;
    c.beginEdit(0, b, offset: edits.single.$3).then((v) => began = v);
    await until(() => began);
    await tester.pump();
    expect(find.byType(PdfProFormatBar), findsOneWidget);
    expect(find.byKey(const ValueKey('pse-input')), findsOneWidget);
    expect(input.text, b.map.text, reason: 'gizli alan blok metniyle dolar');
    expect(find.text('belge'), findsOneWidget, reason: 'gömülü font rozeti');

    // Klavyeden yazı: alan → belge.
    final typed = '${b.map.text} Eklendi';
    input.value = TextEditingValue(
        text: typed, selection: TextSelection.collapsed(offset: typed.length));
    await tester.pump();
    expect(c.live!.text, typed);
    await until(() => c.live?.applied ?? false);
    expect(c.live!.error, isNull);
    expect(c.live!.map.length, typed.runes.length);

    // Sözcük seç + Kalın.
    input.selection = const TextSelection(baseOffset: 0, extentOffset: 4);
    await tester.pump();
    expect(c.live!.selEnd, 4);
    await tester.tap(find.byKey(const ValueKey('pse-bold')));
    await tester.pump();
    expect(c.live!.spans.any((s) => s.bold == true && s.end == 4), isTrue);

    // Bloğun dışına dokunuş = uygula isteği.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 400));
    expect(committed, 1);

    bool? ok;
    c.commitEdit(label: 'pse.step_paragraph').then((v) => ok = v);
    await until(() => ok != null);
    expect(ok, isTrue);
    expect(c.live, isNull);
    expect(c.session.steps, hasLength(1));
    expect(find.byType(PdfProFormatBar), findsNothing);
    String? text;
    doc.pages[0].loadText().then(
        (t) => text = t!.fullText.replaceAll(RegExp(r'\s+'), ''));
    await until(() => text != null);
    expect(text, contains('Eklendi'));
    expect(tester.takeException(), isNull);
  });
}

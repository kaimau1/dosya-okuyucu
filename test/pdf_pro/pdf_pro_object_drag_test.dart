// PDF Pro Faz 59 m.4: taşıma tutamacı + tutunma — gerçek PDFium ile.
// Kasma bekçisi: sürükleme boyunca katman yeniden KURULMAZ (önizleme kendi
// boyayıcısında). CI: PDFIUM_PATH.
import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

void main() {
  late Directory tmp;

  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_drag_test');
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

  testWidgets('blok tutamaçla taşınır; sürüklerken katman yeniden kurulmaz',
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

    Future<void> until(bool Function() done) async {
      for (var i = 0; i < 400 && !done(); i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump();
      }
      expect(done(), isTrue, reason: 'işlem zamanında bitmedi');
    }

    final page = doc.pages[0];
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
        body: Stack(children: [
          Positioned(
            left: 0,
            top: 0,
            child: PdfProBlockLayer(
              page: page,
              pageSize: Size(page.width, page.height),
              controller: c,
              events: PdfProLayerEvents(
                onEdit: (_, _, {offset, selection}) {},
                onLocked: (_, _) {},
                onBlockMenu: (_, _) {},
                onCommit: () {},
                onRefused: (e) => fail('reddedildi: $e'),
                onNote: (_, _, _) {},
                onAnnotTap: (_, _) {},
                onTextBox: (_, _, _) {},
              ),
            ),
          ),
        ]),
      ),
    ));

    final bi = blocks.indexWhere((b) => b.lines.length >= 3 && b.editable);
    final b = blocks[bi];
    // Basılı tut = seç (tek dokunuş doğrudan yazmaya geçer — 2026-11-22).
    await tester.longPressAt(
        Offset((b.left + b.right) / 2, page.height - (b.top + b.bottom) / 2));
    await tester.pump(const Duration(milliseconds: 400));
    expect(c.selectedBlock, bi);

    final grip = find.byKey(const ValueKey('pse-grip-move'));
    expect(grip, findsOneWidget);
    final g = await tester.startGesture(tester.getCenter(grip));
    await g.moveBy(const Offset(0, 30)); // eşik aşılır → taşıma başlar
    await tester.pump();
    final builds = PdfProBlockLayer.debugBuilds;
    for (var i = 0; i < 8; i++) {
      await g.moveBy(const Offset(0, 6));
      await tester.pump();
    }
    expect(PdfProBlockLayer.debugBuilds, builds,
        reason: 'sürüklerken katman yeniden kuruldu (kasma)');
    await g.up();
    await tester.pump();
    await until(() => c.session.steps.length == 1 && !c.busy);
    expect(tester.takeException(), isNull);
  });
}

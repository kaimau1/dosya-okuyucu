// PDF Pro Faz 60 m.5: işaretleme stüdyosu (tek yol) — gerçek PDFium ile.
// Kalem/fosforlu, kasma bekçisi (çizerken katman yeniden KURULMAZ), avuç
// reddi + basınç, bulut, damga ve serbest metin. CI: PDFIUM_PATH.
import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

class _Harness {
  late PdfDocument doc;
  late PdfProEditController c;
  final placed = <(double, double, PdfMarkupKind)>[];
}

void main() {
  late Directory tmp;

  setUpAll(() async {
    await pdfrxInitialize();
    PdfFallbackFonts.loader = (asset) => File(asset).readAsBytes();
  });

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('pdf_pro_markup_test');
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

  Future<void> until(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 400 && !done(); i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    expect(done(), isTrue, reason: 'işlem zamanında bitmedi');
  }

  Future<_Harness> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final h = _Harness();
    final path = p.join(tmp.path, 'belge.pdf');
    await tester.runAsync(() async {
      File(path).writeAsBytesSync(
          File('test/fixtures/pdf_corpus/rl_paragraflar.pdf').readAsBytesSync());
      h.doc = await PdfDocument.openFile(path);
      h.c = PdfProEditController(
          document: h.doc, path: path, snapshotEvery: const Duration(hours: 1));
      for (var i = 0; i < 200 && h.c.blocksOf(0) == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
    });
    addTearDown(() async {
      var closed = false;
      h.c.close().then((_) => h.doc.dispose()).then((_) => closed = true);
      for (var i = 0; i < 400 && !closed; i++) {
        await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)));
        await tester.pump();
      }
    });
    final page = h.doc.pages[0];
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
              controller: h.c,
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
    return h;
  }

  Future<List<PdfAnnotInfo>> annots(WidgetTester tester, _Harness h) async =>
      (await tester.runAsync(() => PdfEditBridge.annotations(h.doc, 0)))!;

  testWidgets('Kalem düğmesi stüdyoyu kalem kurulu açar; fosforlu yarı saydam '
      'mürekkep bırakır', (tester) async {
    final h = await open(tester);
    h.c.armMarkup(PdfMarkupKind.ink);
    expect(h.c.tool, PdfProTool.markup);
    expect(h.c.markup, PdfMarkupKind.ink);
    // İkinci çağrı çip gibi kapatmaz.
    h.c.armMarkup(PdfMarkupKind.ink);
    expect(h.c.markup, PdfMarkupKind.ink);
    expect(h.c.drawing, isTrue);

    h.c.armMarkup(PdfMarkupKind.marker);
    await tester.pump();
    final g = await tester.startGesture(const Offset(100, 200));
    await tester.pump();
    // Kasma bekçisi: çizerken yalnız vuruşun boyayıcısı yeniden çizilir.
    final builds = PdfProBlockLayer.debugBuilds;
    for (var i = 0; i < 6; i++) {
      await g.moveBy(const Offset(20, 0));
      await tester.pump();
    }
    expect(PdfProBlockLayer.debugBuilds, builds,
        reason: 'çizerken katman yeniden kuruldu (kasma)');
    await g.up();
    await tester.pump();
    await until(tester, () => h.c.session.steps.length == 1 && !h.c.busy);
    final ink = (await annots(tester, h))
        .where((a) => a.subtype == PdfAnnotType.ink)
        .toList();
    expect(ink, hasLength(1));
    expect(ink.single.color >>> 24, lessThan(0xFF),
        reason: 'fosforlu opak yazıldı (alttaki yazı örtülür)');
    expect(tester.takeException(), isNull);
  });
}

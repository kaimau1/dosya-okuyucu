// PDF Pro Faz 60 m.5: işaretleme stüdyosu (tek yol) — gerçek PDFium ile.
// Kalem/fosforlu, kasma bekçisi (çizerken katman yeniden KURULMAZ), avuç
// reddi + basınç, bulut, damga ve serbest metin. CI: PDFIUM_PATH.
import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_bridge.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_edit_recovery.dart';
import 'package:dosya_okuyucu/services/pdf/pro/pdf_version_history.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_block_layer.dart';
import 'package:dosya_okuyucu/widgets/pdf_pro/pdf_pro_edit_controller.dart';
import 'package:flutter/gestures.dart' show PointerDeviceKind;
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
                onPlace: (_, x, y, k) => h.placed.add((x, y, k)),
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

  test('bulut yolu: kapalı, kenarda yaylar, dikdörtgenin içine girmez', () {
    final pts = pdfCloudPath(100, 100, 300, 180);
    expect(pts.length.isEven, isTrue);
    // Kısa kenar 80 → çap 20: alt/üst 10, yanlar 4 yay; yay başına 6 nokta.
    expect(pts.length ~/ 2, 1 + (10 + 4 + 10 + 4) * 6);
    expect(pts[pts.length - 2], closeTo(100, 1e-6));
    expect(pts.last, closeTo(100, 1e-6));
    for (var i = 0; i < pts.length; i += 2) {
      final x = pts[i], y = pts[i + 1];
      final inside = x > 100 + 1e-6 && x < 300 - 1e-6 && y > 100 + 1e-6 &&
          y < 180 - 1e-6;
      expect(inside, isFalse, reason: 'yay içe dönmüş: ($x, $y)');
      expect(x, inInclusiveRange(89, 311));
      expect(y, inInclusiveRange(89, 191));
    }
  });

  testWidgets('bulut sürüklemesi tek mürekkep açıklaması bırakır',
      (tester) async {
    final h = await open(tester);
    h.c.armMarkup(PdfMarkupKind.cloud);
    await tester.pump();
    final g = await tester.startGesture(const Offset(100, 200));
    await g.moveBy(const Offset(120, 0));
    await g.moveBy(const Offset(0, 80));
    await tester.pump();
    await g.up();
    await tester.pump();
    await until(tester, () => h.c.session.steps.length == 1 && !h.c.busy);
    final ink = (await annots(tester, h))
        .where((a) => a.subtype == PdfAnnotType.ink)
        .toList();
    expect(ink, hasLength(1));
    expect(ink.single.ink.single.length, greaterThan(40));
  });

  testWidgets('damga / serbest metin kipinde dokunuş yer bildirir',
      (tester) async {
    final h = await open(tester);
    h.c.armMarkup(PdfMarkupKind.stamp);
    expect(h.c.drawing, isFalse, reason: 'damga dokunuşla konur');
    await tester.pump();
    await tester.tapAt(const Offset(120, 140));
    await tester.pump(const Duration(milliseconds: 400));
    h.c.armMarkup(PdfMarkupKind.freeText);
    await tester.pump();
    await tester.tapAt(const Offset(200, 300));
    await tester.pump(const Duration(milliseconds: 400));
    expect([for (final e in h.placed) e.$3],
        [PdfMarkupKind.stamp, PdfMarkupKind.freeText]);
    final page = h.doc.pages[0];
    expect(h.placed.first.$1, closeTo(120, 1));
    expect(h.placed.first.$2, closeTo(page.height - 140, 1));
  });

  test('damga ve serbest metin gerçek Stamp açıklaması; kayıttan sonra da '
      'görünüşüyle durur; fontta olmayan harf açıkça reddedilir', () async {
    final bytes = File('test/fixtures/pdf_corpus/rl_paragraflar.pdf')
        .readAsBytesSync();
    final doc = await PdfDocument.openData(bytes);
    addTearDown(doc.dispose);
    await PdfEditBridge.annotate(
        doc,
        PdfAnnotChange.stamp(0,
            x: 100, y: 700, text: 'REDDEDİLDİ', color: 0xFFC62828, size: 18,
            boxed: true));
    await PdfEditBridge.annotate(
        doc,
        PdfAnnotChange.stamp(0,
            x: 100, y: 500, text: 'Şu satır\nikinci satır', color: 0xFF111111));
    final stamps = (await PdfEditBridge.annotations(doc, 0))
        .where((a) => a.subtype == PdfAnnotType.stamp)
        .toList();
    expect(stamps.map((a) => a.contents),
        ['REDDEDİLDİ', 'Şu satır\nikinci satır']);
    final s = stamps.first;
    expect(s.left, closeTo(100, 0.5));
    expect(s.top, closeTo(700, 0.5));
    expect(s.right - s.left, greaterThan(60), reason: 'kutu yazıya göre');
    expect(stamps.last.top - stamps.last.bottom, greaterThan(30),
        reason: 'iki satır');

    final out = await PdfEditBridge.saveIncremental(doc, original: bytes);
    final tail = String.fromCharCodes(out.sublist(bytes.length));
    expect(tail, contains('/Stamp'));
    expect(tail, contains('/AP'));
    final re = await PdfDocument.openData(out);
    addTearDown(re.dispose);
    expect(
        (await PdfEditBridge.annotations(re, 0))
            .where((a) => a.subtype == PdfAnnotType.stamp),
        hasLength(2));

    await expectLater(
        PdfEditBridge.annotate(
            doc,
            PdfAnnotChange.stamp(0,
                x: 100, y: 300, text: 'مرحبا', color: 0xFF111111)),
        throwsA(isA<PdfEditBridgeRefused>()
            .having((e) => e.glyph, 'glyph', isTrue)));
  });

  test('damga günlüğü: boy ve çerçeve yazılır, font yazılmaz', () {
    final ch = PdfAnnotChange.stamp(2,
            x: 10, y: 20, text: 'GİZLİ', color: 0xFFC62828, size: 18,
            boxed: true)
        .withFont(Uint8List.fromList([1, 2, 3]));
    final j = ch.toJson();
    expect(j['fs'], 18);
    expect(j['bx'], isTrue);
    expect(j.values.whereType<Uint8List>(), isEmpty);
    final back = PdfAnnotChange.fromJson(j)!;
    expect(back.hasText, isTrue);
    expect(back.boxed, isTrue);
    expect(back.font, isNull);
    expect(back.contents, 'GİZLİ');
  });

  test('basınç: kalemde 0–1, parmakta bilgi yok; kalınlık çarpanı', () {
    expect(
        pdfPressureOf(const PointerDownEvent(
            kind: PointerDeviceKind.stylus,
            pressure: 0.5,
            pressureMin: 0,
            pressureMax: 1)),
        0.5);
    expect(
        pdfPressureOf(const PointerDownEvent(
            kind: PointerDeviceKind.touch,
            pressure: 0.5,
            pressureMin: 0,
            pressureMax: 1)),
        -1);
    // Basınçsız kalem (min == max).
    expect(pdfPressureOf(const PointerDownEvent(kind: PointerDeviceKind.stylus)),
        -1);
    expect(pdfPressureFactor(const <double>[-1, -1]), 1);
    expect(pdfPressureFactor(const <double>[0]), closeTo(0.4, 1e-9));
    expect(pdfPressureFactor(const <double>[1, 1]), closeTo(1.6, 1e-9));
    expect(pdfPressureFactor(const <double>[0.5, -1]), closeTo(1.0, 1e-9));
  });

  testWidgets('avuç reddi: kalem çizerken avuç çizgiyi bozmaz; kalem '
      'kipinde parmak çizmez', (tester) async {
    final h = await open(tester);
    h.c.armMarkup(PdfMarkupKind.ink);
    await tester.pump();
    final pen = await tester.createGesture(kind: PointerDeviceKind.stylus);
    await pen.down(const Offset(100, 300));
    await tester.pump();
    await pen.moveBy(const Offset(30, 0));
    // Avuç ekrana değer (eskiden ikinci parmak sayılıp çizgi silinirdi).
    final palm = await tester.createGesture(kind: PointerDeviceKind.touch);
    await palm.down(const Offset(400, 600));
    await palm.moveBy(const Offset(10, 10));
    for (var i = 0; i < 4; i++) {
      await pen.moveBy(const Offset(30, 5));
      await tester.pump();
    }
    await palm.up();
    await pen.up();
    await tester.pump();
    await until(tester, () => h.c.session.steps.length == 1 && !h.c.busy);
    expect(h.c.stylusSeen, isTrue);

    // Kalem kipinde tek parmak sürüklemesi çizim değildir.
    final finger = await tester.startGesture(const Offset(100, 500));
    for (var i = 0; i < 4; i++) {
      await finger.moveBy(const Offset(30, 0));
      await tester.pump();
    }
    await finger.up();
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 15)));
      await tester.pump();
    }
    expect(h.c.session.steps, hasLength(1));
    expect(
        (await annots(tester, h)).where((a) => a.subtype == PdfAnnotType.ink),
        hasLength(1));
    expect(tester.takeException(), isNull);
  });
}

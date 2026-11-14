import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/core/private_zone.dart';
import 'package:dosya_okuyucu/services/pdf/pdf_last_view.dart';
import 'package:dosya_okuyucu/widgets/pdf_open_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Ferrari H1.4 (2026-11-14): kapanıştaki sayfanın görüntüsü saklanır,
/// yeniden açılışta köprü kapak yerine onu gösterir.
void main() {
  late Directory dir;
  late Directory cache;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('pdf_last_view');
    cache = Directory(p.join(dir.path, 'cache'))..createSync();
    PdfLastView.debugUseDir(cache);
  });

  tearDown(() {
    PdfLastView.debugUseDir(null);
    removeTempDir(dir);
  });

  Uint8List jpg(int w, int h) =>
      PdfLastView.encode((Uint8List(w * h * 4)..fillRange(0, w * h * 4, 200), w, h))!;

  File pdf(String name) =>
      File(p.join(dir.path, name))..writeAsBytesSync([0]);

  test('JPEG kodlanır, sınırın altında, oranı başlıktan okunur', () async {
    final b = jpg(540, 760);
    expect(b.length, lessThanOrEqualTo(PdfLastView.maxBytes));
    final f = File(p.join(dir.path, 'x.jpg'))..writeAsBytesSync(b);
    expect(await PdfLastView.jpegAspect(f), closeTo(540 / 760, 1e-9));
  });

  test('saklanan görüntü aynı sayfada bulunur, başka sayfada bulunmaz',
      () async {
    final doc = pdf('kitap.pdf');
    await PdfLastView.save(doc.path, 42, jpg(54, 76));
    final got = await PdfLastView.find(doc.path, 42);
    expect(got, isNotNull);
    expect(got!.aspect, closeTo(54 / 76, 1e-9));
    expect(await PdfLastView.find(doc.path, 41), isNull);
  });

  test('belge başına tek görüntü: yeni sayfa eskisini siler', () async {
    final doc = pdf('kitap.pdf');
    await PdfLastView.save(doc.path, 3, jpg(20, 30));
    await PdfLastView.save(doc.path, 9, jpg(20, 30));
    expect(await PdfLastView.find(doc.path, 3), isNull);
    expect(await PdfLastView.find(doc.path, 9), isNotNull);
    expect(cache.listSync(), hasLength(1));
  });

  test('belge sonradan değiştiyse görüntü bayat sayılır', () async {
    final doc = pdf('kitap.pdf');
    await PdfLastView.save(doc.path, 5, jpg(20, 30));
    doc.setLastModifiedSync(DateTime.now().add(const Duration(hours: 1)));
    expect(await PdfLastView.find(doc.path, 5), isNull);
  });

  test('en çok maxEntries belge tutulur, en eskiler silinir', () async {
    final b = jpg(8, 8);
    final first = pdf('ilk.pdf');
    await PdfLastView.save(first.path, 2, b);
    File(p.join(cache.path, '${PdfLastView.keyOf(first.path)}_2.jpg'))
        .setLastModifiedSync(DateTime(2020));
    for (var i = 0; i < PdfLastView.maxEntries; i++) {
      await PdfLastView.save(p.join(dir.path, 'b$i.pdf'), 2, b);
    }
    expect(cache.listSync(), hasLength(PdfLastView.maxEntries));
    expect(
        File(p.join(cache.path, '${PdfLastView.keyOf(first.path)}_2.jpg'))
            .existsSync(),
        isFalse);
  });

  test('kasa yolunda saklanmaz ve aranmaz', () async {
    final vault = Directory(p.join(dir.path, PrivateZone.vaultTemp))
      ..createSync();
    final doc = File(p.join(vault.path, 'gizli.pdf'))..writeAsBytesSync([0]);
    expect(PdfLastView.allowed(doc.path), isFalse);
    await PdfLastView.save(doc.path, 4, jpg(8, 8));
    expect(cache.listSync(), isEmpty);
    expect(await PdfLastView.find(doc.path, 4), isNull);
  });

  group('köprü', () {
    Widget host(Widget child) => MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Scaffold(
                body: Stack(children: [Positioned.fill(child: child)])),
          ),
        );

    testWidgets('son sayfa görüntüsü kapağın önüne geçer', (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var coverAsked = 0;
      int? askedPage;
      await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf',
        visible: true,
        page: 1,
        coverLoader: (_) async {
          coverAsked++;
          return (path: '/kapak.png', aspect: 2.0);
        },
        lastViewLoader: (_, page) async {
          askedPage = page;
          return (path: '/son.jpg', aspect: 1.5);
        },
      )));
      await tester.pump();
      await tester.pump();
      expect(askedPage, 1);
      expect(coverAsked, 0);
      final size =
          tester.getSize(find.byKey(const ValueKey('pdf-bridge-paper')));
      expect(size.height, closeTo(size.width / 1.5, 0.01));
    });

    testWidgets('ortadan devamda kapak yok ama son sayfa görüntüsü var',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(400, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var coverAsked = 0;
      await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf',
        visible: true,
        useCover: false,
        page: 42,
        coverLoader: (_) async {
          coverAsked++;
          return null;
        },
        lastViewLoader: (_, page) async =>
            page == 42 ? (path: '/son.jpg', aspect: 1.5) : null,
      )));
      await tester.pump();
      await tester.pump();
      expect(coverAsked, 0);
      final size =
          tester.getSize(find.byKey(const ValueKey('pdf-bridge-paper')));
      expect(size.height, closeTo(size.width / 1.5, 0.01));
    });

    testWidgets('görüntü yoksa ilk sayfada kapağa döner', (tester) async {
      var coverAsked = 0;
      await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf',
        visible: true,
        page: 1,
        coverLoader: (_) async {
          coverAsked++;
          return null;
        },
        lastViewLoader: (_, _) async => null,
      )));
      await tester.pump();
      await tester.pump();
      expect(coverAsked, 1);
    });
  });
}

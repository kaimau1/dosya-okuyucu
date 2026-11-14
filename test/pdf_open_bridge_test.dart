import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/pdf_thumbnail.dart';
import 'package:dosya_okuyucu/services/fm/thumbnail_cache.dart';
import 'package:dosya_okuyucu/widgets/pdf_open_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// Ferrari H1.1 (2026-11-14): PDF yüklenirken düz boş ekran yerine kâğıt /
/// kapak köprüsü; belge hazır olunca solar ve ağaçtan çıkar.
void main() {
  Widget host(Widget child) => MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(400, 800)),
          child: Scaffold(body: Stack(children: [Positioned.fill(child: child)])),
        ),
      );

  Future<({String path, double aspect})?> noCover(String _) async => null;

  testWidgets('kapak yokken A4 oranında nötr kâğıt çizer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(PdfOpenBridge(
        path: '/yok.pdf', visible: true, coverLoader: noCover)));
    await tester.pump();
    final size = tester.getSize(find.byKey(const ValueKey('pdf-bridge-paper')));
    expect(size.width, 400 - 16);
    expect(size.height, closeTo((400 - 16) / kPdfBridgeDefaultAspect, 0.01));
  });

  testWidgets('kapak varsa kâğıt kapağın oranını alır', (tester) async {
    await tester.binding.setSurfaceSize(const Size(400, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf',
        visible: true,
        coverLoader: (_) async => (path: '/yok/kapak.png', aspect: 2.0))));
    await tester.pump();
    await tester.pump();
    final size = tester.getSize(find.byKey(const ValueKey('pdf-bridge-paper')));
    expect(size.height, closeTo(size.width / 2, 0.01));
  });

  testWidgets('ortadan devam edilen belgede kapak aranmaz', (tester) async {
    var asked = 0;
    await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf',
        visible: true,
        useCover: false,
        coverLoader: (_) async {
          asked++;
          return null;
        })));
    await tester.pump();
    expect(asked, 0);
  });

  testWidgets('belge hazır olunca solar ve ağaçtan çıkar', (tester) async {
    await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf', visible: true, coverLoader: noCover)));
    await tester.pump();
    expect(find.byKey(const ValueKey('pdf-open-bridge')), findsOneWidget);
    await tester.pumpWidget(host(PdfOpenBridge(
        path: '/a.pdf', visible: false, coverLoader: noCover)));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pdf-open-bridge')), findsNothing);
    expect(find.byKey(const ValueKey('pdf-bridge-paper')), findsNothing);
  });

  group('PdfThumbnail.cachedCover', () {
    late Directory dir;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('pdf_bridge');
      PdfThumbnail.debugReset();
    });

    tearDown(() {
      PdfThumbnail.debugReset();
      removeTempDir(dir);
    });

    Uint8List pngHeader(int w, int h) {
      final b = ByteData(24);
      const sig = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
      for (var i = 0; i < 8; i++) {
        b.setUint8(i, sig[i]);
      }
      b.setUint32(8, 13);
      b.setUint8(12, 0x49); // I
      b.setUint8(13, 0x48); // H
      b.setUint8(14, 0x44); // D
      b.setUint8(15, 0x52); // R
      b.setUint32(16, w);
      b.setUint32(20, h);
      return b.buffer.asUint8List();
    }

    test('üretilmiş kapağı bulur, oranı PNG başlığından okur', () async {
      final cache = Directory(p.join(dir.path, 'thumbs'))..createSync();
      PdfThumbnail.debugUseDir(cache);
      final pdf = File(p.join(dir.path, 'kitap.pdf'))..writeAsBytesSync([0]);
      final ms = pdf.statSync().modified.millisecondsSinceEpoch;
      final name =
          ThumbnailCache.cacheName(pdf.path, ms, 256).replaceAll('.jpg', '.png');
      File(p.join(cache.path, name)).writeAsBytesSync(pngHeader(180, 256));
      final cover = await PdfThumbnail.cachedCover(pdf.path);
      expect(cover, isNotNull);
      expect(cover!.path, p.join(cache.path, name));
      expect(cover.aspect, closeTo(180 / 256, 1e-9));
    });

    test('kapak yoksa null döner, ÜRETMEZ', () async {
      final cache = Directory(p.join(dir.path, 'thumbs'))..createSync();
      PdfThumbnail.debugUseDir(cache);
      final pdf = File(p.join(dir.path, 'yeni.pdf'))..writeAsBytesSync([0]);
      expect(await PdfThumbnail.cachedCover(pdf.path), isNull);
      expect(cache.listSync(), isEmpty);
    });

    test('olmayan dosya ve PNG olmayan önbellek dosyası çökertmez', () async {
      final cache = Directory(p.join(dir.path, 'thumbs'))..createSync();
      PdfThumbnail.debugUseDir(cache);
      expect(await PdfThumbnail.cachedCover(p.join(dir.path, 'yok.pdf')),
          isNull);
      final junk = File(p.join(dir.path, 'bozuk.png'))..writeAsBytesSync([1, 2]);
      expect(await PdfThumbnail.pngAspect(junk), isNull);
    });
  });
}

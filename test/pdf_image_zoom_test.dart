import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/widgets/pdf_image_zoom.dart';

/// Ferrari H3.3 — görsel kipi: siyah zeminde tam ekran, aşağı çekince kapanır.
void main() {
  Future<ui.Image> tinyImage() {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(
        const Rect.fromLTWH(0, 0, 40, 20), Paint()..color = const Color(0xFF808080));
    return rec.endRecording().toImage(40, 20);
  }

  Future<void> open(WidgetTester tester, Future<ui.Image?> Function() load) async {
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(pdfImageZoomRoute(load)),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
  }

  testWidgets('çizilemeyen görselde "açılamadı" yazar', (tester) async {
    await open(tester, () async => null);
    expect(find.text('Görsel açılamadı'), findsOneWidget);
  });

  testWidgets('görsel gösterilir, aşağı çekince kapanır', (tester) async {
    ui.Image? image;
    await tester.runAsync(() async => image = await tinyImage());
    await open(tester, () async => image!.clone());
    expect(find.byKey(const ValueKey('pdf-image-zoom-image')), findsOneWidget);

    await tester.drag(
        find.byKey(const ValueKey('pdf-image-zoom-image')), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(find.byType(PdfImageZoomScreen), findsNothing);
    expect(find.text('aç'), findsOneWidget);
    image!.dispose();
  });

  testWidgets('kısa çekiş kapatmaz, görsel yerine döner', (tester) async {
    ui.Image? image;
    await tester.runAsync(() async => image = await tinyImage());
    await open(tester, () async => image!.clone());
    await tester.timedDrag(find.byKey(const ValueKey('pdf-image-zoom-image')),
        const Offset(0, 40), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.byType(PdfImageZoomScreen), findsOneWidget);
    image!.dispose();
  });
}

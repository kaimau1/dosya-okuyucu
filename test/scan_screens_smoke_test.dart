import 'package:dosya_okuyucu/screens/scan_result_screen.dart';
import 'package:dosya_okuyucu/screens/scan_review_screen.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';
import 'package:dosya_okuyucu/services/scan_prepare.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tarama sonucu + sayfa düzenleme ekranları dar telefonda taşmadan çizilir
/// (2026-10-17: tarama doğrudan kaydediliyor, düzenleme sonuç ekranından).
void main() {
  const pages = [
    ScanPage(
        source: '/yok/1.jpg',
        display: '/yok/1_auto.jpg',
        filter: ScanFilter.auto),
    ScanPage(
        source: '/yok/2.jpg',
        display: '/yok/2_auto.jpg',
        filter: ScanFilter.auto),
  ];

  Future<void> pumpAt(WidgetTester tester, Widget child,
      {double textScale = 1.0}) async {
    tester.view.physicalSize = const Size(360 * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(360, 700),
          devicePixelRatio: 3,
          textScaler: TextScaler.linear(textScale),
        ),
        child: child,
      ),
    ));
    await tester.pump();
  }

  for (final scale in [1.0, 1.4]) {
    testWidgets(
        'sonuç ekranı ($scale×): "Sayfaları düzenle" görünür, taşma yok',
        (tester) async {
      await pumpAt(
        tester,
        const ScanResultScreen(
          pdfPath: '/yok/Tarama.pdf',
          pages: pages,
          textPages: [OcrPage(1, 'merhaba')],
        ),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Sayfaları düzenle'), findsOneWidget);
      expect(find.text('1 / 2'), findsOneWidget);
    });

    testWidgets(
        'düzenleme ekranı ($scale×): sıra okları ve filtreler, taşma yok',
        (tester) async {
      await pumpAt(tester, const ScanReviewScreen(pages: pages),
          textScale: scale);
      expect(tester.takeException(), isNull);
      expect(find.text('Sayfa 1 / 2'), findsOneWidget);
      expect(find.byTooltip('Sayfayı arkaya al'), findsOneWidget);
      expect(find.text('Kaydet'), findsOneWidget);
    });
  }

  testWidgets('düzenleme ekranı: değişiklik yoksa Kaydet null döner',
      (tester) async {
    List<ScanPage>? result = const [];
    await pumpAt(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await ScanReviewScreen.open(context, pages),
          child: const Text('aç'),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(result, isNull, reason: 'değişmeyen belge yeniden yazılmamalı');
  });

  testWidgets('düzenleme ekranı: sayfa sırası değişince yeni sıra döner',
      (tester) async {
    List<ScanPage>? result;
    await pumpAt(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () async =>
              result = await ScanReviewScreen.open(context, pages),
          child: const Text('aç'),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sayfayı arkaya al'));
    await tester.pumpAndSettle();
    expect(find.text('Sayfa 2 / 2'), findsOneWidget);
    await tester.tap(find.text('Kaydet'));
    await tester.pumpAndSettle();
    expect(
        result?.map((p) => p.display), ['/yok/2_auto.jpg', '/yok/1_auto.jpg']);
  });
}

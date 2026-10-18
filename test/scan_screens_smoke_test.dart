import 'package:dosya_okuyucu/screens/scan_edit_screen.dart';
import 'package:dosya_okuyucu/screens/scan_result_screen.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';
import 'package:dosya_okuyucu/services/scan_prepare.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Tarama stüdyosu (2026-10-18: akış, düğmeler ve görünüm baştan) dar
/// telefonda ve büyük yazı tipinde taşmadan çizilir; araçlar sayfanın
/// altında GÖRÜNÜR; değişiklik kendiliğinden kaydedilir ve geri alınabilir.
void main() {
  const pages = [
    ScanPage(source: '/yok/1.jpg', display: '/yok/1.jpg'),
    ScanPage(
        source: '/yok/2.jpg',
        display: '/yok/2_auto.jpg',
        filter: ScanFilter.auto),
  ];

  Future<void> pumpAt(WidgetTester tester, Widget child,
      {double textScale = 1.0, double width = 360}) async {
    tester.view.physicalSize = Size(width * 3, 700 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, 700),
          devicePixelRatio: 3,
          textScaler: TextScaler.linear(textScale),
          // Hareket çubuklu telefon: alt sistem çubuğu 48 dp.
          padding: const EdgeInsets.only(top: 24, bottom: 48),
          viewPadding: const EdgeInsets.only(top: 24, bottom: 48),
        ),
        child: child,
      ),
    ));
    await tester.pump();
  }

  for (final scale in [1.0, 1.4]) {
    testWidgets('stüdyo ($scale×): beş araç görünür, taşma yok',
        (tester) async {
      await pumpAt(
        tester,
        ScanResultScreen(
          pdfPath: '/yok/Tarama.pdf',
          pages: pages,
          textPages: const [OcrPage(1, 'merhaba')],
          saver: (_, __, ___) async {},
        ),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      for (final label in ['Kırp', 'Döndür', 'Filtre', 'Yeniden çek', 'Sil']) {
        expect(find.text(label), findsOneWidget, reason: label);
      }
      expect(find.textContaining('1 / 2'), findsOneWidget);
      expect(find.text('Tarama'), findsOneWidget, reason: 'dosya adı başlıkta');
      // Araç çubuğu sistem çubuğunun ÜSTÜNDE: "Sil"in alt kenarı ekranın
      // alttan 48 dp'lik gezinme alanına girmiyor.
      final bottom = tester.getBottomLeft(find.text('Sil')).dy;
      expect(bottom, lessThan(700 - 48));
    });
  }

  testWidgets('sil → kendiliğinden kaydedilir; geri al → iki sayfa döner',
      (tester) async {
    final saved = <List<String>>[];
    await pumpAt(
      tester,
      ScanResultScreen(
        pdfPath: '/yok/Tarama.pdf',
        pages: pages,
        saver: (_, pages, __) async =>
            saved.add([for (final page in pages) page.source]),
      ),
    );
    await tester.tap(find.text('Sil'));
    await tester.pump();
    expect(find.textContaining('1 / 1'), findsOneWidget);
    expect(find.text('Sayfalar (1)'), findsOneWidget);
    // Kayıt kısa bir beklemeyle (art arda değişiklikler tek yazım).
    expect(saved, isEmpty);
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(saved, [
      ['/yok/2.jpg']
    ]);
    expect(find.textContaining('Kaydedildi'), findsOneWidget);

    await tester.tap(find.byTooltip('Geri al'));
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump();
    expect(find.text('Sayfalar (2)'), findsOneWidget);
    expect(saved.last, ['/yok/1.jpg', '/yok/2.jpg']);
  });

  testWidgets('son sayfa silinmez', (tester) async {
    await pumpAt(
      tester,
      ScanResultScreen(
        pdfPath: '/yok/Tarama.pdf',
        pages: const [ScanPage.raw('/yok/1.jpg')],
        saver: (_, __, ___) async => fail('kaydedilmemeli'),
      ),
    );
    await tester.tap(find.text('Sil'));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('Sayfalar (1)'), findsOneWidget);
  });

  testWidgets('bekleyen değişiklik varken geri tuşu önce kaydeder',
      (tester) async {
    var saves = 0;
    await pumpAt(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScanResultScreen(
              pdfPath: '/yok/Tarama.pdf',
              pages: pages,
              saver: (_, __, ___) async => saves++,
            ),
          )),
          child: const Text('aç'),
        ),
      ),
    );
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sil'));
    await tester.pump();
    // Zamanlayıcı dolmadan çık.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves, 1);
    expect(find.text('aç'), findsOneWidget, reason: 'ekran kapandı');
  });

  group('kırpma ekranı', () {
    test('başlangıç çerçevesi görselin TAM sınırı', () {
      expect(ScanEditScreen.fullFrame(1000, 1400), const [
        Offset(0, 0),
        Offset(1000, 0),
        Offset(1000, 1400),
        Offset(0, 1400),
      ]);
      expect(
          ScanEditScreen.isFullFrame(
              ScanEditScreen.fullFrame(10, 20), 10, 20),
          isTrue);
    });

    test('kenar tutamacı kenarı topluca taşır, öteki köşelere dokunmaz', () {
      final full = ScanEditScreen.fullFrame(1000, 1400);
      // Üst kenar (0) 120 px aşağı; yatay bileşen yok sayılır.
      final top = ScanEditScreen.dragEdge(
          full, 0, const Offset(37, 120), const Size(1000, 1400));
      expect(top[0], const Offset(0, 120));
      expect(top[1], const Offset(1000, 120));
      expect(top[2], full[2]);
      expect(top[3], full[3]);
      // Sol kenar (3: sol-alt → sol-üst) 80 px içeri.
      final left = ScanEditScreen.dragEdge(
          full, 3, const Offset(80, -9), const Size(1000, 1400));
      expect(left[3], const Offset(80, 1400));
      expect(left[0], const Offset(80, 0));
      // Dışarı çekmek görsel sınırında durur.
      final out = ScanEditScreen.dragEdge(
          full, 1, const Offset(300, 0), const Size(1000, 1400));
      expect(out[1].dx, 1000);
      expect(out[2].dx, 1000);
    });
  });
}

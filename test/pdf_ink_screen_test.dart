import 'package:dosya_okuyucu/screens/pdf_ink_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kalem ekranının hareket mantığı (pdfium olmadan: `testPageSizes`).
void main() {
  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2000);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: PdfInkScreen(
        path: '/yok/belge.pdf',
        testPageSizes: [Size(595, 842), Size(595, 842)],
      ),
    ));
    await tester.pump();
  }

  Finder inkPaint() => find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is InkPainter);

  int strokeCount(WidgetTester tester) =>
      (tester.widget<CustomPaint>(inkPaint()).painter! as InkPainter)
          .marks
          .length;

  Offset pageCenter(WidgetTester tester) => tester.getCenter(inkPaint());

  Future<void> drawLine(WidgetTester tester, Offset from, Offset to) async {
    final g = await tester.startGesture(from);
    for (var i = 1; i <= 10; i++) {
      await g.moveTo(Offset.lerp(from, to, i / 10)!);
      await tester.pump();
    }
    await g.up();
    await tester.pump();
  }

  testWidgets('tek parmak çizer, geri al / yinele çalışır', (tester) async {
    await pump(tester);
    final c = pageCenter(tester);
    await drawLine(tester, c, c + const Offset(80, 40));
    expect(strokeCount(tester), 1);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(strokeCount(tester), 0);

    await tester.tap(find.byIcon(Icons.redo));
    await tester.pump();
    expect(strokeCount(tester), 1);
  });

  testWidgets('ikinci parmak (yakınlaştırma) yarım darbe bırakmaz',
      (tester) async {
    await pump(tester);
    final c = pageCenter(tester);
    final a = await tester.startGesture(c);
    await a.moveBy(const Offset(20, 0));
    await tester.pump();
    final b = await tester.startGesture(c + const Offset(0, 100));
    await a.moveBy(const Offset(-20, -20));
    await b.moveBy(const Offset(20, 20));
    await tester.pump();
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(strokeCount(tester), 0);
  });

  testWidgets('silgi üstünden geçilen darbeyi siler, tek adımda geri gelir',
      (tester) async {
    await pump(tester);
    final c = pageCenter(tester);
    await drawLine(tester, c - const Offset(60, 0), c + const Offset(60, 0));
    await drawLine(tester, c + const Offset(-60, 150), c + const Offset(60, 150));
    expect(strokeCount(tester), 2);

    await tester.tap(find.byIcon(Icons.auto_fix_normal_outlined));
    await tester.pump();
    await drawLine(tester, c + const Offset(0, -30), c + const Offset(0, 30));
    expect(strokeCount(tester), 1);

    await tester.tap(find.byIcon(Icons.undo));
    await tester.pump();
    expect(strokeCount(tester), 2);
  });

  testWidgets('yazı aracı: dokun, yaz, sayfada görünür', (tester) async {
    await pump(tester);
    await tester.tap(find.byIcon(Icons.text_fields));
    await tester.pump();
    await tester.tapAt(pageCenter(tester));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Fatih Şenel');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();
    expect(find.text('Fatih Şenel'), findsOneWidget);
  });

  testWidgets('sayfa değişince çizimler o sayfada kalır', (tester) async {
    await pump(tester);
    final c = pageCenter(tester);
    await drawLine(tester, c, c + const Offset(50, 50));
    expect(strokeCount(tester), 1);
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pump();
    expect(find.text('2 / 2'), findsOneWidget);
    expect(strokeCount(tester), 0);
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pump();
    expect(strokeCount(tester), 1);
  });

  testWidgets('dar telefonda (360 dp) hiçbir araçta taşma yok', (tester) async {
    tester.view.physicalSize = const Size(900, 1800);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(
      home: PdfInkScreen(
        path: '/yok/belge.pdf',
        testPageSizes: [Size(842, 595)],
      ),
    ));
    await tester.pump();
    for (final icon in [
      Icons.border_color_outlined,
      Icons.text_fields,
      Icons.auto_fix_normal_outlined,
      Icons.pan_tool_outlined,
      Icons.edit_outlined,
    ]) {
      await tester.tap(find.byIcon(icon));
      await tester.pump();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('kaydedilmemiş çizimle geri: sorulur', (tester) async {
    await pump(tester);
    final c = pageCenter(tester);
    await drawLine(tester, c, c + const Offset(50, 50));
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    await nav.maybePop();
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}

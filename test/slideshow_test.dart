import 'package:dosya_okuyucu/screens/editors/slideshow_screen.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const _slide = SlideVM(widthPt: 960, heightPt: 540, shapes: []);

void main() {
  testWidgets('sunum modu sağ/sol dokunuşla slayt değiştirir', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: SlideshowScreen(slides: [_slide, _slide, _slide]),
    ));

    expect(find.text('1 / 3'), findsOneWidget);

    final w = t.view.physicalSize.width / t.view.devicePixelRatio;

    // Çift dokunuş tanıyıcısı yüzünden tek dokunuş kDoubleTapTimeout (300 ms)
    // sonra kesinleşir; testin de o süreyi ilerletmesi gerekir.
    Future<void> tap(double xFactor) async {
      await t.tapAt(Offset(w * xFactor, 200));
      await t.pump(const Duration(milliseconds: 350));
      await t.pumpAndSettle();
    }

    await tap(0.9); // sağ yarı -> ileri
    expect(find.text('2 / 3'), findsOneWidget);

    await tap(0.1); // sol yarı -> geri
    expect(find.text('1 / 3'), findsOneWidget);

    // İlk slayttayken geri dokunuşu sınırın dışına taşmaz.
    await tap(0.1);
    expect(find.text('1 / 3'), findsOneWidget);
  });

  testWidgets('geçişli slayta ileri giderken geçiş oynar (Faz 29b)', (t) async {
    const faded = SlideVM(
        widthPt: 960, heightPt: 540, shapes: [], transition: 'push');
    await t.pumpWidget(const MaterialApp(
      home: SlideshowScreen(slides: [_slide, faded, _slide]),
    ));
    final w = t.view.physicalSize.width / t.view.devicePixelRatio;
    await t.tapAt(Offset(w * 0.9, 200));
    await t.pump(const Duration(milliseconds: 350));
    expect(find.text('2 / 3'), findsOneWidget);
    expect(find.byKey(const ValueKey('ss-transition')), findsOneWidget);
    await t.pumpAndSettle();
    expect(find.byKey(const ValueKey('ss-transition')), findsNothing);
    // Geçişsiz slayta: efekt yok.
    await t.tapAt(Offset(w * 0.9, 200));
    await t.pump(const Duration(milliseconds: 350));
    expect(find.byKey(const ValueKey('ss-transition')), findsNothing);
    await t.pumpAndSettle();
    expect(find.text('3 / 3'), findsOneWidget);
  });

  testWidgets('Faz 38: klavye/kumanda ile ilerler; kalem, lazer, zamanlayıcı', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: SlideshowScreen(slides: [_slide, _slide, _slide]),
    ));
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.pageDown);
    await t.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await t.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('ss-tools')));
    await t.pump();
    await t.tap(find.byKey(const ValueKey('ss-pen')));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-ink-layer')), findsOneWidget);
    final c = t.getCenter(find.byKey(const ValueKey('ss-ink-layer')));
    await t.dragFrom(c, const Offset(80, 30));
    await t.pump();
    // Kalem kipinde kaydırma slayt DEĞİŞTİRMEZ.
    expect(find.text('1 / 3'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ss-clear-ink')));
    await t.tap(find.byKey(const ValueKey('ss-laser')));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-ink-layer')), findsOneWidget);

    await t.tap(find.byKey(const ValueKey('ss-timer-toggle')));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-timer')), findsOneWidget);
    expect(find.textContaining('00:0'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ss-timer-toggle')));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-timer')), findsNothing);
  });

  testWidgets('Faz 38: sunucu görünümü — not, sonraki slayt, süre', (t) async {
    await t.pumpWidget(const MaterialApp(
      home: SlideshowScreen(
        slides: [_slide, _slide],
        notes: ['Birinci not', ''],
        presenter: true,
      ),
    ));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-presenter-panel')), findsOneWidget);
    expect(find.byKey(const ValueKey('ss-next-preview')), findsOneWidget);
    expect(find.text('Birinci not'), findsOneWidget);
    expect(find.byKey(const ValueKey('ss-presenter-clock')), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('ss-presenter-next')));
    await t.pumpAndSettle();
    expect(find.text('2 / 2'), findsWidgets);
    expect(find.byKey(const ValueKey('ss-next-preview')), findsNothing);
    await t.tap(find.byKey(const ValueKey('ss-presenter')));
    await t.pump();
    expect(find.byKey(const ValueKey('ss-presenter-panel')), findsNothing);
  });
}

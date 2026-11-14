import 'package:dosya_okuyucu/widgets/pinch_zoom_area.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// KALANLAR B3.4 (P12): Excel ızgarasında kaydırma SÜRERKEN inen ikinci
/// parmak pinch'e dönmeli — ilk parmak kaydırmanın elindeyken de.
void main() {
  testWidgets('kaydırma sürerken başlayan pinch yakınlaştırır, kaydırma durur',
      (tester) async {
    final ctl = ScrollController();
    addTearDown(ctl.dispose);
    double? committed;
    await tester.pumpWidget(MaterialApp(
      home: PinchZoomArea(
        onCommitted: (f, _) => committed = f,
        builder: (_, zoom, physics) => ListView.builder(
          controller: ctl,
          physics: physics,
          itemCount: 500,
          itemExtent: 40,
          itemBuilder: (_, i) => Text('$i'),
        ),
      ),
    ));

    final a = await tester.startGesture(const Offset(200, 500));
    for (var i = 0; i < 4; i++) {
      await a.moveBy(const Offset(0, -40));
      await tester.pump();
    }
    expect(ctl.offset, greaterThan(0), reason: 'ilk parmak kaydırıyor');

    final b = await tester.startGesture(const Offset(200, 300));
    await tester.pump();
    final locked = ctl.offset;
    for (var i = 0; i < 5; i++) {
      await a.moveBy(const Offset(0, 30));
      await b.moveBy(const Offset(0, -30));
      await tester.pump();
    }
    expect(ctl.offset, closeTo(locked, 0.5),
        reason: 'pinch sürerken ızgara kaymaz');
    await a.up();
    await b.up();
    await tester.pump();
    await tester.pump(const Duration(seconds: 3)); // rozet zamanlayıcısı

    expect(committed, isNotNull);
    expect(committed!, greaterThan(1.5));
  });
}

import 'package:dosya_okuyucu/models/fm_layout.dart';
import 'package:dosya_okuyucu/widgets/fm/pinch_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merdiven: açmak büyütür, sıkıştırmak sütun ekler, uçta durur', () {
    expect(fmPinchStep(FmLayout.grid3, -1), FmLayout.grid2);
    expect(fmPinchStep(FmLayout.grid2, -1), FmLayout.list);
    expect(fmPinchStep(FmLayout.list, 1), FmLayout.grid2);
    expect(fmPinchStep(FmLayout.grid5, 1), FmLayout.grid5);
    expect(fmPinchStep(FmLayout.detail, -1), FmLayout.detail);
  });

  testWidgets('iki parmağı açmak düzeni bir basamak büyütür', (tester) async {
    final got = <FmLayout>[];
    await tester.pumpWidget(MaterialApp(
      home: PinchLayoutSwitcher(
        layout: FmLayout.grid3,
        onChanged: got.add,
        child: const SizedBox.expand(),
      ),
    ));
    final a = await tester.createGesture(pointer: 1);
    final b = await tester.createGesture(pointer: 2);
    await a.down(const Offset(150, 300));
    await b.down(const Offset(210, 300));
    await a.moveTo(const Offset(130, 300));
    await b.moveTo(const Offset(225, 300)); // 60 → 80 basamak, 80 → 95 değil
    await a.up();
    await b.up();
    expect(got, [FmLayout.grid2]);

    got.clear();
    await a.down(const Offset(100, 300));
    await b.down(const Offset(300, 300));
    await b.moveTo(const Offset(250, 300)); // 200 → 150: ×0,75
    await a.up();
    await b.up();
    expect(got, [FmLayout.grid3]); // içteki düzen grid2 idi
  });
}

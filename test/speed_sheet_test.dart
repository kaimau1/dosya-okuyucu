import 'package:dosya_okuyucu/widgets/fm/speed_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('oynatma hızı 0,05 adıma oturur ve aralıkta kalır', () {
    expect(PlaybackSpeed.snap(1.07), 1.05);
    expect(PlaybackSpeed.snap(1.08), 1.1);
    expect(PlaybackSpeed.snap(0.1), PlaybackSpeed.min);
    expect(PlaybackSpeed.snap(9), PlaybackSpeed.max);
    expect(PlaybackSpeed.label(1.0), '1×');
    expect(PlaybackSpeed.label(1.5), '1.5×');
    expect(PlaybackSpeed.label(1.25), '1.25×');
  });

  testWidgets('hız 1× değilken hap + sıfırla görünür', (tester) async {
    var reset = 0;
    Widget app(double v) => MaterialApp(
          home: Scaffold(
            appBar: AppBar(actions: [
              SpeedButton(
                speed: v,
                tooltip: 'Hız',
                onOpen: () {},
                onReset: () => reset++,
              ),
            ]),
          ),
        );
    await tester.pumpWidget(app(1.0));
    expect(find.byKey(const ValueKey('mp-speed-reset')), findsNothing);
    await tester.pumpWidget(app(1.7));
    expect(find.text('1.7×'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mp-speed-reset')));
    expect(reset, 1);
  });
}

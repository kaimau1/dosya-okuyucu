import 'package:dosya_okuyucu/widgets/office_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// P28 / Ferrari H3.7: sayfa rozeti çubuklar (ve yapay zekâ düğmesi)
/// görünürken düğmenin soluna kayar, çubuklar çekikken sağ altta kalır.
void main() {
  Future<double?> endAt(WidgetTester tester, double shown) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: ReadingChrome(
        top: 0,
        bottom: 64,
        shown: AlwaysStoppedAnimation(shown),
        child: const Stack(children: [
          ReadingFloat(start: null, end: 44, endShown: 80, child: SizedBox()),
        ]),
      ),
    ));
    return tester
        .widget<PositionedDirectional>(find.byType(PositionedDirectional))
        .end;
  }

  testWidgets('rozet düğme görünürken sola kayar', (tester) async {
    expect(await endAt(tester, 0), 44);
    expect(await endAt(tester, 1), 80);
    expect(await endAt(tester, 0.5), 62);
  });
}

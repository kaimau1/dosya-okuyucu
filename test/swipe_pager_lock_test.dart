import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/screens/fm/swipe_pager.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Seçim sürerken kaydırmalı gezgin yana geçmemeli (2026-10-17 kullanıcı:
/// "seçim yapılırken sağa sola kaydırıp sayfalar arasında geçiş olmamalı").
void main() {
  /// İlk sayfa, [holding] açıkken bir [SwipeHold] taşır — seçim çubuğunun
  /// belirip kaybolmasının birebir karşılığı.
  Widget pager(ValueNotifier<bool> holding) => MaterialApp(
        home: SwipePager(
          pages: [
            SwipePage(
              label: 'Bir',
              icon: AppIcons.image,
              color: Colors.blue,
              builder: (_) => Scaffold(
                body: ValueListenableBuilder<bool>(
                  valueListenable: holding,
                  builder: (_, hold, __) => Column(
                    children: [
                      const Expanded(child: Center(child: Text('sayfa-1'))),
                      if (hold) const SwipeHold(child: Text('seçim çubuğu')),
                    ],
                  ),
                ),
              ),
            ),
            SwipePage(
              label: 'İki',
              icon: Icons.movie,
              color: Colors.red,
              builder: (_) =>
                  const Scaffold(body: Center(child: Text('sayfa-2'))),
            ),
          ],
        ),
      );

  testWidgets('seçim yokken kaydırınca komşu sayfaya geçer', (tester) async {
    final holding = ValueNotifier(false);
    await tester.pumpWidget(pager(holding));
    await tester.fling(find.text('sayfa-1'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('sayfa-2'), findsOneWidget);
  });

  testWidgets('seçim sürerken kaydırma sayfa DEĞİŞTİRMEZ, bitince serbest',
      (tester) async {
    final holding = ValueNotifier(true);
    await tester.pumpWidget(pager(holding));
    await tester.pump(); // kilit karenin sonunda devreye girer
    await tester.fling(find.text('sayfa-1'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('sayfa-1'), findsOneWidget);
    expect(find.text('sayfa-2'), findsNothing);

    holding.value = false; // seçim bitti → çubuk kalktı
    await tester.pumpAndSettle();
    await tester.fling(find.text('sayfa-1'), const Offset(-500, 0), 2000);
    await tester.pumpAndSettle();
    expect(find.text('sayfa-2'), findsOneWidget);
  });

  testWidgets('iki parmak ekrandayken (pinch) sayfa değişmez', (tester) async {
    final holding = ValueNotifier(false);
    await tester.pumpWidget(pager(holding));
    final center = tester.getCenter(find.text('sayfa-1'));
    final a = await tester.startGesture(center + const Offset(-40, 0));
    final b =
        await tester.startGesture(center + const Offset(40, 0), pointer: 7);
    await tester.pump();
    // Parmaklar açılırken ikisi de sola kayıyor: gerçek pinch'te yatay
    // bileşen hep vardır ve eskiden sayfayı çeviriyordu.
    for (var i = 0; i < 12; i++) {
      await a.moveBy(const Offset(-70, 0));
      await b.moveBy(const Offset(-50, 0));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await a.up();
    await b.up();
    await tester.pumpAndSettle();
    expect(find.text('sayfa-1'), findsOneWidget);
  });

  testWidgets('gezgin dışında SwipeHold zararsız', (tester) async {
    await tester
        .pumpWidget(const MaterialApp(home: SwipeHold(child: Text('yalnız'))));
    expect(find.text('yalnız'), findsOneWidget);
  });
}

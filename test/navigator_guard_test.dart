import 'package:dosya_okuyucu/core/navigator_guard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Boşalan yığının emniyet ağı** (kullanıcı hatası 2026-09-06: *"ekran
/// kararıyor, kapatıp açmak gerekiyor"*).
///
/// `Navigator`ın son sayfası da kapanırsa Flutter'ın çizecek bir şeyi kalmaz:
/// ekran kararır, geri tuşu da işlemez. Asıl sebep (bir sayfa fazladan
/// kapatan `pop` çağrıları) `busy_dialog.dart` ile kaynağında çözüldü; bu
/// gözlemci sonucu ortadan kaldırıyor.
void main() {
  testWidgets('son sayfa da kapanırsa kök ekran geri konur', (tester) async {
    final guard = NavigatorStackGuard((_) => const Scaffold(body: Text('kök')));
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [guard],
      home: const Scaffold(body: Text('kök')),
    ));
    expect(find.text('kök'), findsOneWidget);
    expect(guard.routeCount, 1);

    // Bir yerde fazladan `pop`: yığın boşalıyor.
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    navigator.pop();
    await tester.pumpAndSettle();

    // Kararan ekran YOK: kök ekran geri geldi.
    expect(find.text('kök'), findsOneWidget);
    expect(guard.routeCount, 1);
  });

  testWidgets('olağan gezinmede karışmaz', (tester) async {
    final guard = NavigatorStackGuard((_) => const Scaffold(body: Text('kök')));
    await tester.pumpWidget(MaterialApp(
      navigatorObservers: [guard],
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const Scaffold(body: Text('ikinci')),
            )),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(guard.routeCount, 2);

    tester.state<NavigatorState>(find.byType(Navigator)).pop();
    await tester.pumpAndSettle();
    // Bir sayfa kaldı: kurtarma TETİKLENMEZ, ikinci bir kök eklenmez.
    expect(guard.routeCount, 1);
    expect(find.text('aç'), findsOneWidget);
    expect(find.text('ikinci'), findsNothing);
  });
}

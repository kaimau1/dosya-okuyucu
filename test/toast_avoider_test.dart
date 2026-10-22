import 'package:dosya_okuyucu/core/snack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı 2026-10-22 (ekran görüntüsüyle): *"Bir işlem yapılma bildirimi
/// aşağıdaki menü butonlarını kapatıyor"* — 324 dosya çöpe taşınırken
/// "Çöp kutusuna taşınıyor · 18 / 324" kartı seçim çubuğunun üstüne
/// oturmuştu.
///
/// Kural: [ToastAvoider] ile sarılmış alt çubuk görünürken kart onun
/// ÜSTÜNDE durur; çubuk kalkınca (ya da üstüne başka sayfa açılınca) kart
/// yine ekranın altına iner.
void main() {
  final nav = GlobalKey<NavigatorState>();
  Widget app({required bool bar}) => MaterialApp(
        navigatorKey: nav,
        builder: (context, child) => ToastLayer(child: child!),
        home: Scaffold(
          body: const SizedBox.expand(),
          bottomNavigationBar: bar
              ? const ToastAvoider(
                  child: SizedBox(
                      height: 80, child: Text('çubuk', key: Key('bar'))),
                )
              : null,
        ),
      );

  double barTop(WidgetTester t) =>
      t.getTopLeft(find.byKey(const Key('bar'))).dy;
  double toastBottom(WidgetTester t) =>
      t.getBottomLeft(find.text('Çöp kutusuna taşınıyor')).dy;

  testWidgets('kalıcı iş kartı alt çubuğu örtmez', (tester) async {
    await tester.pumpWidget(app(bar: true));
    final h = showStickyToast(tester.element(find.byType(Scaffold)),
        const Text('Çöp kutusuna taşınıyor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(toastBottom(tester), lessThanOrEqualTo(barTop(tester)));

    // Üstüne yeni sayfa açılınca o sayfanın alt çubuğu yok → kart iner.
    nav.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: SizedBox.expand())));
    await tester.pumpAndSettle();
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(toastBottom(tester), greaterThan(screen - 60));
    h.close();
    await tester.pumpAndSettle();
  });

  testWidgets('çubuk yokken kart ekranın altında', (tester) async {
    await tester.pumpWidget(app(bar: false));
    final h = showStickyToast(tester.element(find.byType(Scaffold)),
        const Text('Çöp kutusuna taşınıyor'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final screen =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(toastBottom(tester), greaterThan(screen - 60));
    h.close();
    await tester.pumpAndSettle();
  });
}

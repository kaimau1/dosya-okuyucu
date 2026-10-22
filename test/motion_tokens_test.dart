import 'package:dosya_okuyucu/core/motion.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 15 / madde 4 + Faz 16 / madde 5: cihazın "animasyonları kaldır"
/// ayarı açıkken arayüz animasyonu süresi 0, sayfa geçişi ilk karede yerinde.
Widget _app({required bool reduce, required GlobalKey<NavigatorState> nav}) =>
    MediaQuery(
      data: MediaQueryData(disableAnimations: reduce),
      child: MaterialApp(
        navigatorKey: nav,
        theme: AppTheme.light(),
        home: const Scaffold(body: Text('ana')),
      ),
    );

void main() {
  testWidgets('Motion.of: ayar açıkken 0, kapalıyken token', (tester) async {
    late Duration on, off;
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: Builder(builder: (c) {
        on = Motion.of(c, Motion.medium);
        return const SizedBox();
      }),
    ));
    await tester.pumpWidget(MediaQuery(
      data: const MediaQueryData(),
      child: Builder(builder: (c) {
        off = Motion.of(c, Motion.medium);
        return const SizedBox();
      }),
    ));
    expect(on, Duration.zero);
    expect(off, Motion.medium);
  });

  for (final reduce in [true, false]) {
    testWidgets('sayfa geçişi (animasyonları kaldır: $reduce)', (tester) async {
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(_app(reduce: reduce, nav: nav));
      nav.currentState!.push(MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Center(child: Text('yeni')))));
      await tester.pump(); // ilk kare
      await tester.pump(const Duration(milliseconds: 16));
      final dx = tester.getCenter(find.text('yeni')).dx;
      final center = tester.getCenter(find.byType(MaterialApp)).dx;
      if (reduce) {
        expect(dx, moreOrLessEquals(center, epsilon: 0.5),
            reason: '0 ms: yeni sayfa ilk karede yerinde');
      } else {
        expect(dx, greaterThan(center + 10),
            reason: 'normalde sağdan kayarak gelir');
      }
      await tester.pumpAndSettle();
    });
  }
}

import 'package:dosya_okuyucu/core/app_icons.dart';
import 'package:dosya_okuyucu/widgets/motion.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-10-17 UI/UX turu: basma hissi, liste iskeleti, boş liste yüzü.
void main() {
  testWidgets('PressScale basılıyken küçülür, bırakınca yerine döner',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressScale(
            child: InkWell(
              onTap: () => taps++,
              child: const SizedBox(width: 120, height: 80),
            ),
          ),
        ),
      ),
    ));
    double scale() =>
        tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale;
    final gesture =
        await tester.startGesture(tester.getCenter(find.byType(InkWell)));
    await tester.pump(const Duration(milliseconds: 100));
    expect(scale(), lessThan(1));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(scale(), 1);
    // Dokunuş jest yarışmasına karışmadan yerine ulaştı.
    expect(taps, 1);
  });

  testWidgets('PressScale kaydırmada iptal olur', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: PressScale(child: SizedBox(width: 120, height: 80)),
        ),
      ),
    ));
    final gesture = await tester
        .startGesture(tester.getCenter(find.byType(SizedBox).last));
    await gesture.moveBy(const Offset(0, 30));
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
  });

  testWidgets('liste iskeleti ve boş liste yüzü çizilir', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(body: FmListSkeleton(rows: 4)),
    ));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: FmEmptyState(
          icon: AppIcons.delete,
          title: 'Çöp kutusu boş',
          hint: 'Silinenler 30 gün burada durur',
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Çöp kutusu boş'), findsOneWidget);
    expect(find.text('Silinenler 30 gün burada durur'), findsOneWidget);
  });
}

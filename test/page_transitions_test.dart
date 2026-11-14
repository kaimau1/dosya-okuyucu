import 'package:dosya_okuyucu/core/page_transitions.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Geçiş performansı** (kullanıcı isteği 2026-09-06: *"geçiş animasyonları ve
/// alan geçişlerini performans iyileştirmesi yap"*).
///
/// Ölçülen şey "kaç kare düştü" değil — o bir cihaz ölçümü. Burada geçişin
/// PAHALI OLMAYAN bir biçimde kurulduğu doğrulanıyor: opaklık (her karede
/// `saveLayer`) yok, yalnız dönüşüm var, ve süre kısaldı. Bu üçü bozulursa
/// eski davranışa sessizce geri dönülürdü.
void main() {
  test('Android sayfa geçişi hızlı olanla değiştirildi', () {
    final builders = AppTheme.light().pageTransitionsTheme.builders;
    expect(builders[TargetPlatform.android], isA<FastPageTransitionsBuilder>());
    expect(builders[TargetPlatform.windows], isA<FastPageTransitionsBuilder>());
    // Koyu tema da aynı: ayar tek yerde.
    expect(AppTheme.dark().pageTransitionsTheme.builders[TargetPlatform.android],
        isA<FastPageTransitionsBuilder>());
  });

  test('süre M3 varsayılanından (300 ms) kısa', () {
    const builder = FastPageTransitionsBuilder();
    expect(builder.transitionDuration.inMilliseconds, lessThan(300));
    expect(builder.reverseTransitionDuration.inMilliseconds,
        lessThanOrEqualTo(builder.transitionDuration.inMilliseconds));
  });

  testWidgets('geçiş yalnız KAYDIRIR — opaklık katmanı açmaz', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
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
    // Ürünün gerçek platformu Android; test varsayılanı da odur.
    await tester.tap(find.text('aç'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 80)); // geçişin ortası

    expect(find.byType(SlideTransition), findsWidgets);
    // `FadeTransition`/`ZoomPageTransitionsBuilder` opaklık kullanır: her
    // karede tüm sayfayı ayrı bir katmana çizip harmanlamak, uzun listelerde
    // geçişin en pahalı işiydi.
    expect(find.byType(FadeTransition), findsNothing);

    await tester.pumpAndSettle();
    expect(find.text('ikinci'), findsOneWidget);
  });

  // Ferrari H6.6: Android 14+ öngörülü geri — hareket sırasında sayfa
  // parmakla küçülüp alttakini gösterir; bırakınca kapanır.
  Future<void> backGesture(WidgetTester tester, String method,
      [Map<String, Object?>? args]) async {
    final msg = const StandardMethodCodec()
        .encodeMethodCall(MethodCall(method, args));
    await tester.binding.defaultBinaryMessenger
        .handlePlatformMessage('flutter/backgesture', msg, (_) {});
  }

  Map<String, Object?> event(double progress) => {
        'touchOffset': <double>[5.0, 300.0],
        'progress': progress,
        'swipeEdge': 0, // sol
      };

  Future<void> openSecond(WidgetTester tester, {bool canPop = true}) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PopScope(
                canPop: canPop,
                child: const Scaffold(body: Text('ikinci')),
              ),
            )),
            child: const Text('aç'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('aç'));
    await tester.pumpAndSettle();
    expect(find.text('aç'), findsNothing);
  }

  testWidgets('öngörülü geri: hareket sırasında önizleme, bırakınca kapanır',
      (tester) async {
    await openSecond(tester);
    await backGesture(tester, 'startBackGesture', event(0));
    await backGesture(tester, 'updateBackGestureProgress', event(0.5));
    await tester.pump();
    // İki sayfa birden görünür (alttaki ortaya çıkıyor) ve üstteki küçülmüş.
    expect(find.text('aç'), findsOneWidget);
    expect(find.text('ikinci'), findsOneWidget);
    final scaled = tester
        .widgetList<Transform>(find.ancestor(
            of: find.text('ikinci'), matching: find.byType(Transform)))
        // x ölçeği (getMaxScaleOnAxis z'yi de sayar; Transform.scale z'yi 1 bırakır).
        .where((t) => t.transform.storage[0] < 0.999);
    expect(scaled, isNotEmpty);
    // Opaklık yok (geçiş performansı kararı).
    expect(find.byType(FadeTransition), findsNothing);

    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('ikinci'), findsNothing);
    expect(find.text('aç'), findsOneWidget);
  });

  testWidgets('öngörülü geri: vazgeçince sayfa yerine döner', (tester) async {
    await openSecond(tester);
    await backGesture(tester, 'startBackGesture', event(0));
    await backGesture(tester, 'updateBackGestureProgress', event(0.4));
    await tester.pump();
    await backGesture(tester, 'cancelBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('ikinci'), findsOneWidget);
    expect(find.text('aç'), findsNothing);
  });

  testWidgets('öngörülü geri: PopScope(canPop: false) sayfayı kapatmaz',
      (tester) async {
    await openSecond(tester, canPop: false);
    await backGesture(tester, 'startBackGesture', event(0));
    await backGesture(tester, 'updateBackGestureProgress', event(0.5));
    await tester.pump();
    // Hareket üstlenilmedi: önizleme yok.
    expect(find.text('aç'), findsNothing);
    await backGesture(tester, 'commitBackGesture');
    await tester.pumpAndSettle();
    expect(find.text('ikinci'), findsOneWidget);
  });
}

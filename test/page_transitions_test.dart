import 'package:dosya_okuyucu/core/page_transitions.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:flutter/material.dart';
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
    // iOS'ta sistemin kendi kenardan geri hareketi korunuyor.
    expect(builders[TargetPlatform.iOS], isA<CupertinoPageTransitionsBuilder>());
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
}

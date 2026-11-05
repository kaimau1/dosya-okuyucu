import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget body, {double scale = 1, bool reduce = false}) => MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        AppStrings.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale), disableAnimations: reduce),
        child: child!,
      ),
      home: Scaffold(body: body),
    );

/// Faz 40 / 10: iskelet + tek tip hata yüzü.
void main() {
  for (final kind in SkeletonKind.values) {
    testWidgets('iskelet çizilir: ${kind.name}', (tester) async {
      await tester.pumpWidget(_app(AppSkeleton(kind: kind)));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      expect(find.bySemanticsLabel('Yükleniyor'), findsOneWidget);
    });
  }

  testWidgets('animasyonlar kapalıyken iskelet kare istemez (boşta 0 kare)',
      (tester) async {
    await tester.pumpWidget(_app(const AppSkeleton(), reduce: true));
    await tester.pump();
    expect(tester.binding.hasScheduledFrame, isFalse);
  });

  testWidgets('hata yüzü: ileti, yeniden dene, ayrıntıyı kopyala',
      (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied = (call.arguments as Map)['text'] as String?;
      }
      return null;
    });
    var retried = 0;
    await tester.pumpWidget(_app(AppErrorView(
      message: 'Dosya bozuk olabilir.',
      details: 'FormatException: zip',
      onRetry: () => retried++,
    )));
    expect(find.text('Açılamadı'), findsOneWidget);
    expect(find.text('Dosya bozuk olabilir.'), findsOneWidget);
    expect(find.text('FormatException: zip'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('app-error-retry')));
    expect(retried, 1);
    await tester.tap(find.byKey(const ValueKey('app-error-copy')));
    await tester.pump();
    expect(copied, 'FormatException: zip');
  });

  testWidgets('2× yazıda hata yüzü taşmaz', (tester) async {
    await tester.pumpWidget(_app(
        AppErrorView(
          message: 'Dosya bozuk, desteklenmeyen bir sürümde ya da başka bir '
              'uygulama tarafından kilitli olabilir.',
          details: 'x',
          onRetry: () {},
        ),
        scale: 2));
    expect(tester.takeException(), isNull);
  });
}

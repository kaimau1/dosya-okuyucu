import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/fm/remote/nearby_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Yakındakiler (2026-11-02 yeniden tasarım): telefonda tek sütun, geniş
/// ekranda (≥ 840 dp) iki sütun — ikisinde de taşma yok.
void main() {
  Future<void> pump(WidgetTester tester, Size size) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await tester.runAsync(state.init);
    tester.view.physicalSize = size * 2;
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: const [
          AppStrings.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const NearbyScreen(services: false),
      ),
    ));
    await tester.pump();
  }

  testWidgets('telefonda tek sütun', (tester) async {
    await pump(tester, const Size(360, 780));
    expect(find.byKey(const ValueKey('near-col-send')), findsNothing);
    expect(find.byKey(const ValueKey('near-add-files')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  // 2026-11-06: ilk sekme (hızlı aktar + QR) telefon ekranına KAYDIRMADAN
  // sığar — kullanıcı isteği "ilk sekme hızlı aktar ve qr olsun ve ekrana
  // sığsın".
  testWidgets('hızlı aktar sekmesi 360×780 ekrana sığar', (tester) async {
    await pump(tester, const Size(360, 780));
    final qr = find.byKey(const ValueKey('near-qr-idle'));
    expect(qr, findsOneWidget);
    expect(tester.getBottomLeft(qr).dy, lessThanOrEqualTo(780));
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş ekranda iki sütun', (tester) async {
    await pump(tester, const Size(1200, 800));
    expect(find.byKey(const ValueKey('near-col-send')), findsOneWidget);
    expect(find.byKey(const ValueKey('near-col-more')), findsOneWidget);
    expect(find.byKey(const ValueKey('near-add-files')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/services/fm/folder_lock.dart';
import 'package:dosya_okuyucu/widgets/app_lock_gate.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-06 denetim turu: uygulamada klasör kilidi vardı ama uygulamanın
/// KENDİSİ korumasızdı — telefonu eline alan biri bütün dosyaları
/// görebiliyordu.
void main() {
  /// `AppState.init()` GERÇEK asenkron iş yapıyor (depolama birimlerini
  /// tarıyor); `testWidgets`in sahte saat zonunda hiç tamamlanmaz ve test
  /// sonsuza kadar asılı kalır — bu deponun bilinen tuzağı
  /// (HAFIZA 2026-07-25 §F). Çözüm `tester.runAsync`.
  Future<AppState> stateWith(WidgetTester tester,
      {required bool lock, String pin = '1234'}) async {
    SharedPreferences.setMockInitialValues({
      if (pin.isNotEmpty) 'fm_lock_pin': FolderLock.hashPin(pin),
      'app_lock_on': lock,
    });
    final state = AppState();
    await tester.runAsync(state.init);
    return state;
  }

  Future<void> pump(WidgetTester tester, AppState state) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<AppState>.value(
        value: state,
        child: const MaterialApp(
          locale: Locale('tr'),
          localizationsDelegates: [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('tr')],
          home: AppLockGate(child: Scaffold(body: Text('gizli içerik'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('kilit kapalıyken ekran doğrudan açılır', (tester) async {
    await pump(tester, await stateWith(tester, lock: false));
    expect(find.text('gizli içerik'), findsOneWidget);
  });

  testWidgets('kilit açıkken içerik GÖRÜNMEZ, PIN sorulur', (tester) async {
    await pump(tester, await stateWith(tester, lock: true));
    expect(find.text('gizli içerik'), findsNothing);
    expect(find.text('Uygulama kilidi'), findsOneWidget);
  });

  testWidgets('doğru PIN içeriği açar', (tester) async {
    await pump(tester, await stateWith(tester, lock: true));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('gizli içerik'), findsOneWidget);
  });

  testWidgets('yanlış PIN içeriği AÇMAZ ve hata yazar', (tester) async {
    await pump(tester, await stateWith(tester, lock: true));
    await tester.enterText(find.byType(TextField), '9999');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('gizli içerik'), findsNothing);
    expect(find.text('PIN yanlış'), findsOneWidget);
  });

  testWidgets('beş yanlış denemeden sonra BEKLEME başlar', (tester) async {
    await pump(tester, await stateWith(tester, lock: true));
    for (var i = 0; i < 5; i++) {
      await tester.enterText(find.byType(TextField), '0000');
      await tester.tap(find.text('Tamam'));
      await tester.pump();
    }
    await tester.pump();
    // Alan kilitli ve geri sayım yazıyor: kaba kuvvet denemesi pratik değil.
    expect(find.textContaining('saniye bekleyin'), findsOneWidget);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.enabled, isFalse);

    // Bekleme dolunca yeniden denenebiliyor.
    await tester.pump(const Duration(seconds: 6));
    await tester.enterText(find.byType(TextField), '1234');
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(find.text('gizli içerik'), findsOneWidget);
  });

  test('PIN kurulu DEĞİLSE kilit açılamaz (kendini dışarıda bırakma)',
      () async {
    SharedPreferences.setMockInitialValues({'app_lock_on': true});
    final state = AppState();
    await state.init();
    // Kayıtta açık yazıyor ama PIN yok: kilit uygulanmaz.
    expect(state.appLock, isFalse);
    await state.setAppLock(true);
    expect(state.appLock, isFalse);
  });
}

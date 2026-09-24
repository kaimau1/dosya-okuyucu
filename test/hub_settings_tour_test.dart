import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/fm/ai_hub_screen.dart';
import 'package:dosya_okuyucu/screens/fm/installed_apps_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 2026-09-24 turu (kullanıcı: *"bellek analizi, ayarlar, uygulamalar, AI
/// sayfası — eksikleri gider, hataları düzelt, görsel tasarımı düzenle"*).
///
/// Kilitlenen sözler:
/// - Ayarlar'da tema tek dokunuşla değişir (hızlı seçici).
/// - AI Merkezi'nin Analiz sekmesinde "Başlat" düğmesi TEK (durum çubuğu o
///   sekmede gizli — eskiden iki düğme alt alta duruyordu).
/// - Sohbet sekme değişiminde silinmez (keep-alive).
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _wrap(AppState state, Widget home, {String locale = 'tr'}) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        locale: Locale(locale),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: home,
      ),
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('ayarlarda tema tek dokunuşla koyuya geçer', (tester) async {
    final state = AppState();
    await tester.runAsync(state.init);
    await tester.pumpWidget(_wrap(state, const SettingsScreen()));
    await tester.pump();
    expect(state.themeMode, ThemeMode.system);
    await tester.tap(find.text('Koyu'));
    await tester.pump();
    expect(state.themeMode, ThemeMode.dark);
  });

  testWidgets('AI Analiz sekmesinde tek başlat düğmesi; sohbette durum çubuğu',
      (tester) async {
    await tester.pumpWidget(_wrap(AppState(), const AiHubScreen()));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('Analizi başlat'), findsOneWidget);

    // Sohbet sekmesinde durum çubuğu (ve onun düğmesi) geri gelir.
    await tester.tap(find.text('Sohbet'));
    await tester.pumpAndSettle();
    expect(find.text('Analizi başlat'), findsOneWidget);
  });

  testWidgets('sohbet sekme değişince silinmez', (tester) async {
    await tester.pumpWidget(_wrap(AppState(), const AiHubScreen()));
    await tester.pump();
    await tester.tap(find.text('Sohbet'));
    await tester.pumpAndSettle();
    // Anahtarsız gönderim bir uyarı verir ama yazılan metin kutuda kalır:
    // keep-alive'ı kutudaki metinle ölçüyoruz.
    await tester.enterText(find.byType(TextField), 'faturalarım');
    // Odak BIRAKILIR: odaktaki `EditableText` kendini zaten canlı tutuyor —
    // odak açık kalsaydı test keep-alive olmadan da geçerdi. Gerçek kullanımda
    // da mesaj gönderildikten sonra klavye kapanıyor.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    await tester.tap(find.text('Rapor'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sohbet'));
    await tester.pumpAndSettle();
    expect(find.text('faturalarım'), findsOneWidget);
  });

  /// "N uygulama" sayacı Türkçe SABİTTİ (`'${n} uygulama'`); İngilizce ve
  /// Arapça arayüzde de Türkçe yazıyordu.
  testWidgets('uygulama sayacı arayüz dilinde yazar', (tester) async {
    await tester.pumpWidget(
        _wrap(AppState(), const InstalledAppsScreen(), locale: 'en'));
    // Eklenti test ortamında yok → liste boş döner; yükleme bitene dek bekle.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump();
    }
    expect(tester.takeException(), isNull);
    expect(find.text('0 apps'), findsOneWidget);
    expect(find.textContaining('uygulama'), findsNothing);
  });
}

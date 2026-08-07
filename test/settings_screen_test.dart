import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.pumpWidget(
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: const MaterialApp(
        locale: Locale('tr'),
        supportedLocales: [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: SettingsScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('ayarlar simgeli gruplara bölünmüş, her grubun açıklaması var',
      (tester) async {
    // 2026-08-07 kullanıcı: "ayarlar kısmı eskidi, görsel ve mantıksal olarak
    // düzenlenmeli". Bölümler artık başlıksız bileşen yığını değil, kart.
    await _pump(tester);
    expect(find.byType(SettingsGroup), findsWidgets);
    expect(find.text('Görünüm ve dil'), findsOneWidget);
    expect(find.text('Tema ve arayüz dili'), findsOneWidget);
  });

  testWidgets('tema ve DİL aynı grupta (ikisi de "arayüz")', (tester) async {
    await _pump(tester);
    final group = find.ancestor(
      of: find.text('Görünüm ve dil'),
      matching: find.byType(SettingsGroup),
    );
    expect(group, findsOneWidget);
    // Dil seçimi artık ayrı bir bölüm değil, bu grubun içinde.
    expect(
      find.descendant(of: group, matching: find.text('Dil')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: group, matching: find.text('Tema')),
      findsOneWidget,
    );
  });

  testWidgets('dosya yöneticisi ayarlarına köprü var', (tester) async {
    // O ekran yalnız gezgin panosundan açılabiliyordu.
    await _pump(tester);
    await tester.dragUntilVisible(
      find.text('Dosya yöneticisi'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Dosya yöneticisi ayarlarını aç'), findsOneWidget);
  });

  testWidgets('arama bölümleri süzer', (tester) async {
    await _pump(tester);
    await tester.tap(find.byIcon(Icons.search));
    await tester.pump();
    await tester.enterText(find.byType(TextField).first, 'dosya');
    await tester.pump();
    expect(find.text('Dosya yöneticisi'), findsOneWidget);
    expect(find.text('Görünüm ve dil'), findsNothing);
  });
}

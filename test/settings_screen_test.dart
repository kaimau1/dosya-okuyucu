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
  testWidgets('yazı boyutu hazır kademelerle seçilebiliyor', (tester) async {
    // Kullanıcı isteği 2026-08-07: "küçük orta büyük çok büyük şeklinde kolay
    // seçimde olsun".
    await _pump(tester);
    expect(find.text('Küçük'), findsOneWidget);
    expect(find.text('Orta'), findsOneWidget);
    expect(find.text('Büyük'), findsOneWidget);
    expect(find.text('Çok büyük'), findsOneWidget);
  });

  testWidgets('yazı tipi listesi örnek satırlarıyla açılıyor', (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Yazı tipi'));
    await tester.pumpAndSettle();
    // Her seçenek kendi yazı tipiyle + Türkçe örnek satırla listeleniyor.
    expect(find.text('Merriweather'), findsOneWidget);
    expect(find.textContaining('Örnek:'), findsWidgets);
  });

  testWidgets('pil ve başarım bölümü iki anahtarla geliyor', (tester) async {
    // 2026-08-07 denetimi: 120 Hz ekran ve 12 saatlik tam depolama taraması
    // koşulsuz açıktı; ikisi de kapatılabilir olmalı.
    await _pump(tester);
    await tester.dragUntilVisible(
      find.text('Pil ve başarım'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    final group = find.ancestor(
      of: find.text('Pil ve başarım'),
      matching: find.byType(SettingsGroup),
    );
    expect(group, findsOneWidget);
    expect(
      find.descendant(of: group, matching: find.text('Yüksek tazeleme hızı')),
      findsOneWidget,
    );
    expect(
      find.descendant(
          of: group, matching: find.text('Otomatik yeniden tarama')),
      findsOneWidget,
    );
  });

  test('tazeleme hızı ve otomatik tarama varsayılan AÇIK ve diske yazılıyor',
      () async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    await state.init();
    // Varsayılanlar: uygulamanın satır başı hız hissi bozulmasın.
    expect(state.highRefreshRate, isTrue);
    expect(state.autoRescan, isTrue);

    await state.setAutoRescan(false);
    await state.setHighRefreshRate(false);

    // Tercih diske yazılıyor: yeni bir oturum onu okumalı.
    final reloaded = AppState();
    await reloaded.init();
    expect(reloaded.autoRescan, isFalse);
    expect(reloaded.highRefreshRate, isFalse);
  });

  testWidgets('anahtara dokunmak tercihi DEĞİŞTİRİYOR', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    // `init()` gerçek asenkron iş: sahte saat zonunda tamamlanmaz
    // (HAFIZA 2026-07-25 §F tuzağı) → gerçek zonda koşturulur.
    await tester.runAsync(state.init);

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
    await tester.dragUntilVisible(
      find.text('Otomatik yeniden tarama'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(state.autoRescan, isTrue);
    // `dragUntilVisible` satırı ekranın ALT KENARINA getirebiliyor; dokunma
    // noktası görünür alanın dışında kalırsa tıklama düşer.
    await tester.ensureVisible(find.text('Otomatik yeniden tarama'));
    await tester.pump();
    await tester.tap(find.text('Otomatik yeniden tarama'));
    await tester.pump();
    expect(state.autoRescan, isFalse);
  });
}

import 'package:dosya_okuyucu/core/app_state.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:dosya_okuyucu/screens/settings/settings_catalog.dart';
import 'package:dosya_okuyucu/screens/settings/settings_category_screen.dart';
import 'package:dosya_okuyucu/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// **Ayarların 2026-08-09 yeniden tasarımı.**
///
/// Kullanıcı: *"ayarlar kısmımız çok karıştı her yer her yerde tamamen 0 dan
/// tasarlanmalı ve yerleştirilmeli"*. Ayarlar iki ekrana (`SettingsScreen` +
/// `FmSettingsScreen`) bölünmüştü ve her ikisinde de arama YALNIZ bölüm
/// başlığına bakıyordu — "küçük resim" yazan kullanıcı hiçbir sonuç bulamıyordu.
///
/// Bu dosya yeni yerleşimin taşıyıcı sözlerini kilitler: tek giriş, sekiz
/// kategori, kartta mevcut değer ve SATIR düzeyinde arama.
const _delegates = <LocalizationsDelegate<Object?>>[
  AppStrings.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

Widget _wrap(AppState state, Widget home) =>
    ChangeNotifierProvider<AppState>.value(
      value: state,
      child: MaterialApp(
        locale: const Locale('tr'),
        supportedLocales: const [Locale('tr'), Locale('en'), Locale('ar')],
        localizationsDelegates: _delegates,
        home: home,
      ),
    );

Future<AppState> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final state = AppState();
  await tester.pumpWidget(_wrap(state, const SettingsScreen()));
  await tester.pump();
  return state;
}

/// Kimliğinden kategori bulur (çeviriden bağımsız).
SettingsCategory _category(String id) =>
    settingsCategories().firstWhere((c) => c.id == id);

void main() {
  testWidgets('ayarlar TEK ekranda, sekiz kategori kartı olarak duruyor',
      (tester) async {
    await _pump(tester);
    // Kategoriler kartlar hâlinde; ana ekran açık bölümlerin üst üste yığıldığı
    // üç ekran boyu bir liste değil.
    expect(settingsCategories().length, 8);
    expect(find.text('Görünüm ve dil'), findsOneWidget);
    expect(find.text('Dosya listeleri'), findsOneWidget);
    expect(find.text('Yapay zekâ'), findsOneWidget);
  });

  testWidgets('kart mevcut değeri gösterir (açmadan ne ayarlı görülüyor)',
      (tester) async {
    await _pump(tester);
    // Varsayılan tema "Sistem", dil "Sistem" → kartta ikisi de yazar.
    expect(find.text('Sistem · Sistem'), findsOneWidget);
  });

  /// **Kök neden testi:** eski arama BÖLÜM başlığına bakıyordu; "küçük resim"
  /// bir bölüm değil bir satır olduğu için hiç bulunamıyordu. Üstelik o satır
  /// ÖTEKİ ekrandaydı (dosya yöneticisi ayarları) — arama onu görmüyordu bile.
  testWidgets('arama SATIR düzeyinde ve tüm kategorilerde çalışır',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'küçük resim');
    await tester.pump();

    // Ayarın kendisi sonuçta: anahtarıyla birlikte, kategorisinin altında.
    expect(find.text('Küçük resimler'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    // Eşleşmeyen kategoriler listede yok.
    expect(find.text('Yapay zekâ'), findsNothing);
  });

  testWidgets('sonuçtaki anahtar doğrudan çalışır (sayfaya gitmek gerekmez)',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = AppState();
    // `init()` gerçek asenkron iş: sahte saat zonunda tamamlanmaz
    // (HAFIZA 2026-07-25 §F tuzağı) → gerçek zonda koşturulur.
    await tester.runAsync(state.init);
    await tester.pumpWidget(_wrap(state, const SettingsScreen()));
    await tester.pump();
    expect(state.fmThumbnails, isTrue);
    await tester.enterText(find.byType(TextField).first, 'küçük resim');
    await tester.pump();
    await tester.tap(find.byType(Switch));
    await tester.pump();
    expect(state.fmThumbnails, isFalse);
  });

  testWidgets('eşleşme yoksa açıkça söylenir', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'zzzz');
    await tester.pump();
    expect(find.text('Eşleşen ayar yok'), findsOneWidget);
  });

  testWidgets('karta dokunmak kategorinin kendi sayfasını açar',
      (tester) async {
    await _pump(tester);
    await tester.tap(find.text('Görünüm ve dil'));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsCategoryScreen), findsOneWidget);
    // Tema, yazı ve dil AYNI kategoride: üçü de "uygulama bana nasıl görünsün"
    // sorusunun cevabı (eskiden dil ayrı bir bölümdü).
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Yazı tipi'), findsOneWidget);
    expect(find.text('Dil'), findsOneWidget);
  });

  testWidgets('yazı boyutu hazır kademelerle seçilebiliyor', (tester) async {
    // Kullanıcı isteği 2026-08-07: "küçük orta büyük çok büyük şeklinde kolay
    // seçimde olsun".
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(AppState(),
        SettingsCategoryScreen(category: _category('appearance'))));
    await tester.pump();
    expect(find.text('Küçük'), findsOneWidget);
    expect(find.text('Orta'), findsOneWidget);
    expect(find.text('Büyük'), findsOneWidget);
    expect(find.text('Çok büyük'), findsOneWidget);
  });

  testWidgets('yazı tipi listesi örnek satırlarıyla açılıyor', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(AppState(),
        SettingsCategoryScreen(category: _category('appearance'))));
    await tester.pump();
    await tester.tap(find.text('Yazı tipi'));
    await tester.pumpAndSettle();
    // Her seçenek KENDİ yazı tipiyle + Türkçe örnek satırla listeleniyor.
    expect(find.text('Merriweather'), findsOneWidget);
    expect(find.textContaining('Örnek:'), findsWidgets);
  });

  /// Dosya yöneticisi ayarları ayrı bir ekran DEĞİL artık: yerleşim, sıralama,
  /// küçük resim ve açılış klasörü "Dosya listeleri" kategorisinde.
  testWidgets('dosya yöneticisi ayarları da aynı ekranda', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(_wrap(
        AppState(), SettingsCategoryScreen(category: _category('browsing'))));
    await tester.pump();
    expect(find.text('Dosya listesi görünümü'), findsOneWidget);
    expect(find.text('Varsayılan sıralama'), findsOneWidget);
    expect(find.text('Küçük resimler'), findsOneWidget);
    await tester.dragUntilVisible(
      find.text('Açılış klasörü'),
      find.byType(ListView),
      const Offset(0, -200),
    );
    expect(find.text('Açılış klasörü'), findsOneWidget);
  });

  test('her ayar satırının kimliği TEK ve her kategori en az bir satır taşır',
      () {
    final ids = <String>[];
    for (final category in settingsCategories()) {
      expect(category.rows, isNotEmpty, reason: '${category.id} boş');
      ids.addAll(category.rows.map((r) => r.id));
    }
    expect(ids.toSet().length, ids.length, reason: 'yinelenen ayar kimliği');
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
}

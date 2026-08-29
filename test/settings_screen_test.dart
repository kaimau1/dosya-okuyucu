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
  testWidgets('ayarlar TEK ekranda, YEDİ kategori kartı olarak duruyor',
      (tester) async {
    await _pump(tester);
    // 2026-08-29: sekizden yediye indi. "Hesap & Senkron" tek satırlık ayrı
    // bir kategoriydi → Gizlilik'e; "Çöp kutusu" ve "Pil/başarım" dörder
    // satırdı ve ikisi de "yer ve hız" sorusuna bakıyordu → tek kategori.
    // Yerine gerçekten eksik olan bir kategori geldi: Okuma ve sesli okuma.
    expect(settingsCategories().length, 7);
    expect(find.text('Görünüm ve dil'), findsOneWidget);
    expect(find.text('Dosya listeleri'), findsOneWidget);
    expect(find.text('Yapay zekâ'), findsOneWidget);
  });

  test('birleştirilen kategoriler kayıp satır bırakmadı', () {
    final ids = {
      for (final c in settingsCategories())
        for (final r in c.rows) r.id,
    };
    // Eski sekiz kategorideki HER satır yeni yapıda da var (birleşme kayıp
    // demek olmamalı — kullanıcı isteği: "bize özellik kaybettirme").
    for (final id in [
      'skin', 'theme', 'background', 'ui_font', 'ui_text_size', 'language',
      'list_layout', 'default_sort', 'show_hidden', 'thumbnails',
      'photo_grid', 'photo_group', 'media_open_with', 'start_folder',
      'api_key', 'ai_backup_keys', 'ai_model_chain', 'ai_pool_status',
      'ai_excluded', 'ai_types', 'ai_privacy', 'ai_budget', 'memory',
      'account', 'privacy_policy', 'pin', 'locked_folders', 'full_access',
      'usage_access', 'use_trash', 'confirm_delete', 'trash_auto',
      'empty_trash', 'high_refresh', 'auto_rescan', 'search_index',
      'thumb_cache', 'volumes', 'about', 'crash_log',
    ]) {
      expect(ids, contains(id), reason: '$id kategorilerden düşmüş');
    }
    // Yeni: sesli okuma ayarları artık Ayarlar'da (eskiden yalnız okuyucu
    // ekranının içindeki alt sayfadan ulaşılabiliyordu).
    expect(ids, contains('tts_voice'));
    expect(ids, contains('tts_ai_read'));
  });

  test('gelişmiş bölümler işaretli ve içleri dolu', () {
    final advanced = [
      for (final c in settingsCategories())
        for (final s in c.sections)
          if (s.advanced) ...s.rows.map((r) => r.id),
    ];
    // Uzman işi satırlar Gelişmiş'e indi ama SİLİNMEDİ.
    expect(advanced, containsAll(['ai_model_chain', 'ai_budget', 'volumes']));
  });

  testWidgets('kart mevcut değeri gösterir (açmadan ne ayarlı görülüyor)',
      (tester) async {
    await _pump(tester);
    // Varsayılan tema ailesi "Kağıt", mod "Sistem", dil "Sistem" → üçü de
    // kartta yazar (aile 2026-08-25'te eklendi: `AppSkin`).
    expect(find.text('Kağıt · Sistem · Sistem'), findsOneWidget);
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

  /// **2026-08-29 arama turu.** Kullanıcı: *"ayar arama iyi çalışmalı"*.
  testWidgets('arama Türkçe harf yazılmadan da bulur', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'kucuk resim');
    await tester.pump();
    expect(find.text('Küçük resimler'), findsOneWidget);
  });

  testWidgets('arayüz Türkçeyken İNGİLİZCE adıyla da bulunur',
      (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'thumbnail');
    await tester.pump();
    expect(find.text('Küçük resimler'), findsOneWidget);
  });

  testWidgets('gelişmiş bölümdeki ayar da aramada çıkar', (tester) async {
    // Gelişmiş SAKLAMAK değil sıralamak içindi; arama onları da bulmalı.
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'model');
    await tester.pump();
    expect(find.text('Model sırası'), findsWidgets);
  });

  testWidgets('açıklamada geçen sözcük de ayarı bulur', (tester) async {
    await _pump(tester);
    await tester.enterText(find.byType(TextField).first, 'gizli');
    await tester.pump();
    expect(find.text('Gizli dosyaları göster'), findsOneWidget);
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
    expect(find.text('Tema ailesi'), findsOneWidget);
    expect(find.text('Tema'), findsOneWidget);
    expect(find.text('Yazı tipi'), findsOneWidget);
    // Kategori 2026-08-25'te "Tema ailesi" ve "Arka plan rengi" satırlarıyla
    // uzadı; "Dil" artık ilk ekranın altında kalıyor, kaydırıp bakıyoruz.
    await tester.scrollUntilVisible(find.text('Dil'), 200,
        scrollable: find.byType(Scrollable).first);
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

  test('eski kategori kimlikleri yeni sayfaya eşleniyor', () {
    // Ekranlardaki "ayarlara git" bağlantıları eski kimliklerle yazılmıştı;
    // birleştirme sonrası hâlâ doğru sayfayı açmalı.
    final ids = settingsCategories().map((c) => c.id).toSet();
    expect(ids, containsAll(['appearance', 'browsing', 'reading', 'ai',
        'privacy', 'storage', 'about']));
    expect(ids.contains('trash'), isFalse);
  });
}

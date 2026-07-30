import 'dart:io';

import 'package:dosya_okuyucu/core/l10n/app_language.dart';
import 'package:dosya_okuyucu/core/l10n/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// `{ad}` biçimindeki yer tutucular.
Set<String> _vars(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  group('AppStrings tablosu', () {
    test('her anahtarın üç dili de dolu', () {
      const langs = [AppLanguage.tr, AppLanguage.en, AppLanguage.ar];
      for (final key in AppStrings.keys) {
        for (final lang in langs) {
          final value = AppStrings(lang).t(key);
          expect(value.trim(), isNotEmpty,
              reason: '$key · ${lang.code} boş');
          expect(value, isNot(key),
              reason: '$key · ${lang.code} çevrilmemiş (anahtarın kendisi)');
        }
      }
    });

    test('yer tutucular üç dilde AYNI', () {
      // Bir dilde `{error}` yazıp diğerinde unutmak, o dilde hatayı GİZLER.
      for (final key in AppStrings.keys) {
        final tr = _vars(const AppStrings(AppLanguage.tr).t(key));
        final en = _vars(const AppStrings(AppLanguage.en).t(key));
        final ar = _vars(const AppStrings(AppLanguage.ar).t(key));
        expect(en, tr, reason: '$key · İngilizce yer tutucuları farklı');
        expect(ar, tr, reason: '$key · Arapça yer tutucuları farklı');
      }
    });

    test('yer tutucu doldurma çalışır', () {
      expect(
        const AppStrings(AppLanguage.en).t('home.time_minutes', {'n': 5}),
        '5 min ago',
      );
      expect(
        const AppStrings(AppLanguage.tr)
            .t('common.open_failed', {'error': 'X'}),
        'Açılamadı: X',
      );
    });

    test('kodda kullanılan HER anahtar tabloda var', () {
      // `context.t('x')` / `.t('x', …)` çağrılarını tarar. Yazım hatası
      // ekranda anahtarın kendisini gösterirdi; burada derlemeden yakalanır.
      final used = <String, String>{}; // anahtar → bulunduğu dosya
      final pattern = RegExp(r"""\.t\(\s*'([a-z0-9_]+\.[a-z0-9_]+)'""");
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        for (final m in pattern.allMatches(entity.readAsStringSync())) {
          used[m.group(1)!] = entity.path;
        }
      }
      expect(used, isNotEmpty, reason: 'tarama hiç çağrı bulamadı');
      final missing = {
        for (final e in used.entries)
          if (!AppStrings.keys.contains(e.key)) e.key: e.value,
      };
      expect(missing, isEmpty, reason: 'tabloda olmayan anahtarlar: $missing');
    });
  });

  group('dil çözümü', () {
    test('sistem dili desteklenmiyorsa Türkçe', () {
      expect(
        AppLanguageInfo.resolve(AppLanguage.system, const Locale('de')),
        AppLanguage.tr,
      );
      expect(
        AppLanguageInfo.resolve(AppLanguage.system, const Locale('ar')),
        AppLanguage.ar,
      );
      // Açık seçim cihaz dilini EZER.
      expect(
        AppLanguageInfo.resolve(AppLanguage.en, const Locale('ar')),
        AppLanguage.en,
      );
    });

    test('kod ↔ dil gidiş-dönüşü', () {
      for (final lang in AppLanguage.values) {
        expect(AppLanguageInfo.byCode(lang.code), lang);
      }
      expect(AppLanguageInfo.byCode(null), AppLanguage.system);
      expect(AppLanguageInfo.byCode('de'), AppLanguage.system);
    });

    test('yalnız Arapça sağdan sola', () {
      expect(AppLanguage.ar.direction, TextDirection.rtl);
      expect(AppLanguage.tr.direction, TextDirection.ltr);
      expect(AppLanguage.en.direction, TextDirection.ltr);
    });
  });

  group('MaterialApp bağlantısı', () {
    Widget app(AppLanguage lang) => MaterialApp(
          locale: lang.locale,
          supportedLocales: AppLanguageInfo.supportedLocales,
          // Üründeki (main.dart) delege listesinin AYNISI: `Default*`
          // delegeleri yalnız İngilizce destekler, onlarla kurulan test
          // Arapça'da sessizce İngilizce'ye düşerdi.
          localizationsDelegates: const [
            AppStrings.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(builder: (ctx) => Text(ctx.t('home.tab_files'))),
        );

    testWidgets('İngilizce seçilince metin İngilizce', (tester) async {
      await tester.pumpWidget(app(AppLanguage.en));
      expect(find.text('Files'), findsOneWidget);
    });

    testWidgets('Arapça seçilince metin Arapça VE yön sağdan sola',
        (tester) async {
      await tester.pumpWidget(app(AppLanguage.ar));
      expect(find.text('الملفات'), findsOneWidget);
      final dir = Directionality.of(
          tester.element(find.byType(Text).first));
      expect(dir, TextDirection.rtl);
    });

    testWidgets('sistem dili desteklenmiyorsa Türkçe çizilir', (tester) async {
      // locale null + cihaz Almanca → supportedLocales'in İLKİ (tr).
      tester.platformDispatcher.localesTestValue = const [Locale('de')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      await tester.pumpWidget(app(AppLanguage.system));
      expect(find.text('Dosyalar'), findsOneWidget);
    });
  });
}

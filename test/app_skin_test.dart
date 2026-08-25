import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';

/// **Tema aileleri** (kullanıcı isteği 2026-08-25): kağıt / açık / modern /
/// iş programı / gece. Aile yalnız renk değil köşe, simge ölçeği ve satır
/// sıklığı da değiştirir — buradaki testler o sözleşmeyi sabitler.
void main() {
  group('palet basamakları', () {
    test('her ailede hiyerarşi kurulu: zemin ile kart ayrı, mürekkep okunur',
        () {
      for (final skin in AppSkin.values) {
        for (final brightness in Brightness.values) {
          final palette = SkinPalette.of(skin, brightness);
          final bg = palette.bg.computeLuminance();
          final ink = palette.ink.computeLuminance();
          // Metin ile zemin arasında gerçek bir fark olmalı, yoksa ekran
          // okunmaz — bu, yeni bir aile eklerken en kolay kaçırılan şey.
          expect((bg - ink).abs(), greaterThan(0.4),
              reason: '$skin/$brightness: mürekkep zeminden ayrışmıyor');
        }
      }
    });

    test('gece ailesi açık parlaklıkta da SİYAH kalır (OLED)', () {
      final light = SkinPalette.of(AppSkin.night, Brightness.light);
      expect(light.bg, const Color(0xFF000000));
      expect(AppSkin.night.forcesDark, isTrue);
    });

    test('kağıt ailesi eski paletin kendisi (görünüm değişmedi)', () {
      final paper = SkinPalette.of(AppSkin.paper, Brightness.light);
      expect(paper.bg, const Color(0xFFFEFEFC));
      expect(paper.ink, const Color(0xFF262219));
      expect(paper.accent, const Color(0xFF2E5AA8));
    });
  });

  group('arka plan rengi', () {
    test('koyu bir zemin seçilince mürekkep AÇIĞA döner (okunurluk korunur)',
        () {
      final paper = SkinPalette.of(AppSkin.paper, Brightness.light);
      final navy = AppBackground.byId('navy');
      final applied = paper.withBackground(navy.dark); // koyu lacivert
      expect(applied.bg, navy.dark);
      expect(applied.ink.computeLuminance(),
          greaterThan(applied.bg.computeLuminance() + 0.4));
    });

    test('zemin değişince kart/şerit basamakları da birlikte taşınır', () {
      final paper = SkinPalette.of(AppSkin.paper, Brightness.light);
      final applied = paper.withBackground(const Color(0xFFFFFFFF));
      // Basamaklar tersine dönmemeli: kart hâlâ zeminden ayrı bir yüzey.
      expect(applied.card, isNot(applied.bg));
    });

    test('varsayılan seçenek hiçbir şey uygulamaz', () {
      expect(AppBackground.byId('default').isDefault, isTrue);
      expect(AppBackground.byId('bilinmeyen').isDefault, isTrue);
      expect(AppBackground.values.length, 12);
    });
  });

  group('ölçüler', () {
    test('iş programı sıkı ve küçük, modern rahat ve büyük', () {
      final office = SkinMetrics.of(AppSkin.office);
      final modern = SkinMetrics.of(AppSkin.modern);
      expect(office.iconScale, lessThan(1));
      expect(modern.iconScale, greaterThan(1));
      expect(office.radiusCard, lessThan(modern.radiusCard));
      expect(office.rowPadding, lessThan(modern.rowPadding));
    });
  });

  group('tema kurulumu', () {
    test('seçilen aile ThemeData\'ya işler', () {
      final theme = AppTheme.light(skin: AppSkin.modern);
      final data = theme.extension<AppSkinData>()!;
      expect(data.skin, AppSkin.modern);
      expect(theme.colorScheme.surface,
          SkinPalette.of(AppSkin.modern, Brightness.light).bg);
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
    });

    test('gece ailesi AÇIK istense bile koyu ThemeData üretir', () {
      final theme = AppTheme.light(skin: AppSkin.night);
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.surface, const Color(0xFF000000));
    });

    test('arka plan seçimi ThemeData zeminine geçer', () {
      final theme = AppTheme.light(skin: AppSkin.light, background: 'mint');
      expect(theme.colorScheme.surface, AppBackground.byId('mint').light);
    });

    testWidgets('uzantı yoksa kağıt varsayılanına düşülür (test/izole widget)',
        (tester) async {
      late AppSkinData seen;
      await tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          seen = AppSkinData.of(context);
          return const SizedBox();
        }),
      ));
      expect(seen.skin, AppSkin.paper);
    });
  });
}

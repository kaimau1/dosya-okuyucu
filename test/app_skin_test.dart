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

    // 2026-11-04 "masa ve kâğıt" (Notlar TEMA_PLANI): açık temalarda kart
    // zeminden AÇIK, zemin beyaz değil (parlamaz).
    test('masa ve kâğıt: açık ailelerde kart zeminden açık, zemin beyaz değil',
        () {
      for (final skin in [
        AppSkin.sage,
        AppSkin.porcelain,
        AppSkin.clay,
        AppSkin.lavender,
        AppSkin.straw,
        AppSkin.mint,
      ]) {
        final p = SkinPalette.of(skin, Brightness.light);
        expect(p.card.computeLuminance(),
            greaterThan(p.bg.computeLuminance()),
            reason: '$skin: kart zeminden koyu');
        expect(p.bg, isNot(const Color(0xFFFFFFFF)));
        expect(p.bg.computeLuminance(), lessThan(0.9), reason: '$skin');
      }
      final sage = SkinPalette.of(AppSkin.sage, Brightness.light);
      expect(sage.bg, const Color(0xFFEAF0EB));
      expect(sage.accent, const Color(0xFF106561));
    });
  });

  group('arka plan rengi', () {
    test('koyu bir zemin seçilince mürekkep AÇIĞA döner (okunurluk korunur)',
        () {
      final paper = SkinPalette.of(AppSkin.sage, Brightness.light);
      final navy = AppBackground.byId('navy');
      final applied = paper.withBackground(navy.dark); // koyu lacivert
      expect(applied.bg, navy.dark);
      expect(applied.ink.computeLuminance(),
          greaterThan(applied.bg.computeLuminance() + 0.4));
    });

    test('zemin değişince kart/şerit basamakları da birlikte taşınır', () {
      final paper = SkinPalette.of(AppSkin.sage, Brightness.light);
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
    test('modern rahat ve büyük, Adaçayı ölçüsü sade', () {
      final paper = SkinMetrics.of(AppSkin.sage);
      final modern = SkinMetrics.of(AppSkin.modern);
      expect(paper.iconScale, 1);
      expect(modern.iconScale, greaterThan(1));
      expect(paper.radiusCard, lessThan(modern.radiusCard));
      expect(paper.rowPadding, lessThan(modern.rowPadding));
    });
  });

  // 2026-10-29: "kırık beyaz ama mavi olmasın" → 2026-11-04 Adaçayı devraldı.
  test('Adaçayı: vurgu mavi DEĞİL ve okunur', () {
    for (final b in Brightness.values) {
      final p = SkinPalette.of(AppSkin.sage, b);
      final hsv = HSVColor.fromColor(p.accent);
      expect(hsv.hue < 190 || hsv.hue > 260, isTrue,
          reason: 'vurgu mavi tonunda: ${hsv.hue}');
      double ratio(Color a, Color c) {
        final l1 = a.computeLuminance(), l2 = c.computeLuminance();
        final hi = l1 > l2 ? l1 : l2, lo = l1 > l2 ? l2 : l1;
        return (hi + 0.05) / (lo + 0.05);
      }

      expect(ratio(p.accent, p.onAccent), greaterThanOrEqualTo(4.5));
      expect(ratio(p.ink, p.bg), greaterThanOrEqualTo(7));
      expect(ratio(p.inkSoft, p.card), greaterThanOrEqualTo(4.5));
    }
    final light = SkinPalette.of(AppSkin.sage, Brightness.light);
    expect(light.bg, isNot(const Color(0xFFFFFFFF)));
    expect(light.bg.computeLuminance(), greaterThan(0.8));
  });

  group('sadeleşme göçü (2026-10-21)', () {
    test('dört aile kalır (+ Faz 19 "Sistem rengi", yalnız Android 12+)', () {
      expect(AppSkin.values, [
        AppSkin.sage,
        AppSkin.porcelain,
        AppSkin.clay,
        AppSkin.lavender,
        AppSkin.olive,
        AppSkin.white,
        AppSkin.straw,
        AppSkin.cream,
        AppSkin.peach,
        AppSkin.mint,
        AppSkin.modern,
        AppSkin.classic,
        AppSkin.ledger,
        AppSkin.night,
        AppSkin.system,
      ]);
      expect(AppSkin.system.available, isFalse, reason: 'testte renk yok');
    });

    test('kaldırılan aile en yakın karşılığa taşınır, seçim sıfırlanmaz', () {
      expect(AppSkin.byName('office'), AppSkin.porcelain);
      expect(AppSkin.byName('graphite'), AppSkin.porcelain);
      // 2026-11-04 (K2): eski açık aileler yeni ailelere eşlenir.
      expect(AppSkin.byName('ivory'), AppSkin.sage);
      expect(AppSkin.byName('light'), AppSkin.porcelain);
      expect(AppSkin.byName('paper'), AppSkin.clay);
      for (final colorful in ['ocean', 'sunset', 'forest', 'rose']) {
        expect(AppSkin.byName(colorful), AppSkin.modern, reason: colorful);
      }
      expect(AppSkin.byName('night'), AppSkin.night);
      expect(AppSkin.byName('bilinmeyen'), AppSkin.sage);
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
      final theme = AppTheme.light(skin: AppSkin.porcelain, background: 'mint');
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
      expect(seen.skin, AppSkin.sage);
    });
  });
}

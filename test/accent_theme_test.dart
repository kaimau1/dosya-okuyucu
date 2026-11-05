import 'dart:math' as math;

import 'package:dosya_okuyucu/core/skin.dart';
import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/screens/settings/tiles_appearance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// Faz 40 / 8: vurgu rengi + tema ön ayarları; kontrast bekçisi.
void main() {
  test('vurgu seçimi birincil rengi değiştirir, varsayılan dokunmaz', () {
    final base = AppTheme.light();
    expect(AppTheme.light(accent: 'default').colorScheme.primary,
        base.colorScheme.primary);
    expect(AppTheme.light(accent: 'blue').colorScheme.primary,
        AppAccent.byId('blue').light);
    expect(AppTheme.dark(accent: 'blue').colorScheme.primary,
        AppAccent.byId('blue').dark);
    expect(AppAccent.byId('yok').isDefault, isTrue);
  });

  for (final skin in AppSkin.values) {
    for (final b in Brightness.values) {
      if (skin.forcesDark && b == Brightness.light) continue;
      test('vurgular okunur: ${skin.name}/${b.name}', () {
        final fails = <String>[];
        for (final a in AppAccent.values) {
          for (final bg in [AppBackground.values.first, ...AppBackground.values]) {
            final t = b == Brightness.light
                ? AppTheme.light(skin: skin, accent: a.id, background: bg.id)
                : AppTheme.dark(skin: skin, accent: a.id, background: bg.id);
            final s = t.colorScheme;
            void need(String what, double r, double min) {
              if (r < min) {
                fails.add('${a.id}/${bg.id} $what ${r.toStringAsFixed(2)}');
              }
            }

            if (a.isDefault) continue; // ailenin kendisi contrast_test'te
            need('onPrimary', _contrast(s.onPrimary, s.primary), 4.5);
            need('primary/surface', _contrast(s.primary, s.surface), 3);
            need('onPrimaryContainer',
                _contrast(s.onPrimaryContainer, s.primaryContainer), 4.5);
          }
        }
        expect(fails, isEmpty);
      });
    }
  }

  test('ön ayar eşleşmesi', () {
    expect(ThemePresetTile.currentId(AppSkin.night, ThemeMode.light), 'amoled');
    expect(ThemePresetTile.currentId(AppSkin.clay, ThemeMode.light), 'paper');
    expect(ThemePresetTile.currentId(AppSkin.sage, ThemeMode.dark), 'dark');
    expect(ThemePresetTile.currentId(AppSkin.modern, ThemeMode.dark), isNull);
  });
}

import 'dart:math' as math;

import 'package:dosya_okuyucu/core/app_colors.dart';
import 'package:dosya_okuyucu/core/skin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Kontrast bekçisi** (Faz 15 / madde 5, WCAG 2.x).
///
/// Her tema ailesi × açık/koyu için: metin rolleri zeminlerin HER basamağında
/// (sayfa, kart, şerit) ≥ 4,5:1; simge/kenar taşıyan roller (vurgu, tehlike,
/// başarı, uyarı, bilgi) ≥ 3:1. Kök neden: `inkFaint` (yol, sayaç, zaman
/// damgası) kağıt temada sayfa üstünde ~3,9:1'di — "soluk" olsun derken
/// okunmaz olmuştu.
double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

void main() {
  final cases = <(String, SkinPalette, AppColors)>[];
  for (final skin in AppSkin.values) {
    for (final b in Brightness.values) {
      if (skin.forcesDark && b == Brightness.light) continue;
      final p = SkinPalette.of(skin, b);
      cases.add(('${skin.name}/${b.name}', p, AppColors.fromPalette(p, b)));
    }
  }

  test('metin rolleri her zemin basamağında ≥ 4,5:1', () {
    final fails = <String>[];
    for (final (name, p, _) in cases) {
      for (final (bgName, bg) in [('bg', p.bg), ('card', p.card), ('band', p.band)]) {
        for (final (role, ink) in [
          ('ink', p.ink),
          ('inkSoft', p.inkSoft),
          ('inkFaint', p.inkFaint),
        ]) {
          final r = contrast(ink, bg);
          if (r < 4.5) fails.add('$name $role/$bgName ${r.toStringAsFixed(2)}');
        }
      }
      final onA = contrast(p.onAccent, p.accent);
      if (onA < 4.5) fails.add('$name onAccent/accent ${onA.toStringAsFixed(2)}');
    }
    expect(fails, isEmpty);
  });

  test('simge/kenar rolleri sayfa ve kartta ≥ 3:1', () {
    final fails = <String>[];
    for (final (name, p, c) in cases) {
      for (final (bgName, bg) in [('bg', p.bg), ('card', p.card)]) {
        for (final (role, fg) in [
          ('accent', p.accent),
          ('danger', c.danger),
          ('success', c.success),
          ('warning', c.warning),
          ('info', c.info),
        ]) {
          final r = contrast(fg, bg);
          if (r < 3) fails.add('$name $role/$bgName ${r.toStringAsFixed(2)}');
        }
      }
    }
    expect(fails, isEmpty);
  });

  test('medya perdesi üstündeki metin ≥ 4,5:1', () {
    // Oynatıcı/galeri çubukları siyah perdenin üstünde beyaz yazar; perde
    // görüntünün en açık karesinde de okunur kalmalı → beyaz zeminde ölçülür.
    final over = Color.alphaBlend(AppColors.mediaChrome, Colors.white);
    expect(contrast(AppColors.onMedia, over), greaterThanOrEqualTo(4.5));
    expect(contrast(AppColors.onMediaSoft, AppColors.mediaSurface),
        greaterThanOrEqualTo(4.5));
  });
}

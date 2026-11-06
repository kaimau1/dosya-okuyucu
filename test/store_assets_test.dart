import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Faz 42 / 4 — mağaza varlıkları bekçisi: Play sınırları (başlık 30, kısa 80,
/// uzun 4000, sürüm notu 500 karakter) ve görsel boyutları. Kaynak
/// `docs/play/magaza_metinleri.md` → `python3 tool/magaza_varliklari.py`.
void main() {
  const root = 'fastlane/metadata/android';
  const limits = {
    'title.txt': 30,
    'short_description.txt': 80,
    'full_description.txt': 4000,
    'changelogs/default.txt': 500,
  };

  for (final lang in ['tr-TR', 'en-US', 'ar']) {
    test('$lang metinleri Play sınırları içinde', () {
      for (final e in limits.entries) {
        final f = File('$root/$lang/${e.key}');
        expect(f.existsSync(), isTrue, reason: '${f.path} yok');
        final text = f.readAsStringSync().trim();
        expect(text, isNotEmpty, reason: f.path);
        expect(text.runes.length, lessThanOrEqualTo(e.value),
            reason: '${f.path}: ${text.runes.length} > ${e.value}');
      }
    });
  }

  /// PNG başlığından genişlik × yükseklik (IHDR).
  (int, int) pngSize(String path) {
    final b = File(path).readAsBytesSync();
    int be(int o) => (b[o] << 24) | (b[o + 1] << 16) | (b[o + 2] << 8) | b[o + 3];
    return (be(16), be(20));
  }

  test('simge 512×512, tanıtım görseli 1024×500', () {
    expect(pngSize('$root/tr-TR/images/icon.png'), (512, 512));
    expect(pngSize('$root/tr-TR/images/featureGraphic.png'), (1024, 500));
  });
}

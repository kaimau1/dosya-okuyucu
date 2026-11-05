import 'package:dosya_okuyucu/services/xlsx/theme_palette.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 9 — tema renk ızgarası.
void main() {
  test('eksik tema Office varsayılanıyla tamamlanır', () {
    final b = ThemePalette.base(const [0xFF112233]);
    expect(b.length, 10);
    expect(b.first, 0xFF112233);
    expect(b[4], 0xFF4472C4);
  });

  test('ton: beyaz koyulaşır, siyah açılır, vurgu 3 açık + 2 koyu', () {
    final g = ThemePalette.grid(const []);
    expect(g.length, 6);
    expect(g.every((r) => r.length == 10), isTrue);
    // beyaz (0) koyulaşır
    expect(ThemePalette.luminance(g[1][0]), lessThan(1));
    // siyah (1) açılır
    expect(ThemePalette.luminance(g[1][1]), greaterThan(0));
    // vurgu: 1. satır daha açık, 5. satır daha koyu
    final a = g[0][4];
    expect(ThemePalette.luminance(g[1][4]), greaterThan(ThemePalette.luminance(a)));
    expect(ThemePalette.luminance(g[5][4]), lessThan(ThemePalette.luminance(a)));
  });

  test('tint uçları', () {
    expect(ThemePalette.tint(0xFF808080, 1), 0xFFFFFFFF);
    expect(ThemePalette.tint(0xFF808080, -1), 0xFF000000);
    expect(ThemePalette.tint(0xFF808080, 0), 0xFF808080);
  });
}

/// **Tema renkleri** — Faz 36 madde 9: dosyanın `theme1.xml` renkleri
/// (lt1, dk1, lt2, dk2, accent1..6) ve Excel'in renk seçicisindeki beş ton
/// satırı. Saf + testli; UI renk seçici (`spreadsheet/formatting.dart`).
library;

abstract final class ThemePalette {
  static const _fallback = <int>[
    0xFFFFFFFF, 0xFF000000, 0xFFE7E6E6, 0xFF44546A, //
    0xFF4472C4, 0xFFED7D31, 0xFFA5A5A5, 0xFFFFC000, //
    0xFF5B9BD5, 0xFF70AD47,
  ];

  /// Excel indeks sırasıyla ilk 10 tema rengi (eksikse Office varsayılanı).
  static List<int> base(List<int> theme) => [
        for (var i = 0; i < 10; i++) i < theme.length ? theme[i] : _fallback[i],
      ];

  /// Göreli parlaklık 0..1.
  static double luminance(int argb) {
    final r = (argb >> 16) & 0xFF, g = (argb >> 8) & 0xFF, b = argb & 0xFF;
    return (0.299 * r + 0.587 * g + 0.114 * b) / 255;
  }

  /// [t] > 0 beyaza, < 0 siyaha doğru karıştırır (Excel `tint`).
  static int tint(int argb, double t) {
    int ch(int c) => t >= 0
        ? (c + (255 - c) * t).round().clamp(0, 255)
        : (c * (1 + t)).round().clamp(0, 255);
    final r = ch((argb >> 16) & 0xFF),
        g = ch((argb >> 8) & 0xFF),
        b = ch(argb & 0xFF);
    return 0xFF000000 | (r << 16) | (g << 8) | b;
  }

  /// Rengin tonları (Excel seçicisinin sütunu): çok açık renk koyulaşır,
  /// çok koyu renk açılır, öteki renkler üç açık + iki koyu ton alır.
  static List<double> tintsFor(int argb) {
    final l = luminance(argb);
    if (l > 0.9) return const [-0.05, -0.15, -0.25, -0.35, -0.5];
    if (l < 0.1) return const [0.5, 0.35, 0.25, 0.15, 0.05];
    return const [0.8, 0.6, 0.4, -0.25, -0.5];
  }

  /// Satır satır ızgara: ilk satır temel renkler, ardından beş ton satırı.
  static List<List<int>> grid(List<int> theme) {
    final b = base(theme);
    return [
      b,
      for (var row = 0; row < 5; row++)
        [for (final c in b) tint(c, tintsFor(c)[row])],
    ];
  }
}

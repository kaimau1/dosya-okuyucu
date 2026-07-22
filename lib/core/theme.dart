import 'package:flutter/material.dart';

import '../models/document.dart';

/// Office marka kimliği (M365 mobil hissi): dosya türüne göre üst şerit rengi
/// ve belgenin arkasındaki Fluent çalışma kanvası. Renkler tek yerden (token)
/// gelir; ekranlara elle hex yazılmaz.
class OfficeColors {
  static const word = Color(0xFF185ABD); // Word mavisi
  static const excel = Color(0xFF107C41); // Excel yeşili
  static const slides = Color(0xFFC43E1C); // PowerPoint turuncusu
  static const pdf = Color(0xFFC50F1F); // PDF kırmızısı (Fluent red)
  static const neutral = Color(0xFF3B6EF6); // metin/görsel/bilinmeyen → uygulama rengi

  static Color forKind(DocKind kind) {
    switch (kind) {
      case DocKind.word:
        return word;
      case DocKind.spreadsheet:
        return excel;
      case DocKind.slides:
        return slides;
      case DocKind.pdf:
        return pdf;
      case DocKind.text:
      case DocKind.image:
      case DocKind.unknown:
        return neutral;
    }
  }

  /// Belge kanvası: sayfanın/ızgaranın arkasındaki nötr çalışma alanı.
  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF201F1E)
          : const Color(0xFFF3F2F1);
}

/// Uygulama teması: sade, modern, tek renk tohumundan üretilen Material 3.
class AppTheme {
  static const Color _seed = Color(0xFF3B6EF6);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        centerTitle: false,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}

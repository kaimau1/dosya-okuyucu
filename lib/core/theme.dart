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

/// Ölçü token'ları: 4/8dp ritmi. Ekranlara serbest sayı yazmak yerine buradan
/// alınır — bileşenler arası dikey/yatay ritim tek yerden değişir.
abstract final class Gap {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

/// Köşe yarıçapı token'ları. Hiyerarşi: küçük kontrol < kart < sayfa/sheet.
abstract final class Radii {
  static const control = 12.0; // buton, giriş alanı
  static const card = 16.0; // kart, liste öğesi
  static const sheet = 28.0; // bottom sheet, dialog
}

/// Uygulama teması: sade, modern, tek renk tohumundan üretilen Material 3.
///
/// Premium hissin kaynağı gösterişli efekt değil TUTARLILIK: tek tipografi
/// ölçeği, tek yarıçap hiyerarşisi, gölge yerine yüzey-tonu + ince kenarlık
/// (M3'ün "flat + outline" dili), her iki temada da eşit okunurluk.
class AppTheme {
  static const Color _seed = Color(0xFF3B6EF6);

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );
    final isDark = brightness == Brightness.dark;
    final text = _textTheme(scheme);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: text,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkSparkle.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3,
        surfaceTintColor: scheme.surfaceTint,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
      ),

      // Gölge yerine yüzey tonu + saç teli kenarlık: yükseltilmiş kutu
      // yığınından daha sakin, koyu temada da kenarı kaybolmuyor.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: isDark ? 0.6 : 0.5),
          ),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodySmall?.copyWith(
          color: scheme.onSurfaceVariant,
        ),
      ),

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          // 48dp: Android dokunma hedefi alt sınırı.
          minimumSize: const Size(64, 48),
          padding: const EdgeInsets.symmetric(horizontal: Gap.lg),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 2,
        focusElevation: 3,
        hoverElevation: 3,
        highlightElevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHigh,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.sheet),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(Radii.sheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Gap.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        contentTextStyle: text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        // Koyu temada da görünür kalsın (tek temaya göre ayarlanan ayraç tuzağı).
        color: scheme.outlineVariant.withValues(alpha: isDark ? 0.7 : 0.6),
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),
      // ponytail: sayfa geçişi Flutter'ın M3 varsayılanına (ZoomPageTransitions)
      // bırakıldı — Android-native ve geri hareketiyle uyumlu.
    );
  }

  /// Tipografi ölçeği: gövde satır yüksekliği 1.45 (uzun Türkçe metinde
  /// okunurluk), başlıklarda hafif negatif harf aralığı (sıkı, modern başlık).
  /// Sistem fontu kullanılır — özel UI fontu APK'yı büyütür ve uygulama
  /// çevrimdışı çalıştığı için Google Fonts indirmesi yapılamaz.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness).textTheme;
    return base.copyWith(
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.4,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        height: 1.3,
      ),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.35),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

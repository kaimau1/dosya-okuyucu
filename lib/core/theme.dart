import 'package:flutter/material.dart';

import '../models/document.dart';

/// Kağıt teması (2026-08-04, claude.ai/design "Sekiz ekran Flutter tasarımı"
/// devir notu): zemin kağıt, metin mürekkep, ayrım gölgeyle değil CETVEL
/// çizgisiyle yapılır. Renkler tek yerden gelir; ekranlara elle hex yazılmaz.
abstract final class Paper {
  // Açık tema — kağıt
  static const bg = Color(0xFFFBF8F1); // sayfa
  static const card = Color(0xFFF6F1E6); // kart, kategori kutusu
  static const band = Color(0xFFF1EADC); // iş şeridi, seçim çubuğu, özet
  static const well = Color(0xFFEFE7D7); // metin kutusu / simge kutusu dolgusu
  static const rule = Color(0xFFDCD3C0); // kenarlık ve ayraç (cetvel)
  static const edge = Color(0xFFC8BEA9); // ikincil kenarlık, çubuk zemini
  static const ink = Color(0xFF262219); // başlık ve gövde
  static const inkSoft = Color(0xFF6E6555); // alt satır, ikincil metin
  static const inkFaint = Color(0xFF8A8071); // yol, sayaç, zaman damgası
  static const accent = Color(0xFF2E5AA8); // seçili sekme, FAB, birincil eylem
  static const accentWell = Color(0xFFE3E9F5); // seçili pil, kullanıcı balonu
  static const danger = Color(0xFFB23A2E); // kalıcı sil, başarısız iş
  static const ok = Color(0xFF2F6B3A); // biten iş, geri yükle

  // Koyu tema — aynı kağıt, gece mürekkebi
  static const bgDark = Color(0xFF1A1712); // sayfa
  static const cardDark = Color(0xFF221E17); // kart
  static const bandDark = Color(0xFF2C2720); // yükseltilmiş
  static const wellDark = Color(0xFF332D24);
  static const ruleDark = Color(0xFF3A342A); // kenarlık
  static const edgeDark = Color(0xFF6B6455);
  static const inkDark = Color(0xFFE8E1D3); // mürekkep
  static const inkSoftDark = Color(0xFFB5AB98); // ikincil
  static const inkFaintDark = Color(0xFF8C8271); // üçüncül
  static const accentDark = Color(0xFF7FA3E0);
  static const accentWellDark = Color(0xFF26364D);
  static const dangerDark = Color(0xFFD9756B);
  static const okDark = Color(0xFF7FA98A);

  /// Belge sayfasının kendisi — koyu temada da AÇIK kalır (okunan metin ters
  /// çevrilmez, yalnız çevresi koyar). Kenarlığı [pageEdge].
  static const page = Color(0xFFFBF8F1);
  static const pageEdge = Color(0xFFD2C8B4);

  /// Üçüncül mürekkep: yol, sayaç, zaman damgası. Gövde metninden bir kademe
  /// soluk — kağıtta "kurşun kalem" tonu.
  static Color faint(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? inkFaintDark : inkFaint;

  /// Başarılı/tamamlandı rengi (hata `colorScheme.error`den gelir).
  static Color success(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? okDark : ok;
}

/// Office marka kimliği: dosya türüne göre üst şerit rengi ve belgenin
/// arkasındaki çalışma kanvası. Kağıt zemin için bir kademe koyulaştırıldı.
class OfficeColors {
  static const word = Color(0xFF2E5AA8);
  static const excel = Color(0xFF2F6B3A);
  static const slides = Color(0xFFB85A2B);
  static const pdf = Color(0xFFB23A2E);
  static const neutral = Color(0xFF2E5AA8); // metin/görsel/bilinmeyen

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

  /// Belge kanvası: sayfanın/ızgaranın arkasındaki çalışma alanı — beyaz
  /// sayfanın öne çıkması için kağıdın bir kademe koyusu.
  static Color canvas(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? Paper.bgDark
          : const Color(0xFFEFE9DC);
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

/// Köşe yarıçapı token'ları. Kağıt temasında hiyerarşi bir kademe düşürüldü
/// (baskı hissi: yumuşak değil, kesilmiş kâğıt kenarı).
abstract final class Radii {
  static const control = 11.0; // buton, giriş alanı
  static const card = 14.0; // kart, liste öğesi
  static const sheet = 26.0; // bottom sheet, dialog
}

/// Uygulama teması: kağıt/mürekkep paleti, gölgesiz, cetvel çizgili.
///
/// Premium hissin kaynağı gösterişli efekt değil TUTARLILIK: tek tipografi
/// ölçeği (serif başlık / sans gövde), tek yarıçap hiyerarşisi, gölge yerine
/// yüzey-tonu + ince kenarlık, her iki temada da eşit okunurluk.
class AppTheme {
  static const Color _seed = Color(0xFF3B6EF6);

  /// Başlık serifi ve gövde sans'ı zaten APK'da gömülü (slayt sadakati için
  /// eklenmişlerdi) — kağıt teması için yeni font indirilmedi, boyut artmadı.
  static const String fontHeading = 'Tinos';
  static const String fontBody = 'Arimo';
  static const String fontMono = 'monospace';

  static ThemeData light() => _base(Brightness.light);
  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    // Tohum korunur (türetilen ikincil/üçüncül roller ondan gelir) ama kağıt
    // hissini bozan mavi-gri YÜZEYLER elle geçersiz kılınır.
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    ).copyWith(
      primary: isDark ? Paper.accentDark : Paper.accent,
      onPrimary: isDark ? const Color(0xFF13202F) : Colors.white,
      primaryContainer: isDark ? Paper.accentWellDark : Paper.accentWell,
      onPrimaryContainer: isDark ? const Color(0xFFD7E2F5) : Paper.accent,
      // Çip, sekme ve rozet dolguları da buradan gelir — tohumun mavi-grisi
      // kağıtta yabancı duruyordu (kabul ölçütü: hiçbir ekranda Material'ın
      // türetilmiş yüzeyi kalmayacak).
      secondary: isDark ? Paper.accentDark : Paper.accent,
      onSecondary: isDark ? const Color(0xFF13202F) : Colors.white,
      secondaryContainer: isDark ? Paper.accentWellDark : Paper.accentWell,
      onSecondaryContainer: isDark ? const Color(0xFFD7E2F5) : Paper.accent,
      tertiary: isDark ? Paper.inkSoftDark : Paper.inkSoft,
      onTertiary: isDark ? Paper.bgDark : Colors.white,
      tertiaryContainer: isDark ? Paper.bandDark : Paper.band,
      onTertiaryContainer: isDark ? Paper.inkDark : Paper.ink,
      surface: isDark ? Paper.bgDark : Paper.bg,
      onSurface: isDark ? Paper.inkDark : Paper.ink,
      inverseSurface: isDark ? Paper.inkDark : Paper.ink,
      onInverseSurface: isDark ? Paper.bgDark : Paper.bg,
      inversePrimary: isDark ? Paper.accent : Paper.accentDark,
      onSurfaceVariant: isDark ? Paper.inkSoftDark : Paper.inkSoft,
      surfaceContainerLowest: isDark ? const Color(0xFF141109) : Colors.white,
      surfaceContainerLow: isDark ? Paper.cardDark : Paper.card,
      surfaceContainer: isDark ? const Color(0xFF262117) : Paper.card,
      surfaceContainerHigh: isDark ? Paper.bandDark : Paper.band,
      surfaceContainerHighest: isDark ? Paper.wellDark : Paper.well,
      outline: isDark ? Paper.edgeDark : Paper.edge,
      outlineVariant: isDark ? Paper.ruleDark : Paper.rule,
      error: isDark ? Paper.dangerDark : Paper.danger,
      onError: isDark ? const Color(0xFF2A0F0C) : Colors.white,
      errorContainer: isDark ? const Color(0xFF6B231B) : const Color(0xFFF6E0DC),
      onErrorContainer:
          isDark ? const Color(0xFFF7DCD8) : const Color(0xFF4A130E),
      surfaceTint: Colors.transparent, // gölge/ton yok: kağıt düz durur
    );
    final text = _textTheme(scheme);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: text,
      fontFamily: fontBody,
      scaffoldBackgroundColor: scheme.surface,
      splashFactory: InkRipple.splashFactory,

      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: text.titleLarge,
        // Gölge yerine cetvel: kaydırınca başlık alanı çizgiyle ayrılır.
        shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),

      // Gölge yerine yüzey tonu + saç teli kenarlık.
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
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
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(Radii.control),
          ),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        elevation: 0,
        focusElevation: 0,
        hoverElevation: 0,
        highlightElevation: 0,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
        ),
      ),

      // ── Metin kutuları ────────────────────────────────────────────────────
      // KULLANICI HATASI 2026-07-30 (PIN diyaloğu): "eski pin girmedim ki".
      // Kullanıcı yalnız bir kutu görüyor, "Tamam"a basıyor ve "İki PIN aynı
      // değil" hatası alıyordu. Sebep tamamen buradaydı: kutunun dolgusu
      // DİYALOĞUN arka planıyla aynıydı ve odaklanmamış kutunun KENARLIĞI
      // YOKTU → diyalogdaki ikinci kutu tamamen görünmezdi.
      //
      // İki katmanlı düzeltme: (a) odaklanmamış kutuya ince ama gerçek bir
      // kenarlık, (b) dolgu bir kademe koyu (`surfaceContainerHighest`), yani
      // kutu diyalog zemininden de sayfa zemininden de ayrışıyor.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.md, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.control),
          borderSide: BorderSide(color: scheme.outlineVariant),
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
          side: BorderSide(color: scheme.outlineVariant),
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
        contentTextStyle:
            text.bodyMedium?.copyWith(color: scheme.onInverseSurface),
      ),

      dividerTheme: DividerThemeData(
        space: 1,
        thickness: 1,
        color: scheme.outlineVariant,
      ),

      chipTheme: ChipThemeData(
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.control),
        ),
      ),

      switchTheme: SwitchThemeData(
        // Kağıt paleti: açık = mürekkep mavisi, kapalı = kağıdın kenarı.
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : (isDark ? Paper.inkSoftDark : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : (isDark ? Paper.ruleDark : const Color(0xFFE1D8C5)),
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outline),
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Radii.card),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      // ponytail: sayfa geçişi Flutter'ın M3 varsayılanına (ZoomPageTransitions)
      // bırakıldı — Android-native ve geri hareketiyle uyumlu.
    );
  }

  /// Tipografi: serif başlık (Tinos w600, hafif negatif harf aralığı) / sans
  /// gövde (Arimo). Karşıtlık kağıt hissinin ikinci yarısı — yalnız renk
  /// değişse gazete değil, boyanmış Material olurdu.
  static TextTheme _textTheme(ColorScheme scheme) {
    final base = ThemeData(brightness: scheme.brightness)
        .textTheme
        .apply(fontFamily: fontBody);
    TextStyle? head(TextStyle? s, {double? size}) => s?.copyWith(
          fontFamily: fontHeading,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontSize: size,
        );

    return base.copyWith(
      displayLarge: head(base.displayLarge),
      displayMedium: head(base.displayMedium),
      displaySmall: head(base.displaySmall),
      headlineLarge: head(base.headlineLarge),
      headlineMedium: head(base.headlineMedium),
      headlineSmall: head(base.headlineSmall),
      titleLarge: head(base.titleLarge),
      titleMedium: head(base.titleMedium)?.copyWith(height: 1.3),
      bodyLarge: base.bodyLarge?.copyWith(height: 1.45),
      bodyMedium: base.bodyMedium?.copyWith(height: 1.45),
      bodySmall: base.bodySmall?.copyWith(height: 1.35),
      labelLarge: base.labelLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }
}

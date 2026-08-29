import 'package:flutter/material.dart';

import '../models/document.dart';
import 'skin.dart';

/// Kağıt teması (2026-08-04, claude.ai/design "Sekiz ekran Flutter tasarımı"
/// devir notu): zemin kağıt, metin mürekkep, ayrım gölgeyle değil CETVEL
/// çizgisiyle yapılır. Renkler tek yerden gelir; ekranlara elle hex yazılmaz.
abstract final class Paper {
  // Açık tema — kağıt
  //
  // **Beyaza yaklaştırıldı — İKİ TURDA** (kullanıcı 2026-08-17: önce *"kağıt
  // temasını biraz beyazlaştıralım, dosya uygulamasına uymadı tam kağıt
  // teması"*, cihazda görünce *"genel rengi biraz daha beyazlat"*). Kağıdın
  // sıcaklığı KALIYOR — mavi-gri bir Material yüzeyine dönmedi — ama krem
  // doygunluğu iki turda dörtte bire indi. Sebep: bir okuyucuda sarımsı zemin
  // gözü dinlendirir, bir DOSYA YÖNETİCİSİNDE ise fotoğraf küçük resimlerinin
  // ve renkli tür simgelerinin yanında zemin "sararmış" görünüyor.
  //
  // Basamak sırası (bg → card → band → well → rule → edge) korundu: hiyerarşi
  // aynı, yalnız her basamak daha açık. `bg` ile `card` arasındaki fark
  // bilinçli olarak İNCE ama sıfır değil — kart kenarlığı (`rule`) ayrımı
  // taşıyor, kartın kendi zemini değil.
  static const bg = Color(0xFFFEFEFC); // sayfa
  static const card = Color(0xFFFCFBF7); // kart, kategori kutusu
  static const band = Color(0xFFF9F7F1); // iş şeridi, seçim çubuğu, özet
  static const well = Color(0xFFF5F3EB); // metin kutusu / simge kutusu dolgusu
  static const rule = Color(0xFFEBE7DC); // kenarlık ve ayraç (cetvel)
  static const edge = Color(0xFFD9D2C4); // ikincil kenarlık, çubuk zemini
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
  static const page = Color(0xFFFEFEFC);
  static const pageEdge = Color(0xFFE4DFD2);

  /// **Belgenin kendi yüzeyi** — Excel hücresi, düz metin sayfası.
  ///
  /// (2026-08-07 kullanıcı: *"kağıt teması arka planları excelde kağıt yapmış
  /// olmaz, beyaz olmalı, txt de öyle"*.) Kağıt dokusu uygulamanın KABUĞUNA
  /// aittir: listeler, kartlar, ayarlar. Belgenin İÇİ kullanıcının verisidir
  /// ve Excel/Not Defteri'nde beyazdır — krem zemin orada "dosyamın rengi
  /// bozulmuş" gibi görünüyor. Koyu temada beyaz yapılamaz (gözü yakar);
  /// kanvastan bir tık koyu, nötr bir yüzey kullanılır.
  static Color docSurface(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const Color(0xFF141210)
          : Colors.white;

  /// Etkin temanın paleti. Tema uzantısı yoksa (test/izole widget) kağıt.
  static SkinPalette paletteOf(BuildContext context) =>
      AppSkinData.of(context).palette;

  /// Üçüncül mürekkep: yol, sayaç, zaman damgası. Gövde metninden bir kademe
  /// soluk — kağıtta "kurşun kalem" tonu.
  ///
  /// **Sabit `inkFaint` DEĞİL, temanın kendi tonu** (2026-08-25): tema aileleri
  /// gelince kağıdın kurşun kalem grisi "Modern"in morumsu zemininde yabancı
  /// duruyordu. 42 çağrı yeri var; hepsinin doğru rengi alması ancak burayı
  /// temaya bağlamakla oluyor.
  static Color faint(BuildContext context) => paletteOf(context).inkFaint;

  /// Başarılı/tamamlandı rengi (hata `colorScheme.error`den gelir).
  static Color success(BuildContext context) => paletteOf(context).ok;
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
          : const Color(0xFFF4F1EA);
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
  /// Başlık serifi ve gövde sans'ı zaten APK'da gömülü (slayt sadakati için
  /// eklenmişlerdi) — kağıt teması için yeni font indirilmedi, boyut artmadı.
  static const String fontHeading = 'Tinos';

  /// Arayüzün **varsayılan** gövde yazı tipi.
  ///
  /// 2026-08-07'de Arimo'dan Carlito'ya alındı (kullanıcı: *"en uygun fontu
  /// varsayılan yap"*). Arimo = Arial/Helvetica metriği: baskı çağının
  /// grotesk'i, küçük puntoda harfleri birbirine yaklaşıyor. Carlito =
  /// Calibri metriği: doğrudan EKRANDA OKUMAK için tasarlanmış hümanist sans,
  /// yuvarlak uçlar, daha açık harf boşluğu; Türkçe'nin ı/İ/ş/ğ işaretleri
  /// tam. Belge tarafıyla da tutarlı: Word/Excel varsayılanı da Calibri.
  static const String fontBody = 'Carlito';

  static const String fontMono = 'monospace';

  /// Varsayılan arayüz yazı tipi: **Carlito** (kullanıcı kararı 2026-08-07).
  ///
  /// Seçim BÜTÜN arayüze uygulanır — başlık, gövde ve tarih/boyut satırları.
  /// Eskiden varsayılan "tasarımın karışımı"ydı (serif başlık + sans gövde);
  /// kullanıcı tek ve tutarlı bir yazı tipi istedi.
  static const String uiFontDefault = fontBody;

  /// Seçilebilir arayüz yazı tipleri — hepsi APK'da **GÖMÜLÜ**: cihazda kurulu
  /// olup olmamasına bağlı değil, her telefonda birebir aynı görünür (sistem
  /// fontuna düşen bir seçenek "her telefonda sabit" olmazdı).
  ///
  /// Etiketler yazı tipinin karakterini söylüyor: kullanıcı adı bilmese de
  /// ne seçtiğini anlasın.
  static const List<(String label, String family)> uiFonts = [
    ('Carlito', fontBody),
    ('Inter', 'Inter'),
    ('Lato', 'Lato'),
    ('Nunito', 'Nunito'),
    ('Arimo', 'Arimo'),
    ('Merriweather', 'Merriweather'),
    ('Tinos', 'Tinos'),
    ('EB Garamond', 'EB Garamond'),
    ('Roboto Slab', 'Roboto Slab'),
    ('JetBrains Mono', 'JetBrains Mono'),
  ];

  /// Yazı boyutu hazır kademeleri (kullanıcı isteği 2026-08-07: *"küçük orta
  /// büyük çok büyük şeklinde kolay seçimde olsun"*). Kaydırıcı ince ayar
  /// için duruyor; günlük kullanımda tek dokunuş yetiyor.
  static const List<(String labelKey, double scale)> uiTextScales = [
    ('settings.size_small', 0.9),
    ('settings.size_medium', 1.0),
    ('settings.size_large', 1.15),
    ('settings.size_xlarge', 1.3),
  ];

  /// [bodyFont] kullanıcının seçtiği aile ([uiFontDefault] ya da null =
  /// tasarımın kendi karışımı). Aile verilirse başlıklar ve veri satırları da
  /// onunla çizilir.
  static ThemeData light({
    String? bodyFont,
    AppSkin skin = AppSkin.paper,
    String? background,
  }) =>
      _base(Brightness.light,
          bodyFont: bodyFont, skin: skin, background: background);

  static ThemeData dark({
    String? bodyFont,
    AppSkin skin = AppSkin.paper,
    String? background,
  }) =>
      _base(Brightness.dark,
          bodyFont: bodyFont, skin: skin, background: background);

  static ThemeData _base(
    Brightness brightness, {
    String? bodyFont,
    AppSkin skin = AppSkin.paper,
    String? background,
  }) {
    // Seçilen aile HER YERE: başlık ve veri satırları da. Gezgin listesinde
    // gövde metni yok (ad = başlık stili, tarih = tek aralıklı); yalnız
    // gövdeyi değiştiren bir ayar orada hiçbir şeyi değiştirmiyordu.
    final body = bodyFont ?? fontBody;
    final heading = body;
    final mono = body;
    // "Gece" ailesinin açık karşılığı yok: sistem açık moddayken bile koyu
    // kalır (bkz. AppSkin.forcesDark). Yoksa kullanıcı OLED temayı seçtiği
    // hâlde gündüz beyaz ekran görürdü.
    final isDark = brightness == Brightness.dark || skin.forcesDark;
    final effective = isDark ? Brightness.dark : Brightness.light;
    final metrics = SkinMetrics.of(skin);
    var palette = SkinPalette.of(skin, effective);
    final bgChoice = AppBackground.byId(background);
    if (!bgChoice.isDefault) {
      palette = palette.withBackground(isDark ? bgChoice.dark : bgChoice.light);
    }
    // Tohum korunur (türetilen ikincil/üçüncül roller ondan gelir) ama ailenin
    // kimliğini bozan türetilmiş YÜZEYLER elle geçersiz kılınır.
    final scheme = ColorScheme.fromSeed(
      seedColor: palette.accent,
      brightness: effective,
    ).copyWith(
      primary: palette.accent,
      onPrimary: palette.onAccent,
      primaryContainer: palette.accentWell,
      onPrimaryContainer: isDark ? palette.ink : palette.accent,
      // Çip, sekme ve rozet dolguları da buradan gelir — tohumun türettiği
      // mavi-gri yüzey her ailede yabancı duruyordu (kabul ölçütü: hiçbir
      // ekranda Material'ın kendi türetilmiş yüzeyi kalmayacak).
      secondary: palette.accent,
      onSecondary: palette.onAccent,
      secondaryContainer: palette.accentWell,
      onSecondaryContainer: isDark ? palette.ink : palette.accent,
      tertiary: palette.inkSoft,
      onTertiary: isDark ? palette.bg : Colors.white,
      tertiaryContainer: palette.band,
      onTertiaryContainer: palette.ink,
      surface: palette.bg,
      onSurface: palette.ink,
      inverseSurface: palette.ink,
      onInverseSurface: palette.bg,
      inversePrimary: palette.accentWell,
      onSurfaceVariant: palette.inkSoft,
      surfaceContainerLowest:
          isDark ? _darken(palette.bg, 0.35) : _lighten(palette.card, 0.6),
      surfaceContainerLow: palette.card,
      surfaceContainer: palette.card,
      surfaceContainerHigh: palette.band,
      surfaceContainerHighest: palette.well,
      outline: palette.edge,
      outlineVariant: palette.rule,
      error: palette.danger,
      onError: isDark ? const Color(0xFF2A0F0C) : Colors.white,
      errorContainer: isDark
          ? Color.lerp(palette.danger, Colors.black, 0.6)
          : Color.lerp(palette.danger, Colors.white, 0.85),
      onErrorContainer: isDark
          ? Color.lerp(palette.danger, Colors.white, 0.7)
          : Color.lerp(palette.danger, Colors.black, 0.55),
      surfaceTint: Colors.transparent, // gölge/ton yok: yüzey düz durur
    );
    final text = _textTheme(scheme, body, heading);

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      textTheme: text,
      fontFamily: body,
      // Tema DIŞINDA kalan yazı tipleri de seçime uysun: tarih/boyut satırları
      // (`MonoText`) ve hücre yazıları koda gömülü 'monospace' kullanıyordu ve
      // ayardan hiç etkilenmiyordu.
      extensions: [
        AppFonts(body: body, heading: heading, mono: mono),
        AppSkinData(skin: skin, palette: palette, metrics: metrics),
      ],
      scaffoldBackgroundColor: scheme.surface,
      // Yoğunluk ailenin kimliğinin yarısı: aynı palet sıkı satırda "iş
      // programı", rahat satırda "modern" görünüyor.
      visualDensity: metrics.density,
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
          borderRadius: BorderRadius.circular(metrics.radiusCard),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),

      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusCard),
        ),
        contentPadding: EdgeInsets.symmetric(
            horizontal: Gap.md, vertical: metrics.rowPadding),
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
            borderRadius: BorderRadius.circular(metrics.radiusControl),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(48, 44),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radiusControl),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, 48),
          side: BorderSide(color: scheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(metrics.radiusControl),
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
          borderRadius: BorderRadius.circular(metrics.radiusCard),
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
          borderRadius: BorderRadius.circular(metrics.radiusControl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusControl),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(metrics.radiusControl),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),

      dialogTheme: DialogThemeData(
        elevation: 0,
        backgroundColor: scheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusSheet),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        titleTextStyle: text.headlineSmall,
        contentTextStyle: text.bodyMedium,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(metrics.radiusSheet)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(Gap.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusControl),
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
          borderRadius: BorderRadius.circular(metrics.radiusControl),
        ),
      ),

      switchTheme: SwitchThemeData(
        // Kağıt paleti: açık = mürekkep mavisi, kapalı = kağıdın kenarı.
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.onPrimary
              : (isDark ? palette.inkSoft : Colors.white),
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? scheme.primary
              : palette.edge,
        ),
        trackOutlineColor: WidgetStateProperty.all(scheme.outline),
      ),

      popupMenuTheme: PopupMenuThemeData(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(metrics.radiusCard),
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
  static TextTheme _textTheme(ColorScheme scheme,
      [String? bodyFont, String? headingFont]) {
    final base = ThemeData(brightness: scheme.brightness)
        .textTheme
        .apply(fontFamily: bodyFont ?? fontBody);
    TextStyle? head(TextStyle? s, {double? size}) => s?.copyWith(
          fontFamily: headingFont ?? fontHeading,
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

/// Temanın yazı tipi üçlüsü — widget'lar koda gömülü aile adı yerine bunu
/// okur, böylece Ayarlar'daki seçim BÜTÜN arayüze işler.
///
/// KÖK NEDEN (2026-08-07 kullanıcı: *"buradaki yazı tipleri değişmiyor, hep
/// aynı kalıyor"*): gezgin listesinde dosya adı başlık stiliyle (serif Tinos),
/// tarih satırı ise `MonoText` ile (koda gömülü 'monospace') çiziliyor — yani
/// o ekranda GÖVDE metni hiç yok. Yalnız gövde yazı tipini değiştiren bir ayar
/// orada hiçbir şeyi değiştirmiyordu.
class AppFonts extends ThemeExtension<AppFonts> {
  final String body;
  final String heading;
  final String mono;

  const AppFonts({
    required this.body,
    required this.heading,
    required this.mono,
  });

  /// Tema uzantısı bulunamazsa (test/izole widget) tasarımın kendi karışımı.
  static AppFonts of(BuildContext context) =>
      Theme.of(context).extension<AppFonts>() ??
      const AppFonts(
        body: AppTheme.fontBody,
        heading: AppTheme.fontHeading,
        mono: AppTheme.fontMono,
      );

  @override
  AppFonts copyWith({String? body, String? heading, String? mono}) => AppFonts(
        body: body ?? this.body,
        heading: heading ?? this.heading,
        mono: mono ?? this.mono,
      );

  /// Yazı tipi ailesi ARA DEĞER ALMAZ (yarı Tinos diye bir şey yok): tema
  /// geçişinin ortasında hedefe atlanır.
  @override
  AppFonts lerp(ThemeExtension<AppFonts>? other, double t) =>
      other is AppFonts && t >= 0.5 ? other : this;
}


/// Rengi koyulaştırır/açar — tema kurulurken ara basamak türetmek için.
Color _darken(Color c, double t) => Color.lerp(c, Colors.black, t) ?? c;
Color _lighten(Color c, double t) => Color.lerp(c, Colors.white, t) ?? c;

/// Etkin tema ailesi — widget'lar palet, ölçü ve simge ölçeğini buradan okur.
///
/// `Theme.of(context).colorScheme` renkleri zaten taşıyor; burada TAŞINMAYAN
/// şeyler var: simge ölçeği, satır sıklığı ve ailenin kimliği ([AppSkin]).
/// Bunlar `ColorScheme`e sığmıyor ama ekranların ihtiyacı — dosya simgesini
/// çizen widget "İş programı ailesindeyim, %22 küçült" diyebilmeli.
class AppSkinData extends ThemeExtension<AppSkinData> {
  final AppSkin skin;
  final SkinPalette palette;
  final SkinMetrics metrics;

  const AppSkinData({
    required this.skin,
    required this.palette,
    required this.metrics,
  });

  /// Tema uzantısı yoksa (test, izole widget) kağıt ailesi varsayılır —
  /// metinsiz/renksiz çizmektense uygulamanın kendi kimliği doğru.
  static AppSkinData of(BuildContext context) =>
      Theme.of(context).extension<AppSkinData>() ??
      AppSkinData(
        skin: AppSkin.paper,
        palette: SkinPalette.of(
            AppSkin.paper, Theme.of(context).brightness),
        metrics: SkinMetrics.of(AppSkin.paper),
      );

  @override
  AppSkinData copyWith({
    AppSkin? skin,
    SkinPalette? palette,
    SkinMetrics? metrics,
  }) =>
      AppSkinData(
        skin: skin ?? this.skin,
        palette: palette ?? this.palette,
        metrics: metrics ?? this.metrics,
      );

  /// Aile ARA DEĞER ALMAZ: "yarı modern" diye bir tema yok, geçişin ortasında
  /// hedefe atlanır (aynı kural [AppFonts]'ta da geçerli).
  @override
  AppSkinData lerp(ThemeExtension<AppSkinData>? other, double t) =>
      other is AppSkinData && t >= 0.5 ? other : this;
}

/// Ekranların kısayolu: `context.fmIconScale` — dosya/klasör simgeleri bu
/// çarpanla çizilir, böylece tema ailesi simge boyutunu gerçekten değiştirir.
extension SkinContext on BuildContext {
  double get fmIconScale => AppSkinData.of(this).metrics.iconScale;

  /// Ailenin glif stili: çizgi mi (outlined) dolu mu (rounded)?
  bool get fmOutlinedIcons => AppSkinData.of(this).metrics.outlinedIcons;

  /// Ailenin kart köşe yarıçapı — koda gömülü [Radii.card] yerine.
  double get fmCardRadius => AppSkinData.of(this).metrics.radiusCard;
}

/// **Koyu zemin üstünde duran çubuklar** için başlık/alt başlık stilleri
/// (video oynatıcı, görsel galerisi, Office kabuğu).
///
/// KÖK NEDEN (kullanıcı 2026-08-29, ekran görüntüsü işaretli: *"video ve
/// görsellerde dosya adı zor görülüyor"*): bu çubuklar `AppBar`a
/// `foregroundColor: Colors.white` veriyordu ama **başlık beyaz olmuyordu.**
/// Flutter'da `foregroundColor` yalnız `titleTextStyle` RENKSİZ olduğunda
/// devreye girer; bizim [AppTheme] `appBarTheme.titleTextStyle: titleLarge`
/// veriyor ve `titleLarge` Material tipografisinden gelen **koyu** rengi
/// taşıyor. Sonuç: simgeler beyaz, dosya adı neredeyse siyah — siyah zemin
/// üzerinde okunmuyordu (ekran görüntüsünde ölçülen renk `#1D1B20`).
///
/// Bu yüzden koyu çubukların başlığı stilini BURADAN alır; `foregroundColor`a
/// güvenmek aynı hatayı sessizce geri getirir.
class OverlayBar {
  /// Başlık: beyaz, hafif gölgeli (parlak bir video karesi üstünde de okunur).
  static TextStyle title(BuildContext context) =>
      (Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge ??
              const TextStyle())
          .copyWith(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        shadows: const [
          Shadow(color: Color(0xCC000000), blurRadius: 6),
        ],
      );

  /// **Dolu marka renginin** üstünde (Office kabuğu): yalnız RENK düzeltilir,
  /// ölçü/yazı tipi temadan kalır — orada perde yok, gölgeye de gerek yok.
  static TextStyle onBrand(BuildContext context) =>
      (Theme.of(context).appBarTheme.titleTextStyle ??
              Theme.of(context).textTheme.titleLarge ??
              const TextStyle())
          .copyWith(color: Colors.white);

  /// Alt satır (sayaç, boyut): beyazın kısılmışı, aynı gölgeyle.
  static TextStyle subtitle(BuildContext context) => TextStyle(
        color: Colors.white.withValues(alpha: 0.85),
        fontSize: 12,
        shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 6)],
      );
}

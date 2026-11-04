import 'package:flutter/material.dart';

/// **Tema aileleri (skin)** — kullanıcı isteği 2026-08-25: *"şuan ki tema açık
/// ama bu aslında kağıt teması, bunu kağıt tema olarak adlandır ve yeni olarak
/// açık tema getir … genel temalarda farklı klasör simgeleri boyutları gibi
/// sanki telefonun ana temasını değiştirir gibi temalar olsun"*.
///
/// ## Neden ayrı bir kavram
/// `ThemeMode` (sistem/açık/koyu) **parlaklık** sorusunun cevabı; buradaki
/// [AppSkin] **kimlik** sorusunun. İkisi diktir: "Modern" temanın da açığı ve
/// koyusu vardır. Tek bir listede birleştirmek ("Kağıt / Açık / Koyu /
/// Modern…") kullanıcıya "modern seçersem karanlık mod gider mi?" sorusunu
/// sordurur.
///
/// Tek istisna [AppSkin.night]: OLED için saf siyah bir aile, açık karşılığı
/// yok — seçilince uygulama koyu kalır (bkz. [AppSkin.forcesDark]).
///
/// ## Tema neyi değiştirir
/// Kullanıcı kararı (2026-08-25): **renk + simge boyutu + yoğunluk**. Yani her
/// aile kendi paletini ([SkinPalette]), kendi köşe yarıçapını, kendi simge
/// ölçeğini ve kendi satır sıklığını getirir ([SkinMetrics]). Yalnız renk
/// değiştiren bir tema listesi "boyanmış aynı uygulama" gibi duruyordu.
enum AppSkin {
  /// **Adaçayı** (2026-11-04, varsayılan — Notlar uygulamasıyla AYNI tema
  /// çalışması, `TEMA_PLANI.md` K1–K6): "masa ve kâğıt". Zemin (masa) orta
  /// açıklıkta ve hafif yeşil-gri (L≈0,95) → parlamaz; kartlar zeminden AÇIK
  /// (kâğıt masanın üstünde), vurgu petrol yeşili. Kırık beyazın yerine geldi:
  /// kullanıcı *"kırık beyaz soluk ve sıkıcı, saman çok sarı, beyaz çok
  /// parlak"* dedi.
  sage,

  /// **Porselen**: serin mavi-gri masa, lacivert vurgu. Eski "Açık"ın yerine.
  porcelain,

  /// **Kil**: sıcak pembe-bej masa, erik vurgu. Eski "Kağıt"ın yerine
  /// (sıcak aile; belge kanvası kâğıt sayfa çerçevesini bu ailede çizer).
  clay,

  /// **Modern:** canlı mor-mavi vurgu, büyük yuvarlak köşeler, büyük simgeler,
  /// rahat satır aralığı. Material 3'ün kendi hissine en yakın aile.
  modern,

  /// **Gece (OLED):** saf siyah zemin. Koyu temadan farkı, `#000000` pikselin
  /// OLED ekranda kapalı olması — hem pil hem gece okunurluğu.
  night,

  /// **Sistem rengi** (Faz 19 / K13 (a), 2026-10-22): Android 12+ duvar
  /// kâğıdından türeyen vurgu (`system_accent1`), yüzeyler Açık ailesinden.
  /// Android 11 ve altında listelenmez; renk okunamazsa Açık gibi görünür.
  system;

  // 2026-10-21 (Faz 2, K8): 10 aile → 4. İş programı, Okyanus, Gün batımı,
  // Orman, Gül ve Grafit KALDIRILDI — her biri ayrı palet + ölçü + simge dili
  // demekti (bakım ve test yükü). Eski seçim [byName] ile en yakın aileye
  // taşınır, kullanıcının tercihi sıfırlanmaz.

  String get labelKey => switch (this) {
        AppSkin.sage => 'skin.sage',
        AppSkin.porcelain => 'skin.porcelain',
        AppSkin.clay => 'skin.clay',
        AppSkin.modern => 'skin.modern',
        AppSkin.night => 'skin.night',
        AppSkin.system => 'skin.system',
      };

  String get descriptionKey => switch (this) {
        AppSkin.sage => 'skin.sage_sub',
        AppSkin.porcelain => 'skin.porcelain_sub',
        AppSkin.clay => 'skin.clay_sub',
        AppSkin.modern => 'skin.modern_sub',
        AppSkin.night => 'skin.night_sub',
        AppSkin.system => 'skin.system_sub',
      };

  /// Bu cihazda seçilebilir mi? (Sistem rengi yalnız Android 12+.)
  bool get available => this != AppSkin.system || SystemAccent.available;

  /// Aile yalnız koyu çalışıyor mu? (Gece/OLED'in açık karşılığı yok.)
  bool get forcesDark => this == AppSkin.night;

  static AppSkin byName(String? name, {AppSkin fallback = AppSkin.sage}) {
    for (final s in AppSkin.values) {
      if (s.name == name) return s;
    }
    return _retired[name] ?? fallback;
  }

  /// Kaldırılan ailelerin en yakın karşılığı: sakin/nötr olanlar Açık'a,
  /// renkli olanlar Modern'e.
  ///
  /// 2026-11-04 (Notlar'la aynı K2 kararı): eski üç açık aile yeni ailelere
  /// bir kez eşlenir — Kırık beyaz → Adaçayı, Açık → Porselen, Kağıt → Kil.
  /// Kayıt yeniden yazılmaz; seçim okunurken çevrilir.
  static const _retired = {
    'ivory': AppSkin.sage,
    'light': AppSkin.porcelain,
    'paper': AppSkin.clay,
    'office': AppSkin.porcelain,
    'graphite': AppSkin.porcelain,
    'ocean': AppSkin.modern,
    'sunset': AppSkin.modern,
    'forest': AppSkin.modern,
    'rose': AppSkin.modern,
  };
}

/// Bir ailenin tek parlaklıktaki renk basamakları.
///
/// Basamak sırası **her ailede aynı** (bg → card → band → well → rule → edge):
/// ekranlar "kartın zemini kağıdınkinden bir tık farklı" varsayımıyla yazıldı,
/// yeni bir aile bu sözleşmeyi bozarsa hiyerarşi kaybolur. Değişen yalnız
/// renklerin kendisi.
class SkinPalette {
  final Color bg; // sayfa
  final Color card; // kart, kategori kutusu
  final Color band; // iş şeridi, seçim çubuğu, özet
  final Color well; // metin kutusu / simge kutusu dolgusu
  final Color rule; // kenarlık ve ayraç
  final Color edge; // ikincil kenarlık, çubuk zemini
  final Color ink; // başlık ve gövde
  final Color inkSoft; // ikincil metin
  final Color inkFaint; // yol, sayaç, zaman damgası
  final Color accent; // seçili sekme, FAB, birincil eylem
  final Color accentWell; // seçili pil, kullanıcı balonu
  final Color onAccent; // vurgunun üstündeki metin
  final Color danger;
  final Color ok;

  const SkinPalette({
    required this.bg,
    required this.card,
    required this.band,
    required this.well,
    required this.rule,
    required this.edge,
    required this.ink,
    required this.inkSoft,
    required this.inkFaint,
    required this.accent,
    required this.accentWell,
    required this.onAccent,
    required this.danger,
    required this.ok,
  });

  /// Zemini kullanıcının seçtiği renge çeker ve **üst basamakları da birlikte
  /// taşır**.
  ///
  /// Yalnız `bg`i değiştirmek yetmiyordu: kart/şerit/kuyu basamakları eski
  /// zemine göre ayarlıydı, yeni zemin onlardan koyu olunca hiyerarşi TERSİNE
  /// dönüyordu (kart sayfadan koyu görünüyordu). Burada her basamak, eski
  /// zeminle arasındaki FARK kadar kaydırılır — hiyerarşi korunur, renk
  /// değişir.
  SkinPalette withBackground(Color newBg) {
    Color shift(Color c) => Color.lerp(newBg, c, 0.55) ?? c;
    return SkinPalette(
      bg: newBg,
      card: shift(card),
      band: shift(band),
      well: shift(well),
      rule: rule,
      edge: edge,
      // Zemin koyuysa mürekkep de dönmeli, yoksa metin okunmaz olur.
      ink: _readable(newBg, ink),
      inkSoft: _readable(newBg, inkSoft),
      inkFaint: _readable(newBg, inkFaint),
      accent: accent,
      accentWell: shift(accentWell),
      onAccent: onAccent,
      danger: danger,
      ok: ok,
    );
  }

  /// Metin rengi zemine göre okunur mu? Değilse zıt uca çevrilir.
  ///
  /// Kullanıcı 12 hazır renkten seçiyor ama "gece mavisi" gibi koyu bir zemin
  /// açık ailede seçilebiliyor; koyu mürekkebi orada bırakmak ekranı
  /// okunamaz yapardı.
  static Color _readable(Color bg, Color ink) {
    final bgLum = bg.computeLuminance();
    final inkLum = ink.computeLuminance();
    // Yeterli fark varsa dokunma.
    if ((bgLum - inkLum).abs() >= 0.35) return ink;
    return bgLum < 0.5
        ? Color.lerp(ink, Colors.white, 0.85) ?? Colors.white
        : Color.lerp(ink, Colors.black, 0.85) ?? Colors.black;
  }

  /// [skin] ailesinin [brightness] paleti.
  static SkinPalette of(AppSkin skin, Brightness brightness) {
    final dark = brightness == Brightness.dark || skin.forcesDark;
    return switch (skin) {
      AppSkin.sage => dark ? _sageDark : _sageLight,
      AppSkin.porcelain => dark ? _porcelainDark : _porcelainLight,
      AppSkin.clay => dark ? _clayDark : _clayLight,
      AppSkin.modern => dark ? _modernDark : _modernLight,
      AppSkin.night => _nightDark,
      AppSkin.system => SystemAccent.apply(
          dark ? _porcelainDark : _porcelainLight, dark: dark),
    };
  }

  // ── "Masa ve kâğıt" aileleri (2026-11-04, Notlar `TEMA_PLANI.md`) ─────
  //
  // İlke: zemin (masa) orta açıklıkta ve hafif renkli → parlamaz; kart
  // (kâğıt) zeminden AÇIK; şerit/levha kartla zemin arası; alan (arama,
  // giriş) kartın bir tık altı. Mürekkep saf siyah değil, zeminin tonunu
  // taşır. Değerler Notlar'daki OKLCH tablosunun aynısı; kontrastlar
  // `contrast_test` (WCAG) ile kilitli.
  static const _sageLight = SkinPalette(
    bg: Color(0xFFEAF0EB),
    card: Color(0xFFFAFCFA),
    band: Color(0xFFF5F9F6),
    well: Color(0xFFEFF4F0),
    rule: Color(0xFFD1D8D2),
    edge: Color(0xFFA9B3AC),
    ink: Color(0xFF1B2420),
    inkSoft: Color(0xFF535E59),
    inkFaint: Color(0xFF5C6762),
    accent: Color(0xFF106561),
    accentWell: Color(0xFFC8E9E6),
    onAccent: Colors.white,
    danger: Color(0xFFB0402F),
    ok: Color(0xFF3B6B47),
  );

  static const _sageDark = SkinPalette(
    bg: Color(0xFF131916),
    card: Color(0xFF1C2420),
    band: Color(0xFF232C27),
    well: Color(0xFF29332E),
    rule: Color(0xFF323D37),
    edge: Color(0xFF5C6862),
    ink: Color(0xFFDFE7E2),
    inkSoft: Color(0xFF9FA7A2),
    inkFaint: Color(0xFF8E9791),
    accent: Color(0xFF78C8C1),
    accentWell: Color(0xFF1E3B38),
    onAccent: Color(0xFF00201E),
    danger: Color(0xFFE58A7C),
    ok: Color(0xFF8FC79E),
  );

  static const _porcelainLight = SkinPalette(
    bg: Color(0xFFECEFF4),
    card: Color(0xFFFAFCFE),
    band: Color(0xFFF6F9FC),
    well: Color(0xFFF0F4F8),
    rule: Color(0xFFD2D8DF),
    edge: Color(0xFFABB2BC),
    ink: Color(0xFF1A1F2A),
    inkSoft: Color(0xFF545B66),
    inkFaint: Color(0xFF5D6470),
    accent: Color(0xFF304D8C),
    accentWell: Color(0xFFD6E2F9),
    onAccent: Colors.white,
    danger: Color(0xFFB3261E),
    ok: Color(0xFF2E6B3A),
  );

  static const _porcelainDark = SkinPalette(
    bg: Color(0xFF13161C),
    card: Color(0xFF1C2028),
    band: Color(0xFF232832),
    well: Color(0xFF2A303B),
    rule: Color(0xFF333A46),
    edge: Color(0xFF5D6573),
    ink: Color(0xFFE0E4EC),
    inkSoft: Color(0xFFA0A7B3),
    inkFaint: Color(0xFF8F96A2),
    accent: Color(0xFF9FB6EA),
    accentWell: Color(0xFF22314F),
    onAccent: Color(0xFF0E1A33),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF86C894),
  );

  static const _clayLight = SkinPalette(
    bg: Color(0xFFF4EBE7),
    card: Color(0xFFFEFBF8),
    band: Color(0xFFFCF7F4),
    well: Color(0xFFF8F1ED),
    rule: Color(0xFFDFD3CE),
    edge: Color(0xFFBFB0AA),
    ink: Color(0xFF2B1E1E),
    inkSoft: Color(0xFF695958),
    inkFaint: Color(0xFF6E5E5D),
    accent: Color(0xFF743957),
    accentWell: Color(0xFFF5D8E4),
    onAccent: Colors.white,
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _clayDark = SkinPalette(
    bg: Color(0xFF1A1415),
    card: Color(0xFF241C1E),
    band: Color(0xFF2C2325),
    well: Color(0xFF342A2C),
    rule: Color(0xFF3E3335),
    edge: Color(0xFF6B5D5F),
    ink: Color(0xFFEDE2E0),
    inkSoft: Color(0xFFB5A7A5),
    inkFaint: Color(0xFFA09391),
    accent: Color(0xFFE2A5C2),
    accentWell: Color(0xFF4A2638),
    onAccent: Color(0xFF2E0F1F),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  // ── Modern ────────────────────────────────────────────────────────────────
  static const _modernLight = SkinPalette(
    bg: Color(0xFFF7F6FC),
    card: Color(0xFFFFFFFF),
    band: Color(0xFFEFEDFA),
    well: Color(0xFFE8E5F7),
    rule: Color(0xFFE0DCF2),
    edge: Color(0xFFC3BCE4),
    ink: Color(0xFF1C1A2E),
    inkSoft: Color(0xFF5B5580),
    inkFaint: Color(0xFF6C668D),
    accent: Color(0xFF6246EA),
    accentWell: Color(0xFFE6E0FF),
    onAccent: Colors.white,
    danger: Color(0xFFE0355A),
    ok: Color(0xFF119E8E),
  );

  static const _modernDark = SkinPalette(
    bg: Color(0xFF14121F),
    card: Color(0xFF1D1A2E),
    band: Color(0xFF262138),
    well: Color(0xFF2F2944),
    rule: Color(0xFF3A3352),
    edge: Color(0xFF5F5680),
    ink: Color(0xFFEDEAF7),
    inkSoft: Color(0xFFB6AFD1),
    inkFaint: Color(0xFF8F88A9),
    accent: Color(0xFF9B8CFF),
    accentWell: Color(0xFF2E2757),
    onAccent: Color(0xFF16112E),
    danger: Color(0xFFFF6B8A),
    ok: Color(0xFF4ED8C4),
  );

  // ── Gece (OLED) ───────────────────────────────────────────────────────────
  //
  // `bg` **tam siyah**: OLED'de kapalı piksel = harcanmayan pil. Basamaklar
  // siyahın üstünde çok az açılır; kenarlık ayrımı taşır, dolgu değil.
  static const _nightDark = SkinPalette(
    bg: Color(0xFF000000),
    card: Color(0xFF0A0A0C),
    band: Color(0xFF121216),
    well: Color(0xFF1A1A20),
    rule: Color(0xFF26262E),
    edge: Color(0xFF4A4A55),
    ink: Color(0xFFE6E6EA),
    inkSoft: Color(0xFFA0A0AA),
    inkFaint: Color(0xFF7E7E88),
    accent: Color(0xFF64B5FF),
    accentWell: Color(0xFF10243A),
    onAccent: Color(0xFF00121F),
    danger: Color(0xFFFF6E6E),
    ok: Color(0xFF5FD98A),
  );
}

/// Bir ailenin **simge dili** (2026-10-18, kullanıcı: *"temalar simgeleri de
/// değiştirsin"*). Pano kutuları, araçlar ve ayar kategorileri aynı glifi
/// ([FmTintedIcon]) kullanıyor; stil orada uygulanır, ekranlar bilmez.
enum SkinIconStyle {
  /// Üstten açık, alttan koyu degrade glif (varsayılan, çerçevesiz).
  gradient,

  /// Düz tek renk çizgi glif — sakin ağırlık (İş programı, Gece).
  outlined,
}

/// Bir ailenin **renk dışı** kimliği: köşe, simge ölçeği, satır sıklığı.
///
/// Kullanıcı "sanki telefonun ana temasını değiştirir gibi" dedi; bunu veren
/// şey renk değil, ölçüdür. Aynı palet keskin köşe + küçük simgeyle "iş
/// programı", yuvarlak köşe + büyük simgeyle "modern" görünür.
class SkinMetrics {
  final double radiusControl;
  final double radiusCard;
  final double radiusSheet;

  /// Dosya/klasör simgelerine uygulanan çarpan (1.0 = bugünkü ölçü).
  final double iconScale;

  /// Liste satırı dikey iç boşluğu — yoğunluğun asıl kaynağı.
  final double rowPadding;

  /// Material'ın kendi yoğunluk ayarı (buton/onay kutusu gibi hazır
  /// bileşenler bunu dinler; kendi satırlarımız [rowPadding]'i).
  final VisualDensity density;

  /// Pano/araç simgelerinin çizim dili (bkz. [SkinIconStyle]).
  final SkinIconStyle iconStyle;

  /// Klasör gövdesinin rengi; null = uygulamanın kehribarı (`FmColors.folder`).
  final Color? folderColor;

  const SkinMetrics({
    required this.radiusControl,
    required this.radiusCard,
    required this.radiusSheet,
    required this.iconScale,
    required this.rowPadding,
    required this.density,
    required this.iconStyle,
    this.folderColor,
  });

  /// Klasör/dosya glifleri çizgi mi (`outlined`) dolu mu (`rounded`)?
  bool get outlinedIcons => iconStyle == SkinIconStyle.outlined;

  static SkinMetrics of(AppSkin skin) => switch (skin) {
        // Notlar'la aynı ölçü: kart 16, levha 24 (TEMA_PLANI F30.2).
        AppSkin.sage || AppSkin.porcelain || AppSkin.clay => const SkinMetrics(
            radiusControl: 12,
            radiusCard: 16,
            radiusSheet: 24,
            iconScale: 1,
            rowPadding: 4,
            density: VisualDensity.standard,
            iconStyle: SkinIconStyle.gradient,
          ),
        // Büyük yuvarlaklık + %12 büyük simge + rahat satır.
        AppSkin.modern => const SkinMetrics(
            radiusControl: 18,
            radiusCard: 24,
            radiusSheet: 32,
            iconScale: 1.12,
            rowPadding: 8,
            density: VisualDensity.comfortable,
            iconStyle: SkinIconStyle.gradient,
            folderColor: Color(0xFF7C5CFA),
          ),
        AppSkin.night || AppSkin.system => const SkinMetrics(
            radiusControl: 12,
            radiusCard: 16,
            radiusSheet: 28,
            iconScale: 1,
            rowPadding: 4,
            density: VisualDensity.standard,
            iconStyle: SkinIconStyle.outlined,
          ),
      };
}

/// **Hazır arka plan renkleri** (kullanıcı kararı 2026-08-25: serbest renk
/// çarkı değil, 12 hazır renk).
///
/// Serbest seçici okunmaz ekran üretebiliyordu; hazır palet her zaman
/// güvenli. Yine de renk koyuysa mürekkep otomatik dönüyor
/// ([SkinPalette._readable]) — kullanıcı "gece mavisi"ni açık ailede
/// seçtiğinde de metin okunur kalır.
class AppBackground {
  final String id;
  final String labelKey;

  /// Açık ailelerde uygulanan zemin.
  final Color light;

  /// Koyu ailelerde uygulanan zemin.
  final Color dark;

  const AppBackground(this.id, this.labelKey, this.light, this.dark);

  /// `id == 'default'` → ailenin kendi zemini (hiçbir şey uygulanmaz).
  bool get isDefault => id == 'default';

  static const values = <AppBackground>[
    AppBackground('default', 'bgc.default', Color(0xFFEAF0EB), Color(0xFF131916)),
    AppBackground('white', 'bgc.white', Color(0xFFFFFFFF), Color(0xFF101012)),
    AppBackground('paper', 'bgc.paper', Color(0xFFFAF6EC), Color(0xFF1B1813)),
    AppBackground('sand', 'bgc.sand', Color(0xFFF6EFE2), Color(0xFF221D16)),
    AppBackground('rose', 'bgc.rose', Color(0xFFFCF0F2), Color(0xFF241619)),
    AppBackground('mint', 'bgc.mint', Color(0xFFEFF8F2), Color(0xFF12211A)),
    AppBackground('ice', 'bgc.ice', Color(0xFFEDF4FB), Color(0xFF121C26)),
    AppBackground('lilac', 'bgc.lilac', Color(0xFFF3EFFC), Color(0xFF1B1727)),
    AppBackground('grey', 'bgc.grey', Color(0xFFF2F3F5), Color(0xFF17181A)),
    AppBackground('olive', 'bgc.olive', Color(0xFFF2F4E8), Color(0xFF1A1D14)),
    AppBackground('navy', 'bgc.navy', Color(0xFFE9EEF6), Color(0xFF0D1524)),
    AppBackground('black', 'bgc.black', Color(0xFFEDEDED), Color(0xFF000000)),
  ];

  static AppBackground byId(String? id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return values.first;
  }
}

/// Android 12+ sistem vurgu rengi (duvar kâğıdından). Açılışta yerel
/// kanaldan bir kez okunur (`NativeExtras.systemAccent`); okunamazsa null ve
/// [AppSkin.system] listelenmez.
abstract final class SystemAccent {
  static Color? light;
  static Color? dark;

  static bool get available => light != null && dark != null;

  static SkinPalette apply(SkinPalette base, {required bool dark}) {
    final accent = dark ? SystemAccent.dark : light;
    if (accent == null) return base;
    final onAccent =
        accent.computeLuminance() > 0.45 ? const Color(0xFF1B1B1F) : Colors.white;
    return SkinPalette(
      bg: base.bg,
      card: base.card,
      band: base.band,
      well: base.well,
      rule: base.rule,
      edge: base.edge,
      ink: base.ink,
      inkSoft: base.inkSoft,
      inkFaint: base.inkFaint,
      accent: accent,
      accentWell: Color.lerp(base.bg, accent, dark ? 0.28 : 0.16) ?? accent,
      onAccent: onAccent,
      danger: base.danger,
      ok: base.ok,
    );
  }
}

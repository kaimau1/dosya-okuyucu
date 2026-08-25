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
  /// Uygulamanın 2026-08-04'ten beri gelen kimliği: kağıt zemin, mürekkep
  /// metin, gölge yerine cetvel çizgisi. Artık ADIYLA anılıyor — kullanıcı
  /// haklıydı, bu "açık tema" değil "kağıt tema".
  paper,

  /// Düz **açık** tema: nötr beyaz/gri, kağıdın sıcaklığı yok. Kağıt dokusunu
  /// sevmeyen kullanıcının aradığı şey buydu.
  light,

  /// **Modern:** canlı mor-mavi vurgu, büyük yuvarlak köşeler, büyük simgeler,
  /// rahat satır aralığı. Material 3'ün kendi hissine en yakın aile.
  modern,

  /// **İş programı:** nötr gri-mavi, keskin köşeler, küçük simgeler, sıkı
  /// satır aralığı — ekrana çok bilgi sığar. Excel/Outlook hissi.
  office,

  /// **Gece (OLED):** saf siyah zemin. Koyu temadan farkı, `#000000` pikselin
  /// OLED ekranda kapalı olması — hem pil hem gece okunurluğu.
  night;

  String get labelKey => switch (this) {
        AppSkin.paper => 'skin.paper',
        AppSkin.light => 'skin.light',
        AppSkin.modern => 'skin.modern',
        AppSkin.office => 'skin.office',
        AppSkin.night => 'skin.night',
      };

  String get descriptionKey => switch (this) {
        AppSkin.paper => 'skin.paper_sub',
        AppSkin.light => 'skin.light_sub',
        AppSkin.modern => 'skin.modern_sub',
        AppSkin.office => 'skin.office_sub',
        AppSkin.night => 'skin.night_sub',
      };

  /// Aile yalnız koyu çalışıyor mu? (Gece/OLED'in açık karşılığı yok.)
  bool get forcesDark => this == AppSkin.night;

  static AppSkin byName(String? name, {AppSkin fallback = AppSkin.paper}) {
    for (final s in AppSkin.values) {
      if (s.name == name) return s;
    }
    return fallback;
  }
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
      AppSkin.paper => dark ? _paperDark : _paperLight,
      AppSkin.light => dark ? _neutralDark : _neutralLight,
      AppSkin.modern => dark ? _modernDark : _modernLight,
      AppSkin.office => dark ? _officeDark : _officeLight,
      AppSkin.night => _nightDark,
    };
  }

  // ── Kağıt ─────────────────────────────────────────────────────────────────
  static const _paperLight = SkinPalette(
    bg: Color(0xFFFEFEFC),
    card: Color(0xFFFCFBF7),
    band: Color(0xFFF9F7F1),
    well: Color(0xFFF5F3EB),
    rule: Color(0xFFEBE7DC),
    edge: Color(0xFFD9D2C4),
    ink: Color(0xFF262219),
    inkSoft: Color(0xFF6E6555),
    inkFaint: Color(0xFF8A8071),
    accent: Color(0xFF2E5AA8),
    accentWell: Color(0xFFE3E9F5),
    onAccent: Colors.white,
    danger: Color(0xFFB23A2E),
    ok: Color(0xFF2F6B3A),
  );

  static const _paperDark = SkinPalette(
    bg: Color(0xFF1A1712),
    card: Color(0xFF221E17),
    band: Color(0xFF2C2720),
    well: Color(0xFF332D24),
    rule: Color(0xFF3A342A),
    edge: Color(0xFF6B6455),
    ink: Color(0xFFE8E1D3),
    inkSoft: Color(0xFFB5AB98),
    inkFaint: Color(0xFF8C8271),
    accent: Color(0xFF7FA3E0),
    accentWell: Color(0xFF26364D),
    onAccent: Color(0xFF13202F),
    danger: Color(0xFFD9756B),
    ok: Color(0xFF7FA98A),
  );

  // ── Açık (nötr) ───────────────────────────────────────────────────────────
  //
  // Kağıdın kremi tamamen alındı: zemin saf beyaz, basamaklar nötr gri.
  static const _neutralLight = SkinPalette(
    bg: Color(0xFFFFFFFF),
    card: Color(0xFFFBFBFC),
    band: Color(0xFFF4F5F7),
    well: Color(0xFFEDEEF1),
    rule: Color(0xFFE2E4E9),
    edge: Color(0xFFC7CBD3),
    ink: Color(0xFF1B1D21),
    inkSoft: Color(0xFF5A5F69),
    inkFaint: Color(0xFF80868F),
    accent: Color(0xFF1F6FEB),
    accentWell: Color(0xFFE1ECFD),
    onAccent: Colors.white,
    danger: Color(0xFFC62828),
    ok: Color(0xFF2E7D32),
  );

  static const _neutralDark = SkinPalette(
    bg: Color(0xFF16181C),
    card: Color(0xFF1D2025),
    band: Color(0xFF25282F),
    well: Color(0xFF2C3038),
    rule: Color(0xFF343943),
    edge: Color(0xFF5B616C),
    ink: Color(0xFFE7E9EC),
    inkSoft: Color(0xFFB0B5BD),
    inkFaint: Color(0xFF868C95),
    accent: Color(0xFF6EA8FF),
    accentWell: Color(0xFF1E3252),
    onAccent: Color(0xFF0B1726),
    danger: Color(0xFFE57373),
    ok: Color(0xFF81C784),
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
    inkFaint: Color(0xFF837CA8),
    accent: Color(0xFF6246EA),
    accentWell: Color(0xFFE6E0FF),
    onAccent: Colors.white,
    danger: Color(0xFFE0355A),
    ok: Color(0xFF12A594),
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
    inkFaint: Color(0xFF8B84A6),
    accent: Color(0xFF9B8CFF),
    accentWell: Color(0xFF2E2757),
    onAccent: Color(0xFF16112E),
    danger: Color(0xFFFF6B8A),
    ok: Color(0xFF4ED8C4),
  );

  // ── İş programı ───────────────────────────────────────────────────────────
  static const _officeLight = SkinPalette(
    bg: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    band: Color(0xFFE8EAEE),
    well: Color(0xFFDEE1E7),
    rule: Color(0xFFCBD0D8),
    edge: Color(0xFFA9B0BC),
    ink: Color(0xFF1A1F27),
    inkSoft: Color(0xFF4C5563),
    inkFaint: Color(0xFF6F7885),
    accent: Color(0xFF1A5FB4),
    accentWell: Color(0xFFDCE7F6),
    onAccent: Colors.white,
    danger: Color(0xFFA02020),
    ok: Color(0xFF1F6B3B),
  );

  static const _officeDark = SkinPalette(
    bg: Color(0xFF15181D),
    card: Color(0xFF1C2027),
    band: Color(0xFF232830),
    well: Color(0xFF2A303A),
    rule: Color(0xFF333A45),
    edge: Color(0xFF59616E),
    ink: Color(0xFFE3E7ED),
    inkSoft: Color(0xFFA9B1BD),
    inkFaint: Color(0xFF7E8794),
    accent: Color(0xFF5B9BE8),
    accentWell: Color(0xFF1B2C43),
    onAccent: Color(0xFF091320),
    danger: Color(0xFFE06C6C),
    ok: Color(0xFF6FBF88),
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
    inkFaint: Color(0xFF75757F),
    accent: Color(0xFF64B5FF),
    accentWell: Color(0xFF10243A),
    onAccent: Color(0xFF00121F),
    danger: Color(0xFFFF6E6E),
    ok: Color(0xFF5FD98A),
  );
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

  /// Klasör/dosya glifleri dolu mu (`rounded`) yoksa çizgi mi (`outlined`)?
  final bool outlinedIcons;

  const SkinMetrics({
    required this.radiusControl,
    required this.radiusCard,
    required this.radiusSheet,
    required this.iconScale,
    required this.rowPadding,
    required this.density,
    required this.outlinedIcons,
  });

  static SkinMetrics of(AppSkin skin) => switch (skin) {
        AppSkin.paper => const SkinMetrics(
            radiusControl: 11,
            radiusCard: 14,
            radiusSheet: 26,
            iconScale: 1,
            rowPadding: 4,
            density: VisualDensity.standard,
            outlinedIcons: false,
          ),
        AppSkin.light => const SkinMetrics(
            radiusControl: 12,
            radiusCard: 16,
            radiusSheet: 28,
            iconScale: 1,
            rowPadding: 4,
            density: VisualDensity.standard,
            outlinedIcons: false,
          ),
        // Büyük yuvarlaklık + %12 büyük simge + rahat satır.
        AppSkin.modern => const SkinMetrics(
            radiusControl: 18,
            radiusCard: 24,
            radiusSheet: 32,
            iconScale: 1.12,
            rowPadding: 8,
            density: VisualDensity.comfortable,
            outlinedIcons: false,
          ),
        // Keskin köşe + %22 küçük simge + sıkı satır: ekrana çok satır sığar.
        AppSkin.office => const SkinMetrics(
            radiusControl: 4,
            radiusCard: 4,
            radiusSheet: 10,
            iconScale: 0.78,
            rowPadding: 0,
            density: VisualDensity.compact,
            outlinedIcons: true,
          ),
        AppSkin.night => const SkinMetrics(
            radiusControl: 12,
            radiusCard: 16,
            radiusSheet: 28,
            iconScale: 1,
            rowPadding: 4,
            density: VisualDensity.standard,
            outlinedIcons: true,
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
    AppBackground('default', 'bgc.default', Color(0xFFFEFEFC), Color(0xFF1A1712)),
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

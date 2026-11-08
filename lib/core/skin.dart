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

  // 2026-11-06 (kullanıcı: "notlardan örnek alıp temalar ekleyelim"):
  // Notlar'ın `ThemeFamily` D–J aileleri, aynı "masa ve kâğıt" belirteçleri.

  /// **Lavanta**: leylak grisi masa, mürdüm mor vurgu.
  lavender,

  /// **Zeytin**: zeytin taşı masa, zeytin yeşili vurgu.
  olive,

  /// **Klasik beyaz**: açık gri masa, bembeyaz kâğıt, mavi vurgu.
  white,

  /// **Saman kâğıdı**: saman masa, krem kâğıt, sepya vurgu.
  straw,

  /// **Krem**: açık krem masa, fildişi kâğıt, kehribar vurgu.
  cream,

  /// **Şeftali**: okuma rahatlığı için sıcak pastel zemin.
  peach,

  /// **Nane**: yeşil-mavi, uzun okumada göz yormayan ton.
  mint,

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
        AppSkin.lavender => 'skin.lavender',
        AppSkin.olive => 'skin.olive',
        AppSkin.white => 'skin.white',
        AppSkin.straw => 'skin.straw',
        AppSkin.cream => 'skin.cream',
        AppSkin.peach => 'skin.peach',
        AppSkin.mint => 'skin.mint',
        AppSkin.modern => 'skin.modern',
        AppSkin.night => 'skin.night',
        AppSkin.system => 'skin.system',
      };

  String get descriptionKey => switch (this) {
        AppSkin.sage => 'skin.sage_sub',
        AppSkin.porcelain => 'skin.porcelain_sub',
        AppSkin.clay => 'skin.clay_sub',
        AppSkin.lavender => 'skin.lavender_sub',
        AppSkin.olive => 'skin.olive_sub',
        AppSkin.white => 'skin.white_sub',
        AppSkin.straw => 'skin.straw_sub',
        AppSkin.cream => 'skin.cream_sub',
        AppSkin.peach => 'skin.peach_sub',
        AppSkin.mint => 'skin.mint_sub',
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

  /// **Vurgu rengini değiştirir** (Faz 40 / 8). Kuyu (seçili pil) zeminle
  /// vurgunun karışımı; vurgunun üstündeki yazı beyaz ya da siyahtan hangisi
  /// daha okunursa. Renkler [AppAccent]te `contrast_test` ile kilitli.
  SkinPalette withAccent(Color newAccent, {required bool dark}) {
    final white = _contrast(Colors.white, newAccent);
    final black = _contrast(Colors.black, newAccent);
    return SkinPalette(
      bg: bg,
      card: card,
      band: band,
      well: well,
      rule: rule,
      edge: edge,
      ink: ink,
      inkSoft: inkSoft,
      inkFaint: inkFaint,
      accent: newAccent,
      accentWell: _wellFor(newAccent, dark: dark),
      onAccent: white >= black ? Colors.white : Colors.black,
      danger: danger,
      ok: ok,
    );
  }

  /// Seçili pil kuyusu: zeminle vurgunun karışımı. Kuyunun üstündeki yazı
  /// (açıkta vurgu, koyuda mürekkep) ≥ 4,5:1 kalana dek karışım azaltılır —
  /// sarımsı zeminli ailelerde (Saman kâğıdı) %16 kiremit yazıyı boğuyordu.
  Color _wellFor(Color newAccent, {required bool dark}) {
    final text = dark ? ink : newAccent;
    var t = dark ? 0.28 : 0.16;
    var well = Color.lerp(bg, newAccent, t) ?? newAccent;
    while (t > 0.04 && _contrast(text, well) < 4.5) {
      t -= 0.02;
      well = Color.lerp(bg, newAccent, t) ?? newAccent;
    }
    return well;
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
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
      AppSkin.lavender => dark ? _lavenderDark : _lavenderLight,
      AppSkin.olive => dark ? _oliveDark : _oliveLight,
      AppSkin.white => dark ? _whiteDark : _whiteLight,
      AppSkin.straw => dark ? _strawDark : _strawLight,
      AppSkin.cream => dark ? _creamDark : _creamLight,
      AppSkin.peach => dark ? _peachDark : _peachLight,
      AppSkin.mint => dark ? _mintDark : _mintLight,
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

  // ── Notlar D–J aileleri (2026-11-06) — Notlar `app_palette.dart`tan;
  // soluk mürekkepler kontrast için bir tık koyulaştırıldı.
  static const _lavenderLight = SkinPalette(
    bg: Color(0xFFEDEBF3),
    card: Color(0xFFFCFBFE),
    band: Color(0xFFF7F5FB),
    well: Color(0xFFF1EFF6),
    rule: Color(0xFFD4D1DD),
    edge: Color(0xFFADAAB8),
    ink: Color(0xFF211F2A),
    inkSoft: Color(0xFF55525F),
    inkFaint: Color(0xFF5F5C6A),
    accent: Color(0xFF5B4B8A),
    accentWell: Color(0xFFE5DEFA),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _lavenderDark = SkinPalette(
    bg: Color(0xFF16151B),
    card: Color(0xFF1F1D26),
    band: Color(0xFF24222B),
    well: Color(0xFF24222B),
    rule: Color(0xFF3C3A45),
    edge: Color(0xFF63606C),
    ink: Color(0xFFE7E4EF),
    inkSoft: Color(0xFFB8B5C2),
    inkFaint: Color(0xFFAEACB8),
    accent: Color(0xFFC6B8F4),
    accentWell: Color(0xFF433669),
    onAccent: Color(0xFF2C2152),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _oliveLight = SkinPalette(
    bg: Color(0xFFEDEEE6),
    card: Color(0xFFFBFCF8),
    band: Color(0xFFF6F7F1),
    well: Color(0xFFF0F1EA),
    rule: Color(0xFFD4D6CB),
    edge: Color(0xFFADAFA4),
    ink: Color(0xFF1F221B),
    inkSoft: Color(0xFF52564B),
    inkFaint: Color(0xFF5D6056),
    accent: Color(0xFF4F6A2A),
    accentWell: Color(0xFFD9EBC0),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _oliveDark = SkinPalette(
    bg: Color(0xFF161813),
    card: Color(0xFF1F221B),
    band: Color(0xFF242720),
    well: Color(0xFF242720),
    rule: Color(0xFF3C3F37),
    edge: Color(0xFF62655C),
    ink: Color(0xFFE4E6DD),
    inkSoft: Color(0xFFB6B9AE),
    inkFaint: Color(0xFFADB0A5),
    accent: Color(0xFFB2D18A),
    accentWell: Color(0xFF384F18),
    onAccent: Color(0xFF203606),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _whiteLight = SkinPalette(
    bg: Color(0xFFF3F4F6),
    card: Color(0xFFFFFFFF),
    band: Color(0xFFFAFAFB),
    well: Color(0xFFF1F2F4),
    rule: Color(0xFFD6D9DE),
    edge: Color(0xFFAAADB3),
    ink: Color(0xFF1A1C1F),
    inkSoft: Color(0xFF4A4E55),
    inkFaint: Color(0xFF545860),
    accent: Color(0xFF1F5FBF),
    accentWell: Color(0xFFD8E4FA),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _whiteDark = SkinPalette(
    bg: Color(0xFF121314),
    card: Color(0xFF1C1D1F),
    band: Color(0xFF212224),
    well: Color(0xFF212224),
    rule: Color(0xFF3A3B3F),
    edge: Color(0xFF616268),
    ink: Color(0xFFE6E7EA),
    inkSoft: Color(0xFFB7B9BE),
    inkFaint: Color(0xFFADAFB5),
    accent: Color(0xFFA8C5F5),
    accentWell: Color(0xFF22437A),
    onAccent: Color(0xFF0B2A5C),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _strawLight = SkinPalette(
    bg: Color(0xFFEDE3C8),
    card: Color(0xFFFCF8EC),
    band: Color(0xFFF8F2E1),
    well: Color(0xFFF3EBD6),
    rule: Color(0xFFD6CAAB),
    edge: Color(0xFFAEA286),
    ink: Color(0xFF2A2216),
    inkSoft: Color(0xFF574C38),
    inkFaint: Color(0xFF605640),
    accent: Color(0xFF7A4A1E),
    accentWell: Color(0xFFF2DCC0),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _strawDark = SkinPalette(
    bg: Color(0xFF1A1711),
    card: Color(0xFF24201A),
    band: Color(0xFF29251E),
    well: Color(0xFF29251E),
    rule: Color(0xFF423C32),
    edge: Color(0xFF6A6255),
    ink: Color(0xFFEDE5D3),
    inkSoft: Color(0xFFC0B6A2),
    inkFaint: Color(0xFFB6AD9A),
    accent: Color(0xFFE5B98A),
    accentWell: Color(0xFF5E3E1C),
    onAccent: Color(0xFF452A0D),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _creamLight = SkinPalette(
    bg: Color(0xFFF6F0DE),
    card: Color(0xFFFFFDF6),
    band: Color(0xFFFBF7EC),
    well: Color(0xFFF7F1E2),
    rule: Color(0xFFE1D8BF),
    edge: Color(0xFFB4AC94),
    ink: Color(0xFF2B261C),
    inkSoft: Color(0xFF5A5241),
    inkFaint: Color(0xFF635B49),
    accent: Color(0xFF8A5A22),
    accentWell: Color(0xFFF6E3C4),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _creamDark = SkinPalette(
    bg: Color(0xFF1B1914),
    card: Color(0xFF25221C),
    band: Color(0xFF2A2721),
    well: Color(0xFF2A2721),
    rule: Color(0xFF433F36),
    edge: Color(0xFF6B6659),
    ink: Color(0xFFEEE8D8),
    inkSoft: Color(0xFFC2BAA7),
    inkFaint: Color(0xFFB8B19E),
    accent: Color(0xFFE8BE87),
    accentWell: Color(0xFF63431D),
    onAccent: Color(0xFF47290A),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _peachLight = SkinPalette(
    bg: Color(0xFFF7EAE2),
    card: Color(0xFFFFF9F5),
    band: Color(0xFFFCF2EC),
    well: Color(0xFFF8EDE6),
    rule: Color(0xFFE2CFC3),
    edge: Color(0xFFB6A49B),
    ink: Color(0xFF2B211D),
    inkSoft: Color(0xFF5C4D46),
    inkFaint: Color(0xFF65564F),
    accent: Color(0xFFA3432C),
    accentWell: Color(0xFFFBDCD2),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _peachDark = SkinPalette(
    bg: Color(0xFF1C1715),
    card: Color(0xFF27201D),
    band: Color(0xFF2C2522),
    well: Color(0xFF2C2522),
    rule: Color(0xFF453B37),
    edge: Color(0xFF6D625D),
    ink: Color(0xFFF0E5E0),
    inkSoft: Color(0xFFC6B8B1),
    inkFaint: Color(0xFFBCAEA8),
    accent: Color(0xFFF4B39F),
    accentWell: Color(0xFF77311F),
    onAccent: Color(0xFF561D0D),
    danger: Color(0xFFE8897F),
    ok: Color(0xFF8FC79E),
  );

  static const _mintLight = SkinPalette(
    bg: Color(0xFFE5F2EE),
    card: Color(0xFFF9FDFB),
    band: Color(0xFFF2FAF7),
    well: Color(0xFFECF6F2),
    rule: Color(0xFFCCDCD6),
    edge: Color(0xFFA4B5AF),
    ink: Color(0xFF182623),
    inkSoft: Color(0xFF475A55),
    inkFaint: Color(0xFF526560),
    accent: Color(0xFF0E6B5C),
    accentWell: Color(0xFFC3EDE3),
    onAccent: Color(0xFFFFFFFF),
    danger: Color(0xFFB0402F),
    ok: Color(0xFF2F6B4A),
  );

  static const _mintDark = SkinPalette(
    bg: Color(0xFF111A18),
    card: Color(0xFF1A2421),
    band: Color(0xFF1F2A26),
    well: Color(0xFF1F2A26),
    rule: Color(0xFF37433E),
    edge: Color(0xFF5C6A65),
    ink: Color(0xFFDFEDE8),
    inkSoft: Color(0xFFAEC0BA),
    inkFaint: Color(0xFFA5B6B1),
    accent: Color(0xFF7FD6C3),
    accentWell: Color(0xFF0B5146),
    onAccent: Color(0xFF00382F),
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
        AppSkin.sage ||
        AppSkin.porcelain ||
        AppSkin.clay ||
        AppSkin.lavender ||
        AppSkin.olive ||
        AppSkin.white ||
        AppSkin.straw ||
        AppSkin.cream ||
        AppSkin.peach ||
        AppSkin.mint =>
          const SkinMetrics(
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
            // 2026-11-08 bug (kullanıcı: *"Gece OLED temada simgeler eskiye
            // dönüyor"*): burada `outlined` vardı → 2026-11-04 squircle/2.5D
            // çizimleri atlanıp eski düz glifler çiziliyordu. Koyu ailede de
            // yeni çizim (koyu varyantı `FmSquircleIcon`/`FmGlyph` içinde).
            iconStyle: SkinIconStyle.gradient,
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

/// **Vurgu rengi** seçimi (Faz 40 / 8, 2026-11-05) — tema ailesinden
/// BAĞIMSIZ: ailenin zemini/mürekkebi kalır, yalnız seçili sekme, birincil
/// düğme ve vurgular değişir. Açık ve koyu karşılıklar ayrı: açıkta koyu
/// ton (beyaz yazı ≥ 4,5:1), koyuda açık ton (siyah yazı). `default` =
/// ailenin kendi vurgusu.
class AppAccent {
  final String id;
  final String labelKey;
  final Color light;
  final Color dark;

  const AppAccent(this.id, this.labelKey, this.light, this.dark);

  bool get isDefault => id == 'default';

  static const values = <AppAccent>[
    AppAccent('default', 'acc.default', Color(0xFF106561), Color(0xFF78C8C1)),
    AppAccent('teal', 'acc.teal', Color(0xFF0D5E5A), Color(0xFF7FD3CB)),
    AppAccent('blue', 'acc.blue', Color(0xFF1B53A8), Color(0xFF9DC1FF)),
    AppAccent('indigo', 'acc.indigo', Color(0xFF4B3FB5), Color(0xFFB4A9FF)),
    AppAccent('plum', 'acc.plum', Color(0xFF7B2F6B), Color(0xFFF0A8DF)),
    AppAccent('forest', 'acc.forest', Color(0xFF285E2D), Color(0xFF9FD8A4)),
    AppAccent('rust', 'acc.rust', Color(0xFF9A3F1C), Color(0xFFFFB59A)),
  ];

  static AppAccent byId(String? id) {
    for (final a in values) {
      if (a.id == id) return a;
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

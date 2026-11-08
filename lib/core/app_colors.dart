import 'package:flutter/material.dart';

import 'skin.dart';

/// **Anlamsal renk tokenları** (Faz 15 / madde 2, 2026-10-22).
///
/// KÖK NEDEN: 150 sabit `Color(0x…)` ve 213 doğrudan `Colors.*` ekranlara
/// dağılmıştı; "başarılı" bir ekranda `0xFF2E7D32`, öbüründe `Colors.green`,
/// üçüncüsünde temanın `ok`u idi. Koyu temada bunların bir kısmı zeminde
/// kayboluyordu. Artık:
/// * **durum rolleri** ([success], [warning], [danger], [info], [selection])
///   tema ailesinin paletinden türetilir → koyu temada kendiliğinden açılır,
///   kontrastı `contrast_test` bekler;
/// * **medya perdesi** ([mediaChrome], [onMedia]…) temadan BAĞIMSIZ sabittir:
///   oynatıcı ve galeri her temada görüntünün üstünde siyah perde kullanır;
/// * **kimlik tonları** ([AppHues]) pano kutuları, araçlar ve ayar
///   kategorileri gibi "bu kutu hep turkuaz" denen yerler içindir — tek
///   tabloda, adla.
///
/// Erişim: `AppColors.of(context).success`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  final Color success;
  final Color warning;
  final Color danger;
  final Color info;

  /// Seçili satır/kart dolgusu (vurgunun hafif tonu).
  final Color selection;

  /// Levha/iletişim penceresi arkasındaki karartma.
  final Color scrim;

  const AppColors({
    required this.success,
    required this.warning,
    required this.danger,
    required this.info,
    required this.selection,
    required this.scrim,
  });

  // ── temadan bağımsız medya perdesi ─────────────────────────────────────
  /// Görüntü/video üstündeki çubuk zemini (yarı saydam siyah).
  static const mediaChrome = Color(0xB3000000);

  /// Oynatıcı/galeri tam zemini.
  static const mediaSurface = Color(0xFF000000);

  /// Perde üstündeki birincil metin/simge.
  static const onMedia = Color(0xFFFFFFFF);

  /// Perde üstündeki ikincil metin (süre, sayaç).
  static const onMediaSoft = Color(0xB3FFFFFF);

  /// Perde üstündeki pasif/ayraç.
  static const onMediaFaint = Color(0x61FFFFFF);

  /// Görüntü üstüne düşen gölge (küçük resim rozeti, alt yazı gölgesi).
  static const shadow = Color(0x33000000);

  /// Görünmez dolgu (kenarlık/zemin "yok").
  static const none = Color(0x00000000);

  // ── Faz 15b (2026-10-23): ekranlardaki `Colors.*` taşımasının tokenları.
  // Değerler taşınan sabitlerle BİREBİR aynı — görünüm değişmedi.

  /// Perde üstünde pasif dolgu (ilerleme çubuğu izi).
  static const onMediaWell = Color(0x3DFFFFFF);

  /// Perde üstünde kılavuz çizgisi (kırpma üçte biri).
  static const onMediaGuide = Color(0x8AFFFFFF);

  /// Görüntü üstündeki rozet/oynat düğmesi zemini.
  static const mediaScrim = Color(0x8A000000);

  /// Görüntü üstündeki hafif karartma (seçim kutusu zemini).
  static const mediaScrimLight = Color(0x73000000);

  /// Belge **sayfası** — PDF/Word/slayt/QR/imza her temada beyaz kâğıttır.
  static const page = Color(0xFFFFFFFF);

  /// Kâğıt teması belge sayfası zemini ve çerçevesi (2026-11-02, Word
  /// WebView + PDF sayfa çerçevesi; KALANLAR A7.7).
  static const paperPage = Color(0xFFFBF8F1);
  static const paperFrame = Color(0xFFD2C8B4);

  /// Word sayfa görünümünün açık temalardaki Fluent kanvası.
  static const docCanvas = Color(0xFFF3F2F1);

  /// Belge mürekkebi (imza, QR modülü, açık zemin üstü kontrast yazı).
  static const pageInk = Color(0xFF000000);

  /// Açık vurgu (fosforlu kalem) üstündeki koyu simge.
  static const inkStrong = Color(0xDD000000);

  /// Dolu marka renginin (Office kabuğu) üstündeki yazı/simge.
  static const onBrand = Color(0xFFFFFFFF);

  /// Marka zemininde pasif yazı.
  static const onBrandMuted = Color(0x61FFFFFF);

  /// Marka zemininde seçili/basılı dolgu.
  static const onBrandWell = Color(0x3DFFFFFF);

  /// Rengi açmak/koyulaştırmak için karışım uçları (`Color.lerp`).
  static const mixLight = Color(0xFFFFFFFF);
  static const mixDark = Color(0xFF000000);

  /// Klasik simge dili (2026-11-08, `FmGlyphSpec.classic`): beyaz sayfa,
  /// gri kontur ve kıvrık köşe — açık / koyu.
  static const classicPage = Color(0xFFFFFFFF);
  static const classicPageDark = Color(0xFF2B2C2F);
  static const classicEdge = Color(0xFF7A7E86);
  static const classicEdgeDark = Color(0xFF8C8F95);
  static const classicEar = Color(0xFFDDDFE3);
  static const classicEarDark = Color(0xFF45474C);

  /// Gölge/karartma tabanı — saydamlık çağıranda (`withValues(alpha:)`).
  static const shade = Color(0xFF000000);

  /// Menü/levha arkasındaki hafif ve orta karartma.
  static const barrierLight = Color(0x1F000000);
  static const barrier = Color(0x42000000);

  /// Yüzen öğe gölgesi (koyu).
  static const shadowStrong = Color(0x61000000);

  /// Belgede bulunan eşleşme ve etkin eşleşme vurgusu.
  /// Koşullu biçimde renk seçilmezse Excel'in açık kırmızı dolgusu.
  static const condFillDefault = Color(0xFFFFC7CE);

  /// Dışa aktarılan grafik görüntüsünün zemini (tema bağımsız beyaz kâğıt).
  static const chartExportPaper = Color(0xFFFFFFFF);
  static const findMatch = Color(0x7FFFEB3B);
  static const findActive = Color(0x7FFF9800);

  /// Kod düzenleyici sözdizimi renkleri (Faz 30) — açık / koyu zemin.
  static const syntaxKeywordLight = Color(0xFF7B2D9B);
  static const syntaxKeywordDark = Color(0xFFC792EA);
  static const syntaxStringLight = Color(0xFF2E7D32);
  static const syntaxStringDark = Color(0xFFA5D6A7);
  static const syntaxCommentLight = Color(0xFF78909C);
  static const syntaxCommentDark = Color(0xFF90A4AE);
  static const syntaxNumberLight = Color(0xFFB45309);
  static const syntaxNumberDark = Color(0xFFFFCC80);
  static const syntaxTypeLight = Color(0xFF00695C);
  static const syntaxTypeDark = Color(0xFF80CBC4);
  static const syntaxTagLight = Color(0xFF1565C0);
  static const syntaxTagDark = Color(0xFF90CAF9);

  /// Eşleşen parantez vurgusu.
  static const bracketMatch = Color(0x55FFC107);

  /// Slayt düzenleyicide seçili/düzenlenen kutunun çerçevesi ve imleç
  /// (PowerPoint'in seçim mavisi — belge yüzeyinde, temadan bağımsız).
  static const slideSelection = Color(0xFF2962FF);

  /// Slaytta taşırken hizalama kılavuzu (PowerPoint'in akıllı kılavuzu gibi).
  static const slideGuide = Color(0xFFE6198A);

  /// Boş yer tutucunun istem metni ve kesik çerçevesi (belge yüzeyinde).
  static const slidePrompt = Color(0xFF8A8A8A);
  static const slidePromptFrame = Color(0xFFB0B0B0);

  /// Palet → tokenlar. Uyarı ve bilgi tonları paletin parlaklığına göre
  /// seçilir: açık zeminde koyu kehribar/mavi, koyu zeminde açık.
  factory AppColors.fromPalette(SkinPalette p, Brightness b) {
    final dark = b == Brightness.dark || p.bg.computeLuminance() < 0.2;
    return AppColors(
      success: p.ok,
      warning: dark ? const Color(0xFFFFB74D) : const Color(0xFFB45309),
      danger: p.danger,
      info: dark ? const Color(0xFF64B5F6) : const Color(0xFF1565C0),
      selection: p.accentWell,
      scrim: dark ? const Color(0xB3000000) : const Color(0x8A000000),
    );
  }

  static AppColors of(BuildContext context) {
    final theme = Theme.of(context);
    return theme.extension<AppColors>() ??
        AppColors.fromPalette(
            SkinPalette.of(AppSkin.sage, theme.brightness), theme.brightness);
  }

  @override
  AppColors copyWith({
    Color? success,
    Color? warning,
    Color? danger,
    Color? info,
    Color? selection,
    Color? scrim,
  }) =>
      AppColors(
        success: success ?? this.success,
        warning: warning ?? this.warning,
        danger: danger ?? this.danger,
        info: info ?? this.info,
        selection: selection ?? this.selection,
        scrim: scrim ?? this.scrim,
      );

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      success: Color.lerp(success, other.success, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      danger: Color.lerp(danger, other.danger, t)!,
      info: Color.lerp(info, other.info, t)!,
      selection: Color.lerp(selection, other.selection, t)!,
      scrim: Color.lerp(scrim, other.scrim, t)!,
    );
  }
}

/// **Kimlik tonları** — pano kutuları, araç kartları, ayar kategorileri ve
/// grafik dilimleri. Bunlar "durum" değil "hangi kutu" bilgisi taşır; temayla
/// değişmezler (koyu temada `FmTintedIcon` kendi açma kuralını uygular).
///
/// Yeni bir kutuya renk gerekiyorsa buradan seçilir; yeni ton gerekiyorsa
/// buraya ADIYLA eklenir — ekranda `Color(0x…)` yazılmaz (bekçi:
/// `design_tokens_test`).
abstract final class AppHues {
  static const blue = Color(0xFF2F6FE0);
  static const royal = Color(0xFF3E6FD8);
  static const navy = Color(0xFF1565C0);
  static const amber = Color(0xFFF2A600);
  static const honey = Color(0xFFE39B2E);
  static const orange = Color(0xFFEF6C00);
  static const tangerine = Color(0xFFE8742A);
  static const teal = Color(0xFF0E9C8A);
  static const sea = Color(0xFF12998A);
  static const jade = Color(0xFF00897B);
  static const cyan = Color(0xFF00838F);
  static const green = Color(0xFF2E7D32);
  static const leaf = Color(0xFF3A9A4A);
  static const mint = Color(0xFF1FA463);
  static const olive = Color(0xFF827717);
  static const indigo = Color(0xFF5A5FD6);
  static const violet = Color(0xFF5E35B1);
  static const purple = Color(0xFF8B4FD1);
  static const plum = Color(0xFF6A4C93);
  static const pink = Color(0xFFE0668F);
  static const red = Color(0xFFD9433B);
  static const slate = Color(0xFF37474F);
  static const steel = Color(0xFF5B6670);
  static const gray = Color(0xFF76808C);
  static const silver = Color(0xFF9E9E9E);
  static const amberBright = Color(0xFFFFD740);

  /// Etiket ve klasör renkleri (Faz 41 / 6) — sıra KALICI (kayıtta indeks
  /// tutulur); yeni renk yalnız SONA eklenir.
  static const labels = [red, orange, amber, green, teal, blue, violet, pink, slate];
}

/// **PDF Pro düzenleme yüzeyi tokenları** (Faz 53 / 4, 2026-11-08).
///
/// Sözleşme: `docs/design/pdf_pro/etkilesim.md` + maketler
/// (`docs/design/pdf_pro/maket/`). Vurgu rengi temadan gelir
/// (`colorScheme.primary` / `primaryContainer`); burada yalnız temadan
/// bağımsız roller, vurgu oranları ve ölçüler durur — düzenleme yüzeyinde
/// sabit sayı yazılmaz.
abstract final class PdfEditTokens {
  // ── renk rolleri ───────────────────────────────────────────────────────
  /// "Kaydedilmedi" noktası ve düzenlenemeyen bloğun kesik çerçevesi.
  static const pendingLight = Color(0xFFB86A00);
  static const pendingDark = Color(0xFFFFB74D);
  static Color pending(bool dark) => dark ? pendingDark : pendingLight;

  /// Seçili bloğun üstündeki yüzen eylem çubuğu (her temada koyu).
  static const floatBar = Color(0xFF1A1F2A);
  static const onFloatBar = Color(0xFFFFFFFF);
  static const floatBarWell = Color(0x1FFFFFFF);
  static const floatBarDanger = Color(0xFFF2B8B5);

  // ── vurgu oranları (vurgu rengine `withValues(alpha:)`) ──────────────────
  /// Dinlenmedeki blok kılavuzu — "her satırı gri kutuya boğma" YOK.
  static const frameIdleAlpha = 0.14;

  /// Seçili blok dolgusu.
  static const frameFillAlpha = 0.06;

  /// Metin seçimi dolgusu (yazma kipinde).
  static const textSelectionAlpha = 0.28;

  // ── ölçüler (dp) ───────────────────────────────────────────────────────
  static const topBar = 56.0;
  static const topBarTablet = 60.0;
  static const toolBar = 64.0;
  static const contextBar = 52.0;
  static const formatBar = 52.0;
  static const railCompact = 64.0;
  static const railWide = 84.0;
  static const propertyPanel = 320.0;
  static const frameIdleWidth = 1.0;
  static const frameActiveWidth = 2.0;
  static const handle = 8.0;
  static const handleTablet = 10.0;
  static const caretWidth = 2.0;
  static const minHit = 44.0;
  static const chip = 36.0;
  static const floatGap = 8.0;
  static const floatRadius = 12.0;
  static const chipRadius = 18.0;

  /// Tablet düzeni (sol ray + sağ panel) bu kısa kenardan itibaren.
  static const tabletShortestSide = 600.0;

  /// Yazmaya girerken düzenlenen satırın ekrandaki yazı boyu (sp).
  static const readableMin = 16.0;
  static const readableMax = 20.0;
  static const readableTarget = 18.0;

  /// Yükleniyor göstergesi yalnız bu süreyi aşan işte çıkar (zamanlayıcı).
  static const loadingDelay = Duration(milliseconds: 300);
}

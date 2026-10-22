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
            SkinPalette.of(AppSkin.paper, theme.brightness), theme.brightness);
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
}

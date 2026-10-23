import 'package:flutter/widgets.dart';

/// **Hareket tokenları** (Faz 15 / madde 4, 2026-10-22).
///
/// KÖK NEDEN: 95 sabit `Duration(milliseconds: …)` vardı; aynı türden
/// geçişler 140, 150, 160, 180 ms arasında dağılmıştı ve cihazın
/// "animasyonları kaldır" ayarını yalnız 2 yer dinliyordu. Artık arayüz
/// animasyonu üç süreden birini kullanır ve [of] ile alınır: ayar açıkken
/// süre **0** olur.
///
/// Zamanlayıcılar (gecikme, yinele, sorgu ertelemesi) hareket DEĞİLDİR,
/// burada değil kendi yerlerinde kalır.
abstract final class Motion {
  /// Küçük durum değişimi: renk, simge, çip, görünür/gizli.
  static const short = Duration(milliseconds: 120);

  /// Bileşen geçişi: sayfa, levha içeriği, kaydırarak konumlama.
  static const medium = Duration(milliseconds: 220);

  /// Büyük yüzey: tam ekran geçiş, galeri açılışı.
  static const long = Duration(milliseconds: 320);

  /// Metin imlecinin yarım yanıp sönme süresi (EditableText ile aynı).
  static const caretBlink = Duration(milliseconds: 500);

  /// Giren öğe (yavaşlayarak durur).
  static const Curve enter = Curves.easeOutCubic;

  /// Çıkan öğe (hızlanarak gider).
  static const Curve exit = Curves.easeInCubic;

  /// Yerinde değişim.
  static const Curve standard = Curves.easeInOutCubic;

  /// Cihazda "animasyonları kaldır" açık mı?
  static bool reduced(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  /// [d] süresi; animasyonlar kapalıysa [Duration.zero].
  static Duration of(BuildContext context, Duration d) =>
      reduced(context) ? Duration.zero : d;

  /// Kaydırarak konumla; animasyonlar kapalıysa atla (`animateTo` sıfır
  /// süreyi kabul etmez).
  static Future<void> scrollTo(
      BuildContext context, ScrollController c, double offset,
      {Duration duration = medium, Curve curve = enter}) {
    if (reduced(context)) {
      c.jumpTo(offset);
      return Future<void>.value();
    }
    return c.animateTo(offset, duration: duration, curve: curve);
  }

  /// Sayfaya geç; animasyonlar kapalıysa atla.
  static Future<void> toPage(BuildContext context, PageController c, int page,
      {Duration duration = medium, Curve curve = enter}) {
    if (reduced(context)) {
      c.jumpToPage(page);
      return Future<void>.value();
    }
    return c.animateToPage(page, duration: duration, curve: curve);
  }
}

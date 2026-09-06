import 'package:flutter/material.dart';

/// **Hızlı sayfa geçişi** — Flutter'ın M3 varsayılanı [ZoomPageTransitionsBuilder]
/// yerine.
///
/// ## Niye değiştirildi (kullanıcı isteği 2026-09-06: *"geçiş animasyonları ve
/// alan geçişlerinde performans iyileştirmesi yap"*)
///
/// Varsayılan geçiş **300 ms** sürüyor ve iki sayfayı birden ölçekleyip
/// soluklaştırıyor. Üç ayrı maliyeti var:
///
/// 1. **Opaklık = `saveLayer`.** Solma animasyonu sayfayı her karede ayrı bir
///    katmana çizip harmanlar. Dosya listesi gibi yüzlerce küçük parçadan
///    (simge, küçük resim, metin) oluşan bir sayfada bu, geçişin en pahalı
///    işidir.
/// 2. **Anlık görüntü alma (`allowSnapshotting`).** Geçiş başlarken sayfa bir
///    kez resme çevriliyor; karmaşık sayfada bu TEK kare uzun sürüyor ve
///    animasyonun başında görünen takılma tam olarak budur.
/// 3. **300 ms** kendi başına, klasörden klasöre gezerken uygulamayı ağır
///    hissettiriyor.
///
/// Buradaki geçiş yalnız **dönüşüm (transform)** kullanır: kaydırma. Transform
/// katman açmaz, harmanlama yapmaz, anlık görüntü istemez — GPU'nun zaten
/// çizdiği katmanı kaydırır. Süre 220 ms'e (geri dönüşte 170 ms'e) çekildi:
/// gözle takip edilebilecek kadar var, beklemeye dönüşmeyecek kadar kısa.
///
/// Yön Android'in alışılmış davranışı: yeni sayfa sağdan gelir, alttaki sayfa
/// hafifçe sola kayar (paralaks). Kenardan geri hareketi ve tahmini geri
/// (predictive back) etkilenmez — ikisi de `animation` üzerinden yürüyor.
class FastPageTransitionsBuilder extends PageTransitionsBuilder {
  const FastPageTransitionsBuilder();

  @override
  Duration get transitionDuration => const Duration(milliseconds: 220);

  /// Geri dönüş daha kısa: kullanıcı geri gittiğinde **zaten gördüğü** bir
  /// sayfaya dönüyor, orada bekletmenin bir karşılığı yok.
  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 170);

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return _FastPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
  }
}

class _FastPageTransition extends StatelessWidget {
  final Animation<double> animation;
  final Animation<double> secondaryAnimation;
  final Widget child;

  const _FastPageTransition({
    required this.animation,
    required this.secondaryAnimation,
    required this.child,
  });

  /// Gelen sayfa ekranın %14'ü kadar sağdan girer. Tam genişlik (%100)
  /// "kaydırılan bir yüzey" hissi verir ama uzun mesafe = uzun süre demek;
  /// kısa mesafe hem hızlı hem yönü belli.
  static final _enter = Tween<Offset>(
    begin: const Offset(0.14, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  /// Alttaki sayfanın paralaksı — derinlik hissini veren şey bu. Küçük
  /// tutuluyor: geri dönerken sayfanın uzaktan gelmesi yavaş görünürdü.
  static final _exit = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.05, 0),
  ).chain(CurveTween(curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: secondaryAnimation.drive(_exit),
      // `transformHitTests: false`: çıkan sayfa kaydırılmış hâldeyken
      // dokunuşları yakalamasın (geçiş sırasında yanlış öğeye basılması).
      transformHitTests: false,
      child: SlideTransition(
        position: animation.drive(_enter),
        child: child,
      ),
    );
  }
}

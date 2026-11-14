import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent, SwipeEdge;

import 'motion.dart';

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
/// hafifçe sola kayar (paralaks). Android 14+ öngörülü geri hareketi
/// [_PredictiveBackPreview] ile aynı `animation`'ı sürer (Ferrari H6.6).
class FastPageTransitionsBuilder extends PageTransitionsBuilder {
  const FastPageTransitionsBuilder();

  @override
  Duration get transitionDuration => Motion.medium;

  /// Geri dönüş daha kısa: kullanıcı geri gittiğinde **zaten gördüğü** bir
  /// sayfaya dönüyor, orada bekletmenin bir karşılığı yok.
  @override
  Duration get reverseTransitionDuration => Motion.pageReverse;

  @override
  Widget buildTransitions<T>(
    PageRoute<T>? route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // "Animasyonları kaldır" açıkken sayfa yerinde belirir (Faz 15/16):
    // kaydırma yok, ilk karede tam konumda.
    if (Motion.reduced(context)) return child;
    final page = _FastPageTransition(
      animation: animation,
      secondaryAnimation: secondaryAnimation,
      child: child,
    );
    if (route == null) return page;
    return _PredictiveBackPreview(
        route: route, animation: animation, child: page);
  }
}

/// **Öngörülü geri önizlemesi** (Android 14+, Ferrari H6.6).
///
/// KÖK NEDEN: manifestte `enableOnBackInvokedCallback` açıktı ama hareket
/// sırasında hiçbir şey kıpırdamıyordu. Flutter'da geri hareketini rotaya
/// bağlayan dinleyici YALNIZ `PredictiveBackPageTransitionsBuilder`'ın
/// içinde; biz onu [FastPageTransitionsBuilder] ile değiştirince dinleyen
/// kalmadı ve çerçeve hareketi ancak parmak kalkınca düz bir "geri" olarak
/// işledi (bkz. `WidgetsBinding._handleCommitBackGesture`).
///
/// Burada aynı dinleyici kuruldu (Flutter 3.47.9 kaynağındaki
/// `_PredictiveBackGestureDetector` ile aynı sözleşme): hareket rotanın
/// animasyonunu sürer — sayfa parmakla birlikte kayar ve hafifçe küçülerek
/// alttaki sayfayı gösterir; vazgeçilirse yerine döner. Yalnız dönüşüm
/// (kaydırma + ölçek), opaklık yok — geçiş performansı kararıyla aynı.
///
/// `popGestureEnabled` false olan rotalarda (ilk sayfa, `PopScope(canPop:
/// false)`, iç geri işleyen sayfa) dinleyici hareketi ÜSTLENMEZ: çerçeve
/// eskisi gibi normal geri çağrısı yapar, `PopScope` kararını verir.
class _PredictiveBackPreview extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  final Widget child;

  const _PredictiveBackPreview({
    required this.route,
    required this.animation,
    required this.child,
  });

  @override
  State<_PredictiveBackPreview> createState() => _PredictiveBackPreviewState();
}

class _PredictiveBackPreviewState extends State<_PredictiveBackPreview>
    with WidgetsBindingObserver {
  /// Önizlemede sayfa en çok bu kadar küçülür (Android yönergesi %90).
  static const _minScale = 0.92;

  /// Hareket sürüyor ya da onaylanıp sayfa kapanıyor: ölçek uygulanır.
  /// Onaydan sonra `popGestureInProgress` false olur; bayrak olmasa sayfa
  /// kapanırken birden tam boya sıçrardı.
  bool _active = false;

  /// Hareketin başladığı kenar — sayfa o kenarın karşısına doğru küçülür.
  SwipeEdge _edge = SwipeEdge.left;

  bool get _enabled => widget.route.isCurrent && widget.route.popGestureEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onSettled);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _setActive(bool v) {
    if (_active == v || !mounted) return;
    setState(() => _active = v);
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !_enabled) return false;
    _edge = backEvent.swipeEdge;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    _setActive(true);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) {
    widget.route
        .handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);
  }

  @override
  void handleCancelBackGesture() {
    widget.route.handleCancelBackGesture();
    // Sayfa yerine dönerken ölçek de birlikte açılsın; dönüş bitince düz.
    if (widget.animation.isCompleted) {
      _setActive(false);
    } else {
      widget.animation.addStatusListener(_onSettled);
    }
  }

  void _onSettled(AnimationStatus status) {
    if (!status.isCompleted) return;
    widget.animation.removeStatusListener(_onSettled);
    _setActive(false);
  }

  @override
  void handleCommitBackGesture() {
    // `_active` kalır: sayfa küçülmüş hâlinden kapanır.
    widget.route.handleCommitBackGesture();
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) return widget.child;
    // Soldan çekince sayfa ekranın SAĞ kenarına yaslanarak küçülür (ve
    // tersi). Kenar fizikseldir; yönlü hizada sağ = soldan sağa dilde "end",
    // sağdan sola dilde "start" — bu yüzden dil yönüyle XOR.
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final alignment = (_edge == SwipeEdge.left) != rtl
        ? AlignmentDirectional.centerEnd
        : AlignmentDirectional.centerStart;
    return AnimatedBuilder(
      animation: widget.animation,
      builder: (context, child) => Transform.scale(
        scale: _minScale + (1 - _minScale) * widget.animation.value,
        alignment: alignment,
        child: child,
      ),
      child: widget.child,
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
  // Faz 40 / 2: eğri Motion tokenından; sağdan sola dilde (Arapça) yön
  // aynalanır — yeni sayfa SOLDAN girer (okuma yönünde "ileri").
  static final _enterLtr = Tween<Offset>(
    begin: const Offset(0.14, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Motion.enter));
  static final _enterRtl = Tween<Offset>(
    begin: const Offset(-0.14, 0),
    end: Offset.zero,
  ).chain(CurveTween(curve: Motion.enter));

  /// Alttaki sayfanın paralaksı — derinlik hissini veren şey bu. Küçük
  /// tutuluyor: geri dönerken sayfanın uzaktan gelmesi yavaş görünürdü.
  static final _exitLtr = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(-0.05, 0),
  ).chain(CurveTween(curve: Motion.enter));
  static final _exitRtl = Tween<Offset>(
    begin: Offset.zero,
    end: const Offset(0.05, 0),
  ).chain(CurveTween(curve: Motion.enter));

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    return SlideTransition(
      position: secondaryAnimation.drive(rtl ? _exitRtl : _exitLtr),
      // `transformHitTests: false`: çıkan sayfa kaydırılmış hâldeyken
      // dokunuşları yakalamasın (geçiş sırasında yanlış öğeye basılması).
      transformHitTests: false,
      child: SlideTransition(
        position: animation.drive(rtl ? _enterRtl : _enterLtr),
        child: child,
      ),
    );
  }
}

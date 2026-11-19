import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// "Hareket açık mı?" — animasyonları kaldır ayarında dönme/çekim yok.
bool _motionOf(BuildContext context) => !Motion.reduced(context);

/// **Sürüklerken çöp kutusu** — "not" uygulamasının `drag_trash_target.dart`
/// dosyasından uyarlandı (2026-11-15, kullanıcı: *"kartların üzerine basılı
/// tutarak yer değiştirme, silme; silmek için altta çöp simgesi çıksın,
/// notlar uygulamasındaki gibi"*). Ana ekranda bir kutu sürüklenirken ekranın
/// altında beliren bırakma hedefi; bırakılan kutu ana ekrandan KALKAR
/// (dosyalar silinmez, "Ana ekranı düzenle"den ya da Geri al ile döner).
///
/// "not"taki gerekçeler (F60.S9/S12) aynen geçerli:
///
/// F60.S12 (kullanıcı: "ne zaman atılacağı anlaşılmıyor … kara delik gibi
/// çekilsin, çöp kutusu yavaşça kırmızıya dönsün"): BEKLEME YOK — hedef
/// bölgesine girip bırakmak yeter (yanlış silmeye karşı geri al çubuğu var).
/// Parmak yaklaştıkça hedef kırmızılaşır ve sürüklenen kart
/// ([TrashPullFeedback]) küçülüp hedefe doğru çekilir; bırakınca kart
/// dönerek içeri çekilir (≈ 350 ms) ve not olağan yoldan [onTrash]'e gider.
///
/// AKICILIK (kasma listesi 4 ve 6): hedef HER ZAMAN ağaçtadır; görünme,
/// büyüme, renk ve çekilme yalnız BOYAMA düzeyinde (kaydırma/solma/ölçek
/// dönüşümü, [CustomPaint]) — ızgara yeniden dizilmez, ana ekran yeniden
/// kurulmaz.
class DragTrashTarget extends StatefulWidget {
  const DragTrashTarget({
    super.key,
    required this.active,
    required this.onTrash,
  });

  /// Bir kart sürükleniyor mu? Hedef buna göre kayarak belirir/kaybolur.
  final bool active;

  /// Hedefe bırakılan kutunun kimliği.
  final void Function(String id) onTrash;

  /// Parmaktan hedef merkezine vektör (küresel, dp); sürükleme yoksa null.
  /// Sürüklenen kartın görseli overlay'de, ana ekranın DIŞINDA kurulur —
  /// ona ulaşmanın en kısa yolu tek bir paylaşılan değer.
  // ponytail: tek hedef varsayımı; ikinci bir çöp hedefi gelirse örneğe taşı.
  static final ValueNotifier<Offset?> pull = ValueNotifier(null);

  /// Çekimin başladığı uzaklık (dp).
  static const pullRadius = 260.0;

  /// [pull] → 0 (uzak) … 1 (merkezde).
  static double pullOf(Offset? v) {
    if (v == null) return 0;
    const inner = 36.0;
    return (1 - (v.distance - inner) / (pullRadius - inner)).clamp(0.0, 1.0);
  }

  @override
  State<DragTrashTarget> createState() => _DragTrashTargetState();
}

class _DragTrashTargetState extends State<DragTrashTarget>
    with TickerProviderStateMixin {
  late final AnimationController _show = AnimationController(
    vsync: this,
    duration: Motion.medium,
    value: widget.active ? 1 : 0,
  );

  /// Kart hedef bölgesinde (bırakılırsa çöpe gider).
  late final AnimationController _hover = AnimationController(
    vsync: this,
    duration: Motion.short,
  );

  // Bir kez kurulur (her build'de yeni CurvedAnimation dinleyici bırakır).
  late final Animation<double> _curved = CurvedAnimation(
    parent: _show,
    curve: Curves.easeOutCubic,
  );

  /// Bırakınca kara delik: kart dönerek merkeze çekilir.
  late final AnimationController _gulp = AnimationController(
    vsync: this,
    duration: Motion.long,
  );

  /// Bölgede mi? Yalnız simge ve etiket bunu dinler.
  final ValueNotifier<bool> _armed = ValueNotifier(false);

  final GlobalKey _ringKey = GlobalKey();
  bool _routed = false;

  @override
  void initState() {
    super.initState();
    if (widget.active) _listen(true);
  }

  /// Sürükleme boyunca parmağı izle (kart hücresi yeniden kurulsa bile
  /// küresel yol kesilmez).
  void _listen(bool on) {
    if (on == _routed) return;
    _routed = on;
    final router = GestureBinding.instance.pointerRouter;
    if (on) {
      router.addGlobalRoute(_onPointer);
    } else {
      router.removeGlobalRoute(_onPointer);
      DragTrashTarget.pull.value = null;
    }
  }

  void _onPointer(PointerEvent event) {
    if (event is! PointerMoveEvent) return;
    final box = _ringKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    DragTrashTarget.pull.value = center - event.position;
  }

  @override
  void didUpdateWidget(DragTrashTarget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active == oldWidget.active) return;
    _listen(widget.active);
    if (widget.active) {
      _setArmed(false);
      _show.forward();
    } else if (!_gulp.isAnimating) {
      _setArmed(false);
      _show.reverse();
    }
  }

  void _setArmed(bool armed) {
    if (_armed.value == armed) return;
    _armed.value = armed;
    armed ? _hover.forward() : _hover.reverse();
  }

  @override
  void dispose() {
    _listen(false);
    (_curved as CurvedAnimation).dispose();
    _show.dispose();
    _hover.dispose();
    _gulp.dispose();
    _armed.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Büyüme: bölgedeyken 1,12; yutarken kısa bir nabız.
    final scale = Listenable.merge([_hover, _gulp]);
    return IgnorePointer(
      ignoring: !widget.active,
      child: SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.8),
          end: Offset.zero,
        ).animate(_curved),
        child: FadeTransition(
          opacity: _curved,
          child: DragTarget<String>(
            onWillAcceptWithDetails: (_) {
              if (!widget.active) return false;
              if (!_armed.value) AppHaptics.selection();
              _setArmed(true);
              return true;
            },
            onLeave: (_) => _setArmed(false),
            onAcceptWithDetails: (details) {
              _setArmed(false);
              _listen(false);
              _gulp.forward(from: 0).whenCompleteOrCancel(() {
                if (mounted && !widget.active) _show.reverse();
              });
              AppHaptics.destructive();
              widget.onTrash(details.data);
            },
            // Geniş bölge: hedefin çevresine bırakmak da sayılır.
            builder: (context, candidate, rejected) => Padding(
              padding: const EdgeInsets.fromLTRB(40, 28, 40, 8),
              child: Semantics(
                label: context.t('home.drag_trash'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedBuilder(
                      animation: scale,
                      builder: (context, child) {
                        final g = _gulp.value;
                        final pulse = g == 0
                            ? 1.0
                            : 1 + 0.12 * math.sin(g * math.pi);
                        return Transform.scale(
                          scale: (1 + 0.12 * _hover.value) * pulse,
                          child: child,
                        );
                      },
                      child: SizedBox.square(
                        key: _ringKey,
                        dimension: 68,
                        child: CustomPaint(
                          painter: _TrashRingPainter(
                            pull: DragTrashTarget.pull,
                            hover: _hover,
                            gulp: _gulp,
                            base: scheme.surfaceContainerHighest,
                            ring: scheme.error,
                            armedBase: scheme.errorContainer,
                            shadow: scheme.shadow,
                            card: scheme.surfaceContainerHigh,
                            motion: _motionOf(context),
                          ),
                          child: Center(
                            child: ValueListenableBuilder<bool>(
                              valueListenable: _armed,
                              builder: (context, armed, _) => Icon(
                                armed
                                    ? AppIcons.deleteForever
                                    : AppIcons.delete,
                                size: 30,
                                color: armed
                                    ? scheme.onErrorContainer
                                    : scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: scheme.surfaceContainerHighest.withValues(
                          alpha: 0.92,
                        ),
                        borderRadius: BorderRadius.circular(Radii.card),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        child: ValueListenableBuilder<bool>(
                          valueListenable: _armed,
                          builder: (context, armed, _) => Text(
                            context.t(armed ? 'home.drag_trash_ready' : 'home.drag_trash'),
                            style: Theme.of(context).textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Sürüklenen kartın görseli: çöpe yaklaştıkça küçülür, hafif döner ve
/// hedefe doğru çekilir (F60.S12). Ağaç şekli hep aynı; yalnız dönüşüm.
class TrashPullFeedback extends StatelessWidget {
  const TrashPullFeedback({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final motion = _motionOf(context);
    return ValueListenableBuilder<Offset?>(
      valueListenable: DragTrashTarget.pull,
      child: child,
      builder: (context, v, child) {
        final t = DragTrashTarget.pullOf(v);
        // Yaklaştıkça hızlanan çekim (kara delik): t² ile.
        final k = t * t;
        return Transform.translate(
          offset: v == null || !motion ? Offset.zero : v * 0.45 * k,
          child: Transform.rotate(
            angle: motion ? -0.35 * k : 0,
            child: Transform.scale(
              scale: 1 - 0.65 * t,
              child: Opacity(opacity: 1 - 0.35 * k, child: child),
            ),
          ),
        );
      },
    );
  }
}

/// Hedef dairesi, yaklaşınca kızaran halka ve yutma. YALNIZ boyar.
class _TrashRingPainter extends CustomPainter {
  _TrashRingPainter({
    required this.pull,
    required this.hover,
    required this.gulp,
    required this.base,
    required this.ring,
    required this.armedBase,
    required this.shadow,
    required this.card,
    required this.motion,
  }) : super(repaint: Listenable.merge([pull, hover, gulp]));

  final ValueNotifier<Offset?> pull;
  final Animation<double> hover;
  final Animation<double> gulp;
  final Color base;
  final Color ring;
  final Color armedBase;
  final Color shadow;
  final Color card;
  final bool motion;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    // Kızarma: uzaktan yavaşça, bölgede tam.
    final heat = math.max(DragTrashTarget.pullOf(pull.value), hover.value);
    canvas.drawCircle(
      c + const Offset(0, 3),
      r - 2,
      Paint()
        ..color = shadow.withValues(alpha: 0.18 + 0.12 * heat)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r - 2,
      Paint()..color = Color.lerp(base, armedBase, heat)!,
    );
    if (heat > 0) {
      canvas.drawCircle(
        c,
        r - 4,
        Paint()
          ..color = ring.withValues(alpha: heat)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 + 2 * hover.value,
      );
    }
    // Kara delik: küçük bir kâğıt dönerek merkeze çekilip kaybolur.
    final g = gulp.value;
    if (g <= 0 || g >= 1) return;
    final e = Curves.easeInCubic.transform(g);
    final spin = motion ? 3 * math.pi * e : 0.0;
    final orbit = motion ? r * 0.9 * (1 - e) : 0.0;
    final at = c + Offset(math.cos(spin), math.sin(spin)) * orbit;
    canvas.save();
    canvas.translate(at.dx, at.dy);
    canvas.rotate(spin);
    final s = 1 - e;
    final rect = Rect.fromCenter(
      center: Offset.zero,
      width: 30 * s,
      height: 38 * s,
    );
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(6 * s));
    canvas.drawRRect(rr, Paint()..color = card.withValues(alpha: 1 - g * 0.5));
    canvas.drawRRect(
      rr,
      Paint()
        ..color = ring.withValues(alpha: 0.6 * (1 - g))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_TrashRingPainter old) =>
      old.pull != pull ||
      old.hover != hover ||
      old.gulp != gulp ||
      old.base != base ||
      old.ring != ring ||
      old.armedBase != armedBase ||
      old.shadow != shadow ||
      old.card != card ||
      old.motion != motion;
}

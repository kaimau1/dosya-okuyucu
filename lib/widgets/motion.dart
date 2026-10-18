import 'dart:async';

import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../core/safe_insets.dart';

/// **Ortak hareket parçaları** — kullanıcı isteği 2026-10-17 (Notlar ile
/// aynı tur): *"UI/UX çalışmaları; iPhone gibi akıcılık, premium his"*.
///
/// Üçü de yalnız DÖNÜŞÜM ve tek bir saydamlık kullanır: liste/ızgara
/// yeniden yerleşmez, `saveLayer` yalnız kısa giriş anında ve tek katmanda
/// olur (2026-09-06 geçiş performansı kararıyla aynı kural — bkz.
/// `core/page_transitions.dart`).

/// **Basınca hafifçe çöken kutu** (iOS'taki dokunsal his).
///
/// Parmak inince kutu biraz küçülür, kalkınca yaylı bir eğriyle yerine
/// oturur. [Listener] ile dinler — jest yarışmasına GİRMEZ: dokunma, uzun
/// basış, sürükleyerek seçme ([DragSelectArea]) aynen çalışır.
///
/// Kaydırırken titremesin diye küçülme kısa bir gecikmeyle başlar ve parmak
/// birkaç pikselden fazla kayarsa (liste kaydırılıyor) iptal olur.
class PressScale extends StatefulWidget {
  final Widget child;

  /// Basılıyken ölçek (1 = değişmez).
  final double scale;
  final bool enabled;

  const PressScale({
    super.key,
    required this.child,
    this.scale = 0.95,
    this.enabled = true,
  });

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  static const _delay = Duration(milliseconds: 70);
  static const _slop = 10.0;

  bool _pressed = false;
  Timer? _timer;
  Offset? _down;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _set(bool value) {
    if (_pressed == value || !mounted) return;
    setState(() => _pressed = value);
  }

  void _onDown(PointerDownEvent e) {
    if (!widget.enabled) return;
    _down = e.position;
    _timer?.cancel();
    _timer = Timer(_delay, () => _set(true));
  }

  void _onMove(PointerMoveEvent e) {
    final down = _down;
    if (down == null) return;
    if ((e.position - down).distance > _slop) _release();
  }

  void _release() {
    _down = null;
    _timer?.cancel();
    _timer = null;
    _set(false);
  }

  /// Gecikme dolmadan kalkan parmakta da (hızlı dokunuş) his kaybolmasın:
  /// kutu bir an çöküp geri gelir.
  void _onUp(PointerUpEvent e) {
    final quickTap = _timer?.isActive ?? false;
    _release();
    if (!quickTap || !widget.enabled) return;
    _set(true);
    _timer = Timer(const Duration(milliseconds: 90), () => _set(false));
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: _onDown,
        onPointerMove: _onMove,
        onPointerUp: _onUp,
        onPointerCancel: (e) => _release(),
        child: AnimatedScale(
          scale: _pressed ? widget.scale : 1,
          duration: _pressed
              ? const Duration(milliseconds: 110)
              : const Duration(milliseconds: 260),
          curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
          child: widget.child,
        ),
      );
}

/// **Yumuşak giriş** — yeni beliren parça hafifçe büyüyüp yukarı süzülerek
/// gelir. İlk kurulumda bir kez oynar; [animate] false ise doğrudan çizilir.
class PopIn extends StatelessWidget {
  final Widget child;
  final Duration duration;
  final double from;
  final double rise;
  final bool animate;

  const PopIn({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 240),
    this.from = 0.96,
    this.rise = 8,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!animate || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) {
      return child;
    }
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: duration,
      curve: Curves.easeOutCubic,
      child: child,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * rise),
          child: Transform.scale(
            scale: from + (1 - from) * t,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// **Liste iskeleti** — dosya/klasör listesi yüklenirken ortada dönen tek
/// bir çark yerine satırların yerini tutan, yumuşakça nabız atan kutular.
/// Liste gelince satırlar AYNI yerlerde belirir; ekran boş ⇄ dolu arasında
/// zıplamaz. Tek denetleyici bütün iskeletin saydamlığını oynatır.
class FmListSkeleton extends StatefulWidget {
  /// Satır sayısı (ekranı doldurmaya yeter).
  final int rows;

  const FmListSkeleton({super.key, this.rows = 9});

  @override
  State<FmListSkeleton> createState() => _FmListSkeletonState();
}

class _FmListSkeletonState extends State<FmListSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  late final Animation<double> _opacity = Tween<double>(
    begin: 0.45,
    end: 0.9,
  ).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut));

  // Satır başlıklarının genişlik oranları (sabit desen — titremez).
  static const _widths = [0.62, 0.48, 0.71, 0.55, 0.66, 0.42, 0.58, 0.69];

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final block = scheme.onSurface.withValues(alpha: 0.08);
    Widget bar(double widthFactor, double height) => FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widthFactor,
          child: Container(
            height: height,
            decoration: BoxDecoration(
              color: block,
              borderRadius: BorderRadius.circular(height / 2),
            ),
          ),
        );
    return Semantics(
      label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
      child: ClipRect(
        child: FadeTransition(
          opacity: _opacity,
          child: ListView.builder(
            physics: const NeverScrollableScrollPhysics(),
            padding: withNavInset(
                context, const EdgeInsets.symmetric(vertical: Gap.sm)),
            itemCount: widget.rows,
            itemBuilder: (context, i) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Gap.md,
                vertical: 10,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: block,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  const SizedBox(width: Gap.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        bar(_widths[i % _widths.length], 12),
                        const SizedBox(height: 8),
                        bar(_widths[(i + 3) % _widths.length] * 0.6, 9),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **Boş liste yüzü** — ortada tek satır soluk yazı yerine renkli bir simge
/// dairesi, başlık ve (varsa) ne yapılacağını söyleyen ipucu; süzülerek
/// belirir. "Çöp kutusu boş", "Kopya yok" gibi durumlar bir hata değil bir
/// SONUÇ — ekran bunu boş bir sayfa gibi değil, bitmiş bir iş gibi söylemeli.
class FmEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final Widget? action;

  const FmEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Center(
      child: SingleChildScrollView(
        padding: withNavInset(context, const EdgeInsets.all(Gap.lg)),
        child: PopIn(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 36, color: scheme.primary),
              ),
              const SizedBox(height: Gap.md),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium,
              ),
              if (hint != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  hint!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
              if (action != null) ...[
                const SizedBox(height: Gap.md),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

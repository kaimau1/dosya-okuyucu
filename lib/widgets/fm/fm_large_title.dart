import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../core/motion.dart';
import '../../core/theme.dart';

/// **Büyük başlık** — Ferrari H4.2 (2026-11-14, Samsung Dosyalarım
/// karşılaştırması: "Belgeler / 8,90 GB" listenin üstünde iri yazı).
///
/// Liste en üstteyken başlık ve özet ("161 öğe · 220 MB") iri yazıyla
/// süzgeç satırının ÜSTÜNDE durur; liste aşağı kaydırılınca katlanır ve
/// aynı yazı üst çubuğa küçülür ([FmCollapsedTitle]). En üste dönülünce
/// yeniden açılır.
///
/// *Niye kaydırma payıyla sürekli değil, eşikle:* başlık listenin DIŞINDA
/// (süzgeç satırının üstünde) — her pikselde boyu değişseydi listenin
/// görünür alanı da değişir, içerik iki kat hızla kayardı. Eşik + kısa
/// animasyon tek seferlik bir geçiş verir. Kısa listede (birkaç ekran
/// boyu yoksa) hiç katlanmaz: görünür alan büyüyünce kaydırma payı
/// kısalır ve başlık açılıp kapanarak titrerdi.
class FmTitleCollapse extends ValueNotifier<bool> {
  final ScrollController controller;

  /// Bu kadar kaydırılınca katlanır.
  static const collapseAt = 48.0;

  /// Liste en az bu kadar kaydırılabiliyorsa katlanır (titreme önlemi).
  static const minScrollRoom = 240.0;

  FmTitleCollapse(this.controller) : super(false) {
    controller.addListener(_check);
  }

  bool _disposed = false;
  bool _pending = false;

  void _check() {
    if (_disposed || controller.positions.length != 1) return;
    final pos = controller.position;
    if (!pos.hasPixels || !pos.hasContentDimensions) return;
    final bool want;
    if (!value &&
        pos.pixels > collapseAt &&
        pos.maxScrollExtent > minScrollRoom) {
      want = true;
    } else if (value && pos.pixels <= 1) {
      want = false;
    } else {
      return;
    }
    // Kaydırma konumu çizim (yerleşim) sırasında da değişebilir; o anda
    // dinleyicileri yeniden kurmak hata verir → kare sonuna ertelenir.
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks ||
        phase == SchedulerPhase.midFrameMicrotasks) {
      if (_pending) return;
      _pending = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _pending = false;
        _check();
      });
      return;
    }
    value = want;
  }

  @override
  void dispose() {
    _disposed = true;
    controller.removeListener(_check);
    super.dispose();
  }
}

/// İri başlık + özet; [collapsed] açıkken katlanır.
class FmLargeTitle extends StatelessWidget {
  final ValueListenable<bool> collapsed;
  final String title;
  final String? summary;

  const FmLargeTitle({
    super.key,
    required this.collapsed,
    required this.title,
    this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Motion.of(context, Motion.medium);
    return ValueListenableBuilder<bool>(
      valueListenable: collapsed,
      builder: (context, folded, _) => AnimatedSize(
        duration: duration,
        curve: Motion.standard,
        alignment: AlignmentDirectional.topStart,
        child: AnimatedSwitcher(
          duration: duration,
          child: folded
              ? const SizedBox(
                  key: ValueKey('fm-large-title-folded'), width: double.infinity)
              : Semantics(
                  key: const ValueKey('fm-large-title'),
                  header: true,
                  headingLevel: 1,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                        Gap.md, Gap.xs, Gap.md, Gap.sm),
                    child: SizedBox(
                      width: double.infinity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          if (summary != null && summary!.isNotEmpty)
                            Text(
                              summary!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontFeatures: const [
                                  FontFeature.tabularFigures()
                                ],
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

/// Üst çubuktaki küçük başlık: yalnız [collapsed] açıkken görünür (büyük
/// başlık ekrandayken aynı yazı iki kez durmasın — TalkBack da iki kez
/// okumasın).
class FmCollapsedTitle extends StatelessWidget {
  final ValueListenable<bool> collapsed;
  final Widget child;

  const FmCollapsedTitle(
      {super.key, required this.collapsed, required this.child});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: collapsed,
        builder: (context, folded, _) => AnimatedSwitcher(
          duration: Motion.of(context, Motion.short),
          child: folded
              ? KeyedSubtree(key: const ValueKey('fm-small-title'), child: child)
              : const SizedBox.shrink(key: ValueKey('fm-small-title-off')),
        ),
      );
}

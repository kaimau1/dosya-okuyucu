/// Belge ekranlarının altındaki **etiketli eylem çubuğu**.
///
/// 2026-07-27'de yalnız PDF'e eklenmişti (kullanıcı bulgusu: WhatsApp'tan gelen
/// dosya *"açılıyor ama ne yapacağım belli değil"* — üst çubuktaki ikonların
/// tooltip'i telefonda hiç görünmüyor). 2026-07-28'de kullanıcı aynısını Word,
/// txt, Excel ve slaytta da istedi; dört ekranda görünüm ayrışmasın diye çubuk
/// tek yerde duruyor.
///
/// Sığmazsa yatay kaydırılır — küçük ekranda düğme kırpılmasın.
library;

import 'package:flutter/material.dart';

import '../core/motion.dart';

/// Çubuktaki tek düğme. [onTap] null ise düğme sönük görünür (işlem şu an
/// yapılamıyor demektir — gizlemek yerine sönük bırakmak yeri sabit tutar).
///
/// [active] bir KİP düğmesi için (ör. Word'de "Mobil akış" açık): simgenin
/// hap zemini vurgu rengine döner.
/// [primary] ana eylem (ör. okuyucuda "Düzenle"): dolgulu vurgu kapsülüyle
/// hemen göze çarpar.
class DocAction {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool primary;

  const DocAction(
    this.icon,
    this.label,
    this.onTap, {
    this.active = false,
    this.primary = false,
  });
}

/// **Belge Stüdyosu Dock'u** (2026-11-24 yenilemesi): simge üstte yumuşak
/// dokunulabilir hap içinde, etiket altta net hiyerarşiyle.
///
/// * Sığıyorsa düğmeler genişliği EŞİT paylaşır.
/// * Sığmıyorsa sabit genişlikte yatay kayar; son düğmenin yarısı görünür
///   kalır — kaydırılabildiği gözle anlaşılır.
/// * [DocAction.primary] ana eylemi (ör. "Düzenle") dolgulu vurgu kapsülüyle
///   öne çıkarır; [DocAction.active] açık kipi vurgulu hapla gösterir.
class DocActionBar extends StatelessWidget {
  final List<DocAction> actions;

  /// **Bağlama duyarlı grup** (Faz 40 / 1): seçime özgü eylemler (aralık
  /// seçiliyken Kopyala/Kes/Yapıştır …). Boş değilse şeridin BAŞINA, hafif
  /// vurgulu bir hap içinde gelir ve şerit kaydırmalı düzene geçer — kalıcı
  /// eylemler yerinde kalır, yalnız sağa kayar.
  final List<DocAction> contextual;

  /// Bağlam grubunun TalkBack etiketi ("Seçim").
  final String? contextLabel;

  const DocActionBar(this.actions,
      {super.key, this.contextual = const [], this.contextLabel});

  /// Bir düğmenin en az genişliği; altına inilirse kaydırmaya geçilir.
  static const double _minSlot = 58;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final width = box.maxWidth.isFinite
          ? box.maxWidth
          : MediaQuery.sizeOf(context).width;
      if (contextual.isNotEmpty) return _withContext(context, width);
      final n = actions.isEmpty ? 1 : actions.length;
      final compact = n >= 6;
      final fits = width / n >= _minSlot;
      if (fits) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            children: [
              for (final a in actions)
                Expanded(child: _DockButton(a, compact: compact)),
            ],
          ),
        );
      }
      // Kaydırmalı düzen: görünen düğme sayısı x.5 olacak şekilde genişlik.
      final visible = ((width - 12) / 76).floor().clamp(3, 12);
      final slot = (width - 12) / (visible + 0.5);
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        child: Row(
          children: [
            for (final a in actions)
              SizedBox(width: slot, child: _DockButton(a, compact: compact)),
          ],
        ),
      );
    });
  }
}

extension on DocActionBar {
  /// Bağlam grubu + kalıcı eylemler, tek kaydırmalı satır.
  Widget _withContext(BuildContext context, double width) {
    final scheme = Theme.of(context).colorScheme;
    final visible = ((width - 12) / 76).floor().clamp(3, 12);
    final slot = (width - 12) / (visible + 0.5);
    return SingleChildScrollView(
      key: const ValueKey('doc-bar-context'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      child: Row(
        children: [
          Semantics(
            container: true,
            label: contextLabel,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.52),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.24),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final a in contextual)
                      SizedBox(width: slot, child: _DockButton(a)),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: 40,
            child: VerticalDivider(
              width: 12,
              color: scheme.outlineVariant.withValues(alpha: 0.8),
            ),
          ),
          for (final a in actions) SizedBox(width: slot, child: _DockButton(a)),
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  final DocAction action;
  final bool compact;
  const _DockButton(this.action, {this.compact = false});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = action.onTap != null;
    final isPrimary = enabled && action.primary && !action.active;
    final isActive = enabled && action.active;
    final iconColor = !enabled
        ? scheme.onSurface.withValues(alpha: 0.36)
        : isPrimary
            ? scheme.onPrimary
            : isActive
                ? scheme.onPrimaryContainer
                : scheme.onSurface;
    final labelColor = !enabled
        ? scheme.onSurface.withValues(alpha: 0.36)
        : (isPrimary || isActive)
            ? scheme.primary
            : scheme.onSurfaceVariant;
    final pillBg = !enabled
        ? Colors.transparent
        : isPrimary
            ? scheme.primary
            : isActive
                ? scheme.primaryContainer
                : scheme.surfaceContainerHigh.withValues(alpha: 0.65);
    final pillBorder = !enabled
        ? null
        : isPrimary
            ? Border.all(color: scheme.primary)
            : isActive
                ? Border.all(color: scheme.primary.withValues(alpha: 0.38))
                : Border.all(
                    color: scheme.outlineVariant.withValues(alpha: 0.45));
    return Semantics(
      button: true,
      enabled: enabled,
      label: action.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding:
              EdgeInsets.symmetric(horizontal: compact ? 1 : 2, vertical: 3),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Motion.of(context, Motion.short),
                curve: Motion.standard,
                width: compact ? 44 : 50,
                height: compact ? 30 : 32,
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(15),
                  border: pillBorder,
                ),
                child: Icon(
                  action.icon,
                  size: compact ? 19 : 20,
                  color: iconColor,
                ),
              ),
              const SizedBox(height: 4),
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 26),
                child: Text(
                  action.label,
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    height: 1.15,
                    letterSpacing: 0,
                    fontWeight: (isActive || isPrimary)
                        ? FontWeight.w700
                        : FontWeight.w600,
                    color: labelColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

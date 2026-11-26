import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/motion.dart';
import '../../core/theme.dart';

/// **Ortak filtre levhası iskeleti** (2026-11-23 yenilemesi).
///
/// Tüm sayfalardaki filtreleme/sıralama levhaları ("Filtrele ve sırala",
/// "Tür", "Kaynak ve zaman", "Analiz ve diğer", Önemli Dosyalar filtreleri)
/// aynı mimariyi paylaşır:
/// - **Sabit üst başlık:** kalın başlık + etkin ölçüt sayısı rozeti + isteğe
///   bağlı sağ eylem (ör. Temizle);
/// - **Kaydırılabilir gövde:** kartlara bölünmüş net filtre grupları;
/// - **Sabit alt işlem çubuğu:** "Uygula" / "N dosyayı göster" düğmeleri uzun
///   listelerde bile her zaman başparmağın altında kalır.
class FmFilterSheetScaffold extends StatelessWidget {
  final String title;
  final String? hint;
  final int activeCount;
  final Widget? trailing;
  final Widget body;
  final Widget footer;

  const FmFilterSheetScaffold({
    super.key,
    required this.title,
    this.hint,
    this.activeCount = 0,
    this.trailing,
    required this.body,
    required this.footer,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final maxH = MediaQuery.sizeOf(context).height * 0.86;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxH),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(
              Gap.md,
              0,
              Gap.sm + 4,
              Gap.sm + 2,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                        ),
                      ),
                    ),
                    if (activeCount > 0) ...[
                      const SizedBox(width: Gap.sm),
                      Container(
                        padding: const EdgeInsetsDirectional.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          '$activeCount',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: scheme.onPrimary,
                            fontWeight: FontWeight.w700,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    ?trailing,
                  ],
                ),
                if (hint != null && hint!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      hint!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 0.5,
            thickness: 0.5,
            color: scheme.outlineVariant.withValues(alpha: 0.8),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.md,
                Gap.sm + 4,
                Gap.md,
                Gap.md,
              ),
              child: body,
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border(
                top: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.8),
                  width: 0.5,
                ),
              ),
            ),
            child: Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                Gap.md,
                Gap.sm + 2,
                Gap.md,
                Gap.sm + 4,
              ),
              child: footer,
            ),
          ),
        ],
      ),
    );
  }
}

/// Filtre grubunu tek bir sakin kart içinde toplayan bölüm kabı.
///
/// Başlıkta konuya özel simge + kalın ad + isteğe bağlı sağ özet rozeti;
/// [onToggle] verilirse katlanabilir bölüm olur (ör. Akıllı kategori).
class FmFilterSectionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color? iconColor;
  final String? badgeText;
  final bool badgeActive;
  final bool expanded;
  final VoidCallback? onToggle;
  final Key? toggleKey;
  final Widget child;

  const FmFilterSectionCard({
    super.key,
    required this.icon,
    required this.title,
    this.iconColor,
    this.badgeText,
    this.badgeActive = false,
    this.expanded = true,
    this.onToggle,
    this.toggleKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final skin = AppSkinData.of(context);
    final pal = skin.palette;
    final tint = iconColor ?? pal.accent;
    final radius = BorderRadius.circular(
      (skin.metrics.radiusCard + 2).clamp(12, 20).toDouble(),
    );

    final header = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        14,
        12,
        onToggle != null ? 10 : 14,
        expanded ? 10 : 12,
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: tint),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
          ),
          if (badgeText != null && badgeText!.isNotEmpty) ...[
            const SizedBox(width: Gap.xs),
            Container(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: badgeActive ? scheme.primaryContainer : pal.well,
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                badgeText!,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: badgeActive
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ],
          if (onToggle != null) ...[
            const SizedBox(width: 4),
            Icon(
              expanded ? AppIcons.expandLess : AppIcons.expandMore,
              size: 20,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: radius,
        border: Border.all(color: pal.rule, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onToggle != null)
            Semantics(
              button: true,
              expanded: expanded,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  key: toggleKey,
                  onTap: onToggle,
                  child: header,
                ),
              ),
            )
          else
            header,
          if (expanded)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 0, 14, 14),
              child: child,
            ),
        ],
      ),
    );
  }
}

/// Filtre levhalarının ortak **seçim hapı**.
///
/// - [filledSelected] `true` iken seçili durum dolu vurgu rengiyle öne çıkar
///   (sıralama, tarih, boyut gibi metin odaklı ölçütler).
/// - [filledSelected] `false` iken kategori/kaynak/etiket rengi yumuşak
///   dolgu + net kenarlıkla korunur.
/// - [count] verildiğinde sayı her zaman son `Text` düğümü olarak kapsül
///   içinde çizilir (test ve ekran okuyucu uyumu).
class FmFilterOptionChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final Color? dotColor;
  final Color? accentColor;
  final int? count;
  final bool filledSelected;
  final bool expand;

  const FmFilterOptionChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.dotColor,
    this.accentColor,
    this.count,
    this.filledSelected = false,
    this.expand = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pal = AppSkinData.of(context).palette;
    final isDark = theme.brightness == Brightness.dark;
    final empty = count == 0 && !selected;
    final tint = accentColor ?? scheme.primary;
    final effectiveTint = empty ? tint.withValues(alpha: 0.45) : tint;
    final radius = BorderRadius.circular(10);

    final Color bg;
    final Color border;
    final Color fg;
    final double borderWidth;

    if (selected && filledSelected) {
      bg = scheme.primary;
      border = scheme.primary;
      fg = scheme.onPrimary;
      borderWidth = 1.2;
    } else if (selected) {
      bg = tint.withValues(alpha: isDark ? 0.24 : 0.13);
      border = tint;
      fg = isDark
          ? Color.lerp(tint, AppColors.mixLight, 0.55)!
          : Color.lerp(tint, AppColors.mixDark, 0.32)!;
      borderWidth = 1.5;
    } else {
      bg = scheme.surface;
      border = pal.rule;
      fg = empty ? scheme.onSurfaceVariant.withValues(alpha: 0.72) : pal.ink;
      borderWidth = 1;
    }

    final Widget? leading;
    if (dotColor != null) {
      leading = Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: selected && filledSelected ? scheme.onPrimary : dotColor,
          shape: BoxShape.circle,
        ),
      );
    } else if (icon != null) {
      leading = Icon(
        selected && !filledSelected && accentColor == null
            ? AppIcons.checkCircle
            : icon,
        size: 16,
        color: selected && filledSelected ? scheme.onPrimary : effectiveTint,
      );
    } else if (selected) {
      leading = Icon(
        AppIcons.check,
        size: 15,
        color: filledSelected ? scheme.onPrimary : tint,
      );
    } else {
      leading = null;
    }

    final row = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment:
          expand ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        if (leading != null) ...[
          leading,
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge?.copyWith(
              height: 1.15,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: fg,
            ),
          ),
        ),
        if (selected && !filledSelected && (dotColor != null || accentColor != null)) ...[
          const SizedBox(width: 5),
          Icon(AppIcons.check, size: 14, color: fg),
        ],
        if (count != null) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 6,
              vertical: 1.5,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? (filledSelected
                      ? scheme.onPrimary.withValues(alpha: 0.20)
                      : tint.withValues(alpha: isDark ? 0.30 : 0.16))
                  : pal.well,
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text(
              '$count',
              maxLines: 1,
              style: theme.textTheme.labelSmall?.copyWith(
                color: selected ? fg : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      selected: selected,
      child: AnimatedContainer(
        duration: Motion.of(context, Motion.short),
        curve: Motion.standard,
        constraints: const BoxConstraints(minHeight: 38),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: radius,
          border: Border.all(color: border, width: borderWidth),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                leading != null ? 10 : 12,
                7,
                count != null ? 8 : 12,
                7,
              ),
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}

/// Sıralama yönü seçici: "Azalan ↓ | Artan ↑" modern iki bölmeli anahtar.
class FmSortDirectionToggle extends StatelessWidget {
  final bool descending;
  final String descLabel;
  final String ascLabel;
  final ValueChanged<bool> onChanged;

  const FmSortDirectionToggle({
    super.key,
    required this.descending,
    required this.descLabel,
    required this.ascLabel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final pal = AppSkinData.of(context).palette;
    final short = Motion.of(context, Motion.short);

    Widget seg({
      required bool active,
      required IconData icon,
      required String label,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: Semantics(
          button: true,
          selected: active,
          child: AnimatedContainer(
            duration: short,
            curve: Motion.standard,
            constraints: const BoxConstraints(minHeight: 38),
            decoration: BoxDecoration(
              color: active ? scheme.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                borderRadius: BorderRadius.circular(9),
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 16,
                        color: active
                            ? scheme.onPrimary
                            : scheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w600,
                            color: active
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
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

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.well,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.rule, width: 1),
      ),
      child: Row(
        children: [
          seg(
            active: descending,
            icon: AppIcons.arrowDown,
            label: descLabel,
            onTap: () => onChanged(true),
          ),
          const SizedBox(width: 4),
          seg(
            active: !descending,
            icon: AppIcons.arrowUp,
            label: ascLabel,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// **Ortak menü dili** (2026-10-29, kullanıcı: *"görsel birlik üzerine çalış —
/// bazı menüler farklı görünüyor: dosya içi farklı, ayarlar farklı, klasör
/// menüsü farklı; hepsi görsel birlikte olmalı"*).
///
/// Bugüne dek dört ayrı menü dili vardı: dosya içindeki "Daha fazla" ızgarası
/// ([DocMoreSheet]), uzun basma menüsü (büyük daire düğmeler + çerçeveli
/// hücreler + BÜYÜK HARF başlık), seçimdeki eylem levhası (çıplak liste +
/// mavi başlık) ve klasörün ⋮ açılır menüsü. Hepsi aynı üç parçaya indi:
///
/// * [MenuGroupTitle] — grup başlığı (tek yazı stili, büyük harf yok);
/// * [MenuGroupCard] — grubun kartı (aynı zemin, aynı köşe);
/// * [MenuIconWell] — simge kutusu (aynı boy, aynı köşe; nötr / vurgu /
///   tehlike / kapalı tonları).
///
/// Ekran bu parçaları dizer; renk ve köşe tek yerden gelir.
abstract final class MenuKit {
  /// Grup kartının köşesi.
  static const double cardRadius = 20;

  /// Simge kutusunun köşesi (kutu boyunun ~üçte biri).
  static const double wellRadius = 14;
}

/// Grup başlığı ("Düzenle", "Taşı / kopyala").
class MenuGroupTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  const MenuGroupTitle(
    this.text, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 6),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Grubun kartı: hafif yükseltilmiş zemin, yuvarlak köşe.
class MenuGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MenuGroupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(MenuKit.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Simge kutusunun tonu.
enum MenuTone { neutral, accent, danger, disabled, selected }

/// Simge kutusu — bütün menülerde aynı şekil.
class MenuIconWell extends StatelessWidget {
  final IconData icon;
  final MenuTone tone;
  final double size;

  const MenuIconWell(
    this.icon, {
    super.key,
    this.tone = MenuTone.neutral,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg, bool border) = switch (tone) {
      MenuTone.neutral => (scheme.surface, scheme.onSurface, true),
      MenuTone.accent => (scheme.primaryContainer, scheme.onPrimaryContainer, false),
      MenuTone.danger => (scheme.errorContainer, scheme.error, false),
      MenuTone.selected => (scheme.primary, scheme.onPrimary, false),
      MenuTone.disabled => (
          scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          scheme.onSurface.withValues(alpha: 0.35),
          false
        ),
    };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MenuKit.wellRadius * size / 48),
        border: border ? Border.all(color: scheme.outlineVariant) : null,
      ),
      child: Icon(icon, size: size * 0.48, color: fg),
    );
  }
}

/// Kart içindeki satır: simge kutusu + etiket (+ ipucu).
class MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? hint;
  final MenuTone tone;
  final VoidCallback? onTap;
  final Widget? trailing;

  const MenuRow({
    super.key,
    required this.icon,
    required this.label,
    this.hint,
    this.tone = MenuTone.neutral,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final danger = tone == MenuTone.danger;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            children: [
              MenuIconWell(icon, tone: tone, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: danger ? scheme.error : null,
                      ),
                    ),
                    if (hint != null)
                      Text(
                        hint!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 8), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Izgara hücresi: simge kutusu + altında etiket (hızlı eylemler, "Daha
/// fazla" ızgarası).
class MenuTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final MenuTone tone;
  final VoidCallback? onTap;

  /// Köşede onay işareti (açık/kapalı ayarlar).
  final Widget? badge;

  const MenuTile({
    super.key,
    required this.icon,
    required this.label,
    this.tone = MenuTone.neutral,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final enabled = onTap != null && tone != MenuTone.disabled;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                MenuIconWell(icon, tone: enabled ? tone : MenuTone.disabled, size: 48),
                if (badge != null)
                  PositionedDirectional(end: -4, top: -4, child: badge!),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 2,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                height: 1.2,
                fontWeight: FontWeight.w600,
                color: !enabled
                    ? scheme.onSurface.withValues(alpha: 0.38)
                    : (tone == MenuTone.danger ? scheme.error : scheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

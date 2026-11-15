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

  /// **Türe özel düğmelerin rengi** (2026-11-15, kullanıcı: *"her türe özel
  /// butonlar ayrı bir renkte olsun, menü içinde ortak olanlar zaten kendi
  /// renginde; böylece ayrım kolaylaşır"*).
  ///
  /// Ortak dosya işleri (taşı, kopyala, sil …) vurgu renginde; PDF'in sayfa
  /// işleri, videonun oynatıcı işleri gibi TÜRE ÖZEL olanlar vurgunun renk
  /// çemberinde 120° ötesinde bir tonda — her temada vurgudan ayrışır. Kırmızı
  /// bölgeye düşerse kaydırılır: kırmızı yalnız "Sil"in.
  static double specialHue(ColorScheme scheme) {
    final base = HSLColor.fromColor(scheme.primary).hue;
    var hue = (base + 120) % 360;
    if (hue > 330 || hue < 30) hue = (hue + 60) % 360;
    return hue;
  }

  /// Türe özel simge kutusunun zemini.
  static Color specialWell(ColorScheme scheme) => HSLColor.fromAHSL(
          1,
          specialHue(scheme),
          0.55,
          scheme.brightness == Brightness.dark ? 0.27 : 0.89)
      .toColor();

  /// Türe özel simge ve başlık rengi (zemin üstünde WCAG ≥ 4,5).
  static Color specialInk(ColorScheme scheme) => HSLColor.fromAHSL(
          1,
          specialHue(scheme),
          0.6,
          scheme.brightness == Brightness.dark ? 0.84 : 0.30)
      .toColor();
}

/// Grup başlığı ("Düzenle", "Taşı / kopyala").
class MenuGroupTitle extends StatelessWidget {
  final String text;
  final EdgeInsetsGeometry padding;

  /// Türe özel grup: başlık [MenuKit.specialInk] renginde.
  final bool special;

  const MenuGroupTitle(
    this.text, {
    super.key,
    this.padding = const EdgeInsetsDirectional.fromSTEB(8, 12, 8, 6),
    this.special = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Büyük ve kalın (2026-11-15, kullanıcı: *"başlıklar büyüsün baya ve
    // bold olsun"*) — eskiden soluk, küçük etiket yazısıydı.
    return Padding(
      padding: padding,
      child: Text(
        text,
        style: theme.textTheme.titleMedium
            ?.apply(fontSizeFactor: 1.12)
            .copyWith(
          height: 1.2,
          color: special ? MenuKit.specialInk(scheme) : scheme.onSurface,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
      ),
    );
  }
}

/// Grubun kartı: hafif yükseltilmiş zemin, yuvarlak köşe.
class MenuGroupCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  /// Türe özel grup: kart [MenuKit.specialWell] tonuna çalar.
  final bool special;

  const MenuGroupCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
    this.special = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: special
            ? Color.lerp(scheme.surfaceContainerHigh,
                MenuKit.specialWell(scheme), 0.45)
            : scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(MenuKit.cardRadius),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Simge kutusunun tonu.
///
/// [special]: türe özel işlem (PDF'in sayfa işi, videonun oynatıcı işi …) —
/// ortak dosya işlerinden ayrı renkte, bkz. [MenuKit.specialWell].
enum MenuTone { neutral, accent, danger, disabled, selected, special }

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
      MenuTone.special => (
          MenuKit.specialWell(scheme),
          MenuKit.specialInk(scheme),
          false
        ),
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

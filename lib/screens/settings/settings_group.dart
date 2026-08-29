import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';

/// **Ayar bölümü — tek bir kart.**
///
/// 2026-08-29 yeniden tasarımı. Eski kategori sayfası düz bir listeydi:
/// başlıklar arasında yalnız bir cetvel vardı, satırlar kâğıdın üstünde
/// serbestçe akıyordu ve "nerede bitti, nerede başladı" ancak okuyarak
/// anlaşılıyordu. Modern ayar ekranlarının (ve pahalı görünmenin) tek numarası
/// bu: **ilişkili satırlar tek bir yüzeyde toplanır**, aralarında ince ayraç,
/// grubun adı üstünde küçük ve sakin durur.
///
/// Kart `surfaceContainer`da — kâğıt zeminden bir kademe ayrı ama gölge yok:
/// gölge, üst üste binen yüzeylerin dili; burada tek katman var.
class SettingsGroup extends StatelessWidget {
  /// Grubun üstünde duran küçük başlık. Boşsa başlık çizilmez (tek gruplu
  /// kategoride kategori adı zaten üstte yazıyor).
  final String? title;

  final List<Widget> children;

  /// Başlığın yanında sağda duran serbest bileşen (ör. Gelişmiş oku).
  final Widget? trailing;

  /// Kenar boşluğunu KENDİSİ verir mi? Gelişmiş bölümün içinde boşluk zaten
  /// dışarıdan geliyor; iki kez uygulanırsa kart ortada sıkışık görünür.
  final bool inset;

  const SettingsGroup({
    super.key,
    required this.children,
    this.title,
    this.trailing,
    this.inset = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0)
          : const EdgeInsets.only(top: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(Gap.sm + 4, 0, Gap.sm, Gap.sm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title!.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.primary,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  if (trailing != null) trailing!,
                ],
              ),
            ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(Radii.card + 2),
              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.45)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(Radii.card + 2),
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0)
                      // Ayraç simgenin hizasından başlar: satırın solundaki
                      // simge sütunu görsel olarak kesilmesin.
                      Divider(
                        height: 1,
                        thickness: 1,
                        indent: 56,
                        color: scheme.outlineVariant.withValues(alpha: 0.35),
                      ),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// **Gelişmiş** grubu — kapalı gelir, başlığa dokununca açılır.
///
/// Kullanıcı isteği 2026-08-29: *"bazı şeyleri gelişmiş ayarlar adı altına
/// ekleyebilirsin"*. Amaç saklamak değil **sıralamak**: günde bir kez
/// dokunulan ayarla ömürde bir kez dokunulan ayar aynı ağırlıkta görünürse
/// sayfa kalabalık okunuyor. İçindekiler ARAMADA normal satır gibi çıkar.
class SettingsAdvancedGroup extends StatefulWidget {
  final String title;
  final List<Widget> children;

  const SettingsAdvancedGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  State<SettingsAdvancedGroup> createState() => _SettingsAdvancedGroupState();
}

class _SettingsAdvancedGroupState extends State<SettingsAdvancedGroup>
    with SingleTickerProviderStateMixin {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(Radii.control),
              onTap: () => setState(() => _open = !_open),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: Gap.sm + 4, vertical: Gap.sm),
                child: Row(
                  children: [
                    Icon(Icons.tune, size: 18, color: scheme.primary),
                    const SizedBox(width: Gap.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title.toUpperCase(),
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: scheme.primary,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                            ),
                          ),
                          if (!_open)
                            Text(
                              context.t('set.advanced_hint'),
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Paper.faint(context)),
                            ),
                        ],
                      ),
                    ),
                    // Ok DÖNER (açılıp kapanmayı gösterir); yön değişimi
                    // 150 ms'de, `Transform` üzerinden — yeniden yerleşim yok.
                    AnimatedRotation(
                      turns: _open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 150),
                      curve: Curves.easeInOut,
                      child: Icon(Icons.expand_more, color: scheme.primary),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild:
                SettingsGroup(inset: false, children: widget.children),
            crossFadeState:
                _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }
}

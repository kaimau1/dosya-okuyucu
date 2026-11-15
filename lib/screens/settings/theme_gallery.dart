import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../core/skin.dart';
import '../../core/theme.dart';
import '../../widgets/fm/fm_glyph.dart';

/// **Tema galerisi** (2026-11-07, kullanıcı: *"temaların görünür biçimde
/// seçilebilmesi örnek görseliyle beraber notlardaki gibi"*).
///
/// Eskiden tema ailesi bir satırın arkasındaki alt sayfadaydı (44 dp'lik
/// renk lekesi + ad), üstelik aynı işi yapan ikinci bir "hızlı tema" çip
/// satırı vardı (Açık · Koyu · AMOLED · Kâğıt — aile + mod çiftleri). İkisi
/// birleşti: her aile KÜÇÜK BİR EKRAN ÖNİZLEMESİ (masa zemini, üst çubuk,
/// kâğıt kart + ailenin klasör simgesi, yazı satırları, vurgu düğmesi) ve
/// altında adı. Dokunulan aile anında uygulanır; seçili kart vurgu
/// çerçeveli + ✓.
///
/// Önizleme ŞU ANKİ parlaklıkta çizilir (koyu moddaysa koyu paletler) —
/// kullanıcı göreceğini görür; Gece ailesi her zaman koyu.
///
/// Başarım: kartlar sabit ölçülü, her biri [RepaintBoundary]; galeri
/// `select` ile yalnız aile/parlaklık değişince yeniden kurulur.
class ThemeGallery extends StatefulWidget {
  /// `true`: tek satır yatay şerit (ana Ayarlar ekranı). `false`: ızgara
  /// (Görünüm sayfası).
  final bool strip;

  const ThemeGallery({super.key, this.strip = false});

  static const cardWidth = 84.0;

  @override
  State<ThemeGallery> createState() => _ThemeGalleryState();
}

class _ThemeGalleryState extends State<ThemeGallery> {
  ScrollController? _scroll;

  @override
  void dispose() {
    _scroll?.dispose();
    super.dispose();
  }

  /// Galeri grupları (2026-11-15, kullanıcı: *"tema ailesini gruplandır,
  /// eski tip olanlarla yeni olanların farkı anlaşılsın"*). Sıra = ekranda
  /// görünen sıra; listede olmayan yeni bir aile "Renk temaları"na düşer.
  static const _groups = <(String, List<AppSkin>)>[
    ('skin.g_layout', [AppSkin.calm, AppSkin.bento, AppSkin.band]),
    ('skin.g_color', [
      AppSkin.sage,
      AppSkin.porcelain,
      AppSkin.clay,
      AppSkin.lavender,
      AppSkin.olive,
      AppSkin.white,
      AppSkin.straw,
      AppSkin.cream,
      AppSkin.peach,
      AppSkin.mint,
      AppSkin.modern,
    ]),
    ('skin.g_classic', [AppSkin.classic, AppSkin.ledger]),
    ('skin.g_special', [AppSkin.night, AppSkin.system]),
  ];

  static List<(String, List<AppSkin>)> _grouped(List<AppSkin> skins) {
    final listed = {for (final g in _groups) ...g.$2};
    final out = <(String, List<AppSkin>)>[];
    for (final (key, members) in _groups) {
      final present = [
        for (final s in members)
          if (skins.contains(s)) s,
        if (key == 'skin.g_color')
          for (final s in skins)
            if (!listed.contains(s)) s,
      ];
      if (present.isNotEmpty) out.add((key, present));
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    const cardWidth = ThemeGallery.cardWidth;
    final strip = widget.strip;
    final current = context.select<AppState, AppSkin>((s) => s.appSkin);
    final brightness = Theme.of(context).brightness;
    final theme = Theme.of(context);
    final skins = [
      for (final s in AppSkin.values)
        if (s.available || s == current) s,
    ];
    final groups = _grouped(skins);
    void pick(AppSkin s) => context.read<AppState>().setAppSkin(s);

    Widget card(AppSkin s) => ThemeSkinCard(
          key: ValueKey('skin-card-${s.name}'),
          skin: s,
          brightness: brightness,
          selected: s == current,
          onTap: () => pick(s),
        );

    Widget groupLabel(String key) => Padding(
          padding: const EdgeInsetsDirectional.only(start: 2),
          child: Text(
            context.t(key),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.primary,
            ),
          ),
        );
    final labelStyle = theme.textTheme.labelMedium;
    final labelH = MediaQuery.textScalerOf(context)
            .scale(labelStyle?.fontSize ?? 12) *
        (labelStyle?.height ?? 1.34);

    if (strip) {
      // Tek yatay şerit; her grup kendi başlığıyla bir blok, bloklar
      // arasında ince ayraç. Seçili aile görünür alanda açılsın.
      const groupGap = Gap.md;
      var offset = 0.0;
      var found = false;
      for (final (_, members) in groups) {
        final i = members.indexOf(current);
        if (i >= 0) {
          offset += i * (cardWidth + Gap.sm);
          found = true;
          break;
        }
        offset += members.length * (cardWidth + Gap.sm) + groupGap;
      }
      if (!found || offset < cardWidth) offset = 0;
      return SizedBox(
        height: ThemeSkinCard.heightOf(context) + labelH + Gap.xs,
        child: ListView.separated(
          key: const ValueKey('theme-gallery-strip'),
          scrollDirection: Axis.horizontal,
          controller: _scroll ??= ScrollController(
            initialScrollOffset: offset <= 0 ? 0 : offset - cardWidth / 2,
          ),
          itemCount: groups.length,
          separatorBuilder: (_, _) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: groupGap / 2 - 1),
            child: VerticalDivider(
                width: 1, color: theme.colorScheme.outlineVariant),
          ),
          itemBuilder: (_, g) {
            final (key, members) = groups[g];
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: members.length * (cardWidth + Gap.sm) - Gap.sm,
                  child: groupLabel(key),
                ),
                const SizedBox(height: Gap.xs),
                Row(
                  children: [
                    for (var i = 0; i < members.length; i++) ...[
                      if (i > 0) const SizedBox(width: Gap.sm),
                      SizedBox(width: cardWidth, child: card(members[i])),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      );
    }
    return LayoutBuilder(
      key: const ValueKey('theme-gallery-grid'),
      builder: (context, c) {
        final w = c.maxWidth;
        final perRow = w < 380 ? 3 : (w < 560 ? 4 : (w < 820 ? 6 : 8));
        final width = (w - Gap.sm * (perRow - 1)) / perRow;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (key, members) in groups) ...[
              if (key != groups.first.$1) const SizedBox(height: Gap.md),
              groupLabel(key),
              const SizedBox(height: Gap.xs),
              Wrap(
                spacing: Gap.sm,
                runSpacing: Gap.sm,
                children: [
                  for (final s in members)
                    SizedBox(width: width, child: card(s)),
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// Tek aile: mini ekran önizlemesi + ad.
class ThemeSkinCard extends StatelessWidget {
  final AppSkin skin;
  final Brightness brightness;
  final bool selected;
  final VoidCallback onTap;

  const ThemeSkinCard({
    super.key,
    required this.skin,
    required this.brightness,
    required this.selected,
    required this.onTap,
  });

  static const previewHeight = 92.0;
  /// Kartın toplam yüksekliği YAZI ÖLÇEĞİYLE büyür (2,0× yazıda sabit 26 dp
  /// ad satırı 12 dp taşıyordu — `a11y_guidelines_test`).
  static double heightOf(BuildContext context) {
    final style = Theme.of(context).textTheme.labelMedium;
    final size = style?.fontSize ?? 12;
    final line = MediaQuery.textScalerOf(context).scale(size) *
        (style?.height ?? 1.34);
    return previewHeight + 6 + line + 4;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final label = context.t(skin.labelKey);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(Radii.card),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: Motion.short,
              height: previewHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Radii.card),
                border: Border.all(
                  color: selected ? scheme.primary : scheme.outlineVariant,
                  width: selected ? 2.5 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(Radii.card - 2),
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _SkinPreview(
                        skin: skin,
                        brightness:
                            skin.forcesDark ? Brightness.dark : brightness,
                      ),
                      if (selected)
                        PositionedDirectional(
                          end: 4,
                          top: 4,
                          child: CircleAvatar(
                            radius: 9,
                            backgroundColor: scheme.primary,
                            child: Icon(AppIcons.check,
                                size: 12, color: scheme.onPrimary),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected ? scheme.primary : null,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ailenin kendi paleti ve ölçüleriyle küçük bir "ana ekran".
class _SkinPreview extends StatelessWidget {
  final AppSkin skin;
  final Brightness brightness;

  const _SkinPreview({required this.skin, required this.brightness});

  @override
  Widget build(BuildContext context) {
    final p = SkinPalette.of(skin, brightness);
    final m = SkinMetrics.of(skin);
    final r = (m.radiusCard * 0.45).clamp(3.0, 10.0);
    Widget line(double w, Color c, [double h = 3]) => Container(
          width: w,
          height: h,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(h),
          ),
        );
    return ColoredBox(
      color: p.bg,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Üst çubuk.
              Container(
                height: 16,
                color: p.band,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                alignment: AlignmentDirectional.centerStart,
                child: line(24, p.ink, 3.5),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: p.rule, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      // Gerçek klasör çizimi: klasik ailede düz manila,
                      // ötekilerde degradeli gövde (2026-11-08).
                      FmGlyph(
                        size: 18,
                        spec: FmGlyphSpec(
                          folder: true,
                          color: m.folderColor ?? AppHues.honey,
                          classic: m.classicIcons,
                          dark: brightness == Brightness.dark,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            line(30, p.ink),
                            const SizedBox(height: 3),
                            line(20, p.inkFaint),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 5, 6, 0),
                child: Container(
                  height: 18,
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(r),
                    border: Border.all(color: p.rule, width: 0.8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  alignment: AlignmentDirectional.centerStart,
                  child: line(26, p.inkSoft),
                ),
              ),
            ],
          ),
          // Vurgu: yüzen düğme.
          PositionedDirectional(
            end: 6,
            bottom: 6,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: p.accent,
                borderRadius: BorderRadius.circular(r.clamp(3.0, 8.0)),
              ),
              child: Icon(AppIcons.add, size: 11, color: p.onAccent),
            ),
          ),
        ],
      ),
    );
  }
}

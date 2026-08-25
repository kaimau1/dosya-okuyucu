import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/skin.dart';
import '../../core/theme.dart';
import 'settings_widgets.dart';

/// Tema: sistem / açık / koyu.
class ThemeTile extends StatelessWidget {
  const ThemeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingChoice<ThemeMode>(
      icon: Icons.contrast,
      title: context.t('settings.theme'),
      options: [
        (ThemeMode.system, context.t('settings.theme_system')),
        (ThemeMode.light, context.t('settings.theme_light')),
        (ThemeMode.dark, context.t('settings.theme_dark')),
      ],
      selected: appState.themeMode,
      onChanged: appState.setThemeMode,
    );
  }
}

/// Arayüz yazı tipi.
///
/// Açılır menü değil alt sayfa: on aile tek satıra sığmıyor ve her birinin
/// nasıl göründüğü ancak KENDİ yazı tipiyle yazılınca anlaşılıyor.
class UiFontTile extends StatelessWidget {
  const UiFontTile({super.key});

  static String labelOf(String family) => AppTheme.uiFonts
      .firstWhere((f) => f.$2 == family, orElse: () => (family, family))
      .$1;

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.text_fields,
      title: context.t('settings.ui_font'),
      value: labelOf(appState.uiFont),
      onTap: () async {
        final pick = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
                  child: Text(ctx.t('settings.ui_font'),
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final f in AppTheme.uiFonts)
                  ListTile(
                    title: Text(f.$1,
                        style: TextStyle(fontFamily: f.$2, fontSize: 17)),
                    subtitle: Text(
                      ctx.t('settings.font_sample'),
                      style: TextStyle(fontFamily: f.$2),
                    ),
                    trailing: f.$2 == appState.uiFont
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, f.$2),
                  ),
              ],
            ),
          ),
        );
        if (pick != null) await appState.setUiFont(pick);
      },
    );
  }
}

/// Yazı boyutu: hazır kademeler + ince ayar kaydırıcısı.
///
/// Cihazın sistem yazı boyutu ayarı YOK SAYILIYOR (bkz. `DosyaOkuyucuApp
/// .builder`) — bu yüzden uygulamanın kendi ayarı tek yer ve kolay bulunur
/// olmalı (kullanıcı 2026-08-07: *"küçük orta büyük çok büyük şeklinde kolay
/// seçimde olsun"*).
class UiTextSizeTile extends StatelessWidget {
  const UiTextSizeTile({super.key});

  /// Kaydırıcıyla ara bir değere gelindiyse EN YAKIN kademe seçili görünür;
  /// hiçbiri seçili olmayan bir segment çubuğu bozuk sanılıyordu.
  static double nearestScale(double value) {
    var best = AppTheme.uiTextScales.first.$2;
    for (final step in AppTheme.uiTextScales) {
      if ((step.$2 - value).abs() < (best - value).abs()) best = step.$2;
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingChoice<double>(
          icon: Icons.format_size,
          title: context.t('settings.ui_text_size'),
          subtitle: context.t('settings.ui_text_size_note'),
          options: [
            for (final step in AppTheme.uiTextScales)
              (step.$2, context.t(step.$1)),
          ],
          selected: nearestScale(appState.uiTextScale),
          onChanged: appState.setUiTextScale,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, 0),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: appState.uiTextScale,
                  min: 0.85,
                  max: 1.4,
                  divisions: 11,
                  label: '%${(appState.uiTextScale * 100).round()}',
                  onChanged: appState.setUiTextScale,
                ),
              ),
              Text('%${(appState.uiTextScale * 100).round()}',
                  style:
                      TextStyle(fontSize: 12, color: Paper.faint(context))),
            ],
          ),
        ),
      ],
    );
  }
}

/// Arayüz dili.
///
/// Diller **kendi dillerinde** yazılır (Türkçe / English / العربية): dilini
/// arayan kullanıcı, o an anlamadığı bir dilde yazılmış listeyi okuyamaz.
/// "Sistem" seçeneği ise seçili dilde yazılır — o, bir dilin adı değil bir
/// davranış.
class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingChoice<AppLanguage>(
      icon: Icons.translate,
      title: context.t('settings.language'),
      subtitle: context.t('settings.language_note'),
      options: [
        for (final lang in AppLanguage.values)
          (
            lang,
            lang == AppLanguage.system
                ? context.t('settings.language_system')
                : lang.nativeLabel
          ),
      ],
      selected: appState.language,
      onChanged: appState.setLanguage,
    );
  }
}

/// **Tema ailesi** — kağıt / açık / modern / iş programı / gece.
///
/// Kullanıcı isteği (2026-08-25): *"şuan ki tema açık ama bu aslında kağıt
/// teması, bunu kağıt tema olarak adlandır ve yeni olarak açık tema getir …
/// genel temalarda farklı klasör simgeleri boyutları gibi sanki telefonun ana
/// temasını değiştirir gibi temalar olsun"*.
///
/// Açılır menü değil alt sayfa, ve her satırda **canlı önizleme**: aile yalnız
/// renk değil köşe/simge/yoğunluk da değiştiriyor, adı okumak neyi seçtiğini
/// anlatmıyor. Önizleme o ailenin kendi paletiyle, kendi köşesiyle çizilir.
class AppSkinTile extends StatelessWidget {
  const AppSkinTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingTile(
      icon: Icons.style_outlined,
      title: context.t('skin.title'),
      value: context.t(appState.appSkin.labelKey),
      onTap: () async {
        final pick = await showModalBottomSheet<AppSkin>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              children: [
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.sm),
                  child: Text(ctx.t('skin.title'),
                      style: Theme.of(ctx).textTheme.titleMedium),
                ),
                for (final skin in AppSkin.values)
                  ListTile(
                    leading: _SkinSwatch(skin: skin),
                    title: Text(ctx.t(skin.labelKey)),
                    subtitle: Text(
                      skin.forcesDark
                          ? '${ctx.t(skin.descriptionKey)} · '
                              '${ctx.t('skin.forces_dark')}'
                          : ctx.t(skin.descriptionKey),
                    ),
                    trailing: skin == appState.appSkin
                        ? const Icon(Icons.check)
                        : null,
                    onTap: () => Navigator.pop(ctx, skin),
                  ),
              ],
            ),
          ),
        );
        if (pick != null) await appState.setAppSkin(pick);
      },
    );
  }
}

/// Bir ailenin üç satırlık minyatürü: zemin, kart, vurgu — ve ailenin kendi
/// köşe yarıçapı. Renk lekesi tek başına "keskin köşe / yuvarlak köşe" farkını
/// göstermiyordu.
class _SkinSwatch extends StatelessWidget {
  final AppSkin skin;
  const _SkinSwatch({required this.skin});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final palette = SkinPalette.of(
        skin, dark ? Brightness.dark : Brightness.light);
    final metrics = SkinMetrics.of(skin);
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: palette.bg,
        borderRadius: BorderRadius.circular(metrics.radiusCard * 0.6),
        border: Border.all(color: palette.edge),
      ),
      child: Center(
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(metrics.radiusControl * 0.5),
            border: Border.all(color: palette.rule),
          ),
          child: Center(
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: palette.accent,
                borderRadius:
                    BorderRadius.circular(metrics.radiusControl * 0.4),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// **Arka plan rengi** — 12 hazır renk (kullanıcı kararı 2026-08-25).
///
/// Serbest renk çarkı DEĞİL: kullanıcı okunamayan bir zemin seçebiliyordu.
/// Hazır renkler her ailede güvenli, ayrıca koyu bir zemin seçilirse mürekkep
/// kendiliğinden dönüyor (bkz. `SkinPalette.withBackground`).
class BackgroundColorTile extends StatelessWidget {
  const BackgroundColorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final current = AppBackground.byId(appState.background);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTile(
          icon: Icons.format_color_fill,
          title: context.t('bgc.title'),
          value: context.t(current.labelKey),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final bg in AppBackground.values)
                _BackgroundDot(
                  background: bg,
                  color: dark ? bg.dark : bg.light,
                  selected: bg.id == current.id,
                  onTap: () => appState.setBackground(bg.id),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BackgroundDot extends StatelessWidget {
  final AppBackground background;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _BackgroundDot({
    required this.background,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: context.t(background.labelKey),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
          child: background.isDefault
              // "Temanın kendi"nin rengi yok — eğik çizgi onu renkli
              // seçeneklerden ayırır, yoksa 12. bir renk sanılıyordu.
              ? Icon(Icons.format_color_reset,
                  size: 18, color: scheme.onSurfaceVariant)
              : (selected
                  ? Icon(Icons.check,
                      size: 20,
                      color: color.computeLuminance() < 0.5
                          ? Colors.white
                          : Colors.black)
                  : null),
        ),
      ),
    );
  }
}

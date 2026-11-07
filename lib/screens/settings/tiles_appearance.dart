import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/skin.dart';
import '../../core/theme.dart';
import 'settings_widgets.dart';
import 'theme_gallery.dart';
import '../../core/app_haptics.dart';

/// Tema: sistem / açık / koyu.
class ThemeTile extends StatelessWidget {
  const ThemeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingChoice<ThemeMode>(
      icon: AppIcons.contrast,
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
      icon: AppIcons.textFields,
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
                        style: context.type.heading.copyWith(fontFamily: f.$2)),
                    subtitle: Text(
                      ctx.t('settings.font_sample'),
                      style: TextStyle(fontFamily: f.$2),
                    ),
                    trailing: f.$2 == appState.uiFont
                        ? const Icon(AppIcons.check)
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
          icon: AppIcons.formatSize,
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
                  // 2,0×: Android 14+ doğrusal olmayan yazı ölçeğinin üst
                  // ucu (Faz 16). Hazır kademeler 1,3'te kalır; büyük yazı
                  // gereken kullanıcı kaydırıcıyla devam eder.
                  max: 2.0,
                  divisions: 23,
                  label: '%${(appState.uiTextScale * 100).round()}',
                  onChanged: appState.setUiTextScale,
                ),
              ),
              Text('%${(appState.uiTextScale * 100).round()}',
                  style: context.type.small.copyWith(color: Paper.faint(context))),
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
      icon: AppIcons.translate,
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

/// **Tema ailesi** — önizlemeli kart ızgarası (2026-11-07, [ThemeGallery]).
///
/// Eskiden satırın arkasında alt sayfa + 44 dp renk lekesiydi; kullanıcı
/// *"temaların görünür biçimde seçilebilmesi örnek görseliyle beraber"*
/// istedi. Artık her aile kendi küçük ekranıyla sayfada açıkça duruyor.
class AppSkinTile extends StatelessWidget {
  const AppSkinTile({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.select<AppState, AppSkin>((s) => s.appSkin);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingTile(
          icon: AppIcons.style,
          title: context.t('skin.title'),
          value: context.t(skin.labelKey),
          subtitle: skin.forcesDark ? context.t('skin.forces_dark') : null,
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          // Tek satır şerit: ızgara 13 aileyi üç satıra yayıp yazı/dil
          // satırlarını ekranın altına itiyordu.
          child: ThemeGallery(strip: true),
        ),
      ],
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
          icon: AppIcons.formatColorFill,
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
          width: 48,
          height: 48,
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
              ? Icon(AppIcons.formatColorReset,
                  size: 18, color: scheme.onSurfaceVariant)
              : (selected
                  ? Icon(AppIcons.check,
                      size: 20,
                      color: color.computeLuminance() < 0.5
                          ? AppColors.onMedia
                          : AppColors.pageInk)
                  : null),
        ),
      ),
    );
  }
}

/// **Alt çubuk kısayolları** (2026-10-18) — çubuğa basılı tutmanın Ayarlar'daki
/// karşılığı; basılı tutmayı bilmeyen de bulabilsin.
/// Dokunsal geri bildirim anahtarı (Faz 19 — `AppHaptics`).
class HapticsTile extends StatelessWidget {
  const HapticsTile({super.key});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: AppHaptics.enabled,
        builder: (context, on, _) => SettingSwitch(
          icon: AppIcons.vibration,
          title: context.t('set.haptics'),
          subtitle: context.t('set.haptics_sub'),
          value: on,
          onChanged: AppHaptics.setEnabled,
        ),
      );
}

/// **Vurgu rengi** (Faz 40 / 8): ailenin zemini kalır, yalnız vurgu değişir.
class AccentColorTile extends StatelessWidget {
  const AccentColorTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final brightness = Theme.of(context).brightness;
    final dark = brightness == Brightness.dark;
    final current = AppAccent.byId(appState.accent);
    final skinAccent = SkinPalette.of(appState.appSkin, brightness).accent;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SettingTile(
          icon: AppIcons.formatColorFill,
          title: context.t('acc.title'),
          value: context.t(current.labelKey),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
          child: Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.sm,
            children: [
              for (final a in AppAccent.values)
                Semantics(
                  selected: a.id == current.id,
                  button: true,
                  label: context.t(a.labelKey),
                  excludeSemantics: true,
                  child: Tooltip(
                    message: context.t(a.labelKey),
                    child: InkWell(
                      key: ValueKey('accent-${a.id}'),
                      onTap: () => appState.setAccent(a.id),
                      customBorder: const CircleBorder(),
                      child: Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: a.isDefault
                              ? skinAccent
                              : (dark ? a.dark : a.light),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: a.id == current.id
                                ? scheme.onSurface
                                : scheme.outlineVariant,
                            width: a.id == current.id ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
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

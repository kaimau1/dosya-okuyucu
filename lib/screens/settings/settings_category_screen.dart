import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import 'settings_catalog.dart';
import 'settings_group.dart';

/// Bir ayar kategorisinin kendi sayfası.
///
/// **2026-08-29 yeniden tasarımı.** Eskiden düz bir listeydi: bölümler yalnız
/// bir cetvelle ayrılıyor, satırlar kâğıdın üstünde serbest akıyordu. Artık her
/// bölüm kendi kartında (`SettingsGroup`) toplanıyor ve nadiren dokunulan
/// satırlar kapalı bir **Gelişmiş** bloğunda duruyor. İçerik AZALMADI — yalnız
/// ağırlıklandı: sık kullanılan üstte ve açık, uzman işi olan altta ve kapalı.
class SettingsCategoryScreen extends StatelessWidget {
  final SettingsCategory category;

  const SettingsCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final normal = category.sections.where((s) => !s.advanced).toList();
    final advanced = category.sections.where((s) => s.advanced).toList();
    return Scaffold(
      appBar: AppBar(title: Text(context.t(category.titleKey))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          // Kategorinin ne olduğu tek satır, sakin: sayfanın başında kullanıcı
          // "doğru yerde miyim" sorusunu bir bakışta cevaplayabilmeli.
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md + 4, Gap.md, Gap.md, 0),
            child: Text(
              context.t(category.subtitleKey),
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: Paper.faint(context)),
            ),
          ),
          for (final section in normal)
            SettingsGroup(
              // Tek bölümlü kategoride başlık gürültü: kategori adı üstte.
              title: normal.length > 1 ? context.t(section.titleKey) : null,
              children: [for (final row in section.rows) row.builder(context)],
            ),
          for (final section in advanced)
            SettingsAdvancedGroup(
              title: context.t(section.titleKey),
              children: [for (final row in section.rows) row.builder(context)],
            ),
        ],
      ),
    );
  }
}

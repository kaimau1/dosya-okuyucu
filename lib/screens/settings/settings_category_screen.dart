import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../widgets/section_header.dart';
import 'settings_catalog.dart';

/// Bir ayar kategorisinin kendi sayfası: cetvelli bölümler, altında satırlar.
///
/// Kategoriler ana ekranda kart olarak duruyor; burası yalnız o kartın içi.
/// Böylece ana ekran hiç kaydırmadan tek bakışta okunuyor (eski Ayarlar yedi
/// açık bölümün üst üste yığıldığı, üç ekran boyu bir listeydi).
class SettingsCategoryScreen extends StatelessWidget {
  final SettingsCategory category;

  const SettingsCategoryScreen({super.key, required this.category});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(context.t(category.titleKey))),
        body: ListView(
          padding: const EdgeInsets.only(bottom: Gap.xl),
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
              child: Text(
                context.t(category.subtitleKey),
                style: TextStyle(fontSize: 13, color: Paper.faint(context)),
              ),
            ),
            for (final section in category.sections) ...[
              // Tek bölümlü kategoride başlık gürültü: kategori adı zaten
              // üstte yazıyor.
              if (category.sections.length > 1)
                SectionHeader(context.t(section.titleKey)),
              if (category.sections.length == 1)
                const SizedBox(height: Gap.sm),
              for (final row in section.rows) row.builder(context),
            ],
          ],
        ),
      );
}

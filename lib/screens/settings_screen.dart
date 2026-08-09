import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import '../widgets/section_header.dart';
import 'settings/settings_catalog.dart';
import 'settings/settings_category_screen.dart';

export 'settings/tiles_system.dart' show showOpenSourceLicenses;

/// **Ayarlar — tek giriş kapısı.**
///
/// KÖK NEDEN (2026-08-09 kullanıcı: *"ayarlar kısmımız çok karıştı, her yer her
/// yerde, tamamen sıfırdan tasarlanmalı ve yerleştirilmeli"*): ayarlar iki ayrı
/// ekrana bölünmüştü (`SettingsScreen` + `FmSettingsScreen`), ikisi birbirine
/// köprü veriyor, "görünüm" başlığı iki ekranda iki farklı şey anlatıyordu.
/// Üstelik her iki ekranda da arama YALNIZ bölüm başlığına bakıyordu: "küçük
/// resim" yazan kullanıcı hiçbir sonuç bulamıyordu, çünkü o metin bir bölüm
/// başlığı değil bir satırdı.
///
/// Yeni yerleşim:
/// - **Sekiz kategori kartı** — her biri kendi sayfası, ana ekran tek bakışta
///   okunuyor (eskiden yedi açık bölüm üst üste, üç ekran boyu bir listeydi).
/// - **Kartta mevcut değer** ("Koyu · Türkçe") — kategoriyi açmadan ne ayarlı
///   olduğu görünüyor.
/// - **Arama TÜM ayarlarda ve satır düzeyinde**: eşleşen ayarın kendisi, kendi
///   denetimiyle ve hangi kategoriden geldiği yazılı olarak listeleniyor —
///   sonuca dokunup değiştirmek için o sayfaya gitmek gerekmiyor.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = settingsCategories();
    final q = _query.trim().toLowerCase();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings.title')),
        // Arama kutusu HEP açık, düğme arkasında değil: "ayarı bulamıyorum"
        // sorununun çözümü, aramanın önce keşfedilmesini gerektirmemeli.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                isDense: true,
                hintText: context.t('set.search_all'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: q.isEmpty
                    ? null
                    : IconButton(
                        tooltip: context.t('common.clear'),
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _query = '';
                          _search.clear();
                        }),
                      ),
              ),
            ),
          ),
        ),
      ),
      body: q.isEmpty ? _categoryList(categories) : _searchResults(categories, q),
    );
  }

  /// Kategori kartları — ana görünüm.
  Widget _categoryList(List<SettingsCategory> categories) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(Gap.sm, Gap.sm, Gap.sm, Gap.xl),
        itemCount: categories.length,
        itemBuilder: (context, i) => _CategoryCard(category: categories[i]),
      );

  /// Arama sonuçları: eşleşen **ayarın kendisi**, kategorisiyle birlikte.
  Widget _searchResults(List<SettingsCategory> categories, String q) {
    final blocks = <Widget>[];
    for (final category in categories) {
      final hits =
          category.rows.where((r) => r.matches(context, q)).toList();
      if (hits.isEmpty) continue;
      blocks.add(SectionHeader(context.t(category.titleKey)));
      for (final row in hits) {
        blocks.add(row.builder(context));
      }
    }
    if (blocks.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Text(context.t('set.no_match'), textAlign: TextAlign.center),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: blocks,
    );
  }
}

/// Bir ayar kategorisini **doğrudan** açar (`settingsCategories()` kimlikleri:
/// `appearance`, `browsing`, `ai`, `account`, `privacy`, `trash`,
/// `performance`, `about`).
///
/// Ekranlar "ayarlara git" derken kullanıcıyı ana listeye bırakıp aradığını
/// kendisi bulmaya zorlamamalı: çöp kutusundaki "otomatik boşaltma kapalı"
/// uyarısı tam o ayarın olduğu sayfayı açar. Kimlik bulunamazsa (yazım hatası)
/// ana ayar ekranı açılır — kullanıcı hiçbir durumda boşluğa düşmez.
Future<void> openSettingsCategory(BuildContext context, String id) {
  final match = settingsCategories().where((c) => c.id == id).toList();
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => match.isEmpty
        ? const SettingsScreen()
        : SettingsCategoryScreen(category: match.first),
  ));
}

/// Ana ekrandaki kategori kartı: simge · ad · ne olduğu · mevcut değer.
class _CategoryCard extends StatelessWidget {
  final SettingsCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: Gap.sm, vertical: Gap.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(Radii.card),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SettingsCategoryScreen(category: category),
        )),
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Icon(category.icon, size: 24, color: scheme.primary),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.t(category.titleKey),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      context.t(category.subtitleKey),
                      style:
                          TextStyle(fontSize: 12, color: Paper.faint(context)),
                    ),
                    const SizedBox(height: Gap.xs),
                    // Mevcut değer: kategoriyi açmadan ne ayarlı olduğu.
                    Text(
                      category.summary(context),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Paper.faint(context)),
            ],
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import 'settings/settings_catalog.dart';
import 'settings/settings_category_screen.dart';
import 'settings/settings_group.dart';

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
    final query = _query.trim();

    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('settings.title')),
        // Arama kutusu HEP açık, düğme arkasında değil: "ayarı bulamıyorum"
        // sorununun çözümü, aramanın önce keşfedilmesini gerektirmemeli.
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.sm + 2),
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
                hintText: context.t('set.search_all'),
                prefixIcon: const Icon(Icons.search),
                // Kenarlık yok, dolgulu ve tam yuvarlak: arama kutusu bir
                // "form alanı" değil, dokunulası bir hap gibi dursun.
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: Gap.md, vertical: Gap.sm + 2),
                suffixIcon: query.isEmpty
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
      body: query.isEmpty
          ? _categoryList(categories)
          : _searchResults(categories, query),
    );
  }

  /// Kategori kartları — ana görünüm.
  Widget _categoryList(List<SettingsCategory> categories) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl),
        itemCount: categories.length,
        itemBuilder: (context, i) => _CategoryCard(category: categories[i]),
      );

  /// **Arama sonuçları — 2026-08-29.**
  ///
  /// Üç şey değişti: (1) eşleşme Türkçe harf duyarsız ve üç dilde birden
  /// aranıyor (`SettingsSearch`), (2) sonuçlar kategoriye göre değil
  /// **eşleşme gücüne** göre sıralanıyor — aradığı ayar en üstte olsun, (3)
  /// her sonucun altında hangi kategoriden geldiği yazıyor, çünkü ayarın
  /// kendisi burada doğrudan değiştirilebiliyor ve kullanıcı "bu neyin
  /// ayarıydı" diye sormamalı.
  Widget _searchResults(List<SettingsCategory> categories, String query) {
    final hits = <({SettingsCategory category, SettingRow row, int score})>[];
    for (final category in categories) {
      for (final row in category.rows) {
        final score = row.score(context, query);
        if (score > 0) {
          hits.add((category: category, row: row, score: score));
        }
      }
    }
    if (hits.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.search_off,
                  size: 48, color: Paper.faint(context)),
              const SizedBox(height: Gap.sm),
              Text(context.t('set.no_match'), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return ListView(
      padding: const EdgeInsets.only(bottom: Gap.xl),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md + 4, Gap.md, Gap.md, 0),
          child: Text(
            context.t('set.results_count', {'n': hits.length}),
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Paper.faint(context)),
          ),
        ),
        for (final hit in hits)
          SettingsGroup(
            title: context.t(hit.category.titleKey),
            children: [hit.row.builder(context)],
          ),
      ],
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
///
/// Geçerli kimlikler: `appearance`, `browsing`, `reading`, `ai`, `privacy`,
/// `storage`, `about` (+ eski `trash`/`performance`/`account` eşlemesi).
Future<void> openSettingsCategory(BuildContext context, String id) {
  // **Eski kimlikler yaşamaya devam ediyor** (2026-08-29 birleştirmesi):
  // çöp kutusu ve başarım "storage"da, hesap "privacy"de toplandı. Ekranlardaki
  // "ayarlara git" bağlantıları bu kimliklerle yazılmıştı; eşleme olmasaydı
  // kullanıcı doğru sayfa yerine ana listeye düşerdi.
  const aliases = {
    'trash': 'storage',
    'performance': 'storage',
    'account': 'privacy',
  };
  final target = aliases[id] ?? id;
  final match = settingsCategories().where((c) => c.id == target).toList();
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (_) => match.isEmpty
        ? const SettingsScreen()
        : SettingsCategoryScreen(category: match.first),
  ));
}

/// Ana ekrandaki kategori kartı — simge kutusu · ad · ne olduğu · mevcut değer.
///
/// **2026-08-29 tasarımı.** Eski kartta simge çıplak duruyordu ve üç satır
/// yazı (ad, açıklama, değer) aynı hizada başlıyordu: göz nereye bakacağını
/// bilemiyordu. Artık simge kendi yumuşak renkli kutusunda (dokunulacak yerin
/// nişanı), ad kalın, açıklama sakin, mevcut değer ise **vurgu renginde ve
/// altta** — kartın söylediği son şey "şu an şöyle ayarlı" oluyor.
class _CategoryCard extends StatelessWidget {
  final SettingsCategory category;

  const _CategoryCard({required this.category});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm + 2),
      child: Material(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.card + 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card + 2),
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SettingsCategoryScreen(category: category),
          )),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                // Simge kutusu: 44 dp, %12 vurgu dolgusu. Sabit ölçü, kartlar
                // alt alta dizilince simgeler tek bir sütun gibi okunuyor.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(category.icon, size: 22, color: scheme.primary),
                ),
                const SizedBox(width: Gap.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        context.t(category.titleKey),
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        context.t(category.subtitleKey),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: Paper.faint(context)),
                      ),
                      const SizedBox(height: Gap.xs + 2),
                      Text(
                        category.summary(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

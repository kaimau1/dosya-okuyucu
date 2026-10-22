import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/app_icons.dart';
import '../core/app_state.dart';

import '../core/l10n/app_strings.dart';
import '../core/theme.dart';
import 'settings/settings_catalog.dart';
import 'settings/settings_category_screen.dart';
import 'settings/settings_group.dart';
import '../core/safe_insets.dart';

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

  /// Geniş ekranda (≥ 840 dp) sağ bölmede açık kategori (Faz 18 / G17:
  /// liste-ayrıntı). Telefonda kullanılmaz — kart dokunuşu sayfa açar.
  String? _wideSelected;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categories = settingsCategories(
        developer: context.select<AppState, bool>((s) => s.developerMode));
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
                prefixIcon: const Icon(AppIcons.search),
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
                        icon: const Icon(AppIcons.close),
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
      body: query.isNotEmpty
          ? _searchResults(categories, query)
          : MediaQuery.sizeOf(context).width >= 840 && categories.isNotEmpty
              ? _wideLayout(categories)
              : _categoryList(categories),
    );
  }

  /// Liste-ayrıntı: solda kategoriler, sağda seçili kategorinin sayfası.
  Widget _wideLayout(List<SettingsCategory> categories) {
    final selected = categories.firstWhere((c) => c.id == _wideSelected,
        orElse: () => categories.first);
    return Row(
      key: const ValueKey('settings-list-detail'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 380,
          child: _categoryList(categories,
              selectedId: selected.id,
              onPick: (c) => setState(() => _wideSelected = c.id)),
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: SettingsCategoryScreen(
              key: ValueKey('settings-detail-${selected.id}'),
              category: selected),
        ),
      ],
    );
  }

  /// Kategori kartları — ana görünüm. En üstte hızlı tema seçici
  /// ([_QuickHeader]).
  Widget _categoryList(List<SettingsCategory> categories,
          {String? selectedId, ValueChanged<SettingsCategory>? onPick}) =>
      ListView.builder(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
        itemCount: categories.length + 1,
        itemBuilder: (context, i) => i == 0
            ? const _QuickHeader()
            : _CategoryCard(
                category: categories[i - 1],
                selected: categories[i - 1].id == selectedId,
                onTap: onPick == null ? null : () => onPick(categories[i - 1]),
              ),
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
              Icon(Icons.search_off_rounded, size: 48, color: Paper.faint(context)),
              const SizedBox(height: Gap.sm),
              Text(context.t('set.no_match'), textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }
    hits.sort((a, b) => b.score.compareTo(a.score));
    return ListView(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      children: [
        Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Gap.md + 4, Gap.md, Gap.md, 0),
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
  final developer = context.read<AppState>().developerMode;
  final match = settingsCategories(developer: developer)
      .where((c) => c.id == target)
      .toList();
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

  /// Geniş ekranda seçili kart vurgulanır; [onTap] verilirse sayfa AÇILMAZ.
  final bool selected;
  final VoidCallback? onTap;

  const _CategoryCard(
      {required this.category, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm + 2),
      child: Material(
        color: selected
            ? scheme.secondaryContainer
            : scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(Radii.card + 2),
        child: InkWell(
          borderRadius: BorderRadius.circular(Radii.card + 2),
          onTap: onTap ??
              () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsCategoryScreen(category: category),
                  )),
          child: Padding(
            padding: const EdgeInsets.all(Gap.md),
            child: Row(
              children: [
                // Simge kutusu: 44 dp, %12 vurgu dolgusu. Sabit ölçü, kartlar
                // alt alta dizilince simgeler tek bir sütun gibi okunuyor.
                // Kategori kendi renginde, üstten-sola açık degrade: pano
                // simgeleriyle (`FmTintedIcon`) aynı ışık dili.
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        category.color.withValues(alpha: 0.22),
                        category.color.withValues(alpha: 0.12),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(Radii.control),
                  ),
                  child: Icon(category.icon, size: 22, color: category.color),
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
                Icon(AppIcons.chevron, color: Paper.faint(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// **Ana ayar ekranının başlığı** — en sık değiştirilen ayar için kısa yol:
/// açık / koyu / otomatik tema. Tema üç dokunuş derinlikteydi (Ayarlar →
/// Görünüm → Tema → seçim); gece göz kamaştıran bir ekranı koyuya çevirmek
/// tek dokunuş olmalı. Ayrıntılı tema ailesi seçimi yerinde duruyor.
///
/// Bilinçli olarak TEK satır: kategori kartlarını ekranın dışına itmemeli.
class _QuickHeader extends StatelessWidget {
  const _QuickHeader();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm + 2),
      child: SegmentedButton<ThemeMode>(
        showSelectedIcon: false,
        // Dokunma alanı en az 48 dp (Faz 16, `androidTapTargetGuideline`;
        // sıkı yoğunlukta 40 dp'ye iniyordu).
        style: const ButtonStyle(
            minimumSize: WidgetStatePropertyAll(Size(0, 48))),
        segments: [
          ButtonSegment(
            value: ThemeMode.light,
            icon: const Icon(Icons.light_mode_rounded, size: 18),
            label: Text(context.t('settings.theme_light')),
          ),
          ButtonSegment(
            value: ThemeMode.dark,
            icon: const Icon(Icons.dark_mode_rounded, size: 18),
            label: Text(context.t('settings.theme_dark')),
          ),
          ButtonSegment(
            value: ThemeMode.system,
            icon: const Icon(Icons.brightness_auto_rounded, size: 18),
            label: Text(context.t('set.theme_auto')),
          ),
        ],
        selected: {state.themeMode},
        onSelectionChanged: (v) =>
            context.read<AppState>().setThemeMode(v.first),
      ),
    );
  }
}

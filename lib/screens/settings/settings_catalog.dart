import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import 'tiles_account.dart';
import 'tiles_ai.dart';
import 'tiles_appearance.dart';
import 'tiles_browsing.dart';
import 'tiles_privacy.dart';
import 'tiles_system.dart';
import 'tiles_trash.dart';

/// **Ayarların tek kaynağı.**
///
/// KÖK NEDEN (2026-08-09 kullanıcı: *"ayarlar kısmımız çok karıştı, her yer her
/// yerde, tamamen sıfırdan tasarlanmalı ve yerleştirilmeli"*): ayarlar İKİ ayrı
/// ekrana dağılmıştı — `SettingsScreen` (tema, dil, Gemini, hesap, pil) ve
/// `FmSettingsScreen` (yerleşim, küçük resim, çöp, izinler, dizin) — ve ikisi
/// birbirine köprü veriyordu. Aynı soru iki yerde cevaplanıyordu: "fotoğraf
/// ızgarası" hem gezgin ayarlarında hem galeri başlığındaydı, "görünüm" başlığı
/// iki ekranda iki farklı şey demekti. Kullanıcı bir ayarı ararken hangi ekranda
/// olduğunu ezberlemek zorundaydı.
///
/// Artık **tek** ekran, **sekiz** kategori ve TÜM ayarlarda çalışan bir arama
/// var. Bir ayarın nerede yaşadığı bu dosyada, tek satırda görünür; yeni ayar
/// eklemek "hangi ekrana koysam" sorusunu değil, "hangi kategoriye" sorusunu
/// sordurur.
class SettingRow {
  /// Sabit kimlik — testler ve derin bağlantılar için (çeviriden bağımsız).
  final String id;

  /// Aramada eşleşen ve arama sonucunda başlık olarak görünen ad.
  final String titleKey;

  /// Ek arama sözcükleri (eşanlam: "karanlık" → tema, "api" → Gemini).
  /// Çeviri anahtarıdır — arama üç dilde de çalışır.
  final List<String> altKeys;

  /// Ayarın gerçek denetimi.
  final WidgetBuilder builder;

  const SettingRow({
    required this.id,
    required this.titleKey,
    required this.builder,
    this.altKeys = const [],
  });

  /// [query] (küçük harfe çevrilmiş) bu ayara uyuyor mu?
  bool matches(BuildContext context, String query) {
    if (query.isEmpty) return true;
    if (context.t(titleKey).toLowerCase().contains(query)) return true;
    for (final key in altKeys) {
      if (context.t(key).toLowerCase().contains(query)) return true;
    }
    return false;
  }
}

/// Bir kategorinin içindeki alt başlık (cetvelli bölüm).
class SettingsSection {
  final String titleKey;
  final List<SettingRow> rows;
  const SettingsSection(this.titleKey, this.rows);
}

/// Ayar kategorisi — ana ekrandaki bir kart, dokununca kendi sayfası.
class SettingsCategory {
  final String id;
  final IconData icon;
  final String titleKey;

  /// "Bu kategoride ne var" — kartın altındaki tek satır.
  final String subtitleKey;

  final List<SettingsSection> sections;

  /// Kartın sağında görünen **mevcut değer** özeti ("Koyu · Türkçe").
  /// Kategoriyi açmadan ne ayarlı olduğunu görebilmek için.
  final String Function(BuildContext) summary;

  const SettingsCategory({
    required this.id,
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
    required this.sections,
    required this.summary,
  });

  List<SettingRow> get rows => [for (final s in sections) ...s.rows];
}

/// Sekiz kategori. **Sıra bilinçli:** önce her açılışta göze çarpan şey
/// (görünüm), sonra en çok kullanılan (dosya listeleri), sonra yetenek açan
/// ayarlar (yapay zekâ, hesap), sonra koruma (gizlilik), sonra yer açma
/// (silme), sonra pil, en sonda hakkında.
List<SettingsCategory> settingsCategories() => [
      SettingsCategory(
        id: 'appearance',
        icon: Icons.palette_outlined,
        titleKey: 'set.cat_appearance',
        subtitleKey: 'set.cat_appearance_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          final theme = switch (s.themeMode) {
            ThemeMode.light => context.t('settings.theme_light'),
            ThemeMode.dark => context.t('settings.theme_dark'),
            _ => context.t('settings.theme_system'),
          };
          final lang = s.language == AppLanguage.system
              ? context.t('settings.language_system')
              : s.language.nativeLabel;
          return '$theme · $lang';
        },
        sections: const [
          SettingsSection('set.sec_theme', [
            SettingRow(
              id: 'theme',
              titleKey: 'settings.theme',
              altKeys: ['settings.theme_dark', 'settings.theme_light'],
              builder: _themeTile,
            ),
          ]),
          SettingsSection('set.sec_text', [
            SettingRow(
                id: 'ui_font',
                titleKey: 'settings.ui_font',
                builder: _fontTile),
            SettingRow(
                id: 'ui_text_size',
                titleKey: 'settings.ui_text_size',
                builder: _textSizeTile),
          ]),
          SettingsSection('set.sec_language', [
            SettingRow(
                id: 'language',
                titleKey: 'settings.language',
                builder: _languageTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'browsing',
        icon: Icons.view_list_outlined,
        titleKey: 'set.cat_browsing',
        subtitleKey: 'set.cat_browsing_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return '${context.t(s.fmLayout.labelKey)} · '
              '${context.t(s.fmSort.labelKey)} ${s.fmSortDesc ? '↓' : '↑'}';
        },
        sections: const [
          SettingsSection('set.sec_lists', [
            SettingRow(
                id: 'list_layout',
                titleKey: 'fmset.list_layout',
                builder: _listLayoutTile),
            SettingRow(
                id: 'default_sort',
                titleKey: 'fmset.default_sort',
                builder: _defaultSortTile),
            SettingRow(
                id: 'show_hidden',
                titleKey: 'fmset.show_hidden',
                builder: _showHiddenTile),
            SettingRow(
                id: 'thumbnails',
                titleKey: 'fmset.thumbnails',
                builder: _thumbnailsTile),
          ]),
          SettingsSection('set.sec_photos', [
            SettingRow(
                id: 'photo_grid',
                titleKey: 'fmset.photo_grid',
                builder: _photoGridTile),
            SettingRow(
                id: 'photo_group',
                titleKey: 'fmset.group_photos',
                builder: _photoGroupTile),
          ]),
          SettingsSection('set.sec_opening', [
            SettingRow(
                id: 'media_open_with',
                titleKey: 'fmset.media_open_with',
                builder: _mediaOpenWithTile),
            SettingRow(
                id: 'start_folder',
                titleKey: 'fmset.start_folder',
                builder: _startFolderTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'ai',
        icon: Icons.auto_awesome_outlined,
        titleKey: 'set.cat_ai',
        subtitleKey: 'set.cat_ai_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return s.hasApiKey ? s.model : context.t('set.key_missing');
        },
        sections: const [
          SettingsSection('set.sec_key', [
            SettingRow(
              id: 'api_key',
              titleKey: 'settings.api_key',
              altKeys: ['settings.model_default', 'set.cat_ai'],
              builder: _aiAccessTile,
            ),
          ]),
          SettingsSection('settings.memory', [
            SettingRow(
                id: 'memory',
                titleKey: 'settings.memory',
                builder: _memoryTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'account',
        icon: Icons.account_circle_outlined,
        titleKey: 'settings.account',
        subtitleKey: 'settings.account_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          if (!s.firebaseAvailable) return context.t('settings.account_local');
          return s.signedIn
              ? (s.userEmail ?? context.t('settings.signed_in'))
              : context.t('settings.sign_in');
        },
        sections: const [
          SettingsSection('settings.account', [
            SettingRow(
              id: 'account',
              titleKey: 'settings.account',
              altKeys: ['settings.email', 'settings.sync_active'],
              builder: _accountTile,
            ),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'privacy',
        icon: Icons.lock_outline,
        titleKey: 'set.cat_privacy',
        subtitleKey: 'set.cat_privacy_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return s.fmHasLockPin
              ? context.t('fmset.pin_sub_locked',
                  {'n': s.fmLockedFolders.length})
              : context.t('fmset.pin_sub_unset');
        },
        sections: const [
          SettingsSection('set.sec_lock', [
            SettingRow(
              id: 'pin',
              titleKey: 'fmset.pin_set',
              altKeys: ['fmset.pin_change', 'fmset.sec_privacy'],
              builder: _pinTile,
            ),
            SettingRow(
                id: 'locked_folders',
                titleKey: 'fmset.unlock',
                builder: _lockedFoldersTile),
          ]),
          SettingsSection('fmset.sec_permissions', [
            SettingRow(
                id: 'full_access',
                titleKey: 'fmset.full_access',
                builder: _fullAccessTile),
            SettingRow(
                id: 'usage_access',
                titleKey: 'fmset.usage_access',
                builder: _usageAccessTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'trash',
        icon: Icons.delete_outline,
        titleKey: 'set.cat_trash',
        subtitleKey: 'set.cat_trash_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return context.t(s.fmUseTrash ? 'fmset.use_trash' : 'fmset.off');
        },
        sections: const [
          SettingsSection('fmset.sec_delete', [
            SettingRow(
                id: 'use_trash',
                titleKey: 'fmset.use_trash',
                builder: _useTrashTile),
            SettingRow(
                id: 'confirm_delete',
                titleKey: 'fmset.confirm_delete',
                builder: _confirmDeleteTile),
            SettingRow(
                id: 'trash_auto',
                titleKey: 'fmset.trash_auto',
                builder: _trashAutoTile),
            SettingRow(
                id: 'empty_trash',
                titleKey: 'fmset.empty_trash_now',
                builder: _emptyTrashTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'performance',
        icon: Icons.battery_saver_outlined,
        titleKey: 'set.cat_perf',
        subtitleKey: 'set.cat_perf_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          final on = <String>[
            if (s.highRefreshRate) context.t('settings.perf_high_refresh'),
            if (s.autoRescan) context.t('settings.perf_auto_rescan'),
          ];
          return on.isEmpty ? context.t('fmset.off') : on.join(' · ');
        },
        sections: const [
          SettingsSection('set.sec_speed', [
            SettingRow(
                id: 'high_refresh',
                titleKey: 'settings.perf_high_refresh',
                builder: _highRefreshTile),
            SettingRow(
                id: 'auto_rescan',
                titleKey: 'settings.perf_auto_rescan',
                builder: _autoRescanTile),
          ]),
          SettingsSection('fmset.sec_maintenance', [
            SettingRow(
                id: 'search_index',
                titleKey: 'fmset.index',
                builder: _searchIndexTile),
            SettingRow(
                id: 'thumb_cache',
                titleKey: 'fmset.clear_thumbs',
                builder: _thumbCacheTile),
            SettingRow(
                id: 'volumes',
                titleKey: 'fmset.volumes',
                builder: _volumesTile),
          ]),
        ],
      ),
      SettingsCategory(
        id: 'about',
        icon: Icons.info_outline,
        titleKey: 'settings.about',
        subtitleKey: 'settings.about_sub',
        summary: (context) => context.t('settings.oss'),
        sections: const [
          SettingsSection('settings.about', [
            SettingRow(
                id: 'about', titleKey: 'settings.about', builder: _aboutTile),
          ]),
        ],
      ),
    ];

// `const` bir `SettingRow` listesi kurabilmek için üst düzey işlevler
// (kapanış/lambda `const` olamaz).
Widget _themeTile(BuildContext _) => const ThemeTile();
Widget _fontTile(BuildContext _) => const UiFontTile();
Widget _textSizeTile(BuildContext _) => const UiTextSizeTile();
Widget _languageTile(BuildContext _) => const LanguageTile();
Widget _listLayoutTile(BuildContext _) => const ListLayoutTile();
Widget _defaultSortTile(BuildContext _) => const DefaultSortTile();
Widget _showHiddenTile(BuildContext _) => const ShowHiddenTile();
Widget _thumbnailsTile(BuildContext _) => const ThumbnailsTile();
Widget _photoGridTile(BuildContext _) => const PhotoGridTile();
Widget _photoGroupTile(BuildContext _) => const PhotoGroupTile();
Widget _mediaOpenWithTile(BuildContext _) => const MediaOpenWithTile();
Widget _startFolderTile(BuildContext _) => const StartFolderTile();
Widget _aiAccessTile(BuildContext _) => const AiAccessTile();
Widget _memoryTile(BuildContext _) => const MemoryTile();
Widget _accountTile(BuildContext _) => const AccountTile();
Widget _pinTile(BuildContext _) => const PinTile();
Widget _lockedFoldersTile(BuildContext _) => const LockedFoldersTile();
Widget _fullAccessTile(BuildContext _) => const FullAccessTile();
Widget _usageAccessTile(BuildContext _) => const UsageAccessTile();
Widget _useTrashTile(BuildContext _) => const UseTrashTile();
Widget _confirmDeleteTile(BuildContext _) => const ConfirmDeleteTile();
Widget _trashAutoTile(BuildContext _) => const TrashAutoTile();
Widget _emptyTrashTile(BuildContext _) => const EmptyTrashTile();
Widget _highRefreshTile(BuildContext _) => const HighRefreshTile();
Widget _autoRescanTile(BuildContext _) => const AutoRescanTile();
Widget _searchIndexTile(BuildContext _) => const SearchIndexTile();
Widget _thumbCacheTile(BuildContext _) => const ThumbCacheTile();
Widget _volumesTile(BuildContext _) => const VolumesTile();
Widget _aboutTile(BuildContext _) => const AboutTile();

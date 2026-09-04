import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_language.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/settings_search.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import 'tiles_account.dart';
import 'tiles_ai.dart';
import 'tiles_ai_pool.dart';
import 'tiles_ai_scope.dart';
import 'tiles_appearance.dart';
import 'tiles_browsing.dart';
import 'tiles_privacy.dart';
import 'tiles_reading.dart';
import 'tiles_system.dart';
import 'tiles_trash.dart';
import '../../core/app_version.dart';

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

  /// Ayarın ne işe yaradığını anlatan satır. **Aramaya girer** (2026-08-29):
  /// "kaç gün" yazan kullanıcı çöp kutusu ayarını açıklamasından bulur.
  final String? subtitleKey;

  /// Ek arama sözcükleri (eşanlam: "karanlık" → tema, "api" → Gemini).
  /// Çeviri anahtarıdır — arama üç dilde de çalışır.
  final List<String> altKeys;

  /// Ayarın gerçek denetimi.
  final WidgetBuilder builder;

  const SettingRow({
    required this.id,
    required this.titleKey,
    required this.builder,
    this.subtitleKey,
    this.altKeys = const [],
  });

  /// Aramanın baktığı metinler — **üç dilde birden**.
  ///
  /// Sıra önemli: ilk öğe başlıktır ve [SettingsSearch.score] başlıktaki
  /// eşleşmeye daha yüksek puan verir.
  List<String> searchFields(BuildContext context) => [
        context.t(titleKey),
        ...AppStrings.variants(titleKey),
        if (subtitleKey != null) ...[
          context.t(subtitleKey!),
          ...AppStrings.variants(subtitleKey!),
        ],
        for (final key in altKeys) ...[
          context.t(key),
          ...AppStrings.variants(key),
        ],
      ];

  /// [query] bu ayara uyuyor mu?
  bool matches(BuildContext context, String query) =>
      SettingsSearch.matches(searchFields(context), query);

  /// Eşleşme gücü (arama sonuçlarını sıralamak için).
  int score(BuildContext context, String query) =>
      SettingsSearch.score(searchFields(context), query);
}

/// Bir kategorinin içindeki alt başlık (kart hâlinde bir grup).
class SettingsSection {
  final String titleKey;
  final List<SettingRow> rows;

  /// **Gelişmiş bölüm:** kategori sayfasında kapalı gelir, "Gelişmiş"
  /// başlığına dokununca açılır (kullanıcı isteği 2026-08-29: *"bazı şeyleri
  /// gelişmiş ayarlar adı altına ekleyebilirsin"*).
  ///
  /// Ölçüt: günlük kullanımda dokunulmayan, bir kez ayarlanan ya da uzman
  /// işi olan satırlar (model zinciri, anahtar havuzu, dizin bakımı, birim
  /// listesi). Aramada normal satır gibi çıkarlar — gizlenmiyorlar, yalnız
  /// varsayılan görünümde öne çıkmıyorlar.
  final bool advanced;

  const SettingsSection(this.titleKey, this.rows, {this.advanced = false});
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
      // ── 1. GÖRÜNÜM VE DİL ────────────────────────────────────────────────
      SettingsCategory(
        id: 'appearance',
        icon: Icons.palette_outlined,
        titleKey: 'set.cat_appearance',
        subtitleKey: 'set.cat_appearance_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return '${context.t(s.appSkin.labelKey)} · '
              '${_themeModeLabel(context, s.themeMode)} · '
              '${s.language.nativeLabel}';
        },
        sections: const [
          SettingsSection('set.sec_theme', [
            SettingRow(
                id: 'skin',
                titleKey: 'skin.title',
                altKeys: [
                  'skin.paper',
                  'skin.light',
                  'skin.modern',
                  'skin.office',
                  'skin.night',
                  'set.kw_dark',
                ],
                builder: _skinTile),
            SettingRow(
                id: 'theme',
                titleKey: 'settings.theme',
                altKeys: ['settings.theme_dark', 'settings.theme_light',
                    'set.kw_dark'],
                builder: _themeTile),
            SettingRow(
                id: 'background',
                titleKey: 'bgc.title',
                builder: _backgroundTile),
          ]),
          SettingsSection('set.sec_text', [
            SettingRow(
                id: 'ui_font',
                titleKey: 'settings.ui_font',
                altKeys: ['set.kw_font'],
                builder: _fontTile),
            SettingRow(
                id: 'ui_text_size',
                titleKey: 'settings.ui_text_size',
                subtitleKey: 'settings.ui_text_size_note',
                altKeys: ['set.kw_font'],
                builder: _textSizeTile),
          ]),
          SettingsSection('set.sec_language', [
            SettingRow(
                id: 'language',
                titleKey: 'settings.language',
                subtitleKey: 'settings.language_note',
                builder: _languageTile),
          ]),
        ],
      ),

      // ── 2. DOSYA LİSTELERİ ───────────────────────────────────────────────
      SettingsCategory(
        id: 'browsing',
        icon: Icons.view_list_outlined,
        titleKey: 'set.cat_browsing',
        subtitleKey: 'set.cat_browsing_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          return '${context.t(s.fmLayout.labelKey)} · '
              '${context.t(s.fmSort.labelKey)}';
        },
        sections: const [
          SettingsSection('set.sec_lists', [
            SettingRow(
                id: 'list_layout',
                titleKey: 'fmset.list_layout',
                subtitleKey: 'fmset.grid_density',
                builder: _listLayoutTile),
            SettingRow(
                id: 'default_sort',
                titleKey: 'fmset.default_sort',
                builder: _defaultSortTile),
            SettingRow(
                id: 'thumbnails',
                titleKey: 'fmset.thumbnails',
                subtitleKey: 'fmset.thumbnails_sub',
                builder: _thumbnailsTile),
            SettingRow(
                id: 'show_hidden',
                titleKey: 'fmset.show_hidden',
                subtitleKey: 'fmset.show_hidden_sub',
                builder: _showHiddenTile),
            SettingRow(
                id: 'folder_sizes',
                titleKey: 'fmset.folder_sizes',
                subtitleKey: 'fmset.folder_sizes_sub',
                builder: _folderSizesTile),
            SettingRow(
                id: 'resume_position',
                titleKey: 'fmset.resume',
                subtitleKey: 'fmset.resume_sub',
                builder: _resumePositionTile),
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

      // ── 3. OKUMA VE SESLİ OKUMA ──────────────────────────────────────────
      // 2026-08-29'da EKLENDİ: `TtsPrefs` (ses, hız, perde) ve "AI yanıtlarını
      // sesli oku" tercihleri uygulamada VARDI ama yalnız okuyucu ekranının
      // içindeki alt sayfadan ulaşılabiliyordu — Ayarlar'da hiç yoktu, yani
      // kullanıcı bir belge açmadan sesini seçemiyordu.
      SettingsCategory(
        id: 'reading',
        icon: Icons.record_voice_over_outlined,
        titleKey: 'set.cat_reading',
        subtitleKey: 'set.cat_reading_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          final speed = s.ttsPrefs.rate.toStringAsFixed(1);
          return context.t('set.tts_summary', {'x': speed});
        },
        sections: const [
          SettingsSection('set.sec_tts', [
            SettingRow(
                id: 'tts_voice',
                titleKey: 'set.tts_voice',
                subtitleKey: 'set.tts_voice_sub',
                altKeys: ['set.kw_speak'],
                builder: _ttsVoiceTile),
            SettingRow(
                id: 'tts_ai_read',
                titleKey: 'set.tts_ai_read',
                subtitleKey: 'set.tts_ai_read_sub',
                altKeys: ['set.kw_speak'],
                builder: _ttsAiReadTile),
          ]),
        ],
      ),

      // ── 4. YAPAY ZEKÂ ────────────────────────────────────────────────────
      SettingsCategory(
        id: 'ai',
        icon: Icons.auto_awesome_outlined,
        titleKey: 'set.cat_ai',
        subtitleKey: 'set.cat_ai_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          if (!s.hasApiKey) return context.t('set.ai_no_key');
          return '${s.model} · ${context.t('set.ai_key_count', {
                'n': s.apiKeys.length
              })}';
        },
        sections: const [
          SettingsSection('set.sec_key', [
            SettingRow(
              id: 'api_key',
              titleKey: 'settings.api_key',
              subtitleKey: 'set.api_key_sub',
              altKeys: ['set.kw_gemini'],
              builder: _aiAccessTile,
            ),
          ]),
          SettingsSection('set.sec_ai_scope', [
            SettingRow(
              id: 'ai_excluded',
              titleKey: 'aiset.excluded',
              subtitleKey: 'aiset.excluded_sub',
              builder: _aiExcludedTile,
            ),
            SettingRow(
              id: 'ai_types',
              titleKey: 'aiset.types',
              builder: _aiTypesTile,
            ),
            SettingRow(
              id: 'ai_privacy',
              titleKey: 'aiset.send_text',
              subtitleKey: 'aiset.send_text_sub',
              altKeys: ['aiset.send_images', 'aiset.hidden', 'aiset.excerpt'],
              builder: _aiPrivacyTile,
            ),
          ]),
          SettingsSection('settings.memory', [
            SettingRow(
                id: 'memory',
                titleKey: 'settings.memory',
                builder: _memoryTile),
          ]),
          // Uzman işi: model zinciri, yedek anahtar havuzu, günlük bütçe.
          SettingsSection('set.sec_advanced', [
            SettingRow(
              id: 'ai_backup_keys',
              titleKey: 'aipool.backup_keys',
              subtitleKey: 'aipool.backup_keys_sub',
              builder: _aiBackupKeysTile,
            ),
            SettingRow(
              id: 'ai_model_chain',
              titleKey: 'aipool.model_chain',
              subtitleKey: 'aipool.model_chain_sub',
              builder: _aiModelChainTile,
            ),
            SettingRow(
              id: 'ai_pool_status',
              titleKey: 'aipool.status',
              builder: _aiPoolStatusTile,
            ),
            SettingRow(
              id: 'ai_budget',
              titleKey: 'aiset.budget',
              subtitleKey: 'aiset.budget_sub',
              builder: _aiBudgetTile,
            ),
          ], advanced: true),
        ],
      ),

      // ── 5. GİZLİLİK VE HESAP ─────────────────────────────────────────────
      // "Hesap & Senkron" tek satırlık AYRI bir kategoriydi; girip tek bir
      // satır görmek kullanıcıya bir şey kazandırmıyordu. Giriş yapmak da,
      // klasör kilitlemek de, izin vermek de aynı soruya bakıyor: "verime kim
      // erişiyor" (birleştirme, 2026-08-29).
      SettingsCategory(
        id: 'privacy',
        icon: Icons.shield_outlined,
        titleKey: 'set.cat_privacy',
        subtitleKey: 'set.cat_privacy_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          final lock = s.fmHasLockPin
              ? context.t('fmset.pin_sub_locked', {'n': s.fmLockedFolders.length})
              : context.t('fmset.pin_sub_unset');
          if (!s.firebaseAvailable || !s.signedIn) return lock;
          return '${s.userEmail ?? context.t('settings.signed_in')} · $lock';
        },
        sections: const [
          SettingsSection('settings.privacy_policy', [
            SettingRow(
              id: 'privacy_policy',
              titleKey: 'settings.privacy_policy',
              subtitleKey: 'settings.privacy_policy_sub',
              builder: _privacyPolicyTile,
            ),
          ]),
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

      // ── 6. DEPOLAMA VE BAŞARIM ───────────────────────────────────────────
      // "Çöp kutusu" ve "Pil ve başarım" ayrı iki kategoriydi; ikisi de dört
      // satırdı ve ikisi de aynı soruya bakıyordu: "yer ve hız". Birleşti;
      // bakım işleri (dizin, önbellek, birimler) Gelişmiş'e indi.
      SettingsCategory(
        id: 'storage',
        icon: Icons.speed_outlined,
        titleKey: 'set.cat_storage',
        subtitleKey: 'set.cat_storage_sub',
        summary: (context) {
          final s = context.watch<AppState>();
          final trash = context.t(
              s.fmUseTrash ? 'fmset.use_trash' : 'set.trash_off');
          final refresh = s.highRefreshRate
              ? context.t('settings.perf_high_refresh')
              : context.t('set.refresh_60');
          return '$trash · $refresh';
        },
        sections: const [
          SettingsSection('fmset.sec_delete', [
            SettingRow(
                id: 'use_trash',
                titleKey: 'fmset.use_trash',
                subtitleKey: 'fmset.use_trash_sub',
                builder: _useTrashTile),
            SettingRow(
                id: 'confirm_delete',
                titleKey: 'fmset.confirm_delete',
                builder: _confirmDeleteTile),
            SettingRow(
                id: 'trash_auto',
                titleKey: 'fmset.trash_auto',
                altKeys: ['set.kw_days'],
                builder: _trashAutoTile),
            SettingRow(
                id: 'empty_trash',
                titleKey: 'fmset.empty_trash_now',
                builder: _emptyTrashTile),
          ]),
          SettingsSection('set.sec_speed', [
            SettingRow(
                id: 'high_refresh',
                titleKey: 'settings.perf_high_refresh',
                subtitleKey: 'settings.perf_high_refresh_sub',
                builder: _highRefreshTile),
            SettingRow(
                id: 'auto_rescan',
                titleKey: 'settings.perf_auto_rescan',
                subtitleKey: 'settings.perf_auto_rescan_sub',
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
                subtitleKey: 'fmset.clear_thumbs_sub',
                builder: _thumbCacheTile),
            SettingRow(
                id: 'volumes',
                titleKey: 'fmset.volumes',
                builder: _volumesTile),
            // "Bellek takılı ama görünmüyor" sorununun ÖLÇÜMÜ; sorun yaşayan
            // kullanıcı çareyi ayarlarda arar.
            SettingRow(
                id: 'usb_diagnostics',
                titleKey: 'usb.diag_title',
                subtitleKey: 'usb.diag_sub',
                builder: _usbDiagnosticsTile),
          ], advanced: true),
        ],
      ),

      // ── 7. HAKKINDA ──────────────────────────────────────────────────────
      SettingsCategory(
        id: 'about',
        icon: Icons.info_outline,
        titleKey: 'settings.about',
        subtitleKey: 'settings.about_sub',
        summary: (context) => 'v$appVersionName',
        sections: const [
          SettingsSection('settings.about', [
            SettingRow(
                id: 'about', titleKey: 'settings.about', builder: _aboutTile),
            SettingRow(
              id: 'crash_log',
              titleKey: 'settings.crash_log',
              subtitleKey: 'settings.crash_log_sub',
              builder: _crashLogTile,
            ),
          ]),
        ],
      ),
    ];

/// Tema modunun okunur adı (kategori kartındaki özet için).
String _themeModeLabel(BuildContext context, ThemeMode mode) => switch (mode) {
      ThemeMode.light => context.t('settings.theme_light'),
      ThemeMode.dark => context.t('settings.theme_dark'),
      ThemeMode.system => context.t('settings.theme_system'),
    };

// `const` bir `SettingRow` listesi kurabilmek için üst düzey işlevler
// (kapanış/lambda `const` olamaz).
Widget _themeTile(BuildContext _) => const ThemeTile();
Widget _skinTile(BuildContext _) => const AppSkinTile();
Widget _backgroundTile(BuildContext _) => const BackgroundColorTile();
Widget _fontTile(BuildContext _) => const UiFontTile();
Widget _textSizeTile(BuildContext _) => const UiTextSizeTile();
Widget _languageTile(BuildContext _) => const LanguageTile();
Widget _listLayoutTile(BuildContext _) => const ListLayoutTile();
Widget _defaultSortTile(BuildContext _) => const DefaultSortTile();
Widget _showHiddenTile(BuildContext _) => const ShowHiddenTile();
Widget _thumbnailsTile(BuildContext _) => const ThumbnailsTile();
Widget _folderSizesTile(BuildContext _) => const FolderSizesTile();
Widget _resumePositionTile(BuildContext _) => const ResumePositionTile();
Widget _photoGridTile(BuildContext _) => const PhotoGridTile();
Widget _photoGroupTile(BuildContext _) => const PhotoGroupTile();
Widget _mediaOpenWithTile(BuildContext _) => const MediaOpenWithTile();
Widget _startFolderTile(BuildContext _) => const StartFolderTile();
Widget _aiAccessTile(BuildContext _) => const AiAccessTile();
Widget _memoryTile(BuildContext _) => const MemoryTile();
Widget _aiBackupKeysTile(BuildContext _) => const AiBackupKeysTile();
Widget _aiModelChainTile(BuildContext _) => const AiModelChainTile();
Widget _aiPoolStatusTile(BuildContext _) => const AiPoolStatusTile();
Widget _aiExcludedTile(BuildContext _) => const AiExcludedFoldersTile();
Widget _aiTypesTile(BuildContext _) => const AiScopeTypesTile();
Widget _aiPrivacyTile(BuildContext _) => const AiPrivacyTile();
Widget _aiBudgetTile(BuildContext _) => const AiBudgetTile();
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
Widget _usbDiagnosticsTile(BuildContext _) => const UsbDiagnosticsTile();
Widget _aboutTile(BuildContext _) => const AboutTile();
Widget _ttsVoiceTile(BuildContext _) => const TtsVoiceTile();
Widget _ttsAiReadTile(BuildContext _) => const TtsAiReadTile();
Widget _crashLogTile(BuildContext _) => const CrashLogTile();
Widget _privacyPolicyTile(BuildContext _) => const PrivacyPolicyTile();

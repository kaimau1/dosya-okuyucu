import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../models/media_open_with.dart';
import '../../models/photo_group.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/search_index.dart';
import '../../services/fm/storage_permission.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import '../../widgets/fm/pin_dialog.dart';
import '../settings_screen.dart';

/// **Dosya yöneticisine özel** ayarlar (uygulama geneli ayarlar ayrı ekranda:
/// Gemini anahtarı, tema, hesap).
///
/// Buradaki her ayar kalıcıdır (`AppState` → SharedPreferences) ve anında
/// uygulanır: görünüm, küçük resimler, silme davranışı, çöp kutusu bakımı,
/// izinler ve önbellek temizliği.
class FmSettingsScreen extends StatefulWidget {
  const FmSettingsScreen({super.key});

  @override
  State<FmSettingsScreen> createState() => _FmSettingsScreenState();
}

class _FmSettingsScreenState extends State<FmSettingsScreen> {
  int _trashCount = 0;
  int _trashBytes = 0;
  bool _fullAccess = true;
  bool _usageAccess = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  /// Arama dizininin durumu — kullanıcı aramanın neden hızlı/yavaş olduğunu
  /// görebilsin diye açıkça yazılır.
  String _indexSubtitle() {
    final str = AppStrings.of(context);
    if (SearchIndex.isBuilding) return str.t('fmset.index_building');
    if (!SearchIndex.isReady) return str.t('fmset.index_none');
    return str.t('fmset.index_ready', {
      'n': SearchIndex.entryCount,
      'date': FsPaths.humanDate(SearchIndex.builtAtMs),
      'stale': SearchIndex.isStale ? str.t('fmset.index_stale') : '',
    });
  }

  Future<void> _rebuildIndex() async {
    setState(() {});
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    final count = await SearchIndex.rebuild();
    if (!mounted) return;
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(count == 0
          ? str.t('fmset.index_failed')
          : str.t('fmset.index_built', {'n': count})),
    ));
  }

  Future<void> _refresh() async {
    await FmEnv.ensureInit();
    await SearchIndex.ensureLoaded();
    final items = await FmEnv.trash.list();
    final access = await StoragePermission.hasFullAccess();
    final usage = await InstalledAppsService.hasUsagePermission();
    if (!mounted) return;
    setState(() {
      _trashCount = items.length;
      _trashBytes = items.fold<int>(0, (s, i) => s + i.sizeBytes);
      _fullAccess = access;
      _usageAccess = usage;
    });
  }

  /// Boşaltma burada da **ilerleme penceresiyle** yapılır (çöp ekranıyla aynı
  /// davranış — sessiz silme kullanıcı bulgusuydu, 2026-07-25).
  Future<void> _emptyTrash() async {
    final str = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(str.t('fmset.empty_confirm_title')),
        content: Text(str.t('fmset.empty_confirm_body', {
          'n': _trashCount,
          'size': FsPaths.humanSize(_trashBytes),
        })),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(str.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(str.t('fmset.empty'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final freed = _trashBytes;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: str.t('fmset.emptying'),
      task: (report, isCancelled) =>
          FmEnv.trash.empty(onProgress: report, isCancelled: isCancelled),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(result.hasError
          ? str.t('fmset.empty_partial',
              {'ok': result.succeeded, 'fail': result.errors.length})
          : result.cancelled
              ? str.t('fmset.empty_cancelled', {'ok': result.succeeded})
              : str.t('fmset.empty_done', {
                  'ok': result.succeeded,
                  'size': FsPaths.humanSize(freed),
                })),
    ));
    await _refresh();
  }

  Future<void> _clearThumbs() async {
    final str = AppStrings.of(context);
    final dir = Directory('${FmEnv.appSupportDir}/../cache/video_thumbs');
    var removed = 0;
    try {
      if (dir.existsSync()) {
        for (final f in dir.listSync()) {
          try {
            f.deleteSync(recursive: true);
            removed++;
          } catch (_) {}
        }
      }
    } catch (_) {}
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(removed == 0
            ? str.t('fmset.thumbs_none')
            : str.t('fmset.thumbs_cleared', {'n': removed}))));
  }

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(context.t('fmset.title'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: Gap.xl),
        children: [
          _section(context.t('fmset.sec_view')),
          ListTile(
            leading: Icon(fmLayoutIcon(appState.fmLayout)),
            title: Text(context.t('fmset.list_layout')),
            subtitle: Text('${context.t(appState.fmLayout.labelKey)} · '
                '${context.t(appState.fmLayout.descriptionKey)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked =
                  await showFmLayoutSheet(context, current: appState.fmLayout);
              if (picked != null) await appState.setFmLayout(picked);
            },
          ),
          ListTile(
            leading: Icon(fmLayoutIcon(appState.fmPhotoLayout)),
            title: Text(context.t('fmset.photo_grid')),
            subtitle: Text('${context.t(appState.fmPhotoLayout.labelKey)} · '
                '${context.t('fmset.grouping')}: '
                '${context.t(appState.fmPhotoGroup.labelKey)}'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () async {
              final picked = await showFmLayoutSheet(
                context,
                current: appState.fmPhotoLayout,
                title: context.t('fmset.grid_density'),
                allowLists: false,
              );
              if (picked != null) await appState.setFmPhotoLayout(picked);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.visibility_outlined),
            title: Text(context.t('fmset.show_hidden')),
            subtitle: Text(context.t('fmset.show_hidden_sub')),
            value: appState.fmShowHidden,
            onChanged: appState.setFmShowHidden,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.image_outlined),
            title: Text(context.t('fmset.thumbnails')),
            subtitle: Text(context.t('fmset.thumbnails_sub')),
            value: appState.fmThumbnails,
            onChanged: appState.setFmThumbnails,
          ),
          ListTile(
            leading: const Icon(Icons.sort),
            title: Text(context.t('fmset.default_sort')),
            subtitle: Text('${context.t(appState.fmSort.labelKey)} · '
                '${context.t(appState.fmSortDesc ? 'fmset.desc' : 'fmset.asc')}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'dir') {
                  appState.setFmSort(appState.fmSort,
                      descending: !appState.fmSortDesc);
                } else {
                  appState
                      .setFmSort(FmSort.values.firstWhere((s) => s.name == v));
                }
              },
              itemBuilder: (_) => [
                for (final s in FmSort.values)
                  PopupMenuItem(value: s.name, child: Text(context.t(s.labelKey))),
                const PopupMenuDivider(),
                PopupMenuItem(
                    value: 'dir', child: Text(context.t('fmset.reverse_dir'))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: Text(context.t('fmset.group_photos')),
            subtitle: Text(context.t('fmset.group_photos_sub',
                {'unit': context.t(appState.fmPhotoGroup.labelKey)})),
            trailing: PopupMenuButton<PhotoGroup>(
              onSelected: appState.setFmPhotoGroup,
              itemBuilder: (_) => [
                for (final g in PhotoGroup.values)
                  PopupMenuItem(value: g, child: Text(context.t(g.labelKey))),
              ],
            ),
          ),
          _section(context.t('fmset.sec_open')),
          ListTile(
            leading: const Icon(Icons.play_circle_outline),
            title: Text(context.t('fmset.media_open_with')),
            subtitle: Text('${context.t(appState.fmMediaOpenWith.labelKey)} · '
                '${context.t(appState.fmMediaOpenWith.descriptionKey)}'),
            trailing: PopupMenuButton<MediaOpenWith>(
              onSelected: appState.setFmMediaOpenWith,
              itemBuilder: (_) => [
                for (final v in MediaOpenWith.values)
                  PopupMenuItem(value: v, child: Text(context.t(v.labelKey))),
              ],
            ),
          ),
          _section(context.t('fmset.sec_search')),
          ListTile(
            leading: const Icon(Icons.manage_search),
            title: Text(context.t('fmset.index')),
            subtitle: Text(_indexSubtitle()),
            trailing: FilledButton.tonal(
              onPressed: _rebuildIndex,
              child: Text(context.t('common.refresh')),
            ),
          ),
          _section(context.t('fmset.sec_privacy')),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(context
                .t(appState.fmHasLockPin ? 'fmset.pin_change' : 'fmset.pin_set')),
            subtitle: Text(appState.fmHasLockPin
                ? context.t('fmset.pin_sub_locked',
                    {'n': appState.fmLockedFolders.length})
                : context.t('fmset.pin_sub_unset')),
            isThreeLine: true,
            onTap: () => setupPin(context),
          ),
          if (appState.fmHasLockPin)
            ListTile(
              leading: const Icon(Icons.lock_open),
              title: Text(context.t('fmset.pin_remove')),
              subtitle: Text(context.t('fmset.pin_remove_sub')),
              onTap: () async {
                if (!await askPin(context)) return;
                if (!context.mounted) return;
                await context.read<AppState>().setFmLockPin('');
              },
            ),
          if (appState.fmLockedFolders.isNotEmpty)
            for (final path in appState.fmLockedFolders)
              ListTile(
                dense: true,
                leading: const Icon(Icons.folder_off_outlined),
                title: Text(p.basename(path)),
                subtitle:
                    Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  tooltip: context.t('fmset.unlock'),
                  icon: const Icon(Icons.lock_open),
                  onPressed: () async {
                    if (!await askPin(context)) return;
                    if (!context.mounted) return;
                    await context.read<AppState>().toggleLockedFolder(path);
                  },
                ),
              ),
          _section(context.t('fmset.sec_delete')),
          SwitchListTile(
            secondary: const Icon(Icons.delete_outline),
            title: Text(context.t('fmset.use_trash')),
            subtitle: Text(context.t('fmset.use_trash_sub')),
            value: appState.fmUseTrash,
            onChanged: appState.setFmUseTrash,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.help_outline),
            title: Text(context.t('fmset.confirm_delete')),
            value: appState.fmConfirmDelete,
            onChanged: appState.setFmConfirmDelete,
          ),
          ListTile(
            leading: const Icon(Icons.auto_delete_outlined),
            title: Text(context.t('fmset.trash_auto')),
            subtitle: Text(appState.fmTrashAutoDays == 0
                ? context.t('fmset.trash_auto_off')
                : context.t(
                    'fmset.trash_auto_on', {'n': appState.fmTrashAutoDays})),
            trailing: PopupMenuButton<int>(
              onSelected: appState.setFmTrashAutoDays,
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(context.t('fmset.off'))),
                for (final d in const [7, 30, 90])
                  PopupMenuItem(
                      value: d, child: Text(context.t('fmset.days', {'n': d}))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.delete_sweep_outlined),
            title: Text(context.t('fmset.empty_trash_now')),
            subtitle: Text(_trashCount == 0
                ? context.t('fmset.trash_empty')
                : context.t('fmset.trash_summary', {
                    'n': _trashCount,
                    'size': FsPaths.humanSize(_trashBytes),
                  })),
            onTap: _trashCount == 0 ? null : _emptyTrash,
          ),
          _section(context.t('fmset.sec_permissions')),
          ListTile(
            leading: Icon(_fullAccess ? Icons.lock_open : Icons.lock_outline),
            title: Text(context.t('fmset.full_access')),
            subtitle: Text(context.t(_fullAccess
                ? 'fmset.full_access_on'
                : 'fmset.full_access_off')),
            trailing: _fullAccess
                ? null
                : FilledButton.tonal(
                    onPressed: () async {
                      await StoragePermission.request();
                      await FmEnv.ensureInit(force: true);
                      await _refresh();
                    },
                    child: Text(context.t('fmset.grant')),
                  ),
          ),
          ListTile(
            leading: const Icon(Icons.query_stats),
            title: Text(context.t('fmset.usage_access')),
            subtitle: Text(context.t(_usageAccess
                ? 'fmset.usage_access_on'
                : 'fmset.usage_access_off')),
            trailing: _usageAccess
                ? null
                : FilledButton.tonal(
                    onPressed: () async {
                      await InstalledAppsService.requestUsagePermission();
                      await _refresh();
                    },
                    child: Text(context.t('fmset.grant')),
                  ),
          ),
          _section(context.t('fmset.sec_maintenance')),
          ListTile(
            leading: const Icon(Icons.cleaning_services_outlined),
            title: Text(context.t('fmset.clear_thumbs')),
            subtitle: Text(context.t('fmset.clear_thumbs_sub')),
            onTap: _clearThumbs,
          ),
          ListTile(
            leading: const Icon(Icons.storage),
            title: Text(context.t('fmset.volumes')),
            subtitle: Text(FmEnv.volumes.isEmpty
                ? context.t('fmset.volumes_none')
                : FmEnv.volumes.map((v) => v.label).join(' · ')),
            onTap: () async {
              await FmEnv.ensureInit(force: true);
              await _refresh();
            },
          ),
          _section(context.t('fmset.sec_app')),
          ListTile(
            leading: const Icon(Icons.settings_outlined),
            title: Text(context.t('fmset.general')),
            subtitle: Text(context.t('fmset.general_sub')),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.lg, Gap.md, Gap.xs),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w700,
              ),
        ),
      );
}

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../services/fm/storage_permission.dart';
import '../../widgets/fm/pin_dialog.dart';
import 'settings_widgets.dart';

/// Klasör kilidi PIN'i: kurma / değiştirme / kaldırma.
class PinTile extends StatelessWidget {
  const PinTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return Column(
      children: [
        SettingTile(
          icon: Icons.lock_outline,
          title: context
              .t(appState.fmHasLockPin ? 'fmset.pin_change' : 'fmset.pin_set'),
          subtitle: appState.fmHasLockPin
              ? context.t('fmset.pin_sub_locked',
                  {'n': appState.fmLockedFolders.length})
              : context.t('fmset.pin_sub_unset'),
          wrapSubtitle: true,
          onTap: () => setupPin(context),
        ),
        if (appState.fmHasLockPin)
          SettingTile(
            icon: Icons.lock_open,
            title: context.t('fmset.pin_remove'),
            subtitle: context.t('fmset.pin_remove_sub'),
            onTap: () async {
              if (!await askPin(context)) return;
              if (!context.mounted) return;
              await context.read<AppState>().setFmLockPin('');
            },
          ),
      ],
    );
  }
}

/// Kilitli klasörlerin listesi (boşsa hiç çizilmez).
class LockedFoldersTile extends StatelessWidget {
  const LockedFoldersTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    if (appState.fmLockedFolders.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final path in appState.fmLockedFolders)
          ListTile(
            dense: true,
            leading: const Icon(Icons.folder_off_outlined),
            title: Text(p.basename(path)),
            subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
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
      ],
    );
  }
}

/// Tüm dosyalara erişim izni (Android "Tüm dosyaları yönet").
class FullAccessTile extends StatefulWidget {
  const FullAccessTile({super.key});

  @override
  State<FullAccessTile> createState() => _FullAccessTileState();
}

class _FullAccessTileState extends State<FullAccessTile> {
  bool _granted = true;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final access = await StoragePermission.hasFullAccess();
    if (mounted) setState(() => _granted = access);
  }

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: _granted ? Icons.lock_open : Icons.lock_outline,
        title: context.t('fmset.full_access'),
        subtitle: context
            .t(_granted ? 'fmset.full_access_on' : 'fmset.full_access_off'),
        wrapSubtitle: true,
        trailing: _granted
            ? null
            : FilledButton.tonal(
                onPressed: () async {
                  await StoragePermission.request();
                  await FmEnv.ensureInit(force: true);
                  await _refresh();
                },
                child: Text(context.t('fmset.grant')),
              ),
      );
}

/// Kullanım erişimi (kurulu uygulamaların son kullanım zamanı).
class UsageAccessTile extends StatefulWidget {
  const UsageAccessTile({super.key});

  @override
  State<UsageAccessTile> createState() => _UsageAccessTileState();
}

class _UsageAccessTileState extends State<UsageAccessTile> {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final usage = await InstalledAppsService.hasUsagePermission();
    if (mounted) setState(() => _granted = usage);
  }

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.query_stats,
        title: context.t('fmset.usage_access'),
        subtitle: context
            .t(_granted ? 'fmset.usage_access_on' : 'fmset.usage_access_off'),
        wrapSubtitle: true,
        trailing: _granted
            ? null
            : FilledButton.tonal(
                onPressed: () async {
                  await InstalledAppsService.requestUsagePermission();
                  await _refresh();
                },
                child: Text(context.t('fmset.grant')),
              ),
      );
}

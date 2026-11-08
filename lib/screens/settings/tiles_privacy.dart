import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../widgets/ai_send_consent.dart';
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
          icon: AppIcons.lock,
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
            icon: AppIcons.unlock,
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

/// **Uygulama kilidi** — açılışta PIN sorar (2026-09-06 denetim turu).
///
/// Klasör kilidinin PIN'iyle aynı: iki ayrı PIN ezberletmek yerine tek bir
/// sayı. PIN kurulu değilse anahtar açılamaz ve altındaki satır bunu SÖYLER —
/// sessizce kapalı kalan bir anahtar "bozuk" görünürdü.
class AppLockTile extends StatelessWidget {
  const AppLockTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SwitchListTile(
      secondary: const Icon(AppIcons.phonelinkLock),
      title: Text(context.t('lock.app_title')),
      subtitle: Text(
        !appState.fmHasLockPin
            ? context.t('lock.app_needs_pin')
            : context.t(
                appState.appLock ? 'lock.app_sub_on' : 'lock.app_sub_off'),
      ),
      value: appState.appLock,
      onChanged: !appState.fmHasLockPin
          ? null
          : (value) async {
              // Kilidi KAPATIRKEN de PIN sorulur: telefonu eline alan biri
              // ayarlardan tek dokunuşla kapatabilseydi kilit anlamsız olurdu.
              if (!value && !await askPin(context)) return;
              if (!context.mounted) return;
              await context.read<AppState>().setAppLock(value);
            },
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
            leading: const Icon(AppIcons.folderOff),
            title: Text(p.basename(path)),
            subtitle: Text(path, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: IconButton(
              tooltip: context.t('fmset.unlock'),
              icon: const Icon(AppIcons.unlock),
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

/// **Çevrimdışı kip** — açıkken uygulama internete çıkmaz (`OfflineMode`).
class OfflineModeTile extends StatelessWidget {
  const OfflineModeTile({super.key});

  @override
  Widget build(BuildContext context) {
    final on = context.select<AppState, bool>((s) => s.offlineMode);
    return SwitchListTile(
      key: const ValueKey('offline-mode'),
      secondary: Icon(on ? AppIcons.cloudOff : AppIcons.cloud),
      title: Text(context.t('offline.title')),
      subtitle: Text(context.t(on ? 'offline.on' : 'offline.sub')),
      isThreeLine: true,
      value: on,
      onChanged: (v) => context.read<AppState>().setOfflineMode(v),
    );
  }
}

/// AI'ya dosya metni göndermeden önce sorulsun mu ("hatırla" geri alınır).
class AiSendAskTile extends StatelessWidget {
  const AiSendAskTile({super.key});

  @override
  Widget build(BuildContext context) {
    final ask = !context.select<AppState, bool>((s) => s.aiSendConsent);
    return SwitchListTile(
      secondary: const Icon(AppIcons.ai),
      title: Text(context.t('aisend.setting')),
      subtitle: Text(context.t('aisend.setting_sub')),
      value: ask,
      onChanged: (v) {
        if (v) AiSendConsent.forget();
        context.read<AppState>().setAiSendConsent(!v);
      },
    );
  }
}

/// **Eklenen klasörler** (SAF ağaç izinleri) — her biri "Geri al" ile
/// bırakılır; Android kalıcı izni de geri verilir.
class SafFoldersTile extends StatefulWidget {
  const SafFoldersTile({super.key});

  @override
  State<SafFoldersTile> createState() => _SafFoldersTileState();
}

class _SafFoldersTileState extends State<SafFoldersTile> {
  List<SafRoot>? _roots;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final roots = await AppStorageService.safRoots();
    if (mounted) setState(() => _roots = roots);
  }

  @override
  Widget build(BuildContext context) {
    final roots = _roots ?? const <SafRoot>[];
    return Column(
      children: [
        SettingTile(
          icon: AppIcons.folderSpecial,
          title: context.t('saf.folders_title'),
          subtitle: context.t(
              roots.isEmpty ? 'saf.folders_none' : 'saf.folders_sub'),
          wrapSubtitle: true,
        ),
        for (final r in roots)
          ListTile(
            dense: true,
            leading: const Icon(AppIcons.folder),
            title: Text(r.name),
            trailing: TextButton(
              onPressed: () async {
                await AppStorageService.safForget(r.uri);
                await _refresh();
              },
              child: Text(context.t('perm.revoke')),
            ),
          ),
      ],
    );
  }
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
        icon: AppIcons.queryStats,
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

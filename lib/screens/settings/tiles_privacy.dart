import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/state/focused_states.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/pii.dart';
import '../../core/snack.dart';
import '../../services/fm/app_storage_service.dart';
import '../../services/fm/installed_apps_service.dart';
import '../../core/edition.dart';
import '../../services/privacy_wipe.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/ai_send_consent.dart';
import '../../widgets/fm/pin_dialog.dart';
import 'settings_widgets.dart';

/// Klasör kilidi PIN'i: kurma / değiştirme / kaldırma.
class PinTile extends StatelessWidget {
  const PinTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watchBrowse();
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
    final appState = context.watchBrowse();
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
    context.dependOnAi();
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

/// **Kişisel veri maskesi** (G10.2): AI'ya giden metinde TC/IBAN/kart/
/// telefon/e-posta yer tutucuyla gider. Varsayılan açık.
class PiiMaskTile extends StatefulWidget {
  const PiiMaskTile({super.key});

  @override
  State<PiiMaskTile> createState() => _PiiMaskTileState();
}

class _PiiMaskTileState extends State<PiiMaskTile> {
  bool _on = true;

  @override
  void initState() {
    super.initState();
    PiiMaskSetting.enabled().then((v) {
      if (mounted) setState(() => _on = v);
    });
  }

  @override
  Widget build(BuildContext context) => SwitchListTile(
        key: const ValueKey('pii-mask'),
        secondary: const Icon(AppIcons.lock),
        title: Text(context.t('pii.setting')),
        subtitle: Text(context.t('pii.setting_sub')),
        isThreeLine: true,
        value: _on,
        onChanged: (v) async {
          setState(() => _on = v);
          await PiiMaskSetting.set(v);
        },
      );
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
  Widget build(BuildContext context) => !Edition.current.has(Feature.installedApps)
      ? const SizedBox.shrink()
      : SettingTile(
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

/// **Verilerimi sil** (G10.5): uygulamanın dosyalar hakkında tuttuğu kayıtlar
/// (geçmiş, AI, arama dizinleri, hata kayıtları) tek yerden silinir.
/// Dosyalara, kayıtlı bağlantılara, anahtarlara ve kasaya dokunulmaz.
class PrivacyWipeTile extends StatelessWidget {
  const PrivacyWipeTile({super.key});

  static const _labels = {
    WipeCategory.history: 'wipe.history',
    WipeCategory.ai: 'wipe.ai',
    WipeCategory.indexes: 'wipe.indexes',
    WipeCategory.logs: 'wipe.logs',
  };

  Future<void> _run(BuildContext context) async {
    final str = AppStrings.of(context);
    final app = context.read<AppState>();
    final sel = {...WipeCategory.values};
    final picked = await showAppSheet<Set<WipeCategory>>(
      context,
      title: str.t('wipe.title'),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(ctx.t('wipe.note')),
              ),
              for (final c in WipeCategory.values)
                CheckboxListTile(
                  key: ValueKey('wipe-${c.name}'),
                  value: sel.contains(c),
                  title: Text(ctx.t(_labels[c]!)),
                  onChanged: (v) => setState(() {
                    if (v == true) {
                      sel.add(c);
                    } else {
                      sel.remove(c);
                    }
                  }),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: FilledButton(
                  key: const ValueKey('wipe-go'),
                  onPressed: sel.isEmpty
                      ? null
                      : () => Navigator.pop(ctx, {...sel}),
                  child: Text(ctx.t('wipe.go')),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null || picked.isEmpty || !context.mounted) return;
    final ok = await showAppConfirm(context,
        title: str.t('wipe.title'),
        message: str.t('wipe.confirm'),
        confirmLabel: str.t('wipe.go'),
        destructive: true);
    if (!ok || !context.mounted) return;
    final failed =
        await PrivacyWipe.run(picked, clearAppLists: app.clearRecentsAndMemory);
    if (!context.mounted) return;
    showSnack(context,
        failed == 0 ? str.t('wipe.done') : str.t('wipe.partial', {'n': failed}));
  }

  @override
  Widget build(BuildContext context) => ListTile(
        key: const ValueKey('privacy-wipe'),
        leading: const Icon(AppIcons.deleteSweep),
        title: Text(context.t('wipe.title')),
        subtitle: Text(context.t('wipe.sub')),
        onTap: () => _run(context),
      );
}

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../../core/app_icons.dart';
import '../../../core/l10n/app_strings.dart';
import '../../../core/theme.dart';
import '../../../services/fm/fm_env.dart';
import '../../../services/fm/remote/auto_sync.dart';
import '../../../services/fm/remote/trusted_peers.dart';
import '../../../widgets/app_dialog.dart';
import '../folder_picker_screen.dart';

/// Bir cihaz için **otomatik klasör eşitleme** ayarı ([AutoSync]).
/// Açınca cihaz anahtarıyla güvenilenlere eklenir (eşitleme yalnız anahtarı
/// kanıtlayan eşe, yalnız şifreli gider).
Future<void> showAutoSyncSheet(BuildContext context,
    {required String fp, required String name, String id = ''}) async {
  await AutoSync.instance.ensureLoaded();
  if (!context.mounted) return;
  await showAppSheet<void>(
    context,
    title: context.t('sync.title', {'name': name}),
    builder: (_) => _AutoSyncBody(fp: fp, name: name, id: id),
  );
}

class _AutoSyncBody extends StatelessWidget {
  final String fp, name, id;
  const _AutoSyncBody({required this.fp, required this.name, required this.id});

  static String defaultCamera() {
    final cam = p.join(FmEnv.primaryRoot, 'DCIM', 'Camera');
    return Directory(cam).existsSync() ? cam : p.join(FmEnv.primaryRoot, 'DCIM');
  }

  Future<void> _addFolder(BuildContext context, SyncRule? r) async {
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        actionLabel: context.t('sync.pick'),
        startPath: defaultCamera(),
      ),
    ));
    if (dest == null) return;
    final list = [...?r?.folders];
    if (!list.contains(dest)) list.add(dest);
    await AutoSync.instance.set(fp, name, folders: list);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: AutoSync.instance,
      builder: (context, _) {
        final r = AutoSync.instance.rule(fp);
        final on = r?.on ?? false;
        final folders = r?.folders ?? const <String>[];
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(context.t('sync.explain'), style: theme.textTheme.bodySmall),
              SwitchListTile(
                key: const ValueKey('sync-on'),
                contentPadding: EdgeInsets.zero,
                value: on,
                title: Text(context.t('sync.on')),
                onChanged: (v) async {
                  if (v) {
                    await TrustedPeers.instance.add(name, id, fp);
                    if (folders.isEmpty) {
                      await AutoSync.instance
                          .set(fp, name, folders: [defaultCamera()]);
                    }
                  }
                  await AutoSync.instance.set(fp, name, on: v);
                },
              ),
              for (final f in folders)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(AppIcons.folder),
                  title: Text(p.basename(f)),
                  subtitle: Text(f, maxLines: 1, overflow: TextOverflow.ellipsis),
                  trailing: IconButton(
                    tooltip: context.t('sync.remove'),
                    icon: const Icon(AppIcons.close),
                    onPressed: () => unawaited(AutoSync.instance.set(fp, name,
                        folders: [for (final x in folders) if (x != f) x])),
                  ),
                ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  key: const ValueKey('sync-add'),
                  onPressed: () => unawaited(_addFolder(context, r)),
                  icon: const Icon(AppIcons.addFolder),
                  label: Text(context.t('sync.add')),
                ),
              ),
              if (on)
                Text(context.t('sync.when'),
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            ],
          ),
        );
      },
    );
  }
}

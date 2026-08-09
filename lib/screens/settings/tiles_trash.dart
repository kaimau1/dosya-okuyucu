import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_scan.dart';
import '../../widgets/fm/fm_progress_dialog.dart';
import 'settings_widgets.dart';

/// Silinen dosya çöp kutusuna mı gitsin?
class UseTrashTile extends StatelessWidget {
  const UseTrashTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.delete_outline,
      title: context.t('fmset.use_trash'),
      subtitle: context.t('fmset.use_trash_sub'),
      value: appState.fmUseTrash,
      onChanged: appState.setFmUseTrash,
    );
  }
}

/// Silmeden önce onay sorulsun mu?
class ConfirmDeleteTile extends StatelessWidget {
  const ConfirmDeleteTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    return SettingSwitch(
      icon: Icons.help_outline,
      title: context.t('fmset.confirm_delete'),
      value: appState.fmConfirmDelete,
      onChanged: appState.setFmConfirmDelete,
    );
  }
}

/// Çöp kutusunun kendi kendine boşalma süresi.
class TrashAutoTile extends StatelessWidget {
  const TrashAutoTile({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();
    final off = appState.fmTrashAutoDays == 0;
    return SettingTile(
      icon: Icons.auto_delete_outlined,
      title: context.t('fmset.trash_auto'),
      subtitle: off
          ? context.t('fmset.trash_auto_off')
          : context.t('fmset.trash_auto_on', {'n': appState.fmTrashAutoDays}),
      value: off
          ? context.t('fmset.off')
          : context.t('fmset.days', {'n': appState.fmTrashAutoDays}),
      trailing: PopupMenuButton<int>(
        icon: const Icon(Icons.arrow_drop_down),
        onSelected: appState.setFmTrashAutoDays,
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 0, child: Text(ctx.t('fmset.off'))),
          for (final d in const [7, 30, 90])
            PopupMenuItem(value: d, child: Text(ctx.t('fmset.days', {'n': d}))),
        ],
      ),
    );
  }
}

/// Çöp kutusunu şimdi boşalt — **ilerleme penceresiyle**.
///
/// Sessiz silme kullanıcı bulgusuydu (2026-07-25): binlerce dosya silinirken
/// ekranda hiçbir şey olmuyor, uygulama donmuş sanılıyordu.
class EmptyTrashTile extends StatefulWidget {
  const EmptyTrashTile({super.key});

  @override
  State<EmptyTrashTile> createState() => _EmptyTrashTileState();
}

class _EmptyTrashTileState extends State<EmptyTrashTile> {
  int _count = 0;
  int _bytes = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    await FmEnv.ensureInit();
    final items = await FmEnv.trash.list();
    if (!mounted) return;
    setState(() {
      _count = items.length;
      _bytes = items.fold<int>(0, (s, i) => s + i.sizeBytes);
    });
  }

  Future<void> _empty() async {
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(str.t('fmset.empty_confirm_title')),
        content: Text(str.t('fmset.empty_confirm_body',
            {'n': _count, 'size': FsPaths.humanSize(_bytes)})),
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
    final freed = _bytes;
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

  @override
  Widget build(BuildContext context) => SettingTile(
        icon: Icons.delete_sweep_outlined,
        title: context.t('fmset.empty_trash_now'),
        subtitle: _count == 0
            ? context.t('fmset.trash_empty')
            : context.t('fmset.trash_summary',
                {'n': _count, 'size': FsPaths.humanSize(_bytes)}),
        onTap: _count == 0 ? null : _empty,
      );
}

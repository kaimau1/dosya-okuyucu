import 'dart:io';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/hidden_vault.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/pin_dialog.dart';
import 'entry_actions.dart';

/// **Gizli dosyalar** — [HiddenVault]'taki öğeler (2026-09-27).
///
/// Klasör kilidi PIN'i ayarlıysa ekran önce onu sorar (aynı PIN: kullanıcı
/// ikinci bir parola ezberlemesin).
class HiddenFilesScreen extends StatefulWidget {
  const HiddenFilesScreen({super.key});

  /// PIN (varsa) sorulduktan sonra açar.
  static Future<void> open(BuildContext context) async {
    final state = context.read<AppState>();
    if (state.fmHasLockPin) {
      final ok = await askPin(context, title: context.t('hv.title'));
      if (!ok || !context.mounted) return;
    }
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const HiddenFilesScreen()));
  }

  @override
  State<HiddenFilesScreen> createState() => _HiddenFilesScreenState();
}

class _HiddenFilesScreenState extends State<HiddenFilesScreen> {
  List<HiddenItem>? _items;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final items = await HiddenVault.list();
    if (mounted) setState(() => _items = items);
  }

  Future<void> _restore(List<HiddenItem> items) async {
    final messenger = ScaffoldMessenger.of(context);
    final strings = AppStrings.of(context);
    final n = await HiddenVault.restore(items);
    showSnackOn(messenger, strings.t('hv.restored_n', {'n': n}));
    await _load();
  }

  Future<void> _delete(HiddenItem item) async {
    final entry =
        FsEntry.fromEntity(item.isDir ? Directory(item.path) : File(item.path));
    if (await deleteEntries(context, [entry])) {
      await HiddenVault.forget([item]);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = _items;
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('hv.title')),
        actions: [
          if (items != null && items.isNotEmpty)
            TextButton.icon(
              onPressed: () => _restore(items),
              icon: const Icon(Icons.restore_rounded),
              label: Text(context.t('hv.restore')),
            ),
        ],
      ),
      body: items == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: Gap.xl),
              children: [
                Padding(
                  padding: const EdgeInsets.all(Gap.md),
                  child: Material(
                    color: scheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.md),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.visibility_off_outlined,
                              color: scheme.onSecondaryContainer),
                          const SizedBox(width: Gap.sm),
                          Expanded(
                            child: Text(context.t('hv.note'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                        color: scheme.onSecondaryContainer)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(Gap.xl),
                    child: Text(context.t('hv.empty'),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: scheme.onSurfaceVariant)),
                  ),
                for (final item in items)
                  ListTile(
                    leading: SizedBox(
                      width: 44,
                      height: 44,
                      child: FmEntryIcon(
                        entry: FsEntry.fromEntity(item.isDir
                            ? Directory(item.path)
                            : File(item.path)),
                        size: 44,
                      ),
                    ),
                    title: Text(item.name,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      context.t(
                          'hv.from', {'path': File(item.original).parent.path}),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () => item.isDir
                        ? null
                        : EntryOpener.open(context, item.path),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: context.t('hv.restore'),
                          icon: const Icon(Icons.restore_rounded),
                          onPressed: () => _restore([item]),
                        ),
                        IconButton(
                          tooltip: context.t('common.delete'),
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                          onPressed: () => _delete(item),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
    );
  }
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../core/theme.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_ops.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/job_queue.dart';
import '../../widgets/app_dialog.dart';
import 'folder_picker_screen.dart';

/// **İş sonucu ayrıntısı** — bir işin dosya dosya ne yaptığı (ya da önerdiği).
///
/// Kullanıcı isteği 2026-10-30: *"üzerine basınca ne yapıldığını gösteren,
/// tek tek hangi resimler/dosyalar neye etiketlendi gösteren, geri alınabilen,
/// silinebilen, düzenlenebilen (etiket adları vs.), taşıma yapılabilen bir
/// sayfa açılmalı — tüm bu tür işlerde"*.
///
/// Değişiklikler [FmJob.changes]'ten okunur ve **(tür, değer)** başına
/// gruplanır: etikette "#Fatura · 12 dosya". Etiket grubunda: uygula / geri
/// al, yeniden adlandır, kaldır, dosyaları klasöre taşı; dosya satırında: aç,
/// yalnız bu dosyadan kaldır. Tanınmayan türler (ileride eklenecek işler)
/// yalnız listelenir ve açılabilir — sayfa her işte açılır.
class JobReportScreen extends StatefulWidget {
  final FmJob job;
  const JobReportScreen({super.key, required this.job});

  @override
  State<JobReportScreen> createState() => _JobReportScreenState();
}

class _JobReportScreenState extends State<JobReportScreen> {
  FmJob get _job => widget.job;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  /// (tür, değer) → değişiklikler; en kalabalık grup üstte.
  List<MapEntry<(String, String), List<JobChange>>> get _groups {
    final map = <(String, String), List<JobChange>>{};
    for (final c in _job.changes) {
      (map[(c.kind, c.value)] ??= []).add(c);
    }
    return map.entries.toList()
      ..sort((a, b) => b.value.length.compareTo(a.value.length));
  }

  void _saved() {
    JobQueue.instance.touch(_job);
    if (mounted) setState(() {});
  }

  Future<void> _guard(Future<void> Function() body) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await body();
    } finally {
      if (mounted) setState(() => _busy = false);
      _saved();
    }
  }

  // ── Etiket eylemleri ──────────────────────────────────────────────────────

  Future<void> _applyTag(List<JobChange> list, bool on) => _guard(() async {
        final byTag = <String, List<JobChange>>{};
        for (final c in list) {
          if (c.kind == 'tag' && c.applied != on) {
            (byTag[c.value] ??= []).add(c);
          }
        }
        for (final e in byTag.entries) {
          final paths = [for (final c in e.value) c.path];
          if (on) {
            await FileTags.add(paths, e.key);
          } else {
            await FileTags.remove(paths, e.key);
          }
          for (final c in e.value) {
            c.applied = on;
          }
        }
      });

  Future<void> _renameTag(String from, List<JobChange> list) async {
    final to = await showAppPrompt(context,
        title: context.t('jr.rename_tag'), initial: from);
    if (to == null || to.isEmpty || to == from || !mounted) return;
    await _guard(() async {
      final paths = [for (final c in list) if (c.applied) c.path];
      // Yalnız BU işin dosyalarındaki etiket değişir; aynı adlı etiketin
      // başka dosyalardaki kullanımı olduğu gibi kalır.
      if (paths.isNotEmpty) {
        await FileTags.remove(paths, from);
        await FileTags.add(paths, to);
      }
      for (final c in list) {
        c.value = to;
      }
    });
  }

  Future<void> _removeGroup(String tag, List<JobChange> list) async {
    final ok = await showAppConfirm(context,
        title: context.t('jr.remove_tag'),
        message: context.t('jr.remove_tag_body', {'tag': tag, 'n': list.length}),
        confirmLabel: context.t('common.delete'),
        destructive: true);
    if (!ok) return;
    await _guard(() async {
      final paths = [for (final c in list) if (c.applied) c.path];
      if (paths.isNotEmpty) await FileTags.remove(paths, tag);
      _job.changes.removeWhere(list.contains);
    });
  }

  Future<void> _removeOne(JobChange c) => _guard(() async {
        if (c.kind == 'tag' && c.applied) {
          await FileTags.remove([c.path], c.value);
        }
        _job.changes.remove(c);
      });

  /// Grubun dosyalarını bir klasöre taşır; etiketler ve kayıttaki yollar
  /// yeni yere göre güncellenir.
  Future<void> _moveGroup(List<JobChange> list) async {
    final paths = {
      for (final c in list)
        if (File(c.path).existsSync()) c.path
    }.toList();
    if (paths.isEmpty) {
      showSnack(context, context.t('jr.nothing_to_move'));
      return;
    }
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
          sources: paths, actionLabel: context.t('fm.move_here')),
    ));
    if (dest == null || !mounted) return;
    final str = AppStrings.of(context);
    await _guard(() async {
      final result = await FileOps.moveAll(paths, dest);
      for (final t in result.transfers) {
        await FileTags.movePath(t.source, t.dest);
        for (final c in _job.changes) {
          if (c.path == t.source) c.path = t.dest;
        }
      }
      if (mounted) {
        showSnack(context, str.t('jr.moved', {'n': result.succeeded}));
      }
    });
  }

  // ── Arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final groups = _groups;
    final changes = _job.changes;
    final applied = changes.where((c) => c.applied).length;
    final pending = changes.length - applied;
    final files = {for (final c in changes) c.path}.length;
    final hasTags = changes.any((c) => c.kind == 'tag');
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_job.shownTitle, overflow: TextOverflow.ellipsis),
        bottom: _busy
            ? const PreferredSize(
                preferredSize: Size.fromHeight(3),
                child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: changes.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(context.t('jr.empty'), textAlign: TextAlign.center),
              ),
            )
          : ListView(
              padding: const EdgeInsets.only(bottom: Gap.lg),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      Gap.md, Gap.md, Gap.md, Gap.sm),
                  child: Text(
                    context.t('jr.summary', {
                      'groups': groups.length,
                      'files': files,
                      'applied': applied,
                      'pending': pending,
                    }),
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
                if (hasTags)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                    child: Wrap(
                      spacing: Gap.sm,
                      children: [
                        if (pending > 0)
                          FilledButton.icon(
                            key: const ValueKey('jr-apply-all'),
                            onPressed: _busy
                                ? null
                                : () => _applyTag(changes, true),
                            icon: const Icon(AppIcons.check, size: 18),
                            label: Text(
                                context.t('jr.apply_all', {'n': pending})),
                          ),
                        if (applied > 0)
                          OutlinedButton.icon(
                            key: const ValueKey('jr-undo-all'),
                            onPressed: _busy
                                ? null
                                : () => _applyTag(changes, false),
                            icon: const Icon(AppIcons.undo, size: 18),
                            label: Text(context.t('jr.undo_all')),
                          ),
                      ],
                    ),
                  ),
                for (final g in groups) _group(context, g.key, g.value),
              ],
            ),
    );
  }

  Widget _group(
      BuildContext context, (String, String) key, List<JobChange> list) {
    final (kind, value) = key;
    final isTag = kind == 'tag';
    final applied = list.where((c) => c.applied).length;
    final scheme = Theme.of(context).colorScheme;
    return ExpansionTile(
      key: ValueKey('jr-group-$kind-$value'),
      leading: Icon(isTag ? AppIcons.labelOutline : AppIcons.edit,
          color: applied > 0 ? scheme.primary : scheme.onSurfaceVariant),
      title: Text(isTag ? '#$value' : value),
      subtitle: Text(context.t(
          applied == list.length
              ? 'jr.group_applied'
              : applied == 0
                  ? 'jr.group_pending'
                  : 'jr.group_partial',
          {'n': list.length, 'applied': applied})),
      trailing: PopupMenuButton<String>(
        key: ValueKey('jr-menu-$value'),
        enabled: !_busy,
        onSelected: (a) {
          switch (a) {
            case 'apply':
              _applyTag(list, true);
            case 'undo':
              _applyTag(list, false);
            case 'rename':
              _renameTag(value, list);
            case 'remove':
              _removeGroup(value, list);
            case 'move':
              _moveGroup(list);
          }
        },
        itemBuilder: (ctx) => [
          if (isTag && applied < list.length)
            PopupMenuItem(value: 'apply', child: Text(ctx.t('jr.apply'))),
          if (isTag && applied > 0)
            PopupMenuItem(value: 'undo', child: Text(ctx.t('common.undo'))),
          if (isTag)
            PopupMenuItem(value: 'rename', child: Text(ctx.t('jr.rename_tag'))),
          if (isTag)
            PopupMenuItem(value: 'remove', child: Text(ctx.t('jr.remove_tag'))),
          PopupMenuItem(value: 'move', child: Text(ctx.t('jr.move_files'))),
        ],
      ),
      children: [
        for (final c in list) _fileRow(context, c, list),
      ],
    );
  }

  Widget _fileRow(BuildContext context, JobChange c, List<JobChange> group) {
    final exists = File(c.path).existsSync();
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsetsDirectional.only(start: 56, end: 8),
      leading: Icon(c.applied ? AppIcons.checkCircle : AppIcons.ai,
          size: 18, color: c.applied ? scheme.primary : scheme.outline),
      title: Text(p.basename(c.path),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
          exists ? p.dirname(c.path) : context.t('jr.missing'),
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      onTap: exists
          ? () => EntryOpener.open(context, c.path,
              siblings: [for (final g in group) g.path])
          : null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (c.kind == 'tag' && !c.applied)
            IconButton(
              tooltip: context.t('jr.apply'),
              icon: const Icon(AppIcons.check),
              onPressed: _busy ? null : () => _applyTag([c], true),
            ),
          IconButton(
            tooltip: context.t('jr.remove_one'),
            icon: const Icon(AppIcons.close),
            onPressed: _busy ? null : () => _removeOne(c),
          ),
        ],
      ),
    );
  }
}

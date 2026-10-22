import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_icons.dart';
import '../../core/app_state.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../services/fm/ai_buckets.dart';
import '../../services/fm/ai_index.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/smart_folders.dart';
import '../../widgets/fm/ai_preview_card.dart';
import '../../widgets/fm/fm_entry_icon.dart';

/// **Akıllı klasörler listesi** — her biri kayıtlı bir AI araması (bkz.
/// [SmartFolders]). Satırda klasörün o anki dosya sayısı, yeni gelen sayısı ve
/// ilk üç dosyanın küçük resmi.
class SmartFoldersScreen extends StatefulWidget {
  const SmartFoldersScreen({super.key});

  @override
  State<SmartFoldersScreen> createState() => _SmartFoldersScreenState();
}

class _SmartFoldersScreenState extends State<SmartFoldersScreen> {
  @override
  void initState() {
    super.initState();
    SmartFolders.instance.ensureLoaded();
    AiIndex.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
  }

  Future<void> _create() async {
    final query = await _askText(context,
        title: context.t('smart.create'), hint: context.t('smart.query_hint'));
    if (query == null || query.trim().isEmpty || !mounted) return;
    final folder = await SmartFolders.instance.add(query);
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SmartFolderScreen(folderId: folder.id)));
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<AppState>().aiScopeRules;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('smart.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(AppIcons.newFolder),
        label: Text(context.t('smart.create')),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([SmartFolders.instance, AiIndex.revision]),
        builder: (context, _) {
          final folders = SmartFolders.instance.folders;
          if (folders.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(Gap.xl),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.folder_special_outlined,
                        size: 56, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(height: Gap.md),
                    Text(context.t('smart.empty'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: Gap.sm),
                    Text(context.t('smart.empty_sub'),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }
          return ListView.separated(
            padding: withNavInset(
                context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 96)),
            itemCount: folders.length,
            separatorBuilder: (_, __) => const SizedBox(height: Gap.sm),
            itemBuilder: (context, i) {
              final folder = folders[i];
              final items = SmartFolders.contents(folder, scope);
              return _FolderRow(
                folder: folder,
                items: items,
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SmartFolderScreen(folderId: folder.id))),
              );
            },
          );
        },
      ),
    );
  }
}

class _FolderRow extends StatelessWidget {
  final SmartFolder folder;
  final List<AiRecord> items;
  final VoidCallback onTap;

  const _FolderRow(
      {required this.folder, required this.items, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fresh = SmartFolders.newCount(folder, items);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(Gap.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.folder_special_rounded,
                    color: scheme.onPrimaryContainer),
              ),
              const SizedBox(width: Gap.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(folder.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      [
                        context.t('smart.count', {'n': items.length}),
                        if (fresh > 0) context.t('smart.new_n', {'n': fresh}),
                      ].join(' · '),
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: fresh > 0
                              ? scheme.primary
                              : scheme.onSurfaceVariant),
                    ),
                  ],
                ),
              ),
              // İlk üç dosyanın küçük resmi: klasörün ne içerdiği adı
              // okumadan görülsün.
              for (final r in items.take(3))
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: FmEntryIcon(
                        entry: AiBuckets.entryOf(r), size: 36, radius: 6),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tek akıllı klasörün içi: önizleme ızgarası, en yeni önce.
class SmartFolderScreen extends StatefulWidget {
  final String folderId;
  const SmartFolderScreen({super.key, required this.folderId});

  @override
  State<SmartFolderScreen> createState() => _SmartFolderScreenState();
}

class _SmartFolderScreenState extends State<SmartFolderScreen> {
  /// Açılıştaki "son bakış" anı: rozetler bu ekran açıkken kaybolmasın.
  int? _seenAtOpen;

  @override
  void initState() {
    super.initState();
    AiIndex.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    SmartFolders.instance.ensureLoaded().then((_) {
      final folder = _folder;
      if (folder == null) return;
      _seenAtOpen = folder.seenMs;
      SmartFolders.instance.markSeen(folder.id);
      if (mounted) setState(() {});
    });
  }

  SmartFolder? get _folder {
    for (final f in SmartFolders.instance.folders) {
      if (f.id == widget.folderId) return f;
    }
    return null;
  }

  Future<void> _rename(SmartFolder folder) async {
    final name = await _askText(context,
        title: context.t('smart.rename'), initial: folder.name);
    if (name != null) await SmartFolders.instance.rename(folder.id, name);
  }

  Future<void> _delete(SmartFolder folder) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('smart.delete')),
        content: Text(ctx.t('smart.delete_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('smart.delete'))),
        ],
      ),
    );
    if (ok != true) return;
    await SmartFolders.instance.remove(folder.id);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final scope = context.watch<AppState>().aiScopeRules;
    return ListenableBuilder(
      listenable: Listenable.merge([SmartFolders.instance, AiIndex.revision]),
      builder: (context, _) {
        final folder = _folder;
        if (folder == null) {
          return Scaffold(appBar: AppBar());
        }
        final items = SmartFolders.contents(folder, scope);
        final seen = _seenAtOpen ?? folder.seenMs;
        final bytes = AiBuckets.totalBytes(items);
        return Scaffold(
          appBar: AppBar(
            title: Text(folder.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) =>
                    v == 'rename' ? _rename(folder) : _delete(folder),
                itemBuilder: (ctx) => [
                  PopupMenuItem(
                      value: 'rename', child: Text(ctx.t('smart.rename'))),
                  PopupMenuItem(
                      value: 'delete', child: Text(ctx.t('smart.delete'))),
                ],
              ),
            ],
          ),
          body: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, 0),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    context.t('smart.header', {
                      'query': folder.query,
                      'n': items.length,
                      'size': FsPaths.humanSize(bytes),
                    }),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ),
              ),
              if (items.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(Gap.xl),
                      child: Text(context.t('smart.no_items'),
                          textAlign: TextAlign.center),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: withNavInset(context, const EdgeInsets.all(Gap.md)),
                  sliver: SliverGrid.builder(
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 128,
                      mainAxisSpacing: Gap.sm,
                      crossAxisSpacing: Gap.sm,
                      childAspectRatio: 0.72,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => LayoutBuilder(
                      builder: (context, box) => AiPreviewCard(
                        record: items[i],
                        size: box.maxWidth,
                        isNew: items[i].modifiedMs > seen,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Tek satırlık metin sorar (yeni klasör sorgusu, yeniden adlandırma).
Future<String?> _askText(BuildContext context,
    {required String title, String? hint, String? initial}) {
  final controller = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(hintText: hint),
        onSubmitted: (v) => Navigator.pop(ctx, v),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.t('common.ok'))),
      ],
    ),
  ).whenComplete(controller.dispose);
}

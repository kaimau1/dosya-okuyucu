import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/edition.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../widgets/pro_gate.dart';
import '../../models/fs_entry.dart';
import '../../models/media_bucket.dart';
import '../../services/fm/collection_insights.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/open_history.dart';
import '../../widgets/app_action_sheet.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/tag_picker_sheet.dart';
import '../../services/fm/fm_env.dart';
import '../../widgets/new_document_sheet.dart';
import '../../widgets/scan_flow.dart';
import 'ai_actions.dart' show giveAiAliasBatch;
import 'downloads_screen.dart' show downloadsPathIn;
import 'entry_actions.dart' show shareEntriesFrom, zipEntries;
import 'smart_sort_screen.dart';
import 'category_screen.dart';

/// **"Analiz ve düzenle"** — kategori / hızlı klasör ekranlarının ayar menüsü
/// (2026-10-23, kullanıcı: *"bu tür hızlı klasörlerde bir ayar menüsü ile
/// özet analiz, genel analiz, AI analiz vb. işlevler yapılabilmeli;
/// kategorilendirme, toplu etiketleme, AI ile etiketleme, manuel etiketleme
/// yapılabilmesi gerekli"*). AI ile etiketleme 2026-11-19'dan beri Akıllı
/// ikinci ad ([giveAiAliasBatch]).
///
/// [visible] = ekranda o an görünen (süzülmüş) liste; analiz ve etiketleme
/// ona uygulanır — kullanıcı önce "yalnız PDF" der, sonra "bunları
/// etiketle". [onChanged] etiketler değişince ekranı tazeler.
Future<void> showCategoryTools(
  BuildContext context, {
  required String title,
  required List<FsEntry> visible,
  required Future<void> Function() onChanged,
  VoidCallback? onSelectAll,
  // Üst çubuktan ⋮'ye taşınanlar (2026-11-22 "üst alanları toparla").
  VoidCallback? onLayout,
  IconData? layoutIcon,
  VoidCallback? onFolderView,
}) async {
  final n = visible.where((e) => !e.isDir).length;
  // **Belge grubu** (2026-11-20, kullanıcı: "Belgeler sayfasında bir menü
  // olsun, içinde güzel özellikler; AI modeliyle ilgili ve tüm belgelerle
  // ilgili genel düğmeler"): liste belge ağırlıklıysa görünür.
  final docs = visible.where((e) => e.category == FmCategory.document).length;
  final isDocs = docs > 0 && docs * 2 >= n;
  final v = await showAppActionSheet<String>(
    context,
    title: context.t('ct.title'),
    subtitle: context.t('ct.subtitle', {'title': title, 'n': n}),
    groups: [
      if (isDocs)
        AppActionGroup(title: context.t('ct.group_quick_create'), actions: [
          AppAction(
              value: 'scan',
              icon: AppIcons.ocr,
              accent: true,
              label: context.t('fm.scan_document')),
          AppAction(
              value: 'new_doc',
              icon: AppIcons.noteAdd,
              label: context.t('home.new_document_title')),
        ]),
      AppActionGroup(title: context.t('ct.group_analysis'), actions: [
        AppAction(
            value: 'summary',
            icon: AppIcons.summarize,
            label: context.t('ct.summary'),
            hint: context.t('ct.summary_hint')),
        AppAction(
            value: 'analysis',
            icon: AppIcons.insights,
            label: context.t('ct.analysis'),
            hint: context.t('ct.analysis_hint')),
      ]),
      if (isDocs)
        AppActionGroup(title: context.t('ui.ct_docs'), actions: [
          AppAction(
              value: 'smart',
              icon: AppIcons.ai,
              proBadge: ProGate.locked(Feature.smartFolders),
              label: context.t('sm.tile'),
              hint: context.t('ui.ct_smart_hint')),
        ]),
      AppActionGroup(title: context.t('ui.ct_list'), actions: [
        if (onLayout != null)
          AppAction(
              value: 'layout',
              icon: layoutIcon ?? AppIcons.layoutGrid,
              label: context.t('ph.view')),
        if (onFolderView != null)
          AppAction(
              value: 'folder_view',
              icon: AppIcons.accountTree,
              label: context.t('downloads.folder_view')),
        if (onSelectAll != null)
          AppAction(
              value: 'select_all',
              icon: AppIcons.selectAll,
              label: context.t('ui.ct_select_all')),
        AppAction(
            value: 'share_all',
            icon: AppIcons.share,
            label: context.t('ui.ct_share_all', {'n': n})),
        AppAction(
            value: 'zip_all',
            icon: AppIcons.compress,
            label: context.t('ui.ct_zip_all', {'n': n}),
            hint: context.t('ui.ct_zip_hint')),
      ]),
      AppActionGroup(title: context.t('ct.group_tags'), actions: [
        // 2026-11-19 (B15): eski "AI ile etiketle" yerine Akıllı ikinci ad —
        // yeni model hem ad hem kategori/etiket veriyor (seçim çubuğuyla aynı).
        AppAction(
            value: 'ai_tag',
            icon: AppIcons.ai,
            accent: true,
            label: context.t('alias.action'),
            hint: context.t('alias.batch_hint')),
        AppAction(
            value: 'bulk_tag',
            icon: AppIcons.tag,
            label: context.t('ct.bulk_tag'),
            hint: context.t('ct.bulk_tag_hint', {'n': n})),
        AppAction(
            value: 'manage_tags',
            icon: AppIcons.labelOutline,
            label: context.t('ct.manage_tags'),
            hint: context.t('ct.manage_tags_hint')),
      ]),
    ],
  );
  if (v == null || !context.mounted) return;
  final files = [for (final e in visible) if (!e.isDir) e];
  switch (v) {
    case 'summary':
      await _showInsights(context, title, files, full: false);
    case 'analysis':
      await _showInsights(context, title, files, full: true);
    case 'ai_tag':
      if (files.isEmpty) return;
      await giveAiAliasBatch(context, files);
      await onChanged();
    case 'bulk_tag':
      if (files.isEmpty) return;
      if (await showTagPicker(context, [for (final e in files) e.path])) {
        await onChanged();
      }
    case 'manage_tags':
      if (await showTagManager(context)) await onChanged();
    case 'smart':
      await SmartSortScreen.open(context);
    case 'scan':
      await ScanFlow.run(context);
    case 'new_doc':
      await showNewDocumentSheet(context);
    case 'layout':
      onLayout?.call();
    case 'folder_view':
      onFolderView?.call();
    case 'select_all':
      onSelectAll?.call();
    case 'share_all':
      if (files.isEmpty) return;
      await shareEntriesFrom(context, [for (final e in files) e.path]);
    case 'zip_all':
      if (files.isEmpty) return;
      // Arşiv İndirilenler'e yazılır (kategori listesinin tek klasörü yok).
      final dest = downloadsPathIn(FmEnv.primaryRoot) ?? FmEnv.primaryRoot;
      if (await zipEntries(context, [for (final e in files) e.path], dest)) {
        await onChanged();
      }
  }
}

CollectionInsights _insightsOf(List<FsEntry> files) => CollectionInsights.of(
      files,
      openedAtOf: OpenHistory.forPath,
      tagsOf: FileTags.forPath,
    );

/// Özet veya genel analiz levhasını doğrudan açar (tek katmanlı menüler için).
Future<void> showCategoryInsights(
  BuildContext context, {
  required String title,
  required List<FsEntry> visible,
  required bool full,
}) =>
    _showInsights(
      context,
      title,
      [for (final e in visible) if (!e.isDir) e],
      full: full,
    );

/// Özet (kısa) ya da genel analiz (uzun) levhası — ikisi de cihazda.
Future<void> _showInsights(
    BuildContext context, String title, List<FsEntry> files,
    {required bool full}) async {
  await OpenHistory.ensureLoaded();
  await FileTags.ensureLoaded();
  if (!context.mounted) return;
  final ins = _insightsOf(files);
  await showAppSheet<void>(
    context,
    title: context.t(full ? 'ct.analysis' : 'ct.summary'),
    builder: (ctx) => Padding(
      padding: const EdgeInsets.fromLTRB(Gap.md + 8, 0, Gap.md + 8, Gap.lg),
      child: _InsightsView(insights: ins, title: title, full: full),
    ),
  );
}

class _InsightsView extends StatelessWidget {
  final CollectionInsights insights;
  final String title;
  final bool full;
  const _InsightsView(
      {required this.insights, required this.title, required this.full});

  @override
  Widget build(BuildContext context) {
    final ins = insights;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    if (ins.count == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.lg),
        child: Text(context.t('ct.empty')),
      );
    }
    Widget heading(String text) => Padding(
          padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm),
          child: Text(text,
              style: theme.textTheme.labelLarge?.copyWith(
                  color: scheme.primary, fontWeight: FontWeight.w700)),
        );
    final maxTypeBytes = ins.byType.isEmpty ? 1 : ins.byType.first.bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            _Stat(
                value: '${ins.count}', label: context.t('ct.stat_files')),
            const SizedBox(width: Gap.sm),
            _Stat(
                value: FsPaths.humanSize(ins.bytes),
                label: context.t('ct.stat_size')),
            const SizedBox(width: Gap.sm),
            _Stat(
                value: '${ins.lastMonthCount}',
                label: context.t('ct.stat_month')),
          ],
        ),
        heading(context.t('ct.by_type')),
        for (final s in ins.byType.take(full ? 8 : 4))
          _BarRow(
            label: context.t(s.key.labelKey),
            value: '${s.count} · ${FsPaths.humanSize(s.bytes)}',
            ratio: maxTypeBytes <= 0 ? 0 : s.bytes / maxTypeBytes,
          ),
        heading(context.t('ct.by_source')),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.xs,
          children: [
            for (final s in ins.bySource.take(full ? 8 : 4))
              Chip(
                visualDensity: VisualDensity.compact,
                label: Text('${context.t(s.key.labelKey)} · ${s.count}'),
              ),
          ],
        ),
        if (full) ...[
          heading(context.t('ct.by_month')),
          _MonthBars(slices: ins.byMonth),
          heading(context.t('ct.cleanable')),
          _ActionRow(
            icon: AppIcons.historyToggleOff,
            title: context.t('ct.stale', {'days': CollectionInsights.staleDays}),
            value: '${ins.stale.length} · ${FsPaths.humanSize(ins.staleBytes)}',
            onTap: ins.stale.isEmpty
                ? null
                : () => _openList(context,
                    context.t('ct.stale_title', {'title': title}), ins.stale),
          ),
          _ActionRow(
            icon: AppIcons.copyAll,
            title: context.t('ct.copies'),
            value: '${ins.copies.length} · ${FsPaths.humanSize(ins.copyBytes)}',
            onTap: ins.copies.isEmpty
                ? null
                : () => _openList(context,
                    context.t('ct.copies_title', {'title': title}), ins.copies),
          ),
          heading(context.t('ct.largest')),
          for (final e in ins.largest)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: FmEntryIcon(entry: e, size: 32),
              title: Text(e.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              trailing: Text(FsPaths.humanSize(e.sizeBytes),
                  style: theme.textTheme.labelMedium),
              onTap: () => EntryOpener.open(context, e.path),
            ),
        ],
        heading(context.t('ct.tags_heading')),
        if (ins.topTags.isEmpty)
          Text(context.t('ct.no_tags'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: Paper.faint(context)))
        else
          Wrap(
            spacing: Gap.sm,
            runSpacing: Gap.xs,
            children: [
              for (final t in ins.topTags)
                Chip(
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(AppIcons.tag, size: 16),
                  label: Text('${t.key} · ${t.value}'),
                ),
            ],
          ),
      ],
    );
  }

  static void _openList(BuildContext context, String title, List<FsEntry> files) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CategoryScreen(title: title, files: files),
    ));
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: Gap.sm),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(Radii.control),
        ),
        child: Column(
          children: [
            Text(value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800)),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: Paper.faint(context))),
          ],
        ),
      ),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final String value;
  final double ratio;
  const _BarRow({required this.label, required this.value, required this.ratio});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium)),
              Text(value,
                  style: theme.textTheme.labelMedium
                      ?.copyWith(color: Paper.faint(context))),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.02, 1.0).toDouble(),
              minHeight: 6,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBars extends StatelessWidget {
  final List<InsightSlice<DateTime>> slices;
  const _MonthBars({required this.slices});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final max = slices.fold<int>(1, (m, s) => s.count > m ? s.count : m);
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final s in slices)
            Expanded(
              child: Tooltip(
                message: '${s.key.month}/${s.key.year} · ${s.count}',
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      height: 60 * s.count / max + 2,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: s.count == 0
                            ? theme.colorScheme.surfaceContainerHighest
                            : theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${s.key.month}',
                        style: theme.textTheme.labelSmall
                            ?.copyWith(color: Paper.faint(context))),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final VoidCallback? onTap;
  const _ActionRow(
      {required this.icon, required this.title, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        dense: true,
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(value),
        trailing: onTap == null ? null : const Icon(AppIcons.chevron),
        onTap: onTap,
      );
}

/// **Etiketleri yönet** — elle: yeniden adlandır, sil (dosyalara dokunmaz).
/// Değişiklik olduysa true.
Future<bool> showTagManager(BuildContext context) async {
  await FileTags.ensureLoaded();
  if (!context.mounted) return false;
  // Levha sürükleyerek de kapanabilir (dönüş değeri yok) → değişiklik
  // bilgisi dışarıda tutulur.
  final changed = ValueNotifier(false);
  await showAppSheet<void>(
    context,
    title: context.t('ct.manage_tags'),
    scrollable: false,
    builder: (_) => _TagManager(changed: changed),
  );
  final result = changed.value;
  changed.dispose();
  return result;
}

class _TagManager extends StatefulWidget {
  final ValueNotifier<bool> changed;
  const _TagManager({required this.changed});

  @override
  State<_TagManager> createState() => _TagManagerState();
}

class _TagManagerState extends State<_TagManager> {
  void _mark() {
    widget.changed.value = true;
    if (mounted) setState(() {});
  }

  Future<void> _rename(String tag) async {
    final name = await showAppPrompt(context,
        title: context.t('ct.tag_rename'),
        label: context.t('tp.new_tag'),
        initial: tag,
        maxLength: 32);
    if (name == null || name == tag) return;
    await FileTags.renameTag(tag, name);
    _mark();
  }

  Future<void> _delete(String tag, int n) async {
    final ok = await showAppConfirm(context,
        title: context.t('ct.tag_delete'),
        message: context.t('ct.tag_delete_body', {'tag': tag, 'n': n}),
        confirmLabel: context.t('common.delete'),
        destructive: true);
    if (!ok) return;
    await FileTags.deleteTag(tag);
    _mark();
  }

  @override
  Widget build(BuildContext context) {
    final counts = FileTags.counts().entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: counts.isEmpty
            ? Padding(
                padding: const EdgeInsets.fromLTRB(24, Gap.sm, 24, Gap.lg),
                child: Text(context.t('ct.no_tags_yet')),
              )
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final e in counts)
                    ListTile(
                      leading: const Icon(AppIcons.tag),
                      title: Text(e.key),
                      subtitle:
                          Text(context.t('count.files', {'n': e.value})),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: context.t('ct.tag_rename'),
                            icon: const Icon(AppIcons.rename),
                            onPressed: () => _rename(e.key),
                          ),
                          IconButton(
                            tooltip: context.t('ct.tag_delete'),
                            icon: const Icon(AppIcons.delete),
                            onPressed: () => _delete(e.key, e.value),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
    );
  }
}

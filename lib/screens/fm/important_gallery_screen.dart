import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/safe_insets.dart';
import '../../core/theme.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/doc_classifier.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fm_env.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/important_gallery_filter.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/fm/fm_entry_icon.dart';
import '../../widgets/fm/fm_quick_filters.dart' show FmFilterBar, FmPill;
import '../../widgets/fm/fm_type_chips.dart' show FmChoiceTile, FmSheetFooter;
import 'browser_screen.dart';
import 'important_screen.dart';

/// **Önemli Galeri** — Önemli Dosyalar'daki her dosya önizlemeli ızgarada,
/// ana ekranda kendi kartıyla (2026-11-10, kullanıcı isteği).
///
/// Süzgeçler üç kartta toplanır (pano/galeri ekranlarının şerit dili,
/// [FmFilterBar]): **Tür** (görsel / belge / diğer grupları altında ince
/// türler), **Konu ve klasör** (alt klasör = kategori, dosya adından belge
/// konusu, etiketler) ve **Zaman ve boyut**. Sıralama üst çubukta, arama
/// alanı ad üzerinde. Her seçeneğin yanında "bunu seçersem kaç dosya" sayısı.
class ImportantGalleryScreen extends StatefulWidget {
  const ImportantGalleryScreen({super.key});

  @override
  State<ImportantGalleryScreen> createState() => _ImportantGalleryScreenState();
}

class _ImportantGalleryScreenState extends State<ImportantGalleryScreen> {
  String get _root => ImportantScreen.pathIn(FmEnv.primaryRoot);

  List<ImpItem> _items = const [];
  bool _loading = true;
  ImpFilter _filter = const ImpFilter();
  bool _searching = false;
  final _query = TextEditingController();

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_reload);
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_reload);
    _query.dispose();
    super.dispose();
  }

  void _reload() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final root = _root;
    final files = Directory(root).existsSync()
        ? await FsScan.collect([root])
        : const <FsEntry>[];
    if (!mounted) return;
    setState(() {
      _items = [
        for (final f in files)
          if (!f.isDir) ImpItem.of(root, f, tags: FileTags.forPath(f.path)),
      ];
      _loading = false;
    });
  }

  void _set(ImpFilter f) => setState(() => _filter = f);

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final shown = _filter.apply(_items, now);
    final paths = [for (final i in shown) i.entry.path];
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _query,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: context.t('ig.search_hint'),
                  border: InputBorder.none,
                ),
                onChanged: (v) => _set(_filter.copyWith(query: v)),
              )
            : Text(context.t('ig.title')),
        actions: [
          IconButton(
            tooltip: context.t(_searching ? 'common.close' : 'important.search'),
            icon: Icon(_searching ? AppIcons.close : AppIcons.search),
            onPressed: () => setState(() {
              _searching = !_searching;
              if (!_searching) {
                _query.clear();
                _filter = _filter.copyWith(query: '');
              }
            }),
          ),
          PopupMenuButton<ImpSort>(
            tooltip: context.t('ig.sort'),
            icon: const Icon(AppIcons.sort),
            initialValue: _filter.sort,
            onSelected: (s) => _set(_filter.copyWith(sort: s)),
            itemBuilder: (ctx) => [
              for (final s in ImpSort.values)
                CheckedPopupMenuItem(
                  value: s,
                  checked: _filter.sort == s,
                  child: Text(ctx.t(s.labelKey)),
                ),
            ],
          ),
          IconButton(
            tooltip: context.t('important.open_in_browser'),
            icon: const Icon(AppIcons.star),
            onPressed: () async {
              await Navigator.of(context)
                  .push(browserRoute(const ImportantScreen()));
              await _load();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: Gap.xs),
          FmFilterBar(children: [
            _pill(context, AppIcons.layoutGrid, 'ig.type',
                _filter.typeActive, _typeSheet),
            _pill(context, AppIcons.labelOutline, 'ig.topic',
                _filter.topicActive, _topicSheet),
            _pill(context, AppIcons.dateRange, 'ig.when',
                _filter.whenActive, _whenSheet),
          ]),
          if (!_filter.isEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(
                  Gap.md, Gap.xs, Gap.sm, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(context.t('ig.result', {'n': shown.length}),
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      _query.clear();
                      _set(_filter.clearAll());
                    },
                    icon: const Icon(AppIcons.clearAll, size: 18),
                    label: Text(context.t('ig.clear_all')),
                  ),
                ],
              ),
            ),
          Expanded(child: _grid(context, shown, paths)),
        ],
      ),
    );
  }

  Widget _pill(BuildContext context, IconData icon, String key, int active,
      Future<void> Function() open) {
    return InkWell(
      key: ValueKey('ig-$key'),
      borderRadius: BorderRadius.circular(12),
      onTap: open,
      child: FmPill(
        icon: icon,
        label: context.t(key),
        count: active > 0 ? active : null,
        dropdown: true,
        highlighted: active > 0,
      ),
    );
  }

  Widget _grid(BuildContext context, List<ImpItem> shown, List<String> paths) {
    if (!_loading && _items.isEmpty) {
      return _message(context, context.t('ig.empty'));
    }
    if (!_loading && shown.isEmpty) {
      return _message(context, context.t('ig.no_match'));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: LayoutBuilder(builder: (context, box) {
        final cols = (box.maxWidth / 120).floor().clamp(3, 8);
        final cell = (box.maxWidth - Gap.md * 2 - (cols - 1) * 4) / cols;
        return GridView.builder(
          padding: withNavInset(context,
              const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
          ),
          itemCount: shown.length,
          itemBuilder: (context, i) {
            final f = shown[i].entry;
            return ImportantGalleryTile(
              key: ValueKey(f.path),
              entry: f,
              size: cell,
              onTap: () => EntryOpener.open(context, f.path, siblings: paths),
            );
          },
        );
      }),
    );
  }

  Widget _message(BuildContext context, String text) => ListView(
        children: [
          Padding(
            padding: const EdgeInsets.all(Gap.xl),
            child: Column(
              children: [
                Icon(AppIcons.importantGallery,
                    size: 48,
                    color: Theme.of(context).colorScheme.onSurfaceVariant),
                const SizedBox(height: Gap.md),
                Text(text, textAlign: TextAlign.center),
              ],
            ),
          ),
        ],
      );

  // ── Levhalar ─────────────────────────────────────────────────────────────

  /// Ortak levha iskeleti: bölümler (başlık + kutu ızgarası) + alt satır.
  Future<void> _sheet({
    required String titleKey,
    required List<(String, List<Widget Function(double)>)> Function(
            BuildContext ctx, ImpFilter f, void Function(ImpFilter) apply)
        sections,
    required ImpFilter Function(ImpFilter) clear,
    required int Function(ImpFilter) active,
  }) {
    var f = _filter;
    return showAppSheet<void>(
      context,
      title: context.t(titleKey),
      builder: (ctx) => StatefulBuilder(builder: (ctx, setSheet) {
        void apply(ImpFilter next) {
          setSheet(() => f = next);
          _set(next);
        }

        final scheme = Theme.of(ctx).colorScheme;
        final now = DateTime.now();
        return SingleChildScrollView(
          child: Padding(
            padding:
                const EdgeInsetsDirectional.fromSTEB(Gap.md, 0, Gap.md, Gap.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (title, tiles) in sections(ctx, f, apply))
                  if (tiles.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsetsDirectional.only(
                          start: Gap.sm, top: Gap.sm, bottom: Gap.sm),
                      child: Text(title,
                          style: Theme.of(ctx).textTheme.labelLarge?.copyWith(
                              color: scheme.onSurfaceVariant)),
                    ),
                    LayoutBuilder(builder: (ctx, box) {
                      final cols = box.maxWidth < 300 ? 2 : 3;
                      final w = (box.maxWidth - Gap.sm * (cols - 1)) / cols;
                      return Wrap(
                        spacing: Gap.sm,
                        runSpacing: Gap.sm,
                        children: [for (final t in tiles) t(w)],
                      );
                    }),
                  ],
                const SizedBox(height: Gap.md),
                FmSheetFooter(
                  shown: f.countIf(_items, now, f),
                  onClear: active(f) == 0 ? null : () => apply(clear(f)),
                  onDone: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  Widget Function(double) _tile({
    required String key,
    required IconData icon,
    required Color color,
    required String label,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) =>
      (w) => FmChoiceTile(
            key: ValueKey(key),
            width: w,
            icon: icon,
            color: color,
            label: label,
            count: count,
            selected: selected,
            onTap: onTap,
          );

  static IconData _kindIcon(ImpKind k) => switch (k) {
        ImpKind.photo => FmColors.iconFor(FmCategory.image),
        ImpKind.screenshot => AppIcons.screenshot,
        ImpKind.video => FmColors.iconFor(FmCategory.video),
        ImpKind.pdf => AppIcons.pdf,
        ImpKind.word => AppIcons.kindWord,
        ImpKind.sheet => AppIcons.kindSheet,
        ImpKind.slides => AppIcons.kindSlides,
        ImpKind.text => AppIcons.kindText,
        ImpKind.book => AppIcons.kindBook,
        ImpKind.audio => FmColors.iconFor(FmCategory.audio),
        ImpKind.archive => FmColors.iconFor(FmCategory.archive),
        ImpKind.other => AppIcons.kindOther,
      };

  static Color _kindColor(ImpKind k) => switch (k) {
        ImpKind.photo => FmColors.forCategory(FmCategory.image),
        ImpKind.screenshot => AppHues.indigo,
        ImpKind.video => FmColors.forCategory(FmCategory.video),
        ImpKind.pdf => AppHues.red,
        ImpKind.word => AppHues.blue,
        ImpKind.sheet => AppHues.green,
        ImpKind.slides => AppHues.orange,
        ImpKind.text => AppHues.steel,
        ImpKind.book => AppHues.plum,
        ImpKind.audio => FmColors.forCategory(FmCategory.audio),
        ImpKind.archive => FmColors.forCategory(FmCategory.archive),
        ImpKind.other => FmColors.forCategory(FmCategory.other),
      };

  static IconData _topicIcon(DocClass c) => switch (c) {
        DocClass.fatura => AppIcons.topicInvoice,
        DocClass.makbuz => AppIcons.receiptLong,
        DocClass.kimlik => AppIcons.badge,
        DocClass.saglik => AppIcons.topicHealth,
        DocClass.banka => AppIcons.topicBank,
        DocClass.sozlesme => AppIcons.topicContract,
        DocClass.egitim => AppIcons.topicEducation,
        DocClass.ekranGoruntusu => AppIcons.screenshot,
        DocClass.bilet => AppIcons.topicTicket,
        DocClass.diger => AppIcons.kindOther,
      };

  Future<void> _typeSheet() => _sheet(
        titleKey: 'ig.type',
        clear: (f) => f.clearType(),
        active: (f) => f.typeActive,
        sections: (ctx, f, apply) {
          final now = DateTime.now();
          return [
            for (final g in ImpKindGroup.values)
              (
                ctx.t('ig.group_${g.name}'),
                [
                  for (final k in ImpKind.values)
                    if (k.group == g)
                      if (f.kinds.contains(k) ||
                          _items.any((i) => i.kind == k))
                        _tile(
                          key: 'ig-kind-${k.name}',
                          icon: _kindIcon(k),
                          color: _kindColor(k),
                          label: ctx.t(k.labelKey),
                          count: f.countIf(
                              _items, now, f.copyWith(kinds: {k})),
                          selected: f.kinds.contains(k),
                          onTap: () => apply(f.toggleKind(k)),
                        ),
                ],
              ),
          ];
        },
      );

  Future<void> _topicSheet() => _sheet(
        titleKey: 'ig.topic',
        clear: (f) => f.clearTopic(),
        active: (f) => f.topicActive,
        sections: (ctx, f, apply) {
          final now = DateTime.now();
          final scheme = Theme.of(ctx).colorScheme;
          final folders = <String>{
            for (final i in _items) i.folder,
            ...f.folders,
          }.toList()
            ..sort((a, b) => a.isEmpty
                ? -1
                : (b.isEmpty ? 1 : a.toLowerCase().compareTo(b.toLowerCase())));
          final topics = [
            for (final c in DocClass.values)
              if (f.topics.contains(c) || _items.any((i) => i.topic == c)) c,
          ];
          final tags = <String>{
            for (final i in _items) ...i.tags,
            ...f.tags,
          }.toList()
            ..sort();
          return [
            (
              ctx.t('ig.sec_folder'),
              // Tek klasör (yalnız kök) varsa seçmenin anlamı yok.
              folders.length < 2
                  ? const []
                  : [
                      for (final d in folders)
                        _tile(
                          key: 'ig-folder-$d',
                          icon: d.isEmpty ? AppIcons.star : AppIcons.folder,
                          color: d.isEmpty ? AppHues.amber : FmColors.folder,
                          label: d.isEmpty ? ctx.t('ig.folder_root') : d,
                          count: f.countIf(
                              _items, now, f.copyWith(folders: {d})),
                          selected: f.folders.contains(d),
                          onTap: () => apply(f.toggleFolder(d)),
                        ),
                    ],
            ),
            (
              ctx.t('ig.sec_topic'),
              topics.length < 2 && f.topics.isEmpty
                  ? const []
                  : [
                      for (final c in topics)
                        _tile(
                          key: 'ig-topic-${c.name}',
                          icon: _topicIcon(c),
                          color: scheme.primary,
                          label: ctx.t(c.labelKey),
                          count: f.countIf(
                              _items, now, f.copyWith(topics: {c})),
                          selected: f.topics.contains(c),
                          onTap: () => apply(f.toggleTopic(c)),
                        ),
                    ],
            ),
            (
              ctx.t('ig.sec_tags'),
              [
                for (final t in tags)
                  _tile(
                    key: 'ig-tag-$t',
                    icon: AppIcons.labelOutline,
                    color: scheme.secondary,
                    label: '#$t',
                    count: f.countIf(_items, now, f.copyWith(tags: {t})),
                    selected: f.tags.contains(t),
                    onTap: () => apply(f.toggleTag(t)),
                  ),
              ],
            ),
          ];
        },
      );

  Future<void> _whenSheet() => _sheet(
        titleKey: 'ig.when',
        clear: (f) => f.clearWhen(),
        active: (f) => f.whenActive,
        sections: (ctx, f, apply) {
          final now = DateTime.now();
          final scheme = Theme.of(ctx).colorScheme;
          return [
            (
              ctx.t('ig.sec_time'),
              [
                for (final t in ImpTime.values)
                  _tile(
                    key: 'ig-time-${t.name}',
                    icon: t == ImpTime.older
                        ? AppIcons.history
                        : AppIcons.calendarMonth,
                    color: scheme.primary,
                    label: ctx.t(t.labelKey),
                    count: f.countIf(_items, now, f.copyWith(times: {t})),
                    selected: f.times.contains(t),
                    onTap: () => apply(f.toggleTime(t)),
                  ),
              ],
            ),
            (
              ctx.t('ig.sec_size'),
              [
                for (final s in ImpSize.values)
                  _tile(
                    key: 'ig-size-${s.name}',
                    icon: AppIcons.storage,
                    color: s.index >= ImpSize.large.index
                        ? scheme.error
                        : scheme.tertiary,
                    label: ctx.t(s.labelKey),
                    count: f.countIf(_items, now, f.copyWith(sizes: {s})),
                    selected: f.sizes.contains(s),
                    onTap: () => apply(f.toggleSize(s)),
                  ),
              ],
            ),
          ];
        },
      );
}

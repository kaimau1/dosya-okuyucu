import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../../core/app_colors.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/file_age.dart';
import '../../models/fm_filter.dart';
import '../../models/fm_layout.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/file_tags.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/list_memory.dart';
import '../../core/app_icons.dart';
import '../../widgets/side_menu_view.dart';
import '../../widgets/fm/fm_bar_title.dart';
import '../../widgets/fm/fm_file_list_view.dart';
import '../../widgets/fm/fm_filter_sheet.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_list_controls.dart';
import '../../widgets/fm/fm_more_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_type_chips.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import 'browser_screen.dart';
import 'category_tools.dart';
import 'entry_actions.dart';
import '../../widgets/motion.dart';

/// İndirilenler: "gereksizleri kolay silmek" için yaş odaklı liste.
///
/// Her satırda **indirilme tarihi** ve mümkünse **son açılma** (dosya sisteminin
/// erişim zamanı) ile renkli yaş rozeti var. Üstte "180+ gündür dokunulmamış"
/// özeti ve tek dokunuşla hepsini seçme düğmesi.
///
/// *Not:* Android'de erişim zamanı (atime) çoğu bağlamada güncellenmez; bu
/// yüzden erişim zamanı değiştirilme zamanından büyük DEĞİLSE "son açılma"
/// gösterilmez — uydurma bilgi vermeyiz ([FsEntry.hasAccessInfo]).
class DownloadsScreen extends StatefulWidget {
  final String path;
  const DownloadsScreen({super.key, required this.path});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  List<FsEntry> _files = const [];
  final Set<String> _selected = {};

  /// Sürükleyerek seçimde kenarda otomatik kaydırma için.
  final ScrollController _scroll = ScrollController();
  bool _loading = true;
  /// **Varsayılan: en yeni önce** (kullanıcı 2026-08-17: *"indirilenlerde en
  /// güncelden en eskiye sıralanmalı, şu an tam tersi varsayılan"*).
  FmSort _sort = FmSort.date;
  bool _desc = true;

  static const _memoryId = 'downloads';

  /// Görünüm (liste/ayrıntılı/ızgara) — 2026-11-16, kullanıcı: "Önemli
  /// Galeri'de görünüm ayarlanıyor, İndirilenler'de ayarlanamıyor". Kalıcı.
  FmLayout _layout = FmLayout.list;

  void _setLayout(FmLayout l) {
    setState(() => _layout = l);
    ListMemory.saveLayout(_memoryId, l);
  }

  /// Tür süzgeci (Faz 13) — oturum boyunca hatırlanır, sıralama kalıcı (K17).
  FmFilter _filter = ListMemory.filterOf(_memoryId);

  void _setFilter(FmFilter f) => setState(() {
        _filter = f;
        ListMemory.rememberFilter(_memoryId, f);
      });

  void _setSort(FmSort sort, bool desc) {
    setState(() {
      _sort = sort;
      _desc = desc;
    });
    ListMemory.saveSort(_memoryId, sort, desc);
  }

  final _searchController = TextEditingController();
  bool _searching = false;
  String _query = '';

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    FsEvents.version.addListener(_load);
    // Başka uygulamanın (Claude, Notlar, tarayıcı…) indirdiği dosya: sekme
    // ayakta kaldığı için initState bir daha koşmuyor (bkz. FsEvents.returned).
    FsEvents.returned.addListener(_load);
    FileTags.ensureLoaded().then((_) {
      if (mounted) setState(() {});
    });
    ListMemory.load(_memoryId).then((saved) {
      if (!mounted) return;
      setState(() {
        _sort = saved.sort ?? _sort;
        _desc = saved.descending ?? _desc;
        _layout = saved.layout ?? _layout;
      });
    });
    _load();
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_load);
    FsEvents.returned.removeListener(_load);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Üst üste gelen tazelemelerde yalnız EN SON taramanın sonucu yazılır.
  int _loadSeq = 0;

  Future<void> _load() async {
    if (!mounted) return;
    final seq = ++_loadSeq;
    // İskelet yalnız liste boşken: tazelemede eski liste yerinde kalır
    // (eskiden her dosya işleminde ekran iskelete dönüp yanıp sönüyordu).
    if (_files.isEmpty && !_loading) setState(() => _loading = true);
    // `index(perCategory: 5000)` kategori başına kırpıyordu; `collect`
    // eksiksiz döner (aynı 800 sınırı hatasının küçük kardeşi).
    final all = await FsScan.collect([widget.path]);
    if (!mounted || seq != _loadSeq) return;
    // Değişiklik yoksa yeniden çizme (arkadan dönüşte çoğu zaman böyle).
    if (!_loading && FsScan.sameListing(_files, all)) return;
    setState(() {
      _files = all;
      _selected.removeWhere((s) => !all.any((e) => e.path == s));
      _loading = false;
    });
  }

  int get _now => DateTime.now().millisecondsSinceEpoch;

  int? _ageDays(FsEntry e) => daysBetween(e.lastTouchedMs, _now);

  List<FsEntry>? _sortedCache;
  String? _sortedKey;

  /// Süzülmüş + sıralı liste — **önbellekli** (G13): eskiden her `build`'de
  /// (her seçim dokunuşunda) bütün liste yeniden süzülüp sıralanıyordu.
  List<FsEntry> get _sorted {
    final key = '${identityHashCode(_files)}|$_query|${_filter.signature}|'
        '${_sort.name}|$_desc';
    final cached = _sortedCache;
    if (cached != null && key == _sortedKey) return cached;
    // Arama bellekte süzer: bu ekranın listesi zaten yüklü, disk okunmaz.
    final filtered = _filter
        .apply(_files, tagsOf: FileTags.forPath)
        .where((e) =>
            _query.trim().isEmpty || fmMatches(e.name, _query, path: e.path))
        .toList();
    final list =
        FsScan.sort(filtered, _sort, descending: _desc, foldersFirst: false);
    _sortedCache = list;
    _sortedKey = key;
    return list;
  }

  FmListControls get _controls => FmListControls(
        sort: _sort,
        descending: _desc,
        onSort: _setSort,
        filter: _filter,
        onFilterChanged: _setFilter,
        onOpenFilter: _openFilterSheet,
        onTools: () => _openTools(_sorted),
      );

  Future<void> _openFilterSheet() async {
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: extensionCounts(_files),
      tags: FileTags.counts(),
      smartCats: smartCatCountsFor(_files, _filter),
    );
    if (result == null || !mounted) return;
    _setFilter(result.filter);
    _setSort(result.sort, result.descending);
  }

  Future<void> _openTools(List<FsEntry> files) => showCategoryTools(
        context,
        title: context.t('downloads.title'),
        visible: files,
        onSelectAll: () => setState(() {
          if (files.every((e) => _selected.contains(e.path))) {
            _selected.removeAll(files.map((e) => e.path));
          } else {
            _selected.addAll(files.map((e) => e.path));
          }
        }),
        // Klasör görünümü + yerleşim ⋮'de (2026-11-22 "üst alanları toparla").
        layoutIcon: fmLayoutIcon(_layout),
        onLayout: () async {
          final picked = await showFmLayoutSheet(context, current: _layout);
          if (picked != null && mounted) _setLayout(picked);
        },
        onFolderView: () => Navigator.of(context).push(
          browserRoute(BrowserScreen(
              path: widget.path, title: context.t('downloads.title'))),
        ),
        onChanged: _load,
      );

  List<FsEntry> get _ancient => _files
      .where((e) => ageLevelFor(_ageDays(e)) == AgeLevel.ancient)
      .toList();

  /// Seçili girdiler (yol → girdi haritasıyla, liste uzun olabilir).
  List<FsEntry> get _selectedEntries {
    final map = {for (final e in _files) e.path: e};
    return [
      for (final path in _selected)
        if (map[path] != null) map[path]!,
    ];
  }

  int get _selectedBytes => _files
      .where((e) => _selected.contains(e.path))
      .fold(0, (sum, e) => sum + e.sizeBytes);

  /// Seçim varken sistem geri tuşu önce SEÇİMİ bırakır, ekrandan/klasörden
  /// çıkmaz (2026-11-20, kullanıcı: "seçim yaptığımda geri butonu klasörden
  /// çıkıyor, önce seçimi iptal etmeli").
  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _selected.isEmpty,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop && _selected.isNotEmpty) setState(_selected.clear);
        },
        child: _buildSelectable(context),
      );

  Widget _buildSelectable(BuildContext context) {
    final files = _sorted;
    final total = _files.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    final ancient = _ancient;

    return Scaffold(
      appBar: _selecting
          ? AppBar(
              leading: IconButton(
                tooltip: context.t('common.clear_selection'),
                icon: const Icon(AppIcons.close),
                onPressed: () => setState(_selected.clear),
              ),
              title: Text(context.t('downloads.selected', {'n': _selected.length, 'total': files.length})),
              actions: [
                IconButton(
                  tooltip: files.every((e) => _selected.contains(e.path))
                      ? context.t('fm.select_none')
                      : context.t('fm.select_all'),
                  icon: Icon(files.every((e) => _selected.contains(e.path))
                      ? AppIcons.selectNone
                      : AppIcons.selectAll),
                  onPressed: () => setState(() {
                    if (files.every((e) => _selected.contains(e.path))) {
                      _selected.removeAll(files.map((e) => e.path));
                    } else {
                      _selected.addAll(files.map((e) => e.path));
                    }
                  }),
                ),
              ],
            )
          : _searching
              ? AppBar(
                  leading: IconButton(
                    tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                    icon: const Icon(AppIcons.back),
                    onPressed: () => setState(() {
                      _searching = false;
                      _query = '';
                      _searchController.clear();
                    }),
                  ),
                  title: FmSearchField(
                    controller: _searchController,
                    hint: context.t('downloads.search_hint'),
                    onChanged: (v) => setState(() => _query = v),
                  ),
                )
              : AppBar(
                  leading: const SideMenuButton(),
                  // Başlıkta ne gösterdiğimiz yazıyor: bu ekran klasörün
                  // KENDİSİ değil, alt klasörler dahil TÜM dosyaların yaş
                  // odaklı listesi. Kullanıcı "ilginç, kullanışsız bir klasör"
                  // dedi (2026-07-29) — çünkü klasör sandı.
                  // Sayı + boyut tek satırda (2026-11-20, kullanıcı:
                  // "üstte de altta da 54 dosya yazıyor").
                  titleSpacing: 0,
                  title: FmBarTitle(
                    title: context.t('downloads.title'),
                    subtitle: context.t('count.files_size', {
                      'n': _files.length,
                      'size': FsPaths.humanSize(total),
                    }),
                  ),
                  actions: [
                    IconButton(
                      tooltip: context.t('downloads.search'),
                      icon: const Icon(AppIcons.search),
                      onPressed: () => setState(() => _searching = true),
                    ),
                    FmFilterButton(
                        filter: _filter, onPressed: _openFilterSheet),
                    IconButton(
                      key: const ValueKey('downloads-more'),
                      tooltip: context.t('fm.more'),
                      icon: const Icon(AppIcons.more),
                      onPressed: () => _openTools(files),
                    ),
                  ],
                ),
      // Stack: alt eylem çubuğu gövdeyi kısaltmasın → liste zıplamaz.
      body: Stack(children: [
        _loading
          ? const FmListSkeleton()
          : _files.isEmpty
              ? FmEmptyState(
                  icon: AppIcons.download, title: context.t('downloads.empty'))
              : Column(
                  children: [
                    if (ancient.isNotEmpty) ...[
                      _summary(ancient),
                      const Divider(height: 1),
                    ],
                    FmQuickFilters(
                      source: _files,
                      filter: _filter,
                      onChanged: _setFilter,
                      leading: FmTypeChips.forEntries(
                        context,
                        source: _files,
                        filter: _filter,
                        onChanged: _setFilter,
                        query: _query,
                      ),
                      trailing: [
                        FmMoreChip(
                          active: _filter.activeCount,
                          sections: (c) => _controls.sections(c,
                              tags: FileTags.counts()),
                        ),
                      ],
                    ),
                    FmActiveCriteria(
                      filter: _filter,
                      onChanged: _setFilter,
                      padding: const EdgeInsetsDirectional.only(start: 12),
                    ),
                    Expanded(
                      child: FmFileListView(
                        entries: files,
                        layout: _layout,
                        onLayoutChange: _setLayout,
                        selected: _selected,
                        controller: _scroll,
                        onOpen: (e) => EntryOpener.open(context, e.path,
                            siblings: _files.map((e) => e.path).toList()),
                        onToggle: (e) => setState(() {
                          if (!_selected.remove(e.path)) _selected.add(e.path);
                        }),
                        onSelectRange: (a, b, sel) => setState(() {
                          for (var i = a; i <= b; i++) {
                            if (i < 0 || i >= files.length) continue;
                            if (sel) {
                              _selected.add(files[i].path);
                            } else {
                              _selected.remove(files[i].path);
                            }
                          }
                        }),
                        subtitle: _subtitle,
                        badge: _ageBadge,
                        empty: FmEmptyState(
                          icon: AppIcons.noMatch,
                          title: _query.trim().isEmpty
                              ? context.t('list.no_match')
                              : context.t('downloads.no_result', {'q': _query}),
                          action: _filter.isActive
                              ? TextButton(
                                  key: const ValueKey('clear-filter'),
                                  onPressed: () => _setFilter(FmFilter.none),
                                  child: Text(context.t('list.filter_clear')),
                                )
                              : null,
                        ),
                        // Menü YOKTU: kullanıcı "içerisinde pek bir şey
                        // yapamıyorum" dedi (2026-07-29) — açma ve toplu
                        // silme dışında hiçbir işleme yol yoktu.
                        onMore: (entry) async {
                          await showEntryActions(context, entry,
                              allowReveal: true,
                              onReveal: (path) => Navigator.of(context).push(
                                    browserRoute(BrowserScreen(path: path)),
                                  ));
                          await _load();
                        },
                      ),
                    ),
                  ],
                ),
        // Seçim varken: Taşı · Kopyala · Paylaş · Sil (ortak çubuk). Seçimin
        // toplam boyutu da yazılır — bu ekranın derdi yer açmak.
        if (_selecting)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Material(
              elevation: 8,
              color: Theme.of(context).colorScheme.surfaceContainerHigh,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, 0),
                    child: Text(
                      '${context.t('dls.selected', {'n': _selected.length})}'
                      '${FsPaths.humanSize(_selectedBytes)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  FmSelectionBar(
                    onDeselect: (e) => setState(() => _selected.remove(e.path)),
                    selected: _selectedEntries,
                    allowReveal: true,
                    onReveal: (path) => Navigator.of(context).push(
                          browserRoute(BrowserScreen(path: path)),
                        ),
                    onChanged: () async {
                      setState(_selected.clear);
                      await _load();
                    },
                  ),
                ],
              ),
            ),
          ),
      ]),
    );
  }

  /// Yalnız dokunulmamış eski dosya varsa görünen ince satır (sayı/boyut
  /// başlıkta).
  Widget _summary(List<FsEntry> ancient) {
    final ancientBytes = ancient.fold<int>(0, (s, e) => s + e.sizeBytes);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '${context.t('dls.untouched', {'n': ancient.length})}'
              '${FsPaths.humanSize(ancientBytes)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ),
          TextButton(
            onPressed: () =>
                setState(() => _selected.addAll(ancient.map((e) => e.path))),
            child: Text(context.t('downloads.select_old')),
          ),
        ],
      ),
    );
  }

  /// Satırın alt yazısı: boyut · (alt klasör) · indirilme · son açılma.
  String _subtitle(FsEntry entry) => [
        FsPaths.humanSize(entry.sizeBytes),
        // Liste alt klasörleri de kapsıyor; dosyanın hangi alt klasörde
        // olduğu yazılmazsa aynı adlı iki dosya ayırt edilemiyordu.
        if (p.dirname(entry.path) != widget.path)
          '📁 ${p.basename(p.dirname(entry.path))}',
        context.t('dls.downloaded_at',
            {'when': FsPaths.humanDate(entry.modifiedMs)}),
        if (entry.hasAccessInfo)
          context.t('dls.last_opened', {
            'when': relativeDays(daysBetween(entry.accessedMs, _now)),
          }),
      ].join(' · ');

  /// Yaş rozeti ("3 ay") — renk yaşla koyulaşır.
  Widget _ageBadge(FsEntry entry) {
    final days = _ageDays(entry);
    final color = switch (ageLevelFor(days)) {
      AgeLevel.fresh => AppHues.green,
      AgeLevel.recent => AppHues.olive,
      AgeLevel.old => AppHues.orange,
      AgeLevel.ancient => Theme.of(context).colorScheme.error,
      AgeLevel.unknown => Theme.of(context).colorScheme.onSurfaceVariant,
    };
    return Text(
      relativeDays(days),
      style: Theme.of(context)
          .textTheme
          .bodySmall
          ?.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

/// Standart İndirilenler yolu (varsa) — `Download`, bazı cihazlarda `Downloads`.
String? downloadsPathIn(String root) {
  // DİKKAT: bunlar DOSYA SİSTEMİ klasör adları, arayüz metni DEĞİL —
  // çevrilirlerse yol bulunamaz.
  for (final name in const ['Download', 'Downloads', 'İndirilenler']) {
    final candidate = p.join(root, name);
    if (Directory(candidate).existsSync()) return candidate;
  }
  return null;
}

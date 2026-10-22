import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/snack.dart';
import '../../models/fm_filter.dart';
import '../../models/fs_entry.dart';
import '../../services/fm/entry_opener.dart';
import '../../services/fm/fs_events.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/list_memory.dart';
import '../../services/fm/open_history.dart';
import '../../core/app_icons.dart';
import '../../models/fm_layout.dart';
import '../../widgets/fm/fm_file_list_view.dart';
import '../../widgets/fm/fm_layout_sheet.dart';
import '../../widgets/fm/fm_quick_filters.dart';
import '../../widgets/fm/fm_search_field.dart';
import '../../widgets/fm/fm_selection_bar.dart';
import '../../widgets/fm/fm_type_chips.dart';
import 'entry_actions.dart';
import '../../widgets/motion.dart';

/// **Son açılanlar** — uygulamada açılan HER dosya (tür fark etmez), en son
/// açılma zamanına göre sıralı.
///
/// Kullanıcı isteği (2026-07-29): *"son açılma tarihi tüm dosyalar içinde
/// yapılabilmeli ayrı bir alanda"*. "AI" sekmesindeki "Son belgeler" yalnız
/// Word/Excel/PDF/metin gibi belgeleri kapsar ve en yeni 40'la sınırlıdır —
/// o, hızlı erişim listesi. Burası **ayrı bir alan**: görüntü/video/ses/arşiv
/// dahil her tür ve dosya sistemde durduğu sürece sınırsız geçmiş.
///
/// **Faz 13 (2026-10-22, G1)** — kullanıcı: *"son dosyalarda PDF vs ayrı
/// filtreleyemiyorum"*. Ekran yalnız ad aramalı düz bir listeydi; artık öteki
/// listelerle aynı: tür çipleri (PDF/Word/Görsel…), sıralama (son açılma · ad ·
/// boyut · tür), açılma tarihine göre gruplar, liste/ızgara, çoklu seçim +
/// toplu eylemler ve **Geçmişten kaldır**. "Tümünü temizle" ⋮ menüsünde.
class OpenHistoryScreen extends StatefulWidget {
  const OpenHistoryScreen({super.key, this.entriesForTest});

  /// Testler için hazır liste (girdi + açılma zamanı): verilirse disk ve
  /// `OpenHistory` okunmaz — `flutter_test`in sahte saatinde dosya G/Ç'si ve
  /// `compute` hiç tamamlanmıyor (HAFIZA 2026-07-25 §F).
  @visibleForTesting
  final List<({FsEntry entry, int openedAtMs})>? entriesForTest;

  /// [ListMemory] anahtarı.
  static const memoryId = 'recent';

  @override
  State<OpenHistoryScreen> createState() => _OpenHistoryScreenState();
}

class _OpenHistoryScreenState extends State<OpenHistoryScreen> {
  List<FsEntry> _entries = const [];

  /// Yol → son açılma zamanı.
  Map<String, int> _openedAt = const {};
  bool _loading = true;
  bool _searching = false;
  String _query = '';
  final _searchController = TextEditingController();
  final _scroll = ScrollController();
  final Set<String> _selected = {};

  /// Tür süzgeci: oturum boyunca hatırlanır (K17).
  FmFilter _filter = ListMemory.filterOf(OpenHistoryScreen.memoryId);

  /// Sıralama: [FmSort.date] burada **açılma** zamanıdır.
  FmSort _sort = FmSort.date;
  bool _desc = true;
  FmLayout _layout = FmLayout.list;

  bool get _selecting => _selected.isNotEmpty;

  @override
  void initState() {
    super.initState();
    // Başka ekranda silinen bir dosya burada "hayalet" satır olarak kalmasın.
    FsEvents.version.addListener(_load);
    ListMemory.load(OpenHistoryScreen.memoryId).then((saved) {
      if (!mounted) return;
      setState(() {
        _sort = saved.sort ?? _sort;
        _desc = saved.descending ?? _desc;
        _layout = saved.layout ?? _layout;
      });
    });
    final fixed = widget.entriesForTest;
    if (fixed == null) {
      _load();
    } else {
      _entries = [for (final i in fixed) i.entry];
      _openedAt = {for (final i in fixed) i.entry.path: i.openedAtMs};
      _loading = false;
    }
  }

  @override
  void dispose() {
    FsEvents.version.removeListener(_load);
    _searchController.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Geç dönen eski yükleme yenisini ezmesin (silme sonrası art arda
  /// tazelemede `FsEvents` birden çok kez tetikleniyor).
  int _loadToken = 0;

  /// Diskteki gerçeği okumak **arka planda** yapılır: birkaç bin kayıtlık bir
  /// geçmişte ana izlekte `existsSync`+`statSync` çağırmak ekranı saniyelerce
  /// donduruyordu (kullanıcı 2026-08-09: *"son açılanlar ... çok daha hızlı
  /// çalışmalı"*).
  Future<void> _load() async {
    final fixed = widget.entriesForTest;
    if (fixed != null) {
      setState(() {
        _entries = [for (final i in fixed) i.entry];
        _openedAt = {for (final i in fixed) i.entry.path: i.openedAtMs};
        _loading = false;
      });
      return;
    }
    final token = ++_loadToken;
    if (mounted) setState(() => _loading = true);
    await OpenHistory.ensureLoaded();
    final paths = OpenHistory.pathsByRecency();
    final alive = await FsScan.statPaths(paths);
    if (!mounted || token != _loadToken) return;
    setState(() {
      // `statPaths` sırayı korur, yani liste zaten en yeniden eskiye.
      _entries = alive;
      _openedAt = {
        for (final e in alive) e.path: OpenHistory.forPath(e.path) ?? 0,
      };
      _selected.removeWhere((s) => !_openedAt.containsKey(s));
      _loading = false;
    });
  }

  int _openedOf(FsEntry e) => _openedAt[e.path] ?? 0;

  List<FsEntry>? _visibleCache;
  String? _visibleKey;

  /// Süzülmüş + sıralı liste. Arama Türkçe-duyarlı ("sarki" → "Şarkı").
  /// Önbellekli: seçim dokunuşları her karede yeniden süzdürmesin.
  List<FsEntry> get _visible {
    final key = '${identityHashCode(_entries)}|$_query|${_filter.signature}|'
        '${_sort.name}|$_desc';
    final cached = _visibleCache;
    if (cached != null && key == _visibleKey) return cached;
    final list = _filter.apply(_entries, query: _query);
    if (_sort == FmSort.date) {
      list.sort((a, b) => _desc
          ? _openedOf(b).compareTo(_openedOf(a))
          : _openedOf(a).compareTo(_openedOf(b)));
    } else {
      final sorted =
          FsScan.sort(list, _sort, descending: _desc, foldersFirst: false);
      list
        ..clear()
        ..addAll(sorted);
    }
    _visibleCache = list;
    _visibleKey = key;
    return list;
  }

  void _setFilter(FmFilter f) => setState(() {
        _filter = f;
        ListMemory.rememberFilter(OpenHistoryScreen.memoryId, f);
      });

  void _toggle(FsEntry e) => setState(() {
        if (!_selected.remove(e.path)) _selected.add(e.path);
      });

  void _selectRange(List<FsEntry> visible, int a, int b, bool select) =>
      setState(() {
        for (var i = a; i <= b; i++) {
          if (i < 0 || i >= visible.length) continue;
          if (select) {
            _selected.add(visible[i].path);
          } else {
            _selected.remove(visible[i].path);
          }
        }
      });

  /// Seçili dosyaları (dosyaların KENDİSİNE dokunmadan) geçmişten çıkarır;
  /// snackbar'da **Geri al** — yanlışlıkla kaldırılan kayıt açılma zamanıyla
  /// geri gelir.
  Future<void> _removeFromHistory(List<FsEntry> entries) async {
    if (entries.isEmpty) return;
    final removed = {for (final e in entries) e.path: _openedOf(e)};
    // Önce ekran (anında), sonra disk.
    setState(() {
      _selected.removeAll(removed.keys);
      _entries = [
        for (final e in _entries)
          if (!removed.containsKey(e.path)) e,
      ];
    });
    unawaited(OpenHistory.removeAll(removed.keys));
    showSnack(
      context,
      context.t('oh.removed_n', {'n': removed.length}),
      action: SnackBarAction(
        label: context.t('common.undo'),
        onPressed: () async {
          await OpenHistory.restoreAll(removed);
          await _load();
        },
      ),
    );
  }

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('oh.clear_title')),
        content: Text(ctx.t('oh.clear_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('ph.clean'))),
        ],
      ),
    );
    if (ok != true) return;
    await OpenHistory.clearAll();
    if (mounted) {
      setState(() {
        _entries = const [];
        _selected.clear();
      });
    }
  }

  void _closeSearch() => setState(() {
        _searching = false;
        _query = '';
        _searchController.clear();
      });

  @override
  Widget build(BuildContext context) {
    final visible = _visible;
    final selectedEntries = [
      for (final e in visible)
        if (_selected.contains(e.path)) e,
    ];
    final filtered = _filter.isActive || _query.trim().isNotEmpty;
    return Scaffold(
      appBar: _selecting
          ? _selectionBar(visible, selectedEntries)
          : (_searching ? _searchBar() : _normalBar()),
      body: Stack(
        children: [
          Column(
            children: [
              if (_entries.isNotEmpty)
                FmFilterBar(
                  children: FmTypeChips.forEntries(
                    context,
                    source: _entries,
                    filter: _filter,
                    onChanged: _setFilter,
                    query: _query,
                  ),
                ),
              if (_entries.isNotEmpty)
                FmListToolbar(
                  count: visible.length,
                  sort: _sort,
                  descending: _desc,
                  onSort: (sort, desc) {
                    setState(() {
                      _sort = sort;
                      _desc = desc;
                    });
                    ListMemory.saveSort(OpenHistoryScreen.memoryId, sort, desc);
                  },
                ),
              Expanded(
                child: FmFileListView(
                  entries: visible,
                  layout: _layout,
                  selected: _selected,
                  controller: _scroll,
                  loading: _loading,
                  groupBy: _sort,
                  groupTimeOf: _openedOf,
                  bottomPadding: 88,
                  onOpen: (e) => EntryOpener.open(context, e.path,
                      siblings: [
                        for (final x in visible)
                          if (!x.isDir) x.path,
                      ]),
                  onToggle: _toggle,
                  onSelectRange: (a, b, sel) =>
                      _selectRange(visible, a, b, sel),
                  subtitle: (e) => '${context.t('oh.last_opened')}'
                      '${FsPaths.humanDate(_openedOf(e))} · '
                      '${FsPaths.humanSize(e.sizeBytes)}',
                  onMore: (e) async {
                    await showEntryActions(context, e, allowReveal: false);
                    _load();
                  },
                  empty: filtered && _entries.isNotEmpty
                      ? FmEmptyState(
                          icon: AppIcons.noMatch,
                          title: _query.trim().isEmpty
                              ? context.t('list.no_match')
                              : context.t('oh.no_match', {'query': _query}),
                          action: _filter.isActive
                              ? TextButton(
                                  key: const ValueKey('clear-filter'),
                                  onPressed: () => _setFilter(FmFilter.none),
                                  child: Text(context.t('list.filter_clear')),
                                )
                              : null,
                        )
                      : FmEmptyState(
                          icon: AppIcons.emptyFolder,
                          title: context.t('oh.empty'),
                        ),
                ),
              ),
            ],
          ),
          if (_selecting)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: FmSelectionBar(
                selected: selectedEntries,
                onChanged: () async {
                  if (!mounted) return;
                  setState(_selected.clear);
                  await _load();
                },
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _normalBar() => AppBar(
        title: Text(context.t('oh.title')),
        actions: [
          IconButton(
            tooltip: context.t('common.search'),
            icon: const Icon(AppIcons.search),
            onPressed: () => setState(() => _searching = true),
          ),
          IconButton(
            tooltip:
                context.t('ph.layout', {'name': context.t(_layout.labelKey)}),
            icon: Icon(fmLayoutIcon(_layout)),
            onPressed: () async {
              final picked = await showFmLayoutSheet(context, current: _layout);
              if (picked == null) return;
              setState(() => _layout = picked);
              ListMemory.saveLayout(OpenHistoryScreen.memoryId, picked);
            },
          ),
          if (_entries.isNotEmpty)
            PopupMenuButton<String>(
              tooltip: context.t('common.more'),
              onSelected: (_) => _clearAll(),
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'clear',
                  child: Text(ctx.t('oh.clear')),
                ),
              ],
            ),
        ],
      );

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.back),
          onPressed: _closeSearch,
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: context.t('oh.search'),
          onChanged: (v) => setState(() => _query = v),
        ),
      );

  /// Seçim çubuğu: sayaç + tümünü seç; ⋮ içinde **Geçmişten kaldır** (alttaki
  /// ortak çubukta karşılığı olmayan eylem — proje kuralı).
  PreferredSizeWidget _selectionBar(
          List<FsEntry> visible, List<FsEntry> selectedEntries) =>
      AppBar(
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => setState(_selected.clear),
        ),
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': visible.length})),
        actions: [
          FmSelectionActions(
            extra: [
              (
                icon: Icons.history_toggle_off_rounded,
                label: context.t('oh.remove'),
                onTap: () => _removeFromHistory(selectedEntries),
              ),
            ],
            allSelected: visible.every((e) => _selected.contains(e.path)),
            single: _selected.length == 1,
            onToggleAll: () => setState(() {
              if (visible.every((e) => _selected.contains(e.path))) {
                _selected.removeAll(visible.map((e) => e.path));
              } else {
                _selected.addAll(visible.map((e) => e.path));
              }
            }),
            onAbove: () => _anchor(visible, above: true),
            onBelow: () => _anchor(visible, above: false),
          ),
        ],
      );

  void _anchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final i = visible.indexWhere((e) => e.path == _selected.first);
    if (i < 0) return;
    _selectRange(visible, above ? 0 : i, above ? i : visible.length - 1, true);
  }
}

part of '../category_screen.dart';

/// [_CategoryScreenState]'in çizim yardımcıları (A4.1 bölmesi, davranış aynı).
extension _CategoryScreenStateParts on _CategoryScreenState {
  PreferredSizeWidget _normalBar() {
    final shown = _sorted;
    final theme = Theme.of(context);
    final bytes = _bytesOf(shown);
    final count = shown.length == _files.length
        ? context.t('lc.count', {'n': shown.length})
        : context.t('lc.count_of', {'n': shown.length, 'total': _files.length});
    return AppBar(
      // Başlık + **özet satırı** (2026-10-23 yeniden tasarım): "161 öğe ·
      // 220 MB"; süzgeç açıksa "42 / 161 öğe · 33 MB" — sayı artık listenin
      // üstündeki şeritte soluk bir yazı değil, ekranın kimliğinin parçası.
      titleSpacing: 0,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700)),
          Text(
            bytes > 0 ? '$count · ${FsPaths.humanSize(bytes)}' : count,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.t('ph.search_in', {'title': widget.title}),
          icon: const Icon(AppIcons.search),
          onPressed: () => _update(() => _searching = true),
        ),
        IconButton(
          tooltip: context.t('ph.layout', {'name': context.t(_layout.labelKey)}),
          icon: Icon(fmLayoutIcon(_layout)),
          onPressed: () async {
            final picked = await showFmLayoutSheet(context, current: _layout);
            if (picked != null) _setLayout(picked);
          },
        ),
      ],
    );
  }

  /// Görünen listenin toplam boyutu (liste değişmedikçe yeniden toplanmaz).
  int _bytesOf(List<FsEntry> shown) {
    final key = identityHashCode(shown);
    if (_bytesKey == key) return _bytesCache;
    _bytesKey = key;
    return _bytesCache = shown.fold<int>(0, (s, e) => s + e.sizeBytes);
  }


  /// Sırala · Süzgeç · Analiz hapları (süzgeç satırına katılır).
  FmListControls get _controls => FmListControls(
        sort: _sort,
        descending: _desc,
        onSort: _setSort,
        filter: _filter,
        onFilterChanged: _setFilter,
        onOpenFilter: _openFilterSheet,
        onTools: _openTools,
      );

  /// "Analiz ve düzenle" levhası — görünen (süzülmüş) listeye uygulanır.
  Future<void> _openTools() => showCategoryTools(
        context,
        title: widget.title,
        visible: _sorted,
        onChanged: () async {
          if (mounted) _update(() => _sortedCache = null);
        },
      );

  /// Bu listedeki etiketlerin sayıları ("Analiz ve diğer" levhasında kutu).
  Map<String, int> _tagCounts() {
    final counts = <String, int>{};
    for (final e in _files) {
      for (final t in FileTags.forPath(e.path)) {
        counts[t] = (counts[t] ?? 0) + 1;
      }
    }
    return counts;
  }

  /// Süzgeç ve sıralama sayfası (tarih aralığı, boyut, kaynak, tür).
  Future<void> _openFilterSheet() async {
    _ensureCounts();
    final result = await showFmFilterSheet(
      context,
      filter: _filter,
      sort: _sort,
      descending: _desc,
      extensions: _extCache ?? const {},
      buckets: _bucketCache ?? const {},
      chatKinds: _chatKindCache ?? const {},
      tags: FileTags.counts(),
      showDuplicateSwitch: true,
    );
    if (result == null || !mounted) return;
    _setFilter(result.filter);
    _setSort(result.sort, result.descending);
  }

  PreferredSizeWidget _searchBar() => AppBar(
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.back),
          onPressed: _closeSearch,
        ),
        title: FmSearchField(
          controller: _searchController,
          // Süzgeç seçiliyse ipucu onu söyler: "PDF'lerde ara…" yerine
          // genel "Belgelerde ara…" yazıp PDF dışını da arıyormuş gibi
          // görünmesin.
          hint: _filter.isActive
              ? context.t('srch.in_filter_hint', {'n': _scope.length})
              : context.t('ph.search_in_hint', {'title': widget.title}),
          onChanged: (v) => _update(() {
            _query = v;
            if (_mode != _SearchMode.name) {
              _modeResults = null;
              _modeSubs = const {};
            }
          }),
          onSubmitted: (_) => unawaited(_runMode()),
        ),
        actions: [
          if (_mode != _SearchMode.name)
            IconButton(
              key: const ValueKey('search-mode-run'),
              tooltip: context.t('common.search'),
              icon: const Icon(AppIcons.search),
              onPressed: _modeBusy ? null : () => unawaited(_runMode()),
            ),
          if (_query.isNotEmpty)
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(AppIcons.close),
              onPressed: () => _update(() {
                _query = '';
                _searchController.clear();
                _modeResults = null;
                _modeSubs = const {};
              }),
            ),
          // Arama açıkken de süzgeç erişilebilir: "adında tatil geçen, geçen
          // ay çekilmiş videolar" tek adımda daralsın.
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        ],
      );

  /// Seçim üst çubuğu **sade**: sayaç + tümünü seç. Eylemler alttaki
  /// [FmSelectionBar]'da (proje kuralı: üstte yalnız altta karşılığı OLMAYAN).
  PreferredSizeWidget _selectionBar(
          List<FsEntry> files, List<FsEntry> selectedEntries) =>
      AppBar(
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => _update(_selected.clear),
        ),
        // Sayaç EYLEMLE aynı kümeyi sayar (bkz. [_selectedEntries]).
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': files.length})),
        actions: [
          FmSelectionActions(
            allSelected: files.every((e) => _selected.contains(e.path)),
            single: _selected.length == 1,
            onToggleAll: () => _toggleSelectAll(files),
            onAbove: () => _selectFromAnchor(files, above: true),
            onBelow: () => _selectFromAnchor(files, above: false),
          ),
        ],
      );

  Future<void> _open(FsEntry e) => EntryOpener.open(
        context,
        e.path,
        siblings: _sorted.map((x) => x.path).toList(),
      );

  void _reveal(String path) {
    Navigator.of(context).push(browserRoute(BrowserScreen(path: path)));
  }
}

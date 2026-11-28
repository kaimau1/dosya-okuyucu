part of '../pick_file_screen.dart';

/// [_PickFileScreenState]'in çizim yardımcıları (A4.1 bölmesi, davranış aynı).
extension _PickFileScreenStateParts on _PickFileScreenState {
  Widget _body() {
    if (_loading) return const FmListSkeleton();
    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child:
              Text(context.t('pick.unreadable'), textAlign: TextAlign.center),
        ),
      );
    }
    if (_view == _PickView.home) return _home();
    if (_view == _PickView.matches) return _matchesView();
    if (_entries.isEmpty) {
      return FmEmptyState(
        icon: AppIcons.folderOff,
        title: context.t('pick.empty'),
      );
    }
    final source = _entries.where((e) => !e.isDir).toList();
    final entries = pickVisibleEntries(
      _entries,
      _filter,
      sort: _sort,
      sortDesc: _sortDesc,
      keepOrder: _view == _PickView.folder &&
          _sort == FmSort.date &&
          _sortDesc,
    );
    final files = entries.where((e) => !e.isDir).toList();
    final bar = _filterBar(source);
    final actionRow = _listMetaBar(files);
    if (files.isEmpty && _filter.isActive && entries.isEmpty) {
      return ListView(children: [bar, actionRow, _noFilterMatches()]);
    }
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      itemCount: entries.length + 2,
      itemBuilder: (context, i) {
        if (i == 0) return bar;
        if (i == 1) return actionRow;
        return _row(entries[i - 2]);
      },
    );
  }

  /// **Ortak süzgeç satırı** (A11, 2026-11-03): gezgin / kategori /
  /// İndirilenler'deki `FmQuickFilters` — kaynak (WhatsApp, Kamera…),
  /// büyük dosyalar, açılmayanlar; tür hapı ve sıralama+tarih/boyut levhası.
  /// Alt sıkışıklığı önlemek için sıralama ve "Tümünü seç" ayrı başlıkta.
  Widget _filterBar(List<FsEntry> files) => FmQuickFilters(
        key: const ValueKey('pick-filters'),
        source: files,
        filter: _filter,
        onChanged: _setFilter,
        leading: _request.isSpecific
            ? const []
            : FmTypeChips.forEntries(
                context,
                source: files,
                filter: _filter,
                onChanged: _setFilter,
              ),
        trailing: [
          FmMoreChip(
            active: _filter.activeCount,
            sections: (c) => [
              fmSortSection(
                c,
                sort: _sort,
                descending: _sortDesc,
                options: const [FmSort.date, FmSort.size, FmSort.name],
                onSort: (s, desc) => _update(() {
                  _sort = s;
                  _sortDesc = desc;
                }),
              ),
              ...fmDateSizeSections(c,
                  filter: _filter, onChanged: _setFilter),
            ],
          ),
        ],
      );

  /// Süzgecin altında kompakt bilgi, boyut/tarih/ad sıralaması ve "Tümünü seç".
  Widget _listMetaBar(List<FsEntry> files) {
    final faint = Paper.faint(context);
    final allSelected =
        files.isNotEmpty && files.every((e) => _selected.containsKey(e.path));
    final sortLabel = switch (_sort) {
      FmSort.size => context.t(FmSort.size.labelKey),
      FmSort.name => context.t('pick.sort_name'),
      _ => context.t('pick.sort_newest'),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Gap.md, vertical: Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.t('pick.matches_count', {'n': files.length}),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.type.small.copyWith(color: faint),
            ),
          ),
          InkWell(
            key: const ValueKey('pick-sort-pill'),
            borderRadius: BorderRadius.circular(Radii.control),
            onTap: _openSortSheet,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: Gap.sm, vertical: Gap.xs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(AppIcons.swapVert, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '$sortLabel ${_sortDesc ? '↓' : '↑'}',
                    style: context.type.small
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
          if (_request.allowMultiple && files.isNotEmpty) ...[
            const SizedBox(width: Gap.xs),
            TextButton.icon(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: Gap.sm),
              ),
              onPressed: () => _update(() {
                for (final e in files) {
                  if (allSelected) {
                    _selected.remove(e.path);
                  } else {
                    _selected[e.path] = e.sizeBytes;
                  }
                }
              }),
              icon: Icon(
                  allSelected ? AppIcons.checkCircle : AppIcons.check,
                  size: 16),
              label: Text(context.t('pick.select_all')),
            ),
          ],
        ],
      ),
    );
  }

  void _openSortSheet() => showFmMoreSheet(
        context,
        (c) => [
          fmSortSection(
            c,
            sort: _sort,
            descending: _sortDesc,
            options: const [FmSort.date, FmSort.size, FmSort.name],
            onSort: (s, desc) => _update(() {
              _sort = s;
              _sortDesc = desc;
            }),
          ),
          ...fmDateSizeSections(c, filter: _filter, onChanged: _setFilter),
        ],
      );

  Widget _noFilterMatches() => Padding(
        padding: const EdgeInsets.all(Gap.lg),
        child: Column(children: [
          Text(context.t('pick.no_filter_matches'), textAlign: TextAlign.center),
          const SizedBox(height: Gap.sm),
          TextButton(
            onPressed: () => _setFilter(FmFilter.none),
            child: Text(context.t('common.clear')),
          ),
        ]),
      );

  /// Başlık: çağıranın başlığı ("PDF seç") + altında "Notlar için · PDF".
  Widget _titleWidget(Color faint) {
    final title =
        Text(_titleText, maxLines: 1, overflow: TextOverflow.ellipsis);
    if (!(_view == _PickView.home || _view == _PickView.matches)) return title;
    final parts = [
      if (_request.caller case final caller?)
        context.t('pick.for_caller', {'app': caller}),
      if (_request.kindLabel.isNotEmpty) _request.kindLabel,
    ];
    if (parts.isEmpty) return title;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        title,
        Text(
          parts.join(' · '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.type.small.copyWith(color: faint),
        ),
      ],
    );
  }

  /// **Eşleşme listesi** — belirli tür isteğinin ilk yüzü.
  Widget _matchesView() {
    final all = _matches ?? const <FsEntry>[];
    final q = _search.text.trim().toLowerCase();
    final counts = <String, int>{};
    for (final entry in all) {
      final ext = entry.extension.toLowerCase();
      counts[ext] = (counts[ext] ?? 0) + 1;
    }
    final filter = counts.containsKey(_extFilter) ? _extFilter : null;
    final filtered = [
      for (final entry in all)
        if ((filter == null || entry.extension.toLowerCase() == filter) &&
            (q.isEmpty || entry.name.toLowerCase().contains(q)))
          entry
    ];
    final visible = pickVisibleEntries(
      filtered,
      _filter,
      sort: _sort,
      sortDesc: _sortDesc,
    );
    final showRecent =
        q.isEmpty && filter == null && !_filter.isActive && _recent.isNotEmpty;
    final exts = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final header = <Widget>[
      if (exts.length > 1)
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            children: [
              _chip(
                label: '${context.t('pick.all')} · ${all.length}',
                selected: filter == null,
                onTap: () => _update(() => _extFilter = null),
              ),
              for (final ext in exts)
                _chip(
                  label: '${ext.isEmpty ? '?' : ext.toUpperCase()} · '
                      '${counts[ext]}',
                  selected: filter == ext,
                  onTap: () => _update(() => _extFilter = ext),
                ),
            ],
          ),
        ),
      _filterBar(all),
      _listMetaBar(visible),
      if (showRecent) ...[
        SectionHeader(context.t('fm.recent_opened')),
        for (final entry in _recent) _row(entry),
      ],
      SectionHeader(
        context.t('pick.browse_folders'),
        trailing: TextButton.icon(
          onPressed: () {
            _search.clear();
            _loadHome();
          },
          icon: const Icon(AppIcons.emptyFolder, size: 18),
          label: Text(context.t('pick.browse_folders')),
        ),
      ),
    ];

    if (visible.isEmpty) {
      return ListView(
        children: [
          ...header,
          Padding(
            padding: const EdgeInsets.all(Gap.lg),
            child: Text(
              context.t(all.isEmpty ? 'pick.no_matches' : 'pick.no_filter_matches'),
              textAlign: TextAlign.center,
            ),
          ),
          Center(
            child: OutlinedButton.icon(
              onPressed: () {
                _search.clear();
                _loadHome();
              },
              icon: const Icon(AppIcons.emptyFolder),
              label: Text(context.t('pick.browse_folders')),
            ),
          ),
        ],
      );
    }
    // Binlerce satır olabilir: başlık + satırlar TEMBEL kurulur.
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      itemCount: header.length + visible.length,
      itemBuilder: (context, i) =>
          i < header.length ? header[i] : _row(visible[i - header.length]),
    );
  }

  Widget _chip({
    required String label,
    required VoidCallback onTap,
    bool selected = false,
    IconData? icon,
  }) =>
      Padding(
        padding: const EdgeInsetsDirectional.only(end: Gap.sm),
        child: Center(
          child: FilterChip(
            avatar: icon == null ? null : Icon(icon, size: 16),
            label: Text(label),
            selected: selected,
            showCheckmark: false,
            onSelected: (_) => onTap(),
          ),
        ),
      );

  /// **Ana sayfa** — seçicinin asıl yüzü.
  ///
  /// 2026-11-03 (A11, kullanıcı: *"dosya seçici ekranı yeniden yazılsın"*):
  /// sıra **ne arandığına göre**: önce kategori kutuları (en sık giriş),
  /// hemen altında hızlı klasörler; depolama **ince tek satır** (eskiden
  /// panonun büyük halka kartıydı ve ilk ekranın yarısını yiyordu — seçerken
  /// kaç GB boş olduğu ikincil bilgi); son açılanlar EN ALTTA. Dokunuşlar
  /// uygulamanın ekranlarına değil seçicinin kendi görünümlerine gider.
  Widget _home() {
    final folders = StorageStats.standardFolders(FmEnv.primaryRoot);
    final tiles = _tiles();

    return ListView(
      key: const ValueKey('pick-home'),
      padding: withNavInset(
          context,
          const EdgeInsets.fromLTRB(
              Gap.md, Gap.sm, Gap.md, Gap.xl + Gap.lg)),
      children: [
        // 2026-11-18 kullanıcı (Aktar → Dosya ekle): "yeni dosyalar da
        // gözüksün, SS alınca hemen üstte kayan şeritte" — eskiden yalnız
        // en altta son açılanlar vardı.
        Padding(
          padding: const EdgeInsets.only(bottom: Gap.md),
          child: FreshFilesStrip(
            key: const ValueKey('pick-fresh'),
            selected: _selected.keys.toSet(),
            accepts: _request.acceptsEntry,
            onTap: _onTapEntry,
          ),
        ),
        if (tiles.isNotEmpty)
          FmCategoryGrid(
            tiles: DashboardLayout.instance.arrangeTiles(tiles, (t) => t.id),
          ),
        SectionHeader(context.t('fm.quick_folders'),
            padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.sm)),
        Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            if (_lastFolder case final last?)
              ActionChip(
                key: const ValueKey('pick-last-folder'),
                avatar: const Icon(AppIcons.history, size: 18),
                label: Text(p.basename(last)),
                tooltip: context.t('pick.last_folder'),
                onPressed: () => _openFolder(last),
              ),
            for (final folder in folders)
              ActionChip(
                avatar: const Icon(AppIcons.folder, size: 18),
                label: Text(folder.label),
                onPressed: () => _openFolder(folder.path),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        for (final v in FmEnv.volumes) _volumeRow(v),
        if (FmEnv.volumes.isEmpty)
          for (final root in FmEnv.volumeRoots)
            _volumeRow(null, root: root),
        if (_recent.isNotEmpty) ...[
          SectionHeader(context.t('fm.recent_opened'),
              padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs)),
          for (final entry in _recent) _row(entry),
        ],
      ],
    );
  }

  /// Depolama birimi — **ince tek satır**: simge · ad · "x GB boş" + 3 dp
  /// doluluk çizgisi. Dokununca birimin kökü (eski "Tüm dosyalar" girişi).
  Widget _volumeRow(StorageVolume? v, {String? root}) {
    final path = v?.path ?? root!;
    final scheme = Theme.of(context).colorScheme;
    final label = v?.displayLabel(context.t) ??
        (p.equals(path, FmEnv.primaryRoot)
            ? context.t('fm.internal_storage')
            : p.basename(path));
    final hasStats = v?.hasStats ?? false;
    return InkWell(
      key: ValueKey('pick-volume-$path'),
      borderRadius: BorderRadius.circular(Radii.card),
      onTap: () => _openFolder(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.sm, horizontal: 4),
        child: Row(children: [
          Icon(v == null ? AppIcons.storage : volumeIcon(v),
              size: 20, color: scheme.onSurfaceVariant),
          const SizedBox(width: Gap.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ),
                  if (hasStats)
                    Text(
                      context.t('fm.free_bytes',
                          {'v': FsPaths.humanCapacity(v!.freeBytes)}),
                      style: context.type.small
                          .copyWith(color: Paper.faint(context)),
                    ),
                ]),
                if (hasStats) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: v!.usedFraction,
                      minHeight: 3,
                      backgroundColor: scheme.surfaceContainerHighest,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: Gap.sm),
          Icon(AppIcons.chevron, size: 18, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }

  /// Panodaki kutuların seçicideki karşılığı. Seçilebilir dosya vermeyen
  /// kutular (Uygulamalar, Geçmiş, Kitaplık) burada YOK; Drive, çağıran
  /// "diğer kaynaklar"ı açtıysa onun kapısı olur. İstenen türü karşılamayan
  /// kategori kutusu hiç çizilmez (`image/*` isteyen yerde "Belgeler"e girip
  /// boş liste görmek zaman kaybı).
  List<FmTileData> _tiles() {
    String sub(CategoryStat stat) => stat.count == 0
        ? context.t('fm.none')
        : '${FsPaths.humanSize(stat.bytes)} (${stat.count})';

    FmTileData? category(String id, FmCategory c, {String? label}) {
      if (!_categoryAccepted(c)) return null;
      return FmTileData(
        id: id,
        icon: FmColors.iconFor(c),
        color: FmColors.forCategory(c),
        label: label ?? context.t(c.labelKey),
        subtitle: sub(DashboardScreen.cachedStat(c)),
        onTap: () => _openCategory(c),
      );
    }

    final downloads = downloadsPathIn(FmEnv.primaryRoot);
    final important = ImportantScreen.pathIn(FmEnv.primaryRoot);
    return [
      if (downloads != null)
        FmTileData(
          id: 'downloads',
          icon: AppIcons.download,
          color: AppHues.blue,
          label: context.t('fm.downloads'),
          subtitle: '',
          onTap: () => _openFolder(downloads),
        ),
      if (_importantExists)
        FmTileData(
          id: 'important',
          icon: AppIcons.star,
          color: AppHues.amber,
          label: ImportantScreen.folderName,
          subtitle: context.t('common.open'),
          onTap: () => _openFolder(important),
        ),
      ?category('image', FmCategory.image, label: context.t('fm.photos')),
      ?category('video', FmCategory.video),
      ?category('document', FmCategory.document),
      ?category('audio', FmCategory.audio),
      ?category('archive', FmCategory.archive),
      ?category('apk', FmCategory.apk, label: context.t('fm.apk_files')),
      if (_request.otherSources)
        FmTileData(
          id: 'drive',
          icon: AppIcons.cloud,
          color: AppHues.mint,
          label: 'Google Drive',
          subtitle: context.t('pick.other_sources'),
          onTap: _inApp
              ? () => Navigator.of(context).pop(const [AppFilePicker._system])
              : PickerBridge.otherSources,
        ),
    ];
  }

  /// Bu kategoride çağıranın kabul edeceği dosya olabilir mi?
  bool _categoryAccepted(FmCategory category) {
    final sample = switch (category) {
      FmCategory.image => 'jpg',
      FmCategory.video => 'mp4',
      FmCategory.audio => 'mp3',
      _ => 'pdf',
    };
    return _request.accepts(
        PickerRequest.mimeForExtension(sample, category));
  }

  /// Ortak satır ([FmEntryRow], Faz 6): seçici de gezginle AYNI satırı
  /// çizer; çoklu seçimde onay rozeti önizlemenin köşesine biner.
  Widget _row(FsEntry entry) {
    final picked = _selected.containsKey(entry.path);
    return FmEntryRow(
      entry: entry,
      selected: picked,
      selecting: _request.allowMultiple && !entry.isDir,
      showChevron: true,
      // Ana sayfada ve arama sonucunda dosyanın NEREDE olduğu kritik:
      // aynı adlı iki dosyayı ayırt etmenin tek yolu bu.
      subtitle: entry.isDir || _view == _PickView.folder
          ? ''
          : FmLocation.label(entry.path, context.t, volumes: FmEnv.volumes),
      dateText: FmLocation.shortDate(entry.modifiedMs),
      subtitleEnd: entry.isDir ? null : FsPaths.humanSize(entry.sizeBytes),
      showDivider: true,
      onCheck: () => _onTapEntry(entry),
      onTap: () => _onTapEntry(entry),
    );
  }
}

/// Seçici listesinin görünen satırları (saf işlev — test edilir): klasörler
/// süzgeçten ETKİLENMEZ (gezinme yolu kapanmasın), dosyalar [filter]'dan
/// geçer; [keepOrder] (klasör görünümü, ad sırası zaten verili) değilse en
/// yeni üstte ya da [byName] ile ada göre. Klasörler hep dosyalardan önce.
List<FsEntry> pickVisibleEntries(
  List<FsEntry> entries,
  FmFilter filter, {
  bool byName = false,
  FmSort? sort,
  bool? sortDesc,
  bool keepOrder = false,
}) {
  final dirs = [for (final e in entries) if (e.isDir) e];
  final files =
      filter.apply([for (final e in entries) if (!e.isDir) e]);
  final effectiveSort = sort ?? (byName ? FmSort.name : FmSort.date);
  final desc = sortDesc ?? (effectiveSort != FmSort.name);
  if (!keepOrder) {
    int cmp(FsEntry a, FsEntry b) {
      final r = switch (effectiveSort) {
        FmSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        FmSort.date => a.modifiedMs.compareTo(b.modifiedMs),
        FmSort.size => a.sizeBytes.compareTo(b.sizeBytes),
        FmSort.type =>
          a.extension.toLowerCase().compareTo(b.extension.toLowerCase()),
      };
      if (r != 0) return desc ? -r : r;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    }
    dirs.sort(cmp);
    files.sort(cmp);
  }
  return [...dirs, ...files];
}

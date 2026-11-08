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
    final entries = pickVisibleEntries(_entries, _filter,
        byName: _byName, keepOrder: _view == _PickView.folder && !_byName);
    final files = entries.where((e) => !e.isDir).toList();
    final bar = _filterBar(source, trailing: [
      _chip(
        label: context.t(_byName ? 'pick.sort_name' : 'pick.sort_newest'),
        icon: AppIcons.swapVert,
        onTap: () => _update(() => _byName = !_byName),
      ),
      if (_request.allowMultiple && files.isNotEmpty) _selectAllChip(files),
    ]);
    if (files.isEmpty && _filter.isActive && entries.isEmpty) {
      return ListView(children: [bar, _noFilterMatches()]);
    }
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) => i == 0 ? bar : _row(entries[i - 1]),
    );
  }

  /// **Ortak süzgeç satırı** (A11, 2026-11-03): gezgin / kategori /
  /// İndirilenler'deki `FmQuickFilters` — kaynak (WhatsApp, Kamera…),
  /// büyük dosyalar, açılmayanlar; tür hapı ve tarih/boyut levhası. Seçici
  /// belirli bir türle açıldıysa tür hapı YOK (her şey zaten o tür; eşleşme
  /// listesinin kendi uzantı çipleri var).
  Widget _filterBar(List<FsEntry> files, {List<Widget> trailing = const []}) =>
      FmQuickFilters(
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
            sections: (c) => fmDateSizeSections(c,
                filter: _filter, onChanged: _setFilter),
          ),
          ...trailing,
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

  /// Görünen bütün dosyalar seç / bırak.
  Widget _selectAllChip(List<FsEntry> files) {
    final all = files.every((e) => _selected.containsKey(e.path));
    return _chip(
      label: context.t('pick.select_all'),
      icon: AppIcons.check,
      selected: all,
      onTap: () => _update(() {
        for (final e in files) {
          if (all) {
            _selected.remove(e.path);
          } else {
            _selected[e.path] = e.sizeBytes;
          }
        }
      }),
    );
  }

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
    final visible = _filter.apply([
      for (final entry in all)
        if ((filter == null || entry.extension.toLowerCase() == filter) &&
            (q.isEmpty || entry.name.toLowerCase().contains(q)))
          entry
    ]);
    if (_byName) {
      visible.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final showRecent =
        q.isEmpty && filter == null && !_filter.isActive && _recent.isNotEmpty;
    final exts = counts.keys.toList()
      ..sort((a, b) => counts[b]!.compareTo(counts[a]!));

    final header = <Widget>[
      SizedBox(
        height: 48,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: Gap.md),
          children: [
            if (exts.length > 1) ...[
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
            _chip(
              label: context.t(_byName ? 'pick.sort_name' : 'pick.sort_newest'),
              icon: AppIcons.swapVert,
              onTap: () => _update(() => _byName = !_byName),
            ),
            if (_request.allowMultiple && visible.isNotEmpty)
              _selectAllChip(visible),
            _chip(
              label: context.t('pick.browse_folders'),
              icon: AppIcons.emptyFolder,
              onTap: () {
                _search.clear();
                _loadHome();
              },
            ),
          ],
        ),
      ),
      _filterBar(all),
      if (showRecent) ...[
        SectionHeader(context.t('fm.recent_opened')),
        for (final entry in _recent) _row(entry),
      ],
      SectionHeader(context.t('pick.matches_count', {'n': visible.length})),
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
          context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
      children: [
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
        label: label ?? c.label,
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
      if (Directory(important).existsSync())
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
      subtitle: entry.isDir
          ? FsPaths.humanDate(entry.modifiedMs)
          : (_view == _PickView.folder
              ? FsPaths.humanSize(entry.sizeBytes)
              : '${FsPaths.humanSize(entry.sizeBytes)} · '
                  '${p.basename(p.dirname(entry.path))}'),
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
  bool keepOrder = false,
}) {
  final dirs = [for (final e in entries) if (e.isDir) e];
  final files =
      filter.apply([for (final e in entries) if (!e.isDir) e]);
  if (!keepOrder) {
    int cmp(FsEntry a, FsEntry b) => byName
        ? a.name.toLowerCase().compareTo(b.name.toLowerCase())
        : b.modifiedMs.compareTo(a.modifiedMs);
    dirs.sort(cmp);
    files.sort(cmp);
  }
  return [...dirs, ...files];
}

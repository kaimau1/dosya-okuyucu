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
    final entries = [..._entries];
    if (_view != _PickView.folder || _byName) {
      entries.sort(_byName
          ? (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase())
          : (a, b) => b.modifiedMs.compareTo(a.modifiedMs));
    }
    final files = entries.where((e) => !e.isDir).toList();
    return ListView.builder(
      padding: withNavInset(context, const EdgeInsets.only(bottom: Gap.xl)),
      itemCount: entries.length + 1,
      itemBuilder: (context, i) {
        if (i > 0) return _row(entries[i - 1]);
        return SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Gap.md),
            children: [
              _chip(
                label: context.t(_byName ? 'pick.sort_name' : 'pick.sort_newest'),
                icon: AppIcons.swapVert,
                onTap: () => _update(() => _byName = !_byName),
              ),
              if (_request.allowMultiple && files.isNotEmpty)
                _selectAllChip(files),
            ],
          ),
        );
      },
    );
  }

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
    final visible = [
      for (final entry in all)
        if ((filter == null || entry.extension.toLowerCase() == filter) &&
            (q.isEmpty || entry.name.toLowerCase().contains(q)))
          entry
    ];
    if (_byName) {
      visible.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    final showRecent = q.isEmpty && filter == null && _recent.isNotEmpty;
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

  /// **Ana sayfa** — seçicinin asıl yüzü: panonun AYNISI (2026-11-02,
  /// kullanıcı: *"dosya seçici ekranı bizim ana ekranımızın aynısı olmalı,
  /// oradaki tüm kartlar bulunmalı"*). Bellek kartları, kullanıcının
  /// dizdiği kutu ızgarası ve hızlı klasörler; dokunuşlar uygulamanın
  /// ekranlarına değil seçicinin kendi görünümlerine gider.
  Widget _home() {
    final folders = StorageStats.standardFolders(FmEnv.primaryRoot);
    final tiles = _tiles();

    return ListView(
      padding: withNavInset(
          context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
      children: [
        for (final v in FmEnv.volumes) ...[
          DashboardVolumeCard(
            volume: v,
            onTap: () => _openFolder(v.path),
          ),
          const SizedBox(height: Gap.sm),
        ],
        if (_recent.isNotEmpty) ...[
          SectionHeader(context.t('fm.recent_opened'),
              padding: const EdgeInsets.only(top: Gap.md, bottom: Gap.xs)),
          for (final entry in _recent) _row(entry),
        ],
        if (tiles.isNotEmpty) ...[
          const SizedBox(height: Gap.sm),
          FmCategoryGrid(
            tiles: DashboardLayout.instance.arrangeTiles(tiles, (t) => t.id),
          ),
        ],
        SectionHeader(context.t('fm.quick_folders'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.sm)),
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
            for (final root in FmEnv.volumeRoots)
              ActionChip(
                avatar: const Icon(AppIcons.storage, size: 18),
                label: Text(p.equals(root, FmEnv.primaryRoot)
                    ? context.t('fm.internal_storage')
                    : p.basename(root)),
                onPressed: () => _openFolder(root),
              ),
          ],
        ),
        const SizedBox(height: Gap.md),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(AppIcons.database),
          title: Text(context.t('fm.all_files')),
          trailing: const Icon(AppIcons.chevron),
          onTap: () => _openFolder(FmEnv.primaryRoot),
        ),
      ],
    );
  }

  /// Panodaki kutuların seçicideki karşılığı. Seçilebilir dosya vermeyen
  /// kutular (Uygulamalar, Geçmiş, Kitaplık) burada YOK; Drive, çağıran
  /// "diğer kaynaklar"ı açtıysa onun kapısı olur. İstenen türü karşılamayan
  /// kategori kutusu hiç çizilmez (`image/*` isteyen yerde "Belgeler"e girip
  /// boş liste görmek zaman kaybı).
  List<FmTileData> _tiles() {
    final outlined = context.fmOutlinedIcons;
    String sub(CategoryStat stat) => stat.count == 0
        ? context.t('fm.none')
        : '${FsPaths.humanSize(stat.bytes)} (${stat.count})';

    FmTileData? category(String id, FmCategory c, {String? label}) {
      if (!_categoryAccepted(c)) return null;
      return FmTileData(
        id: id,
        icon: FmColors.iconFor(c, outlined: outlined),
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
      if (category('image', FmCategory.image, label: context.t('fm.photos')) case final t?) t,
      if (category('video', FmCategory.video) case final t?) t,
      if (category('document', FmCategory.document) case final t?) t,
      if (category('audio', FmCategory.audio) case final t?) t,
      if (category('archive', FmCategory.archive) case final t?) t,
      if (category('apk', FmCategory.apk, label: context.t('fm.apk_files')) case final t?) t,
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

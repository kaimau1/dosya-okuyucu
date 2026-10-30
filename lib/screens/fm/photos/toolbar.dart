part of '../photos_screen.dart';

extension _PhotosScreenToolbarPart on _PhotosScreenState {
  /// Yüzen üst çubuk: başlık + eylemler + süzgeç şeridi.
  ///
  /// **Yükseklik her kipte AYNI** (normal / arama / seçim): kip değişince
  /// ızgaranın zıplamaması buna bağlı (2026-07-29 "zıplama" hatası). Seçim ve
  /// aramada çubuk SABİTLENİR (seçim sayacı ve arama alanı kaybolmasın);
  /// normal gezinmede aşağı kaydırınca kaybolur, yukarı kaydırınca geri gelir.
  Widget _appBar(AppState appState, PhotoGroup group, List<FsEntry> visible,
      List<FsEntry> selectedEntries) {
    final PreferredSizeWidget strip = PreferredSize(
      preferredSize: const Size.fromHeight(kFmFilterBarHeight),
      child: _filterStrip(appState, group),
    );
    if (_selecting) {
      return SliverAppBar(
        pinned: true,
        toolbarHeight: _PhotosScreenState._toolbarHeight,
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => _partSetState(_selected.clear),
        ),
        // Sayaç EYLEMLE aynı kümeyi sayar (bkz. [_selectedEntries]): görünen
        // listeye daraltıldığında "8214 / 12 seçildi" gibi kendisiyle çelişen
        // bir başlık çıkmaz.
        title: Text(context.t('ph.selected_of',
            {'n': selectedEntries.length, 'total': visible.length})),
        actions: [
          // Tek dosya seçiliyken çıkar: "üstündekileri/altındakileri de seç"
          // (istek 2026-07-29). Birden çok seçiliyken hangi dosya "anchor"
          // olacağı belirsizleşir, o yüzden yalnız tek seçimde gösterilir.
          if (_selected.length == 1) ...[
            IconButton(
              tooltip: context.t('ph.select_above'),
              icon: const Icon(AppIcons.expandLess),
              onPressed: () => _selectFromAnchor(visible, above: true),
            ),
            IconButton(
              tooltip: context.t('ph.select_below'),
              icon: const Icon(AppIcons.expandMore),
              onPressed: () => _selectFromAnchor(visible, above: false),
            ),
          ],
          IconButton(
            tooltip: context.t(visible.every((e) => _selected.contains(e.path))
                ? 'ph.clear_selection'
                : 'ph.select_all'),
            icon: Icon(visible.every((e) => _selected.contains(e.path))
                ? AppIcons.selectNone
                : AppIcons.selectAll),
            onPressed: () => _toggleSelectAll(visible),
          ),
        ],
        bottom: strip,
      );
    }
    if (_searching) {
      return SliverAppBar(
        pinned: true,
        toolbarHeight: _PhotosScreenState._toolbarHeight,
        leading: IconButton(
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(AppIcons.back),
          onPressed: _clearSearchAndSelection,
        ),
        title: FmSearchField(
          controller: _searchController,
          hint: context.t('ph.search_in_hint', {'title': widget.title}),
          onChanged: (v) => _partSetState(() => _query = v),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              tooltip: context.t('common.clear'),
              icon: const Icon(AppIcons.close),
              onPressed: () => _partSetState(() {
                _query = '';
                _searchController.clear();
              }),
            ),
          // Arama açıkken de süzgeç erişilebilir: "adında tatil geçen, geçen
          // ay çekilmiş videolar" tek adımda daralsın.
          FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        ],
        bottom: strip,
      );
    }
    final theme = Theme.of(context);
    final shown = visible.length;
    final total = _files.length;
    final subtitle = shown == total
        ? context.t('count.files_size',
            {'n': shown, 'size': FsPaths.humanSize(_visibleBytes)})
        : context.t('count.of_files', {'shown': shown, 'total': total});
    return SliverAppBar(
      floating: true,
      snap: true,
      toolbarHeight: _PhotosScreenState._toolbarHeight,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: context.t('ph.search_in', {'title': widget.title}),
          icon: const Icon(AppIcons.search),
          onPressed: () => _partSetState(() => _searching = true),
        ),
        FmFilterButton(filter: _filter, onPressed: _openFilterSheet),
        // Nadir işler menüde: çubuk Google Foto'daki gibi sade kalsın (eskiden
        // dört simge + iki satırlı başlık sığmak için yarışıyordu).
        // Nadir işler levhada (2026-10-23: ortada açılan menü yerine gruplu
        // eylem levhası — bkz. `showAppActionSheet`); "Analiz ve düzenle"
        // kategori ekranlarıyla aynı.
        IconButton(
          key: const ValueKey('ph-more'),
          tooltip: context.t('fm.more_actions'),
          icon: const Icon(AppIcons.more),
          onPressed: () async {
            final v = await showAppActionSheet<String>(
              context,
              title: widget.title,
              groups: [
                AppActionGroup(title: context.t('ph.view'), actions: [
                  AppAction(
                      value: 'view',
                      icon: AppIcons.layoutGrid,
                      label: context.t('ph.view')),
                  AppAction(
                      value: 'pin',
                      icon: AppIcons.homeShortcut,
                      label: context.t('ph.pin_home'),
                      hint: context.t('ph.pin_home_hint')),
                  if (visible.isNotEmpty)
                    AppAction(
                        value: 'select',
                        icon: AppIcons.selectAll,
                        label: context.t('ph.select_all')),
                ]),
                AppActionGroup(title: context.t('ct.group_analysis'), actions: [
                  AppAction(
                      value: 'tools',
                      icon: AppIcons.insights,
                      accent: true,
                      label: context.t('ct.title'),
                      hint: context.t('ct.menu_hint')),
                  AppAction(
                      value: 'similar',
                      icon: AppIcons.autoAwesomeMotion,
                      label: context.t('ph.similar_short')),
                ]),
              ],
            );
            if (!mounted) return;
            switch (v) {
              case 'view':
                _showViewSheet();
              case 'similar':
                _openSimilar();
              case 'select':
                _toggleSelectAll(visible);
              case 'pin':
                await _pinToHome();
              case 'tools':
                await showCategoryTools(
                  context,
                  title: widget.title,
                  visible: visible,
                  onChanged: () async {
                    if (mounted) _partSetState(() {});
                  },
                );
            }
          },
        ),
        const SizedBox(width: 4),
      ],
      bottom: strip,
    );
  }

  /// Bu sayfayı telefonun ana ekranına **kendi simgesiyle** ekler
  /// (kullanıcı 2026-10-28: *"görüntüler sayfasını ana ekrana ekleyebilmek
  /// istiyorum"*). Görüntüler (foto+video) / Fotoğraflar / Videolar ayrı
  /// kısayol; simge türün renginde çizilir, dokunuş `app:images` bağlantısı.
  Future<void> _pinToHome() async {
    final messenger = ScaffoldMessenger.of(context);
    final str = AppStrings.of(context);
    final scope = widget.scopeId ?? '';
    final (link, cat) = switch (scope) {
      'depolama-image' => ('app:photos', FmCategory.image),
      'depolama-video' => ('app:videos', FmCategory.video),
      _ => ('app:images', FmCategory.image),
    };
    if (!scope.startsWith('depolama-')) {
      showSnackOn(messenger, str.t('ea.shortcut_unsupported'));
      return;
    }
    if (!await HomeShortcuts.supported()) {
      showSnackOn(messenger, str.t('ea.shortcut_unsupported'));
      return;
    }
    final ok = await HomeShortcuts.pin(
      path: link,
      label: widget.title,
      icon: link == 'app:videos' ? AppIcons.videoLibrary : AppIcons.photos,
      color: FmColors.forCategory(cat),
    );
    showSnackOn(
        messenger,
        ok
            ? str.t('ea.shortcut_requested', {'name': widget.title})
            : str.t('ea.shortcut_failed'));
  }

  void _openSimilar() {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SimilarScreen(
        files: _files,
        title: context.t('ph.similar_title', {'title': widget.title}),
        // Kapsam kimliği: Görüntüler / Videolar ve "tüm depolama" /
        // "Önemli Dosyalar" taramaları aynı kuyruk işini paylaşmasın
        // (bkz. [PhotosScreen.scopeId] ve SimilarFinder.jobIdFor).
        scopeId: widget.scopeId ?? widget.title,
      ),
    ));
  }

  /// **Üç kartlık süzgeç satırı** (2026-10-28, kullanıcı: *"en fazla 3
  /// simge: Tür · Kaynak ve zaman · Analiz ve diğer"*). Kaynaklar (Kamera,
  /// Ekran görüntüsü, WhatsApp …) "Kaynak ve zaman" levhasında; sıralama,
  /// gün/ay/yıl ölçeği, kopyalar ve görünüm "Analiz ve diğer" levhasında.
  /// Yükleme çizgisi şeridin ALTINA biner — ayrı satır açmaz.
  Widget _filterStrip(AppState appState, PhotoGroup group) => Stack(
        children: [
          FmQuickFilters(
            source: _files,
            filter: _filter,
            onChanged: (f) => _partSetState(() => _filter = f),
            showBuckets: widget.showSources,
            leading: FmTypeChips.forEntries(
              context,
              source: _files,
              filter: _filter,
              onChanged: (f) => _partSetState(() => _filter = f),
              tagsOf: FileTags.forPath,
              openedAtOf: OpenHistory.forPath,
              cacheSalt: '${OpenHistory.revision}',
            ),
            trailing: [
              FmMoreChip(
                active: _filter.activeCount + (_hiddenDuplicates > 0 ? 1 : 0),
                sections: _moreSections,
              ),
            ],
          ),
          if (_loadingAll)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      );

  /// "Analiz ve diğer" levhasının bölümleri (her çağrıda güncel durum).
  List<FmMoreSection> _moreSections(BuildContext ctx) {
    final appState = context.read<AppState>();
    final controls = FmListControls(
      sort: _sort,
      descending: _desc,
      onSort: (s, d) => _partSetState(() {
        _sort = s;
        _desc = d;
      }),
      filter: _filter,
      onFilterChanged: (f) => _partSetState(() => _filter = f),
      onOpenFilter: _openFilterSheet,
      // Fotoğraf ızgarasında "türe göre" sıralamanın karşılığı yok.
      sortOptions: const [FmSort.date, FmSort.name, FmSort.size],
    );
    final group = appState.fmPhotoGroup;
    return controls.sections(ctx, tags: FileTags.counts(), extras: [
      FmMoreSection(ctx.t('ph.view'), [
        if (_timelineMode)
          for (final g in PhotoGroup.values)
            FmMoreTile(
              icon: AppIcons.calendarMonth,
              label: ctx.t(g.labelKey),
              selected: g == group,
              onTap: () => appState.setFmPhotoView(appState.fmPhotoLayout, g),
            ),
        FmMoreTile(
          icon: AppIcons.layoutGrid,
          label: ctx.t('ph.view_columns'),
          keepOpen: false,
          onTap: _showViewSheet,
        ),
      ]),
      if (_hiddenDuplicates > 0)
        FmMoreSection(
            ctx.t('ph.hidden_dupes_short', {'n': _hiddenDuplicates}), [
          FmMoreTile(
            icon: AppIcons.filterNone,
            label: ctx.t('ph.show'),
            keepOpen: false,
            onTap: () =>
                _partSetState(() => _filter = _filter.withHideDuplicates(false)),
          ),
          FmMoreTile(
            icon: AppIcons.delete,
            label: ctx.t('ph.clean'),
            color: Theme.of(ctx).colorScheme.error,
            keepOpen: false,
            onTap: _selecting ? () {} : _cleanDuplicates,
          ),
        ]),
    ]);
  }

  /// Gizlenen kopyaları **gerçekten** siler.
  ///
  /// Gizleme ad+boyut tahminine dayanır; SİLME asla tahmine dayanamaz →
  /// adaylar önce bayt bayt doğrulanır (`DuplicateFinder.scanPaths`) ve her
  /// gruptan **en eski** dosya korunur. Silinenler çöp kutusuna gider.
  Future<void> _cleanDuplicates() async {
    // `tagsOf` verilmek ZORUNDA: etiket süzgeci açıkken çözücü verilmezse
    // `FmFilter.matches` her dosyanın etiket kümesini boş sayar ve aday listesi
    // TÜMÜYLE boşalır → ekran kopyaları gösterirken bu düğme "kopya bulunamadı"
    // diyordu (2026-07-29 sadakat denetimi, 2. tur).
    final candidates = _filter
        .withHideDuplicates(false)
        .apply(_files, query: _query, tagsOf: FileTags.forPath)
        .toList();
    final messenger = ScaffoldMessenger.of(context);
    // Metinler await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final str = AppStrings.of(context);
    showSnackOn(messenger, str.t('ph.verifying'));
    final groups = await DuplicateFinder.scanPaths(candidates);
    if (!mounted) return;

    final extras = <FsEntry>[];
    for (final group in groups) {
      final sorted = [...group.files]
        ..sort((a, b) => a.modifiedMs.compareTo(b.modifiedMs));
      extras.addAll(sorted.skip(1));
    }
    if (extras.isEmpty) {
      showSnackOn(messenger, str.t('ph.not_identical'));
      return;
    }
    final bytes = extras.fold<int>(0, (sum, e) => sum + e.sizeBytes);
    // Pencere metni AYARI okur. Sabit "çöp kutusuna taşınacak" yazıyordu; çöp
    // kutusu kapalıyken bu doğrudan yanlıştı ve dosyalar kalıcı siliniyordu
    // (2026-07-29 sadakat denetimi, 2. tur — `deleteEntries`teki nota bak).
    final useTrash = context.read<AppState>().fmUseTrash;
    final ok = await showAppConfirm(
        context,
        title: context.t('ph.delete_dupes_title'),
        message: context.t('ph.delete_dupes_body', {
          'n': extras.length,
          'size': FsPaths.humanSize(bytes),
          'fate': context.t(useTrash ? 'ph.fate_trash' : 'ph.fate_permanent'),
        }),
        confirmLabel: context.t('common.delete'),
        destructive: true,
    );
    if (ok != true || !mounted) return;
    if (await deleteEntries(context, extras, confirm: false)) {
      await _dropMissing();
    }
  }

  /// Görünüm sayfası: zaman ölçeği + sütun sayısı + pinch ipucu.
  ///
  /// İki ayar tek yerde çünkü iki parmakla yakınlaştırma da ikisini BİRLİKTE
  /// değiştiriyor; ayrı yerlerde dursalar biri değişince öteki "kendiliğinden
  /// değişti" sanılırdı.
  Future<void> _showViewSheet() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) {
          final state = ctx.watch<AppState>();
          final theme = Theme.of(ctx);
          final label = theme.textTheme.labelLarge
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(ctx.t('ph.view'), style: theme.textTheme.titleMedium),
                  const SizedBox(height: Gap.md),
                  Text(ctx.t('ph.view_scale'), style: label),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<PhotoGroup>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final g in PhotoGroup.values)
                        ButtonSegment(value: g, label: Text(ctx.t(g.labelKey))),
                    ],
                    selected: {state.fmPhotoGroup},
                    onSelectionChanged: (s) =>
                        state.setFmPhotoView(state.fmPhotoLayout, s.first),
                  ),
                  const SizedBox(height: Gap.md),
                  Text(ctx.t('ph.view_columns'), style: label),
                  const SizedBox(height: Gap.sm),
                  SegmentedButton<FmLayout>(
                    expandedInsets: EdgeInsets.zero,
                    showSelectedIcon: false,
                    segments: [
                      for (final l in FmLayout.values.where((l) => l.isGrid))
                        ButtonSegment(
                          value: l,
                          icon: Icon(_PhotosScreenState._columnsIcon(l.columns), size: 18),
                          label: Text('${l.columns}'),
                        ),
                    ],
                    selected: {state.fmPhotoLayout},
                    onSelectionChanged: (s) =>
                        state.setFmPhotoView(s.first, state.fmPhotoGroup),
                  ),
                  const SizedBox(height: Gap.md),
                  Row(
                    children: [
                      Icon(AppIcons.pinch,
                          size: 20, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(ctx.t('ph.pinch_hint'),
                            style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );

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
      // Fotoğraf ızgarasında "türe göre" sıralamanın karşılığı yok (uzantı
      // süzgeci zaten var); ada/tarihe/boyuta göre yeter.
      sortOptions: const [FmSort.date, FmSort.name, FmSort.size],
    );
    if (result == null || !mounted) return;
    _partSetState(() {
      _filter = result.filter;
      _sort = result.sort;
      _desc = result.descending;
    });
  }

  /// Kaynak, uzantı ve mesajlaşma türü sayıları — liste değişmedikçe yeniden
  /// sayılmaz.
  void _ensureCounts() {
    final key = identityHashCode(_files);
    if (_countsKey == key && _bucketCache != null) return;
    _bucketCache = bucketCounts(_files.map((f) => f.path));
    _extCache = extensionCounts(_files);
    _chatKindCache = chatKindCounts(_files);
    _countsKey = key;
  }
}

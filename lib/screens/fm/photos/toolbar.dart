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
              icon: const Icon(Icons.expand_less_rounded),
              onPressed: () => _selectFromAnchor(visible, above: true),
            ),
            IconButton(
              tooltip: context.t('ph.select_below'),
              icon: const Icon(Icons.expand_more_rounded),
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
        PopupMenuButton<String>(
          tooltip: context.t('fm.more_actions'),
          icon: const Icon(AppIcons.more),
          onSelected: (v) {
            switch (v) {
              case 'view':
                _showViewSheet();
              case 'similar':
                _openSimilar();
              case 'select':
                _toggleSelectAll(visible);
            }
          },
          itemBuilder: (ctx) => [
            _menuItem(ctx, 'view', AppIcons.layoutGrid, ctx.t('ph.view')),
            _menuItem(ctx, 'similar', Icons.auto_awesome_motion_rounded,
                ctx.t('ph.similar_short')),
            if (visible.isNotEmpty)
              _menuItem(ctx, 'select', AppIcons.selectAll, ctx.t('ph.select_all')),
          ],
        ),
        const SizedBox(width: 4),
      ],
      bottom: strip,
    );
  }

  PopupMenuItem<String> _menuItem(
          BuildContext ctx, String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: 20),
            const SizedBox(width: 14),
            Flexible(child: Text(label)),
          ],
        ),
      );

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

  /// **TEK süzgeç satırı** (2026-08-09 kullanıcı: *"görüntüler ve
  /// videolardaki işaretli üst alan çok yer kaplıyor, kompaktlaşmalı"*).
  /// Sıra: kopya uyarısı → ölçek (ya da sıralama) → kaynaklar → süzgeçler.
  /// Yükleme çizgisi şeridin ALTINA biner — ayrı satır açmaz.
  Widget _filterStrip(AppState appState, PhotoGroup group) => Stack(
        children: [
          FmQuickFilters(
            source: _files,
            filter: _filter,
            onChanged: (f) => _partSetState(() => _filter = f),
            showBuckets: false,
            leading: [
              // Kopya uyarısı EN BAŞTA: satır yatay kaydırmalı ve sona konan
              // bir uyarı ekran dışında kalabiliyor — "dosyam kayboldu"
              // hatasını önlemesi gereken bilgi görünmeden işe yaramaz.
              if (_hiddenDuplicates > 0) _duplicateChip(),
              if (_timelineMode) _scalePill(appState, group) else _sortChip(),
              if (widget.showSources) ..._sourceChips(),
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

  /// Gün / Ay / Yıl — **tek pil + menü** (2026-09-26).
  ///
  /// Eskiden şeridin başında üç bölmeli bir kutuydu; ölçek artık iki parmakla
  /// da değişiyor ve kutu şeridin en değerli yerini (ilk 150 dp) kaplıyordu.
  /// Pil o anki ölçeği YAZAR (gizli bir durum yok), dokununca üçü birden
  /// menüde görünür.
  Widget _scalePill(AppState appState, PhotoGroup group) =>
      PopupMenuButton<PhotoGroup>(
        tooltip: context.t('ph.view_scale'),
        initialValue: group,
        onSelected: (g) => appState.setFmPhotoView(appState.fmPhotoLayout, g),
        itemBuilder: (ctx) => [
          for (final g in PhotoGroup.values)
            CheckedPopupMenuItem(
              value: g,
              checked: g == group,
              child: Text(ctx.t(g.labelKey)),
            ),
        ],
        // `FmChip` DEĞİL `FmPill`: çipin kendi dokunma tanıyıcısı menü
        // düğmesinin dokunuşunu yutar ve menü hiç açılmazdı.
        child: FmPill(
          icon: Icons.calendar_month_rounded,
          label: context.t(group.labelKey),
          dropdown: true,
        ),
      );

  /// Tarih dışı sıralamada ölçek yerine sıralamanın kendisi yazar
  /// ("Ada göre ↑"); dokununca süzgeç ve sıralama sayfası açılır.
  Widget _sortChip() => FmChip(
        icon: AppIcons.sort,
        label: '${context.t(_sort.labelKey)} ${_desc ? '↓' : '↑'}',
        selected: false,
        onTap: _openFilterSheet,
      );

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
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ph.delete_dupes_title')),
        content: Text(ctx.t('ph.delete_dupes_body', {
          'n': extras.length,
          'size': FsPaths.humanSize(bytes),
          'fate': ctx.t(useTrash ? 'ph.fate_trash' : 'ph.fate_permanent'),
        })),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('common.delete'))),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (await deleteEntries(context, extras, confirm: false)) {
      await _dropMissing();
    }
  }

  /// "N kopya gizlendi" — süzgeç satırının başındaki **tek pil**.
  ///
  /// Sessiz gizleme "dosyam kayboldu" hatasına yol açar, o yüzden bilgi hep
  /// ekranda; ama kendi satırını hak etmiyordu (2026-08-09: üst alan çok yer
  /// kaplıyor). Dokununca "Göster / Temizle" menüsü açılır — iki eylem de
  /// eskisi gibi tek dokunuş uzakta, yalnız 48 dp'lik satırı yemiyor.
  Widget _duplicateChip() => PopupMenuButton<String>(
        // Seçim sırasında PASİF: etkin kalsa "seçtiklerimi mi siliyor?" sanılır.
        enabled: !_selecting,
        tooltip: context.t('ph.hidden_dupes', {'n': _hiddenDuplicates}),
        onSelected: (value) {
          if (value == 'show') {
            _partSetState(() => _filter = _filter.withHideDuplicates(false));
          } else {
            _cleanDuplicates();
          }
        },
        itemBuilder: (ctx) => [
          PopupMenuItem(value: 'show', child: Text(ctx.t('ph.show'))),
          PopupMenuItem(value: 'clean', child: Text(ctx.t('ph.clean'))),
        ],
        // `FmChip` DEĞİL `FmPill`: çipin kendi jest tanıyıcısı menü düğmesinin
        // dokunuşunu yutar ve menü hiç açılmazdı.
        child: FmPill(
          icon: Icons.filter_none_rounded,
          label: context.t('ph.hidden_dupes_short', {'n': _hiddenDuplicates}),
          disabled: _selecting,
          highlighted: !_selecting,
        ),
      );

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
                      Icon(Icons.pinch_rounded,
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

  /// Kaynak çipleri (Tümü / Kamera / WhatsApp …) — **kendi satırı yok**,
  /// ortak süzgeç şeridine katılır (bkz. `FmQuickFilters.leading`).
  List<Widget> _sourceChips() {
    _ensureCounts();
    final counts = _bucketCache!;
    final buckets = MediaBucket.values
        .where((b) => (counts[b] ?? 0) > 0)
        .toList()
      ..sort((a, b) => (counts[b] ?? 0).compareTo(counts[a] ?? 0));
    if (buckets.length < 2) return const [];
    return [
      FmChip(
        label: context.t('flt.all'),
        count: _files.length,
        selected: _filter.buckets.isEmpty,
        onTap: () => _partSetState(() => _filter = _filter.withBuckets(const {})),
      ),
      for (final b in buckets)
        // Çoklu seçim (istek 2026-07-29). Çip ve süzgeç sayfası AYNI alanı
        // yazar → ikisi hep tutarlı.
        FmChip(
          // `b.label` Türkçe SABİT (klasör adı üretiminde kullanılıyor);
          // ekranda görünen ad çeviri anahtarından gelmeli.
          label: context.t(b.labelKey),
          count: counts[b],
          selected: _filter.buckets.contains(b),
          onTap: () => _partSetState(() => _filter = _filter.toggleBucket(b)),
        ),
    ];
  }
}

part of '../browser_screen.dart';

extension _BrowserScreenViewsPart on _BrowserScreenState {
  /// Üst çubuk: başlık + yalnız `Ara` · `Görünüm` · `⋮` (Faz 6 / U2).
  /// Sıralama ve filtre artık listenin üstündeki araç şeridinde
  /// ([FmListToolbar]); ⋮ menüsü 13 → 8 madde.
  PreferredSizeWidget _normalBar(BuildContext context, AppState appState) {
    final starred = appState.isBookmarked(widget.path);
    return AppBar(
      title: Text(widget.title ?? p.basename(widget.path),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: context.t('fm.search_here'),
          icon: const Icon(AppIcons.search),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SearchScreen(root: widget.path),
          )),
        ),
        IconButton(
          tooltip: context.t('fm.layout', {'name': appState.fmLayout.label}),
          icon: Icon(fmLayoutIcon(appState.fmLayout)),
          onPressed: () async {
            final picked =
                await showFmLayoutSheet(context, current: appState.fmLayout);
            if (picked != null) await appState.setFmLayout(picked);
          },
        ),
        // ⋮ artık açılır liste değil, dosya içindeki "Daha fazla" ile AYNI
        // levha (2026-10-29 görsel birlik: *"klasör menüsü farklı"*).
        IconButton(
          key: const ValueKey('browser-more'),
          tooltip: context.t('fm.other'),
          icon: const Icon(AppIcons.more),
          onPressed: () => _openFolderMenu(context, appState, starred),
        ),
      ],
    );
  }

  void _openFolderMenu(BuildContext context, AppState appState, bool starred) {
    final locked = appState.isFolderLocked(widget.path);
    Future<void> lock() async {
      if (!appState.fmHasLockPin && !await setupPin(context)) return;
      if (!context.mounted) return;
      // Kilidi KALDIRIRKEN de PIN sorulur: telefonu eline alan biri kilidi
      // tek dokunuşla açabilseydi kilit anlamsız olurdu.
      if (locked && !await askPin(context)) return;
      await appState.toggleLockedFolder(widget.path);
    }

    DocMoreSheet.show(
      context,
      [
        DocMoreGroup(context.t('more.folder'), [
          DocMoreItem(
            appState.fmShowHidden ? AppIcons.hiddenOff : AppIcons.hidden,
            context.t('fm.show_hidden'),
            () async {
              await appState.setFmShowHidden(!appState.fmShowHidden);
              _load();
            },
            selected: appState.fmShowHidden,
          ),
          DocMoreItem(
            starred ? AppIcons.star : AppIcons.starEmpty,
            context.t('fm.favorite'),
            () => appState.toggleBookmark(widget.path),
            selected: starred,
          ),
          DocMoreItem(
            locked ? AppIcons.lock : AppIcons.unlock,
            context.t('fm.lock_folder'),
            () => unawaited(lock()),
            selected: locked,
          ),
          DocMoreItem(AppIcons.selectAll, context.t('fm.select_all'),
              _toggleSelectAll),
          // Faz 41 / 6: klasör rengi (gezginde ve listelerde klasör gövdesi).
          DocMoreItem(AppIcons.palette, context.t('lcol.folder'), () async {
            await FmColorsStore.ensureLoaded();
            if (!context.mounted) return;
            final pick = await showLabelColorSheet(context,
                title: context.t('lcol.folder'),
                current: FmColorsStore.folderIndex(widget.path));
            if (pick == null) return;
            await FmColorsStore.setFolder(widget.path, pick.index);
            _load();
          }),
          if (appState.bookmarks.length >= 2)
            DocMoreItem(AppIcons.sort, context.t('fav.reorder'),
                () => unawaited(showFavoritesOrderSheet(context))),
        ]),
        DocMoreGroup(context.t('fm.other'), [
          DocMoreItem(AppIcons.organize, context.t('fm.auto_organize'),
              () async {
            await Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => OrganizeScreen(path: widget.path),
            ));
            _load();
          }),
          DocMoreItem(AppIcons.cleanEmpty, context.t('fm.empty_folders'),
              () => unawaited(_cleanEmptyFolders())),
          DocMoreItem(AppIcons.exportList, context.t('fm.export_list'),
              () => unawaited(_exportListing())),
          DocMoreItem(AppIcons.refresh, context.t('common.refresh'), _load),
          // Faz 41 / 1 (A7.1): bu klasör solda, ikinci bölme aynı yerden.
          DocMoreItem(AppIcons.viewColumn, context.t('dp.title'), () {
            Navigator.of(context).push(MaterialPageRoute(
                builder: (_) =>
                    DualPaneScreen(left: widget.path, right: widget.path)));
          }),
        ]),
      ],
      header: Row(
        children: [
          const Icon(AppIcons.folder, color: FmColors.folder),
          const SizedBox(width: Gap.sm),
          Expanded(
            child: Text(
              widget.title ?? p.basename(widget.path),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
        ],
      ),
    );
  }

  /// Seçim üst çubuğu **sade**: sayaç + toplam boyut + **metinli** seçim
  /// menüsü (Faz 6 / U8). Eylemler (Taşı/Kopyala/Paylaş/Sil/…) alttaki
  /// [FmSelectionBar]'da — proje kuralı: üstte yalnız altta karşılığı
  /// OLMAYAN durur (HAFIZA 2026-07-28 D).
  ///
  /// KÖK NEDEN: "yukarısını seç / aşağısını seç / tersini seç" üç çıplak
  /// simgeydi (`expand_less`, `expand_more`, `swap_horiz`) — anlamlarını
  /// yalnız uzun basınca çıkan ipucu söylüyordu.
  PreferredSizeWidget _selectionBar(BuildContext context, List<FsEntry> visible) {
    return AppBar(
      leading: IconButton(
        tooltip: context.t('common.clear_selection'),
        icon: const Icon(AppIcons.close),
        onPressed: () {
          AppHaptics.selection();
          _partSetState(_selected.clear);
        },
      ),
      // **Seçimin toplam boyutu** (2026-09-04): "12 dosya seçtim, USB'ye
      // sığar mı?" sorusunun cevabı hiçbir yerde yoktu; kullanıcı dosyaları
      // tek tek Özellikler'den toplamak zorundaydı.
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(context.t('fm.selected_count',
              {'n': _selected.length, 'total': _entries.length})),
          if (_selectionBytes > 0)
            Text(
              FsPaths.humanSize(_selectionBytes),
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
      actions: [
        FmSelectionActions(
          allSelected: _allSelected,
          single: _selected.length == 1,
          onToggleAll: _toggleSelectAll,
          onInvert: () => _partSetState(() {
            final all = _entries.map((e) => e.path).toSet();
            final inverted = all.difference(_selected);
            _selected
              ..clear()
              ..addAll(inverted);
          }),
          onAbove: () => _selectFromAnchor(visible, above: true),
          onBelow: () => _selectFromAnchor(visible, above: false),
        ),
      ],
    );
  }

  /// Geniş ekranın sol bölmesi: birimler + hızlı klasörler + favori klasörler.
  Widget _sidePane(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final here = p.normalize(widget.path);
    final root = FmEnv.primaryRoot;
    final quick = root.isEmpty
        ? const <({String label, String path, String icon})>[]
        : StorageStats.standardFolders(root);
    final candidates = <String>[
      for (final v in FmEnv.volumes) v.path,
      for (final f in quick) f.path,
      for (final b in appState.bookmarks) b,
    ];
    String? bestMatch;
    var bestLen = -1;
    for (final c in candidates) {
      if (FsPaths.isInside(c, here)) {
        final len = p.normalize(c).length;
        if (len > bestLen) {
          bestLen = len;
          bestMatch = p.normalize(c);
        }
      }
    }

    IconData quickIcon(String folderPath) =>
        switch (p.basename(folderPath).toLowerCase()) {
          'download' || 'downloads' => AppIcons.download,
          'dcim' || 'pictures' => AppIcons.image,
          'music' => AppIcons.audio,
          'movies' => AppIcons.video,
          'documents' => AppIcons.kindWord,
          _ => AppIcons.folder,
        };

    Widget tile(IconData icon, String label, String path) {
      final active = bestMatch != null && p.normalize(path) == bestMatch;
      return ListTile(
        dense: true,
        leading: Icon(icon, size: AppIcons.medium),
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        selected: active,
        selectedTileColor: scheme.secondaryContainer.withValues(alpha: 0.6),
        shape: const StadiumBorder(),
        onTap: () => BrowserScreen.jumpTo(context, path),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(Gap.sm),
      children: [
        _paneHeader(context, context.t('pane.places')),
        for (final v in FmEnv.volumes)
          tile(
            switch (v.kind) {
              StorageKind.usb => AppIcons.external,
              StorageKind.sdCard => AppIcons.sdCard,
              _ => AppIcons.device,
            },
            v.displayLabel(context.t),
            v.path,
          ),
        if (quick.isNotEmpty) ...[
          _paneHeader(context, context.t('fm.quick_folders')),
          for (final f in quick) tile(quickIcon(f.path), f.label, f.path),
        ],
        if (appState.bookmarks.isNotEmpty) ...[
          _paneHeader(context, context.t('pane.favorites')),
          for (final b in appState.bookmarks)
            tile(AppIcons.star, p.basename(b), b),
        ],
      ],
    );
  }

  Widget _paneHeader(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, Gap.md, Gap.md, Gap.xs),
        child: Text(text,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );

  Widget _body(List<FsEntry> entries, AppState appState) {
    if (_error != null) {
      return FmEmptyState(
        icon: AppIcons.unreadable,
        title: context.t(_error!),
        hint: context.t('list.unreadable_hint'),
        action: FilledButton.tonal(
            onPressed: _load, child: Text(context.t('common.retry'))),
      );
    }
    final layout = appState.fmLayout;
    return FmFileListView(
      entries: entries,
      layout: layout,
      onLayoutChange: appState.setFmLayout,
      selected: _selected,
      controller: _scroll,
      loading: _loading,
      focusPath: _focus,
      focusKey: _focusKey,
      groupBy: _sortOf(appState).$1,
      onRefresh: _load,
      onOpen: _openEntry,
      onToggle: _toggle,
      onSelectRange: (a, b, sel) => _selectRange(entries, a, b, sel),
      onMore: (e) async {
        if (await showEntryActions(context, e)) _load();
      },
      // Tarih kesinlikle görünür, boyut sağda sabitlenir.
      subtitle: (_) => '',
      dateText: (e) => FmLocation.shortDate(e.modifiedMs),
      subtitleEnd: (e) =>
          e.isDir ? _folderSizeEnd(e) : FsPaths.humanSize(e.sizeBytes),
      empty: _entries.isEmpty
          ? FmEmptyState(
              icon: AppIcons.emptyFolder,
              title: context.t('fm.empty_folder'),
              hint: context.t('list.empty_hint'),
            )
          : FmEmptyState(
              icon: AppIcons.noMatch,
              title: context.t('list.no_match'),
              hint: context.t('list.no_match_hint'),
              action: TextButton(
                onPressed: () => _partSetState(() {
                  _filter = FmFilter.none;
                }),
                child: Text(context.t('list.filter_clear')),
              ),
            ),
    );
  }

  /// "+" levhası (Faz 6 / U7): yeni klasör · yeni belge · **buraya tara** ·
  /// **buraya içe aktar**.
  void _showCreateSheet() {
    Widget item(IconData icon, String text, VoidCallback onTap) => ListTile(
          leading: Icon(icon),
          title: Text(text),
          onTap: onTap,
        );
    showAppSheet<void>(
      context,
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item(AppIcons.newFolder, context.t('fm.new_folder'), () {
            Navigator.pop(ctx);
            _newFolder();
          }),
          item(AppIcons.newWord, context.t('fm.new_word_doc'), () {
            Navigator.pop(ctx);
            _newDocument('docx');
          }),
          item(AppIcons.newSheet, context.t('fm.new_xlsx'), () {
            Navigator.pop(ctx);
            _newDocument('xlsx');
          }),
          item(AppIcons.newText, context.t('fm.new_text_file'), () {
            Navigator.pop(ctx);
            _newDocument('txt');
          }),
          const Divider(),
          item(AppIcons.scanHere, context.t('create.scan'), () {
            Navigator.pop(ctx);
            _scanHere();
          }),
          item(AppIcons.importHere, context.t('create.import'), () {
            Navigator.pop(ctx);
            _importHere();
          }),
          const SizedBox(height: Gap.sm),
        ],
      ),
    );
  }
}

part of '../browser_screen.dart';

extension _BrowserScreenViewsPart on _BrowserScreenState {
  /// Üst çubuk: başlık + yalnız `Ara` · `Görünüm` · `⋮` (Faz 6 / U2).
  /// Sıralama ve filtre artık listenin üstündeki araç şeridinde
  /// ([FmListToolbar]); ⋮ menüsü 13 → 8 madde.
  PreferredSizeWidget _normalBar(BuildContext context) {
    final appState = context.watch<AppState>();
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
        PopupMenuButton<String>(
          tooltip: context.t('fm.other'),
          icon: const Icon(AppIcons.more),
          onSelected: (value) async {
            switch (value) {
              case 'hidden':
                await appState.setFmShowHidden(!appState.fmShowHidden);
                _load();
              case 'star':
                appState.toggleBookmark(widget.path);
              case 'lock':
                if (!appState.fmHasLockPin && !await setupPin(context)) break;
                if (!context.mounted) break;
                // Kilidi KALDIRIRKEN de PIN sorulur: telefonu eline alan biri
                // kilidi tek dokunuşla açabilseydi kilit anlamsız olurdu.
                if (appState.isFolderLocked(widget.path) &&
                    !await askPin(context)) {
                  break;
                }
                await appState.toggleLockedFolder(widget.path);
              case 'organize':
                await Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => OrganizeScreen(path: widget.path),
                ));
                _load();
              case 'select_all':
                _toggleSelectAll();
              case 'empty_folders':
                await _cleanEmptyFolders();
              case 'export_list':
                await _exportListing();
              case 'refresh':
                _load();
            }
          },
          itemBuilder: (ctx) => [
            _menuItem('hidden',
                appState.fmShowHidden ? AppIcons.hiddenOff : AppIcons.hidden,
                appState.fmShowHidden
                    ? context.t('fm.hide_hidden')
                    : context.t('fm.show_hidden')),
            _menuItem(
                'star',
                starred ? AppIcons.star : AppIcons.starEmpty,
                starred
                    ? context.t('fm.unfavorite')
                    : context.t('fm.favorite')),
            _menuItem(
                'lock',
                appState.isFolderLocked(widget.path)
                    ? AppIcons.unlock
                    : AppIcons.lock,
                appState.isFolderLocked(widget.path)
                    ? context.t('fm.unlock_folder')
                    : context.t('fm.lock_folder')),
            _menuItem('select_all', AppIcons.selectAll, context.t('fm.select_all')),
            const PopupMenuDivider(),
            _menuItem('organize', AppIcons.organize, context.t('fm.auto_organize')),
            _menuItem('empty_folders', AppIcons.cleanEmpty,
                context.t('fm.empty_folders')),
            _menuItem('export_list', AppIcons.exportList,
                context.t('fm.export_list')),
            _menuItem('refresh', AppIcons.refresh, context.t('common.refresh')),
          ],
        ),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String value, IconData icon, String text) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon, size: AppIcons.small),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(text)),
          ],
        ),
      );

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
        onPressed: () => _partSetState(_selected.clear),
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

  /// Geniş ekranın sol bölmesi: birimler + favori klasörler.
  Widget _sidePane(BuildContext context, AppState appState) {
    final scheme = Theme.of(context).colorScheme;
    final here = p.normalize(widget.path);
    Widget tile(IconData icon, String label, String path) {
      final active = FsPaths.isInside(path, here);
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
      subtitle: (e) => e.isDir
          ? _folderSubtitle(e)
          : '${FsPaths.humanSize(e.sizeBytes)} · '
              '${FsPaths.humanDate(e.modifiedMs)}',
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
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
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
        ),
      ),
    );
  }
}

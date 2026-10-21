part of '../browser_screen.dart';

extension _BrowserScreenViewsPart on _BrowserScreenState {
  PreferredSizeWidget _normalBar(BuildContext context) {
    final appState = context.watch<AppState>();
    final starred = appState.isBookmarked(widget.path);
    return AppBar(
      title: Text(widget.title ?? p.basename(widget.path),
          maxLines: 1, overflow: TextOverflow.ellipsis),
      actions: [
        IconButton(
          tooltip: context.t('fm.search_here'),
          icon: const Icon(Icons.search),
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
          onSelected: (value) async {
            switch (value) {
              case 'sort_name':
                appState.setFmSort(FmSort.name);
              case 'sort_date':
                appState.setFmSort(FmSort.date, descending: true);
              case 'sort_size':
                appState.setFmSort(FmSort.size, descending: true);
              case 'sort_type':
                appState.setFmSort(FmSort.type);
              case 'sort_dir':
                appState.setFmSort(appState.fmSort,
                    descending: !appState.fmSortDesc);
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
            PopupMenuItem(
                value: 'sort_name', child: Text(context.t('fm.sort_name'))),
            PopupMenuItem(
                value: 'sort_date', child: Text(context.t('fm.sort_date'))),
            PopupMenuItem(
                value: 'sort_size', child: Text(context.t('fm.sort_size'))),
            PopupMenuItem(
                value: 'sort_type', child: Text(context.t('fm.sort_type'))),
            PopupMenuItem(
              value: 'sort_dir',
              child:
                  Text(appState.fmSortDesc ? context.t('fm.sort_asc') : context.t('fm.sort_desc')),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'hidden',
              child: Text(appState.fmShowHidden
                  ? context.t('fm.hide_hidden')
                  : context.t('fm.show_hidden')),
            ),
            PopupMenuItem(
              value: 'star',
              child: Text(starred
                  ? context.t('fm.unfavorite')
                  : context.t('fm.favorite')),
            ),
            PopupMenuItem(
              value: 'lock',
              child: Text(appState.isFolderLocked(widget.path)
                  ? context.t('fm.unlock_folder')
                  : context.t('fm.lock_folder')),
            ),
            PopupMenuItem(
                value: 'organize', child: Text(context.t('fm.auto_organize'))),
            PopupMenuItem(value: 'select_all', child: Text(context.t('fm.select_all'))),
            const PopupMenuDivider(),
            PopupMenuItem(
                value: 'empty_folders',
                child: Text(context.t('fm.empty_folders'))),
            PopupMenuItem(
                value: 'export_list', child: Text(context.t('fm.export_list'))),
            PopupMenuItem(
                value: 'refresh', child: Text(context.t('common.refresh'))),
          ],
        ),
      ],
    );
  }

  /// Seçim üst çubuğu **sade**: sayaç + seçme yardımcıları. Eylemler
  /// (Taşı/Kopyala/Paylaş/Sil/…) alttaki [FmSelectionBar]'da — proje kuralı:
  /// üstte yalnız altta karşılığı OLMAYAN durur (HAFIZA 2026-07-28 D).
  PreferredSizeWidget _selectionBar(BuildContext context, List<FsEntry> visible) {
    return AppBar(
      leading: IconButton(
        tooltip: context.t('common.clear_selection'),
        icon: const Icon(Icons.close),
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
        if (_selected.length == 1) ...[
          IconButton(
            tooltip: context.t('fm.select_above'),
            icon: const Icon(Icons.expand_less),
            onPressed: () => _selectFromAnchor(visible, above: true),
          ),
          IconButton(
            tooltip: context.t('fm.select_below'),
            icon: const Icon(Icons.expand_more),
            onPressed: () => _selectFromAnchor(visible, above: false),
          ),
        ],
        IconButton(
          tooltip: _allSelected ? context.t('fm.select_none') : context.t('fm.select_all'),
          icon: Icon(_allSelected ? Icons.deselect : Icons.select_all),
          onPressed: _toggleSelectAll,
        ),
        IconButton(
          tooltip: context.t('fm.select_invert'),
          icon: const Icon(Icons.swap_horiz),
          onPressed: () => _partSetState(() {
            final all = _entries.map((e) => e.path).toSet();
            final inverted = all.difference(_selected);
            _selected
              ..clear()
              ..addAll(inverted);
          }),
        ),
      ],
    );
  }

  Widget _pasteBar(AppState appState) {
    final count = appState.clipboard.length;
    return Material(
      color: Theme.of(context).colorScheme.secondaryContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.sm, Gap.sm),
          child: Row(
            children: [
              Icon(appState.clipboardCut
                  ? Icons.content_cut
                  : Icons.copy_outlined),
              const SizedBox(width: Gap.sm),
              Expanded(
                child: Text(
                  context.t('fm.clipboard_ready', {
                    'n': count,
                    'verb': context.t(appState.clipboardCut
                        ? 'fm.verb_move'
                        : 'fm.verb_copy'),
                  }),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: appState.clearClipboard,
                child: Text(context.t('common.cancel')),
              ),
              FilledButton.icon(
                onPressed: _paste,
                icon: const Icon(Icons.content_paste),
                label: Text(context.t('fm.paste')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(List<FsEntry> entries) {
    if (_loading) return const FmListSkeleton();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.lock_outline,
                  size: 56, color: Theme.of(context).colorScheme.outline),
              const SizedBox(height: Gap.md),
              Text(context.t(_error!), textAlign: TextAlign.center),
              const SizedBox(height: Gap.md),
              FilledButton.tonal(
                  onPressed: _load, child: Text(context.t('common.retry'))),
            ],
          ),
        ),
      );
    }
    if (entries.isEmpty) {
      return RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            Icon(Icons.folder_open,
                size: 64, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: Gap.md),
            Center(child: Text(context.t('fm.empty_folder'))),
          ],
        ),
      );
    }

    final layout = context.watch<AppState>().fmLayout;
    return RefreshIndicator(
      onRefresh: _load,
      // Uzun basış artık öğelerde değil BURADA yakalanır (çocuk uzun basışı
      // jest arenasını kazanıp sürüklemeyi öldürürdü) → basılı tutup kaydırınca
      // çapa ile parmağın altındaki öğe arasındaki tüm dosyalar seçilir.
      child: DragSelectArea(
        scrollController: _scroll,
        isSelected: (i) =>
            i >= 0 && i < entries.length && _selected.contains(entries[i].path),
        onSelectRange: (a, b, sel) => _selectRange(entries, a, b, sel),
        child: layout.isGrid ? _grid(entries, layout) : _list(entries, layout),
      ),
    );
  }

  Widget _list(List<FsEntry> entries, FmLayout layout) => ListView.builder(
        controller: _scroll,
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(Gap.sm, Gap.xs, Gap.sm, 96)),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return DragSelectItem(
            index: i,
            child: FmEntryListTile(
              entry: e,
              layout: layout,
              selected: _selected.contains(e.path),
              selecting: _selecting,
              subtitle: e.isDir
                  ? _folderSubtitle(e)
                  : '${FsPaths.humanSize(e.sizeBytes)} · '
                      '${FsPaths.humanDate(e.modifiedMs)}',
              onTap: () => _openEntry(e),
              onCheck: () => _toggle(e),
              onMore: () async {
                if (await showEntryActions(context, e)) _load();
              },
            ),
          );
        },
      );

  Widget _grid(List<FsEntry> entries, FmLayout layout) => LayoutBuilder(
        builder: (context, constraints) {
          const pad = Gap.sm;
          return GridView.builder(
            controller: _scroll,
            padding: withNavInset(
                context, const EdgeInsets.fromLTRB(pad, pad, pad, 96)),
            gridDelegate:
                fmGridDelegate(layout, constraints.maxWidth - pad * 2),
            itemCount: entries.length,
            itemBuilder: (context, i) {
              final e = entries[i];
              return DragSelectItem(
                index: i,
                child: FmEntryGridTile(
                  entry: e,
                  layout: layout,
                  selected: _selected.contains(e.path),
                  selecting: _selecting,
                  onTap: () => _openEntry(e),
                ),
              );
            },
          );
        },
      );

  void _showCreateSheet() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.create_new_folder_outlined),
              title: Text(context.t('fm.new_folder')),
              onTap: () {
                Navigator.pop(ctx);
                _newFolder();
              },
            ),
            ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(context.t('fm.new_word_doc')),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('docx');
              },
            ),
            ListTile(
              leading: const Icon(Icons.table_chart_outlined),
              title: Text(context.t('fm.new_xlsx')),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('xlsx');
              },
            ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: Text(context.t('fm.new_text_file')),
              onTap: () {
                Navigator.pop(ctx);
                _newDocument('txt');
              },
            ),
            const SizedBox(height: Gap.sm),
          ],
        ),
      ),
    );
  }
}

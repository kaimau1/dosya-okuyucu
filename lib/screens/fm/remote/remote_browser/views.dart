part of '../remote_browser_screen.dart';

extension _RemoteBrowserScreenViewsPart on _RemoteBrowserScreenState {
  /// **Güvenle çıkar:** aygıt bırakılır ve ekran kapanır.
  ///
  /// Yazma yaptıysak bu bir güvenlik meselesi: yarıda kalan bir yazma
  /// bozuk dosya bırakır. Aygıtı bıraktığımızı SÖYLEMEK de şart — kullanıcı
  /// "çıkarabilir miyim?" sorusunun cevabını uygulamadan almalı.
  Future<void> _eject() async {
    final messenger = ScaffoldMessenger.of(context);
    final done = context.t('usb.eject_done');
    try {
      await _fs.close();
    } catch (_) {
      // Kapatılamadı — yine de ekrandan çıkıyoruz; aygıt zaten gitmiş olabilir.
    }
    if (!mounted) return;
    popOwnPage(context);
    showSnackOn(messenger, done);
  }

  void _onMenu(String value) {
    if (value == 'eject') {
      unawaited(_eject());
      return;
    }
    if (value == 'upload') {
      unawaited(_upload());
      return;
    }
    if (value == 'mkdir') {
      unawaited(_newFolder());
      return;
    }
    if (value == 'asc') return _partSetState(() => _ascending = !_ascending);
    for (final sort in _RemoteSort.values) {
      if (value == 'sort_${sort.name}') {
        _partSetState(() => _sort = sort);
        return;
      }
    }
  }

  /// Seçim kipindeki başlık çubuğu.
  ///
  /// **"Telefona kopyala" salt okunur bellekte de var** (kullanıcı 2026-09-02
  /// dışarıdan bakış): kopyalamak yazma gerektirmez, oysa eski menü tamamen
  /// `canWrite`e bağlıydı ve NTFS bir diskte uzun basış hiçbir şey yapmıyordu.
  AppBar _selectionAppBar() => AppBar(
        leading: IconButton(
          tooltip: context.t('common.clear_selection'),
          icon: const Icon(AppIcons.close),
          onPressed: () => _partSetState(_selected.clear),
        ),
        title: Text('${_selected.length}'),
        actions: [
          IconButton(
            tooltip: context.t('fm.select_all'),
            icon: const Icon(AppIcons.selectAll),
            onPressed: () => _partSetState(() {
              final all = _visible.map((e) => e.path).toSet();
              if (_selected.containsAll(all)) {
                _selected.clear();
              } else {
                _selected.addAll(all);
              }
            }),
          ),
          IconButton(
            tooltip: context.t('nas.copy_to_phone'),
            icon: const Icon(AppIcons.download),
            onPressed: _busy ? null : () => unawaited(_copyToPhone()),
          ),
          if (_fs.canWrite) ...[
            if (_selected.length == 1)
              IconButton(
                tooltip: context.t('nas.rename'),
                icon: const Icon(AppIcons.rename),
                onPressed: _busy
                    ? null
                    : () => _rename(_entryOf(_selected.first)!),
              ),
            IconButton(
              tooltip: context.t('common.delete'),
              icon: const Icon(AppIcons.delete),
              onPressed: _busy ? null : () => unawaited(_deleteSelected()),
            ),
          ],
        ],
      );

  RemoteEntry? _entryOf(String path) {
    for (final e in _entries) {
      if (e.path == path) return e;
    }
    for (final list in _usbCats.values) {
      for (final e in list) {
        if (e.path == path) return e;
      }
    }
    for (final e in _usbRecent) {
      if (e.path == path) return e;
    }
    return null;
  }

  /// **Seçilenleri telefona kopyalar** — Ana Menü hedef seçici, çakışma koruması
  /// ve canlı MB/GB ilerleme penceresiyle.
  Future<void> _copyToPhone() async {
    final targets = [
      for (final path in _selected) ?_entryOf(path),
    ];
    final files = [for (final e in targets) if (!e.isDir) e];
    final skippedDirs = targets.length - files.length;
    if (files.isEmpty) {
      _snack(context.t('nas.copy_only_files'));
      return;
    }
    final dest = await Navigator.of(context).push<String>(MaterialPageRoute(
      builder: (_) => FolderPickerScreen(
        sources: const [],
        homeCards: true,
        itemCount: files.length,
        itemTitle: files.length == 1 ? files.first.name : null,
        actionLabel: context.t('fm.copy_here'),
      ),
    ));
    if (dest == null || !mounted) return;

    final collisions = <String>[];
    for (final f in files) {
      if (await File(p.join(dest, f.name)).exists()) {
        collisions.add(f.name);
      }
    }
    if (!mounted) return;
    var conflict = FmConflict.rename;
    if (collisions.isNotEmpty) {
      final chosen = await showPasteConflictSheet(context, names: collisions);
      if (chosen == null || !mounted) return;
      conflict = chosen;
    }

    final messenger = ScaffoldMessenger.of(context);
    final okText = context.t('nas.copied_to_phone');
    final openText = context.t('common.open');
    final skippedText = context.t('nas.copy_skipped_dirs');
    final title = context.t('fm.copying');
    final jobName = context.t('fm.copying_name');
    final totalBytes = files.fold<int>(0, (sum, e) => sum + e.sizeBytes);

    var done = 0;
    var bytesDone = 0;
    final copied = <String>[];
    String? failed;
    var cancelled = false;

    try {
      await showFmProgress<void>(
        context,
        title: title,
        name: jobName,
        task: (report, isCancelled) async {
          await Directory(dest).create(recursive: true);
          for (final entry in files) {
            if (isCancelled()) {
              cancelled = true;
              break;
            }
            var target = p.join(dest, entry.name);
            if (await File(target).exists()) {
              switch (conflict) {
                case FmConflict.skip:
                  done++;
                  bytesDone += entry.sizeBytes;
                  report(FmProgress(done, files.length, entry.name,
                      bytesDone: bytesDone, bytesTotal: totalBytes));
                  continue;
                case FmConflict.rename:
                  target = await _RemoteBrowserScreenState._uniquePath(
                      dest, entry.name);
                case FmConflict.overwrite:
                  break;
              }
            }
            report(FmProgress(done, files.length, entry.name,
                bytesDone: bytesDone, bytesTotal: totalBytes));
            try {
              final downloaded = await _fs.downloadWithProgress(
                entry,
                target,
                onProgress: (received) {
                  report(FmProgress(
                    done,
                    files.length,
                    entry.name,
                    bytesDone: bytesDone + received,
                    bytesTotal: totalBytes,
                  ));
                },
                isCancelled: isCancelled,
              );
              copied.add(downloaded.path);
              done++;
              bytesDone += entry.sizeBytes;
              report(FmProgress(done, files.length, entry.name,
                  bytesDone: bytesDone, bytesTotal: totalBytes));
            } on UsbTransferCancelled {
              cancelled = true;
              break;
            } on JobCancelled {
              cancelled = true;
              break;
            } catch (_) {
              failed ??= entry.name;
            }
          }
        },
      );
    } on UsbTransferCancelled {
      cancelled = true;
    } on JobCancelled {
      cancelled = true;
    }

    if (copied.isNotEmpty) {
      await FreshCache.noteAdded(copied);
      FsEvents.changed(copied);
      try {
        if (mounted) {
          await context.read<AppState>().rememberDestination(dest);
        }
      } catch (_) {
        // Test ortamında AppState Provider yoksa güvenle atlanır.
      }
    }
    if (!mounted) return;
    _partSetState(_selected.clear);
    final parts = <String>[
      if (cancelled) context.t('pd.cancel') else '$okText ($done/${files.length})',
      if (skippedDirs > 0) '$skippedDirs $skippedText',
      if (failed != null) '· $failed',
    ];
    showSnackOn(
      messenger,
      parts.join(' '),
      duration: kSnackAction,
      action: copied.isEmpty
          ? null
          : SnackBarAction(
              label: openText,
              onPressed: () => unawaited(Navigator.of(context).push(
                  browserRoute(BrowserScreen(path: dest)))),
            ),
    );
  }

  Future<void> _deleteSelected() async {
    final entries = [
      for (final path in _selected)
        ?_entryOf(path),
    ];
    if (entries.isEmpty) return;
    // Tek dosyada ADIYLA sor: "1 öğe silinsin mi?" demek, yanlış dosyayı
    // seçmiş kullanıcıya hiçbir şey söylemez.
    if (entries.length == 1) {
      await _delete(entries.first);
      if (mounted) _partSetState(_selected.clear);
      return;
    }
    final ok = await showAppConfirm(
        context,
        title: context.t('common.delete'),
        message: context.t('nas.delete_many', {'n': '${entries.length}'}),
        confirmLabel: context.t('common.delete'),
        destructive: true,
    );
    if (ok != true || !mounted) return;
    _partSetState(() => _busy = true);
    for (final entry in entries) {
      try {
        await _fs.delete(entry);
      } catch (_) {
        // tek dosya silinemedi — kalanlara devam
      }
    }
    if (!mounted) return;
    _partSetState(_selected.clear);
    await _load(_path);
  }

  Widget _body() {
    if (_busy) return const FmListSkeleton();
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(AppIcons.cloudOff, size: 48),
              const SizedBox(height: 12),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => _connected ? _load(_path) : _start(),
                child: Text(context.t('common.refresh')),
              ),
            ],
          ),
        ),
      );
    }

    if (_inUsbHome && _usbCat == null) {
      return _usbHomeBody();
    }

    final isSmbRoot = widget.connection.protocol == RemoteProtocol.smb &&
        (_path == '/' || _path.isEmpty);
    final showingCategory = _inUsbHome && _usbCat != null;

    return Column(
      children: [
        if (showingCategory)
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.xs, Gap.md, 0),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ActionChip(
                avatar: const Icon(AppIcons.back, size: 16),
                label: Text(context.t('usb.view_home')),
                onPressed: () => _partSetState(() => _usbCat = null),
              ),
            ),
          ),
        // Toplu iş sürerken kaç dosya bitti? Sessiz bir bekleme, kullanıcıya
        // "takıldı mı?" dedirtiyordu.
        if (_progress != null)
          LinearProgressIndicator(
            value: _progressValue,
            minHeight: 3,
          ),
        if (_progress != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text('${context.t('nas.copying')} $_progress',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        if (isSmbRoot)
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.surfaceContainerHigh,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text(context.t('nas.smb_share_root'),
                style: Theme.of(context).textTheme.bodySmall),
          ),
        Expanded(
          child: _visible.isEmpty
              ? _filter.trim().isEmpty
                  ? FmEmptyState(
                      icon: AppIcons.folder,
                      title: context.t('nas.empty_folder'))
                  : FmEmptyState(
                      icon: AppIcons.searchOff,
                      title: context.t('nas.no_match'))
              : RefreshIndicator(
                  onRefresh: () =>
                      showingCategory ? _scanUsbHome() : _load(_path),
                  child: ListView.separated(
                    itemCount: _visible.length +
                        ((showingCategory || _atRoot) ? 0 : 1),
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (!showingCategory && !_atRoot && i == 0) {
                        return ListTile(
                          leading: const Icon(AppIcons.arrowUp),
                          title: const Text('..'),
                          onTap: _selecting ? null : _up,
                        );
                      }
                      final entry = _visible[
                          (showingCategory || _atRoot) ? i : i - 1];
                      return _entryTile(entry);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _entryTile(RemoteEntry entry) {
    final selected = _selected.contains(entry.path);
    final category = FsEntry.categoryForExtension(
        p.extension(entry.name).replaceFirst('.', ''),
        isDir: entry.isDir);
    return ListTile(
      selected: selected,
      leading: selected
          ? const Icon(AppIcons.checkCircle)
          : Icon(FmColors.iconFor(category),
              color: FmColors.forCategory(category)),
      title: Text(entry.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(_subtitle(entry)),
      onTap: () => _selecting ? _toggle(entry) : _open(entry),
      onLongPress: () => _toggle(entry),
    );
  }

  Widget _usbHomeBody() {
    String sub(FmCategory c) {
      final list = _usbCats[c] ?? const <RemoteEntry>[];
      if (list.isEmpty) return context.t('fm.none');
      final total = list.fold<int>(0, (s, e) => s + e.sizeBytes);
      return '${FsPaths.humanSize(total)} (${list.length})';
    }

    FmTileData cat(FmCategory c, FmTileArt? art) => FmTileData(
          id: 'usb_raw_${c.name}',
          icon: FmColors.iconFor(c),
          color: FmColors.forCategory(c),
          art: art,
          label: context.t(c.labelKey),
          subtitle: sub(c),
          onTap: () => _partSetState(() => _usbCat = c),
        );

    final q = _filter.trim().toLowerCase();
    final recent = [
      for (final e in _usbRecent)
        if (q.isEmpty || e.name.toLowerCase().contains(q)) e,
    ];
    final totalFound = _usbCats.values.fold<int>(0, (s, l) => s + l.length);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: _scanUsbHome,
      child: ListView(
        padding: withNavInset(
            context, const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.md, Gap.xl)),
        children: [
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(AppIcons.external, size: 28, color: scheme.primary),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.connection.name,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_usage.isNotEmpty || _readOnlyNote.isNotEmpty)
                              Text(
                                [
                                  if (_usage.isNotEmpty) _usage,
                                  if (_readOnlyNote.isNotEmpty) _readOnlyNote,
                                ].join(' · '),
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Gap.sm),
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton.icon(
                      onPressed: () => unawaited(_toggleUsbView(false)),
                      icon: const Icon(AppIcons.folder, size: 18),
                      label: Text(context.t('usb.all_folders')),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_scanningHome)
            const Padding(
              padding: EdgeInsets.only(top: Gap.sm),
              child: LinearProgressIndicator(minHeight: 2),
            ),
          const SizedBox(height: Gap.md),
          FmCategoryGrid(
            tiles: [
              cat(FmCategory.document, FmTileArt.document),
              cat(FmCategory.image, FmTileArt.photos),
              cat(FmCategory.video, FmTileArt.video),
              cat(FmCategory.audio, FmTileArt.audio),
              cat(FmCategory.archive, null),
              FmTileData(
                id: 'usb_raw_folders',
                icon: AppIcons.folder,
                color: AppHues.teal,
                label: context.t('usb.all_folders'),
                subtitle: '$totalFound',
                onTap: () => unawaited(_toggleUsbView(false)),
              ),
            ],
          ),
          SectionHeader(
            context.t('usb.recent_on_drive'),
            padding: const EdgeInsets.only(top: Gap.lg, bottom: Gap.xs),
          ),
          if (recent.isEmpty && !_scanningHome)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: Gap.lg),
              child: Text(
                context.t('usb.empty_drive'),
                textAlign: TextAlign.center,
              ),
            )
          else
            for (final entry in recent) _entryTile(entry),
        ],
      ),
    );
  }

  /// İlerleme çubuğunun değeri ("3/12" → 0.25); okunamazsa belirsiz çubuk.
  double? get _progressValue {
    final parts = _progress?.split('/');
    if (parts == null || parts.length != 2) return null;
    final done = int.tryParse(parts[0]);
    final total = int.tryParse(parts[1]);
    if (done == null || total == null || total == 0) return null;
    return done / total;
  }

  void _toggle(RemoteEntry entry) => _partSetState(() {
        if (!_selected.remove(entry.path)) _selected.add(entry.path);
      });

  String _subtitle(RemoteEntry entry) {
    final parts = <String>[
      if (!entry.isDir) FsPaths.humanSize(entry.sizeBytes),
      if (entry.modifiedMs > 0) FsPaths.humanDate(entry.modifiedMs),
    ];
    return parts.join(' · ');
  }
}

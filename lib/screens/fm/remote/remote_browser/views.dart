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
    showSnackOn(messenger, done, duration: kSnackAction);
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
    return null;
  }

  /// **Seçilenleri telefona kopyalar** — USB'nin bir numaralı kullanım amacı.
  ///
  /// Hedef `İndirilenler/Dosya Okuyucu`: kullanıcının ULAŞABİLECEĞİ bir yer.
  /// (Dosyayı açmak da kopyalıyor ama uygulamanın özel klasörüne; oraya
  /// kullanıcı giremez, dolayısıyla "kopyaladım" sayılmaz.)
  ///
  /// Klasörler bu turda atlanıyor ve sayısı kullanıcıya SÖYLENİYOR — sessizce
  /// atlamak "kopyaladım sandım" demek olurdu.
  Future<void> _copyToPhone() async {
    final targets = [
      for (final path in _selected)
        if (_entryOf(path) case final e?) e,
    ];
    final files = [for (final e in targets) if (!e.isDir) e];
    final skippedDirs = targets.length - files.length;
    if (files.isEmpty) {
      _snack(context.t('nas.copy_only_files'));
      return;
    }
    final dir = p.join(FmEnv.primaryRoot, 'Download', 'Dosya Okuyucu');
    final messenger = ScaffoldMessenger.of(context);
    final okText = context.t('nas.copied_to_phone');
    final openText = context.t('common.open');
    final skippedText = context.t('nas.copy_skipped_dirs');
    _partSetState(() {
      _busy = true;
      _progress = '0/${files.length}';
    });
    var done = 0;
    String? failed;
    try {
      await Directory(dir).create(recursive: true);
      for (final entry in files) {
        try {
          await _fs.download(entry, _RemoteBrowserScreenState._uniquePath(dir, entry.name));
          done++;
        } catch (e) {
          failed ??= entry.name;
        }
        if (!mounted) return;
        _partSetState(() => _progress = '$done/${files.length}');
      }
    } finally {
      if (mounted) {
        _partSetState(() {
          _busy = false;
          _progress = null;
        });
      }
    }
    if (!mounted) return;
    _partSetState(_selected.clear);
    final parts = <String>[
      '$okText ($done/${files.length})',
      if (skippedDirs > 0) '$skippedDirs $skippedText',
      if (failed != null) '· $failed',
    ];
    showSnackOn(
      messenger,
      parts.join(' '),
      duration: kSnackAction,
      action: SnackBarAction(
        label: openText,
        onPressed: () => unawaited(Navigator.of(context).push(
            browserRoute(BrowserScreen(path: dir)))),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final entries = [
      for (final path in _selected)
        if (_entryOf(path) case final e?) e,
    ];
    if (entries.isEmpty) return;
    // Tek dosyada ADIYLA sor: "1 öğe silinsin mi?" demek, yanlış dosyayı
    // seçmiş kullanıcıya hiçbir şey söylemez.
    if (entries.length == 1) {
      await _delete(entries.first);
      if (mounted) _partSetState(_selected.clear);
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('common.delete')),
        content: Text(ctx.t('nas.delete_many', {'n': '${entries.length}'})),
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
              const Icon(Icons.cloud_off_rounded, size: 48),
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

    final isSmbRoot = widget.connection.protocol == RemoteProtocol.smb &&
        (_path == '/' || _path.isEmpty);

    return Column(
      children: [
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
              ? Center(
                  child: Text(_filter.trim().isEmpty
                      ? context.t('nas.empty_folder')
                      : context.t('nas.no_match')))
              : RefreshIndicator(
                  onRefresh: () => _load(_path),
                  child: ListView.separated(
                    itemCount: _visible.length + (_atRoot ? 0 : 1),
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      if (!_atRoot && i == 0) {
                        return ListTile(
                          leading: const Icon(AppIcons.arrowUp),
                          title: const Text('..'),
                          onTap: _selecting ? null : _up,
                        );
                      }
                      final entry = _visible[_atRoot ? i : i - 1];
                      final selected = _selected.contains(entry.path);
                      // **Tür simgesi ve rengi** (kullanıcı 2026-09-02
                      // dışarıdan bakış): jenerik "dosya" simgesi listeyi
                      // okunmaz yapıyordu; yerel gezginle aynı dil.
                      final category = FsEntry.categoryForExtension(
                          p.extension(entry.name).replaceFirst('.', ''),
                          isDir: entry.isDir);
                      return ListTile(
                        selected: selected,
                        leading: selected
                            ? const Icon(AppIcons.checkCircle)
                            : Icon(FmColors.iconFor(category),
                                color: FmColors.forCategory(category)),
                        title: Text(entry.name,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        subtitle: Text(_subtitle(entry)),
                        onTap: () => _selecting
                            ? _toggle(entry)
                            : _open(entry),
                        // Uzun basış HER ZAMAN seçim başlatır (salt okunur
                        // bellekte de): kopyalamak yazma gerektirmiyor.
                        onLongPress: () => _toggle(entry),
                      );
                    },
                  ),
                ),
        ),
      ],
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

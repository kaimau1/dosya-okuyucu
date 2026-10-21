part of '../scan_result_screen.dart';

extension _ScanResultScreenActionsPart on _ScanResultScreenState {
  /// Sayfa listesini değiştirir: önceki hâli geri alma yığınına koyar ve
  /// kaydı (kısa bir beklemeyle — art arda döndürmeler tek yazım olsun)
  /// planlar.
  void _commit(List<ScanPage> next, {int? index}) {
    _history.add(_pages);
    if (_history.length > _ScanResultScreenState._historyLimit) _history.removeAt(0);
    _partSetState(() {
      _pages = next;
      if (index != null) _index = index;
      _index = _index.clamp(0, _pages.length - 1);
      _dirty = true;
    });
    _scheduleSave();
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _save);
  }

  /// Bekleyen değişikliği yazar. Yazımlar sıraya girer (aynı dosyaya iki
  /// yazım aynı anda koşmaz); yazım sürerken gelen değişiklik bir sonraki
  /// turda yazılır.
  Future<void> _save() {
    _saveTimer?.cancel();
    final previous = _saving ?? Future<void>.value();
    late final Future<void> run;
    run = previous.then((_) async {
      if (!_dirty) return;
      _dirty = false;
      final snapshot = List<ScanPage>.of(_pages);
      if (mounted) _partSetState(() => _saveState = _SaveState.saving);
      try {
        await _saver(_pdfPath, snapshot, _ocr);
        if (!_logged) {
          _logged = true;
          unawaited(ActivityLog.add(ActivityKind.scan, _pdfPath));
        }
        if (mounted && !_dirty) {
          _partSetState(() => _saveState = _SaveState.saved);
        }
      } catch (e) {
        _dirty = true;
        if (mounted) {
          _partSetState(() => _saveState = _SaveState.failed);
          showSnack(context, context.t('sf.save_failed', {'error': e}),
              copyable: true);
        }
      }
    }).whenComplete(() {
      if (identical(_saving, run)) {
        _saving = null;
        if (mounted) _partSetState(() {});
      }
    });
    _saving = run;
    return run;
  }

  /// Ekrandan çıkmadan / paylaşmadan önce bekleyen her şeyi yazar.
  Future<void> _flush() async {
    if (_dirty) await _save();
    while (_saving != null) {
      await _saving;
    }
  }

  Future<void> _leave() async {
    final busy = showBusyDialog(
      context,
      builder: (ctx) => AlertDialog(
        content: Row(
          children: [
            const SizedBox(
                width: 22, height: 22, child: CircularProgressIndicator()),
            const SizedBox(width: Gap.md),
            Expanded(child: Text(ctx.t('ss.finishing'))),
          ],
        ),
      ),
    );
    await _flush();
    busy.close();
    // Yazım başarısız olsa da kullanıcı ekranda HAPSOLMAZ: hata bildirimi
    // zaten gösterildi, diskteki PDF son başarılı hâlinde duruyor.
    if (mounted) Navigator.of(context).pop();
  }

  /// Görünen sayfaya [label] başlığıyla bir iş uygular; iş yeni sayfayı
  /// döndürür (null = değişiklik yok).
  Future<void> _runOnPage(
      String label, Future<ScanPage?> Function(ScanPage page) job) async {
    if (_busy || _pages.isEmpty) return;
    final index = _index;
    final before = _pages[index];
    _partSetState(() => _work = label);
    try {
      final next = await job(before);
      if (!mounted) return;
      if (next != null) {
        _commit([
          for (var i = 0; i < _pages.length; i++)
            i == index ? next : _pages[i],
        ]);
      }
    } catch (e) {
      if (mounted) {
        showSnack(context, context.t('scr.add_failed', {'error': e}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  Future<void> _crop() async {
    if (_busy || _pages.isEmpty) return;
    final page = _pages[_index];
    final quad = await ScanEditScreen.open(context, page.source);
    if (quad == null || !mounted) return;
    await _runOnPage(context.t('ss.working_crop'), (page) async {
      final cropped = await ScanPageOps.warp(page.source, quad);
      return _ScanResultScreenState._withFilter(cropped, page.filter);
    });
  }

  Future<void> _rotate() => _runOnPage(context.t('ss.working_rotate'),
          (page) async {
        final source = await ScanPageOps.rotate(page.source, 1);
        if (page.filter == ScanFilter.original) return ScanPage.raw(source);
        // Filtrelenmiş görseli de döndür: filtreyi baştan koşturmaktan
        // hızlı ve sonuç birebir aynı.
        final display = await ScanPageOps.rotate(page.display, 1);
        return ScanPage(source: source, display: display, filter: page.filter);
      });

  Future<void> _filter() async {
    if (_busy || _pages.isEmpty) return;
    final page = _pages[_index];
    final choice = await showModalBottomSheet<_FilterChoice>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => _FilterSheet(
        source: page.source,
        current: page.filter,
        pageCount: _pages.length,
      ),
    );
    if (choice == null || !mounted) return;
    if (choice.straighten) {
      await _straighten();
      return;
    }
    if (!choice.all) {
      if (choice.filter == page.filter) return;
      await _runOnPage(context.t('ss.working_filter'),
          (page) => _ScanResultScreenState._withFilter(page.source, choice.filter));
      return;
    }
    // Tüm sayfalar: sırayla (aynı anda tek büyük görsel bellekte).
    _partSetState(() => _work = context.t('ss.working_filter'));
    try {
      final next = <ScanPage>[];
      for (final page in _pages) {
        next.add(page.filter == choice.filter
            ? page
            : await _ScanResultScreenState._withFilter(page.source, choice.filter));
      }
      if (mounted) _commit(next);
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  Future<void> _straighten() async {
    var changed = false;
    await _runOnPage(context.t('ss.working_straighten'), (page) async {
      final target = await ScanDewarp.tempTarget(page.source);
      final produced = await compute(
        ScanDewarp.runRequest,
        ScanStraightenRequest(sourcePath: page.source, targetPath: target),
      );
      if (produced == null) return null;
      changed = true;
      return _ScanResultScreenState._withFilter(produced, page.filter);
    });
    if (mounted) {
      showSnack(context,
          context.t(changed ? 'sr.straightened' : 'sr.straighten_noop'));
    }
  }

  /// Görünen sayfayı yeniden çeker (tek sayfalık tarama, yerine konur).
  Future<void> _retake() async {
    if (_busy || _pages.isEmpty) return;
    List<String>? shot;
    try {
      shot = await DocumentScanner.scanPages(maxPages: 1);
    } catch (e) {
      if (mounted) _snack(context.t('sf.scanner_failed', {'error': e}));
      return;
    }
    if (shot == null || shot.isEmpty || !mounted) return;
    final index = _index;
    _commit([
      for (var i = 0; i < _pages.length; i++)
        i == index ? ScanPage.raw(shot.first) : _pages[i],
    ]);
  }

  void _delete() {
    if (_busy || _pages.isEmpty) return;
    if (_pages.length == 1) {
      _snack(context.t('sr.last_page'));
      return;
    }
    final index = _index;
    _commit([..._pages]..removeAt(index));
    if (_pager.hasClients) _pager.jumpToPage(_index);
    showSnack(
      context,
      context.t('ss.page_deleted'),
      action: SnackBarAction(label: context.t('common.undo'), onPressed: _undo),
    );
  }

  void _undo() {
    if (_history.isEmpty || _busy) return;
    _partSetState(() {
      _pages = _history.removeLast();
      _index = _index.clamp(0, _pages.length - 1);
      _dirty = true;
    });
    if (_pager.hasClients) _pager.jumpToPage(_index);
    _scheduleSave();
  }

  void _reorder(int from, int to) {
    if (to > from) to -= 1;
    if (from == to) return;
    final next = [..._pages];
    final page = next.removeAt(from);
    next.insert(to, page);
    _commit(next, index: to);
    if (_pager.hasClients) _pager.jumpToPage(to);
  }

  void _goTo(int index) {
    _partSetState(() => _index = index);
    if (_pager.hasClients) {
      _pager.animateToPage(index,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic);
    }
  }

  Future<void> _addPages() async {
    if (_busy) return;
    final source = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: Gap.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const _SheetIcon(Icons.document_scanner_outlined),
                title: Text(ctx.t('ss.add_camera')),
                subtitle: Text(ctx.t('ss.add_camera_sub')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const _SheetIcon(Icons.photo_library_outlined),
                title: Text(ctx.t('ss.add_gallery')),
                subtitle: Text(ctx.t('ss.add_gallery_sub')),
                onTap: () => Navigator.pop(ctx, 'gallery'),
              ),
            ],
          ),
        ),
      ),
    );
    if (source == null || !mounted) return;
    if (source == 'camera') {
      List<String>? more;
      try {
        more = await DocumentScanner.scanPages();
      } catch (e) {
        if (mounted) _snack(context.t('sf.scanner_failed', {'error': e}));
        return;
      }
      if (more == null || more.isEmpty || !mounted) return;
      final first = _pages.length;
      _commit([..._pages, for (final path in more) ScanPage.raw(path)],
          index: first);
      if (_pager.hasClients) _pager.jumpToPage(first);
      _snack(context.t('scr.pages_added', {'n': more.length}));
      return;
    }
    await _addFromGallery();
  }

  /// Galeriden fotoğraf ekler. Fotoğraf HAM çekimdir (tarayıcı kırpmadı):
  /// tek fotoğrafta kırpma ekranı kâğıt kenarı bulunmuş olarak hemen açılır.
  /// Tarayıcının resimli sayfayı yanlış kırptığı durumda kullanıcının
  /// elindeki tam denetimli yol budur.
  Future<void> _addFromGallery() async {
    final res = await FilePicker.platform
        .pickFiles(type: FileType.image, allowMultiple: true);
    final paths = [
      for (final f in res?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    final first = _pages.length;
    var added = [for (final path in paths) ScanPage.raw(path)];
    if (paths.length == 1) {
      final quad =
          await ScanEditScreen.open(context, paths.first, autoDetect: true);
      if (!mounted) return;
      if (quad != null) {
        _partSetState(() => _work = context.t('ss.working_crop'));
        try {
          added = [ScanPage.raw(await ScanPageOps.warp(paths.first, quad))];
        } catch (e) {
          if (mounted) _snack(context.t('se.failed', {'error': e}));
        } finally {
          if (mounted) _partSetState(() => _work = null);
        }
      }
    }
    if (!mounted) return;
    _commit([..._pages, ...added], index: first);
    if (_pager.hasClients) _pager.jumpToPage(first);
    _snack(context.t('scr.pages_added', {'n': added.length}));
  }

  Future<void> _share() async {
    await _flush();
    if (!mounted) return;
    await Share.shareXFiles([XFile(_pdfPath)], text: p.basename(_pdfPath));
  }

  Future<void> _openPdf() async {
    await _flush();
    if (!mounted) return;
    await EntryOpener.open(context, _pdfPath);
  }

  Future<void> _recognize() async {
    _partSetState(() => _work = context.t('vw.ocr_running'));
    try {
      for (final page in _pages) {
        if (_ocr.containsKey(page.source)) continue;
        final lines = await DocumentScanner.recognizePages([page.display]);
        _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
      }
      if (!mounted) return;
      _dirty = true;
      _scheduleSave(); // görünmez metin katmanı PDF'e de girsin
      if (_text.isEmpty) _snack(context.t('vw.ocr_none'));
    } catch (e) {
      if (mounted) _snack(context.t('vw.ocr_failed', {'error': e}));
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  Future<void> _translate() async {
    await TranslateFlow.runDocument(
      context,
      title: p.basename(_pdfPath),
      load: (progress) async {
        if (_text.isNotEmpty) return _text;
        progress.status(AppStrings.of(context).t('vw.ocr_running'));
        for (final page in _pages) {
          if (_ocr.containsKey(page.source)) continue;
          final lines = await DocumentScanner.recognizePages([page.display]);
          _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
        }
        if (mounted) _partSetState(() {});
        return _text;
      },
    );
  }

  /// Dosya adını değiştirir (uzantı sabit kalır). Ad OCR'dan kendiliğinden
  /// gelir; burası "beğenmedim" yolu.
  Future<void> _rename() async {
    await _flush();
    if (!mounted) return;
    final controller =
        TextEditingController(text: p.basenameWithoutExtension(_pdfPath));
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('scr.rename')),
        content: TextField(
          controller: controller,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.t('common.ok')),
          ),
        ],
      ),
    );
    controller.dispose();
    final clean = name?.trim();
    if (clean == null || clean.isEmpty || !mounted) return;
    try {
      final old = _pdfPath;
      final newPath = await FileOps.rename(_pdfPath, '$clean.pdf');
      if (!mounted) return;
      _partSetState(() => _pdfPath = newPath);
      // "Son belgeler" kaydı yolla eşleşir; ad değişince eski kayıt ölü
      // bağlantıya dönerdi.
      await EntryOpener.rememberFile(context, newPath, previousPath: old);
    } catch (e) {
      if (mounted) _snack(context.t('scr.rename_failed', {'error': e}));
    }
  }

  /// PDF'i kullanıcının seçtiği klasöre **taşır**.
  Future<void> _changeLocation() async {
    await _flush();
    if (!mounted) return;
    final target = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => FolderPickerScreen(
          sources: [_pdfPath],
          actionLabel: context.t('scr.save_here'),
        ),
      ),
    );
    if (target == null || !mounted || target == _folder) return;
    await _moveTo(target);
  }

  /// Önerilen tür klasörüne taşır (yoksa kurulur).
  Future<void> _acceptClassFolder() async {
    final target = _suggestedFolder;
    if (target == null) return;
    await _flush();
    try {
      await Directory(target).create(recursive: true);
    } catch (_) {}
    if (!mounted) return;
    _partSetState(() => _classGuess = null);
    await _moveTo(target);
  }

  Future<void> _moveTo(String target) async {
    _partSetState(() => _work = context.t('ss.moving'));
    final old = _pdfPath;
    final result = await FileOps.moveAll([_pdfPath], target);
    if (!mounted) return;
    _partSetState(() => _work = null);
    if (result.transfers.isNotEmpty) {
      _partSetState(() => _pdfPath = result.transfers.first.dest);
      await EntryOpener.rememberFile(context, _pdfPath, previousPath: old);
      if (!mounted) return;
      _snack(context.t('scr.moved', {'folder': p.basename(_folder)}));
    } else {
      _snack(result.errors.isEmpty
          ? context.t('scr.move_failed', {'error': '-'})
          : context.t('scr.move_failed', {'error': result.errors.first}));
    }
  }

  void _snack(String msg) => showSnack(context, msg);
}

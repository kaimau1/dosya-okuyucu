part of '../scan_result_screen.dart';

extension _ScanResultScreenActionsPart on _ScanResultScreenState {
  static const autoSaveDelay = Duration(milliseconds: 1500);

  /// Sayfa listesini değiştirir: önceki hâli geri alma yığınına koyar ve
  /// kaydı planlar.
  void _commit(List<ScanPage> next, {int? index}) {
    _history.add(_pages);
    if (_history.length > _ScanResultScreenState._historyLimit) {
      _history.removeAt(0);
    }
    _partSetState(() {
      _pages = next;
      if (index != null) _index = index;
      _index = _index.clamp(0, _pages.length - 1);
      _comparingOriginal = false;
      _dirty = true;
    });
    _scrollThumbTo(_index);
    _scheduleSave();
    unawaited(_measureVisible());
    if (_filterStripOpen && _pages.isNotEmpty) {
      unawaited(_ensurePreviews(_pages[_index].source));
    }
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    final delay = widget.saver != null ? autoSaveDelay ~/ 3 : autoSaveDelay;
    _saveTimer = Timer(delay, _save);
  }

  void _scrollThumbTo(int index) {
    if (!_thumbScroll.hasClients || _pages.isEmpty) return;
    const itemWidth = 62.0; // 54 genişlik + 8 boşluk
    final pos = _thumbScroll.position;
    final target = (index * itemWidth - (pos.viewportDimension - 54) / 2)
        .clamp(0.0, pos.maxScrollExtent);
    final duration = Motion.of(context, Motion.short);
    if (duration == Duration.zero) {
      _thumbScroll.jumpTo(target);
    } else {
      unawaited(
          _thumbScroll.animateTo(target, duration: duration, curve: Curves.easeOut));
    }
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
          showSnack(
              context, context.t('sf.save_failed', {'error': userErrorText(e)}),
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
        showSnack(
            context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  Future<void> _crop() async {
    if (_busy || _pages.isEmpty) return;
    final page = _pages[_index];
    final res = await ScanEditScreen.open(context, page.source);
    if (!res.isCropped || !mounted) return;
    final quad = res.corners!;
    await _runOnPage(context.t('ss.working_crop'), (page) async {
      final cropped = await ScanPageOps.warp(page.source, quad);
      return _ScanResultScreenState._withFilter(cropped, page.filter);
    });
  }

  Future<void> _rotate() => _rotateBy(1);

  Future<void> _rotateLeft() => _rotateBy(3);

  Future<void> _rotateBy(int quarterTurns) =>
      _runOnPage(context.t('ss.working_rotate'), (page) async {
        final source = await ScanPageOps.rotate(page.source, quarterTurns);
        if (page.filter == ScanFilter.original) return ScanPage.raw(source);
        final display = await ScanPageOps.rotate(page.display, quarterTurns);
        return ScanPage(source: source, display: display, filter: page.filter);
      });

  /// Filtreyi TEK dokunuşla kaldırır.
  Future<void> _clearFilter() async {
    if (_busy || _pages.isEmpty) return;
    if (_pages[_index].filter == ScanFilter.original) return;
    await _runOnPage(
        context.t('ss.working_filter'),
        (page) => _ScanResultScreenState._withFilter(
            page.source, ScanFilter.original));
  }

  /// Yerinde canlı filtre şeridini açar/kapatır ve aktif sayfanın 6 filtre
  /// önizlemesini `page.source` bazında önbellekten yükler.
  Future<void> _filter() async {
    if (_busy || _pages.isEmpty) return;
    _partSetState(() {
      if (_grid) {
        _grid = false;
        _resetPager();
        _filterStripOpen = true;
      } else {
        _filterStripOpen = !_filterStripOpen;
      }
    });
    if (_filterStripOpen) {
      unawaited(_ensurePreviews(_pages[_index].source));
    }
  }

  /// Yerinde canlı filtre şeridinden seçilen filtreyi uygular.
  Future<void> _applyLiveFilter(ScanFilter filter) async {
    if (_busy || _pages.isEmpty) return;
    if (!_applyFilterToAll) {
      if (filter == _pages[_index].filter) return;
      await _runOnPage(
          context.t('ss.working_filter'),
          (page) => _ScanResultScreenState._withFilter(page.source, filter));
      return;
    }
    if (_pages.every((p) => p.filter == filter)) return;
    _partSetState(() => _work = context.t('ss.working_filter'));
    try {
      final next = <ScanPage>[];
      for (final page in _pages) {
        next.add(page.filter == filter
            ? page
            : await _ScanResultScreenState._withFilter(page.source, filter));
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

  /// Görünen sayfayı yeniden çeker (tek sayfalık tarama, önceki filtre korunarak
  /// yerine konur).
  Future<void> _retake() async {
    if (_busy || _pages.isEmpty) return;
    List<String>? shot;
    try {
      shot = await DocumentScanner.scanPages(maxPages: 1);
    } catch (e) {
      if (mounted) {
        _snack(context.t('sf.scanner_failed', {'error': userErrorText(e)}));
      }
      return;
    }
    if (shot == null || shot.isEmpty || !mounted) return;
    final prevFilter = _pages[_index].filter;
    await _runOnPage(context.t('ss.working_filter'), (_) async {
      return _ScanResultScreenState._withFilter(shot!.first, prevFilter);
    });
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
      action: SnackBarAction(
        label: context.t('common.undo'),
        onPressed: () {
          if (mounted) _undo();
        },
      ),
    );
  }

  void _undo() {
    if (_history.isEmpty || _busy) return;
    _resetZoom();
    _partSetState(() {
      _pages = _history.removeLast();
      _index = _index.clamp(0, _pages.length - 1);
      _comparingOriginal = false;
      _dirty = true;
    });
    if (_pager.hasClients) _pager.jumpToPage(_index);
    _scrollThumbTo(_index);
    _scheduleSave();
  }

  /// `onReorderItem`: [to] zaten çıkarılan öğeye göre düzeltilmiş gelir.
  void _reorder(int from, int to) {
    if (from == to) return;
    final next = [..._pages];
    final page = next.removeAt(from);
    next.insert(to, page);
    _commit(next, index: to);
    if (_pager.hasClients) _pager.jumpToPage(to);
  }

  /// Belge türünü uygular (Faz 35 / madde 1). Kimlik ve Kitap kiplerinde
  /// birleştirme/bölme + varsayılan filtre **TEK atomik geri al adımı**
  /// olarak uygulanır.
  Future<void> _applyKind(ScanKind kind) async {
    if (_busy || _pages.isEmpty) return;
    final label = context.t(kind.labelKey);
    if (kind == ScanKind.idCard && _pages.length < 2) {
      _snack(context.t('sk.id_need_two'));
      return;
    }
    _partSetState(() => _work = context.t('sk.working'));
    String? done;
    try {
      if (kind == ScanKind.businessCard) {
        done = await _saveContactCard();
        if (!mounted) return;
        _partSetState(() {
          _kind = kind;
          _kindExplicit = true;
          _dirty = true;
        });
        _scheduleSave();
        if (done.isNotEmpty) _snack(done);
        return;
      }

      var working = List<ScanPage>.of(_pages);
      var targetIndex = _index;
      var structureChanged = false;

      switch (kind) {
        case ScanKind.idCard:
          final merged = await ScanKindOps.combineId(
              working[0].source, working[1].source);
          if (!mounted) return;
          working = [ScanPage.raw(merged), ...working.skip(2)];
          targetIndex = 0;
          structureChanged = true;
          done = context.t('sk.id_combined');
        case ScanKind.book:
          final splitPages = <ScanPage>[];
          for (final page in working) {
            final parts = await ScanKindOps.splitBook(page.source);
            if (parts.length == 1) {
              splitPages.add(page);
              continue;
            }
            for (final part in parts) {
              splitPages.add(ScanPage.raw(part));
            }
          }
          if (!mounted) return;
          if (splitPages.length != working.length) {
            working = splitPages;
            targetIndex = 0;
            structureChanged = true;
            done = context.t('sk.book_split', {'n': working.length});
          }
        case ScanKind.document:
        case ScanKind.receipt:
        case ScanKind.whiteboard:
        case ScanKind.photo:
        case ScanKind.businessCard:
          break;
      }

      final filter = kind.defaultFilter;
      final filterNeeded = working.any((page) => page.filter != filter);
      if (filterNeeded) {
        final filtered = <ScanPage>[];
        for (final page in working) {
          filtered.add(page.filter == filter
              ? page
              : await _ScanResultScreenState._withFilter(page.source, filter));
        }
        if (!mounted) return;
        working = filtered;
      }

      if (!mounted) return;
      _partSetState(() {
        _kind = kind;
        _kindExplicit = true;
      });
      if (structureChanged || filterNeeded) {
        _commit(working, index: targetIndex);
        if (_pager.hasClients) _pager.jumpToPage(_index);
      } else {
        _partSetState(() => _dirty = true);
        _scheduleSave();
      }
      _snack(done ?? context.t('sk.applied', {'type': label}));
    } catch (e) {
      if (mounted) {
        showSnack(
            context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  /// Kartvizit: görünen sayfanın metninden kişi kartı (.vcf) üretir; diske
  /// yazmadan önce kısa önizleme + onay penceresi gösterir.
  Future<String> _saveContactCard() async {
    final page = _pages[_index];
    var lines = _ocr[page.source];
    if (lines == null) {
      final got = await DocumentScanner.recognizePages([page.display]);
      lines = got.isEmpty ? const <OcrLine>[] : got.first;
      _ocr[page.source] = lines;
    }
    final card =
        BusinessCard.parse(lines.map((line) => line.text).join('\n'));
    if (!mounted) return '';
    if (card.isEmpty) return context.t('sk.card_none');
    final name =
        card.name ?? card.company ?? p.basenameWithoutExtension(_pdfPath);
    final summary = <String>[
      if (card.name != null) card.name!,
      if (card.company != null) card.company!,
      ...card.phones,
      ...card.emails,
      if (card.web != null) card.web!,
    ].join('\n');

    final ok = await showAppConfirm(
      context,
      title: context.t('sk.card_preview_title'),
      message: summary,
      confirmLabel: context.t('sk.card_save_action'),
    );
    if (!ok || !mounted) return '';

    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = FileOps.uniquePath(p.join(_folder, '$safe.vcf'));
    await File(path).writeAsString(card.toVcf(), flush: true);
    FsEvents.changed();
    unawaited(ActivityLog.add(ActivityKind.scan, path));
    if (!mounted) return '';
    return context.t('sk.card_saved', {'name': name});
  }

  /// **Akıllı çıktı** (Faz 35 / madde 3): Word · Excel (tablo algılama) ·
  /// TXT · Görsel (JPEG/PNG) · seçilen kalitede PDF.
  Future<void> _export() async {
    if (_busy || _pages.isEmpty) return;
    await _flush();
    if (!mounted) return;
    final displays = ScanPage.displays(_pages);
    final choice = await showAppSheet<_ExportChoice>(
      context,
      title: context.t('sx.title'),
      builder: (_) => _ExportSheet(pages: displays),
    );
    if (choice == null || !mounted) return;
    final str = AppStrings.current;
    final task =
        TrackedTask(title: str.t('sx.title'), name: p.basename(_pdfPath));
    _partSetState(() => _work = context.t('sx.working'));
    try {
      final base = p.basenameWithoutExtension(_pdfPath);
      if (choice.format == 'jpg' || choice.format == 'png') {
        final created = <String>[];
        for (var i = 0; i < displays.length; i++) {
          if (task.cancelRequested) break;
          task.report(
            done: i,
            total: displays.length,
            detail: '${i + 1} / ${displays.length}',
          );
          final fileName = displays.length == 1
              ? '$base.${choice.format}'
              : '${base}_${i + 1}.${choice.format}';
          final out = FileOps.uniquePath(p.join(_folder, fileName));
          await compute(
            ScanExport.exportImageFile,
            (source: displays[i], target: out, format: choice.format),
          );
          created.add(out);
          unawaited(ActivityLog.add(ActivityKind.scan, out));
        }
        if (task.cancelRequested) {
          await task.stopped();
          return;
        }
        FsEvents.changed();
        task.target = FmJobTarget.files(created);
        final firstOut = created.first;
        await task.complete(
            detail: str.t('job.op_created', {'name': p.basename(firstOut)}));
        if (!mounted) return;
        showSnack(
          context,
          context.t('sx.saved', {'name': p.basename(firstOut)}),
          action: SnackBarAction(
            label: context.t('common.open'),
            onPressed: () {
              if (mounted) EntryOpener.open(context, firstOut);
            },
          ),
        );
        return;
      }

      // Metin gereken her çıktı için eksik sayfalar tanınır (bir kez).
      final total = _pages.length;
      for (var i = 0; i < total; i++) {
        if (task.cancelRequested) break;
        final page = _pages[i];
        if (_ocr.containsKey(page.source)) continue;
        task.report(
            done: i,
            total: total,
            detail: str.t('sf.ocr_progress', {'n': i + 1, 'total': total}));
        final lines = await DocumentScanner.recognizePages(
          [page.source],
          isCancelled: () => task.cancelRequested,
        );
        _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
      }
      if (task.cancelRequested) {
        await task.stopped();
        return;
      }
      final ocr = [
        for (final page in _pages) _ocr[page.source] ?? const <OcrLine>[]
      ];
      final Uint8List bytes;
      final String ext;
      var suffix = '';
      switch (choice.format) {
        case 'docx':
          bytes = await Isolate.run(() => ScanExport.toDocx(ocr));
          ext = 'docx';
        case 'xlsx':
          final sheetPrefix = str.t('sx.sheet');
          bytes = await Isolate.run(
              () => ScanExport.toXlsx(ocr, sheetPrefix: sheetPrefix));
          ext = 'xlsx';
        case 'txt':
          bytes = ScanExport.toTxt(ocr);
          ext = 'txt';
        default:
          final packed = await ScanExport.compressPages(
            displays,
            choice.quality,
            isCancelled: () => task.cancelRequested,
            onProgress: (done, all) => task.report(
                done: done, total: all, detail: str.t('sf.building_pdf')),
          );
          if (task.cancelRequested) {
            await task.stopped();
            return;
          }
          bytes = await DocumentScanner.renderPdf(
            [for (final c in packed) c.path],
            ocrLinesPerPage: [
              for (var i = 0; i < packed.length; i++)
                ScanExport.scaleLines(ocr[i], packed[i].ratio),
            ],
            uniformA4: _kind.uniformA4,
            ocrSourcePaths: [for (final page in _pages) page.source],
          );
          for (final c in packed) {
            unawaited(File(c.path).delete().then((_) {}, onError: (_) {}));
          }
          ext = 'pdf';
          suffix = ' (${str.t(choice.quality.labelKey)})';
      }
      final out = FileOps.uniquePath(p.join(_folder, '$base$suffix.$ext'));
      await File(out).writeAsBytes(bytes, flush: true);
      FsEvents.changed();
      unawaited(ActivityLog.add(ActivityKind.scan, out));
      task.target = FmJobTarget.files([out]);
      await task.complete(
          detail: str.t('job.op_created', {'name': p.basename(out)}));
      if (!mounted) return;
      showSnack(
        context,
        context.t('sx.saved', {'name': p.basename(out)}),
        action: SnackBarAction(
          label: context.t('common.open'),
          onPressed: () {
            if (mounted) EntryOpener.open(context, out);
          },
        ),
      );
    } catch (e) {
      await task.fail(e);
      if (mounted) {
        showSnack(
            context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  /// Kimlik taraması şifreli kasaya: PDF kasaya girer, aslı silinir, stüdyo
  /// kapanır.
  Future<void> _moveToVault() async {
    await _flush();
    if (!mounted) return;
    final ok = await addToVault(context, [_pdfPath]);
    if (!ok || !mounted) return;
    _partSetState(() => _actionDismissed = true);
    Navigator.of(context).pop();
  }

  /// Fiş/fatura → `Giderler.csv` satırı.
  Future<void> _addExpense() async {
    final text = _text.map((page) => page.text).join('\n');
    final info = ReceiptInfo.parse(text);
    if (info.isEmpty) {
      _snack(context.t('sa.expense_none'));
      return;
    }
    try {
      final path = await ScanActions.appendExpense(
          _folder, info, p.basename(_pdfPath));
      FsEvents.changed();
      if (!mounted) return;
      _partSetState(() => _actionDismissed = true);
      showSnack(
        context,
        context.t('sa.expense_done'),
        action: SnackBarAction(
          label: context.t('common.open'),
          onPressed: () {
            if (mounted) EntryOpener.open(context, path);
          },
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnack(
            context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    }
  }

  /// Izgaradaki sayfa menüsü.
  Future<void> _gridAction(int index, String action) async {
    if (_busy) return;
    _partSetState(() => _index = index);
    switch (action) {
      case 'rotate_left':
        await _rotateLeft();
      case 'rotate':
        await _rotate();
      case 'filter':
        await _filter();
      case 'crop':
        await _crop();
      case 'delete':
        _delete();
    }
  }

  void _goTo(int index) {
    _resetZoom();
    _partSetState(() {
      _index = index;
      _comparingOriginal = false;
    });
    _scrollThumbTo(index);
    if (_pager.hasClients) {
      Motion.toPage(context, _pager, index);
    }
    if (_filterStripOpen && index >= 0 && index < _pages.length) {
      unawaited(_ensurePreviews(_pages[index].source));
    }
  }

  Future<void> _addPages() async {
    if (_busy) return;
    final source = await showAppActionSheet<String>(context, groups: [
      AppActionGroup(actions: [
        AppAction(
            value: 'camera',
            icon: AppIcons.ocr,
            label: context.t('ss.add_camera'),
            hint: context.t('ss.add_camera_sub')),
        AppAction(
            value: 'gallery',
            icon: AppIcons.layoutGallery,
            label: context.t('ss.add_gallery'),
            hint: context.t('ss.add_gallery_sub')),
      ]),
    ]);
    if (source == null || !mounted) return;
    if (source == 'camera') {
      List<String>? more;
      try {
        more = await DocumentScanner.scanPages();
      } catch (e) {
        if (mounted) {
          _snack(context.t('sf.scanner_failed', {'error': userErrorText(e)}));
        }
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

  /// Galeriden fotoğraf ekler: önce EXIF/HEIC/WebP normalizasyonundan
  /// geçirilir; tek fotoğrafta `ScanEditScreen` açılır. Kullanıcı X (Vazgeç)
  /// tuşuna basarsa (`res.isCancelled`) fotoğraf eklenmez.
  Future<void> _addFromGallery() async {
    final res = await AppFilePicker.pickFiles(
        type: FileType.image, allowMultiple: true);
    final rawPaths = [
      for (final f in res?.files ?? const <PickedFile>[])
        if (f.path != null) f.path!,
    ];
    if (rawPaths.isEmpty || !mounted) return;
    _partSetState(() => _work = context.t('ss.working_crop'));
    List<String> paths;
    try {
      paths = await ScanPageOps.normalizeAll(rawPaths);
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
    if (paths.isEmpty || !mounted) return;
    final first = _pages.length;
    var added = [for (final path in paths) ScanPage.raw(path)];
    if (paths.length == 1) {
      final cropRes =
          await ScanEditScreen.open(context, paths.first, autoDetect: true);
      if (!mounted || cropRes.isCancelled) return;
      if (cropRes.isCropped) {
        _partSetState(() => _work = context.t('ss.working_crop'));
        try {
          added = [
            ScanPage.raw(
                await ScanPageOps.warp(paths.first, cropRes.corners!)),
          ];
        } catch (e) {
          if (mounted) {
            _snack(context.t('se.failed', {'error': userErrorText(e)}));
          }
          return;
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
    if (_dirty || _saveState == _SaveState.failed) {
      _snack(context.t('ss.save_failed'));
      return;
    }
    await SharePlus.instance.share(
        ShareParams(files: [XFile(_pdfPath)], text: p.basename(_pdfPath)));
  }

  /// **Kaydet**: son yazım beklenir, tarama ekranı kapanır ve belgenin
  /// klasörü açılıp dosya vurgulanır.
  Future<void> _saveAndReveal() async {
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
    if (!mounted) return;
    if (_dirty || _saveState == _SaveState.failed) {
      _snack(context.t('ss.save_failed'));
      return;
    }
    final path = _pdfPath;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final strings = AppStrings.of(context);
    unawaited(Navigator.of(context).pushReplacement(browserRoute(
        BrowserScreen(path: p.dirname(path), focusPath: path))));
    if (messenger != null) {
      showSnackBarReplacing(
          messenger,
          SnackBar(
              content: Text(
                  strings.t('scr.saved_here', {'name': p.basename(path)}))));
    }
  }

  Future<void> _openPdf() async {
    await _flush();
    if (!mounted) return;
    await EntryOpener.open(context, _pdfPath);
  }

  Future<void> _recognize({bool force = false}) async {
    if (_busy || _pages.isEmpty) return;
    _partSetState(() => _work = context.t('vw.ocr_running'));
    var modelNotReady = false;
    try {
      final targets = <ScanPage>[
        for (final page in _pages)
          if (force || !_ocr.containsKey(page.source)) page,
      ];
      if (targets.isNotEmpty) {
        final recognized = await DocumentScanner.recognizePages(
          [for (final page in targets) page.display],
          onModelNotReady: (_) => modelNotReady = true,
        );
        for (var i = 0; i < targets.length && i < recognized.length; i++) {
          _ocr[targets[i].source] = recognized[i];
        }
      }
      if (!mounted) return;
      _partSetState(() => _dirty = true);
      _scheduleSave(); // görünmez metin katmanı PDF'e de girsin
      if (modelNotReady) {
        _snack(const OcrModelNotReady().toString());
      } else if (_text.isEmpty) {
        _snack(context.t('vw.ocr_none'));
      }
    } catch (e) {
      if (mounted) {
        _snack(context.t('vw.ocr_failed', {'error': userErrorText(e)}));
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  /// Çevrimdışı Türkçe OCR düzeltici (`ScanTextFix`) ile tüm sayfaların
  /// metin satırlarını iyileştirir.
  void _fixOcrText() {
    if (_busy || _pages.isEmpty) return;
    var fixedCount = 0;
    for (final page in _pages) {
      final lines = _ocr[page.source];
      if (lines == null || lines.isEmpty) continue;
      final raw = [for (final l in lines) l.text];
      final fixed = ScanTextFix.lines(raw);
      var pageChanged = false;
      final updated = <OcrLine>[];
      for (var i = 0; i < lines.length; i++) {
        final text = i < fixed.length ? fixed[i] : lines[i].text;
        if (text != lines[i].text) {
          fixedCount++;
          pageChanged = true;
        }
        if (text.trim().isNotEmpty) {
          updated.add(OcrLine(text, lines[i].box));
        }
      }
      if (pageChanged) {
        _ocr[page.source] = updated;
      }
    }
    if (fixedCount == 0) {
      _snack(context.t('st.fix_noop'));
      return;
    }
    _partSetState(() => _dirty = true);
    _scheduleSave();
    _snack(context.t('st.fix_done', {'n': fixedCount}));
  }

  /// Tek sayfanın OCR metnini elle düzenleme levhasında açar ve kaydeder.
  Future<void> _editPageText(int pageIndex, String currentText) async {
    if (_busy || pageIndex < 0 || pageIndex >= _pages.length) return;
    final edited = await showAppSheet<String>(
      context,
      title: context.t('st.edit_page', {'n': pageIndex + 1}),
      builder: (_) => _PageTextEditSheet(initial: currentText),
    );
    if (edited == null || !mounted) return;
    final page = _pages[pageIndex];
    final oldLines = _ocr[page.source] ?? const <OcrLine>[];
    final newRaw = edited
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final updated = <OcrLine>[];
    for (var i = 0; i < newRaw.length; i++) {
      final box = i < oldLines.length
          ? oldLines[i].box
          : Rect.fromLTWH(20, 20.0 + i * 24.0, 400, 20);
      updated.add(OcrLine(newRaw[i], box));
    }
    _partSetState(() {
      _ocr[page.source] = updated;
      _dirty = true;
    });
    _scheduleSave();
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

  /// Dosya adını değiştirir (uzantı sabit kalır).
  Future<void> _rename() async {
    await _flush();
    if (!mounted) return;
    final name = await showAppPrompt(
      context,
      title: context.t('scr.rename'),
      initial: p.basenameWithoutExtension(_pdfPath),
    );
    final clean = name?.trim();
    if (clean == null || clean.isEmpty || !mounted) return;
    try {
      final old = _pdfPath;
      final newPath = await FileOps.rename(_pdfPath, '$clean.pdf');
      if (!mounted) return;
      _partSetState(() => _pdfPath = newPath);
      await EntryOpener.rememberFile(context, newPath, previousPath: old);
    } catch (e) {
      if (mounted) {
        _snack(context.t('scr.rename_failed', {'error': userErrorText(e)}));
      }
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
    } catch (e) {
      if (mounted) showUserError(context, e);
      return;
    }
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

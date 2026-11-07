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
    unawaited(_measureVisible());
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
          showSnack(context, context.t('sf.save_failed', {'error': userErrorText(e)}),
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
        showSnack(context, context.t('scr.add_failed', {'error': userErrorText(e)}),
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
      if (mounted) _snack(context.t('sf.scanner_failed', {'error': userErrorText(e)}));
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

  /// `onReorderItem`: [to] zaten çıkarılan öğeye göre düzeltilmiş gelir.
  void _reorder(int from, int to) {
    if (from == to) return;
    final next = [..._pages];
    final page = next.removeAt(from);
    next.insert(to, page);
    _commit(next, index: to);
    if (_pager.hasClients) _pager.jumpToPage(to);
  }

  /// Belge türünü uygular (Faz 35 / madde 1). Ağır işler izolatta, sayfa
  /// sayfa sırayla (aynı anda tek büyük görsel bellekte); her adım "Geri
  /// al" yığınına girer.
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
      switch (kind) {
        case ScanKind.idCard:
          final merged = await ScanKindOps.combineId(
              _pages[0].source, _pages[1].source);
          if (!mounted) return;
          _commit([ScanPage.raw(merged), ..._pages.skip(2)], index: 0);
          done = context.t('sk.id_combined');
        case ScanKind.book:
          final next = <ScanPage>[];
          for (final page in _pages) {
            final parts = await ScanKindOps.splitBook(page.source);
            if (parts.length == 1) {
              next.add(page);
              continue;
            }
            for (final part in parts) {
              next.add(page.filter == ScanFilter.original
                  ? ScanPage.raw(part)
                  : await _ScanResultScreenState._withFilter(part, page.filter));
            }
          }
          if (!mounted) return;
          if (next.length != _pages.length) {
            _commit(next, index: 0);
            done = context.t('sk.book_split', {'n': next.length});
          }
        case ScanKind.businessCard:
          done = await _saveContactCard();
        case ScanKind.document:
        case ScanKind.receipt:
        case ScanKind.whiteboard:
        case ScanKind.photo:
          break;
      }
      if (!mounted) return;
      // Filtre varsayılanı (kimlikte birleşik sayfa da dahil).
      final filter = kind.defaultFilter;
      if (kind != ScanKind.businessCard &&
          _pages.any((page) => page.filter != filter)) {
        final next = <ScanPage>[];
        for (final page in _pages) {
          next.add(page.filter == filter
              ? page
              : await _ScanResultScreenState._withFilter(page.source, filter));
        }
        if (!mounted) return;
        _commit(next);
      }
      if (!mounted) return;
      _partSetState(() => _kind = kind);
      // Sayfa düzeni (A4 / görsel oranı) değişti → PDF yeniden yazılsın.
      _partSetState(() => _dirty = true);
      _scheduleSave();
      _snack(done ?? context.t('sk.applied', {'type': label}));
    } catch (e) {
      if (mounted) {
        showSnack(context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  /// Kartvizit: görünen sayfanın metninden kişi kartı (.vcf) üretir, PDF'in
  /// yanına yazar. Metin cihazda tanınır, hiçbir yere gönderilmez.
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
    final name = card.name ?? card.company ?? p.basenameWithoutExtension(_pdfPath);
    final safe = name.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    final path = FileOps.uniquePath(p.join(_folder, '$safe.vcf'));
    await File(path).writeAsString(card.toVcf(), flush: true);
    FsEvents.changed();
    if (!mounted) return '';
    return context.t('sk.card_saved', {'name': name});
  }

  /// **Akıllı çıktı** (Faz 35 / madde 3): Word · Excel (tablo algılama) ·
  /// TXT · seçilen kalitede PDF. İş kuyruğunda izlenir (ilerleme, iptal,
  /// bitince bildirim — `TrackedTask`); çıktı PDF'in yanına yazılır.
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
    final task = TrackedTask(title: str.t('sx.title'), name: p.basename(_pdfPath));
    _partSetState(() => _work = context.t('sx.working'));
    try {
      // Metin gereken her çıktı için eksik sayfalar tanınır (bir kez).
      final total = _pages.length;
      for (var i = 0; i < total; i++) {
        if (task.cancelRequested) break;
        final page = _pages[i];
        if (_ocr.containsKey(page.source)) continue;
        task.report(
            done: i, total: total, detail: str.t('sf.ocr_progress', {'n': i + 1, 'total': total}));
        final lines = await DocumentScanner.recognizePages([page.display]);
        _ocr[page.source] = lines.isEmpty ? const [] : lines.first;
      }
      if (task.cancelRequested) {
        await task.stopped();
        return;
      }
      final ocr = [for (final page in _pages) _ocr[page.source] ?? const <OcrLine>[]];
      final base = p.basenameWithoutExtension(_pdfPath);
      final Uint8List bytes;
      final String ext;
      var suffix = '';
      switch (choice.format) {
        case 'docx':
          bytes = ScanExport.toDocx(ocr);
          ext = 'docx';
        case 'xlsx':
          bytes = ScanExport.toXlsx(ocr, sheetPrefix: str.t('sx.sheet'));
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
          );
          // Ham sıkıştırılmış sayfalar iş bitince silinir.
          for (final c in packed) {
            unawaited(File(c.path).delete().then((_) {}, onError: (_) {}));
          }
          ext = 'pdf';
          suffix = ' (${str.t(choice.quality.labelKey)})';
      }
      final out = FileOps.uniquePath(p.join(_folder, '$base$suffix.$ext'));
      await File(out).writeAsBytes(bytes, flush: true);
      FsEvents.changed();
      task.target = FmJobTarget.files([out]);
      await task.complete(detail: str.t('job.op_created', {'name': p.basename(out)}));
      if (!mounted) return;
      showSnack(
        context,
        context.t('sx.saved', {'name': p.basename(out)}),
        action: SnackBarAction(
          label: context.t('common.open'),
          onPressed: () => EntryOpener.open(context, out),
        ),
      );
    } catch (e) {
      await task.fail(e);
      if (mounted) {
        showSnack(context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    } finally {
      if (mounted) _partSetState(() => _work = null);
    }
  }

  /// Kimlik taraması şifreli kasaya: PDF kasaya girer, aslı silinir, stüdyo
  /// kapanır (kasadaki dosya oradan açılır).
  Future<void> _moveToVault() async {
    await _flush();
    if (!mounted) return;
    final ok = await addToVault(context, [_pdfPath]);
    if (!ok || !mounted) return;
    _partSetState(() => _actionDismissed = true);
    Navigator.of(context).pop();
  }

  /// Fiş/fatura → `Giderler.csv` satırı (tarih, satıcı, toplam, dosya adı).
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
          onPressed: () => EntryOpener.open(context, path),
        ),
      );
    } catch (e) {
      if (mounted) {
        showSnack(context, context.t('scr.add_failed', {'error': userErrorText(e)}),
            copyable: true);
      }
    }
  }

  /// Izgaradaki sayfa menüsü: işler "görünen sayfa"ya uygulandığı için önce
  /// [index] seçilir.
  Future<void> _gridAction(int index, String action) async {
    if (_busy) return;
    _partSetState(() => _index = index);
    switch (action) {
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
    _partSetState(() => _index = index);
    if (_pager.hasClients) {
      Motion.toPage(context, _pager, index);
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
                leading: const _SheetIcon(AppIcons.ocr),
                title: Text(ctx.t('ss.add_camera')),
                subtitle: Text(ctx.t('ss.add_camera_sub')),
                onTap: () => Navigator.pop(ctx, 'camera'),
              ),
              ListTile(
                leading: const _SheetIcon(AppIcons.layoutGallery),
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
        if (mounted) _snack(context.t('sf.scanner_failed', {'error': userErrorText(e)}));
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
    final res = await AppFilePicker
        .pickFiles(type: FileType.image, allowMultiple: true);
    final paths = [
      for (final f in res?.files ?? const <PickedFile>[])
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
          if (mounted) _snack(context.t('se.failed', {'error': userErrorText(e)}));
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
    await SharePlus.instance.share(ShareParams(files: [XFile(_pdfPath)], text: p.basename(_pdfPath)));
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
      if (mounted) _snack(context.t('vw.ocr_failed', {'error': userErrorText(e)}));
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
      // "Son belgeler" kaydı yolla eşleşir; ad değişince eski kayıt ölü
      // bağlantıya dönerdi.
      await EntryOpener.rememberFile(context, newPath, previousPath: old);
    } catch (e) {
      if (mounted) _snack(context.t('scr.rename_failed', {'error': userErrorText(e)}));
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
      // Kullanıcı eylemi: klasör kurulamadıysa taşıma DENENMEZ ve nedeni
      // söylenir (eskiden hata yutuluyor, ardından taşıma boşuna deneniyordu
      // — FAZ_PLANI I5).
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

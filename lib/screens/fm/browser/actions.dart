part of '../browser_screen.dart';

extension _BrowserScreenActionsPart on _BrowserScreenState {
  /// Seçili DOSYALARIN toplam boyutu.
  ///
  /// Klasörler sayılmıyor: bir klasörün boyutu ancak altındaki her şey
  /// gezilerek bulunur ve seçim çubuğunda anlık bir sayı gerekiyor — ölçülen
  /// klasör varsa (bkz. [FolderSizeCache]) o da toplanıyor.
  int get _selectionBytes {
    var total = 0;
    for (final e in _entries) {
      if (!_selected.contains(e.path)) continue;
      if (e.isDir) {
        total += FolderSizeCache.sizeOf(e.path) ?? 0;
      } else {
        total += e.sizeBytes;
      }
    }
    return total;
  }

  /// Klasör satırının alt yazısı: tarih, ayar açıksa **boyut da**.
  ///
  /// Ölçüm ekranda görünen klasör için İSTENİYOR (bkz. [FolderSizeCache]);
  /// gelene kadar yalnız tarih yazıyor — "…" gibi bir yer tutucu, listede
  /// her kaydırmada titreşen bir metin demek olurdu.
  String _folderSubtitle(FsEntry entry) {
    final date = FsPaths.humanDate(entry.modifiedMs);
    if (!context.read<AppState>().fmFolderSizes) return date;
    final size = FolderSizeCache.sizeOf(entry.path);
    if (size == null) {
      FolderSizeCache.request(entry.path);
      return date;
    }
    return '${FsPaths.humanSize(size)} · $date';
  }

  /// Kilit denetimi: klasör kilitliyse PIN sorulur, yanlışsa geri çıkılır.
  Future<void> _checkLock() async {
    final appState = context.read<AppState>();
    if (!appState.isFolderLocked(widget.path)) return;
    _partSetState(() => _locked = true);
    final ok = await askPin(context, title: context.t('fm.locked_folder'));
    if (!mounted) return;
    if (ok) {
      _partSetState(() => _locked = false);
      await _load();
    } else {
      Navigator.of(context).maybePop();
    }
  }

  /// Vurgulanan dosyayı görünür alana getirir. Liste tembel kurulduğu için
  /// satır ekranın dışındaysa henüz yoktur: önce sıradaki yerine oranla
  /// atlanır (sabit satır yüksekliğinde birebir, ızgarada yakın), satır
  /// kurulunca `ensureVisible` tam ortalar. Vurgu birkaç saniye sonra söner.
  void _revealFocus() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Liste ilk karelerde henüz yerleşmemiş olabilir (yükleme iskeleti,
      // tahmini kaydırma boyu): birkaç kare boyunca yeniden denenir.
      for (var tries = 0; tries < 6; tries++) {
        if (!mounted || _focus == null) return;
        final target = _focusKey.currentContext;
        final box = target?.findRenderObject();
        if (box != null && _scroll.hasClients) {
          // Kendi denetleyicimizle: `ensureVisible` en yakın Scrollable'ı
          // arıyor ve satır alt çubuğun arkasında kalıyordu (test ölçtü).
          final pos = _scroll.position;
          final want = RenderAbstractViewport.of(box)
              .getOffsetToReveal(box, 0.3)
              .offset
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          await Motion.scrollTo(context, _scroll, want);
          break;
        }
        final entries = _visible(_sorted(context.read<AppState>()));
        final i = entries.indexWhere((e) => e.path == _focus);
        if (i < 0) return; // dosya yok/süzgeçte gizli
        if (_scroll.hasClients) {
          final max = _scroll.position.maxScrollExtent;
          _scroll.jumpTo((max * i / entries.length).clamp(0.0, max));
        }
        final frame = Completer<void>();
        WidgetsBinding.instance
          ..addPostFrameCallback((_) => frame.complete())
          ..scheduleFrame();
        await frame.future;
      }
      await Future<void>.delayed(const Duration(seconds: 4));
      if (mounted) _partSetState(() => _focus = null);
    });
  }

  Future<void> _load() async {
    _partSetState(() {
      _loading = true;
      _error = null;
    });
    try {
      final appState = context.read<AppState>();
      final list =
          await FsScan.list(widget.path, showHidden: appState.fmShowHidden);
      if (!mounted) return;
      _partSetState(() {
        _entries = list;
        _loading = false;
        // Silinen/taşınan öğeler seçimde kalmasın.
        _selected.removeWhere((s) => !list.any((e) => e.path == s));
      });
      if (_focus != null) _revealFocus();
    } catch (e) {
      if (!mounted) return;
      _partSetState(() {
        _loading = false;
        // Hata metni build'de çevriliyor; burada YALNIZ anahtar saklanıyor
        // (dil değişince ekranda eski dilde asılı kalmasın).
        _error = 'fm.unreadable';
      });
    }
  }

  /// Sıralı liste. [appState] ÇAĞIRANDAN gelir (Faz 6 / B1): eskiden
  /// getter kendi içinde `context.watch` çağırıyordu ve dokunma geri
  /// çağrısından (`_openEntry`) da okunuyordu → hata ayıklama derlemesinde
  /// Provider iddia hatası.
  List<FsEntry> _sorted(AppState appState) {
    final eff = _sortOf(appState);
    final key = (_entries, eff.$1, eff.$2);
    final cached = _sortedCache;
    final last = _sortedKey;
    if (cached != null &&
        last != null &&
        identical(last.$1, key.$1) &&
        last.$2 == key.$2 &&
        last.$3 == key.$3) {
      return cached;
    }
    _sortedKey = key;
    return _sortedCache =
        FsScan.sort(_entries, eff.$1, descending: eff.$2);
  }

  Future<void> _openEntry(FsEntry entry) async {
    if (_selecting) {
      _toggle(entry);
      return;
    }
    if (entry.isDir) {
      await Navigator.of(context).push(browserRoute(BrowserScreen(path: entry.path),
      ));
      if (mounted) _load(); // alt klasörde yapılan değişiklikler yansısın
      return;
    }
    // Arşive dokunmak: içeriği ÇIKARMADAN listelenir (RAR/7z/zip/tar).
    // Oradan tümünü ya da tek dosyayı çıkarabilir, önizleyebilir.
    if (ArchiveOps.canExtract(entry.path)) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => ArchiveScreen(path: entry.path),
      ));
      if (mounted) _load(); // çıkarılan klasör listede görünsün
      return;
    }
    // Kardeş dosyalar: görselde kaydırmalı galeri, medyada çalma listesi.
    await EntryOpener.open(
      context,
      entry.path,
      siblings: _visible(_sorted(context.read<AppState>()))
          .where((e) => !e.isDir)
          .map((e) => e.path)
          .toList(),
    );
  }

  void _toggle(FsEntry entry) {
    _partSetState(() {
      if (!_selected.remove(entry.path)) _selected.add(entry.path);
    });
  }

  /// Sürükleyerek seçimde çağrılır: görünen sıradaki [start]..[end] aralığı.
  void _selectRange(List<FsEntry> visible, int start, int end, bool select) {
    _partSetState(() {
      for (var i = start; i <= end; i++) {
        if (i < 0 || i >= visible.length) continue;
        if (select) {
          _selected.add(visible[i].path);
        } else {
          _selected.remove(visible[i].path);
        }
      }
    });
  }

  /// Toplu seçme: hepsi seçiliyse seçimi kaldırır, değilse tümünü seçer.
  void _toggleSelectAll() {
    final all = _entries.map((e) => e.path).toSet();
    _partSetState(() {
      if (_selected.length >= all.length && all.every(_selected.contains)) {
        _selected.clear();
      } else {
        _selected.addAll(all);
      }
    });
  }

  /// Tek dosya seçiliyken görünürdeki konumuna göre üstündekileri/
  /// altındakileri de seçer (Google Fotoğraflar'daki "buraya kadar seç"
  /// jesti). Kullanıcı isteği (2026-07-29): *"1 görüntü seçtim, onun altında
  /// kalanları seç, onun üstünde kalanları seç butonu olsun"*.
  void _selectFromAnchor(List<FsEntry> visible, {required bool above}) {
    if (_selected.length != 1) return;
    final anchorIndex = visible.indexWhere((e) => e.path == _selected.first);
    if (anchorIndex < 0) return;
    _selectRange(
      visible,
      above ? 0 : anchorIndex,
      above ? anchorIndex : visible.length - 1,
      true,
    );
  }

  List<FsEntry> get _selectedEntries =>
      _entries.where((e) => _selected.contains(e.path)).toList();

  Future<void> _paste() async {
    final appState = context.read<AppState>();
    final sources = appState.clipboard;
    if (sources.isEmpty) return;
    final cut = appState.clipboardCut;
    // ÇAKIŞMA SORULUYOR (KALANLAR maddesi kapandı). Eskiden sessizce
    // "yeniden adlandır" uygulanıyordu: aynı dosyanın yeni sürümünü
    // yapıştıran kullanıcı klasörde iki kopya buluyor ve hangisinin güncel
    // olduğunu bilemiyordu. Çakışma yoksa hiçbir şey sorulmuyor.
    var conflict = FmConflict.rename;
    final collisions = PasteConflict.collisions(sources, widget.path);
    if (collisions.isNotEmpty) {
      final choice = await showPasteConflictSheet(context, names: collisions);
      // Pencereyi kapatmak = vazgeç. Sessizce bir varsayılana düşmek,
      // kullanıcının kapattığı pencerenin yine de dosya yazması olurdu.
      if (choice == null) return;
      conflict = choice;
    }
    if (!mounted) return;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: cut ? context.t('fm.moving') : context.t('fm.copying'),
      name: context.t(cut ? 'fm.moving_name' : 'fm.copying_name'),
      task: (report, isCancelled) => cut
          ? FileOps.moveAll(sources, widget.path,
              conflict: conflict, onProgress: report, isCancelled: isCancelled)
          : FileOps.copyAll(sources, widget.path,
              conflict: conflict, onProgress: report, isCancelled: isCancelled),
    );
    appState.clearClipboard();
    if (!mounted) return;
    if (result.hasError) {
      _snack(context.t('fm.transfer_partial', {'error': result.errors.first}));
    } else if (result.cancelled) {
      _snack(context.t('fm.transfer_cancelled'));
    }
    _load();
  }

  /// **Boş klasörleri temizle** (2026-09-06 denetim turu).
  ///
  /// Yer kazandırmazlar ama listeyi kirletirler: silinen uygulamaların
  /// bıraktığı `Android/data/...`, medyası silinmiş WhatsApp klasörleri,
  /// "hepsini sil" sonrası kalan tarih klasörleri. Kullanıcı dosyasını
  /// ararken onlarca boş klasörün içine girip çıkıyordu.
  ///
  /// Silmeden ÖNCE kaç tane olduğu soruluyor: sessizce silmek, kullanıcının
  /// bilerek boş bıraktığı bir klasörü de götürebilirdi.
  Future<void> _cleanEmptyFolders() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final found = await showFmProgress<List<String>>(
      context,
      title: strings.t('fm.empty_scanning'),
      backgroundable: false,
      task: (report, isCancelled) => EmptyFolders.find(
        widget.path,
        isCancelled: isCancelled,
        onScan: (path) => report(FmProgress(0, 0, p.basename(path))),
      ),
    );
    if (!mounted) return;
    if (found.isEmpty) {
      showSnackOn(messenger, strings.t('fm.empty_none'));
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('fm.empty_folders')),
        content: Text(strings.t('fm.empty_found', {'n': found.length})),
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
    if (confirm != true) return;
    final deleted = await EmptyFolders.deleteAll(found);
    if (!mounted) return;
    showSnackOn(messenger, strings.t('fm.empty_deleted', {'n': deleted}));
    _load();
  }

  /// **Klasör listesini dosyaya yaz** (2026-09-06 denetim turu).
  ///
  /// "Bu klasörde neler var" sorusunun ekran DIŞINA çıkan bir cevabı yoktu;
  /// kullanıcı ekran görüntüsü alıyordu. Metin mesaja yapıştırmak, CSV
  /// Excel'de sıralayıp süzmek için.
  Future<void> _exportListing() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final csv = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.newText),
              title: Text(ctx.t('fm.export_text')),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(AppIcons.newSheet),
              title: Text(ctx.t('fm.export_csv')),
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (csv == null || !mounted) return;
    try {
      final out = await FolderReport.save(widget.path, _entries, csv: csv);
      if (!mounted) return;
      showSnackOn(messenger,
          strings.t('fm.export_done', {'name': p.basename(out)}));
      _load();
    } catch (e) {
      if (!mounted) return;
      showSnackOn(messenger, userErrorText(e));
    }
  }

  Future<void> _newFolder() async {
    // Hata metni await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final createFailed = context.t('fm.folder_create_failed');
    final name = await _askName(context.t('fm.new_folder'),
        context.t('fm.folder_name'), context.t('fm.new_folder'));
    if (name == null) return;
    try {
      await FileOps.createFolder(widget.path, name);
      _load();
    } catch (e) {
      _snack(createFailed.replaceAll('{error}', userErrorText(e)));
    }
  }

  /// Yeni boş belge (metin / Word / Excel) — mevcut BlankDocs üreteçleriyle,
  /// ama dosya GEÇERLİ klasöre yazılır (BlankDocs kendi dizinine yazıyordu).
  Future<void> _newDocument(String kind) async {
    // Hata metni await'ten ÖNCE (asenkron boşluktan sonra `context` yok).
    final fileCreateFailed = context.t('fm.file_create_failed');
    final suggestion = switch (kind) {
      'docx' => 'Yeni Belge.docx',
      'xlsx' => 'Yeni Tablo.xlsx',
      _ => 'Yeni Metin.txt',
    };
    final name = await _askName(
        context.t('create.doc'), context.t('fm.file_name'), suggestion);
    if (name == null) return;
    try {
      final target =
          FileOps.uniquePath(p.join(widget.path, FileOps.sanitizeName(name)));
      final bytes = switch (kind) {
        'docx' => BlankDocs.blankDocx(),
        'xlsx' => BlankDocs.blankXlsx(),
        _ => const <int>[],
      };
      await File(target).writeAsBytes(bytes);
      if (!mounted) return;
      _load();
      await EntryOpener.open(context, target);
    } catch (e) {
      _snack(fileCreateFailed.replaceAll('{error}', userErrorText(e)));
    }
  }

  /// **Buraya tara** (Faz 6 / U7): ortak tarama akışı PDF'i Belgeler'e
  /// yazar; sonuç bu klasöre TAŞINIR (aynı ad varsa yeni ad alır).
  Future<void> _scanHere() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final made = await ScanFlow.run(context, open: false);
    if (made == null || !mounted) return;
    final result = await FileOps.moveAll([made], widget.path);
    if (!mounted) return;
    showSnackOn(
        messenger,
        result.hasError
            ? strings.t('fm.transfer_partial', {'error': result.errors.first})
            : strings.t('create.scanned'));
    _load();
  }

  /// **Buraya içe aktar** (Faz 6 / U7): sistem dosya seçicisinden (Drive,
  /// başka uygulamalar, indirilenler) seçilen dosyalar bu klasöre KOPYALANIR.
  Future<void> _importHere() async {
    final strings = AppStrings.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final res = await FilePicker.platform
        .pickFiles(allowMultiple: true, withData: false);
    final paths = [
      for (final f in res?.files ?? const <PlatformFile>[])
        if (f.path != null) f.path!,
    ];
    if (paths.isEmpty || !mounted) return;
    final result = await showFmProgress<FmOpResult>(
      context,
      title: strings.t('fm.copying'),
      name: strings.t('fm.copying_name'),
      task: (report, isCancelled) => FileOps.copyAll(paths, widget.path,
          onProgress: report, isCancelled: isCancelled),
    );
    if (!mounted) return;
    showSnackOn(
        messenger,
        result.hasError
            ? strings.t('fm.transfer_partial', {'error': result.errors.first})
            : strings.t('create.imported', {'n': paths.length}));
    _load();
  }

  Future<String?> _askName(String title, String label, String initial) async {
    final controller = TextEditingController(text: initial);
    final dot = initial.lastIndexOf('.');
    controller.selection = TextSelection(
        baseOffset: 0, extentOffset: dot > 0 ? dot : initial.length);
    final value = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: label),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(context.t('common.cancel'))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(context.t('fm.create')),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = value?.trim();
    return (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  void _snack(String message) {
    if (!mounted) return;
    showSnack(context, message);
  }
}

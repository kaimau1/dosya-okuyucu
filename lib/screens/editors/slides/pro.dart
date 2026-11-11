part of '../slides_editor_screen.dart';

/// **Faz 38 — Slayt pro araçları.** Alt çubuktaki "Araçlar" levhası her pro
/// işlemi [_SlidesEditorScreenState._proApply] kapısından geçirir: deste
/// kaydedilir, işlem paket düzeyinde İZOLATTA koşar ([PptxPro.run]), sonuç
/// yeniden ayrıştırılır (izolatta) ve editöre bağlanır. Önceki bayt
/// [_proUndo]'ya girer — üst çubuktaki ↶ editör yığını boşsa onu geri alır.
/// Bayrak `slides_pro_v1` (anayasa k.9): kapalıysa levha yok, eski yol aynen.
extension _SlidesProPart on _SlidesEditorScreenState {
  static const flagKey = 'slides_pro_v1';

  Future<void> _loadProFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool(flagKey) ?? true;
      if (on != _proOn && mounted) _partSetState(() => _proOn = on);
    } catch (_) {
      // En iyi çaba: ayar okunamazsa varsayılan (açık) kalır.
    }
  }

  static Future<PptxEditor> _parseDeck(Uint8List bytes) async {
    if (SlidesEditorScreen.parseInIsolate) {
      try {
        return await compute(PptxEditor.parse, bytes);
      } catch (_) {
        // İzolat kurulamazsa ana izlekte (açılıştaki yolla aynı).
      }
    }
    return PptxEditor.parse(bytes);
  }

  /// Açık düzenlemeyi yazar, destenin güncel baytını verir.
  Future<Uint8List?> _deckBytes() async {
    final editor = _editor;
    if (editor == null) return null;
    if (_textCtrl != null) _partSetState(_commitEdit);
    _flushOutline();
    return editor.saveAsync();
  }

  /// Paket işlemini uygular; yeni bayt (başarısızsa null).
  Future<Uint8List?> _proApply(PptxOp op, {String? doneKey}) async {
    if (_editor == null || _proBusy) return null;
    _partSetState(() => _proBusy = true);
    final failed = context.t('wp.failed');
    final done = doneKey == null ? null : context.t(doneKey);
    try {
      final before = (await _deckBytes())!;
      final after = await PptxPro.run(before, op);
      final next = await _parseDeck(after);
      if (!mounted) return null;
      _proUndo.add(before);
      if (_proUndo.length > 5) _proUndo.removeAt(0);
      // Eski geçmiş eski editör nesnesine bağlı → temizlenir; ↶ artık
      // [_proUndo]'dan geri alır.
      _history.clear();
      _partSetState(() {
        _selShape = null;
        _selSlide = null;
        _editor = next;
        _proBusy = false;
      });
      _session.changed();
      if (done != null && mounted) showSnack(context, done);
      return after;
    } catch (e) {
      _partSetState(() => _proBusy = false);
      if (mounted) {
        showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      }
      return null;
    }
  }

  Future<void> _proUndoLast() async {
    if (_proUndo.isEmpty || _proBusy) return;
    final bytes = _proUndo.removeLast();
    final next = await _parseDeck(bytes);
    if (!mounted) return;
    _history.clear();
    _partSetState(() {
      _selShape = null;
      _selSlide = null;
      _editor = next;
    });
    _session.changed();
  }

  int get _curIndex =>
      ((_selSlide?.index ?? _currentSlide) - 1)
          .clamp(0, (_editor?.slides.length ?? 1) - 1);

  Future<void> _openProTools() async {
    final editor = _editor;
    if (editor == null) return;
    final pick = await showAppActionSheet<String>(context,
        title: context.t('sp.tools'),
        groups: [
          AppActionGroup(title: context.t('sp.g_design'), actions: [
            AppAction(
                value: 'master',
                icon: AppIcons.spaceDashboard,
                label: context.t('sp.master'),
                hint: context.t('sp.master_hint')),
            AppAction(
                value: 'templates',
                icon: AppIcons.autoAwesomeMosaic,
                label: context.t('sp.templates')),
          ]),
          AppActionGroup(title: context.t('sp.g_insert'), actions: [
            AppAction(
                value: 'chart',
                icon: AppIcons.insertChart,
                label: context.t('sp.chart_insert')),
            AppAction(
                value: 'shapes',
                icon: AppIcons.dashboardCustomize,
                label: context.t('sp.shape_library'),
                hint: context.t('sp.shape_library_hint')),
            AppAction(
                value: 'counter',
                icon: AppIcons.hourglassEmpty,
                label: context.t('sp.counter'),
                hint: context.t('sp.counter_hint')),
            AppAction(
                value: 'media',
                icon: AppIcons.videoLibrary,
                label: context.t('sp.media_insert'),
                hint: context.t('sp.media_hint')),
            AppAction(
                value: 'smartart',
                icon: AppIcons.accountTree,
                label: context.t('sp.smartart'),
                hint: context.t('sp.smartart_hint')),
          ]),
          AppActionGroup(title: context.t('sp.g_arrange'), actions: [
            AppAction(
                value: 'layers',
                icon: AppIcons.layers,
                label: context.t('sp.layers_align'),
                hint: context.t('sp.layers_hint')),
            AppAction(
                value: 'anims',
                icon: AppIcons.autoAwesomeMotion,
                label: context.t('sp.anim_order')),
          ]),
          AppActionGroup(title: context.t('sp.g_slides'), actions: [
            AppAction(
                value: 'sections',
                icon: AppIcons.bookmarks,
                label: context.t('sp.sections_title'),
                hint: context.t('sp.sections_hint')),
          ]),
          AppActionGroup(title: context.t('sp.g_show'), actions: [
            AppAction(
                value: 'presenter',
                icon: AppIcons.chromeReaderMode,
                label: context.t('ss.presenter'),
                hint: context.t('sp.presenter_hint')),
            AppAction(
                value: 'record',
                icon: AppIcons.micNone,
                label: context.t('sp.record'),
                hint: context.t('sp.record_hint')),
            AppAction(
                value: 'png_one',
                icon: AppIcons.image,
                label: context.t('sp.png_one')),
            AppAction(
                value: 'png_all',
                icon: AppIcons.photos,
                label: context.t('sp.png_all')),
            AppAction(
                value: 'video',
                icon: AppIcons.video,
                label: context.t('sp.video_export'),
                hint: context.t('sp.video_hint')),
          ]),
        ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'layers' || 'anims':
        final bytes = await _deckBytes();
        if (bytes == null || !mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SlideArrangePage(
                bytes: bytes,
                slide: _curIndex,
                apply: _proApply,
                initialTab: pick == 'anims' ? 1 : 0)));
      case 'sections':
        final bytes = await _deckBytes();
        if (bytes == null || !mounted) return;
        final labels = [
          for (final sl in _editor!.slides)
            sl.paragraphs
                    .map((p) => p.text.trim())
                    .where((t) => t.isNotEmpty)
                    .firstOrNull ??
                context.t('sp.slide_n', {'n': sl.index}),
        ];
        final play = await Navigator.of(context).push<List<int>>(MaterialPageRoute(
            builder: (_) =>
                SlideSectionsPage(bytes: bytes, labels: labels, apply: _proApply)));
        if (play != null && play.isNotEmpty && mounted) await _playList(play);
      case 'presenter':
        await _play(_curIndex, presenter: true);
      case 'record':
        await _recordNarration();
      case 'png_one':
        await _exportImages(only: _curIndex);
      case 'png_all':
        await _exportImages();
      case 'video':
        await _exportVideo();
      case 'chart':
        await _insertChart(_curIndex, SlideChartData.sample);
      case 'smartart':
        await _convertSmartArts();
      case 'media':
        await _insertMedia(_curIndex);
      case 'shapes':
        await _insertFromLibrary(editor.slides[_curIndex]);
      case 'counter':
        await _insertCounter(_curIndex);
      case 'master':
        final bytes = await _deckBytes();
        if (bytes == null || !mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => SlidesMasterPage(bytes: bytes, apply: _proApply)));
      case 'templates':
        final id = await showTemplateGallery(context);
        if (id != null) {
          await _proApply(PptxTemplates.apply(id), doneKey: 'sp.applied');
        }
    }
  }

  /// Bölüm adları (sıralayıcı için), izolatta.
  Future<Map<int, String>> _sectionStartsOf() async {
    final bytes = await _deckBytes();
    if (bytes == null) return const {};
    return PptxPro.query(bytes, sectionStarts);
  }

  /// Özel gösteri: verilen sıralardaki slaytlar (gizli olsalar da) oynar.
  Future<void> _playList(List<int> order) async {
    final editor = _editor;
    if (editor == null) return;
    final views = <SlideVM>[], notes = <String>[], idx = <int>[];
    for (final i in order) {
      if (i < 0 || i >= editor.slides.length) continue;
      final v = editor.slides[i].view;
      if (v == null) continue;
      views.add(v);
      notes.add(editor.notesOf(editor.slides[i]));
      idx.add(i);
    }
    if (views.isEmpty) return;
    final deck = await _deckBytes();
    if (!mounted) return;
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SlideshowScreen(
            slides: views, notes: notes, deck: deck, deckIndex: idx)));
  }

  // ── Madde 9: kayıtlı anlatım ──────────────────────────────────────────────

  Future<void> _recordNarration() async {
    final editor = _editor;
    if (editor == null) return;
    final perm = await Permission.microphone.request();
    if (!mounted) return;
    if (!perm.isGranted) {
      _snack(context.t('sp.mic_denied'));
      return;
    }
    final views = <SlideVM>[], notes = <String>[], idx = <int>[];
    for (var i = 0; i < editor.slides.length; i++) {
      final v = editor.slides[i].view;
      if (v == null || editor.isHidden(editor.slides[i])) continue;
      views.add(v);
      notes.add(editor.notesOf(editor.slides[i]));
      idx.add(i);
    }
    if (views.isEmpty) return;
    final clips = await Navigator.of(context).push<List<NarrationClip>>(MaterialPageRoute(
        builder: (_) => SlideshowScreen(
            slides: views, notes: notes, deckIndex: idx, record: true, presenter: true)));
    if (clips == null || clips.isEmpty || !mounted) return;
    final ok = await showAppConfirm(context,
        title: context.t('sp.record'),
        message: context.t('sp.record_save', {'n': clips.length}),
        confirmLabel: context.t('sp.apply'));
    if (!ok || !mounted) return;
    final data = <(int, Uint8List, int)>[
      for (final c in clips) (c.slide, await File(c.path).readAsBytes(), c.ms),
    ];
    if (!mounted) return;
    await _proApply(_narrationOp(data), doneKey: 'sp.record_done');
    for (final c in clips) {
      try {
        await File(c.path).delete();
      } catch (_) {
        // Geçici dosya: sistem zaten temizler.
      }
    }
  }

  // ── Madde 3: grafik / SmartArt ─────────────────────────────────────────────

  Future<void> _insertChart(int slide, SlideChartData initial) async {
    final d = await Navigator.of(context).push<SlideChartData>(
        MaterialPageRoute(builder: (_) => SlideChartPage(initial: initial)));
    if (d == null || !mounted) return;
    await _proApply(PptxChartOps.insert(slide, d), doneKey: 'sp.applied');
  }

  Future<void> _editChart(int slide, int shapeId) async {
    final bytes = await _deckBytes();
    if (bytes == null) return;
    final d = await PptxPro.query(bytes, _readChart(slide, shapeId));
    if (!mounted) return;
    if (d == null) {
      _snack(context.t('sp.no_chart'));
      return;
    }
    final next = await Navigator.of(context).push<SlideChartData>(
        MaterialPageRoute(builder: (_) => SlideChartPage(initial: d)));
    if (next == null || !mounted) return;
    await _proApply(PptxChartOps.update(slide, shapeId, next),
        doneKey: 'sp.applied');
  }

  Future<void> _chartFromTable(int slide, int tableId) async {
    final bytes = await _deckBytes();
    if (bytes == null) return;
    final d = await PptxPro.query(bytes, _readTable(slide, tableId));
    if (!mounted) return;
    if (d == null) {
      _snack(context.t('sp.table_no_data'));
      return;
    }
    await _insertChart(slide, d);
  }

  Future<void> _convertSmartArts() async {
    final bytes = await _deckBytes();
    if (bytes == null) return;
    final n = await PptxPro.query(bytes, PptxChartOps.countSmartArts);
    if (!mounted) return;
    if (n == 0) {
      _snack(context.t('sp.no_smartart'));
      return;
    }
    await _proApply(PptxChartOps.allSmartArtsToShapes(),
        doneKey: 'sp.smartart_done');
  }

  // ── Madde 4: ses / video ──────────────────────────────────────────────────

  /// Bellek tavanı: medya baytı desteyle birlikte izolata kopyalanır.
  static const _mediaMaxBytes = 150 * 1024 * 1024;

  Future<void> _insertMedia(int slide) async {
    final picked = await AppFilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: PptxMediaOps.mimes.keys.toList(),
    );
    final f = picked?.files.single;
    final path = f?.path;
    if (f == null || path == null || !mounted) return;
    final ext = (f.extension ?? path.split('.').last).toLowerCase();
    if (!PptxMediaOps.isMediaExt(ext)) return;
    final file = File(path);
    if (await file.length() > _mediaMaxBytes) {
      if (mounted) _snack(context.t('sp.media_too_big'));
      return;
    }
    final data = await file.readAsBytes();
    Uint8List? poster;
    if (PptxMediaOps.isVideoExt(ext)) {
      // Kapak: ilk kare (yerel küçük resim üreticisi; olmazsa ses simgesi).
      try {
        final dest = '${Directory.systemTemp.path}/sp_poster_${data.length}.jpg';
        final ok = await FcNativeVideoThumbnail().saveThumbnailToFile(
            srcFile: path, destFile: dest, width: 960, height: 960,
            format: 'jpeg', quality: 80);
        if (ok && await File(dest).exists()) poster = await File(dest).readAsBytes();
      } catch (_) {
        // En iyi çaba: kapaksız video da oynar.
      }
    }
    if (!mounted) return;
    await _proApply(
        PptxMediaOps.insert(slide, data, ext,
            poster: poster, posterExt: 'jpg', name: f.name),
        doneKey: 'sp.media_added');
  }

  // ── Madde 5: PNG / video dışa aktarım ─────────────────────────────────────

  /// Slaytları PNG'e basar (ekrandaki çizimle aynı); [ratio] punto başına
  /// piksel. İlerleme [progress]'e yazılır. Ekran kapanırsa null.
  Future<List<String>?> _renderPngs(Directory dir, double Function(SlideVM) ratio,
      ValueNotifier<String> progress, {int? only}) async {
    final editor = _editor!;
    final out = <String>[];
    for (var i = 0; i < editor.slides.length; i++) {
      if (only != null && i != only) continue;
      if (only == null && editor.isHidden(editor.slides[i])) continue;
      final view = editor.slides[i].view;
      if (view == null) continue;
      if (!mounted) return null;
      progress.value =
          context.t('sl.pdf_progress', {'n': i + 1, 'total': editor.slides.length});
      final png = await SlideSnapshot.toPng(context, view, pixelRatio: ratio(view));
      if (png == null) return null;
      final f = File('${dir.path}/${_stem(widget.name)}-${(i + 1).toString().padLeft(3, '0')}.png');
      await f.writeAsBytes(png);
      out.add(f.path);
    }
    return out;
  }

  BusyDialog _progressDialog(ValueNotifier<String> progress) => showBusyDialog(
        context,
        builder: (_) => AlertDialog(
          content: Row(children: [
            const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
            const SizedBox(width: 16),
            Expanded(
              child: ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (_, v, _) => Text(v),
              ),
            ),
          ]),
        ),
      );

  Future<void> _exportImages({int? only}) async {
    if (_editor == null) return;
    await _deckBytes(); // açık düzenleme modele yazılsın
    if (!mounted) return;
    final progress = ValueNotifier<String>('');
    final busy = _progressDialog(progress);
    try {
      final dir = await Directory.systemTemp.createTemp('slayt-png');
      // 1920 px genişlik (Full HD) — tek tek paylaşımda okunur, zip'te makul.
      final paths = await _renderPngs(dir, (v) => 1920 / v.widthPt, progress, only: only);
      if (paths == null || paths.isEmpty) return;
      String share;
      if (paths.length == 1) {
        share = paths.single;
      } else {
        final archive = Archive();
        for (final p in paths) {
          final b = await File(p).readAsBytes();
          archive.addFile(ArchiveFile(p.split('/').last, b.length, b));
        }
        final zip = await SaveIsolate.encodeZip(archive);
        final f = File('${dir.path}/${_stem(widget.name)}-png.zip');
        await f.writeAsBytes(zip);
        share = f.path;
      }
      busy.close();
      if (!mounted) return;
      await SharePlus.instance.share(ShareParams(files: [XFile(share)], text: widget.name));
    } catch (e) {
      busy.close();
      if (mounted) showUserError(context, e);
    } finally {
      busy.close();
      progress.dispose();
    }
  }

  Future<void> _exportVideo() async {
    final editor = _editor;
    if (editor == null) return;
    final secs = await promptNumber(context, context.t('sp.video_seconds'),
        initial: 5, min: 1, max: 600);
    if (secs == null || !mounted) return;
    final bytes = await _deckBytes();
    if (bytes == null || !mounted) return;
    // Kayıtlı zamanlama (advTm, ör. anlatım) varsa o kullanılır.
    final info = await PptxPro.query(bytes, PptxShowInfo.read);
    if (!mounted) return;
    final progress = ValueNotifier<String>('');
    final busy = _progressDialog(progress);
    try {
      final dir = await Directory.systemTemp.createTemp('slayt-video');
      final paths = await _renderPngs(dir, (v) => 1920 / v.widthPt, progress);
      if (paths == null || paths.isEmpty || !mounted) return;
      final durations = <int>[];
      for (var i = 0; i < editor.slides.length; i++) {
        if (editor.isHidden(editor.slides[i]) || editor.slides[i].view == null) continue;
        durations.add(i < info.length && (info[i].advanceMs ?? 0) > 0
            ? info[i].advanceMs!
            : (secs * 1000).round());
      }
      progress.value = context.t('sp.video_encoding');
      final first = editor.slides.firstWhere((s) => s.view != null).view!;
      final h = (1920 * first.heightPt / first.widthPt).round();
      final out = '${dir.path}/${_stem(widget.name)}.mp4';
      final done = await SlidesNative.video(paths, durations, out, 1920, h);
      busy.close();
      if (!mounted) return;
      if (done == null) {
        _snack(context.t('sp.video_unavailable'));
        return;
      }
      await SharePlus.instance.share(ShareParams(files: [XFile(done)], text: widget.name));
    } catch (e) {
      busy.close();
      if (mounted) showUserError(context, e);
    } finally {
      busy.close();
      progress.dispose();
    }
  }

  // ── Şekil araçları (seçili şekil) ─────────────────────────────────────────

  Future<void> _openShapeTools(PptxSlide slide, ShapeVM shape) async {
    final i = slide.index - 1;
    final isChart = shape.chart != null;
    final isTable = shape.tableFrame;
    final pick = await showAppActionSheet<String>(context,
        title: context.t('sp.shape_tools'),
        groups: [
          AppActionGroup(actions: [
            if (isChart)
              AppAction(
                  value: 'chart_edit',
                  icon: AppIcons.insertChart,
                  label: context.t('sp.chart_edit')),
            if (isTable)
              AppAction(
                  value: 'chart_table',
                  icon: AppIcons.barChart,
                  label: context.t('sp.chart_from_table')),
            ..._shapeProActions(shape),
          ]),
        ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'chart_edit':
        await _editChart(i, shape.id);
      case 'chart_table':
        await _chartFromTable(i, shape.id);
      default:
        await _runShapePro(pick, slide, shape);
    }
  }
}

/// İzolata giden okuyucular yalnız sayıları yakalar (durum nesnesini değil).
SlideChartData? Function(PptxPackage) _readChart(int slide, int id) =>
    (pkg) => PptxChartOps.read(pkg, slide, id);

SlideChartData? Function(PptxPackage) _readTable(int slide, int id) =>
    (pkg) => PptxChartOps.fromTable(pkg, slide, id);

PptxOp _narrationOp(List<(int, Uint8List, int)> clips) => (pkg) {
      for (final (slide, audio, ms) in clips) {
        PptxMediaOps.setNarration(slide, audio, ms)(pkg);
      }
    };

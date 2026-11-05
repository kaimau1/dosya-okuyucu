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
                value: 'smartart',
                icon: AppIcons.accountTree,
                label: context.t('sp.smartart'),
                hint: context.t('sp.smartart_hint')),
          ]),
        ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'chart':
        await _insertChart(_curIndex, SlideChartData.sample);
      case 'smartart':
        await _convertSmartArts();
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

  // ── Madde 3: grafik / SmartArt ─────────────────────────────────────────────

  Future<void> _insertChart(int slide, SlideChartData initial,
      {int? tableId}) async {
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
          ]),
        ]);
    if (pick == null || !mounted) return;
    switch (pick) {
      case 'chart_edit':
        await _editChart(i, shape.id);
      case 'chart_table':
        await _chartFromTable(i, shape.id);
    }
  }
}

/// İzolata giden okuyucular yalnız sayıları yakalar (durum nesnesini değil).
SlideChartData? Function(PptxPackage) _readChart(int slide, int id) =>
    (pkg) => PptxChartOps.read(pkg, slide, id);

SlideChartData? Function(PptxPackage) _readTable(int slide, int id) =>
    (pkg) => PptxChartOps.fromTable(pkg, slide, id);

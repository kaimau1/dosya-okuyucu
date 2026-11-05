part of '../word_mobile_editor_screen.dart';

/// **Faz 37 — Word pro araçları.** Araçlar sekmesindeki her düğme
/// [_WordMobileEditorScreenState._onPro] kapısından geçer. Yapısal işlemler
/// (stil tanımı, bölüm, tablo ızgarası, denklem, şekil …) paket düzeyinde
/// izolatta koşar ([DocxPro.run]); sonuç yeniden ayrıştırılıp editöre bağlanır,
/// önceki bayt [_proUndo]'ya girer (üst çubuktaki ↶ onu da geri alır).
extension _WordProPart on _WordMobileEditorScreenState {
  static const flagKey = 'word_pro_v1';

  Future<void> _loadProFlag() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final on = prefs.getBool(flagKey) ?? true;
      if (on != _proOn && mounted) _setState(() => _proOn = on);
    } catch (_) {}
  }

  void _setState(VoidCallback f) {
    if (mounted) {
      // ignore: invalid_use_of_protected_member
      setState(f);
    }
  }

  /// Paket işlemini uygular. [keepPara]: işlem sonrası imlecin konacağı
  /// paragraf (null → işlem öncesi imleç).
  Future<bool> _proApply(DocxOp op, {int? keepPara, String? doneKey}) async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null || _proBusy) return false;
    final caret = keepPara ?? c.extent.para;
    _setState(() => _proBusy = true);
    final done = doneKey == null ? null : context.t(doneKey);
    final failed = context.t('wp.failed');
    try {
      final before = await doc.saveAsync();
      final after = await DocxPro.run(before, op);
      final parsed = WordMobileEditorScreen.parseInIsolate
          ? await compute(_WordMobileEditorScreenState._parse, after)
          : _WordMobileEditorScreenState._parse(after);
      if (!mounted) return false;
      _proUndo.add(before);
      if (_proUndo.length > 5) _proUndo.removeAt(0);
      _setState(() {
        _attach(parsed);
        _proBusy = false;
      });
      _session.changed();
      _placeCaret(caret);
      if (done != null && mounted) showSnack(context, done);
      return true;
    } catch (e) {
      _setState(() => _proBusy = false);
      if (mounted) {
        showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      }
      return false;
    }
  }

  void _placeCaret(int i) {
    final c = _ctrl;
    if (c == null || c.paras.isEmpty) return;
    final at = i.clamp(0, c.paras.length - 1);
    c.select(DocPos(at, 0), DocPos(at, 0));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_viewKey.currentState?.revealParagraph(at));
    });
  }

  Future<void> _proUndoLast() async {
    if (_proUndo.isEmpty || _proBusy) return;
    final caret = _ctrl?.extent.para ?? 0;
    final bytes = _proUndo.removeLast();
    final parsed = WordMobileEditorScreen.parseInIsolate
        ? await compute(_WordMobileEditorScreenState._parse, bytes)
        : _WordMobileEditorScreenState._parse(bytes);
    if (!mounted) return;
    _setState(() => _attach(parsed));
    _session.changed();
    _placeCaret(caret);
  }

  Future<void> _onPro(String id) async {
    final c = _ctrl;
    if (c == null || _proBusy) return;
    switch (id) {
      case 'style_update':
        await _proApply(DocxStyleOps.updateStyleFromParagraph(c.extent.para),
            doneKey: 'wp.style_updated');
      case 'theme':
        await _pickTheme();
      case 'page_setup':
        await _pageSetup();
      case 'print_preview':
        await _printPreview();
      case 'equation':
        await _equation();
      case 'tbl_merge':
        final dir = await _choose('wp.tbl_merge', const [
          ('right', 'wp.tbl_merge_right'),
          ('down', 'wp.tbl_merge_down'),
        ]);
        if (dir == null) return;
        await _tableOp(dir == 'right'
            ? DocxTableOps.mergeRight(c.extent.para)
            : DocxTableOps.mergeDown(c.extent.para));
      case 'tbl_split':
        await _tableOp(DocxTableOps.split(c.extent.para));
      case 'tbl_borders':
        final v = await _choose('wp.tbl_borders', const [
          ('all', 'wp.tbl_b_all'),
          ('outer', 'wp.tbl_b_outer'),
          ('inner', 'wp.tbl_b_inner'),
          ('none', 'wp.tbl_b_none'),
        ]);
        if (v != null) await _tableOp(DocxTableOps.borders(c.extent.para, v));
      case 'tbl_autofit':
        final v = await _choose('wp.tbl_autofit', const [
          ('content', 'wp.tbl_fit_content'),
          ('window', 'wp.tbl_fit_window'),
          ('fixed', 'wp.tbl_fit_fixed'),
        ]);
        if (v != null) await _tableOp(DocxTableOps.autofit(c.extent.para, v));
      case 'tbl_sort':
        final v = await _choose('wp.tbl_sort', const [
          ('asc_h', 'wp.tbl_sort_asc_h'),
          ('desc_h', 'wp.tbl_sort_desc_h'),
          ('asc', 'wp.tbl_sort_asc'),
          ('desc', 'wp.tbl_sort_desc'),
        ]);
        if (v != null) {
          await _tableOp(DocxTableOps.sort(c.extent.para,
              descending: v.startsWith('desc'), header: v.endsWith('_h')));
        }
    }
  }

  /// Tek seçimli levha: (değer, etiket anahtarı) listesi.
  Future<String?> _choose(String titleKey, List<(String, String)> items) =>
      showAppSheet<String>(
        context,
        title: context.t(titleKey),
        builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (v, k) in items)
              ListTile(
                key: ValueKey('word-choose-$v'),
                title: Text(ctx.t(k)),
                onTap: () => Navigator.pop(ctx, v),
              ),
          ],
        ),
      );

  // ── Madde 1: stil + tema ─────────────────────────────────────────────────

  Future<void> _pickTheme() async {
    final doc = _doc;
    if (doc == null) return;
    final bytes = await doc.saveAsync();
    final (_, body) = await DocxPro.query(bytes, DocxStyleOps.themeFonts);
    if (!mounted) return;
    final set = await showAppSheet<DocxStyleSet>(
      context,
      title: context.t('wp.theme'),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in kDocxStyleSets)
            ListTile(
              key: ValueKey('word-theme-${s.id}'),
              title: Text(ctx.t('wp.theme_${s.id}'),
                  style: TextStyle(
                      fontFamily: renderFamilyFor(s.headingFont),
                      fontWeight: FontWeight.w600)),
              subtitle: Text('${s.headingFont} · ${s.bodyFont} · ${s.bodyPt.round()} pt',
                  style: TextStyle(fontFamily: renderFamilyFor(s.bodyFont))),
              trailing: body == s.bodyFont ? const Icon(AppIcons.check) : null,
              onTap: () => Navigator.pop(ctx, s),
            ),
        ],
      ),
    );
    if (set == null || !mounted) return;
    await _proApply(DocxStyleOps.applyStyleSet(set), doneKey: 'wp.theme_applied');
  }

  // ── Madde 2: sayfa düzeni + baskı önizleme ───────────────────────────────

  Future<void> _pageSetup() async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null) return;
    final bytes = await doc.saveAsync();
    final spec = await DocxPro.query(bytes, DocxLayoutOps.read);
    if (!mounted) return;
    final r = await showAppSheet<(String, DocxPageSpec)>(
      context,
      title: context.t('wp.page_setup'),
      builder: (_) => _PageSetupSheet(spec: spec),
    );
    if (r == null || !mounted) return;
    switch (r.$1) {
      case 'break':
        c.insertPageBreak();
      case 'preview':
        await _proApply(DocxLayoutOps.apply(r.$2));
        await _printPreview();
      default:
        await _proApply(DocxLayoutOps.apply(r.$2), doneKey: 'wp.page_applied');
    }
  }

  /// Yazdırma önizlemesi: kendi PDF çizicimiz (gömülü yazı tipleri) →
  /// sistemin yazdırma ekranı (önizleme + yazıcı/PDF kaydı).
  Future<void> _printPreview() async {
    final pdf = await _renderPdf();
    if (pdf == null || !mounted) return;
    await Printing.layoutPdf(onLayout: (_) async => pdf, name: widget.name);
  }

  Future<Uint8List?> _renderPdf() async {
    final doc = _doc;
    if (doc == null) return null;
    final failed = context.t('wp.failed');
    _setState(() => _proBusy = true);
    try {
      final bytes = await doc.saveAsync();
      final fonts = await DocxPdfFonts.load();
      return await DocxPdf.renderInBackground(bytes, fonts: fonts);
    } catch (e) {
      if (mounted) {
        showSnack(context, failed.replaceAll('{error}', userErrorText(e)));
      }
      return null;
    } finally {
      _setState(() => _proBusy = false);
    }
  }

  // ── Madde 3: denklem + tablo ─────────────────────────────────────────────

  Future<void> _tableOp(DocxOp op) async {
    final c = _ctrl;
    if (c == null) return;
    if (!c.inTable) {
      showSnack(context, context.t('wp.tbl_err_no_table'));
      return;
    }
    final msgs = {
      for (final k in const ['no_table', 'no_neighbor', 'shape', 'not_merged', 'merged'])
        k: context.t('wp.tbl_err_$k'),
    };
    final doc = _doc!;
    // Tablo hatası işlemden önce denetlenir (yanlış yere yazılmasın).
    final bytes = await doc.saveAsync();
    try {
      await DocxPro.run(bytes, op);
    } on DocxTableException catch (e) {
      if (mounted) showSnack(context, msgs[e.code] ?? e.code);
      return;
    } catch (_) {}
    if (mounted) await _proApply(op);
  }

  Future<void> _equation() async {
    final doc = _doc;
    final c = _ctrl;
    if (doc == null || c == null) return;
    final i = c.extent.para;
    final bytes = await doc.saveAsync();
    final existing = await DocxPro.query(bytes, _readMath(i));
    if (!mounted) return;
    final latex = await showAppSheet<String>(
      context,
      title: context.t(existing.isEmpty ? 'wp.equation' : 'wp.equation_edit'),
      builder: (_) => _EquationSheet(initial: existing.firstOrNull ?? ''),
    );
    if (latex == null || latex.trim().isEmpty || !mounted) return;
    await _proApply(
        existing.isEmpty
            ? DocxMathOps.insert(i, latex.trim())
            : DocxMathOps.replace(i, 0, latex.trim()),
        keepPara: existing.isEmpty ? i + 1 : i);
  }

  static List<String> Function(DocxPackage) _readMath(int i) =>
      (pkg) => DocxMathOps.read(pkg, i);
}

/// Sayfa düzeni levhası: kâğıt, yön, kenar boşlukları (cm), cilt payı,
/// sütun, farklı ilk sayfa. Döner: ('apply' | 'preview' | 'break', değerler).
class _PageSetupSheet extends StatefulWidget {
  final DocxPageSpec spec;
  const _PageSetupSheet({required this.spec});

  @override
  State<_PageSetupSheet> createState() => _PageSetupSheetState();
}

class _PageSetupSheetState extends State<_PageSetupSheet> {
  late DocxPageSpec _s = widget.spec;
  late final _fields = {
    'top': TextEditingController(text: _cm(_s.top)),
    'bottom': TextEditingController(text: _cm(_s.bottom)),
    'left': TextEditingController(text: _cm(_s.left)),
    'right': TextEditingController(text: _cm(_s.right)),
    'gutter': TextEditingController(text: _cm(_s.gutter)),
  };

  static String _cm(int tw) =>
      DocxPageSpec.twipToCm(tw).toStringAsFixed(2).replaceAll(RegExp(r'0$'), '');

  @override
  void dispose() {
    for (final f in _fields.values) {
      f.dispose();
    }
    super.dispose();
  }

  String get _paper {
    final short = _s.width < _s.height ? _s.width : _s.height;
    final long = _s.width < _s.height ? _s.height : _s.width;
    for (final e in kDocxPaperSizes.entries) {
      if ((e.value.$1 - short).abs() <= 40 && (e.value.$2 - long).abs() <= 40) {
        return e.key;
      }
    }
    return 'custom';
  }

  DocxPageSpec _collect() {
    int f(String k, int def) {
      final v = double.tryParse(_fields[k]!.text.replaceAll(',', '.'));
      if (v == null || v < 0 || v > 20) return def;
      return DocxPageSpec.cmToTwip(v);
    }

    return _s.copyWith(
      top: f('top', _s.top),
      bottom: f('bottom', _s.bottom),
      left: f('left', _s.left),
      right: f('right', _s.right),
      gutter: f('gutter', _s.gutter),
    );
  }

  Widget _field(String k) => Expanded(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: TextField(
            key: ValueKey('word-ps-$k'),
            controller: _fields[k],
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: context.t('wp.margin_$k'), suffixText: 'cm',
                isDense: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final paper = _paper;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Expanded(child: Text(context.t('word.paper_size'))),
            DropdownButton<String>(
              key: const ValueKey('word-ps-paper'),
              value: paper,
              onChanged: (k) {
                final v = kDocxPaperSizes[k];
                if (v == null) return;
                setState(() => _s = _s.copyWith(width: v.$1, height: v.$2));
              },
              items: [
                for (final k in kDocxPaperSizes.keys)
                  DropdownMenuItem(value: k, child: Text(k.toUpperCase())),
                if (paper == 'custom')
                  DropdownMenuItem(
                      value: 'custom', child: Text(context.t('wp.custom'))),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            key: const ValueKey('word-ps-orient'),
            segments: [
              ButtonSegment(value: false, label: Text(context.t('word.portrait'))),
              ButtonSegment(value: true, label: Text(context.t('word.landscape'))),
            ],
            selected: {_s.landscape},
            onSelectionChanged: (v) =>
                setState(() => _s = _s.copyWith(landscape: v.first)),
          ),
          const SizedBox(height: 12),
          Text(context.t('word.margins'), style: context.type.small),
          Row(children: [_field('top'), _field('bottom')]),
          Row(children: [_field('left'), _field('right')]),
          Row(children: [_field('gutter'), const Spacer()]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Text(context.t('word.columns'))),
            SegmentedButton<int>(
              key: const ValueKey('word-ps-cols'),
              segments: [
                for (final n in const [1, 2, 3])
                  ButtonSegment(value: n, label: Text('$n')),
              ],
              selected: {_s.columns.clamp(1, 3)},
              onSelectionChanged: (v) =>
                  setState(() => _s = _s.copyWith(columns: v.first)),
            ),
          ]),
          SwitchListTile(
            key: const ValueKey('word-ps-title'),
            contentPadding: EdgeInsets.zero,
            title: Text(context.t('wp.title_page')),
            value: _s.titlePage,
            onChanged: (v) => setState(() => _s = _s.copyWith(titlePage: v)),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                key: const ValueKey('word-ps-break'),
                icon: const Icon(AppIcons.wrapText),
                label: Text(context.t('word.insert_break')),
                onPressed: () => Navigator.pop(context, ('break', _s)),
              ),
              OutlinedButton.icon(
                key: const ValueKey('word-ps-preview'),
                icon: const Icon(AppIcons.print),
                label: Text(context.t('wp.print_preview')),
                onPressed: () => Navigator.pop(context, ('preview', _collect())),
              ),
              FilledButton(
                key: const ValueKey('word-ps-apply'),
                onPressed: () => Navigator.pop(context, ('apply', _collect())),
                child: Text(context.t('common.apply')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Denklem levhası: LaTeX girişi + hızlı simgeler.
class _EquationSheet extends StatefulWidget {
  final String initial;
  const _EquationSheet({required this.initial});

  @override
  State<_EquationSheet> createState() => _EquationSheetState();
}

class _EquationSheetState extends State<_EquationSheet> {
  late final _t = TextEditingController(text: widget.initial);

  static const _snippets = [
    (r'\frac{a}{b}', 'a/b'),
    (r'x^{2}', 'x²'),
    (r'x_{i}', 'xᵢ'),
    (r'\sqrt{x}', '√x'),
    (r'\sum_{i=1}^{n} ', '∑'),
    (r'\int_{a}^{b} ', '∫'),
    (r'\left( \right)', '( )'),
    (r'\pi', 'π'),
    (r'\alpha', 'α'),
    (r'\theta', 'θ'),
    (r'\infty', '∞'),
    (r'\pm', '±'),
    (r'\times', '×'),
    (r'\leq', '≤'),
    (r'\geq', '≥'),
    (r'\neq', '≠'),
  ];

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  void _insert(String snippet) {
    final sel = _t.selection;
    final text = _t.text;
    final at = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    final out = text.replaceRange(at, end, snippet);
    _t.value = TextEditingValue(
        text: out,
        selection: TextSelection.collapsed(offset: at + snippet.length));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('word-eq-field'),
            controller: _t,
            autofocus: true,
            minLines: 2,
            maxLines: 5,
            style: context.type.body.copyWith(fontFamily: 'monospace'),
            decoration: InputDecoration(
              labelText: context.t('wp.equation_latex'),
              hintText: r'\frac{-b \pm \sqrt{b^2-4ac}}{2a}',
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (snip, label) in _snippets)
                ActionChip(
                  label: Text(label),
                  onPressed: () => _insert(snip),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-eq-ok'),
              onPressed: () => Navigator.pop(context, _t.text),
              child: Text(context.t(widget.initial.isEmpty ? 'common.insert' : 'common.apply')),
            ),
          ),
        ],
      ),
    );
  }
}

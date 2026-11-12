part of '../word_mobile_editor_screen.dart';

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


/// Gizli girişli parola levhası; [confirm] → ikinci alan, eşleşme denetimi.
class _WordPasswordSheet extends StatefulWidget {
  final String? error;
  final bool confirm;
  const _WordPasswordSheet({this.error, this.confirm = false});

  @override
  State<_WordPasswordSheet> createState() => _WordPasswordSheetState();
}

class _WordPasswordSheetState extends State<_WordPasswordSheet> {
  final _a = TextEditingController();
  final _b = TextEditingController();
  String? _err;

  @override
  void initState() {
    super.initState();
    _err = widget.error;
  }

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  void _ok() {
    if (_a.text.isEmpty) return;
    if (widget.confirm && _a.text != _b.text) {
      setState(() => _err = context.t('xp.password_mismatch'));
      return;
    }
    Navigator.pop(context, _a.text);
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
            key: const ValueKey('word-pw-field'),
            controller: _a,
            obscureText: true,
            autofocus: true,
            decoration: InputDecoration(labelText: context.t('xp.password')),
            onSubmitted: (_) => widget.confirm ? null : _ok(),
          ),
          if (widget.confirm)
            TextField(
              key: const ValueKey('word-pw-again'),
              controller: _b,
              obscureText: true,
              decoration:
                  InputDecoration(labelText: context.t('xp.password_again')),
              onSubmitted: (_) => _ok(),
            ),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_err!,
                  style: context.type.small
                      .copyWith(color: Theme.of(context).colorScheme.error)),
            ),
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-pw-ok'),
              onPressed: _ok,
              child: Text(context.t('common.ok')),
            ),
          ),
        ],
      ),
    );
  }
}


/// Satır içi AI levhası: görev çipleri → önizleme → Değiştir / Altına ekle.
/// İstek sürerken "Vazgeç" yanıtı yok sayar (iptal; anayasa: AI çağrıları
/// iptal edilebilir).
class _AiInlineSheet extends StatefulWidget {
  final String text;
  const _AiInlineSheet({required this.text});

  @override
  State<_AiInlineSheet> createState() => _AiInlineSheetState();
}

class _AiInlineSheetState extends State<_AiInlineSheet> {
  String? _task;
  String? _result;
  String? _error;
  int _gen = 0;
  bool _busy = false;
  String _lang = 'en';

  static const _langs = ['tr', 'en', 'de', 'fr', 'es', 'ar', 'ru'];

  Future<void> _run(String task) async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('aia.need_key'));
      return;
    }
    final instruction = context.t('wp.ai_p_$task',
        {'lang': context.t('wp.lang_$_lang')});
    final gen = ++_gen;
    setState(() {
      _task = task;
      _busy = true;
      _error = null;
      _result = null;
    });
    try {
      final answer = await state.gemini.chat(history: [
        ChatTurn(fromUser: true, text: DocxAi.prompt(instruction, widget.text)),
      ]);
      if (!mounted || gen != _gen) return;
      setState(() {
        _busy = false;
        _result = DocxAi.clean(answer);
      });
    } catch (e) {
      if (!mounted || gen != _gen) return;
      setState(() {
        _busy = false;
        _error = userErrorText(e);
      });
    }
  }

  void _cancel() => setState(() {
        _gen++;
        _busy = false;
      });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.type.small.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final t in kWordAiTasks)
                ChoiceChip(
                  key: ValueKey('word-ai-$t'),
                  label: Text(context.t('wp.ai_$t')),
                  selected: _task == t,
                  onSelected: _busy ? null : (_) => _run(t),
                ),
            ],
          ),
          Row(children: [
            Text(context.t('wp.ai_target')),
            const SizedBox(width: 8),
            DropdownButton<String>(
              value: _lang,
              onChanged: _busy ? null : (v) => setState(() => _lang = v ?? _lang),
              items: [
                for (final l in _langs)
                  DropdownMenuItem(value: l, child: Text(context.t('wp.lang_$l'))),
              ],
            ),
          ]),
          if (_busy)
            Row(children: [
              const Expanded(child: LinearProgressIndicator()),
              TextButton(
                key: const ValueKey('word-ai-cancel'),
                onPressed: _cancel,
                child: Text(context.t('common.cancel')),
              ),
            ]),
          if (_error != null)
            Text(_error!, style: context.type.small.copyWith(color: scheme.error)),
          if (_result != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: SingleChildScrollView(
                child: SelectableText(_result!,
                    key: const ValueKey('word-ai-result')),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              children: [
                OutlinedButton(
                  key: const ValueKey('word-ai-below'),
                  onPressed: () => Navigator.pop(context, ('below', _result!)),
                  child: Text(context.t('wp.ai_below')),
                ),
                FilledButton(
                  key: const ValueKey('word-ai-replace'),
                  onPressed: () => Navigator.pop(context, ('replace', _result!)),
                  child: Text(context.t('wp.ai_replace')),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}


/// Başlık ağacı: alt başlıkları olan düğüm katlanır; imlecin bulunduğu
/// başlık vurgulu; sağda tahmini sayfa.
class _OutlineTree extends StatefulWidget {
  final List<(int, int, String)> headings;
  final List<int> pages;
  final int current;
  const _OutlineTree(
      {required this.headings, required this.pages, required this.current});

  @override
  State<_OutlineTree> createState() => _OutlineTreeState();
}

class _OutlineTreeState extends State<_OutlineTree> {
  final _collapsed = <int>{};

  bool _hasKids(int k) {
    final hs = widget.headings;
    return k + 1 < hs.length && hs[k + 1].$2 > hs[k].$2;
  }

  bool _hidden(int k) {
    final hs = widget.headings;
    var level = hs[k].$2;
    for (var j = k - 1; j >= 0; j--) {
      if (hs[j].$2 < level) {
        if (_collapsed.contains(j)) return true;
        level = hs[j].$2;
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final hs = widget.headings;
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: hs.length,
        itemBuilder: (_, k) {
          if (_hidden(k)) return const SizedBox.shrink();
          final (i, level, text) = hs[k];
          final kidsHere = _hasKids(k);
          final page = i < widget.pages.length ? widget.pages[i] + 1 : null;
          return ListTile(
            key: ValueKey('word-outline-$i'),
            selected: k == widget.current,
            selectedTileColor: scheme.secondaryContainer,
            contentPadding: EdgeInsetsDirectional.only(
                start: 4.0 + (level - 1).clamp(0, 5) * 18, end: 12),
            leading: kidsHere
                ? IconButton(
                    key: ValueKey('word-outline-fold-$i'),
                    tooltip: context.t('wp.outline_fold'),
                    icon: Icon(_collapsed.contains(k)
                        ? AppIcons.keyboardArrowRight
                        : AppIcons.keyboardArrowDown),
                    onPressed: () => setState(() => _collapsed.contains(k)
                        ? _collapsed.remove(k)
                        : _collapsed.add(k)),
                  )
                : const SizedBox(width: 48),
            title: Text(text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: level == 1 ? const TextStyle(fontWeight: FontWeight.w600) : null),
            trailing: page == null ? null : Text('$page', style: context.type.small),
            onTap: () => Navigator.pop(context, i),
          );
        },
      ),
    );
  }
}

/// Sayfa küçük resimleri: PDF sayfaları düşük çözünürlükte, geldikçe
/// (akış); levha kapanınca akış durur. Görsel bütçesi: `cacheWidth`.
class _ThumbGrid extends StatefulWidget {
  final Uint8List pdf;
  const _ThumbGrid({required this.pdf});

  @override
  State<_ThumbGrid> createState() => _ThumbGridState();
}

class _ThumbGridState extends State<_ThumbGrid> {
  final _pages = <Uint8List>[];
  StreamSubscription<dynamic>? _sub;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _sub = Printing.raster(widget.pdf, dpi: 28).asyncMap((r) => r.toPng()).listen(
          (png) {
            if (mounted) setState(() => _pages.add(png));
          },
          onDone: () {
            if (mounted) setState(() => _done = true);
          },
          onError: (_) {
            if (mounted) setState(() => _done = true);
          },
        );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);
    const tileW = 104.0;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_done) const LinearProgressIndicator(minHeight: 2),
          Flexible(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: tileW + 16,
                  mainAxisExtent: tileW * 1.414 + 28,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8),
              itemCount: _pages.length,
              itemBuilder: (_, i) => RepaintBoundary(
                child: InkWell(
                  key: ValueKey('word-thumb-$i'),
                  onTap: () => Navigator.pop(context, i),
                  child: Column(children: [
                    Expanded(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                            border: Border.all(
                                color: Theme.of(context).colorScheme.outlineVariant)),
                        child: Image.memory(_pages[i],
                            cacheWidth: (tileW * dpr).round(),
                            fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('${i + 1}', style: context.type.small),
                  ]),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


/// Birkaç metin alanlı form levhası; değerleri sırayla döndürür.
class _FormSheet extends StatefulWidget {
  /// (kimlik, etiket, başlangıç değeri)
  final List<(String, String, String)> fields;
  const _FormSheet({required this.fields});

  @override
  State<_FormSheet> createState() => _FormSheetState();
}

class _FormSheetState extends State<_FormSheet> {
  late final _c = [
    for (final f in widget.fields) TextEditingController(text: f.$3),
  ];

  @override
  void dispose() {
    for (final c in _c) {
      c.dispose();
    }
    super.dispose();
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
          for (var i = 0; i < widget.fields.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: TextField(
                key: ValueKey('word-form-${widget.fields[i].$1}'),
                controller: _c[i],
                autofocus: i == 0,
                decoration: InputDecoration(labelText: widget.fields[i].$2),
              ),
            ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const ValueKey('word-form-ok'),
              onPressed: () =>
                  Navigator.pop(context, [for (final c in _c) c.text]),
              child: Text(context.t('common.insert')),
            ),
          ),
        ],
      ),
    );
  }
}


/// Paragrafları ~3000 harflik parçalara toplar (tek istek = tek parça).
List<List<(int, String)>> proofChunks(List<(int, String)> paras, {int limit = 3000}) {
  final out = <List<(int, String)>>[];
  var cur = <(int, String)>[];
  var size = 0;
  for (final p in paras) {
    if (p.$2.trim().isEmpty) continue;
    if (size + p.$2.length > limit && cur.isNotEmpty) {
      out.add(cur);
      cur = [];
      size = 0;
    }
    cur.add(p);
    size += p.$2.length;
  }
  if (cur.isNotEmpty) out.add(cur);
  return out;
}

/// AI yazım denetimi levhası: parçalar sırayla gönderilir; her öneri
/// "Uygula / Atla" (belgeye kendiliğinden yazılmaz); "Durdur" iptal eder.
class _ProofSheet extends StatefulWidget {
  final List<List<(int, String)>> chunks;
  final String language;
  final bool Function(int para, String wrong, String right) apply;
  const _ProofSheet(
      {required this.chunks, required this.language, required this.apply});

  @override
  State<_ProofSheet> createState() => _ProofSheetState();
}

class _ProofSheetState extends State<_ProofSheet> {
  final _items = <(int, ProofSuggestion)>[];
  int _done = 0;
  bool _stopped = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  @override
  void dispose() {
    _stopped = true;
    super.dispose();
  }

  Future<void> _run() async {
    final state = context.read<AppState>();
    if (!state.hasApiKey) {
      setState(() => _error = context.t('aia.need_key'));
      return;
    }
    for (final chunk in widget.chunks) {
      if (_stopped || !mounted) return;
      final text = chunk.map((p) => p.$2).join('\n');
      try {
        final answer = await state.gemini.chat(history: [
          ChatTurn(fromUser: true, text: DocxAi.proofPrompt(text, widget.language)),
        ]);
        if (_stopped || !mounted) return;
        final found = DocxAi.parseProof(answer, text);
        setState(() {
          for (final s in found) {
            final p = chunk.firstWhere((x) => x.$2.contains(s.wrong), orElse: () => chunk.first);
            _items.add((p.$1, s));
          }
          _done++;
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = userErrorText(e);
          _done = widget.chunks.length;
        });
        return;
      }
    }
  }

  void _apply(int k) {
    final (para, s) = _items[k];
    widget.apply(para, s.wrong, s.right);
    setState(() => _items.removeAt(k));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = _done < widget.chunks.length && !_stopped && _error == null;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (busy)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(
                    child: LinearProgressIndicator(
                        value: (_done + 0.5) / widget.chunks.length)),
                TextButton(
                  key: const ValueKey('word-proof-stop'),
                  onPressed: () => setState(() => _stopped = true),
                  child: Text(context.t('wp.proof_stop')),
                ),
              ]),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(_error!, style: context.type.small.copyWith(color: scheme.error)),
            ),
          if (!busy && _items.isEmpty && _error == null)
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(context.t('wp.proof_clean'), textAlign: TextAlign.center),
            ),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _items.length,
              itemBuilder: (_, k) {
                final s = _items[k].$2;
                return ListTile(
                  key: ValueKey('word-proof-$k'),
                  title: Text.rich(TextSpan(children: [
                    TextSpan(
                        text: s.wrong,
                        style: TextStyle(
                            decoration: TextDecoration.lineThrough,
                            color: scheme.error)),
                    const TextSpan(text: '  →  '),
                    TextSpan(
                        text: s.right,
                        style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w600)),
                  ])),
                  subtitle: s.reason.isEmpty ? null : Text(s.reason),
                  trailing: Wrap(spacing: 4, children: [
                    IconButton(
                      key: ValueKey('word-proof-skip-$k'),
                      tooltip: context.t('wp.proof_skip'),
                      icon: const Icon(AppIcons.close),
                      onPressed: () => setState(() => _items.removeAt(k)),
                    ),
                    IconButton(
                      key: ValueKey('word-proof-apply-$k'),
                      tooltip: context.t('wp.proof_apply'),
                      icon: const Icon(AppIcons.check),
                      onPressed: () => _apply(k),
                    ),
                  ]),
                );
              },
            ),
          ),
          if (_items.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
              child: FilledButton(
                key: const ValueKey('word-proof-all'),
                onPressed: () {
                  for (final (para, s) in _items) {
                    widget.apply(para, s.wrong, s.right);
                  }
                  setState(_items.clear);
                },
                child: Text(context.t('wp.proof_apply_all', {'n': _items.length})),
              ),
            ),
        ],
      ),
    );
  }
}

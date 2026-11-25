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

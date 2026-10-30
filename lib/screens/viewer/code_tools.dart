part of '../viewer_screen.dart';

/// Faz 30 — metin / kod / Markdown düzenleyici araçları: klavye üstü çubuk,
/// durum satırı (kodlama · satır sonu · konum), Markdown önizleme ve
/// gelişmiş bul-değiştir seçenekleri.
/// Bu genişlikten itibaren Markdown önizleme editörün yanında açılır.
const double _mdSplitMinWidth = 840;

extension _ViewerCodeToolsPart on _ViewerScreenState {
  bool get _isCodeDoc => widget.doc.kind == DocKind.text;

  bool get _isMarkdown {
    final e = p.extension(widget.doc.path).toLowerCase();
    return _isCodeDoc && (e == '.md' || e == '.markdown');
  }

  CodeLang get _codeLang => codeLangFor(p.extension(widget.doc.path));

  /// Yazarken uygulanan kod kuralları (yalnız düzenlenebilir metinde).
  List<TextInputFormatter> get _codeFormatters {
    if (!_isCodeDoc || !widget.doc.isEditableText) return const [];
    if (_isMarkdown) return const [MarkdownEnterFormatter()];
    final lang = _codeLang;
    return [
      CodeInputFormatter(
        indentWidth: _tabWidth,
        autoClose: lang != CodeLang.plain,
        colonIndent: lang == CodeLang.python || lang == CodeLang.yaml,
      ),
    ];
  }

  void _applyEdit(TextEditingValue Function(TextEditingValue) fn) {
    final ctl = _textController;
    if (ctl == null || !widget.doc.isEditableText) return;
    ctl.value = fn(ctl.value);
    if (!_dirty) _partSetState(() => _dirty = true);
    _textFocus.requestFocus();
  }

  /// Klavye üstü çubuk öğeleri: geri al/yinele + türe göre araçlar.
  List<AccessoryItem> _codeAccessoryItems() {
    final undo = _undoCtl.value;
    final items = <AccessoryItem>[
      AccessoryItem(
          key: const ValueKey('code-undo'),
          icon: AppIcons.undo,
          tooltip: context.t('code.undo'),
          onPressed: undo.canUndo ? _undoCtl.undo : null),
      AccessoryItem(
          key: const ValueKey('code-redo'),
          icon: AppIcons.redo,
          tooltip: context.t('code.redo'),
          onPressed: undo.canRedo ? _undoCtl.redo : null),
    ];
    if (_isMarkdown) {
      items.addAll([
        AccessoryItem(
            key: const ValueKey('md-heading'),
            text: 'H',
            tooltip: context.t('md.heading'),
            onPressed: () => _applyEdit((v) => mdHeading(v, 2))),
        AccessoryItem(
            key: const ValueKey('md-bold'),
            icon: AppIcons.formatBold,
            tooltip: context.t('md.bold'),
            onPressed: () => _applyEdit((v) => mdWrap(v, '**'))),
        AccessoryItem(
            key: const ValueKey('md-italic'),
            icon: AppIcons.formatItalic,
            tooltip: context.t('md.italic'),
            onPressed: () => _applyEdit((v) => mdWrap(v, '_'))),
        AccessoryItem(
            key: const ValueKey('md-bullets'),
            icon: AppIcons.formatListBulleted,
            tooltip: context.t('md.bullets'),
            onPressed: () => _applyEdit((v) => mdLinePrefix(v, '- '))),
        AccessoryItem(
            key: const ValueKey('md-numbered'),
            icon: AppIcons.formatListNumbered,
            tooltip: context.t('md.numbered'),
            onPressed: () =>
                _applyEdit((v) => mdLinePrefix(v, '', numbered: true))),
        AccessoryItem(
            key: const ValueKey('md-task'),
            text: '☑',
            tooltip: context.t('md.task'),
            onPressed: () => _applyEdit((v) => mdLinePrefix(v, '- [ ] '))),
        AccessoryItem(
            key: const ValueKey('md-link'),
            icon: AppIcons.link,
            tooltip: context.t('md.link'),
            onPressed: () => _applyEdit((v) => mdLink(v))),
        AccessoryItem(
            key: const ValueKey('md-code'),
            icon: AppIcons.code,
            tooltip: context.t('md.code'),
            onPressed: () => _applyEdit(mdCode)),
        AccessoryItem(
            key: const ValueKey('md-quote'),
            icon: AppIcons.formatQuote,
            tooltip: context.t('md.quote'),
            onPressed: () => _applyEdit((v) => mdLinePrefix(v, '> '))),
        AccessoryItem(
            key: const ValueKey('md-table'),
            icon: AppIcons.tableView,
            tooltip: context.t('md.table'),
            onPressed: () => _applyEdit((v) => mdTable(v))),
      ]);
    } else {
      AccessoryItem ins(String label, String text, {int back = 0}) =>
          AccessoryItem(
              key: ValueKey('code-ins-$label'),
              text: label,
              tooltip: label,
              onPressed: () =>
                  _applyEdit((v) => insertAtCursor(v, text, cursorBack: back)));
      items.addAll([
        AccessoryItem(
            key: const ValueKey('code-tab'),
            icon: AppIcons.keyboardTab,
            tooltip: context.t('code.tab'),
            onPressed: () => _applyEdit((v) => indentSelection(v, _tabWidth))),
        ins('{ }', '{}', back: 1),
        ins('( )', '()', back: 1),
        ins('[ ]', '[]', back: 1),
        ins('"', '""', back: 1),
        ins(';', ';'),
        ins('=', '='),
        ins('< >', '<>', back: 1),
        ins('/', '/'),
        AccessoryItem(
            key: const ValueKey('code-left'),
            icon: AppIcons.keyboardArrowLeft,
            tooltip: context.t('code.cursor_left'),
            onPressed: () => _applyEdit((v) => moveCursor(v, -1))),
        AccessoryItem(
            key: const ValueKey('code-right'),
            icon: AppIcons.keyboardArrowRight,
            tooltip: context.t('code.cursor_right'),
            onPressed: () => _applyEdit((v) => moveCursor(v, 1))),
      ]);
    }
    items.add(AccessoryItem(
        key: const ValueKey('code-find'),
        icon: AppIcons.search,
        tooltip: context.t('code.find'),
        onPressed: () {
          if (!_findOpen) _toggleFind();
        }));
    return items;
  }

  /// Klavye üstü çubuk + durum satırı. Yalnız metin düzenlenirken (odak
  /// alanda) görünür.
  Widget _codeAccessoryBar() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusRow(),
        KeyboardAccessoryBar(
          items: _codeAccessoryItems(),
          onHideKeyboard: () => _textFocus.unfocus(),
        ),
      ],
    );
  }

  /// "UTF-8 · LF · Sat 12, Süt 5" — satır sonuna dokunmak biçimi döndürür.
  Widget _statusRow() {
    final scheme = Theme.of(context).colorScheme;
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: scheme.onSurfaceVariant);
    return Material(
      key: const ValueKey('code-status'),
      color: scheme.surfaceContainer,
      child: SizedBox(
        height: 28,
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _textController!,
          builder: (_, v, __) {
            final off = v.selection.isValid
                ? v.selection.extentOffset.clamp(0, v.text.length)
                : 0;
            var line = 1, col = 1;
            for (var i = 0; i < off; i++) {
              if (v.text.codeUnitAt(i) == 0x0A) {
                line++;
                col = 1;
              } else {
                col++;
              }
            }
            return Row(
              children: [
                const SizedBox(width: 12),
                Text('UTF-8', style: style),
                const SizedBox(width: 12),
                InkWell(
                  key: const ValueKey('code-eol'),
                  onTap: _cycleLineEnding,
                  child: Tooltip(
                    message: context.t('code.eol'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Text(_eolName(_lineEnding), style: style),
                    ),
                  ),
                ),
                const Spacer(),
                Text('$line:$col', style: style),
                const SizedBox(width: 12),
              ],
            );
          },
        ),
      ),
    );
  }

  String _eolName(LineEnding e) => switch (e) {
        LineEnding.crlf => 'CRLF',
        LineEnding.cr => 'CR',
        LineEnding.lf => 'LF',
      };

  void _cycleLineEnding() {
    final next = switch (_lineEnding) {
      LineEnding.lf => LineEnding.crlf,
      LineEnding.crlf => LineEnding.cr,
      LineEnding.cr => LineEnding.lf,
    };
    _partSetState(() {
      _lineEnding = next;
      _dirty = true;
    });
    _snack(context.t('code.eol_changed', {'name': _eolName(next)}));
  }

  /// Markdown önizleme (telefonda Düzenle | Önizle; mevcut `MarkdownText`).
  Widget _markdownPreview() {
    final chrome = ReadingChrome.insetsOf(context);
    return Container(
      key: const ValueKey('md-preview'),
      color: Paper.docSurface(context),
      child: SingleChildScrollView(
        padding:
            EdgeInsets.fromLTRB(20, 16 + chrome.top, 20, 16 + chrome.bottom),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: MarkdownText(_textController!.text),
          ),
        ),
      ),
    );
  }

  /// Bul/değiştir seçenekleri satırı: Aa · tam sözcük · .* (düzenli ifade).
  Widget _findOptionsRow() {
    Widget chip(String key, String label, bool on, VoidCallback tap) =>
        Padding(
          padding: const EdgeInsetsDirectional.only(end: 6),
          child: FilterChip(
            key: ValueKey(key),
            label: Text(label),
            selected: on,
            visualDensity: VisualDensity.compact,
            onSelected: (_) {
              tap();
              _runFind(_findCtl.text);
            },
          ),
        );
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            chip('find-case', 'Aa', _findCase,
                () => _partSetState(() => _findCase = !_findCase)),
            chip('find-word', context.t('code.whole_word'), _findWord,
                () => _partSetState(() => _findWord = !_findWord)),
            chip('find-regex', '.*', _findRegex,
                () => _partSetState(() => _findRegex = !_findRegex)),
            if (_findRegexBad)
              Text(context.t('code.bad_regex'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ]),
        ),
      ),
    );
  }
}

part of '../slides_editor_screen.dart';

/// Faz 28 — anahat görünümü (madde 7) ve konuşmacı notu yazma (madde 8).
extension _SlidesEditorScreenOutlinePart on _SlidesEditorScreenState {
  /// Slaydın anahat sırasıyla metin şekilleri: başlık önce, sonra öbürleri
  /// slayttaki sırayla. Yalnız slayt XML'ine bağlı (düzenlenebilir) metin.
  List<ShapeVM> _outlineShapes(PptxSlide slide) {
    final shapes = [
      for (final s in slide.view?.shapes ?? const <ShapeVM>[])
        if (s.paragraphs.any((p) => p.source != null && p.plainText.isNotEmpty))
          s,
    ];
    bool isTitle(ShapeVM s) =>
        s.placeholderType == 'title' || s.placeholderType == 'ctrTitle';
    return [...shapes.where(isTitle), ...shapes.where((s) => !isTitle(s))];
  }

  void _toggleOutline() {
    if (_outline) _flushOutline();
    if (_textCtrl != null) _commitEdit();
    _partSetState(() {
      _outline = !_outline;
      _selShape = null;
    });
  }

  /// Anahatta yazılan ama henüz yazılmamış değişiklikleri TEK geri al
  /// adımıyla XML'e işler (odak çıkınca, kaydederken, görünümden çıkarken).
  void _flushOutline() {
    final editor = _editor;
    if (editor == null || _outlinePending.isEmpty) return;
    final pending = Map.of(_outlinePending);
    _outlinePending.clear();
    _mutate('sl.undo_outline', () {
      var any = false;
      for (final e in pending.entries) {
        final (slide, para) = e.key;
        if (para.text == e.value) continue;
        editor.updateParagraph(slide, para, e.value);
        any = true;
      }
      return any;
    });
  }

  Widget _outlineView(PptxEditor editor) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView.builder(
      key: const ValueKey('slides-outline'),
      padding: withNavInset(context, const EdgeInsets.fromLTRB(12, 8, 12, 24)),
      itemCount: editor.slides.length,
      itemBuilder: (context, i) {
        final slide = editor.slides[i];
        final shapes = _outlineShapes(slide);
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Başlık şeridi: dokununca slayda git (anahat kapanır).
                InkWell(
                  onTap: () async {
                    _toggleOutline();
                    await WidgetsBinding.instance.endOfFrame;
                    if (mounted) await _goToSlide(slide.index);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${slide.index}',
                            style: theme.textTheme.labelMedium?.copyWith(
                                color: scheme.onPrimaryContainer,
                                fontWeight: FontWeight.w700)),
                      ),
                      const Spacer(),
                      Icon(AppIcons.openFull,
                          size: 18, color: scheme.onSurfaceVariant),
                    ]),
                  ),
                ),
                if (shapes.isEmpty)
                  Text(context.t('ss.no_text'),
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant)),
                for (final shape in shapes)
                  for (final p in shape.paragraphs)
                    if (slide.paragraphOf(p.source) case final para?
                        when para.text.isNotEmpty)
                      _OutlineField(
                        key: ObjectKey(para.element),
                        text: _outlinePending[(slide, para)] ?? para.text,
                        title: shape.placeholderType == 'title' ||
                            shape.placeholderType == 'ctrTitle',
                        level: p.level,
                        onChanged: (v) => _outlinePending[(slide, para)] = v,
                        onDone: _flushOutline,
                      ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Konuşmacı notunu yazma levhası. Not yoksa boş açılır; kaydedince not
  /// sayfası (gerekirse not şablonu) oluşturulur.
  Future<void> _editNotes(PptxSlide slide) async {
    final editor = _editor;
    if (editor == null) return;
    final result = await showAppSheet<String>(
      context,
      title: context.t('sl.notes_title', {'n': slide.index}),
      builder: (ctx) => _NotesEditor(initial: editor.notesOf(slide)),
    );
    if (result == null || !mounted) return;
    final text = result.trimRight();
    if (text == editor.notesOf(slide)) return;
    if (!_mutate('sl.undo_notes', () => editor.setNotes(slide, text))) {
      _snack(context.t('sl.no_structure'));
    }
  }
}

/// Not yazma levhasının içeriği — denetleyici levha kapanış animasyonu
/// bitene dek yaşasın diye kendi durumunda.
class _NotesEditor extends StatefulWidget {
  final String initial;
  const _NotesEditor({required this.initial});

  @override
  State<_NotesEditor> createState() => _NotesEditorState();
}

class _NotesEditorState extends State<_NotesEditor> {
  late final _ctrl = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const ValueKey('notes-edit'),
            controller: _ctrl,
            autofocus: true,
            minLines: 4,
            maxLines: 12,
            keyboardType: TextInputType.multiline,
            decoration: InputDecoration(
              hintText: context.t('sl.notes_hint'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.t('common.cancel')),
              ),
              const SizedBox(width: 8),
              FilledButton(
                key: const ValueKey('notes-save'),
                onPressed: () => Navigator.pop(context, _ctrl.text),
                child: Text(context.t('common.save')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Anahattaki tek paragraf alanı — kendi denetleyicisini tutar (liste
/// yeniden çizilince imleç kaçmasın), odak çıkınca değişikliği bildirir.
class _OutlineField extends StatefulWidget {
  final String text;
  final bool title;
  final int level;
  final ValueChanged<String> onChanged;
  final VoidCallback onDone;

  const _OutlineField({
    super.key,
    required this.text,
    required this.title,
    required this.level,
    required this.onChanged,
    required this.onDone,
  });

  @override
  State<_OutlineField> createState() => _OutlineFieldState();
}

class _OutlineFieldState extends State<_OutlineField> {
  late final _ctrl = TextEditingController(text: widget.text);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    // Odak kaybı ağaç kilitliyken de gelebilir (alan listeden çıkarken):
    // yazım bir kare sonraya bırakılır.
    _focus.addListener(() {
      if (_focus.hasFocus) return;
      final done = widget.onDone;
      WidgetsBinding.instance.addPostFrameCallback((_) => done());
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = widget.title
        ? theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)
        : theme.textTheme.bodyLarge;
    return Padding(
      padding: EdgeInsetsDirectional.only(
          start: widget.title ? 0 : 12.0 + widget.level * 16, top: 2, bottom: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.title)
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8, top: 2),
              child: Text('•', style: style),
            ),
          Expanded(
            child: TextField(
              controller: _ctrl,
              focusNode: _focus,
              maxLines: null,
              style: style,
              onChanged: widget.onChanged,
              decoration: const InputDecoration(
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                contentPadding: EdgeInsets.symmetric(vertical: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

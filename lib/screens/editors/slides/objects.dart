part of '../slides_editor_screen.dart';

/// Faz 29 — slayt nesneleri arayüzü: çerçeve sürükleme sonucu, Ekle levhası
/// (yeni slayt düzeni, metin kutusu, tablo, şekil), Tasarım levhası (arka
/// plan, geçiş), şekil dolgusu, çizgisi ve saydamlığı.
const _fillPalette = <int>[
  0xFF4472C4, 0xFFED7D31, 0xFFA5A5A5, 0xFFFFC000, 0xFF5B9BD5, 0xFF70AD47,
  0xFFC00000, 0xFF7030A0, 0xFF000000, 0xFFFFFFFF,
];

extension _SlidesEditorScreenObjectsPart on _SlidesEditorScreenState {
  PptxSlide? get _targetSlide {
    final e = _editor;
    if (e == null || e.slides.isEmpty) return null;
    final sel = _selSlide;
    if (sel != null) return _fresh(sel);
    return e.slides[(_currentSlide - 1).clamp(0, e.slides.length - 1)];
  }

  void _commitFrame(PptxSlide slide, ShapeVM shape, Rect r, double rot) {
    final editor = _editor;
    if (editor == null) return;
    final id = shape.id;
    if (_mutate('sl.move_shape', () => editor.setShapeFrame(slide, shape,
        x: r.left, y: r.top, w: r.width, h: r.height, rotationDeg: rot))) {
      _select(slide, id);
    }
  }

  /// `_mutate` (geri al kaydı) destenin XML'ini yeniden kurabilir: eski
  /// [slide] ve şekil/düğüm başvuruları bayatlar. Güncel slayt dosya adıyla,
  /// şekil `p:cNvPr@id` ile bulunur.
  PptxSlide _fresh(PptxSlide slide) =>
      _editor?.slides.firstWhere((s) => s.fileName == slide.fileName,
          orElse: () => slide) ??
      slide;

  int? _idOf(Object? el) {
    if (el is! XmlElement) return null;
    for (final c in el.findAllElements('p:cNvPr')) {
      return int.tryParse(c.getAttribute('id') ?? '');
    }
    return null;
  }

  void _select(PptxSlide slide, int? id) {
    if (id == null) return;
    final now = _fresh(slide);
    ShapeVM? found;
    for (final s in now.view?.shapes ?? const <ShapeVM>[]) {
      if (s.id == id && s.element != null) found = s;
    }
    _partSetState(() {
      _selSlide = now;
      _selShape = found;
    });
  }

  Widget _tile(IconData icon, String label, VoidCallback onTap,
      {bool selected = false, Color? color, double width = 96}) {
    return FmChoiceTile(
      width: width,
      icon: icon,
      color: color ?? Theme.of(context).colorScheme.primary,
      label: label,
      count: -1,
      selected: selected,
      onTap: onTap,
    );
  }

  /// Ekle levhası: yeni slayt, metin kutusu, şekiller.
  Future<void> _openInsert() async {
    final editor = _editor;
    final slide = _targetSlide;
    if (editor == null || slide == null) return;
    final act = await showAppSheet<String>(
      context,
      title: context.t('sl.insert'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            if (editor.canEditStructure)
              _tile(AppIcons.add, ctx.t('sl.new_slide'),
                  () => Navigator.pop(ctx, 'slide')),
            _tile(AppIcons.textFields, ctx.t('sl.text_box'),
                () => Navigator.pop(ctx, 'text')),
            _tile(AppIcons.tableView, ctx.t('sl.table'),
                () => Navigator.pop(ctx, 'table')),
            for (final k in kPptxShapeKinds)
              _tile(_shapeIcon(k), ctx.t('sl.shape_$k'),
                  () => Navigator.pop(ctx, 'shape:$k')),
          ],
        ),
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'slide') {
      await _openLayoutGallery(slide);
    } else if (act == 'text') {
      XmlElement? el;
      if (_mutate('sl.text_box', () {
        el = editor.addTextBox(slide, context.t('sl.text_box_default'));
        return el != null;
      })) {
        _select(slide, _idOf(el));
      }
    } else if (act == 'table') {
      await _openTablePicker(slide);
    } else if (act.startsWith('shape:')) {
      final kind = act.substring(6);
      XmlElement? el;
      if (_mutate('sl.shape', () {
        el = editor.addShape(slide, kind);
        return el != null;
      })) {
        _select(slide, _idOf(el));
      }
    }
  }

  IconData _shapeIcon(String k) => switch (k) {
        'rect' => AppIcons.crop,
        'roundRect' => AppIcons.cropFree,
        'ellipse' => AppIcons.circle,
        'triangle' => AppIcons.play,
        'rightArrow' => AppIcons.arrowForward,
        'star5' => AppIcons.starOutline,
        _ => AppIcons.remove,
      };

  /// Düzen galerisi → yer tutuculu yeni slayt.
  Future<void> _openLayoutGallery(PptxSlide after) async {
    final editor = _editor!;
    final list = editor.layouts();
    if (list.isEmpty) return;
    final pick = await showAppSheet<PptxLayoutInfo>(
      context,
      title: context.t('sl.new_slide'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Wrap(
          spacing: Gap.sm,
          runSpacing: Gap.sm,
          children: [
            for (final l in list)
              _tile(AppIcons.slideshow, l.name, () => Navigator.pop(ctx, l),
                  width: 104),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    PptxSlide? made;
    if (_mutate('sl.new_slide', () {
      made = editor.addSlideFromLayout(pick, after: after);
      return made != null;
    })) {
      final n = made!.index;
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await _goToSlide(n);
    }
  }

  /// Tasarım levhası: arka plan rengi + geçiş.
  Future<void> _openDesign() async {
    final editor = _editor;
    final slide = _targetSlide;
    if (editor == null || slide == null) return;
    await showAppSheet<void>(
      context,
      title: context.t('sl.design'),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final t = editor.transitionOf(slide);
        final scheme = Theme.of(ctx).colorScheme;
        final style = Theme.of(ctx)
            .textTheme
            .labelLarge
            ?.copyWith(color: scheme.onSurfaceVariant);
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(ctx.t('sl.background'), style: style),
              const SizedBox(height: Gap.sm),
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in _fillPalette)
                  InkWell(
                    key: ValueKey('sl-bg-${c.toRadixString(16)}'),
                    customBorder: const CircleBorder(),
                    onTap: () {
                      _mutate('sl.background',
                          () => editor.setSlideBackground(slide, Color(c)));
                      set(() {});
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: scheme.outlineVariant),
                      ),
                    ),
                  ),
                TextButton(
                  key: const ValueKey('sl-bg-clear'),
                  onPressed: () {
                    _mutate('sl.background',
                        () => editor.setSlideBackground(slide, null));
                    set(() {});
                  },
                  child: Text(ctx.t('sl.bg_default')),
                ),
              ]),
              const SizedBox(height: Gap.md),
              Text(ctx.t('sl.transition'), style: style),
              const SizedBox(height: Gap.sm),
              Wrap(spacing: Gap.sm, runSpacing: Gap.sm, children: [
                for (final k in PptxTransition.values)
                  _tile(AppIcons.slideshow, ctx.t('sl.tr_${k.name}'), () {
                    _mutate('sl.transition',
                        () => editor.setTransition(slide, k));
                    set(() {});
                  }, selected: t == k, width: 88),
              ]),
            ],
          ),
        );
      }),
    );
  }

  /// Seçili şeklin dolgu rengi.
  Future<void> _openFill() async {
    final editor = _editor;
    final slide = _selSlide;
    final shape = _selShape;
    if (editor == null || slide == null || shape == null) return;
    final pick = await showAppSheet<int>(
      context,
      title: context.t('sl.fill'),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
        child: Wrap(spacing: 10, runSpacing: 10, children: [
          for (final c in _fillPalette)
            InkWell(
              key: ValueKey('sl-fill-${c.toRadixString(16)}'),
              customBorder: const CircleBorder(),
              onTap: () => Navigator.pop(ctx, c),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: Theme.of(ctx).colorScheme.outlineVariant),
                ),
              ),
            ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: Text(ctx.t('sl.no_fill')),
          ),
        ]),
      ),
    );
    if (pick == null || !mounted) return;
    final id = shape.id;
    if (_mutate('sl.fill',
        () => editor.setShapeFill(slide, shape, pick == 0 ? null : Color(pick)))) {
      _select(slide, id);
    }
  }

  /// Tablo ekle: satır × sütun seçici (PowerPoint mobil gibi ızgara; dokunulan
  /// hücreye kadar olan alan tablonun boyutu). Hücreye dokun → yaz.
  Future<void> _openTablePicker(PptxSlide slide) async {
    final editor = _editor;
    if (editor == null) return;
    const maxR = 8, maxC = 6;
    var pick = (3, 3);
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('sl.table'),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ctx.t('sl.table_size', {'r': pick.$1, 'c': pick.$2}),
                  style: Theme.of(ctx).textTheme.titleMedium),
              const SizedBox(height: Gap.sm),
              for (var r = 1; r <= maxR; r++)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var c = 1; c <= maxC; c++)
                      GestureDetector(
                        key: ValueKey('sl-tbl-$r-$c'),
                        onTap: () => set(() => pick = (r, c)),
                        child: Container(
                          width: 40,
                          height: 32,
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: r <= pick.$1 && c <= pick.$2
                                ? scheme.primaryContainer
                                : scheme.surfaceContainerHigh,
                            border: Border.all(color: scheme.outlineVariant),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                  ],
                ),
              const SizedBox(height: Gap.sm),
              FilledButton(
                key: const ValueKey('sl-tbl-insert'),
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('sl.table_insert')),
              ),
            ],
          ),
        );
      }),
    );
    if (ok != true || !mounted) return;
    if (_mutate('sl.table', () => editor.addTable(slide, pick.$1, pick.$2) != null)) {
      _snack(context.t('sl.table_added'));
    }
  }

  /// Seçili şeklin çizgisi: renk (ya da çizgisiz), kalınlık, kesik.
  Future<void> _openLine() async {
    final editor = _editor;
    final slide = _selSlide;
    final shape = _selShape;
    if (editor == null || slide == null || shape == null) return;
    int? color = shape.stroke?.toARGB32();
    var width = shape.stroke == null ? 1.0 : shape.strokeWidth.clamp(0.5, 12.0);
    var dashed = shape.dashed;
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('sl.line'),
      builder: (ctx) => StatefulBuilder(builder: (ctx, set) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(spacing: 10, runSpacing: 10, children: [
                for (final c in _fillPalette)
                  InkWell(
                    key: ValueKey('sl-line-${c.toRadixString(16)}'),
                    customBorder: const CircleBorder(),
                    onTap: () => set(() => color = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: color == c ? scheme.primary : scheme.outlineVariant,
                            width: color == c ? 3 : 1),
                      ),
                    ),
                  ),
                TextButton(
                  key: const ValueKey('sl-line-none'),
                  onPressed: () => set(() => color = null),
                  child: Text(ctx.t('sl.no_line')),
                ),
              ]),
              const SizedBox(height: Gap.md),
              Text(ctx.t('sl.line_width', {'pt': width.toStringAsFixed(1)})),
              Slider(
                value: width,
                min: 0.5,
                max: 12,
                divisions: 23,
                onChanged: color == null ? null : (v) => set(() => width = v),
              ),
              SwitchListTile(
                key: const ValueKey('sl-line-dash'),
                contentPadding: EdgeInsets.zero,
                title: Text(ctx.t('sl.line_dashed')),
                value: dashed,
                onChanged: color == null ? null : (v) => set(() => dashed = v),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.apply')),
              ),
            ],
          ),
        );
      }),
    );
    if (ok != true || !mounted) return;
    final id = shape.id;
    if (_mutate(
        'sl.line',
        () => editor.setShapeLine(slide, shape,
            color: color == null ? null : Color(color!),
            widthPt: width,
            dashed: dashed))) {
      _select(slide, id);
    }
  }

  /// Seçili şeklin dolgu saydamlığı (%0–100); düz dolgu gerekir.
  Future<void> _openTransparency() async {
    final editor = _editor;
    final slide = _selSlide;
    final shape = _selShape;
    if (editor == null || slide == null || shape == null) return;
    final now = editor.shapeTransparency(shape);
    if (now == null) {
      _snack(context.t('sl.transparency_needs_fill'));
      return;
    }
    var t = now;
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('sl.transparency'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(Gap.md, 0, Gap.md, Gap.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('%${(t * 100).round()}',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.titleMedium),
              Slider(
                key: const ValueKey('sl-transparency'),
                value: t,
                divisions: 20,
                onChanged: (v) => set(() => t = v),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(ctx.t('common.apply')),
              ),
            ],
          ),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    final id = shape.id;
    if (_mutate('sl.transparency',
        () => editor.setShapeTransparency(slide, shape, t))) {
      _select(slide, id);
    }
  }
}

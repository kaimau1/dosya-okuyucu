part of '../image_edit_screen.dart';

/// [_ImageEditScreenState]'in çizim yardımcıları (A4.1 bölmesi, davranış aynı).
extension _ImageEditScreenStateParts on _ImageEditScreenState {
  Widget _canvas() {
    final src = _src;
    if (_error != null) {
      return Center(
        child: Text(userErrorText(_error!),
            style: const TextStyle(color: AppColors.onMediaSoft)),
      );
    }
    if (src == null) return const Center(child: CircularProgressIndicator());
    _ensureSharp();
    return LayoutBuilder(builder: (context, c) {
      _avail = c.biggest;
      final (box, visible) = _layout(c.biggest);
      _box = box;
      final edits = _showOriginal ? const ImageEdits() : _e;
      final crop = _tab == _Tab.crop && !_showOriginal;
      final markup = _tab == _Tab.markup;
      final view = _showOriginal ? (_proxy ?? src) : _view;
      final sel = markup ? _selected : null;
      return GestureDetector(
        key: const ValueKey('ied-canvas'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: _gestureStart,
        onScaleUpdate: _gestureUpdate,
        onScaleEnd: _gestureEnd,
        onTapUp: markup ? (d) => _markTap(d.localPosition) : null,
        onDoubleTap: _vs != 1 || _vo != Offset.zero
            ? () => _update(() {
                  _vs = 1;
                  _vo = Offset.zero;
                })
            : null,
        child: Stack(children: [
          RepaintBoundary(
            child: CustomPaint(
              size: c.biggest,
              painter: _EditPainter(
                src: view,
                edits: edits,
                box: box,
                clip: visible,
                cropRect: crop ? _cropOnScreen() : null,
                cropLabel: crop ? _cropLabel() : null,
                fineGrid: crop && _straightening,
                selection: sel == null ? null : markBounds(sel, box),
                selectionRotation:
                    sel?.kind == MarkKind.text ? sel!.rotation : 0,
                handles: sel == null ? null : _handles(sel),
                labelStyle: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          // Çizilmekte olan işaret ayrı katmanda: her noktada yalnız bu boyanır.
          RepaintBoundary(
            child: CustomPaint(
              size: c.biggest,
              painter: _LivePainter(
                tick: _liveTick,
                mark: () => _live,
                src: view,
                edits: edits,
                box: box,
                clip: visible,
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _panel(ColorScheme scheme) {
    final chipTheme = ChipTheme.of(context);
    final hint = chipTheme.labelStyle?.copyWith(color: AppColors.onMediaSoft);
    return Material(
      color: AppColors.mediaSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: switch (_tab) {
          _Tab.crop => Column(mainAxisSize: MainAxisSize.min, children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (label, ratio) in _ImageEditScreenState._ratios)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(label.startsWith('ied.')
                            ? context.t(label)
                            : label),
                        selected: _ratioKey == label,
                        onSelected: (_) => _setRatioKey(label, ratio),
                      ),
                    ),
                ]),
              ),
              // Serbest açı (−45…45): sürüklerken ince ızgara.
              Row(children: [
                IconButton(
                  tooltip: context.t('ied.reset_one'),
                  color: AppColors.onMediaSoft,
                  icon: const Icon(AppIcons.straighten),
                  onPressed: _e.angle == 0
                      ? null
                      : () => _push(_e.copyWith(angle: 0)),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('ied-angle'),
                    value: _e.angle,
                    min: -45,
                    max: 45,
                    onChangeStart: (_) {
                      _history.push(_e);
                      _update(() => _straightening = true);
                    },
                    onChangeEnd: (_) => _update(() => _straightening = false),
                    onChanged: (v) => _update(() =>
                        _e = _e.copyWith(angle: (v * 2).roundToDouble() / 2)),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${_e.angle.toStringAsFixed(1)}°',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: AppColors.onMediaSoft)),
                ),
              ]),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _toolButton(AppIcons.rotateRight, 'ied.rotate',
                      () => _push(_e.rotated())),
                  _toolButton(AppIcons.selectInvert, 'ied.flip',
                      () => _push(_e.flipped())),
                  _toolButton(
                      AppIcons.flipV, 'ied.flip_v', () => _push(_e.flippedV())),
                  _toolButton(AppIcons.reset, 'ied.reset', () {
                    _update(() {
                      _ratio = null;
                      _ratioKey = 'ied.free';
                    });
                    _push(const ImageEdits());
                  }),
                ]),
              ),
            ]),
          _Tab.adjust => _adjustPanel(),
          _Tab.filter => _filterPanel(),
          _Tab.size => _sizePanel(),
          _Tab.markup => _markupPanel(scheme, hint),
        },
      ),
    );
  }

  Widget _adjustPanel() {
    final unipolar = _adjustKey == 'sharpness' || _adjustKey == 'vignette';
    final value = _e.adjust(_adjustKey);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final k in _ImageEditScreenState._adjustKeys)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('adj-$k'),
                // Değişmiş ayar noktayla işaretli.
                avatar: _e.adjust(k) != 0
                    ? const Icon(AppIcons.dot, size: 8)
                    : null,
                label: Text(context.t('ied.$k')),
                selected: _adjustKey == k,
                onSelected: (_) => _update(() => _adjustKey = k),
              ),
            ),
        ]),
      ),
      Row(children: [
        IconButton(
          key: const ValueKey('adj-reset'),
          tooltip: context.t('ied.reset_one'),
          color: AppColors.onMediaSoft,
          icon: const Icon(AppIcons.reset),
          onPressed: value == 0
              ? null
              : () => _push(_e.withAdjust(_adjustKey, 0)),
        ),
        Expanded(
          child: Slider(
            key: const ValueKey('adj-slider'),
            value: value,
            min: unipolar ? 0 : -1,
            max: 1,
            // Bir sürükleme = bir geri al adımı (IM4).
            onChangeStart: (_) => _history.push(_e),
            onChanged: (v) =>
                _update(() => _e = _e.withAdjust(_adjustKey, v)),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.onMediaSoft)),
        ),
      ]),
    ]);
  }

  Widget _filterPanel() {
    final thumb = _thumb ?? _proxy ?? _src!;
    Widget tile(String key, String label) {
      final selected = _e.filter == key;
      final m = editMatrix(_e.copyWith(filter: key, filterStrength: 1));
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          key: ValueKey('filter-$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (selected) return;
            _push(_e.copyWith(filter: key, filterStrength: 1));
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.onMediaFaint,
                  width: selected ? 3 : 1,
                ),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(m),
                child: RawImage(image: thumb, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 2),
            Text(context.t(label),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.onMedia : AppColors.onMediaSoft)),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tile('', 'ied.f_none'),
          for (final f in imageFilters.entries) tile(f.key, f.value.$1),
        ]),
      ),
      if (_e.filter.isNotEmpty)
        Row(children: [
          SizedBox(
            width: 72,
            child: Text(context.t('ied.strength'),
                style: const TextStyle(color: AppColors.onMediaSoft)),
          ),
          Expanded(
            child: Slider(
              key: const ValueKey('filter-strength'),
              value: _e.filterStrength,
              onChangeStart: (_) => _history.push(_e),
              onChanged: (v) =>
                  _update(() => _e = _e.copyWith(filterStrength: v)),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(_e.filterStrength * 100).round()}',
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.onMediaSoft)),
          ),
        ]),
    ]);
  }

  Widget _markupPanel(ColorScheme scheme, TextStyle? hint) {
    final sel = _selected;
    const soft = TextStyle(color: AppColors.onMediaSoft);
    Widget slider(IconData icon, String key, double value, double min,
            double max, void Function(double) onChanged,
            {void Function(double)? onStart}) =>
        Expanded(
          child: Row(children: [
            Tooltip(
              message: context.t(key),
              child: Icon(icon, size: 18, color: AppColors.onMediaSoft),
            ),
            Expanded(
              child: Slider(
                key: ValueKey(key),
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChangeStart: onStart,
                onChanged: onChanged,
              ),
            ),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (tool, icon, key) in const [
            (_Tool.select, AppIcons.pointer, 'ied.select'),
            (_Tool.pen, AppIcons.edit, 'ied.pen'),
            (_Tool.text, AppIcons.textFields, 'ied.text'),
            (_Tool.highlighter, AppIcons.highlighter, 'ied.highlighter'),
            (_Tool.eraser, AppIcons.eraser, 'ied.eraser'),
            (_Tool.arrow, AppIcons.arrowTool, 'ied.arrow'),
            (_Tool.line, AppIcons.lineTool, 'ied.line'),
            (_Tool.rect, AppIcons.rectTool, 'ied.rect'),
            (_Tool.ellipse, AppIcons.ellipseTool, 'ied.ellipse'),
            (_Tool.blur, AppIcons.blur, 'ied.blur'),
            (_Tool.pixelate, AppIcons.pixelate, 'ied.pixelate'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('tool-${tool.name}'),
                avatar: Icon(icon, size: 18),
                label: Text(context.t(key)),
                selected: _tool == tool,
                onSelected: (_) => _update(() {
                  _tool = tool;
                  if (tool != _Tool.select && tool != _Tool.text) _sel = null;
                }),
              ),
            ),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final color in _ImageEditScreenState._colors)
            Semantics(
              button: true,
              selected: color == (sel?.color ?? _color),
              child: InkResponse(
                onTap: () {
                  _update(() => _color = color);
                  if (sel != null && sel.color != color) {
                    _updateSelected(sel.copyWith(color: color));
                  }
                },
                radius: 22,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == (sel?.color ?? _color)
                          ? scheme.primary
                          : AppColors.onMediaFaint,
                      width: color == (sel?.color ?? _color) ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Row(children: [
        slider(
          AppIcons.lineWeight,
          'ied.thickness',
          sel == null
              ? _stroke
              : sel.kind == MarkKind.text
                  ? sel.size
                  : _sizeOf(sel),
          0.004,
          sel?.kind == MarkKind.text ? 0.4 : 0.05,
          (v) => sel == null
              ? _update(() => _stroke = v)
              : _replaceSelected(sel.copyWith(
                  size: sel.kind == MarkKind.text ? v : v * (sel.size / _sizeOf(sel)))),
          onStart: sel == null ? null : (_) => _history.push(_e),
        ),
        slider(
          AppIcons.opacity,
          'ied.opacity',
          sel?.opacity ?? _opacity,
          0.1,
          1,
          (v) => sel == null
              ? _update(() => _opacity = v)
              : _replaceSelected(sel.copyWith(opacity: v)),
          onStart: sel == null ? null : (_) => _history.push(_e),
        ),
      ]),
      if (sel != null)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (sel.kind == MarkKind.text) ...[
              _toolButton(AppIcons.edit, 'ied.edit_text', _editText),
              for (final (font, key) in const [
                ('sans', 'ied.font_sans'),
                ('serif', 'ied.font_serif'),
                ('mono', 'ied.font_mono'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(context.t(key)),
                    selected: sel.font == font,
                    onSelected: (_) =>
                        _updateSelected(sel.copyWith(font: font)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FilterChip(
                  key: const ValueKey('text-bg'),
                  label: Text(context.t('ied.text_box')),
                  selected: sel.background,
                  onSelected: (v) =>
                      _updateSelected(sel.copyWith(background: v)),
                ),
              ),
            ],
            _toolButton(AppIcons.delete, 'common.delete', _deleteSelected),
          ]),
        )
      else if (_tool == _Tool.text)
        Text(context.t('ied.tap_for_text'), style: hint)
      else if (_tool == _Tool.blur || _tool == _Tool.pixelate)
        Text(context.t('ied.blur_hint'),
            textAlign: TextAlign.center, style: hint ?? soft)
      else
        Text(context.t('ied.zoom_hint'), style: hint ?? soft),
    ]);
  }

  /// Seçili çizgi işaretinin taban kalınlığı (araç çarpanı çıkarılmış).
  double _sizeOf(ImageMark m) => switch (m.kind) {
        MarkKind.blur || MarkKind.pixelate => m.size / 5,
        MarkKind.highlighter => m.size / 2.5,
        _ => m.size,
      };

  Widget _toolButton(IconData icon, String key, VoidCallback onTap) => TextButton.icon(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.onMedia, minimumSize: const Size(48, 48)),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(context.t(key)),
      );
}

class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.src,
    required this.edits,
    required this.box,
    required this.clip,
    this.cropRect,
    this.cropLabel,
    this.fineGrid = false,
    this.selection,
    this.selectionRotation = 0,
    this.handles,
    this.labelStyle,
  });

  final ui.Image src;
  final ImageEdits edits;
  final Rect box, clip;
  final Rect? cropRect;

  /// Kırpma kutusunun piksel ölçüsü — kutunun üst ortasında rozet.
  final String? cropLabel;

  /// Serbest açı sürüklenirken 6×6 ince ızgara (yatay çizgiyi hizalamak için).
  final bool fineGrid;

  /// Seçili işaretin çerçevesi + tutamakları (boyut, döndür).
  final Rect? selection;
  final double selectionRotation;
  final (Offset, Offset?)? handles;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(clip);
    paintEdits(canvas, src, edits, box);
    canvas.restore();
    final sel = selection;
    if (sel != null) {
      final line = Paint()
        ..color = AppColors.slideSelection
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.save();
      canvas.translate(sel.center.dx, sel.center.dy);
      canvas.rotate(selectionRotation);
      canvas.drawRect(sel.shift(-sel.center), line);
      canvas.restore();
      final (scale, rotate) = handles!;
      final fill = Paint()..color = AppColors.slideSelection;
      final ring = Paint()
        ..color = AppColors.onMedia
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final h in [scale, ?rotate]) {
        canvas.drawCircle(h, 9, fill);
        canvas.drawCircle(h, 9, ring);
      }
    }
    final r = cropRect;
    if (r == null) return;
    // Kırpma dışını karart, çerçeve + üçte bir kılavuzu + köşe tutamaçları.
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(clip),
          Path()..addRect(r)),
      Paint()..color = const Color(0x99000000),
    );
    final line = Paint()
      ..color = AppColors.onMedia
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(r, line);
    line
      ..strokeWidth = 0.6
      ..color = AppColors.onMediaGuide;
    final steps = fineGrid ? 6 : 3;
    for (var i = 1; i < steps; i++) {
      final f = i / steps;
      canvas.drawLine(Offset(r.left + r.width * f, r.top),
          Offset(r.left + r.width * f, r.bottom), line);
      canvas.drawLine(Offset(r.left, r.top + r.height * f),
          Offset(r.right, r.top + r.height * f), line);
    }
    final handle = Paint()
      ..color = AppColors.onMedia
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 18.0;
    for (final (o, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomRight, -1.0, -1.0),
      (r.bottomLeft, 1.0, -1.0),
    ]) {
      canvas.drawLine(o, o + Offset(l * dx, 0), handle);
      canvas.drawLine(o, o + Offset(0, l * dy), handle);
    }
    final label = cropLabel;
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: (labelStyle ?? const TextStyle()).copyWith(
              color: AppColors.onMedia, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = Rect.fromCenter(
        center: Offset(r.center.dx, r.top + 8 + tp.height / 2 + 4),
        width: tp.width + 16,
        height: tp.height + 8,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(pill, const Radius.circular(12)),
          Paint()..color = AppColors.mediaChrome);
      tp.paint(canvas, pill.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_EditPainter old) =>
      old.edits != edits ||
      old.src != src ||
      old.box != box ||
      old.clip != clip ||
      old.cropRect != cropRect ||
      old.cropLabel != cropLabel ||
      old.fineGrid != fineGrid ||
      old.selection != selection ||
      old.selectionRotation != selectionRotation;
}

/// Çizilmekte olan tek işaret (IM2): [tick] her noktada yalnız bunu boyar.
class _LivePainter extends CustomPainter {
  _LivePainter({
    required this.tick,
    required this.mark,
    required this.src,
    required this.edits,
    required this.box,
    required this.clip,
  }) : super(repaint: tick);

  final ValueNotifier<int> tick;
  final ImageMark? Function() mark;
  final ui.Image src;
  final ImageEdits edits;
  final Rect box, clip;

  @override
  void paint(Canvas canvas, Size size) {
    final m = mark();
    if (m == null) return;
    canvas.save();
    canvas.clipRect(clip);
    paintMarks(canvas, [m], box, src: src, edits: edits);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.src != src || old.edits != edits || old.box != box || old.clip != clip;
}

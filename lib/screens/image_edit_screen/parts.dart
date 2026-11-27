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
      // Dinleyici arenaya girmez: yalnız son değen işaretçinin türünü ve
      // düğmelerini not eder (kalemin silgi ucu, B20).
      return Listener(
        onPointerDown: (e) {
          _downKind = e.kind;
          _downButtons = e.buttons;
        },
        child: GestureDetector(
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
          // Bir kezlik ipucu (B21): panelde yer kaplamaz; yok iken de aynı
          // ağaç şekli (SizedBox.shrink).
          Positioned(
            top: Gap.sm,
            left: Gap.md,
            right: Gap.md,
            child: IgnorePointer(
              child: Center(
                child: _hint == null
                    ? const SizedBox.shrink()
                    : DecoratedBox(
                        key: const ValueKey('ied-hint'),
                        decoration: BoxDecoration(
                          color: AppColors.mediaChrome,
                          borderRadius: BorderRadius.circular(Radii.card),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: Gap.md, vertical: Gap.sm),
                          child: Text(context.t(_hint!),
                              textAlign: TextAlign.center,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelMedium
                                  ?.copyWith(color: AppColors.onMedia)),
                        ),
                      ),
              ),
            ),
          ),
        ]),
      ),
      );
    });
  }

  Widget _panel(ColorScheme scheme) {
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
          _Tab.size => _sizePanel(scheme),
          _Tab.markup => _markupPanel(scheme),
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

  /// Üst sıradaki kipe geçiş (B21): Çiz son kalemi, Şekil son şekli açar.
  void _setMode(_Mode m) => _update(() {
        _tool = switch (m) {
          _Mode.select => _Tool.select,
          _Mode.draw => PenTrayMemory.lastPen == PenTrayTool.highlighter
              ? _Tool.highlighter
              : _Tool.pen,
          _Mode.blur => _Tool.blur,
          _Mode.pixelate => _Tool.pixelate,
          _Mode.text => _Tool.text,
          _Mode.shape => _lastShape,
        };
        if (_tool != _Tool.select && _tool != _Tool.text) _sel = null;
        if (m == _Mode.text) _showHint('ied.tap_for_text');
        if (m == _Mode.blur || m == _Mode.pixelate) _showHint('ied.blur_hint');
      });

  /// İpucu oturumda bir kez, tuvalin üstünde; ilk dokunuşta kaybolur
  /// (B21, kullanıcı: "ipucu kalıcı değil, bir kez gösterilip kaybolsun").
  void _showHint(String key) {
    if (_ImageEditScreenState._hintsShown.add(key)) _hint = key;
  }

  /// İşaretle paneli (B21, kullanıcı 2026-11-27): üstte KESİLMEYEN kip sırası
  /// (Seç · Çiz · Bulanıklaştır · Pikselleştir · Yazı · Şekil — bulanık/piksel
  /// yine Çiz'in hemen ardında, 2026-11-22), altında yalnız seçili kipin tek
  /// sırası; kalınlık/saydamlık ayar düğmesiyle açılır → fotoğraf alanı büyür.
  Widget _markupPanel(ColorScheme scheme) {
    final sel = _selected;
    final mode = _mode;
    final label = Theme.of(context).textTheme.labelSmall;
    Widget modeButton(_Mode m, IconData icon, String key) {
      final on = mode == m;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          child: InkWell(
            key: ValueKey('tool-${m.name}'),
            borderRadius: BorderRadius.circular(Radii.control),
            onTap: () => _setMode(m),
            child: Ink(
              padding: const EdgeInsets.symmetric(vertical: Gap.xs),
              decoration: BoxDecoration(
                color: on ? scheme.secondaryContainer : null,
                borderRadius: BorderRadius.circular(Radii.control),
              ),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(icon,
                    size: 22,
                    color: on
                        ? scheme.onSecondaryContainer
                        : AppColors.onMediaSoft),
                // Ad kesilmez: dar ekranda küçülerek sığar.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(context.t(key),
                      maxLines: 1,
                      style: label?.copyWith(
                          color: on ? AppColors.onMedia : AppColors.onMediaSoft)),
                ),
              ]),
            ),
          ),
        ),
      );
    }

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
    final current = sel?.color ?? _color;
    final colors = Expanded(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final color in _ImageEditScreenState._colors)
            Semantics(
              button: true,
              selected: color == current,
              child: InkResponse(
                onTap: () {
                  _update(() => _color = color);
                  if (sel != null && sel.color != color) {
                    _updateSelected(sel.copyWith(color: color));
                  }
                },
                radius: 20,
                child: Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.all(Gap.xs + 1),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == current
                          ? scheme.primary
                          : AppColors.onMediaFaint,
                      width: color == current ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
    );
    final tune = IconButton(
      key: const ValueKey('ied-tune'),
      tooltip: context.t('ied.stroke_settings'),
      isSelected: _strokeOpen,
      color: AppColors.onMediaSoft,
      icon: const Icon(AppIcons.tune),
      onPressed: () => _update(() => _strokeOpen = !_strokeOpen),
    );
    final thickness = slider(
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
              size: sel.kind == MarkKind.text
                  ? v
                  : v * (sel.size / _sizeOf(sel)))),
      onStart: sel == null ? null : (_) => _history.push(_e),
    );
    final brush = mode == _Mode.blur || mode == _Mode.pixelate;
    final Widget modeRow = sel != null
        ? Row(children: [
            colors,
            tune,
            IconButton(
              key: const ValueKey('ied-delete-mark'),
              tooltip: context.t('common.delete'),
              color: AppColors.onMediaSoft,
              icon: const Icon(AppIcons.delete),
              onPressed: _deleteSelected,
            ),
          ])
        : switch (mode) {
            _Mode.select => const SizedBox.shrink(),
            _Mode.blur || _Mode.pixelate => Row(children: [thickness]),
            _Mode.text => Row(children: [colors, tune]),
            _Mode.draw => Row(children: [
                // Kalem · fosforlu · silgi YAN YANA ortak tepside (B20).
                PenTray(
                  selected: _trayTool,
                  onSelect: _selectTray,
                  penColor: _color,
                  highlighterColor: _color,
                  onSettings: _traySettings,
                  onClear: _clearMarks,
                ),
                colors,
                tune,
              ]),
            _Mode.shape => Row(children: [
                for (final (tool, icon, key) in const [
                  (_Tool.arrow, AppIcons.arrowTool, 'ied.arrow'),
                  (_Tool.line, AppIcons.lineTool, 'ied.line'),
                  (_Tool.rect, AppIcons.rectTool, 'ied.rect'),
                  (_Tool.ellipse, AppIcons.ellipseTool, 'ied.ellipse'),
                ])
                  IconButton(
                    key: ValueKey('tool-${tool.name}'),
                    tooltip: context.t(key),
                    isSelected: _tool == tool,
                    color: AppColors.onMediaSoft,
                    style: IconButton.styleFrom(
                        backgroundColor:
                            _tool == tool ? scheme.secondaryContainer : null),
                    icon: Icon(icon),
                    onPressed: () => _update(() {
                      _tool = tool;
                      _lastShape = tool;
                      _sel = null;
                    }),
                  ),
                colors,
                tune,
              ]),
          };
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Row(children: [
        modeButton(_Mode.select, AppIcons.pointer, 'ied.select'),
        modeButton(_Mode.draw, AppIcons.edit, 'ied.draw'),
        modeButton(_Mode.blur, AppIcons.blur, 'ied.blur'),
        modeButton(_Mode.pixelate, AppIcons.pixelate, 'ied.pixelate'),
        modeButton(_Mode.text, AppIcons.textFields, 'ied.text'),
        modeButton(_Mode.shape, AppIcons.rectTool, 'ied.shape'),
      ]),
      modeRow,
      if (_strokeOpen && !brush && (mode != _Mode.select || sel != null))
        Row(children: [
          thickness,
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
      if (sel != null && sel.kind == MarkKind.text)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
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
                  onSelected: (_) => _updateSelected(sel.copyWith(font: font)),
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
          ]),
        ),
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
      tp.dispose();
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

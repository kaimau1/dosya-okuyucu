part of '../slides_editor_screen.dart';

/// **Faz 38 / madde 8 — şekil araçları:** kitaplık, eylem düğmesi, sayaç;
/// seçili şekle bağlayıcı, gradyan/gölge/yansıma/parıltı, kırpma/şekle kırp,
/// arka plan kaldırma, tablo biçimi, köprü/eylem.
extension _SlidesProShapes on _SlidesEditorScreenState {
  Future<void> _insertFromLibrary(PptxSlide slide) async {
    final prst = await showShapeLibrary(context);
    if (prst == null || !mounted) return;
    final i = slide.index - 1;
    if (kActionButtonTargets.containsKey(prst)) {
      await _proApply(PptxShapeOps.addActionButton(i, prst), doneKey: 'sp.applied');
      return;
    }
    final editor = _editor!;
    _mutate('sp.shape_library', () => editor.addShape(slide, prst) != null);
  }

  Future<void> _insertCounter(int slide) async {
    final min = await promptNumber(context, context.t('sp.counter_minutes'),
        initial: 5, min: 0.1, max: 600);
    if (min == null || !mounted) return;
    await _proApply(PptxShapeOps.addCounter(slide, (min * 60).round()),
        doneKey: 'sp.counter_added');
  }

  /// Şekil araçları levhasının madde 8 eylemleri.
  List<AppAction<String>> _shapeProActions(ShapeVM shape) {
    final tag = shape.element?.name.qualified;
    final isPic = tag == 'p:pic' && shape.image != null;
    final isSp = tag == 'p:sp';
    return [
      if (isSp || isPic || shape.tableFrame || shape.chart != null)
        AppAction(value: 'connect', icon: AppIcons.lineTool, label: context.t('sp.connect')),
      if (isSp) ...[
        AppAction(value: 'gradient', icon: AppIcons.gradient, label: context.t('sp.gradient')),
      ],
      if (isSp || isPic) ...[
        AppAction(value: 'shadow', icon: AppIcons.layers, label: context.t('sp.shadow')),
        AppAction(value: 'reflection', icon: AppIcons.flipV, label: context.t('sp.reflection')),
        AppAction(value: 'glow', icon: AppIcons.lightbulbOutline, label: context.t('sp.glow')),
      ],
      if (isPic) ...[
        AppAction(value: 'crop', icon: AppIcons.crop, label: context.t('sp.crop')),
        AppAction(value: 'crop_shape', icon: AppIcons.cropFree, label: context.t('sp.crop_shape')),
        AppAction(
            value: 'remove_bg',
            icon: AppIcons.autoFixNormal,
            label: context.t('sp.remove_bg'),
            hint: context.t('sp.remove_bg_hint')),
      ],
      if (shape.tableFrame)
        AppAction(value: 'table_style', icon: AppIcons.tableView, label: context.t('sp.table_style')),
      if (isSp || isPic)
        AppAction(value: 'link', icon: AppIcons.link, label: context.t('sp.link')),
    ];
  }

  Future<void> _runShapePro(String pick, PptxSlide slide, ShapeVM shape) async {
    final i = slide.index - 1, id = shape.id;
    switch (pick) {
      case 'connect':
        await _connect(i, id);
      case 'gradient':
        final a = await pickHexColor(context);
        if (a == null || !mounted) return;
        final b = await pickHexColor(context);
        if (b == null || !mounted) return;
        await _proApply(PptxShapeOps.setGradient(i, id, a, b));
      case 'shadow' || 'reflection' || 'glow':
        final on = await showAppActionSheet<bool>(context,
            title: context.t('sp.$pick'),
            groups: [
              AppActionGroup(actions: [
                AppAction(value: true, icon: AppIcons.check, label: context.t('sp.on')),
                AppAction(value: false, icon: AppIcons.close, label: context.t('sp.off')),
              ]),
            ]);
        if (on == null || !mounted) return;
        await _proApply(switch (pick) {
          'shadow' => PptxShapeOps.setShadow(i, id, on),
          'reflection' => PptxShapeOps.setReflection(i, id, on),
          _ => PptxShapeOps.setGlow(i, id, on ? 'FFC000' : null),
        });
      case 'crop':
        await _crop(i, id, shape);
      case 'crop_shape':
        final prst = await showShapeLibrary(context);
        if (prst != null && mounted) await _proApply(PptxShapeOps.cropToShape(i, id, prst));
      case 'remove_bg':
        await _removeBg(i, id);
      case 'table_style':
        final st = await showAppActionSheet<String>(context,
            title: context.t('sp.table_style'),
            groups: [
              AppActionGroup(actions: [
                for (final s in PptxShapeOps.tableStyles)
                  AppAction(value: s.id, icon: AppIcons.tableView, label: context.t('sp.ts_${s.id}')),
              ]),
            ]);
        if (st != null && mounted) await _proApply(PptxShapeOps.applyTableStyle(i, id, st));
      case 'link':
        await _link(i, id);
    }
  }

  Future<void> _connect(int slide, int from) async {
    final bytes = await _deckBytes();
    if (bytes == null) return;
    final layers = await PptxPro.query(bytes, _readLayers(slide));
    if (!mounted) return;
    final others = [for (final l in layers) if (l.id != from && l.frame != null) l];
    if (others.isEmpty) {
      _snack(context.t('sp.connect_none'));
      return;
    }
    final to = await showAppActionSheet<int>(context,
        title: context.t('sp.connect_to'),
        groups: [
          AppActionGroup(actions: [
            for (final l in others.reversed)
              AppAction(value: l.id, icon: AppIcons.rectTool, label: l.name.isEmpty ? '#${l.id}' : l.name),
          ]),
        ]);
    if (to == null || !mounted) return;
    final elbow = await showAppActionSheet<bool>(context,
        title: context.t('sp.connect'),
        groups: [
          AppActionGroup(actions: [
            AppAction(value: false, icon: AppIcons.arrowRightAlt, label: context.t('sp.conn_straight')),
            AppAction(value: true, icon: AppIcons.turnRight, label: context.t('sp.conn_elbow')),
          ]),
        ]);
    if (elbow == null || !mounted) return;
    await _proApply(PptxShapeOps.connect(slide, from, to, elbow: elbow), doneKey: 'sp.applied');
  }

  Future<void> _crop(int slide, int id, ShapeVM shape) async {
    final c = shape.crop;
    var v = [c?.left ?? 0.0, c?.top ?? 0.0, c?.right ?? 0.0, c?.bottom ?? 0.0];
    final keys = ['sp.crop_l', 'sp.crop_t', 'sp.crop_r', 'sp.crop_b'];
    final ok = await showAppSheet<bool>(
      context,
      title: context.t('sp.crop'),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            for (var k = 0; k < 4; k++)
              Row(children: [
                SizedBox(width: 72, child: Text(ctx.t(keys[k]))),
                Expanded(
                  child: Slider(
                    key: ValueKey('sp-crop-$k'),
                    value: v[k],
                    max: 0.45,
                    onChanged: (x) => set(() => v = [...v]..[k] = x),
                  ),
                ),
                SizedBox(width: 44, child: Text('${(v[k] * 100).round()}%')),
              ]),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(ctx.t('sp.apply')),
            ),
          ]),
        ),
      ),
    );
    if (ok != true || !mounted) return;
    await _proApply(PptxShapeOps.setCrop(slide, id, v[0], v[1], v[2], v[3]));
  }

  Future<void> _removeBg(int slide, int id) async {
    final bytes = await _deckBytes();
    if (bytes == null) return;
    final img = await PptxPro.query(bytes, _readImage(slide, id));
    if (img == null || !mounted) return;
    final dir = await Directory.systemTemp.createTemp('slayt-bg');
    final src = File('${dir.path}/in.${img.$2}');
    await src.writeAsBytes(img.$1);
    String? out;
    try {
      if (mounted) _snack(context.t('sp.remove_bg_working'));
      out = await SlidesNative.removeBackground(src.path, '${dir.path}/out.png');
    } on PlatformException catch (e) {
      if (mounted) {
        _snack(context.t(e.code == 'downloading' ? 'sp.remove_bg_downloading' : 'sp.remove_bg_failed'));
      }
      return;
    }
    if (!mounted) return;
    if (out == null) {
      _snack(context.t('sp.remove_bg_unavailable'));
      return;
    }
    final png = await File(out).readAsBytes();
    if (!mounted) return;
    await _proApply(PptxShapeOps.replaceImage(slide, id, png), doneKey: 'sp.applied');
  }

  Future<void> _link(int slide, int id) async {
    final kind = await showAppActionSheet<SlideLinkKind>(context,
        title: context.t('sp.link'),
        groups: [
          AppActionGroup(actions: [
            for (final k in SlideLinkKind.values)
              AppAction(
                  value: k,
                  icon: k == SlideLinkKind.none ? AppIcons.linkOff : AppIcons.link,
                  label: context.t('sp.link_${k.name}')),
          ]),
        ]);
    if (kind == null || !mounted) return;
    String? url;
    int? target;
    if (kind == SlideLinkKind.url) {
      url = await showAppPrompt(context, title: context.t('sp.link_url'), initial: 'https://');
      if (url == null || !mounted) return;
    } else if (kind == SlideLinkKind.slide) {
      final n = _editor!.slides.length;
      target = await showAppActionSheet<int>(context,
          title: context.t('sp.link_slide'),
          groups: [
            AppActionGroup(actions: [
              for (var k = 0; k < n; k++)
                AppAction(value: k, icon: AppIcons.slideshow, label: context.t('sp.slide_n', {'n': k + 1})),
            ]),
          ]);
      if (target == null || !mounted) return;
    }
    await _proApply(PptxShapeOps.setLink(slide, id, kind, url: url, target: target),
        doneKey: 'sp.applied');
  }
}

List<SlideLayer> Function(PptxPackage) _readLayers(int slide) =>
    (pkg) => PptxArrangeOps.layers(pkg, slide);

(Uint8List, String)? Function(PptxPackage) _readImage(int slide, int id) =>
    (pkg) => PptxShapeOps.imageOf(pkg, slide, id);

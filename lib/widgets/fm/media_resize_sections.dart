part of 'media_resize_sheet.dart';

extension _ResizeSheetSections on _ResizeSheetState {
  Widget _chips(List<Widget> children) => Wrap(
        spacing: Gap.sm,
        runSpacing: Gap.xs,
        children: children,
      );

  Widget _choice(String label, bool selected, VoidCallback onTap,
          {Key? key}) =>
      ChoiceChip(
        key: key,
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
      );

  Widget _numberField(TextEditingController c, String label,
          ValueChanged<String> onChanged,
          {String? suffix, Key? key, double width = 110}) =>
      SizedBox(
        width: width,
        child: TextField(
          key: key,
          controller: c,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: label,
            suffixText: suffix,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          onChanged: onChanged,
        ),
      );

  Widget _note(String text, {bool warn = false}) {
    final theme = Theme.of(context);
    final color =
        warn ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(warn ? AppIcons.warning : AppIcons.info,
              size: 16, color: color),
          const SizedBox(width: Gap.xs),
          Expanded(
            child: Text(text,
                style: theme.textTheme.bodySmall?.copyWith(color: color)),
          ),
        ],
      ),
    );
  }

  /// Kenar boşluğu rengi çipleri (saydam yalnız PNG çıktısında anlamlı).
  Widget _padColors() => _chips([
        for (final c in PadColor.values)
          if (c != PadColor.transparent ||
              _options.imageFormat == ImageOutputFormat.png)
            _choice(context.t(c.labelKey), _options.padColor == c,
                () => _set(_options.copyWith(padColor: c))),
      ]);

  /// Çözünürlük bölümü: kip seçici + seçili kipin denetimleri (Faz 14).
  List<Widget> _resolutionSection(BuildContext context) {
    final o = _options;
    final src = _sized;
    final upscale = widget.hasImages &&
        o.upscales(sourceWidth: src?.width, sourceHeight: src?.height);
    return [
      _label(context.t('rs.presets')),
      _chips([
        if (_photoOnly)
          for (final (key, preset) in _ResizeSheetState._presets)
            _choice(context.t(key), _isPreset(preset),
                () => _applyPreset(preset),
                key: ValueKey('preset-$key')),
        for (final up in _userPresets)
          if (_presetFits(up))
            GestureDetector(
              key: ValueKey('user-preset-${up.name}'),
              onLongPress: () => _deletePreset(up),
              child: ChoiceChip(
                avatar: const Icon(AppIcons.bookmark, size: 16),
                label: Text(up.name),
                selected: _isPreset(up.options),
                onSelected: (_) => _applyPreset(up.options, full: true),
              ),
            ),
        ActionChip(
          key: const ValueKey('save-preset'),
          avatar: const Icon(AppIcons.add, size: 16),
          label: Text(context.t('rs.save_preset')),
          onPressed: _valid ? _savePreset : null,
        ),
      ]),
      if (_userPresets.isNotEmpty) _note(context.t('rs.preset_hint')),
      const SizedBox(height: Gap.md),
      _label(context.t('rs.resolution')),
      _chips([
        for (final r in _modes)
          _choice(context.t(r.labelKey), o.resolution == r,
              () => _set(o.copyWith(resolution: r)),
              key: ValueKey('mode-${r.name}')),
      ]),
      const SizedBox(height: Gap.sm),
      ...switch (o.resolution) {
        ResolutionChoice.percent => _percentControls(),
        ResolutionChoice.custom => _pixelControls(),
        ResolutionChoice.longEdge => _longEdgeControls(),
        ResolutionChoice.aspect => _aspectControls(),
        ResolutionChoice.fileSize => _fileSizeControls(),
        _ => const <Widget>[],
      },
      if (upscale) _note(context.t('rs.upscale_warning'), warn: true),
    ];
  }

  List<Widget> _percentControls() {
    final max = _photoOnly ? 400 : 100;
    final p = _options.percent.clamp(1, max);
    void setPercent(int v) {
      _percentController.text = '$v';
      _set(_options.copyWith(percent: v.clamp(1, max)));
    }

    return [
      Row(
        children: [
          Expanded(
            child: Slider(
              value: p.toDouble(),
              min: 1,
              max: max.toDouble(),
              label: '%$p',
              onChanged: (v) => setPercent(v.round()),
            ),
          ),
          _numberField(_percentController, '%', (v) {
            final n = int.tryParse(v.trim());
            if (n != null) _set(_options.copyWith(percent: n.clamp(1, max)));
          }, key: const ValueKey('percent-field'), width: 76),
        ],
      ),
      _chips([
        for (final v in [25, 50, 75, if (_photoOnly) ...[150, 200]])
          _choice('%$v', p == v, () => setPercent(v)),
      ]),
    ];
  }

  List<Widget> _pixelControls() {
    final o = _options;
    final locked = o.lockAspect;
    final both = o.customWidth != null && o.customHeight != null;
    // Faz 14b: video da dört yerleşimi yapar (Media3 düzen kipleri).
    const fits = ResizeFit.values;
    return [
      Row(
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('width-field'),
              controller: _widthController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.t('rs.width'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _readCustom('w'),
            ),
          ),
          IconButton(
            key: const ValueKey('lock-aspect'),
            tooltip: context.t(locked ? 'rs.lock_on' : 'rs.lock_off'),
            isSelected: locked,
            icon: const Icon(AppIcons.linkOff),
            selectedIcon: const Icon(AppIcons.link),
            onPressed: _toggleLock,
          ),
          Expanded(
            child: TextField(
              key: const ValueKey('height-field'),
              controller: _heightController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.t('rs.height'),
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => _readCustom('h'),
            ),
          ),
        ],
      ),
      _note(context.t(locked ? 'rs.lock_note' : 'rs.unlock_note')),
      if (!locked && both) ...[
        const SizedBox(height: Gap.sm),
        _label(context.t('rs.fit')),
        _chips([
          for (final f in fits)
            _choice(context.t(f.labelKey), o.fit == f,
                () => _set(o.copyWith(fit: f)),
                key: ValueKey('fit-${f.name}')),
        ]),
        ..._fitDetails(),
      ],
    ];
  }

  /// Seçili yerleşimin ayrıntısı: kırpmada korunacak kısım, boşlukta renk;
  /// videoda motorun sınırı açıkça yazılır (orta kırpma, siyah boşluk).
  List<Widget> _fitDetails() {
    final o = _options;
    // Oran kipinde "pad dışı her şey" kırpmadır (bkz. ImageResizer.render).
    final cover = o.resolution == ResolutionChoice.aspect
        ? o.fit != ResizeFit.pad
        : o.fit == ResizeFit.cover;
    return [
      if (cover && widget.hasImages) ...[
        const SizedBox(height: Gap.sm),
        _label(context.t('rs.anchor')),
        _chips([
          for (final a in CropAnchor.values)
            _choice(context.t(a.labelKey), o.anchor == a,
                () => _set(o.copyWith(anchor: a)),
                key: ValueKey('anchor-${a.name}')),
        ]),
      ],
      if (o.fit == ResizeFit.pad && widget.hasImages) ...[
        const SizedBox(height: Gap.sm),
        _padColors(),
      ],
      if (widget.hasVideos && (cover || o.fit == ResizeFit.pad))
        _note(context.t('rs.video_layout_note')),
    ];
  }

  List<Widget> _longEdgeControls() => [
        _chips([
          for (final v in longEdgeChoices)
            _choice('$v px', _options.longEdgePx == v, () {
              _longEdgeController.text = '$v';
              _set(_options.copyWith(longEdgePx: v));
            }),
        ]),
        const SizedBox(height: Gap.sm),
        _numberField(_longEdgeController, context.t('rs.custom_value'), (v) {
          final n = int.tryParse(v.trim());
          if (n != null && n > 0) _set(_options.copyWith(longEdgePx: n));
        }, suffix: 'px', width: 160),
        _note(context.t('rs.long_edge_note')),
      ];

  List<Widget> _aspectControls() {
    final o = _options;
    void readCustom() {
      final w = double.tryParse(_aspectWController.text.replaceAll(',', '.'));
      final h = double.tryParse(_aspectHController.text.replaceAll(',', '.'));
      if (w != null && h != null && w > 0 && h > 0) {
        _set(_options.copyWith(aspectW: w, aspectH: h));
      }
    }

    return [
      _chips([
        for (final (label, w, h) in aspectChoices)
          _choice(label, o.aspectW == w && o.aspectH == h,
              () => _set(o.copyWith(aspectW: w, aspectH: h)),
              key: ValueKey('aspect-$label')),
      ]),
      const SizedBox(height: Gap.sm),
      Row(
        children: [
          _numberField(_aspectWController, context.t('rs.aspect_w'),
              (_) => readCustom(), width: 90),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: Gap.sm),
            child: Text(':'),
          ),
          _numberField(_aspectHController, context.t('rs.aspect_h'),
              (_) => readCustom(), width: 90),
        ],
      ),
      const SizedBox(height: Gap.sm),
      _chips([
        for (final f in const [ResizeFit.cover, ResizeFit.pad])
          _choice(context.t('rs.aspect_${f.name}'),
              (o.fit == ResizeFit.pad) == (f == ResizeFit.pad),
              () => _set(o.copyWith(fit: f)),
              key: ValueKey('aspect-fit-${f.name}')),
      ]),
      ..._fitDetails(),
    ];
  }

  List<Widget> _fileSizeControls() {
    String label(int kb) => kb >= 1024 ? '≤ ${kb ~/ 1024} MB' : '≤ $kb KB';
    return [
      _chips([
        for (final kb in fileSizeChoicesKb)
          _choice(label(kb), _options.targetKb == kb, () {
            _kbController.text = '$kb';
            _set(_options.copyWith(targetKb: kb));
          }, key: ValueKey('kb-$kb')),
      ]),
      const SizedBox(height: Gap.sm),
      _numberField(_kbController, context.t('rs.custom_value'), (v) {
        final n = int.tryParse(v.trim());
        if (n != null && n > 0) _set(_options.copyWith(targetKb: n));
      }, suffix: 'KB', width: 160),
      if (widget.hasImages) _note(context.t('rs.file_size_note')),
      if (widget.hasVideos) _note(context.t('rs.video_file_size_note')),
    ];
  }

  /// **Şu an → sonra** kartı.
  ///
  /// Kullanıcı 2026-08-07: *"video boyut düşürmede şu anki durum görülmeli,
  /// çözünürlük kare sayısı vs görülmeli ki ne yapacağımızı bilelim"*. Sayfa
  /// yalnız hedefleri sunuyordu; kaynağın ne olduğu hiçbir yerde yazmıyordu.
  ///
  /// Tek dosyada dosyanın kendi ölçüleri, çoklu seçimde ilk dosya + "ve N
  /// dosya daha" yazılır (hepsini listelemek sayfayı kaplardı).
  Widget _sourceCard(BuildContext context) {
    final theme = Theme.of(context);
    final first = widget.sources.first;
    final totalBytes =
        widget.sources.fold<int>(0, (sum, s) => sum + s.sizeBytes);
    final target = first.targetFor(_options);
    final fps = first.targetFps(_options);
    // Ayarlar bu videoda hiçbir şeyi küçültmüyorsa SÖYLENİR: kullanıcı
    // dakikalarca bekleyip "küçülmedi" yazısını görmesin.
    final noChange = first.noVisualChangeWith(_options);
    // Seçimin TAMAMI için tahmin (kullanıcı isteği 2026-08-07: "boyut
    // düşürmede tahmini boyut yazmalı").
    final estimate = estimateResizeTotal(widget.sources, _options);
    return Card(
      margin: const EdgeInsets.only(bottom: Gap.md),
      child: Padding(
        padding: const EdgeInsets.all(Gap.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(first.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall),
            const SizedBox(height: Gap.xs),
            _specRow(
              context,
              context.t('rs.now'),
              [
                if (first.hasSize) '${first.width}×${first.height}',
                if (first.fps != null)
                  context.t('rs.fps_value', {'n': first.fps!.round()}),
                if (first.durationMs > 0)
                  humanDuration(Duration(milliseconds: first.durationMs)),
                FsPaths.humanSize(first.sizeBytes),
                if (first.bitrate case final b?)
                  context.t('rs.bitrate', {'n': (b / 1000000).toStringAsFixed(1)}),
              ],
              bold: true,
            ),
            if (target != null)
              _specRow(
                context,
                context.t('rs.after'),
                [
                  '${target.width}×${target.height}',
                  if (fps != null) context.t('rs.fps_value', {'n': fps}),
                  if (_options.removeAudio && first.isVideo)
                    context.t('rs.no_audio'),
                  // Bu dosyanın tahmini boyutu — "sonra" satırının doğal yeri.
                  if (first.estimatedBytes(_options) case final b?)
                    '≈ ${FsPaths.humanSize(b)}',
                ],
              ),
            if (estimate != null) _estimateRow(context, estimate),
            if (widget.sources.length > 1)
              Padding(
                padding: const EdgeInsets.only(top: Gap.xs),
                child: Text(
                  context.t('rs.and_more', {
                    'n': widget.sources.length - 1,
                    'size': FsPaths.humanSize(totalBytes),
                  }),
                  style: context.type.small.copyWith(color: Paper.faint(context)),
                ),
              ),
            if (noChange)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(AppIcons.info,
                        size: 16, color: theme.colorScheme.error),
                    const SizedBox(width: Gap.xs),
                    Expanded(
                      child: Text(
                        context.t('rs.no_change_warning'),
                        style: context.type.small.copyWith(
                            color: theme.colorScheme.error,
                          ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Canlı önizleme için ilk ölçülü fotoğraf (videonun küçük resmi yok).
  MediaSourceInfo? get _previewSource {
    for (final s in widget.sources) {
      if (!s.isVideo && s.hasSize && s.path != null) return s;
    }
    return null;
  }

  /// **Canlı önizleme küçük resmi** (Faz 14b): çıktının oranında bir çerçeve,
  /// içinde fotoğraf seçilen yerleşimle (kırp/boşluk/esnet) — "kare yap"
  /// dendiğinde neyin kesileceği iş başlamadan görülür. Küçük resim
  /// `cacheWidth` ile çözülür; 12 MP'yi tam açmaz.
  Widget _preview(BuildContext context, MediaSourceInfo src) {
    final o = _options;
    final t = src.targetFor(o);
    if (t == null || t.width <= 0 || t.height <= 0) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    final custom = o.resolution == ResolutionChoice.custom &&
        o.customWidth != null &&
        o.customHeight != null;
    final fit = o.resolution == ResolutionChoice.aspect
        ? (o.fit == ResizeFit.pad ? ResizeFit.pad : ResizeFit.cover)
        : custom
            ? o.effectiveFit
            : ResizeFit.stretch;
    final boxFit = switch (fit) {
      ResizeFit.cover => BoxFit.cover,
      ResizeFit.pad => BoxFit.contain,
      _ => BoxFit.fill,
    };
    // Kırpma piksel uzayında: "sol" görüntünün solu, arayüz yönünden bağımsız.
    final alignment = fit == ResizeFit.cover
        ? Alignment(o.anchor.fraction(horizontal: true) * 2 - 1,
            o.anchor.fraction(horizontal: false) * 2 - 1)
        : Alignment.center;
    final image = Image(
        image: FmFileImage(src.path!, cacheWidth: 360),
        fit: boxFit,
        alignment: alignment,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const SizedBox.shrink());
    final background = fit != ResizeFit.pad
        ? null
        : switch (o.padColor) {
            PadColor.white => const ColoredBox(color: AppColors.onMedia),
            PadColor.black => const ColoredBox(color: AppColors.mediaSurface),
            PadColor.transparent => ColoredBox(color: scheme.surfaceContainerHighest),
            PadColor.blur => ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Image(
                    image: FmFileImage(src.path!, cacheWidth: 120),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink()),
              ),
          };
    return Padding(
      key: const ValueKey('resize-preview'),
      padding: const EdgeInsets.only(bottom: Gap.md),
      child: Column(
        children: [
          SizedBox(
            height: 132,
            child: Center(
              child: AspectRatio(
                aspectRatio: t.width / t.height,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                      border: Border.all(color: scheme.primary, width: 1.5)),
                  child: ClipRect(
                    child: Stack(fit: StackFit.expand, children: [
                      ?background,
                      image,
                    ]),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: Gap.xs),
          Text('${context.t('rs.preview')} · ${t.width} × ${t.height}',
              style: Theme.of(context).textTheme.labelSmall),
        ],
      ),
    );
  }

  /// **Tahmini boyut** satırı: `48 MB → ≈ 12 MB · ≈ %75 kazanç`.
  ///
  /// Sayı "≈" ile yazılır ve altında tek satırlık uyarı durur: gerçek boyut
  /// ancak kodlama bitince bilinir (içeriğe göre ±%30 sapabilir). Kesinmiş
  /// gibi yazmak, tutmadığında güveni bitirirdi.
  Widget _estimateRow(
      BuildContext context, ({int before, int after}) estimate) {
    final theme = Theme.of(context);
    final saved = estimate.before - estimate.after;
    final percent = estimate.before > 0
        ? (saved * 100 / estimate.before).round()
        : 0;
    return Padding(
      padding: const EdgeInsets.only(top: Gap.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(AppIcons.shrink,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  context.t('rs.estimate', {
                    'before': FsPaths.humanSize(estimate.before),
                    'after': FsPaths.humanSize(estimate.after),
                  }),
                  style: context.type.compact.copyWith(
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (percent > 0)
                Text(
                  context.t('rs.estimate_gain', {'n': percent}),
                  style: context.type.compact.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              context.t('rs.estimate_note'),
              style: context.type.caption.copyWith(color: Paper.faint(context)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _specRow(BuildContext context, String label, List<String> parts,
          {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.only(top: Gap.xs),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 62,
              child: Text(label,
                  style: context.type.small.copyWith(color: Paper.faint(context))),
            ),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: context.type.compact.copyWith(
                  fontWeight: bold ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

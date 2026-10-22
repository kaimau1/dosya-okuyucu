import 'package:flutter/material.dart';

import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/media_resize.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart' show humanDuration;

/// Boyut düşürme ayarları sayfası.
///
/// Seçime göre kısımlar açılır/kapanır: yalnız fotoğraf seçildiyse kare sayısı
/// ve ses sorulmaz, yalnız video seçildiyse JPEG kalitesi/format sorulmaz.
/// Görünmeyecek ayarları göstermek "acaba bu videoya da mı uygulanıyor?"
/// sorusunu doğurur.
Future<MediaResizeOptions?> showMediaResizeSheet(
  BuildContext context, {
  required bool hasImages,
  required bool hasVideos,
  required int fileCount,
  MediaResizeOptions initial = const MediaResizeOptions(),
  List<MediaSourceInfo> sources = const [],
}) =>
    showModalBottomSheet<MediaResizeOptions>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ResizeSheet(
        hasImages: hasImages,
        hasVideos: hasVideos,
        fileCount: fileCount,
        initial: initial,
        sources: sources,
      ),
    );

class _ResizeSheet extends StatefulWidget {
  final bool hasImages;
  final bool hasVideos;
  final int fileCount;
  final MediaResizeOptions initial;

  /// Seçilen dosyaların ÖLÇÜLEN özellikleri (bkz. [MediaSourceInfo]). Boş
  /// olabilir — ölçüm başarısızsa sayfa eskisi gibi çalışır, yalnız üstteki
  /// "şu an" kartı çizilmez.
  final List<MediaSourceInfo> sources;

  const _ResizeSheet({
    required this.hasImages,
    required this.hasVideos,
    required this.fileCount,
    required this.initial,
    this.sources = const [],
  });

  @override
  State<_ResizeSheet> createState() => _ResizeSheetState();
}

class _ResizeSheetState extends State<_ResizeSheet> {
  late MediaResizeOptions _options = _normalized(widget.initial);
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();
  final _percentController = TextEditingController();
  final _longEdgeController = TextEditingController();
  final _kbController = TextEditingController();
  final _aspectWController = TextEditingController();
  final _aspectHController = TextEditingController();

  /// Kilit açıkken kullanıcının YAZDIĞI alan ('w' / 'h'); öteki alan ondan
  /// hesaplanıp gösterilir ama modele yazılmaz — çoklu seçimde her dosya
  /// kendi oranını korusun.
  String? _driver;

  /// Seçimde video yoksa fotoğraf kipleri (uzun kenar, oran, dosya boyutu)
  /// sunulur; video kademeleri (480p…) fotoğrafta anlamsız (G4f).
  bool get _photoOnly => widget.hasImages && !widget.hasVideos;

  List<ResolutionChoice> get _modes => _photoOnly
      ? const [
          ResolutionChoice.keep,
          ResolutionChoice.percent,
          ResolutionChoice.custom,
          ResolutionChoice.longEdge,
          ResolutionChoice.aspect,
          ResolutionChoice.fileSize,
        ]
      : const [
          ResolutionChoice.keep,
          ResolutionChoice.p480,
          ResolutionChoice.p540,
          ResolutionChoice.p720,
          ResolutionChoice.p1080,
          ResolutionChoice.percent,
          ResolutionChoice.custom,
        ];

  /// Hatırlanan ayar bu seçime uymuyorsa (fotoğrafa video kademesi, videoya
  /// fotoğraf kipi) en yakın karşılığa çevrilir.
  MediaResizeOptions _normalized(MediaResizeOptions o) {
    var r = o;
    if (_photoOnly && r.resolution.shortEdge != null) {
      r = r.copyWith(resolution: ResolutionChoice.longEdge);
    } else if (!_photoOnly && r.resolution.photoOnly) {
      r = r.copyWith(resolution: ResolutionChoice.p1080);
    }
    final maxPercent = _photoOnly ? 400 : 100;
    if (r.percent > maxPercent) r = r.copyWith(percent: maxPercent);
    if (!_photoOnly && r.fit != ResizeFit.stretch) {
      // Video motoru yalnız sığdır/esnet yapabiliyor (14b'ye kadar).
      r = r.copyWith(fit: ResizeFit.contain);
    }
    return r;
  }

  @override
  void initState() {
    super.initState();
    final o = _options;
    if (o.customWidth != null) _widthController.text = '${o.customWidth}';
    if (o.customHeight != null) _heightController.text = '${o.customHeight}';
    if (o.lockAspect) {
      _driver = o.customWidth != null ? 'w' : (o.customHeight != null ? 'h' : null);
      _syncLocked();
    }
    _percentController.text = '${o.percent}';
    _longEdgeController.text = '${o.longEdgePx}';
    _kbController.text = '${o.targetKb}';
  }

  @override
  void dispose() {
    for (final c in [
      _widthController,
      _heightController,
      _percentController,
      _longEdgeController,
      _kbController,
      _aspectWController,
      _aspectHController,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Ölçüsü bilinen ilk dosya (kilitli alanın canlı karşılığı için).
  MediaSourceInfo? get _sized {
    for (final s in widget.sources) {
      if (s.hasSize) return s;
    }
    return null;
  }

  /// Kilit açıkken yazılmayan alanı ilk dosyanın oranından doldurur
  /// ("1600" yazınca yükseklik alanında anında "1200").
  void _syncLocked() {
    final src = _sized;
    if (src == null || !_options.lockAspect) return;
    final w = _options.customWidth;
    final h = _options.customHeight;
    if (_driver == 'w' && w != null) {
      _heightController.text = '${(w * src.height / src.width).round()}';
    } else if (_driver == 'h' && h != null) {
      _widthController.text = '${(h * src.width / src.height).round()}';
    }
  }

  /// Serbest ölçüde en az bir alan dolu olmalı, yoksa "Uygula" hiçbir şey
  /// yapmayan bir düğme olurdu.
  bool get _valid => switch (_options.resolution) {
        ResolutionChoice.custom =>
          _options.customWidth != null || _options.customHeight != null,
        ResolutionChoice.longEdge => _options.longEdgePx >= 16,
        ResolutionChoice.fileSize => _options.targetKb >= 10,
        ResolutionChoice.percent => _options.percent >= 1,
        ResolutionChoice.aspect =>
          _options.aspectW > 0 && _options.aspectH > 0,
        _ => true,
      };

  /// Video yeniden kodlanacak mı? Kullanıcı bunu bilmeli: kodlama uzun sürer
  /// (uzun bir videoda dakikalar) ve kaynaktan bir tur kalite kaybı olur.
  ///
  /// Seçimde video varsa **her zaman** doğru: video yolu (`VideoTranscoder.run`)
  /// çözünürlük değişmese de yeniden kodluyor — yalnız kalite/kare sayısı/ses
  /// değişse bile. Eskiden uyarı `changesResolution`e bağlıydı, yani
  /// "Çözünürlük: Değiştirme" seçen kullanıcı dakikalar sürecek bir kodlamayı
  /// hiç uyarılmadan başlatıyordu (2026-07-29 sadakat denetimi, 2. tur).
  bool get _videoNotice => widget.hasVideos;

  /// Alan yazıldı. Kilit açıkken YALNIZ yazılan alan modele girer, öteki
  /// alan hesaplanıp gösterilir; kilit kapalıyken ikisi de girer.
  void _readCustom(String field) {
    int? read(TextEditingController c) {
      final v = int.tryParse(c.text.trim());
      return v != null && v > 0 ? v : null;
    }

    setState(() {
      if (_options.lockAspect) {
        _driver = field;
        final w = field == 'w' ? read(_widthController) : null;
        final h = field == 'h' ? read(_heightController) : null;
        _options = _options.copyWith(clearCustom: true).copyWith(
            customWidth: w, customHeight: h);
        if (w == null && h == null) {
          (field == 'w' ? _heightController : _widthController).clear();
        }
        _syncLocked();
      } else {
        _options = _options.copyWith(clearCustom: true).copyWith(
            customWidth: read(_widthController),
            customHeight: read(_heightController));
      }
    });
  }

  void _toggleLock() {
    setState(() {
      final locked = !_options.lockAspect;
      _options = _options.copyWith(lockAspect: locked);
      if (locked) {
        // Kilitlenince genişlik sürücü olur, yükseklik ondan hesaplanır.
        _driver = _options.customWidth != null ? 'w' : 'h';
        _options = _driver == 'w'
            ? _options.copyWith(clearCustom: true)
                .copyWith(customWidth: _options.customWidth)
            : _options.copyWith(clearCustom: true)
                .copyWith(customHeight: _options.customHeight);
        _syncLocked();
      } else {
        // Kilit açılınca ekranda görünen İKİ değer de modele geçer.
        final w = int.tryParse(_widthController.text.trim());
        final h = int.tryParse(_heightController.text.trim());
        _options = _options.copyWith(clearCustom: true).copyWith(
            customWidth: w, customHeight: h);
      }
    });
  }

  void _set(MediaResizeOptions o) => setState(() => _options = o);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                    context.t('rs.title', {'n': widget.fileCount}),
                    style: theme.textTheme.titleMedium),
              ),
            ),
            const Divider(height: Gap.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  if (widget.sources.isNotEmpty) _sourceCard(context),
                  ..._resolutionSection(context),
                  // Dosya boyutu kipinde kalite ve biçim KENDİLİĞİNDEN seçilir
                  // (JPEG, ikili arama) — elle kalite kaydırıcısı çelişirdi.
                  if (widget.hasImages &&
                      _options.resolution != ResolutionChoice.fileSize) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('rs.jpeg_quality')),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _options.imageQuality.toDouble(),
                            min: 40,
                            max: 100,
                            divisions: 12,
                            label: '${_options.imageQuality}',
                            onChanged: (v) => setState(() => _options =
                                _options.copyWith(imageQuality: v.round())),
                          ),
                        ),
                        SizedBox(
                          width: 40,
                          child: Text('${_options.imageQuality}',
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    _label(context.t('rs.format')),
                    Wrap(
                      spacing: Gap.sm,
                      children: [
                        for (final f in ImageOutputFormat.values)
                          ChoiceChip(
                            label: Text(context.t(f.labelKey)),
                            selected: _options.imageFormat == f,
                            onSelected: (_) => setState(() =>
                                _options = _options.copyWith(imageFormat: f)),
                          ),
                      ],
                    ),
                  ],
                  if (widget.hasVideos) ...[
                    const SizedBox(height: Gap.md),
                    _label(context.t('rs.video_quality')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final q in VideoQualityChoice.values)
                          ChoiceChip(
                            label: Text(context.t(q.labelKey)),
                            selected: _options.videoQuality == q,
                            onSelected: (_) => setState(() =>
                                _options = _options.copyWith(videoQuality: q)),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    _label(context.t('rs.fps')),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final fps in frameRateChoices)
                          ChoiceChip(
                            label: Text(
                                fps == null ? context.t('rs.keep') : '$fps'),
                            selected: _options.frameRate == fps,
                            onSelected: (_) => setState(() => _options = fps ==
                                    null
                                ? _options.copyWith(clearFrameRate: true)
                                : _options.copyWith(frameRate: fps)),
                          ),
                      ],
                    ),
                    if (_videoNotice) ...[
                      const SizedBox(height: Gap.sm),
                      Row(
                        children: [
                          Icon(AppIcons.info,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: Gap.xs),
                          Expanded(
                            child: Text(
                              context.t('rs.video_note'),
                              style: theme.textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                    ],
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _options.removeAudio,
                      onChanged: (v) => setState(
                          () => _options = _options.copyWith(removeAudio: v)),
                      title: Text(context.t('rs.strip_audio')),
                      subtitle: Text(context.t('rs.strip_audio_sub')),
                    ),
                  ],
                  const Divider(height: Gap.lg),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _options.replaceOriginal,
                    onChanged: (v) => setState(() =>
                        _options = _options.copyWith(replaceOriginal: v)),
                    title: Text(context.t('rs.trash_original')),
                    subtitle: Text(context.t('rs.trash_original_sub')),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    // Çıktının NEREYE gittiği işlem başlamadan söylenir:
                    // kullanıcı hatası 2026-07-30 ("nereye gitti, nereden
                    // açacağım bilinmiyor") önce burada karşılanıyor, sonra
                    // İşlemler ekranında.
                    context.t('rs.queue_note'),
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: Gap.md),
                ],
              ),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(Gap.md),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(context.t('common.cancel')),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _valid
                          ? () => Navigator.pop(context, _options)
                          : null,
                      child: Text(context.t('rs.start')),
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

  /// Hazır ayarlar (Faz 14, G4g) — yalnız fotoğraf seçiminde. Kalite, biçim
  /// ve "özgünü çöpe at" gibi öteki ayarlara dokunmaz.
  static const _presets = <(String, MediaResizeOptions)>[
    (
      'rs.preset_profile',
      MediaResizeOptions(
          resolution: ResolutionChoice.custom,
          customWidth: 640,
          customHeight: 640,
          lockAspect: false,
          fit: ResizeFit.cover),
    ),
    (
      'rs.preset_form',
      MediaResizeOptions(resolution: ResolutionChoice.fileSize, targetKb: 200),
    ),
    (
      'rs.preset_share',
      MediaResizeOptions(
          resolution: ResolutionChoice.custom,
          customWidth: 1080,
          customHeight: 1350,
          lockAspect: false,
          fit: ResizeFit.cover),
    ),
    (
      'rs.preset_web',
      MediaResizeOptions(
          resolution: ResolutionChoice.longEdge, longEdgePx: 1600),
    ),
  ];

  void _applyPreset(MediaResizeOptions p) {
    setState(() {
      _options = _options.copyWith(clearCustom: true).copyWith(
            resolution: p.resolution,
            customWidth: p.customWidth,
            customHeight: p.customHeight,
            lockAspect: p.lockAspect,
            fit: p.fit,
            longEdgePx: p.longEdgePx,
            targetKb: p.targetKb,
          );
      _widthController.text = p.customWidth?.toString() ?? '';
      _heightController.text = p.customHeight?.toString() ?? '';
      _longEdgeController.text = '${p.longEdgePx}';
      _kbController.text = '${p.targetKb}';
      _driver = null;
    });
  }

  bool _isPreset(MediaResizeOptions p) =>
      _options.resolution == p.resolution &&
      switch (p.resolution) {
        ResolutionChoice.custom => _options.customWidth == p.customWidth &&
            _options.customHeight == p.customHeight &&
            _options.effectiveFit == p.effectiveFit,
        ResolutionChoice.fileSize => _options.targetKb == p.targetKb,
        ResolutionChoice.longEdge => _options.longEdgePx == p.longEdgePx,
        _ => false,
      };

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
          Icon(warn ? Icons.warning_amber_rounded : AppIcons.info,
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
      if (_photoOnly) ...[
        _label(context.t('rs.presets')),
        _chips([
          for (final (key, preset) in _presets)
            _choice(context.t(key), _isPreset(preset),
                () => _applyPreset(preset),
                key: ValueKey('preset-$key')),
        ]),
        const SizedBox(height: Gap.md),
      ],
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
    final fits = _photoOnly
        ? ResizeFit.values
        : const [ResizeFit.contain, ResizeFit.stretch];
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
            icon: const Icon(Icons.link_off_rounded),
            selectedIcon: const Icon(Icons.link_rounded),
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
        if (o.fit == ResizeFit.pad) ...[
          const SizedBox(height: Gap.sm),
          _padColors(),
        ],
      ],
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
      if (o.fit == ResizeFit.pad) ...[
        const SizedBox(height: Gap.sm),
        _padColors(),
      ],
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
      _note(context.t('rs.file_size_note')),
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
                  style: TextStyle(fontSize: 12, color: Paper.faint(context)),
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
                        style: TextStyle(
                            fontSize: 12, color: theme.colorScheme.error),
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
              Icon(Icons.compress_rounded,
                  size: 16, color: theme.colorScheme.primary),
              const SizedBox(width: Gap.xs),
              Expanded(
                child: Text(
                  context.t('rs.estimate', {
                    'before': FsPaths.humanSize(estimate.before),
                    'after': FsPaths.humanSize(estimate.after),
                  }),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
              if (percent > 0)
                Text(
                  context.t('rs.estimate_gain', {'n': percent}),
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              context.t('rs.estimate_note'),
              style: TextStyle(fontSize: 11, color: Paper.faint(context)),
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
                  style: TextStyle(fontSize: 12, color: Paper.faint(context))),
            ),
            Expanded(
              child: Text(
                parts.join(' · '),
                style: TextStyle(
                  fontSize: 13,
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

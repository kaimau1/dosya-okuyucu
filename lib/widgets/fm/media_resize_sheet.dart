import 'dart:io' show Platform;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_icons.dart';
import '../app_dialog.dart';
import '../../core/snack.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/media_resize.dart';
import '../../services/fm/fs_scan.dart';
import '../../services/fm/job_queue.dart' show humanDuration;
import '../../services/fm/resize_memory.dart';
import 'fm_file_image.dart';

part 'media_resize_sections.dart';

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
          // Faz 14b: Media3 düzen kipleri ve bit hızı hedefiyle videoda da.
          ResolutionChoice.longEdge,
          ResolutionChoice.aspect,
          ResolutionChoice.fileSize,
        ];

  /// Hatırlanan ayar bu seçime uymuyorsa (fotoğrafa video kademesi, videoya
  /// fotoğraf kipi) en yakın karşılığa çevrilir.
  MediaResizeOptions _normalized(MediaResizeOptions o) {
    var r = o;
    if (_photoOnly && r.resolution.shortEdge != null) {
      r = r.copyWith(resolution: ResolutionChoice.longEdge);
    }
    final maxPercent = _photoOnly ? 400 : 100;
    if (r.percent > maxPercent) r = r.copyWith(percent: maxPercent);
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
    ResizeMemory.presets().then((list) {
      if (mounted) setState(() => _userPresets = list);
    });
  }

  /// Kullanıcının kaydettiği ön ayarlar (Faz 14b).
  List<ResizePreset> _userPresets = const [];

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
                  if (_previewSource case final src?) _preview(context, src),
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
                          if (f != ImageOutputFormat.webp || Platform.isAndroid)
                          ChoiceChip(
                            label: Text(context.t(f.labelKey)),
                            selected: _options.imageFormat == f,
                            onSelected: (_) => setState(() =>
                                _options = _options.copyWith(imageFormat: f)),
                          ),
                      ],
                    ),
                  ],
                  if (widget.hasImages)
                    SwitchListTile(
                      key: const ValueKey('strip-location'),
                      contentPadding: EdgeInsets.zero,
                      value: _options.stripLocation,
                      onChanged: (v) => setState(() =>
                          _options = _options.copyWith(stripLocation: v)),
                      title: Text(context.t('rs.strip_location')),
                      subtitle: Text(context.t('rs.strip_location_sub')),
                    ),
                  if (widget.hasVideos) ...[
                    // Dosya boyutu kipinde bit hızı hedeften hesaplanır.
                    if (_options.resolution != ResolutionChoice.fileSize) ...[
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
                    ],
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

  void _applyPreset(MediaResizeOptions p, {bool full = false}) {
    setState(() {
      // Kullanıcı ön ayarı ([full]) kalite/biçim/kare/ses dahil her şeyi
      // getirir; "özgünü çöpe at" hiçbir zaman (bkz. ResizeMemory).
      final base = full
          ? _normalized(p).copyWith(replaceOriginal: _options.replaceOriginal)
          : _options;
      _options = base.copyWith(clearCustom: true).copyWith(
            resolution: p.resolution,
            customWidth: p.customWidth,
            customHeight: p.customHeight,
            lockAspect: p.lockAspect,
            fit: p.fit,
            anchor: p.anchor,
            longEdgePx: p.longEdgePx,
            targetKb: p.targetKb,
            aspectW: p.aspectW,
            aspectH: p.aspectH,
            percent: p.percent,
          );
      _percentController.text = '${_options.percent}';
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
        ResolutionChoice.percent => _options.percent == p.percent,
        ResolutionChoice.aspect => _options.aspectW == p.aspectW &&
            _options.aspectH == p.aspectH &&
            (_options.fit == ResizeFit.pad) == (p.fit == ResizeFit.pad),
        _ => p.resolution.shortEdge != null || p.resolution == ResolutionChoice.keep,
      };

  /// Şu anki ayarı adlandırıp kaydeder (Faz 14b).
  Future<void> _savePreset() async {
    final name = await showAppPrompt(context,
        title: context.t('rs.save_preset'),
        label: context.t('rs.preset_name'),
        maxLength: 32);
    if (name == null || !mounted) return;
    final list = await ResizeMemory.addPreset(name, _options);
    if (!mounted) return;
    setState(() => _userPresets = list);
    showSnack(context, context.t('rs.preset_saved', {'name': name}));
  }

  Future<void> _deletePreset(ResizePreset preset) async {
    final ok = await showAppConfirm(
        context,
        message: context.t('rs.preset_delete', {'name': preset.name}),
        destructive: true,
    );
    if (!ok || !mounted) return;
    final list = await ResizeMemory.removePreset(preset.name);
    if (!mounted) return;
    setState(() => _userPresets = list);
    showSnack(context, context.t('rs.preset_deleted', {'name': preset.name}));
  }

  /// Kullanıcı ön ayarı bu seçime uyuyor mu? Fotoğrafa video kademesi
  /// (480p…) anlamsız; geri kalan her kip ikisinde de geçer.
  bool _presetFits(ResizePreset p) =>
      !(_photoOnly && p.options.resolution.shortEdge != null);
}

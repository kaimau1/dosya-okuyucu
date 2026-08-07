import 'package:flutter/material.dart';

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
  late MediaResizeOptions _options = widget.initial;
  final _widthController = TextEditingController();
  final _heightController = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.initial.customWidth != null) {
      _widthController.text = '${widget.initial.customWidth}';
    }
    if (widget.initial.customHeight != null) {
      _heightController.text = '${widget.initial.customHeight}';
    }
  }

  @override
  void dispose() {
    _widthController.dispose();
    _heightController.dispose();
    super.dispose();
  }

  /// Serbest ölçüde en az bir alan dolu olmalı, yoksa "Uygula" hiçbir şey
  /// yapmayan bir düğme olurdu.
  bool get _valid {
    if (_options.resolution != ResolutionChoice.custom) return true;
    return _options.customWidth != null || _options.customHeight != null;
  }

  /// Video yeniden kodlanacak mı? Kullanıcı bunu bilmeli: kodlama uzun sürer
  /// (uzun bir videoda dakikalar) ve kaynaktan bir tur kalite kaybı olur.
  ///
  /// Seçimde video varsa **her zaman** doğru: video yolu (`VideoTranscoder.run`)
  /// çözünürlük değişmese de yeniden kodluyor — yalnız kalite/kare sayısı/ses
  /// değişse bile. Eskiden uyarı `changesResolution`e bağlıydı, yani
  /// "Çözünürlük: Değiştirme" seçen kullanıcı dakikalar sürecek bir kodlamayı
  /// hiç uyarılmadan başlatıyordu (2026-07-29 sadakat denetimi, 2. tur).
  bool get _videoNotice => widget.hasVideos;

  void _readCustom() {
    final w = int.tryParse(_widthController.text.trim());
    final h = int.tryParse(_heightController.text.trim());
    setState(() => _options = MediaResizeOptions(
          resolution: _options.resolution,
          percent: _options.percent,
          customWidth: w != null && w > 0 ? w : null,
          customHeight: h != null && h > 0 ? h : null,
          imageQuality: _options.imageQuality,
          imageFormat: _options.imageFormat,
          videoQuality: _options.videoQuality,
          frameRate: _options.frameRate,
          removeAudio: _options.removeAudio,
          replaceOriginal: _options.replaceOriginal,
        ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: Gap.md),
              child: Align(
                alignment: Alignment.centerLeft,
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
                  _label(context.t('rs.resolution')),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    children: [
                      for (final r in ResolutionChoice.values)
                        ChoiceChip(
                          label: Text(context.t(r.labelKey)),
                          selected: _options.resolution == r,
                          onSelected: (_) => setState(
                              () => _options = _options.copyWith(resolution: r)),
                        ),
                    ],
                  ),
                  if (_options.resolution == ResolutionChoice.percent) ...[
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: Slider(
                            value: _options.percent.toDouble(),
                            min: 10,
                            max: 95,
                            divisions: 17,
                            label: '%${_options.percent}',
                            onChanged: (v) => setState(() => _options =
                                _options.copyWith(percent: v.round())),
                          ),
                        ),
                        SizedBox(
                          width: 52,
                          child: Text('%${_options.percent}',
                              textAlign: TextAlign.end),
                        ),
                      ],
                    ),
                  ],
                  if (_options.resolution == ResolutionChoice.custom) ...[
                    const SizedBox(height: Gap.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _widthController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.t('rs.width'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => _readCustom(),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: Gap.sm),
                          child: Text('×'),
                        ),
                        Expanded(
                          child: TextField(
                            controller: _heightController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: context.t('rs.height'),
                              border: const OutlineInputBorder(),
                            ),
                            onChanged: (_) => _readCustom(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      context.t('rs.custom_note'),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (widget.hasImages) ...[
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
                          Icon(Icons.info_outline,
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
                    Icon(Icons.info_outline,
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
              Icon(Icons.compress,
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

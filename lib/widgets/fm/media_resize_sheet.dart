import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../models/media_resize.dart';

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
      ),
    );

class _ResizeSheet extends StatefulWidget {
  final bool hasImages;
  final bool hasVideos;
  final int fileCount;
  final MediaResizeOptions initial;

  const _ResizeSheet({
    required this.hasImages,
    required this.hasVideos,
    required this.fileCount,
    required this.initial,
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

  /// Videoda serbest ölçü **birebir** verilemiyor (motorun sınırı; gerekçe
  /// `services/fm/video_transcode.dart` başında yazılı). Kullanıcı yüzde ya da
  /// serbest en×boy seçtiyse bunu bilmeli — sessizce başka bir çözünürlük
  /// üretmek "ayar çalışmıyor" hatası olarak geri döner.
  bool get _videoApproxWarning =>
      widget.hasVideos && _options.needsExactSize;

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
                child: Text('Boyut düşür (${widget.fileCount} dosya)',
                    style: theme.textTheme.titleMedium),
              ),
            ),
            const Divider(height: Gap.md),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: Gap.md),
                children: [
                  _label('Çözünürlük'),
                  Wrap(
                    spacing: Gap.sm,
                    runSpacing: Gap.xs,
                    children: [
                      for (final r in ResolutionChoice.values)
                        ChoiceChip(
                          label: Text(r.label),
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
                            decoration: const InputDecoration(
                              labelText: 'Genişlik (px)',
                              border: OutlineInputBorder(),
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
                            decoration: const InputDecoration(
                              labelText: 'Yükseklik (px)',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (_) => _readCustom(),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: Gap.xs),
                    Text(
                      'Yalnız birini yazarsan diğeri en/boy oranından '
                      'hesaplanır. Kaynaktan büyütme yapılmaz.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                  if (widget.hasImages) ...[
                    const SizedBox(height: Gap.md),
                    _label('JPEG kalitesi (fotoğraf)'),
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
                    _label('Biçim (fotoğraf)'),
                    Wrap(
                      spacing: Gap.sm,
                      children: [
                        for (final f in ImageOutputFormat.values)
                          ChoiceChip(
                            label: Text(f.label),
                            selected: _options.imageFormat == f,
                            onSelected: (_) => setState(() =>
                                _options = _options.copyWith(imageFormat: f)),
                          ),
                      ],
                    ),
                  ],
                  if (widget.hasVideos) ...[
                    const SizedBox(height: Gap.md),
                    _label('Video sıkıştırma'),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final q in VideoQualityChoice.values)
                          ChoiceChip(
                            label: Text(q.label),
                            selected: _options.videoQuality == q,
                            onSelected: (_) => setState(() =>
                                _options = _options.copyWith(videoQuality: q)),
                          ),
                      ],
                    ),
                    const SizedBox(height: Gap.md),
                    _label('Kare sayısı (fps)'),
                    Wrap(
                      spacing: Gap.sm,
                      runSpacing: Gap.xs,
                      children: [
                        for (final fps in frameRateChoices)
                          ChoiceChip(
                            label: Text(fps == null ? 'Değiştirme' : '$fps'),
                            selected: _options.frameRate == fps,
                            onSelected: (_) => setState(() => _options = fps ==
                                    null
                                ? _options.copyWith(clearFrameRate: true)
                                : _options.copyWith(frameRate: fps)),
                          ),
                      ],
                    ),
                    if (_videoApproxWarning) ...[
                      const SizedBox(height: Gap.sm),
                      Row(
                        children: [
                          Icon(Icons.info_outline,
                              size: 18,
                              color: theme.colorScheme.onSurfaceVariant),
                          const SizedBox(width: Gap.xs),
                          Expanded(
                            child: Text(
                              'Videolarda birebir piksel verilemiyor: hedefe '
                              'en yakın alt kademe (1080p / 720p / 540p / '
                              '480p) kullanılır. Fotoğraflarda istediğin ölçü '
                              'tam olarak uygulanır.',
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
                      title: const Text('Sesi çıkar'),
                      subtitle: const Text('Ses kaydı olmayan videolarda '
                          'belirgin yer kazandırır.'),
                    ),
                  ],
                  const Divider(height: Gap.lg),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _options.replaceOriginal,
                    onChanged: (v) => setState(() =>
                        _options = _options.copyWith(replaceOriginal: v)),
                    title: const Text('Özgün dosyayı çöp kutusuna at'),
                    subtitle: const Text(
                        'Kapalıyken küçültülmüş kopya aynı klasöre yeni bir '
                        'dosya olarak yazılır, aslına dokunulmaz.'),
                  ),
                  const SizedBox(height: Gap.sm),
                  Text(
                    'İşlem arka planda kuyrukta çalışır; başka ekranlara '
                    'geçebilirsin. Uygulamayı tamamen kapatırsan durur.',
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
                      child: const Text('Vazgeç'),
                    ),
                  ),
                  const SizedBox(width: Gap.sm),
                  Expanded(
                    child: FilledButton(
                      onPressed: _valid
                          ? () => Navigator.pop(context, _options)
                          : null,
                      child: const Text('Başlat'),
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

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: Gap.sm),
        child: Text(text,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(fontWeight: FontWeight.w700)),
      );
}

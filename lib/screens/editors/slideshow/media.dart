part of '../slideshow_screen.dart';

/// Oynayan medya: denetleyici + hangi şekil.
class _MediaPlay {
  final SlideMediaRef ref;
  final VideoPlayerController ctrl;
  _MediaPlay(this.ref, this.ctrl);
  void dispose() => unawaited(ctrl.dispose());
}

/// **Faz 38 / madde 4 — sunumda ses/video oynatma.** Medya şekline dokunmak
/// onu oynatır: bayt destenin içinden izolatta çıkarılıp geçici dosyaya
/// yazılır (ilk dokunuşta, tembel — anayasa k.2); video şeklin yerinde,
/// ses alttaki küçük çubukta. Slayt değişince durur.
extension _SlideshowMedia on _SlideshowScreenState {
  Future<void> _playMedia(SlideMediaRef ref) async {
    final cur = _media;
    if (cur != null && cur.ref.part == ref.part && cur.ref.shapeId == ref.shapeId) {
      cur.ctrl.value.isPlaying ? await cur.ctrl.pause() : await cur.ctrl.play();
      _partSetState(() {});
      return;
    }
    _stopMedia();
    final deck = widget.deck;
    if (deck == null) return;
    final ext = ref.part.split('.').last;
    final file = File('${Directory.systemTemp.path}/ss_media_'
        '${ref.part.hashCode.toUnsigned(32)}_${deck.length}.$ext');
    if (!await file.exists()) {
      final bytes = await PptxPro.query(deck, _mediaBytes(ref.part));
      if (bytes == null || !mounted) return;
      await file.writeAsBytes(bytes, flush: true);
    }
    final ctrl = VideoPlayerController.file(file);
    try {
      await ctrl.initialize();
    } catch (_) {
      await ctrl.dispose();
      return; // çözülemeyen biçim: sessizce geç (slayt yine gösterilir)
    }
    if (!mounted) {
      await ctrl.dispose();
      return;
    }
    ctrl.addListener(_onMediaTick);
    _partSetState(() => _media = _MediaPlay(ref, ctrl));
    await ctrl.play();
  }

  /// Kayıtlı anlatım slayta girince çalar (prova kaydında çalmaz).
  void _autoPlayMedia() {
    if (widget.record) return;
    for (final m in _curInfo?.media ?? const <SlideMediaRef>[]) {
      if (m.autoplay) {
        unawaited(_playMedia(m));
        return;
      }
    }
  }

  void _onMediaTick() {
    final m = _media;
    if (m == null) return;
    final v = m.ctrl.value;
    if (v.isCompleted && !v.isPlaying) _partSetState(() {});
  }

  void _stopMedia() {
    final m = _media;
    if (m == null) return;
    m.ctrl.removeListener(_onMediaTick);
    m.dispose();
    _media = null;
  }

  Widget _mediaOverlay(_MediaPlay m) {
    final size = _stageSize;
    final slide = widget.slides[_index];
    final r = _SlideshowScreenState.slideRect(size, slide);
    final k = r.width / slide.widthPt;
    final bar = Container(
      key: const ValueKey('ss-media-bar'),
      decoration: BoxDecoration(
        color: AppColors.mediaChrome,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        ValueListenableBuilder<VideoPlayerValue>(
          valueListenable: m.ctrl,
          builder: (_, v, _) => IconButton(
            tooltip: context.t(v.isPlaying ? 'ss.pause' : 'ss.play'),
            icon: Icon(v.isPlaying ? AppIcons.pause : AppIcons.play,
                color: AppColors.onMedia),
            onPressed: () => v.isPlaying ? m.ctrl.pause() : m.ctrl.play(),
          ),
        ),
        SizedBox(
          width: 160,
          child: VideoProgressIndicator(m.ctrl, allowScrubbing: true),
        ),
        IconButton(
          tooltip: context.t('ss.stop'),
          icon: const Icon(AppIcons.stop, color: AppColors.onMedia),
          onPressed: () => _partSetState(_stopMedia),
        ),
      ]),
    );
    if (!m.ref.video) {
      return Positioned(
        left: 0,
        right: 0,
        bottom: 72,
        child: Center(child: bar),
      );
    }
    final rect = Rect.fromLTWH(r.left + m.ref.x * k, r.top + m.ref.y * k,
        m.ref.w * k, m.ref.h * k);
    return Positioned.fromRect(
      rect: rect,
      child: Stack(fit: StackFit.expand, children: [
        ColoredBox(
          color: AppColors.mediaSurface,
          child: Center(
            child: AspectRatio(
              aspectRatio: m.ctrl.value.aspectRatio,
              child: VideoPlayer(m.ctrl),
            ),
          ),
        ),
        Positioned(left: 4, right: 4, bottom: 4, child: Center(child: bar)),
      ]),
    );
  }
}

Uint8List? Function(PptxPackage) _mediaBytes(String part) =>
    (pkg) => pkg.bytes(part);

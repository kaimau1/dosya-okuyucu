part of '../slideshow_screen.dart';

/// **Faz 38 / madde 5 — sunucu görünümü.** Sağ sütunda geçen süre (dur /
/// sıfırla), slayt sırası, sonraki slaytın önizlemesi ve konuşmacı notu;
/// altta önceki/sonraki. Önizleme tek [SlideCanvas] + [RepaintBoundary].
extension _SlideshowPresenter on _SlideshowScreenState {
  Widget _presenterPanel() {
    final next = _index + 1 < widget.slides.length ? widget.slides[_index + 1] : null;
    final note = _note;
    return ColoredBox(
      key: const ValueKey('ss-presenter-panel'),
      color: AppColors.mediaChrome,
      child: SafeArea(
        left: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(children: [
                Expanded(
                  child: ValueListenableBuilder<int>(
                    valueListenable: _seconds,
                    builder: (_, s, _) => Text(
                      _SlideshowScreenState.clock(s),
                      key: const ValueKey('ss-presenter-clock'),
                      style: context.type.heading.copyWith(
                          color: _clock.isRunning
                              ? AppColors.onMedia
                              : AppColors.onMediaFaint,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: context.t(_clock.isRunning ? 'ss.pause' : 'ss.play'),
                  icon: Icon(_clock.isRunning ? AppIcons.pause : AppIcons.play,
                      color: AppColors.onMediaSoft),
                  onPressed: _toggleClockRun,
                ),
                IconButton(
                  tooltip: context.t('ss.reset_timer'),
                  icon: const Icon(AppIcons.replay10, color: AppColors.onMediaSoft),
                  onPressed: _resetClock,
                ),
              ]),
              Text(
                '${_index + 1} / ${widget.slides.length}',
                style: context.type.small.copyWith(color: AppColors.onMediaSoft),
              ),
              const SizedBox(height: 8),
              Text(context.t('ss.next_slide'),
                  style: context.type.caption.copyWith(color: AppColors.onMediaFaint)),
              const SizedBox(height: 4),
              if (next != null)
                AspectRatio(
                  aspectRatio: next.widthPt / next.heightPt,
                  child: RepaintBoundary(
                    key: const ValueKey('ss-next-preview'),
                    child: SlideCanvas(slide: next, step: next.steps.length),
                  ),
                )
              else
                Text(context.t('ss.end_of_show'),
                    style: context.type.body.copyWith(color: AppColors.onMediaSoft)),
              const SizedBox(height: 12),
              Text(context.t('ss.notes'),
                  style: context.type.caption.copyWith(color: AppColors.onMediaFaint)),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    note.isEmpty ? context.t('ss.no_notes') : note,
                    style: context.type.large.copyWith(
                        color: note.isEmpty ? AppColors.onMediaFaint : AppColors.onMedia,
                        height: 1.4),
                  ),
                ),
              ),
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _backward,
                    icon: const Icon(AppIcons.chevronLeft, color: AppColors.onMedia),
                    label: Text(context.t('ss.prev'),
                        style: context.type.body.copyWith(color: AppColors.onMedia)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    key: const ValueKey('ss-presenter-next'),
                    onPressed: _forward,
                    icon: const Icon(AppIcons.chevron),
                    label: Text(context.t('ss.next')),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

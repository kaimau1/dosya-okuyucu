import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/app_icons.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/theme.dart';
import '../../models/video_trim.dart';
import 'fm_file_image.dart';

/// **Kes ekranının zaman çizelgesi** (Ferrari H8.2, 2026-11-14).
///
/// Altta kare şeridi ([frames], eşit aralıklı küçük kareler), üstünde seçili
/// aralığı çevreleyen çerçeve ve iki tutamaç. Aralık dışı karartılır.
/// Sürüklemede en yakın tutamaç tutulur; her tam saniyede hafif titreşim
/// ([AppHaptics.step]). Tutamaç sürüklenirken [onSeek] önizlemeyi o kareye
/// götürür.
///
/// Zaman her dilde soldan sağa akar (oynatıcı çubuğuyla aynı) — şerit bu
/// yüzden kendi içinde LTR.
class VideoTrimTimeline extends StatefulWidget {
  const VideoTrimTimeline({
    super.key,
    required this.durationMs,
    required this.range,
    required this.onChanged,
    this.onSeek,
    this.frames = const [],
    this.height = 56,
    this.marks = const [],
    this.playheadMs,
    this.accent,
    this.dimOutside = true,
  });

  /// Düzenleme işaretleri (silinen bölüm, sessiz bölge, eklenen ses).
  final List<TimelineMark> marks;

  /// Önizlemenin şu anki yeri (ince çizgi); null → çizilmez.
  final int? playheadMs;

  /// Tutamaç + çerçeve rengi (varsayılan `primary`). Bölge seçerken ayrı
  /// renk, kırpma tutamaçlarıyla karışmasın.
  final Color? accent;

  /// Aralık dışı karartılsın mı (kırpmada evet, bölge seçerken hayır).
  final bool dimOutside;

  final int durationMs;
  final TrimRange range;
  final ValueChanged<TrimRange> onChanged;
  final ValueChanged<int>? onSeek;
  final List<String> frames;
  final double height;

  /// Tutamaç genişliği (dokunma alanı bundan geniş — bkz. [_grab]).
  static const handleWidth = 14.0;

  @override
  State<VideoTrimTimeline> createState() => _VideoTrimTimelineState();
}

enum _Grip { start, end }

/// Zaman çizelgesindeki düzenleme işareti türü.
enum TimelineMarkKind { cut, mute, audio }

class TimelineMark {
  const TimelineMark(this.range, this.kind);
  final TrimRange range;
  final TimelineMarkKind kind;
}

class _VideoTrimTimelineState extends State<VideoTrimTimeline> {
  _Grip? _grip;
  int _lastSecond = -1;

  /// Parmağın x'i → ms (şerit genişliğinde).
  int _msAt(double x, double width) {
    final usable = width - 2 * VideoTrimTimeline.handleWidth;
    if (usable <= 0 || widget.durationMs <= 0) return 0;
    final f = ((x - VideoTrimTimeline.handleWidth) / usable).clamp(0.0, 1.0);
    return (f * widget.durationMs).round();
  }

  double _xOf(int ms, double width) {
    final usable = width - 2 * VideoTrimTimeline.handleWidth;
    if (widget.durationMs <= 0) return VideoTrimTimeline.handleWidth;
    return VideoTrimTimeline.handleWidth +
        usable * (ms / widget.durationMs).clamp(0.0, 1.0);
  }

  /// Dokunulan yere en yakın tutamaç.
  _Grip _grab(double x, double width) {
    final s = _xOf(widget.range.startMs, width);
    final e = _xOf(widget.range.endMs, width);
    return (x - s).abs() <= (x - e).abs() ? _Grip.start : _Grip.end;
  }

  void _move(double x, double width) {
    final grip = _grip;
    if (grip == null) return;
    final ms = _msAt(x, width);
    final next = grip == _Grip.start
        ? widget.range.withStart(ms, widget.durationMs)
        : widget.range.withEnd(ms, widget.durationMs);
    if (next == widget.range) return;
    final edge = grip == _Grip.start ? next.startMs : next.endMs;
    final second = edge ~/ 1000;
    if (second != _lastSecond) {
      _lastSecond = second;
      AppHaptics.step();
    }
    widget.onChanged(next);
    widget.onSeek?.call(edge);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = widget.accent ?? scheme.primary;
    return Semantics(
      label: '${context.t('vtr.start')} ${formatClock(widget.range.startMs)}, '
          '${context.t('vtr.end')} ${formatClock(widget.range.endMs)}',
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SizedBox(
          height: widget.height,
          child: LayoutBuilder(builder: (context, c) {
            final w = c.maxWidth;
            final s = _xOf(widget.range.startMs, w);
            final e = _xOf(widget.range.endMs, w);
            const hw = VideoTrimTimeline.handleWidth;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              // Tutamaç parmağın İNDİĞİ yere göre seçilir (eşik sonrası
              // konum kısa aralıkta öbür tutamaca daha yakın olabilir).
              onHorizontalDragDown: (d) {
                _grip = _grab(d.localPosition.dx, w);
                _lastSecond = -1;
              },
              onHorizontalDragStart: (_) => AppHaptics.selection(),
              onHorizontalDragUpdate: (d) => _move(d.localPosition.dx, w),
              onHorizontalDragEnd: (_) => _grip = null,
              onHorizontalDragCancel: () => _grip = null,
              // Dokunuş = önizlemeyi oraya götür.
              onTapUp: widget.onSeek == null
                  ? null
                  : (d) => widget.onSeek!(_msAt(d.localPosition.dx, w)),
              child: Stack(
                children: [
                  // Kare şeridi (tutamaç payı kadar içeriden).
                  PositionedDirectional(
                    start: hw,
                    end: hw,
                    top: Gap.xs,
                    bottom: Gap.xs,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(Radii.control),
                      child: _strip(context, scheme, w - 2 * hw),
                    ),
                  ),
                  for (final m in widget.marks) _mark(scheme, m, w),
                  // Aralık dışı karartma.
                  if (widget.dimOutside) PositionedDirectional(
                    start: hw,
                    width: (s - hw).clamp(0.0, w),
                    top: Gap.xs,
                    bottom: Gap.xs,
                    child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.6)),
                  ),
                  if (widget.dimOutside) PositionedDirectional(
                    start: e,
                    end: hw,
                    top: Gap.xs,
                    bottom: Gap.xs,
                    child: ColoredBox(color: scheme.scrim.withValues(alpha: 0.6)),
                  ),
                  // Seçili aralığın çerçevesi.
                  PositionedDirectional(
                    start: s,
                    width: (e - s).clamp(0.0, w),
                    top: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            horizontal:
                                BorderSide(color: accent, width: 3),
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (widget.playheadMs != null)
                    PositionedDirectional(
                      start: _xOf(widget.playheadMs!, w) - 1,
                      width: 2,
                      top: 0,
                      bottom: 0,
                      child: const IgnorePointer(
                        child: ColoredBox(color: AppColors.onMedia),
                      ),
                    ),
                  _handle(accent, scheme, s - hw, const ValueKey('trim-start'),
                      start: true),
                  _handle(accent, scheme, e, const ValueKey('trim-end'),
                      start: false),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  /// Bir düzenleme işareti: silinen bölüm koyu + makas; sessiz bölge altta,
  /// eklenen ses üstte renkli şerit.
  Widget _mark(ColorScheme scheme, TimelineMark m, double w) {
    final s = _xOf(m.range.startMs, w);
    final e = _xOf(m.range.endMs, w);
    final width = (e - s).clamp(0.0, w);
    const bar = 6.0;
    switch (m.kind) {
      case TimelineMarkKind.cut:
        return PositionedDirectional(
          start: s,
          width: width,
          top: Gap.xs,
          bottom: Gap.xs,
          child: IgnorePointer(
            child: ColoredBox(
              color: scheme.scrim.withValues(alpha: 0.78),
              child: width < 18
                  ? null
                  : Icon(AppIcons.cut, size: 16, color: scheme.error),
            ),
          ),
        );
      case TimelineMarkKind.mute:
        return PositionedDirectional(
          start: s,
          width: width,
          bottom: Gap.xs,
          height: bar,
          child: IgnorePointer(child: ColoredBox(color: scheme.error)),
        );
      case TimelineMarkKind.audio:
        return PositionedDirectional(
          start: s,
          width: width,
          top: Gap.xs,
          height: bar,
          child: IgnorePointer(child: ColoredBox(color: scheme.tertiary)),
        );
    }
  }

  Widget _handle(Color accent, ColorScheme scheme, double x, Key key,
      {required bool start}) {
    const r = Radius.circular(Radii.control);
    return PositionedDirectional(
      key: key,
      start: x,
      width: VideoTrimTimeline.handleWidth,
      top: 0,
      bottom: 0,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: accent,
          borderRadius: BorderRadiusDirectional.horizontal(
            start: start ? r : Radius.zero,
            end: start ? Radius.zero : r,
          ),
        ),
        child: Center(
          child: Container(
            width: 2,
            height: widget.height / 3,
            decoration: BoxDecoration(
              color: scheme.onPrimary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
      ),
    );
  }

  Widget _strip(BuildContext context, ColorScheme scheme, double width) {
    final frames = widget.frames;
    if (frames.isEmpty) {
      return ColoredBox(color: scheme.surfaceContainerHighest);
    }
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 2;
    final cell = width / frames.length;
    return Row(
      children: [
        for (final f in frames)
          Expanded(
            child: Image(
              image: FmFileImage(f,
                  cacheWidth: (cell * dpr).round().clamp(32, 480)),
              fit: BoxFit.cover,
              height: double.infinity,
              gaplessPlayback: true,
              filterQuality: FilterQuality.low,
              errorBuilder: (_, _, _) =>
                  ColoredBox(color: scheme.surfaceContainerHighest),
            ),
          ),
      ],
    );
  }
}

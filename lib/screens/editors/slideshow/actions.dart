part of '../slideshow_screen.dart';

/// **Faz 38 / madde 8 — sunumda köprü/eylem düğmeleri ve canlı sayaç.**
/// Sayaç slayta girince geri saymaya başlar (dokun → duraklat); vuruş yalnız
/// sayaçlı slayt gösterilirken (anayasa k.6).
extension _SlideshowActions on _SlideshowScreenState {
  bool _hitLink(Offset at) {
    final info = _curInfo;
    if (info == null) return false;
    for (final (i, c) in info.counters.indexed) {
      if (Rect.fromLTWH(c.x, c.y, c.w, c.h).contains(at)) {
        _partSetState(() => _counterPaused[i] = !(_counterPaused[i] ?? false));
        return true;
      }
    }
    for (final l in info.links.reversed) {
      if (!Rect.fromLTWH(l.x, l.y, l.w, l.h).contains(at)) continue;
      switch (l.kind) {
        case SlideLinkKind.next:
          _go(1);
        case SlideLinkKind.prev:
          _go(-1);
        case SlideLinkKind.first:
          _goTo(0);
        case SlideLinkKind.last:
          _goTo(widget.slides.length - 1);
        case SlideLinkKind.end:
          Navigator.of(context).maybePop();
        case SlideLinkKind.slide:
          final shown = widget.deckIndex.indexOf(l.slide ?? -1);
          if (shown >= 0) _goTo(shown);
        case SlideLinkKind.url:
          final u = Uri.tryParse(l.url ?? '');
          if (u != null && (u.scheme == 'http' || u.scheme == 'https' || u.scheme == 'mailto')) {
            unawaited(launchUrl(u, mode: LaunchMode.externalApplication));
          }
        case SlideLinkKind.none:
          break;
      }
      return true;
    }
    return false;
  }

  /// Slayta girerken sayaçları kurar.
  void _startCounters() {
    _counterTick?.cancel();
    _counterTick = null;
    _counterLeft.clear();
    _counterPaused.clear();
    final cs = _curInfo?.counters ?? const <SlideCounter>[];
    if (cs.isEmpty) return;
    for (final (i, c) in cs.indexed) {
      _counterLeft[i] = c.seconds;
    }
    _counterTick = Timer.periodic(const Duration(seconds: 1), (_) {
      var any = false;
      for (final k in _counterLeft.keys.toList()) {
        if (_counterPaused[k] == true) continue;
        final v = _counterLeft[k]!;
        if (v > 0) {
          _counterLeft[k] = v - 1;
          any = true;
        }
      }
      if (any) {
        _counterRev.value++;
      } else if (_counterPaused.values.every((p) => !p)) {
        _counterTick?.cancel(); // hepsi bitti
        _counterTick = null;
      }
    });
  }

  List<Widget> _counterOverlays() {
    final cs = _curInfo?.counters ?? const <SlideCounter>[];
    if (cs.isEmpty) return const [];
    final slide = widget.slides[_index];
    final r = _SlideshowScreenState.slideRect(_stageSize, slide);
    final k = r.width / slide.widthPt;
    return [
      for (final (i, c) in cs.indexed)
        // Slayt koordinatı fiziksel (slayt RTL'de aynalanmaz) → fromRect.
        Positioned.fromRect(
          rect: Rect.fromLTWH(r.left + c.x * k, r.top + c.y * k, c.w * k, c.h * k),
          child: IgnorePointer(
            child: ValueListenableBuilder<int>(
              valueListenable: _counterRev,
              builder: (context, _, _) {
                final left = _counterLeft[i] ?? c.seconds;
                return Container(
                  key: ValueKey('ss-counter-$i'),
                  alignment: Alignment.center,
                  padding: EdgeInsets.all(c.h * k * 0.12),
                  decoration: BoxDecoration(
                    color: left == 0 ? AppHues.red : AppColors.mediaChrome,
                    borderRadius: BorderRadius.circular(c.h * k * 0.15),
                  ),
                  child: FittedBox(
                    child: Text(
                      _SlideshowScreenState.clock(left),
                      style: context.type.heading.copyWith(
                          color: AppColors.onMedia,
                          fontFeatures: const [FontFeature.tabularFigures()]),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
    ];
  }
}

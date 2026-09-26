import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart' show HapticFeedback;

import '../../core/l10n/app_strings.dart';

/// Kaydırma çubuğundaki bir işaret (ör. yıl başlangıcı): [offset] kaydırma
/// ekseninde (ScrollPosition.pixels cinsinden) nerede başladığı.
class FmScrollTick {
  final double offset;
  final String label;
  const FmScrollTick(this.offset, this.label);
}

/// **Hızlı kaydırma tutamacı** — Google Foto / Samsung Galeri'deki sağ kenar
/// kulpu (2026-09-26 galeri turu).
///
/// 5000 fotoğraflık bir galeride iki yıl öncesine parmakla kaydırarak inmek
/// dakikalar sürüyordu. Tutamaç:
/// * kaydırma başlayınca sağ kenarda belirir, 1,5 sn hareketsizlikte söner
///   (duran ekranda fotoğrafın üstünde kalıcı bir çubuk olmasın);
/// * sürüklenince listeyi **doğrudan** o noktaya atlatır (liste satır
///   yükseklikleri bilindiği için ara satırlar kurulmaz — bkz.
///   `PhotoGridPlan`);
/// * sürüklerken yanında o anki ayı yazan bir balon ve kenar boyunca yıl
///   işaretleri gösterir; ay değiştikçe hafif titreşim verir.
///
/// Durum TUTMAZ: konum her karede [controller]dan okunur. Kendi yerleşimi
/// yoktur — üstüne bindiği alanı kaplar ama yalnız kulp dokunuş alır; geri
/// kalan her şey `IgnorePointer` (altındaki ızgaranın dokunuşları çalınmaz).
class FmFastScroller extends StatefulWidget {
  final ScrollController controller;

  /// Kaydırma ofsetindeki içeriğin kısa adı (balon metni). null → balon yok.
  final String? Function(double offset) labelFor;

  /// Sürüklerken kenarda gösterilen işaretler (ör. yıllar).
  final List<FmScrollTick> Function()? ticks;

  /// Kulpun gezdiği izin üst/alt payı (üst çubuk, alt eylem çubuğu).
  final EdgeInsets padding;

  /// İçerik görünür alanın en az bu katıysa tutamaç çıkar — kısa listede
  /// gereksiz.
  final double minContentRatio;

  const FmFastScroller({
    super.key,
    required this.controller,
    required this.labelFor,
    this.ticks,
    this.padding = EdgeInsets.zero,
    this.minContentRatio = 2.5,
  });

  @override
  State<FmFastScroller> createState() => _FmFastScrollerState();
}

class _FmFastScrollerState extends State<FmFastScroller> {
  static const _thumbHeight = 52.0;
  static const _thumbWidth = 30.0;

  bool _visible = false;
  bool _dragging = false;
  double _grab = 0;
  String? _lastLabel;
  Timer? _hide;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(FmFastScroller old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!mounted) return;
    // Konum yerleşim sırasında da değişebilir (içerik boyu değişince
    // kırpılır); o anda `setState` yasak → bir sonraki kareye ertele.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _onScroll());
      return;
    }
    _hide?.cancel();
    if (!_dragging) {
      _hide = Timer(const Duration(milliseconds: 1500), () {
        if (mounted && !_dragging) setState(() => _visible = false);
      });
    }
    setState(() => _visible = true);
  }

  ScrollPosition? get _position {
    final c = widget.controller;
    if (!c.hasClients || c.positions.length != 1) return null;
    final p = c.position;
    if (!p.hasContentDimensions || !p.hasViewportDimension) return null;
    return p;
  }

  void _dragTo(double localY, double trackHeight) {
    final p = _position;
    if (p == null) return;
    final usable = trackHeight - _thumbHeight;
    if (usable <= 0) return;
    final frac =
        ((localY - _grab - widget.padding.top) / usable).clamp(0.0, 1.0);
    p.jumpTo(frac * p.maxScrollExtent);
    final label = widget.labelFor(p.pixels);
    if (label != null && label != _lastLabel) {
      if (_lastLabel != null) HapticFeedback.selectionClick();
      _lastLabel = label;
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    if (p == null ||
        p.maxScrollExtent < p.viewportDimension * widget.minContentRatio) {
      return const SizedBox.shrink();
    }
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, constraints) {
      final track = constraints.maxHeight - widget.padding.vertical;
      if (track < _thumbHeight * 2) return const SizedBox.shrink();
      final usable = track - _thumbHeight;
      final frac = p.maxScrollExtent <= 0
          ? 0.0
          : (p.pixels / p.maxScrollExtent).clamp(0.0, 1.0);
      final thumbTop = widget.padding.top + frac * usable;
      final shown = _visible || _dragging;
      final label = _dragging ? widget.labelFor(p.pixels) : null;

      final children = <Widget>[];

      // ── Yıl işaretleri (yalnız sürüklerken) ─────────────────────────────
      if (_dragging && widget.ticks != null) {
        var lastY = -1000.0;
        for (final tick in widget.ticks!()) {
          final f = (tick.offset / p.maxScrollExtent).clamp(0.0, 1.0);
          final y = widget.padding.top + f * usable + _thumbHeight / 2;
          // Üst üste binen işaretler atlanır; kulpun hizasındaki işaret de
          // (balon zaten orada).
          if (y - lastY < 28) continue;
          if ((y - (thumbTop + _thumbHeight / 2)).abs() < 22) continue;
          lastY = y;
          children.add(Positioned(
            right: _thumbWidth + 10,
            top: y - 11,
            child: _TickLabel(text: tick.label),
          ));
        }
      }

      // ── Balon: o anki ay ────────────────────────────────────────────────
      if (label != null) {
        children.add(Positioned(
          right: _thumbWidth + 14,
          top: thumbTop + _thumbHeight / 2 - 20,
          child: Material(
            elevation: 3,
            color: scheme.inverseSurface,
            shape: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                label,
                style: TextStyle(
                  color: scheme.onInverseSurface,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ));
      }

      return Stack(
        children: [
          Positioned.fill(child: IgnorePointer(child: Stack(children: children))),
          Positioned(
            right: 0,
            top: thumbTop,
            child: IgnorePointer(
              ignoring: !shown,
              child: AnimatedOpacity(
                opacity: shown ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (d) {
                    _hide?.cancel();
                    _grab = d.localPosition.dy;
                    _lastLabel = widget.labelFor(p.pixels);
                    setState(() => _dragging = true);
                  },
                  onVerticalDragUpdate: (d) {
                    final box = context.findRenderObject() as RenderBox?;
                    if (box == null) return;
                    _dragTo(box.globalToLocal(d.globalPosition).dy, track);
                  },
                  onVerticalDragEnd: (_) => _endDrag(),
                  onVerticalDragCancel: _endDrag,
                  child: Semantics(
                    label: context.t('ph.fast_scroll'),
                    child: SizedBox(
                      // Dokunma alanı görünen kulptan geniş: kenarda ince bir
                      // kulpu tutturmak zor.
                      width: _thumbWidth + 18,
                      height: _thumbHeight,
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: Container(
                          width: _thumbWidth,
                          height: _thumbHeight,
                          decoration: BoxDecoration(
                            color: _dragging
                                ? scheme.primary
                                : scheme.surfaceContainerHighest,
                            borderRadius: const BorderRadius.horizontal(
                              left: Radius.circular(_thumbHeight / 2),
                            ),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.unfold_more,
                            size: 20,
                            color: _dragging
                                ? scheme.onPrimary
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  void _endDrag() {
    if (!mounted) return;
    setState(() => _dragging = false);
    _onScroll(); // sönme sayacını yeniden kur
  }
}

class _TickLabel extends StatelessWidget {
  final String text;
  const _TickLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'office_shell.dart';

/// Ham pointer'lardan pinch zoom — jest arenasına girmez, kaydırmayla çekişmez.
/// İki parmak inince [builder]'a verilen physics kilitlenir ve parmaklar
/// arası mesafe oranı canlı GPU ölçeği olur; parmak kalkınca ölçek kalıcı
/// zoom'a işlenir ([builder] net içerikle yeniden çizer) ve [onCommitted]
/// kaydırma ofsetlerini düzeltebilsin diye çarpanı alır (kare sonrası).
/// Zoom % rozeti içeridedir. Excel ızgarası ve slayt listesi bunu paylaşır.
class PinchZoomArea extends StatefulWidget {
  final double minZoom;
  final double maxZoom;
  final Widget Function(
      BuildContext context, double zoom, ScrollPhysics? physics) builder;

  /// Ölçek işlendiğinde çağrılır: [factor] uygulanacak çarpan, [focal] pinch'in
  /// başladığı nokta (bu widget'ın yerel koordinatında) — kaydırma ofseti bu
  /// noktayı sabit tutacak şekilde düzeltilmeli.
  final void Function(double factor, Offset focal)? onCommitted;

  const PinchZoomArea({
    super.key,
    this.minZoom = 0.5,
    this.maxZoom = 3,
    required this.builder,
    this.onCommitted,
  });

  @override
  State<PinchZoomArea> createState() => _PinchZoomAreaState();
}

class _PinchZoomAreaState extends State<PinchZoomArea> {
  double _zoom = 1; // işlenmiş ölçek
  double _gestureZoom = 1; // pinch sırasında geçici Transform ölçeği
  final Map<int, Offset> _touches = {};
  double? _pinchStartDist;
  Offset _focal = Offset.zero; // pinch odağı — zoom bu noktadan büyür/küçülür
  late final _badge = ZoomBadgeController((fn) {
    if (mounted) setState(fn);
  });

  @override
  void dispose() {
    _badge.dispose();
    super.dispose();
  }

  double _dist() {
    final pts = _touches.values.toList();
    return (pts[0] - pts[1]).distance;
  }

  void _down(PointerDownEvent e) {
    _touches[e.pointer] = e.localPosition;
    if (_touches.length == 2) {
      _pinchStartDist = _dist();
      final pts = _touches.values.toList();
      _focal = (pts[0] + pts[1]) / 2; // parmakların ortası = zoom odağı
      setState(() {}); // kaydırma kilidi devreye girsin
    }
  }

  void _move(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    final start = _pinchStartDist;
    if (start != null && start > 0 && _touches.length == 2) {
      final f = (_dist() / start)
          .clamp(widget.minZoom / _zoom, widget.maxZoom / _zoom);
      setState(() => _gestureZoom = f);
      _badge.bump(_zoom * f);
    }
  }

  void _end(int pointer) {
    _touches.remove(pointer);
    if (_pinchStartDist != null && _touches.length < 2) {
      _pinchStartDist = null;
      _commit();
    }
  }

  void _commit() {
    final f = _gestureZoom;
    setState(() {
      _zoom = (_zoom * f).clamp(widget.minZoom, widget.maxZoom);
      _gestureZoom = 1;
    });
    if ((f - 1).abs() < 0.001) return;
    // Ofset düzeltmesi yeni yerleşim ölçüldükten sonra yapılmalı.
    final focal = _focal;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onCommitted?.call(f, focal);
    });
  }

  @override
  Widget build(BuildContext context) {
    final ScrollPhysics? physics =
        _pinchStartDist != null ? const NeverScrollableScrollPhysics() : null;
    return Stack(
      children: [
        Positioned.fill(
          child: Listener(
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: (e) => _end(e.pointer),
            onPointerCancel: (e) => _end(e.pointer),
            // Pinch sırasında büyüyen içerik alanın dışına (rozet/komşu çubuklar)
            // taşmasın diye kırpılır; commit sonrası içerik zaten görünür alanda.
            child: ClipRect(
              child: Transform.scale(
                scale: _gestureZoom,
                // Zoom parmakların ortasından büyür — sol üstten değil; içerik
                // parmakların altında kalır, "sayfa kayboluyor" hissi olmaz.
                // alignment varsayılanı (center) origin'e EKLENİR; topLeft
                // verilmezse etkin merkez odak+viewport/2 olur ve içerik
                // yaklaştırırken sağa/aşağı kayar (commit matematiğiyle uyumsuz).
                alignment: Alignment.topLeft,
                origin: _focal,
                child: widget.builder(context, _zoom, physics),
              ),
            ),
          ),
        ),
        Positioned(
          left: 12,
          bottom: MediaQuery.of(context).padding.bottom + 12,
          child: ZoomBadge(zoom: _badge.zoom, visible: _badge.visible),
        ),
      ],
    );
  }
}

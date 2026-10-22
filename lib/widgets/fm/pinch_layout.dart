import 'package:flutter/widgets.dart';

import '../../models/fm_layout.dart';

/// Altındaki listeye **iki parmakla sütun değiştirme** ekler (Faz 17 / G12).
///
/// Ham işaretçi olayları (`Listener`) kullanılır: jest arenasına girmez,
/// liste kaydırması ve sürükleyerek seçim aynen çalışır. Eşikler
/// Fotoğraflar ızgarasıyla aynı (açmak 1,22×, sıkıştırmak 0,84×); bir pinch
/// içinde basamak geçince taban yenilenir, yani tek harekette birden çok
/// basamak atlanabilir.
class PinchLayoutSwitcher extends StatefulWidget {
  final FmLayout layout;
  final ValueChanged<FmLayout> onChanged;
  final Widget child;

  const PinchLayoutSwitcher({
    super.key,
    required this.layout,
    required this.onChanged,
    required this.child,
  });

  @override
  State<PinchLayoutSwitcher> createState() => _PinchLayoutSwitcherState();
}

class _PinchLayoutSwitcherState extends State<PinchLayoutSwitcher> {
  final _touches = <int, Offset>{};
  double? _base;
  late FmLayout _current = widget.layout;

  @override
  void didUpdateWidget(PinchLayoutSwitcher old) {
    super.didUpdateWidget(old);
    _current = widget.layout;
  }

  double _distance() {
    final pts = _touches.values.toList(growable: false);
    return (pts[0] - pts[1]).distance;
  }

  void _move(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.localPosition;
    final base = _base;
    if (base == null || base <= 0 || _touches.length != 2) return;
    final ratio = _distance() / base;
    final dir = ratio > 1.22 ? -1 : (ratio < 0.84 ? 1 : 0);
    if (dir == 0) return;
    _base = _distance();
    final next = fmPinchStep(_current, dir);
    if (next == _current) return;
    _current = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) => Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (e) {
          _touches[e.pointer] = e.localPosition;
          if (_touches.length == 2) _base = _distance();
        },
        onPointerMove: _move,
        onPointerUp: (e) => _end(e.pointer),
        onPointerCancel: (e) => _end(e.pointer),
        child: widget.child,
      );

  void _end(int pointer) {
    _touches.remove(pointer);
    if (_touches.length < 2) _base = null;
  }
}

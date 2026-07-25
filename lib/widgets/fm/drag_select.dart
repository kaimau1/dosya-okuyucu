import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show BoxHitTestResult, RenderMetaData;
import 'package:flutter/services.dart' show HapticFeedback;

/// Basılı tutup **kaydırarak** çoklu seçim (dosya yöneticilerindeki tanıdık his).
///
/// Kullanım: listeyi/ızgarayı [DragSelectArea] ile sar, her öğeyi
/// [DragSelectItem] ile (indeksini vererek) sar. Uzun basış öğeyi seçer ve
/// sürükleme kipini başlatır; parmak gezindikçe **çapa ile o an dokunulan öğe
/// arasındaki tüm aralık** aynı işleme (seç / seçimden çıkar) tabi tutulur.
/// Parmak listenin kenarına yaklaşınca liste kendiliğinden kayar.
///
/// *Niye kendi çözümümüz:* hazır paketler (drag_select_grid_view) yalnız
/// GridView'ı sarıyor, ayrıca kendi seçim durumunu tutuyor — bizde seçim
/// ekranların `Set<String>`inde ve hem liste hem ızgara var. Burada durum
/// TUTULMAZ; yalnız "şu aralığa şunu uygula" geri çağrısı verilir.
///
/// Öğe indeksini bulmak için [MetaData] kullanılır: `RenderMetaData` hit-test
/// sonucunda yola eklendiği için, parmağın altındaki öğeyi widget ağacına
/// GlobalKey ekleyip ölçmeden (O(1)) bulabiliyoruz.
class DragSelectArea extends StatefulWidget {
  /// Sarılan kaydırılabilir alanın denetleyicisi (kenarda otomatik kaydırma).
  final ScrollController? scrollController;

  /// Verilen indeks şu an seçili mi? (Çapadaki öğeye göre kip belirlenir:
  /// seçili değilse sürükleme *seçer*, seçiliyse *seçimden çıkarır*.)
  final bool Function(int index) isSelected;

  /// [start]..[end] (uçlar dahil) aralığındaki öğeler [select] ise seçilir,
  /// değilse seçimden çıkarılır.
  final void Function(int start, int end, bool select) onSelectRange;

  /// Uzun basış tamamlandığında (parmak kalkınca) çağrılır — tek öğe uzun
  /// basışı da buraya düşer; ekran isterse geri bildirim gösterir.
  final VoidCallback? onEnd;

  final bool enabled;
  final Widget child;

  const DragSelectArea({
    super.key,
    required this.isSelected,
    required this.onSelectRange,
    required this.child,
    this.scrollController,
    this.onEnd,
    this.enabled = true,
  });

  @override
  State<DragSelectArea> createState() => _DragSelectAreaState();
}

class _DragSelectAreaState extends State<DragSelectArea> {
  int? _anchor;
  int _curStart = 0;
  int _curEnd = 0;
  bool _mode = true;
  Offset? _pointer;
  Timer? _autoScroll;

  @override
  void dispose() {
    _autoScroll?.cancel();
    super.dispose();
  }

  // ── indeks bulma ──────────────────────────────────────────────────────────

  RenderBox? get _box {
    final ro = context.findRenderObject();
    return ro is RenderBox && ro.hasSize ? ro : null;
  }

  /// Ekran koordinatındaki noktanın altındaki öğe indeksi (yoksa null).
  /// Nokta alanın dışındaysa kenara kırpılır — otomatik kaydırma sırasında
  /// parmak listenin dışına taşsa da en yakın öğe bulunur.
  int? _indexAt(Offset globalPos) {
    final box = _box;
    if (box == null) return null;
    var local = box.globalToLocal(globalPos);
    local = Offset(
      local.dx.clamp(0.5, box.size.width - 0.5),
      local.dy.clamp(0.5, box.size.height - 0.5),
    );
    final result = BoxHitTestResult();
    box.hitTest(result, position: local);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is RenderMetaData) {
        final meta = target.metaData;
        if (meta is DragSelectIndex) return meta.index;
      }
    }
    return null;
  }

  // ── jest ──────────────────────────────────────────────────────────────────

  void _start(LongPressStartDetails d) {
    if (!widget.enabled) return;
    final idx = _indexAt(d.globalPosition);
    if (idx == null) return;
    _anchor = idx;
    _curStart = idx;
    _curEnd = idx;
    _mode = !widget.isSelected(idx);
    _pointer = d.globalPosition;
    widget.onSelectRange(idx, idx, _mode);
    HapticFeedback.selectionClick();
  }

  void _move(LongPressMoveUpdateDetails d) {
    if (_anchor == null) return;
    _pointer = d.globalPosition;
    _applyPointer();
    _tickAutoScroll();
  }

  void _finish() {
    _autoScroll?.cancel();
    _autoScroll = null;
    if (_anchor != null) widget.onEnd?.call();
    _anchor = null;
    _pointer = null;
  }

  void _applyPointer() {
    final anchor = _anchor;
    final pointer = _pointer;
    if (anchor == null || pointer == null) return;
    final idx = _indexAt(pointer);
    if (idx == null) return;
    final newStart = idx < anchor ? idx : anchor;
    final newEnd = idx < anchor ? anchor : idx;
    if (newStart == _curStart && newEnd == _curEnd) return;
    for (final step
        in dragSelectDelta(_curStart, _curEnd, newStart, newEnd, _mode)) {
      widget.onSelectRange(step.start, step.end, step.select);
    }
    _curStart = newStart;
    _curEnd = newEnd;
  }

  /// Parmak kenardaysa listeyi kaydırır ve kayma sonrası parmağın altına gelen
  /// yeni öğeleri seçime katar.
  void _tickAutoScroll() {
    _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) {
      final ctrl = widget.scrollController;
      final box = _box;
      final pointer = _pointer;
      if (ctrl == null || !ctrl.hasClients || box == null || pointer == null) {
        return;
      }
      final dy = box.globalToLocal(pointer).dy;
      const zone = 72.0; // kenardan bu kadar yakınsa kaydır
      double delta = 0;
      if (dy < zone) {
        delta = -(zone - dy) * 0.35;
      } else if (dy > box.size.height - zone) {
        delta = (dy - (box.size.height - zone)) * 0.35;
      }
      if (delta == 0) return;
      final target = (ctrl.offset + delta)
          .clamp(ctrl.position.minScrollExtent, ctrl.position.maxScrollExtent);
      if (target == ctrl.offset) return;
      ctrl.jumpTo(target);
      // Kaydıktan sonra parmağın altındaki öğe değişmiş olabilir.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _applyPointer();
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return GestureDetector(
      // Uzun basış BURADA yakalanır; öğelerin kendi onLongPress'i olmamalı
      // (olursa jest arenasını çocuk kazanır ve sürükleme hiç başlamaz).
      onLongPressStart: _start,
      onLongPressMoveUpdate: _move,
      onLongPressEnd: (_) => _finish(),
      onLongPressCancel: _finish,
      child: widget.child,
    );
  }
}

/// [DragSelectArea] içindeki bir öğeyi indeksiyle işaretler.
class DragSelectItem extends StatelessWidget {
  final int index;
  final Widget child;
  const DragSelectItem({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) => MetaData(
        metaData: DragSelectIndex(index),
        // opaque: öğeler arasındaki boşlukta da (ızgara aralıkları) indeks
        // bulunsun; çocukların kendi hit-test'ini engellemez.
        behavior: HitTestBehavior.opaque,
        child: child,
      );
}

/// [MetaData] içinde taşınan indeks işareti.
class DragSelectIndex {
  final int index;
  const DragSelectIndex(this.index);
}

/// Sürükleme aralığı değiştiğinde uygulanacak adımlar (saf fonksiyon → testli).
///
/// Aralık daima çapayı içerir, bu yüzden eski ve yeni aralık iç içedir ya da
/// çapada kesişir: büyüyen uçlar [mode] ile işaretlenir, küçülen uçlar geri
/// alınır (`!mode`).
List<DragSelectStep> dragSelectDelta(
    int oldStart, int oldEnd, int newStart, int newEnd, bool mode) {
  final steps = <DragSelectStep>[];
  if (newStart > oldStart) {
    steps.add(DragSelectStep(oldStart, newStart - 1, !mode));
  } else if (newStart < oldStart) {
    steps.add(DragSelectStep(newStart, oldStart - 1, mode));
  }
  if (newEnd < oldEnd) {
    steps.add(DragSelectStep(newEnd + 1, oldEnd, !mode));
  } else if (newEnd > oldEnd) {
    steps.add(DragSelectStep(oldEnd + 1, newEnd, mode));
  }
  return steps;
}

class DragSelectStep {
  final int start;
  final int end;
  final bool select;
  const DragSelectStep(this.start, this.end, this.select);

  @override
  bool operator ==(Object other) =>
      other is DragSelectStep &&
      other.start == start &&
      other.end == end &&
      other.select == select;

  @override
  int get hashCode => Object.hash(start, end, select);

  @override
  String toString() => 'DragSelectStep($start..$end, $select)';
}

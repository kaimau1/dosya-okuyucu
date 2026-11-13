import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:pdfrx/pdfrx.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/motion.dart';
import '../../services/pdf/pro/pdf_edit_bridge.dart';
import 'pdf_pro_edit_controller.dart';

part 'pdf_block_layer_painter.dart';

/// [point]'e düşen blok: kutusu ([slop] kadar genişletilmiş) noktayı içeren
/// bloklardan merkezi en yakın olan; yoksa null. Komşu bloklar çakışırsa
/// dokunulan noktaya en yakın kutu kazanır (etkileşim sözleşmesi §2).
int? hitPdfBlock(List<Rect> rects, Offset point, {double slop = 6}) {
  int? best;
  var bestD = double.infinity;
  for (var i = 0; i < rects.length; i++) {
    if (!rects[i].inflate(slop).contains(point)) continue;
    final d = (rects[i].center - point).distanceSquared;
    if (d < bestD) {
      bestD = d;
      best = i;
    }
  }
  return best;
}

/// Sayfa katmanının ekrana (görüntüleyici) bildirdiği olaylar.
class PdfProLayerEvents {
  const PdfProLayerEvents({
    required this.onEdit,
    required this.onLocked,
    required this.onBlockMenu,
    required this.onCommit,
    required this.onRefused,
    required this.onNote,
    required this.onAnnotTap,
    required this.onTextBox,
  });

  /// Bloğu yazmaya aç (imleç [offset]'te; çift dokunuşta sözcük seçili).
  final void Function(int pageIndex, PdfTextBlock block,
      {int? offset, (int, int)? selection}) onEdit;

  /// Kilitli bloğa dokunuldu (PK7: neden + seçenekler).
  final void Function(int pageIndex, PdfTextBlock block) onLocked;
  final void Function(int pageIndex, PdfTextBlock block) onBlockMenu;

  /// Yazarken bloğun dışına dokunuldu: uygula.
  final VoidCallback onCommit;

  /// Bir işlem reddedildi (taşıma, işaretleme…).
  final void Function(Object error) onRefused;

  /// Not eklenecek nokta (sayfa uzayı).
  final void Function(int pageIndex, double x, double y) onNote;
  final void Function(int pageIndex, PdfAnnotInfo annot) onAnnotTap;

  /// Yeni metin kutusu noktası (sayfa uzayı).
  final void Function(int pageIndex, double x, double y) onTextBox;
}

/// **Düzenleme kipinin sayfa katmanı** (PDF Pro Faz 54–60).
///
/// Araca göre davranır:
/// * **Metin:** blok kılavuzları; dokunuş seçer, seçili bloğa dokunuş yazmayı
///   açar (imleç dokunulan harfte); seçili blok sürüklenerek taşınır, yan
///   tutamaçla genişliği değişir. Yazarken imleç, seçim ve bileşim alt çizgisi
///   burada çizilir — metnin kendisi PDFium'un çizdiği gerçek sayfadır (PK6).
/// * **Görsel:** görsel/şekil seçimi, taşıma, köşeden ölçekleme.
/// * **İşaretle:** metin üstü vurgu/alt/üst çizgi, kalem, not, şekil, silgi.
///
/// **Katman kaydırmayı/yakınlaştırmayı YUTMAZ** (kök neden 2026-11-13 —
/// kullanıcı: *"seçim açıkken çift parmak zoom, kaydırma yapılmıyor"*): pdfrx
/// sayfa katmanlarını `InteractiveViewer`'ın ÜSTÜNE kardeş olarak dizer; sayfayı
/// kaplayan bir `GestureDetector` (ve `hitTest`'i null dönen her `CustomPaint`)
/// parmağı yutar, görüntüleyici hiç görmez. Bu yüzden:
/// * boya katmanı isabet almaz ([_LayerPainter.hitTest] false);
/// * dokun / çift dokun / uzun bas pdfrx'in [PdfOverlayInteractionRegion]'ıyla
///   gelir (jesti görüntüleyici tanır, kaydırma ve yakınlaştırma onda kalır);
/// * çizim ve seçim uzatma arenaya girmeyen `Listener` ile izlenir;
/// * parmağı sahiplenen tek şey küçük tutamaçlardır (taşı, genişlet, ölçekle).
/// Sayfa koordinatında çizer — dil değişince aynalanmaz.
class PdfProBlockLayer extends StatefulWidget {
  const PdfProBlockLayer({
    super.key,
    required this.page,
    required this.pageSize,
    required this.controller,
    required this.events,
    this.zoom,
  });

  final PdfPage page;
  final Size pageSize;
  final PdfProEditController controller;
  final PdfProLayerEvents events;

  /// Görüntüleyicinin güncel yakınlaştırması (tutamaç/çizgi kalınlığı ekranda
  /// sabit kalsın diye).
  final double Function()? zoom;

  @override
  State<PdfProBlockLayer> createState() => _PdfProBlockLayerState();
}

class _PdfProBlockLayerState extends State<PdfProBlockLayer> {
  PdfProEditController get c => widget.controller;
  int get pageIndex => widget.page.pageNumber - 1;

  // Sürükleme önizlemesi (sayfa katmanı pikseli).
  Offset _drag = Offset.zero;
  double _widthDrag = 0, _scale = 1;
  bool _dragging = false;

  // İşaretleme önizlemesi.
  final List<Offset> _stroke = [];
  Offset? _markFrom, _markTo;

  Timer? _blink;
  final ValueNotifier<bool> _caretOn = ValueNotifier(true);
  int _lastSel = -1;

  @override
  void initState() {
    super.initState();
    c.addListener(_onController);
  }

  @override
  void didUpdateWidget(PdfProBlockLayer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onController);
      c.addListener(_onController);
    }
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _blink?.cancel();
    _caretOn.dispose();
    super.dispose();
  }

  bool get _liveHere => c.live?.pageIndex == pageIndex;

  void _onController() {
    // İmleç yalnız bu sayfada yazılırken yanıp söner; boşta 0 kare.
    final live = c.live;
    if (live != null && live.pageIndex == pageIndex) {
      final sel = live.selStart * 100003 + live.selEnd;
      if (sel != _lastSel) {
        _lastSel = sel;
        _caretOn.value = true;
        _blink?.cancel();
        _blink = null;
      }
      _blink ??= Timer.periodic(
          Motion.caretBlink, (_) => _caretOn.value = !_caretOn.value);
    } else {
      _blink?.cancel();
      _blink = null;
    }
  }

  /// Katman ekran pikselindedir (pdfrx sayfa dikdörtgenini ekran uzayında
  /// verir): tutamaç ve çizgi kalınlığı yakınlaştırmadan bağımsız sabittir.
  double get _px => 1;

  // Çizim (İşaretle) ve seçim uzatma: ham işaretçi izleme.
  int _drawPointers = 0;
  int? _drawPointer;
  bool _extending = false;

  void _drawReset() {
    _drawPointer = null;
    if (_markFrom == null && _stroke.isEmpty) return;
    setState(() {
      _markFrom = null;
      _markTo = null;
      _stroke.clear();
    });
  }

  void _drawDown(PointerDownEvent e) {
    _drawPointers++;
    // İkinci parmak = yakınlaştırma: başlamış çizgi bırakılır.
    if (_drawPointers > 1) {
      _drawReset();
      return;
    }
    _drawPointer = e.pointer;
    setState(() {
      _markFrom = e.localPosition;
      _markTo = e.localPosition;
      _stroke
        ..clear()
        ..add(e.localPosition);
    });
  }

  void _drawMove(PointerMoveEvent e) {
    if (e.pointer != _drawPointer) return;
    setState(() {
      _markTo = e.localPosition;
      if (c.markup == PdfMarkupKind.ink) _stroke.add(e.localPosition);
    });
  }

  void _drawUp(PointerEvent e, {bool cancel = false}) {
    _drawPointers = math.max(0, _drawPointers - 1);
    if (e.pointer != _drawPointer) return;
    _drawPointer = null;
    if (cancel) {
      _drawReset();
      return;
    }
    _finishMarkup();
  }

  /// Dokun / çift dokun / uzun bas hedefi. Görüntüleyicinin içindeyken jesti
  /// pdfrx tanır ve buraya bildirir (parmak görüntüleyicide kalır); tek başına
  /// (test) sıradan jest algılayıcı.
  Widget _tapTarget(
    BuildContext context, {
    required void Function(Offset local) onTap,
    required void Function(Offset local) onDoubleTap,
    required void Function(Offset local) onLongPress,
  }) {
    final box = SizedBox.fromSize(size: widget.pageSize);
    if (PdfOverlayHitTester.of(context) != null) {
      return PdfOverlayInteractionRegion(
        onTap: (d) {
          onTap(d.localPosition);
          return true;
        },
        onDoubleTap: (d) {
          onDoubleTap(d.localPosition);
          return true;
        },
        onLongPress: (d) {
          onLongPress(d.localPosition);
          return true;
        },
        child: box,
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapUp: (d) => onTap(d.localPosition),
      onDoubleTapDown: (d) => onDoubleTap(d.localPosition),
      onLongPressStart: (d) => onLongPress(d.localPosition),
      child: box,
    );
  }

  Offset _w(double x, double y) => PdfPoint(x, y)
      .toOffset(page: widget.page, scaledPageSize: widget.pageSize);
  PdfPoint _p(Offset o) =>
      o.toPdfPoint(page: widget.page, scaledPageSize: widget.pageSize);
  Rect _r(double l, double b, double r, double t) => PdfRect(l, t, r, b)
      .toRect(page: widget.page, scaledPageSize: widget.pageSize);
  double get _unit => widget.pageSize.height / widget.page.height;

  List<Rect> _blockRects(List<PdfTextBlock> blocks) =>
      [for (final b in blocks) _r(b.left, b.bottom, b.right, b.top)];

  // ── yazma kipi hareketleri ─────────────────────────────────────────────
  void _caretTo(Offset local, {bool word = false, bool extend = false}) {
    final live = c.live;
    if (live == null) return;
    final pt = _p(local);
    final off = live.map.offsetAt(pt.x, pt.y);
    var a = off, b = off;
    if (word) {
      (a, b) = live.map.wordAt(off);
    } else if (extend) {
      a = live.selStart;
    }
    final t = live.text;
    c.liveInput(t, pdfUtf16Index(t, a), pdfUtf16Index(t, b));
  }

  Rect _liveBounds(PdfLiveEdit live) {
    final map = live.map;
    Rect? r;
    for (var i = 0; i < map.lineCount; i++) {
      double x0 = map.starts[i], x1 = map.starts[i];
      for (var k = 0; k < map.length; k++) {
        if (map.line[k] != i) continue;
        x0 = math.min(x0, map.xs[k]);
        x1 = math.max(x1, map.xe[k]);
      }
      final (ax, ay, bx, by) = _lineCorners(map, i, x0, x1);
      final lr = Rect.fromPoints(_w(ax, ay), _w(bx, by));
      r = r == null ? lr : r.expandToInclude(lr);
    }
    return (r ?? Rect.zero).inflate(8 * _px);
  }

  (double, double, double, double) _lineCorners(
      PdfBlockTextMap map, int line, double x0, double x1) {
    final cs = math.cos(map.angle), sn = math.sin(map.angle);
    final y0 = map.bases[line] - map.sizes[line] * 0.25;
    final y1 = map.bases[line] + map.sizes[line] * 0.9;
    return (
      x0 * cs - y0 * sn,
      x0 * sn + y0 * cs,
      x1 * cs - y1 * sn,
      x1 * sn + y1 * cs
    );
  }

  // ── işaretleme ─────────────────────────────────────────────────────────
  bool get _textMarkup => const {
        PdfMarkupKind.highlight,
        PdfMarkupKind.underline,
        PdfMarkupKind.strikeout,
        PdfMarkupKind.squiggly
      }.contains(c.markup);
  bool get _shapeMarkup => const {
        PdfMarkupKind.rect,
        PdfMarkupKind.ellipse,
        PdfMarkupKind.line,
        PdfMarkupKind.arrow,
        PdfMarkupKind.redact
      }.contains(c.markup);

  /// Sürüklenen iki nokta arasındaki metnin satır dörtgenleri (PDF sırası:
  /// sol-üst, sağ-üst, sol-alt, sağ-alt).
  List<List<double>> _quadsBetween(Offset from, Offset to) {
    final blocks = c.blocksOf(pageIndex) ?? const <PdfTextBlock>[];
    final a = _p(from), b = _p(to);
    final out = <List<double>>[];
    // Başlangıç noktasının bloğu; yoksa en yakını.
    PdfTextBlock? hit;
    var best = double.infinity;
    for (final blk in blocks) {
      final dx = math.max(0.0, math.max(blk.left - a.x, a.x - blk.right));
      final dy = math.max(0.0, math.max(blk.bottom - a.y, a.y - blk.top));
      final d = dx + dy;
      if (d < best) {
        best = d;
        hit = blk;
      }
    }
    if (hit == null || best > 24) return out;
    final map = hit.map;
    var s = map.offsetAt(a.x, a.y), e = map.offsetAt(b.x, b.y);
    if (s > e) (s, e) = (e, s);
    for (final q in map.selection(s, e)) {
      // selection: sol-alt, sağ-alt, sağ-üst, sol-üst → PDF sırası.
      out.add([q[6], q[7], q[4], q[5], q[0], q[1], q[2], q[3]]);
    }
    return out;
  }

  Future<void> _finishMarkup() async {
    final from = _markFrom, to = _markTo;
    final kind = c.markup;
    final stroke = List<Offset>.of(_stroke);
    setState(() {
      _markFrom = null;
      _markTo = null;
      _stroke.clear();
    });
    try {
      if (kind == PdfMarkupKind.ink) {
        if (stroke.length < 2) return;
        final pts = <double>[];
        var l = double.infinity, b = double.infinity;
        var r = -double.infinity, t = -double.infinity;
        for (final o in stroke) {
          final p = _p(o);
          pts
            ..add(p.x)
            ..add(p.y);
          l = math.min(l, p.x);
          r = math.max(r, p.x);
          b = math.min(b, p.y);
          t = math.max(t, p.y);
        }
        final pad = c.markupWidth;
        await c.annotate(
            PdfAnnotChange.add(pageIndex, PdfAnnotType.ink,
                rect: [l - pad, b - pad, r + pad, t + pad],
                ink: [pts],
                color: c.markupColor | 0xFF000000,
                width: c.markupWidth),
            label: 'pse.step_ink');
        return;
      }
      if (from == null || to == null) return;
      if (_textMarkup) {
        final quads = _quadsBetween(from, to);
        if (quads.isEmpty) return;
        var l = double.infinity, b = double.infinity;
        var r = -double.infinity, t = -double.infinity;
        for (final q in quads) {
          for (var i = 0; i < 8; i += 2) {
            l = math.min(l, q[i]);
            r = math.max(r, q[i]);
            b = math.min(b, q[i + 1]);
            t = math.max(t, q[i + 1]);
          }
        }
        await c.annotate(
            PdfAnnotChange.add(
                pageIndex,
                switch (kind) {
                  PdfMarkupKind.underline => PdfAnnotType.underline,
                  PdfMarkupKind.strikeout => PdfAnnotType.strikeout,
                  PdfMarkupKind.squiggly => PdfAnnotType.squiggly,
                  _ => PdfAnnotType.highlight,
                },
                rect: [l, b, r, t],
                quads: quads,
                color: c.markupColor | 0xFF000000),
            label: 'pse.step_markup');
        return;
      }
      if (kind == PdfMarkupKind.redact && (to - from).distance > 6 * _px) {
        final a = _p(from), z = _p(to);
        // Satırın üstünden yatay sürükleme ince bir kutu verir (cihaz
        // 2026-11-13: yalnız birkaç harf silindi, kutu çizgi gibi) → metin
        // seçimi gibi satır dörtgenleri karartılır.
        final quads =
            (a.y - z.y).abs() < 6 ? _quadsBetween(from, to) : const <List<double>>[];
        List<double> box(List<double> q) {
          final xs = [q[0], q[2], q[4], q[6]], ys = [q[1], q[3], q[5], q[7]];
          return [xs.reduce(math.min), ys.reduce(math.min),
              xs.reduce(math.max), ys.reduce(math.max)];
        }
        await c.mutate(pageIndex, [
          PdfMutAction.redact(quads.isEmpty
              ? [a.x, a.y, z.x, z.y]
              : [for (final q in quads) ...box(q)]),
        ], label: 'pse.step_redact');
        return;
      }
      if (_shapeMarkup && (to - from).distance > 6 * _px) {
        final a = _p(from), z = _p(to);
        await c.mutate(pageIndex, [
          PdfMutAction.shape(
              switch (kind) {
                PdfMarkupKind.ellipse => PdfShapeKind.ellipse,
                PdfMarkupKind.line => PdfShapeKind.line,
                PdfMarkupKind.arrow => PdfShapeKind.arrow,
                _ => PdfShapeKind.rect,
              },
              a.x,
              a.y,
              z.x,
              z.y,
              stroke: c.markupColor | 0xFF000000,
              strokeWidth: c.markupWidth),
        ], label: 'pse.step_shape');
      }
    } catch (e) {
      widget.events.onRefused(e);
    }
  }

  PdfAnnotInfo? _annotAt(Offset local) {
    final annots = c.annotsOf(pageIndex) ?? const <PdfAnnotInfo>[];
    final p = _p(local);
    final slop = 6 / _unit * _px;
    for (final a in annots.reversed) {
      if (p.x >= a.left - slop &&
          p.x <= a.right + slop &&
          p.y >= a.bottom - slop &&
          p.y <= a.top + slop) {
        return a;
      }
    }
    return null;
  }

  PdfPageItem? _itemAt(Offset local) {
    final items = c.contentOf(pageIndex)?.items ?? const <PdfPageItem>[];
    final p = _p(local);
    final pageW = widget.page.width, pageH = widget.page.height;
    PdfPageItem? best;
    var bestArea = double.infinity;
    for (final it in items) {
      if (it.mark.startsWith('DO')) continue;
      // Sayfanın tamamını kaplayan arka plan/kırpma yolu seçilmez.
      if (it.isPath && it.width > pageW * 0.95 && it.height > pageH * 0.95) {
        continue;
      }
      final slop = 8 / _unit * _px;
      if (p.x < it.left - slop ||
          p.x > it.right + slop ||
          p.y < it.bottom - slop ||
          p.y > it.top + slop) {
        continue;
      }
      final area = math.max(1.0, it.width) * math.max(1.0, it.height);
      if (area < bestArea) {
        bestArea = area;
        best = it;
      }
    }
    return best;
  }

  // ── taşıma / boyutlandırma ─────────────────────────────────────────────
  /// Nesnenin taşıma tutamacı: üst kenarın ortası; nesne sayfayı kaplıyorsa
  /// (antetli kâğıt, taranmış sayfa) kenar ekran dışında kalabileceği için
  /// biraz içeride.
  Offset _gripAnchor(Rect r) => r.height > widget.pageSize.height * 0.6
      ? r.topCenter + const Offset(0, PdfEditTokens.gripHit)
      : r.topCenter;

  Future<void> _dropBlock(PdfTextBlock block) async {
    final d = _drag, w = _widthDrag;
    setState(() {
      _dragging = false;
      _drag = Offset.zero;
      _widthDrag = 0;
    });
    if (d.distance < 1.5 * _px && w.abs() < 1.5 * _px) return;
    try {
      // Çerçeve = sayfa (dik blok); döndürülmüş blokta taşıma çerçeveye çevrilir.
      final dxp = d.dx / _unit, dyp = -d.dy / _unit;
      final cs = math.cos(block.angle), sn = math.sin(block.angle);
      await c.reshape(pageIndex, block,
          dx: dxp * cs + dyp * sn,
          dy: -dxp * sn + dyp * cs,
          width: w == 0
              ? null
              : math.max(block.size * 3, block.frameWidth + w / _unit),
          label: w == 0 ? 'pse.step_move' : 'pse.step_resize');
    } catch (e) {
      widget.events.onRefused(e);
    }
  }

  Future<void> _dropItem(PdfPageItem item) async {
    final d = _drag, s = _scale;
    setState(() {
      _dragging = false;
      _drag = Offset.zero;
      _scale = 1;
    });
    if (d.distance < 1.5 * _px && (s - 1).abs() < 0.01) return;
    try {
      final List<double> m;
      if ((s - 1).abs() >= 0.01) {
        // Sol-üst köşe sabit, oran kilitli ölçek.
        final ax = item.left, ay = item.top;
        m = [s, 0, 0, s, ax - s * ax, ay - s * ay];
      } else {
        m = [1, 0, 0, 1, d.dx / _unit, -d.dy / _unit];
      }
      await c.mutate(pageIndex, [PdfMutAction.transform([item.index], m)],
          label: (s - 1).abs() >= 0.01 ? 'pse.step_resize' : 'pse.step_move');
    } catch (e) {
      widget.events.onRefused(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final live = _liveHere ? c.live : null;
        final blocks = c.blocksOf(pageIndex) ?? const <PdfTextBlock>[];
        final rects = _blockRects(blocks);
        final selected = c.selectedPage == pageIndex ? c.selectedBlock : null;
        final item = c.selectedPage == pageIndex ? c.selectedItem : null;
        final annot = c.selectedPage == pageIndex ? c.selectedAnnot : null;
        final tool = c.tool;
        final px = _px;

        final painter = _LayerPainter(
          rects: tool == PdfProTool.text && live == null ? rects : const [],
          locked: [for (final b in blocks) !b.editable],
          selected: live == null ? selected : null,
          accent: accent,
          pending: PdfEditTokens.pending(dark),
          px: px,
          drag: _dragging ? _drag : Offset.zero,
          widthDrag: _dragging ? _widthDrag : 0,
          itemRect: item == null
              ? null
              : _r(item.left, item.bottom, item.right, item.top),
          itemScale: _dragging ? _scale : 1,
          itemGrip: item == null
              ? null
              : _gripAnchor(_r(item.left, item.bottom, item.right, item.top)),
          onAccent: scheme.onPrimary,
          movable: selected != null &&
              selected < blocks.length &&
              blocks[selected].editable,
          annotRect: annot == null
              ? null
              : _r(annot.left, annot.bottom, annot.right, annot.top),
          live: live,
          toWidget: _w,
          caretOn: _caretOn,
          stroke: _stroke,
          strokeColor: c.markup == PdfMarkupKind.redact
              ? scheme.onSurface
              : Color(c.markupColor | 0xFF000000),
          strokeWidth: c.markupWidth * _unit,
          markFrom: _markFrom,
          markTo: _markTo,
          markRects: _markFrom != null && _markTo != null && _textMarkup
              ? [
                  for (final q in _quadsBetween(_markFrom!, _markTo!))
                    Rect.fromPoints(_w(q[0], q[1]), _w(q[6], q[7]))
                ]
              : const [],
          shape: _shapeMarkup ? c.markup : null,
        );

        final children = <Widget>[
          IgnorePointer(
              child: CustomPaint(size: widget.pageSize, painter: painter)),
        ];

        if (live == null && c.drawing) {
          // Çizim/işaretleme: tek parmak çizer (görüntüleyicide tek parmak
          // kaydırma bu sırada kapalı — `body.dart`), iki parmak yakınlaştırır.
          children.add(Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: _drawDown,
              onPointerMove: _drawMove,
              onPointerUp: _drawUp,
              onPointerCancel: (e) => _drawUp(e, cancel: true),
            ),
          ));
        } else {
          final bounds = live == null ? Rect.zero : _liveBounds(live);
          children
            ..add(_tapTarget(
              context,
              onTap: (at) {
                if (c.live != null) {
                  // Yazarken: dokun = imleç; bloğun dışı (ya da başka sayfa)
                  // = uygula.
                  if (live != null && bounds.contains(at)) {
                    _caretTo(at);
                  } else {
                    widget.events.onCommit();
                  }
                  return;
                }
                _tap(at, blocks, rects, selected);
              },
              onDoubleTap: (at) {
                if (c.live != null) {
                  if (live != null && bounds.contains(at)) {
                    _caretTo(at, word: true);
                  }
                  return;
                }
                if (tool != PdfProTool.text) return;
                final hit = hitPdfBlock(rects, at, slop: 6 * px);
                if (hit == null || c.busy) return;
                final b = blocks[hit];
                if (!b.editable) {
                  widget.events.onLocked(pageIndex, b);
                  return;
                }
                final pt = _p(at);
                final w = b.map.wordAt(b.map.offsetAt(pt.x, pt.y));
                widget.events.onEdit(pageIndex, b, selection: w);
              },
              onLongPress: (at) {
                if (c.live != null) {
                  // Uzun bas = sözcük; parmak kalkmadan sürükle = seçimi uzat.
                  if (live == null) return;
                  AppHaptics.selection();
                  _caretTo(at, word: true);
                  _extending = true;
                  return;
                }
                if (tool != PdfProTool.text) return;
                final hit = hitPdfBlock(rects, at, slop: 6 * px);
                if (hit == null) return;
                AppHaptics.selection();
                c.select(pageIndex, hit);
                widget.events.onBlockMenu(pageIndex, blocks[hit]);
              },
            ))
            ..add(Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerMove: (e) {
                  if (_extending && _liveHere) {
                    _caretTo(e.localPosition, extend: true);
                  }
                },
                onPointerUp: (_) => _extending = false,
                onPointerCancel: (_) => _extending = false,
              ),
            ));
        }

        // Tutamaçlar parmağı sahiplenir (yalnız kendi küçük alanlarında):
        // gövdeye dokunuş/sürükleme görüntüleyicide kalır — seçim açıkken de
        // sayfa kayar ve yakınlaşır.
        Widget grip(Offset center, double size,
                {required GestureDragUpdateCallback onUpdate,
                required VoidCallback onEnd,
                required VoidCallback onCancel,
                Key? key}) =>
            Positioned(
              key: key,
              left: center.dx - size / 2,
              top: center.dy - size / 2,
              width: size,
              height: size,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanStart: (_) => setState(() => _dragging = true),
                onPanUpdate: onUpdate,
                onPanEnd: (_) => onEnd(),
                onPanCancel: onCancel,
              ),
            );
        const hs = PdfEditTokens.gripHit;
        // Seçili blok: üst tutamaç = taşı; sağ tutamaç = genişlik.
        if (live == null &&
            tool == PdfProTool.text &&
            selected != null &&
            selected < blocks.length &&
            blocks[selected].editable &&
            !c.busy) {
          final b = blocks[selected];
          final r = rects[selected].inflate(2 * px);
          final d = _dragging ? _drag : Offset.zero;
          children
            ..add(grip(r.topCenter + d, hs,
                key: const ValueKey('pse-grip-move'),
                onUpdate: (e) => setState(() => _drag += e.delta),
                onEnd: () => _dropBlock(b),
                onCancel: () => setState(() {
                      _dragging = false;
                      _drag = Offset.zero;
                    })))
            ..add(grip(
                r.centerRight + d + Offset(_dragging ? _widthDrag : 0, 0), hs,
                key: const ValueKey('pse-grip-width'),
                onUpdate: (e) => setState(() => _widthDrag += e.delta.dx),
                onEnd: () => _dropBlock(b),
                onCancel: () => setState(() {
                      _dragging = false;
                      _widthDrag = 0;
                    })));
        }
        // Seçili nesne: üst tutamaç = taşı; sağ-alt köşe = ölçekle.
        if (live == null && item != null && !c.busy) {
          final r = _r(item.left, item.bottom, item.right, item.top);
          final d = _dragging ? _drag : Offset.zero;
          children
            ..add(grip(_gripAnchor(r) + d, hs,
                key: const ValueKey('pse-grip-item'),
                onUpdate: (e) => setState(() => _drag += e.delta),
                onEnd: () => _dropItem(item),
                onCancel: () => setState(() {
                      _dragging = false;
                      _drag = Offset.zero;
                    })))
            ..add(grip(
                Offset(r.left + r.width * _scale, r.top + r.height * _scale),
                hs,
                key: const ValueKey('pse-grip-scale'),
                onUpdate: (e) => setState(() {
                      final w = math.max(1.0, r.width);
                      _scale = ((w * _scale + e.delta.dx) / w).clamp(0.1, 8.0);
                    }),
                onEnd: () => _dropItem(item),
                onCancel: () => setState(() {
                      _dragging = false;
                      _scale = 1;
                    })));
        }
        return SizedBox.fromSize(
          size: widget.pageSize,
          child: Stack(clipBehavior: Clip.none, children: children),
        );
      },
    );
  }

  void _tap(Offset local, List<PdfTextBlock> blocks, List<Rect> rects,
      int? selected) {
    final px = _px;
    switch (c.tool) {
      case PdfProTool.text:
        final hit = hitPdfBlock(rects, local, slop: 6 * px);
        if (hit == null) {
          if (c.armTextBox) {
            final p = _p(local);
            widget.events.onTextBox(pageIndex, p.x, p.y);
          } else {
            c.clearSelection();
          }
        } else if (!blocks[hit].editable) {
          AppHaptics.selection();
          c.select(pageIndex, hit);
          widget.events.onLocked(pageIndex, blocks[hit]);
        } else if (hit == selected) {
          if (c.busy) return;
          final p = _p(local);
          widget.events.onEdit(pageIndex, blocks[hit],
              offset: blocks[hit].map.offsetAt(p.x, p.y));
        } else {
          AppHaptics.selection();
          c.select(pageIndex, hit);
        }
      case PdfProTool.markup:
        final a = _annotAt(local);
        if (c.markup == PdfMarkupKind.note && a == null) {
          final p = _p(local);
          widget.events.onNote(pageIndex, p.x, p.y);
        } else if (a != null) {
          AppHaptics.selection();
          if (c.markup == PdfMarkupKind.eraser) {
            c
                .annotate(PdfAnnotChange.remove(pageIndex, a.index),
                    label: 'pse.step_markup_remove')
                .catchError(widget.events.onRefused);
          } else {
            c.selectAnnot(pageIndex, a);
            widget.events.onAnnotTap(pageIndex, a);
          }
        } else if (c.markup == PdfMarkupKind.eraser) {
          // Dikdörtgen/ok sayfa içeriği (açıklama değil) — Silgi onu da siler
          // (cihaz 2026-11-13: yalnız Görsel aracıyla siliniyordu).
          final p = _p(local);
          final s = c.shapeAt(pageIndex, p.x, p.y, slop: 6 / _unit * _px);
          if (s == null) return c.clearSelection();
          AppHaptics.selection();
          c
              .mutate(pageIndex, [PdfMutAction.delete([s.index])],
                  label: 'pse.step_delete')
              .catchError(widget.events.onRefused);
        } else {
          c.clearSelection();
        }
      default:
        final it = _itemAt(local);
        if (it == null) {
          c.clearSelection();
        } else {
          AppHaptics.selection();
          c.selectItem(pageIndex, it);
        }
    }
  }
}

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/app_colors.dart';
import '../core/app_haptics.dart';
import '../core/app_icons.dart';
import '../services/pptx_render.dart';

/// Seçili şeklin **taşı / boyutlandır / döndür** katmanı (Faz 29).
///
/// Kanvas punto biriminde çizilir ve ekrana küçültülür; bu yüzden tutamak
/// boyutları dp'den punto'ya [unit] (= 1/ölçek) ile çevrilir. Sürükleme
/// hemen başlar (sürükleme eşiği 2 dp): dikey kaydırılan slayt listesine
/// kaptırmamak için. Bırakınca [onCommit] ile yeni çerçeve bildirilir; canlı
/// önizleme bu katmanın kendi durumudur.
///
/// **Hizalama kılavuzları** (Faz 29b): taşırken kutunun sol/orta/sağ ve
/// üst/orta/alt çizgileri slaytın kenar/merkezine ve [others]'ın kenar/
/// merkezlerine 6 dp yakınlıkta yaslanır; yaslanan çizgi çizilir, yeni bir
/// yaslanmada hafif titreşim verilir. Donmuş (döndürülmüş) şekil yaslanmaz.
/// Donanım klavyesinde oklar 1 pt (⇧ ile 10 pt) iter.
class SlideFrameEditor extends StatefulWidget {
  final ShapeVM shape;
  final Widget child;

  /// 1 dp'nin punto karşılığı.
  final double unit;
  final double slideW, slideH;
  final void Function(Rect frame, double rotationDeg) onCommit;

  /// Slayttaki diğer şekillerin çerçeveleri (pt) — kılavuz hedefleri.
  final List<Rect> others;

  const SlideFrameEditor({
    super.key,
    required this.shape,
    required this.child,
    required this.unit,
    required this.slideW,
    required this.slideH,
    required this.onCommit,
    this.others = const [],
  });

  /// Yaslanma hedefleri: slaytın kenar + merkezi ve diğer şekillerinki.
  @visibleForTesting
  static Rect snapRect(Rect r, double slideW, double slideH, List<Rect> others,
      double threshold, void Function(double? gx, double? gy) guides) {
    final xs = <double>[0, slideW / 2, slideW];
    final ys = <double>[0, slideH / 2, slideH];
    for (final o in others) {
      xs.addAll([o.left, o.center.dx, o.right]);
      ys.addAll([o.top, o.center.dy, o.bottom]);
    }
    final sx = _SlideFrameEditorState._snap([r.left, r.center.dx, r.right], xs, threshold);
    final sy = _SlideFrameEditorState._snap([r.top, r.center.dy, r.bottom], ys, threshold);
    guides(sx?.$2, sy?.$2);
    return r.shift(Offset(sx?.$1 ?? 0, sy?.$1 ?? 0));
  }

  @override
  State<SlideFrameEditor> createState() => _SlideFrameEditorState();
}

class _SlideFrameEditorState extends State<SlideFrameEditor> {
  late Rect _rect;
  late double _rot;

  /// Taşımada yaslanmamış (parmağın götürdüğü) çerçeve; [_rect] bunun
  /// kılavuzlara yaslanmış hâli.
  Rect? _raw;

  /// Etkin kılavuz çizgileri (pt; dikey çizgilerin x'i, yatayların y'si).
  double? _guideX, _guideY;
  final FocusNode _keys = FocusNode(debugLabel: 'slide-frame');

  static const _minSize = 12.0;

  @override
  void initState() {
    super.initState();
    _reset();
  }

  @override
  void didUpdateWidget(SlideFrameEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.shape, widget.shape)) _reset();
  }

  void _reset() {
    final s = widget.shape;
    _rect = Rect.fromLTWH(s.x, s.y, s.w, s.h);
    _rot = s.rotationDeg;
  }

  bool get _isLine => widget.shape.isLine;
  bool get _lockRatio => widget.shape.image != null;

  @override
  void dispose() {
    _keys.dispose();
    super.dispose();
  }

  void _commit() {
    _raw = null;
    if (_guideX != null || _guideY != null) {
      setState(() => _guideX = _guideY = null);
    }
    widget.onCommit(_rect, _rot);
  }

  /// [cands] (kutunun üç çizgisi) içinden [targets]'a en yakın olanın farkı;
  /// [thr] içinde değilse null. (fark, kılavuz konumu)
  static (double, double)? _snap(List<double> cands, List<double> targets, double thr) {
    (double, double)? best;
    for (final c in cands) {
      for (final t in targets) {
        final d = t - c;
        if (d.abs() <= thr && (best == null || d.abs() < best.$1.abs())) {
          best = (d, t);
        }
      }
    }
    return best;
  }

  KeyEventResult _onKey(FocusNode _, KeyEvent e) {
    if (e is! KeyDownEvent && e is! KeyRepeatEvent) return KeyEventResult.ignored;
    final step = HardwareKeyboard.instance.isShiftPressed ? 10.0 : 1.0;
    final d = switch (e.logicalKey) {
      LogicalKeyboardKey.arrowLeft => Offset(-step, 0),
      LogicalKeyboardKey.arrowRight => Offset(step, 0),
      LogicalKeyboardKey.arrowUp => Offset(0, -step),
      LogicalKeyboardKey.arrowDown => Offset(0, step),
      _ => null,
    };
    if (d == null) return KeyEventResult.ignored;
    setState(() => _rect = _rect.shift(d));
    _commit();
    return KeyEventResult.handled;
  }

  Map<Type, GestureRecognizerFactory> _pan(
          {required void Function(DragUpdateDetails) onUpdate,
          void Function(DragStartDetails)? onStart}) =>
      {
        PanGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<PanGestureRecognizer>(
          PanGestureRecognizer.new,
          (r) {
            // Eşik 2 dp: dikey kaydırma yarışını kazanır, dokunuş (seç/düzenle)
            // ise hareketsiz kaldığı için etkilenmez.
            r.gestureSettings = const DeviceGestureSettings(touchSlop: 1);
            r
              ..onStart = onStart
              ..onUpdate = onUpdate
              ..onEnd = (_) => _commit();
          },
        ),
      };

  void _move(Offset d) {
    setState(() {
      var r = (_raw ?? _rect).shift(d);
      r = r.shift(Offset(
        r.left < -r.width + 8 ? -r.width + 8 - r.left : 0,
        r.top < -r.height + 8 ? -r.height + 8 - r.top : 0,
      ));
      _raw = r;
      if (_rot % 360 != 0) {
        _rect = r;
        return;
      }
      final hadX = _guideX, hadY = _guideY;
      _rect = SlideFrameEditor.snapRect(r, widget.slideW, widget.slideH, widget.others,
          6 * widget.unit, (gx, gy) {
        _guideX = gx;
        _guideY = gy;
      });
      if ((_guideX != null && _guideX != hadX) ||
          (_guideY != null && _guideY != hadY)) {
        AppHaptics.selection();
      }
    });
  }

  /// Tutamak ([hx], [hy]) ∈ {-1,0,1}: -1 sol/üst kenar, 1 sağ/alt kenar.
  void _resize(int hx, int hy, Offset d) {
    setState(() {
      var l = _rect.left, t = _rect.top, r = _rect.right, b = _rect.bottom;
      if (hx < 0) l += d.dx;
      if (hx > 0) r += d.dx;
      if (hy < 0) t += d.dy;
      if (hy > 0) b += d.dy;
      if (r - l < _minSize) {
        if (hx < 0) {
          l = r - _minSize;
        } else {
          r = l + _minSize;
        }
      }
      if (b - t < _minSize) {
        if (hy < 0) {
          t = b - _minSize;
        } else {
          b = t + _minSize;
        }
      }
      if (_lockRatio && hx != 0 && hy != 0) {
        final ratio = widget.shape.w / math.max(widget.shape.h, 1);
        final w = r - l;
        final h = w / ratio;
        if (hy < 0) {
          t = b - h;
        } else {
          b = t + h;
        }
      }
      _rect = Rect.fromLTRB(l, t, r, b);
    });
  }

  void _rotate(Offset localInFrame) {
    final c = Offset(_rect.width / 2, _rect.height / 2);
    final v = localInFrame - c;
    if (v.distance < 1) return;
    // Çerçeve zaten dönmüş: "yukarı" eksenine göre kalan açı.
    final delta = math.atan2(v.dx, -v.dy) * 180 / math.pi;
    setState(() {
      var r = _rot + delta;
      final snapped = (r / 15).round() * 15.0;
      if ((r - snapped).abs() < 3) r = snapped;
      _rot = ((r % 360) + 360) % 360;
    });
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.unit;
    // Dokunma alanı 40 dp; ama kutunun ortası (seç/düzenle dokunuşu) her
    // zaman serbest kalsın diye kısa kenarın üçte biriyle sınırlı.
    final hit = math.max(
        14 * u, math.min(40 * u, math.min(_rect.width, _rect.height) / 3));
    final dot = 7 * u;
    final rotated = _rot % 360 != 0;
    // Tutamak dokunma kutusu kenarın DIŞINA taşar, içeri yalnız 4 dp girer:
    // kutunun içindeki dokunuşlar (seç / düzenle) tutamağa takılmasın.
    final inset = 4 * u;
    (double, double) span(int h, double size) => switch (h) {
          -1 => (-(hit - inset), hit),
          1 => (size - inset, hit),
          _ => (size / 2 - hit / 2, hit),
        };
    Widget handle(int hx, int hy) {
      final (left, w) = span(hx, _rect.width);
      final (top, h) = span(hy, _rect.height);
      final cx = _rect.width * (hx + 1) / 2 - left;
      final cy = _rect.height * (hy + 1) / 2 - top;
      return Positioned(
        left: left,
        top: top,
        width: w,
        height: h,
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: _pan(onUpdate: (d) => _resize(hx, hy, d.delta)),
          child: Stack(children: [
            Positioned(
              left: cx - dot,
              top: cy - dot,
              child: Container(
                width: dot * 2,
                height: dot * 2,
                decoration: BoxDecoration(
                  color: AppColors.page,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.slideSelection, width: 1.5 * u),
                ),
              ),
            ),
          ]),
        ),
      );
    }

    final body = SizedBox(
      width: _rect.width,
      height: _rect.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: RawGestureDetector(
              behavior: HitTestBehavior.translucent,
              gestures: _pan(onUpdate: (d) => _move(d.delta)),
              child: CustomPaint(
                foregroundPainter: _FramePainter(u),
                child: widget.child,
              ),
            ),
          ),
          if (_guideX != null || _guideY != null)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  key: const ValueKey('slide-guides'),
                  painter: _GuidePainter(
                    unit: u,
                    origin: _rect.topLeft,
                    slide: Size(widget.slideW, widget.slideH),
                    x: _guideX,
                    y: _guideY,
                  ),
                ),
              ),
            ),
          if (!_isLine && !rotated)
            for (final hx in const [-1, 0, 1])
              for (final hy in const [-1, 0, 1])
                if (!(hx == 0 && hy == 0)) handle(hx, hy),
          if (!_isLine)
            Positioned(
              left: _rect.width / 2 - hit / 2,
              top: -hit - 4 * u,
              width: hit,
              height: hit,
              child: RawGestureDetector(
                behavior: HitTestBehavior.opaque,
                gestures: _pan(
                    onUpdate: (d) => _rotate(Offset(
                        _rect.width / 2 - hit / 2 + d.localPosition.dx,
                        -hit - 4 * u + d.localPosition.dy))),
                child: Center(
                  child: Icon(AppIcons.rotateRight,
                      size: dot * 3.2, color: AppColors.slideSelection),
                ),
              ),
            ),
        ],
      ),
    );
    return Positioned(
      left: _rect.left,
      top: _rect.top,
      width: math.max(_rect.width, _isLine ? 1 : 0),
      height: math.max(_rect.height, _isLine ? 1 : 0),
      child: Focus(
        focusNode: _keys,
        autofocus: true,
        onKeyEvent: _onKey,
        child: Transform.rotate(
        angle: _rot * math.pi / 180,
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: 0,
          minHeight: 0,
          maxWidth: _rect.width,
          maxHeight: _rect.height,
          child: body,
        ),
      ),
      ),
    );
  }
}

/// Hizalama kılavuzları: çerçeve katmanının içinden, slayt boyunca çizilir
/// ([origin] = kutunun slayttaki sol üstü).
class _GuidePainter extends CustomPainter {
  final double unit;
  final Offset origin;
  final Size slide;
  final double? x, y;
  const _GuidePainter(
      {required this.unit, required this.origin, required this.slide, this.x, this.y});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.slideGuide
      ..strokeWidth = 1 * unit;
    if (x != null) {
      final gx = x! - origin.dx;
      canvas.drawLine(Offset(gx, -origin.dy), Offset(gx, slide.height - origin.dy), p);
    }
    if (y != null) {
      final gy = y! - origin.dy;
      canvas.drawLine(Offset(-origin.dx, gy), Offset(slide.width - origin.dx, gy), p);
    }
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.x != x || old.y != y || old.origin != origin || old.unit != unit;
}

class _FramePainter extends CustomPainter {
  final double unit;
  const _FramePainter(this.unit);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..color = AppColors.slideSelection
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5 * unit);
  }

  @override
  bool shouldRepaint(_FramePainter old) => old.unit != unit;
}

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/edit/edit_history.dart';
import '../core/edit/edit_session.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart' show OverlayBar;
import '../core/user_error.dart';
import '../models/media_resize.dart' show aspectChoices, longEdgeChoices;
import '../services/image_edit.dart';
import '../widgets/app_dialog.dart';

/// **Görsel düzenleyici** (Faz 10, N7; Faz 32 "2.0"). Kırp (oran ön ayarlı,
/// serbest açı, dikey/yatay çevir) · 11 ayar · 10 filtre · işaretle (kalem,
/// vurgulayıcı, silgi, şekiller, taşınabilir yazı, bulanıklaştır/
/// pikselleştir) · boyut (Faz 14b: kırp → boyut → kaydet tek akış).
/// Kanvas iki parmakla yakınlaşır (düzenlerken de), çift dokunuş sığdırır.
/// Kaydetme varsayılanı KOPYA; özgüne dokunmak ayrı ve açık bir seçim.
/// Çizim ve kayıt `services/image_edit.dart`taki tek yoldan geçer.
class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({super.key, required this.path});

  final String path;

  /// Testler için son çizilen düzenleme (yalnız hata ayıklama kipinde).
  @visibleForTesting
  static ImageEdits? debugEdits;

  /// Kaydedilen dosyanın yolunu döndürür (iptalde null).
  static Future<String?> open(BuildContext context, String path) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ImageEditScreen(path: path)),
      );

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

enum _Tab { crop, adjust, filter, markup, size }

/// İşaretleme aracı; [MarkKind] dışındakiler: seç ve silgi.
enum _Tool {
  select,
  pen,
  highlighter,
  eraser,
  arrow,
  line,
  rect,
  ellipse,
  text,
  blur,
  pixelate,
}

enum _SelDrag { none, move, scale, rotate }

enum _Drag { none, move, tl, tr, br, bl }

class _ImageEditScreenState extends State<ImageEditScreen> {
  ui.Image? _src;
  Object? _error;
  ImageEdits _e = const ImageEdits();
  /// Faz 20 / IM4: bütün yollar tek geçmişten (sınır 30) — yinele dahil.
  final _history = SnapshotHistory<ImageEdits>(limit: 30);
  _Tab _tab = _Tab.crop;
  double? _ratio; // genişlik/yükseklik (piksel); null = serbest
  String _ratioKey = 'ied.free';

  /// Basılı tutulan "özgünü gör" düğmesi (Faz 14b): düzenlemesiz hâl.
  bool _showOriginal = false;
  final _widthCtl = TextEditingController();
  final _heightCtl = TextEditingController();
  _Tool _tool = _Tool.pen;
  Color _color = const Color(0xFFE53935);
  double _stroke = 0.012; // kısa kenara oranlı kalınlık
  double _opacity = 1;
  _Drag _drag = _Drag.none;
  bool _saving = false;

  /// Faz 32 (IM2): çizilen işaret setState'siz büyür; yalnız canlı katman
  /// [_liveTick] ile yeniden boyanır.
  ImageMark? _live;
  final _liveTick = ValueNotifier<int>(0);

  /// Seçili işaret (taşı / boyutlandır / döndür / düzenle / sil).
  int? _sel;
  _SelDrag _selDrag = _SelDrag.none;
  ImageMark? _selOrig;
  Offset _selStart = Offset.zero;

  /// Sürükleme başındaki hâl — bitince değiştiyse TEK geçmiş adımı.
  ImageEdits? _before;

  /// Ayarla sekmesinde seçili ayar.
  String _adjustKey = 'brightness';
  bool _straightening = false;

  // Faz 32 (IM1): ekran boyunda vekil; keskinlik önizlemesi vekilden.
  ui.Image? _proxy, _thumb, _sharp;
  double _sharpFor = 0;
  bool _sharpBusy = false;

  // Kanvas görünümü (iki parmakla yakınlaştır/kaydır).
  double _vs = 1;
  Offset _vo = Offset.zero;
  bool _viewGesture = false;
  double _vsStart = 1;
  Offset _voStart = Offset.zero, _focalStart = Offset.zero;
  Size _avail = Size.zero;

  // Son yerleşim (jest → normalleştirilmiş koordinat çevirisi için).
  Rect _box = Rect.zero;

  /// Kırpma oranları — boyutlandırma levhasıyla AYNI liste (Faz 14b, G4i).
  /// "Orijinal" ve "Özel" ayrı ele alınır ([_setRatioKey]).
  static final _ratios = <(String, double?)>[
    ('ied.free', null),
    ('ied.original', null),
    for (final (label, w, h) in aspectChoices) (label, w / h),
    ('ied.custom_ratio', null),
  ];
  static const _adjustKeys = [
    'brightness',
    'contrast',
    'saturation',
    'exposure',
    'temperature',
    'tint',
    'highlights',
    'shadows',
    'vibrance',
    'sharpness',
    'vignette',
  ];
  static const _colors = [
    Color(0xFFE53935),
    Color(0xFFFFEB3B),
    Color(0xFF43A047),
    Color(0xFF1E88E5),
    Color(0xFFFFFFFF),
    Color(0xFF000000),
  ];

  @override
  void initState() {
    super.initState();
    loadEditableImage(widget.path).then((im) {
      if (!mounted) return im.dispose();
      setState(() => _src = im);
      _makeProxies(im);
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  Future<void> _makeProxies(ui.Image im) async {
    final view = MediaQuery.sizeOf(context) * MediaQuery.devicePixelRatioOf(context);
    final side = math.max(view.longestSide, 1024).clamp(1024, 2560).round();
    final proxy = await previewProxy(im, maxSide: side);
    final thumb = await previewProxy(proxy ?? im, maxSide: 160);
    if (!mounted) {
      proxy?.dispose();
      thumb?.dispose();
      return;
    }
    setState(() {
      _proxy = proxy;
      _thumb = thumb;
    });
  }

  /// Önizlemede çizilen görsel: (keskinleştirilmiş) vekil ya da özgün.
  ui.Image get _view =>
      (_e.sharpness > 0 && !_showOriginal ? _sharp : null) ?? _proxy ?? _src!;

  /// Keskinlik değiştiyse vekilin keskin kopyası arka planda yenilenir.
  void _ensureSharp() {
    final want = _e.sharpness;
    if (want == 0 || want == _sharpFor || _sharpBusy) return;
    _sharpBusy = true;
    sharpened(_proxy ?? _src!, want).then((im) {
      _sharpBusy = false;
      if (!mounted) return im.dispose();
      setState(() {
        _sharp?.dispose();
        _sharp = im;
        _sharpFor = want;
      });
    }, onError: (_) => _sharpBusy = false);
  }

  @override
  void dispose() {
    _src?.dispose();
    _proxy?.dispose();
    _thumb?.dispose();
    _sharp?.dispose();
    _liveTick.dispose();
    _widthCtl.dispose();
    _heightCtl.dispose();
    super.dispose();
  }

  void _push(ImageEdits next) {
    _history.push(_e);
    setState(() => _e = next);
  }

  Size get _full => orientedSize(_src!, _e);

  // ── yerleşim ──────────────────────────────────────────────────────────────

  /// Görünen bölge (kırpma kipinde tüm görsel, diğerlerinde kırpılmış hâl)
  /// [avail] içine sığdırılır; dönen: tüm yönlendirilmiş görselin tuvaldeki
  /// kutusu ve görünen bölgenin ekrandaki dikdörtgeni.
  (Rect, Rect) _layout(Size avail) {
    final whole = _tab == _Tab.crop || _showOriginal;
    final full = _showOriginal
        ? Size(_src!.width.toDouble(), _src!.height.toDouble())
        : _full;
    final region = whole ? const Rect.fromLTWH(0, 0, 1, 1) : _e.crop;
    final rw = region.width * full.width, rh = region.height * full.height;
    final pad = _tab == _Tab.crop ? 28.0 : 12.0;
    final s = math.min((avail.width - 2 * pad) / rw, (avail.height - 2 * pad) / rh);
    final visible = Rect.fromCenter(
        center: avail.center(Offset.zero), width: rw * s, height: rh * s);
    final box = Rect.fromLTWH(
      visible.left - region.left * full.width * s,
      visible.top - region.top * full.height * s,
      full.width * s,
      full.height * s,
    );
    if (_vs == 1 && _vo == Offset.zero) return (box, visible);
    final c = avail.center(Offset.zero);
    Rect view(Rect r) => Rect.fromLTRB(
          c.dx + (r.left - c.dx) * _vs + _vo.dx,
          c.dy + (r.top - c.dy) * _vs + _vo.dy,
          c.dx + (r.right - c.dx) * _vs + _vo.dx,
          c.dy + (r.bottom - c.dy) * _vs + _vo.dy,
        );
    return (view(box), view(visible).intersect(Offset.zero & avail));
  }

  Offset _norm(Offset local) => Offset(
        ((local.dx - _box.left) / _box.width).clamp(0.0, 1.0),
        ((local.dy - _box.top) / _box.height).clamp(0.0, 1.0),
      );

  Rect _cropOnScreen() => Rect.fromLTRB(
        _box.left + _e.crop.left * _box.width,
        _box.top + _e.crop.top * _box.height,
        _box.left + _e.crop.right * _box.width,
        _box.top + _e.crop.bottom * _box.height,
      );

  /// Kırpma kutusundaki canlı ölçü etiketi ("1080 × 1350").
  String _cropLabel() {
    final c = croppedSize(_src!, _e);
    return '${c.width.round()} × ${c.height.round()}';
  }

  // ── boyut (Faz 14b) ─────────────────────────────────────────────────────────

  void _syncSizeFields() {
    final out = outputSize(_src!, _e);
    _widthCtl.text = '${out.width.round()}';
    _heightCtl.text = '${out.height.round()}';
  }

  void _setScale(double scale) {
    final cropped = croppedSize(_src!, _e);
    // En az 16 px kısa kenar; büyütme yok (netlik katmaz, boyutlandırma
    // levhasında %100 üstü uyarılı ayrı yol).
    final minScale = 16 / math.min(cropped.width, cropped.height);
    final clamped = scale.clamp(math.min(minScale, 1.0), 1.0).toDouble();
    if ((clamped - _e.scale).abs() < 1e-6) {
      _syncSizeFields();
      return;
    }
    _push(_e.copyWith(scale: clamped));
    _syncSizeFields();
  }

  void _readSizeField(bool width) {
    final v = int.tryParse((width ? _widthCtl : _heightCtl).text.trim());
    if (v == null || v <= 0) return;
    final cropped = croppedSize(_src!, _e);
    final scale = v / (width ? cropped.width : cropped.height);
    final clamped = scale.clamp(0.0, 1.0);
    _history.push(_e);
    setState(() => _e = _e.copyWith(scale: clamped));
    // Oran hep kilitli: öteki alan anında hesaplanır.
    final out = outputSize(_src!, _e);
    (width ? _heightCtl : _widthCtl).text =
        '${(width ? out.height : out.width).round()}';
  }

  Widget _sizePanel() {
    final cropped = croppedSize(_src!, _e);
    final out = outputSize(_src!, _e);
    final longSide = math.max(cropped.width, cropped.height);
    const soft = TextStyle(color: AppColors.onMediaSoft);
    InputDecoration deco(String key) => InputDecoration(
          labelText: context.t(key),
          labelStyle: soft,
          isDense: true,
          border: const OutlineInputBorder(),
          enabledBorder: const OutlineInputBorder(
              borderSide: BorderSide(color: AppColors.onMediaFaint)),
        );
    Widget chip(String label, double scale, {Key? key}) => Padding(
          padding: const EdgeInsets.symmetric(horizontal: 3),
          child: ChoiceChip(
            key: key,
            label: Text(label),
            selected: (_e.scale - scale).abs() < 0.002,
            onSelected: (_) => _setScale(scale),
          ),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text(
        context.t('ied.size_now', {
          'from': '${cropped.width.round()} × ${cropped.height.round()}',
          'to': '${out.width.round()} × ${out.height.round()}',
        }),
        style: soft,
      ),
      const SizedBox(height: 6),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          chip(context.t('ied.size_original'), 1),
          for (final p in const [75, 50, 25]) chip('%$p', p / 100),
          for (final edge in longEdgeChoices.reversed)
            if (edge < longSide)
              chip('$edge px', edge / longSide, key: ValueKey('edge-$edge')),
        ]),
      ),
      const SizedBox(height: 8),
      Row(children: [
        Expanded(
          child: TextField(
            key: const ValueKey('ied-width'),
            controller: _widthCtl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onMedia),
            decoration: deco('rs.width'),
            onChanged: (_) => _readSizeField(true),
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(AppIcons.link, color: AppColors.onMediaSoft),
        ),
        Expanded(
          child: TextField(
            key: const ValueKey('ied-height'),
            controller: _heightCtl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: AppColors.onMedia),
            decoration: deco('rs.height'),
            onChanged: (_) => _readSizeField(false),
          ),
        ),
      ]),
      const SizedBox(height: 4),
    ]);
  }

  // ── kırpma ────────────────────────────────────────────────────────────────

  void _cropStart(Offset local) {
    final r = _cropOnScreen();
    final corners = {
      _Drag.tl: r.topLeft,
      _Drag.tr: r.topRight,
      _Drag.br: r.bottomRight,
      _Drag.bl: r.bottomLeft,
    };
    _drag = _Drag.none;
    var best = 40.0; // dokunma yarıçapı (dp)
    corners.forEach((k, o) {
      final d = (o - local).distance;
      if (d < best) {
        best = d;
        _drag = k;
      }
    });
    if (_drag == _Drag.none && r.contains(local)) _drag = _Drag.move;
    if (_drag != _Drag.none) _history.push(_e);
  }

  void _cropUpdate(Offset local, Offset delta) {
    if (_drag == _Drag.none) return;
    final c = _e.crop;
    final d = Offset(delta.dx / _box.width, delta.dy / _box.height);
    Rect next;
    if (_drag == _Drag.move) {
      final dx = d.dx.clamp(-c.left, 1 - c.right);
      final dy = d.dy.clamp(-c.top, 1 - c.bottom);
      next = c.shift(Offset(dx, dy));
    } else {
      const minSide = 0.05;
      final n = _norm(local);
      var l = c.left, t = c.top, r = c.right, b = c.bottom;
      switch (_drag) {
        case _Drag.tl:
          l = math.min(n.dx, r - minSide);
          t = math.min(n.dy, b - minSide);
        case _Drag.tr:
          r = math.max(n.dx, l + minSide);
          t = math.min(n.dy, b - minSide);
        case _Drag.br:
          r = math.max(n.dx, l + minSide);
          b = math.max(n.dy, t + minSide);
        case _Drag.bl:
          l = math.min(n.dx, r - minSide);
          b = math.max(n.dy, t + minSide);
        default:
      }
      next = Rect.fromLTRB(l, t, r, b);
      if (_ratio != null) next = _fitRatio(next, _drag);
    }
    setState(() => _e = _e.copyWith(crop: next));
  }

  /// [r]'nin yüksekliğini orana göre düzeltir; sürüklenmeyen kenar sabit.
  Rect _fitRatio(Rect r, _Drag anchor) {
    final ratio = _ratio!;
    var w = r.width;
    var h = w * _full.width / (_full.height * ratio);
    final top = anchor == _Drag.tl || anchor == _Drag.tr;
    final maxH = top ? r.bottom : 1 - r.top;
    if (h > maxH) {
      h = maxH;
      w = h * _full.height * ratio / _full.width;
    }
    final left = anchor == _Drag.tl || anchor == _Drag.bl;
    return Rect.fromLTWH(
      left ? r.right - w : r.left,
      top ? r.bottom - h : r.top,
      w,
      h,
    );
  }

  /// Oran çipi seçildi. "Orijinal" görselin kendi oranı, "Özel" a:b sorar.
  Future<void> _setRatioKey(String key, double? ratio) async {
    if (key == 'ied.original') {
      ratio = _full.width / _full.height;
    } else if (key == 'ied.custom_ratio') {
      final text = await showAppPrompt(context,
          title: context.t('ied.custom_ratio'),
          label: context.t('ied.ratio_hint'),
          initial: '4:5');
      if (text == null || !mounted) return;
      final parts = text.replaceAll(',', '.').split(RegExp(r'[:x×/ ]+'));
      final a = parts.isNotEmpty ? double.tryParse(parts.first) : null;
      final b = parts.length > 1 ? double.tryParse(parts[1]) : null;
      if (a == null || b == null || a <= 0 || b <= 0) {
        showSnack(context, context.t('ied.ratio_invalid'));
        return;
      }
      ratio = a / b;
    }
    setState(() => _ratioKey = key);
    _setRatio(ratio);
  }

  void _setRatio(double? ratio) {
    setState(() => _ratio = ratio);
    if (ratio == null) return;
    // Var olan kırpmanın ortasına sığan en büyük oranlı dikdörtgen.
    final c = _e.crop;
    final pw = c.width * _full.width, ph = c.height * _full.height;
    var w = pw, h = pw / ratio;
    if (h > ph) {
      h = ph;
      w = ph * ratio;
    }
    _push(_e.copyWith(
      crop: Rect.fromCenter(
        center: c.center,
        width: w / _full.width,
        height: h / _full.height,
      ),
    ));
  }

  // ── işaretleme ────────────────────────────────────────────────────────────

  MarkKind? get _kind => switch (_tool) {
        _Tool.select || _Tool.eraser => null,
        _Tool.pen => MarkKind.pen,
        _Tool.highlighter => MarkKind.highlighter,
        _Tool.arrow => MarkKind.arrow,
        _Tool.line => MarkKind.line,
        _Tool.rect => MarkKind.rect,
        _Tool.ellipse => MarkKind.ellipse,
        _Tool.text => MarkKind.text,
        _Tool.blur => MarkKind.blur,
        _Tool.pixelate => MarkKind.pixelate,
      };

  /// Araca göre kalınlık: fırçalar ve vurgulayıcı kalemden kalın.
  double _sizeFor(MarkKind k) => switch (k) {
        MarkKind.blur || MarkKind.pixelate => _stroke * 5,
        MarkKind.highlighter => _stroke * 2.5,
        _ => _stroke,
      };

  ImageMark? get _selected =>
      _sel != null && _sel! < _e.marks.length ? _e.marks[_sel!] : null;

  /// Seçili işaretin tutamakları (ekran): boyut (sağ alt), döndür (üst, yazı).
  (Offset, Offset?) _handles(ImageMark m) {
    final r = markBounds(m, _box);
    Offset rot(Offset o) {
      if (m.kind != MarkKind.text || m.rotation == 0) return o;
      final d = o - r.center;
      final c = math.cos(m.rotation), s = math.sin(m.rotation);
      return r.center + Offset(d.dx * c - d.dy * s, d.dx * s + d.dy * c);
    }

    return (
      rot(r.bottomRight),
      m.kind == MarkKind.text ? rot(r.topCenter - const Offset(0, 28)) : null,
    );
  }

  void _replaceSelected(ImageMark m) {
    final marks = [..._e.marks];
    marks[_sel!] = m;
    setState(() => _e = _e.copyWith(marks: marks));
  }

  /// Sürükleme bittiğinde: değiştiyse başlangıç hâli tek geri al adımı.
  void _commitDrag() {
    final before = _before;
    _before = null;
    if (before != null && !identical(before, _e)) {
      _history.push(before);
      setState(() {});
    }
  }

  void _markStart(Offset local) {
    final sel = _selected;
    if (sel != null) {
      final (scale, rotate) = _handles(sel);
      // Küçük yazıda tutamak ortaya yakın: ortaya daha yakınsa taşı.
      final center = markBounds(sel, _box).center;
      final ds = (local - scale).distance;
      _selDrag = ds < 28 && ds < (local - center).distance
          ? _SelDrag.scale
          : rotate != null && (local - rotate).distance < 28
              ? _SelDrag.rotate
              : hitMark([sel], _box, local) != null
                  ? _SelDrag.move
                  : _SelDrag.none;
      if (_selDrag != _SelDrag.none) {
        _before = _e;
        _selOrig = sel;
        _selStart = local;
        return;
      }
    }
    if (_tool == _Tool.select || _tool == _Tool.text) {
      final hit = hitMark(_e.marks, _box, local);
      setState(() => _sel = hit);
      if (hit != null) {
        _before = _e;
        _selDrag = _SelDrag.move;
        _selOrig = _e.marks[hit];
        _selStart = local;
      }
      return;
    }
    setState(() => _sel = null);
    if (_tool == _Tool.eraser) {
      _before = _e;
      _erase(local);
      return;
    }
    final kind = _kind!;
    final n = _norm(local);
    _live = ImageMark(
      kind: kind,
      points: kind == MarkKind.arrow ||
              kind == MarkKind.line ||
              kind == MarkKind.rect ||
              kind == MarkKind.ellipse
          ? [n, n]
          : [n],
      color: _color,
      size: _sizeFor(kind),
      opacity: kind == MarkKind.highlighter ? _opacity * 0.45 : _opacity,
    );
    _liveTick.value++;
  }

  void _markUpdate(Offset local) {
    if (_selDrag != _SelDrag.none) return _selUpdate(local);
    if (_tool == _Tool.eraser) return _erase(local);
    final d = _live;
    if (d == null) return;
    // Nokta listesi yerinde büyür (IM2: kopya yok, setState yok).
    if (d.isShape) {
      d.points[1] = _norm(local);
    } else {
      d.points.add(_norm(local));
    }
    _liveTick.value++;
  }

  void _markEnd() {
    if (_selDrag != _SelDrag.none || _tool == _Tool.eraser) {
      _selDrag = _SelDrag.none;
      return _commitDrag();
    }
    final d = _live;
    _live = null;
    _liveTick.value++;
    if (d != null) {
      _push(_e.copyWith(
          marks: [..._e.marks, d.copyWith(points: List.of(d.points))]));
    }
  }

  /// İki parmak dokununca yarım kalan çizim/sürükleme geri alınır.
  void _cancelTool() {
    if (_live != null) {
      _live = null;
      _liveTick.value++;
    }
    if (_before != null) setState(() => _e = _before!);
    _before = null;
    _selDrag = _SelDrag.none;
    _drag = _Drag.none;
  }

  void _selUpdate(Offset local) {
    final o = _selOrig!;
    final r = markBounds(o, _box);
    switch (_selDrag) {
      case _SelDrag.move:
        final d = local - _selStart;
        _replaceSelected(
            o.shifted(Offset(d.dx / _box.width, d.dy / _box.height)));
      case _SelDrag.scale:
        final k = ((local - r.center).distance /
                math.max(1, (_selStart - r.center).distance))
            .clamp(0.2, 8.0);
        if (o.kind == MarkKind.text) {
          _replaceSelected(o.copyWith(size: (o.size * k).clamp(0.004, 0.4)));
        } else {
          final c = _norm(r.center);
          _replaceSelected(o.copyWith(
              points: [for (final p in o.points) c + (p - c) * k]));
        }
      case _SelDrag.rotate:
        final d = local - r.center;
        var a = math.atan2(d.dy, d.dx) + math.pi / 2;
        // 0/90/180/270'e yakınsa yapışır.
        final snap = (a / (math.pi / 2)).roundToDouble() * (math.pi / 2);
        if ((a - snap).abs() < 0.06) a = snap;
        _replaceSelected(o.copyWith(rotation: a));
      case _SelDrag.none:
    }
  }

  void _erase(Offset local) {
    final hit = hitMark(_e.marks, _box, local, slop: 6);
    if (hit == null) return;
    setState(() => _e = _e.copyWith(marks: [..._e.marks]..removeAt(hit)));
  }

  void _markTap(Offset local) {
    final hit = hitMark(_e.marks, _box, local);
    if (_tool == _Tool.text) {
      if (hit != null && _e.marks[hit].kind == MarkKind.text) {
        if (_sel == hit) {
          _editText();
        } else {
          setState(() => _sel = hit);
        }
        return;
      }
      _addText(local);
      return;
    }
    if (_tool == _Tool.select || hit != null && _sel != null) {
      setState(() => _sel = hit);
    } else if (_sel != null) {
      setState(() => _sel = null);
    }
  }

  Future<String?> _askText(String initial) async {
    final text = await showAppPrompt(context,
        label: context.t('ied.text_hint'),
        initial: initial,
        confirmLabel: context.t(initial.isEmpty ? 'common.add' : 'common.ok'));
    if (text == null || text.trim().isEmpty || !mounted) return null;
    return text.trim();
  }

  Future<void> _addText(Offset local) async {
    final text = await _askText('');
    if (text == null) return;
    _push(_e.copyWith(marks: [
      ..._e.marks,
      ImageMark(
        kind: MarkKind.text,
        points: [_norm(local)],
        color: _color,
        size: _stroke,
        opacity: _opacity,
        text: text,
      ),
    ]));
    setState(() => _sel = _e.marks.length - 1);
  }

  Future<void> _editText() async {
    final m = _selected;
    if (m == null || m.kind != MarkKind.text) return;
    final text = await _askText(m.text);
    if (text == null || _selected != m) return;
    _updateSelected(m.copyWith(text: text));
  }

  /// Seçili işarete tek adımlık değişiklik (renk, kalınlık, yazı tipi…).
  void _updateSelected(ImageMark m) {
    _history.push(_e);
    _replaceSelected(m);
  }

  void _deleteSelected() {
    if (_selected == null) return;
    _push(_e.copyWith(marks: [..._e.marks]..removeAt(_sel!)));
    setState(() => _sel = null);
  }

  // ── kanvas jestleri ────────────────────────────────────────────────────────

  void _gestureStart(ScaleStartDetails d) {
    _viewGesture = d.pointerCount > 1;
    if (_viewGesture) return _viewStart(d.localFocalPoint);
    if (_tab == _Tab.crop && !_showOriginal) {
      _cropStart(d.localFocalPoint);
    } else if (_tab == _Tab.markup) {
      _markStart(d.localFocalPoint);
    }
  }

  void _gestureUpdate(ScaleUpdateDetails d) {
    if (d.pointerCount > 1 && !_viewGesture) {
      _cancelTool();
      _viewGesture = true;
      _viewStart(d.localFocalPoint);
    }
    if (_viewGesture) {
      final c = _avail.center(Offset.zero);
      final vs = (_vsStart * d.scale).clamp(1.0, 8.0);
      setState(() {
        _vs = vs;
        _vo = d.localFocalPoint - c - (_focalStart - c - _voStart) * (vs / _vsStart);
      });
      return;
    }
    if (_tab == _Tab.crop && !_showOriginal) {
      _cropUpdate(d.localFocalPoint, d.focalPointDelta);
    } else if (_tab == _Tab.markup) {
      _markUpdate(d.localFocalPoint);
    }
  }

  void _gestureEnd(ScaleEndDetails d) {
    if (_viewGesture) {
      _viewGesture = d.pointerCount > 0;
      if (_vs <= 1.01) setState(() => _vo = Offset.zero);
      return;
    }
    if (_tab == _Tab.crop) {
      setState(() => _drag = _Drag.none);
    } else if (_tab == _Tab.markup) {
      _markEnd();
    }
  }

  void _viewStart(Offset focal) {
    _vsStart = _vs;
    _voStart = _vo;
    _focalStart = focal;
  }

  // ── kaydetme ──────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final src = _src;
    if (src == null || _saving) return;
    final ext = p.extension(widget.path).toLowerCase();
    final sameFormat = editedExtension(widget.path) == ext || ext == '.jpeg';
    final overwrite = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(AppIcons.addPhoto),
              title: Text(ctx.t('ied.save_copy')),
              subtitle: Text(sameFormat
                  ? ctx.t('ied.save_copy_sub')
                  : ctx.t('ied.as_jpeg')),
              onTap: () => Navigator.pop(ctx, false),
            ),
            if (sameFormat)
              ListTile(
                leading: const Icon(AppIcons.save),
                title: Text(ctx.t('ied.overwrite')),
                subtitle: Text(ctx.t('ied.overwrite_sub')),
                onTap: () => Navigator.pop(ctx, true),
              ),
          ],
        ),
      ),
    );
    if (overwrite == null || !mounted) return;
    setState(() => _saving = true);
    try {
      final out = await renderEdits(src, _e);
      final written = await saveEdited(widget.path, out, overwrite: overwrite);
      out.dispose();
      if (!mounted) return;
      showSnack(context, context.t('ied.saved', {'name': p.basename(written)}));
      _history.clear();
      _e = const ImageEdits();
      Navigator.of(context).pop(written);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showUserError(context, e);
      }
    }
  }

  /// Altı editörün ortak çıkış sorusu (Faz 20): Kaydet · Kaydetme · İptal.
  /// "Kaydet" kaydetme akışını açar; o akış başarıyla bitince ekranı kendisi
  /// kapatır, bu yüzden burada false döner.
  Future<bool> _confirmLeave() async {
    if (_e.isIdentity) return true;
    final choice = await showUnsavedChanges(context);
    if (!mounted) return false;
    switch (choice) {
      case UnsavedChoice.save:
        await _save();
        return false;
      case UnsavedChoice.discard:
        return true;
      case UnsavedChoice.cancel:
        return false;
    }
  }

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    assert(() {
      ImageEditScreen.debugEdits = _e;
      return true;
    }());
    return PopScope(
      canPop: _e.isIdentity || _saving,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmLeave() && context.mounted) {
          _e = const ImageEdits();
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.mediaSurface,
        appBar: AppBar(
          backgroundColor: AppColors.mediaSurface,
          foregroundColor: AppColors.onMedia,
          title: Text(context.t('ied.title'),
              style: OverlayBar.title(context)),
          actions: [
            // Basılı tut → özgünü gör (Faz 14b). Bırakınca düzenlenmiş hâl.
            if (!_e.isIdentity)
              Tooltip(
                message: context.t('ied.hold_original'),
                child: GestureDetector(
                  key: const ValueKey('hold-original'),
                  onTapDown: (_) => setState(() => _showOriginal = true),
                  onTapUp: (_) => setState(() => _showOriginal = false),
                  onTapCancel: () => setState(() => _showOriginal = false),
                  child: const Padding(
                    padding: EdgeInsets.all(12),
                    child: Icon(AppIcons.compare),
                  ),
                ),
              ),
            IconButton(
              tooltip: context.t('common.undo'),
              icon: const Icon(AppIcons.undo),
              onPressed: _history.canUndo
                  ? () => setState(() {
                        _e = _history.undo(_e)!;
                        _sel = null;
                      })
                  : null,
            ),
            IconButton(
              tooltip: context.t('common.redo'),
              icon: const Icon(AppIcons.redo),
              onPressed: _history.canRedo
                  ? () => setState(() {
                        _e = _history.redo(_e)!;
                        _sel = null;
                      })
                  : null,
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: FilledButton(
                onPressed:
                    _src == null || _saving || _e.isIdentity ? null : _save,
                child: _saving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(context.t('common.save')),
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Expanded(child: _canvas()),
            if (_src != null) _panel(scheme),
            NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) {
                setState(() {
                  _tab = _Tab.values[i];
                  _sel = null;
                });
                if (_tab == _Tab.size) _syncSizeFields();
              },
              destinations: [
                NavigationDestination(
                    icon: const Icon(AppIcons.crop), label: context.t('ied.crop')),
                NavigationDestination(
                    icon: const Icon(AppIcons.tune), label: context.t('ied.adjust')),
                NavigationDestination(
                    icon: const Icon(AppIcons.photoFilter),
                    label: context.t('ied.filters')),
                NavigationDestination(
                    icon: const Icon(AppIcons.draw),
                    label: context.t('ied.markup')),
                NavigationDestination(
                    icon: const Icon(AppIcons.resize),
                    label: context.t('gal.resize')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _canvas() {
    final src = _src;
    if (_error != null) {
      return Center(
        child: Text(userErrorText(_error!),
            style: const TextStyle(color: AppColors.onMediaSoft)),
      );
    }
    if (src == null) return const Center(child: CircularProgressIndicator());
    _ensureSharp();
    return LayoutBuilder(builder: (context, c) {
      _avail = c.biggest;
      final (box, visible) = _layout(c.biggest);
      _box = box;
      final edits = _showOriginal ? const ImageEdits() : _e;
      final crop = _tab == _Tab.crop && !_showOriginal;
      final markup = _tab == _Tab.markup;
      final view = _showOriginal ? (_proxy ?? src) : _view;
      final sel = markup ? _selected : null;
      return GestureDetector(
        key: const ValueKey('ied-canvas'),
        behavior: HitTestBehavior.opaque,
        onScaleStart: _gestureStart,
        onScaleUpdate: _gestureUpdate,
        onScaleEnd: _gestureEnd,
        onTapUp: markup ? (d) => _markTap(d.localPosition) : null,
        onDoubleTap: _vs != 1 || _vo != Offset.zero
            ? () => setState(() {
                  _vs = 1;
                  _vo = Offset.zero;
                })
            : null,
        child: Stack(children: [
          RepaintBoundary(
            child: CustomPaint(
              size: c.biggest,
              painter: _EditPainter(
                src: view,
                edits: edits,
                box: box,
                clip: visible,
                cropRect: crop ? _cropOnScreen() : null,
                cropLabel: crop ? _cropLabel() : null,
                fineGrid: crop && _straightening,
                selection: sel == null ? null : markBounds(sel, box),
                selectionRotation:
                    sel?.kind == MarkKind.text ? sel!.rotation : 0,
                handles: sel == null ? null : _handles(sel),
                labelStyle: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          ),
          // Çizilmekte olan işaret ayrı katmanda: her noktada yalnız bu boyanır.
          RepaintBoundary(
            child: CustomPaint(
              size: c.biggest,
              painter: _LivePainter(
                tick: _liveTick,
                mark: () => _live,
                src: view,
                edits: edits,
                box: box,
                clip: visible,
              ),
            ),
          ),
        ]),
      );
    });
  }

  Widget _panel(ColorScheme scheme) {
    final chipTheme = ChipTheme.of(context);
    final hint = chipTheme.labelStyle?.copyWith(color: AppColors.onMediaSoft);
    return Material(
      color: AppColors.mediaSurface,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
        child: switch (_tab) {
          _Tab.crop => Column(mainAxisSize: MainAxisSize.min, children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final (label, ratio) in _ratios)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: ChoiceChip(
                        label: Text(label.startsWith('ied.')
                            ? context.t(label)
                            : label),
                        selected: _ratioKey == label,
                        onSelected: (_) => _setRatioKey(label, ratio),
                      ),
                    ),
                ]),
              ),
              // Serbest açı (−45…45): sürüklerken ince ızgara.
              Row(children: [
                IconButton(
                  tooltip: context.t('ied.reset_one'),
                  color: AppColors.onMediaSoft,
                  icon: const Icon(AppIcons.straighten),
                  onPressed: _e.angle == 0
                      ? null
                      : () => _push(_e.copyWith(angle: 0)),
                ),
                Expanded(
                  child: Slider(
                    key: const ValueKey('ied-angle'),
                    value: _e.angle,
                    min: -45,
                    max: 45,
                    onChangeStart: (_) {
                      _history.push(_e);
                      setState(() => _straightening = true);
                    },
                    onChangeEnd: (_) => setState(() => _straightening = false),
                    onChanged: (v) => setState(() =>
                        _e = _e.copyWith(angle: (v * 2).roundToDouble() / 2)),
                  ),
                ),
                SizedBox(
                  width: 56,
                  child: Text('${_e.angle.toStringAsFixed(1)}°',
                      textAlign: TextAlign.end,
                      style: const TextStyle(color: AppColors.onMediaSoft)),
                ),
              ]),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  _toolButton(AppIcons.rotateRight, 'ied.rotate',
                      () => _push(_e.rotated())),
                  _toolButton(AppIcons.selectInvert, 'ied.flip',
                      () => _push(_e.flipped())),
                  _toolButton(
                      AppIcons.flipV, 'ied.flip_v', () => _push(_e.flippedV())),
                  _toolButton(AppIcons.reset, 'ied.reset', () {
                    setState(() {
                      _ratio = null;
                      _ratioKey = 'ied.free';
                    });
                    _push(const ImageEdits());
                  }),
                ]),
              ),
            ]),
          _Tab.adjust => _adjustPanel(),
          _Tab.filter => _filterPanel(),
          _Tab.size => _sizePanel(),
          _Tab.markup => _markupPanel(scheme, hint),
        },
      ),
    );
  }

  Widget _adjustPanel() {
    final unipolar = _adjustKey == 'sharpness' || _adjustKey == 'vignette';
    final value = _e.adjust(_adjustKey);
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final k in _adjustKeys)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('adj-$k'),
                // Değişmiş ayar noktayla işaretli.
                avatar: _e.adjust(k) != 0
                    ? const Icon(AppIcons.dot, size: 8)
                    : null,
                label: Text(context.t('ied.$k')),
                selected: _adjustKey == k,
                onSelected: (_) => setState(() => _adjustKey = k),
              ),
            ),
        ]),
      ),
      Row(children: [
        IconButton(
          key: const ValueKey('adj-reset'),
          tooltip: context.t('ied.reset_one'),
          color: AppColors.onMediaSoft,
          icon: const Icon(AppIcons.reset),
          onPressed: value == 0
              ? null
              : () => _push(_e.withAdjust(_adjustKey, 0)),
        ),
        Expanded(
          child: Slider(
            key: const ValueKey('adj-slider'),
            value: value,
            min: unipolar ? 0 : -1,
            max: 1,
            // Bir sürükleme = bir geri al adımı (IM4).
            onChangeStart: (_) => _history.push(_e),
            onChanged: (v) =>
                setState(() => _e = _e.withAdjust(_adjustKey, v)),
          ),
        ),
        SizedBox(
          width: 40,
          child: Text('${(value * 100).round()}',
              textAlign: TextAlign.end,
              style: const TextStyle(color: AppColors.onMediaSoft)),
        ),
      ]),
    ]);
  }

  Widget _filterPanel() {
    final thumb = _thumb ?? _proxy ?? _src!;
    Widget tile(String key, String label) {
      final selected = _e.filter == key;
      final m = editMatrix(_e.copyWith(filter: key, filterStrength: 1));
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: InkWell(
          key: ValueKey('filter-$key'),
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            if (selected) return;
            _push(_e.copyWith(filter: key, filterStrength: 1));
          },
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 64,
              height: 64,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? Theme.of(context).colorScheme.primary
                      : AppColors.onMediaFaint,
                  width: selected ? 3 : 1,
                ),
              ),
              child: ColorFiltered(
                colorFilter: ColorFilter.matrix(m),
                child: RawImage(image: thumb, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 2),
            Text(context.t(label),
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? AppColors.onMedia : AppColors.onMediaSoft)),
          ]),
        ),
      );
    }

    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          tile('', 'ied.f_none'),
          for (final f in imageFilters.entries) tile(f.key, f.value.$1),
        ]),
      ),
      if (_e.filter.isNotEmpty)
        Row(children: [
          SizedBox(
            width: 72,
            child: Text(context.t('ied.strength'),
                style: const TextStyle(color: AppColors.onMediaSoft)),
          ),
          Expanded(
            child: Slider(
              key: const ValueKey('filter-strength'),
              value: _e.filterStrength,
              onChangeStart: (_) => _history.push(_e),
              onChanged: (v) =>
                  setState(() => _e = _e.copyWith(filterStrength: v)),
            ),
          ),
          SizedBox(
            width: 40,
            child: Text('${(_e.filterStrength * 100).round()}',
                textAlign: TextAlign.end,
                style: const TextStyle(color: AppColors.onMediaSoft)),
          ),
        ]),
    ]);
  }

  Widget _markupPanel(ColorScheme scheme, TextStyle? hint) {
    final sel = _selected;
    const soft = TextStyle(color: AppColors.onMediaSoft);
    Widget slider(IconData icon, String key, double value, double min,
            double max, void Function(double) onChanged,
            {void Function(double)? onStart}) =>
        Expanded(
          child: Row(children: [
            Tooltip(
              message: context.t(key),
              child: Icon(icon, size: 18, color: AppColors.onMediaSoft),
            ),
            Expanded(
              child: Slider(
                key: ValueKey(key),
                value: value.clamp(min, max),
                min: min,
                max: max,
                onChangeStart: onStart,
                onChanged: onChanged,
              ),
            ),
          ]),
        );
    return Column(mainAxisSize: MainAxisSize.min, children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final (tool, icon, key) in const [
            (_Tool.select, AppIcons.pointer, 'ied.select'),
            (_Tool.pen, AppIcons.edit, 'ied.pen'),
            (_Tool.text, AppIcons.textFields, 'ied.text'),
            (_Tool.highlighter, AppIcons.highlighter, 'ied.highlighter'),
            (_Tool.eraser, AppIcons.eraser, 'ied.eraser'),
            (_Tool.arrow, AppIcons.arrowTool, 'ied.arrow'),
            (_Tool.line, AppIcons.lineTool, 'ied.line'),
            (_Tool.rect, AppIcons.rectTool, 'ied.rect'),
            (_Tool.ellipse, AppIcons.ellipseTool, 'ied.ellipse'),
            (_Tool.blur, AppIcons.blur, 'ied.blur'),
            (_Tool.pixelate, AppIcons.pixelate, 'ied.pixelate'),
          ])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('tool-${tool.name}'),
                avatar: Icon(icon, size: 18),
                label: Text(context.t(key)),
                selected: _tool == tool,
                onSelected: (_) => setState(() {
                  _tool = tool;
                  if (tool != _Tool.select && tool != _Tool.text) _sel = null;
                }),
              ),
            ),
        ]),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          for (final color in _colors)
            Semantics(
              button: true,
              selected: color == (sel?.color ?? _color),
              child: InkResponse(
                onTap: () {
                  setState(() => _color = color);
                  if (sel != null && sel.color != color) {
                    _updateSelected(sel.copyWith(color: color));
                  }
                },
                radius: 22,
                child: Container(
                  width: 28,
                  height: 28,
                  margin: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color == (sel?.color ?? _color)
                          ? scheme.primary
                          : AppColors.onMediaFaint,
                      width: color == (sel?.color ?? _color) ? 3 : 1,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ),
      Row(children: [
        slider(
          AppIcons.lineWeight,
          'ied.thickness',
          sel == null
              ? _stroke
              : sel.kind == MarkKind.text
                  ? sel.size
                  : _sizeOf(sel),
          0.004,
          sel?.kind == MarkKind.text ? 0.4 : 0.05,
          (v) => sel == null
              ? setState(() => _stroke = v)
              : _replaceSelected(sel.copyWith(
                  size: sel.kind == MarkKind.text ? v : v * (sel.size / _sizeOf(sel)))),
          onStart: sel == null ? null : (_) => _history.push(_e),
        ),
        slider(
          AppIcons.opacity,
          'ied.opacity',
          sel?.opacity ?? _opacity,
          0.1,
          1,
          (v) => sel == null
              ? setState(() => _opacity = v)
              : _replaceSelected(sel.copyWith(opacity: v)),
          onStart: sel == null ? null : (_) => _history.push(_e),
        ),
      ]),
      if (sel != null)
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            if (sel.kind == MarkKind.text) ...[
              _toolButton(AppIcons.edit, 'ied.edit_text', _editText),
              for (final (font, key) in const [
                ('sans', 'ied.font_sans'),
                ('serif', 'ied.font_serif'),
                ('mono', 'ied.font_mono'),
              ])
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: ChoiceChip(
                    label: Text(context.t(key)),
                    selected: sel.font == font,
                    onSelected: (_) =>
                        _updateSelected(sel.copyWith(font: font)),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: FilterChip(
                  key: const ValueKey('text-bg'),
                  label: Text(context.t('ied.text_box')),
                  selected: sel.background,
                  onSelected: (v) =>
                      _updateSelected(sel.copyWith(background: v)),
                ),
              ),
            ],
            _toolButton(AppIcons.delete, 'common.delete', _deleteSelected),
          ]),
        )
      else if (_tool == _Tool.text)
        Text(context.t('ied.tap_for_text'), style: hint)
      else if (_tool == _Tool.blur || _tool == _Tool.pixelate)
        Text(context.t('ied.blur_hint'),
            textAlign: TextAlign.center, style: hint ?? soft)
      else
        Text(context.t('ied.zoom_hint'), style: hint ?? soft),
    ]);
  }

  /// Seçili çizgi işaretinin taban kalınlığı (araç çarpanı çıkarılmış).
  double _sizeOf(ImageMark m) => switch (m.kind) {
        MarkKind.blur || MarkKind.pixelate => m.size / 5,
        MarkKind.highlighter => m.size / 2.5,
        _ => m.size,
      };

  Widget _toolButton(IconData icon, String key, VoidCallback onTap) => TextButton.icon(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.onMedia, minimumSize: const Size(48, 48)),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(context.t(key)),
      );
}

class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.src,
    required this.edits,
    required this.box,
    required this.clip,
    this.cropRect,
    this.cropLabel,
    this.fineGrid = false,
    this.selection,
    this.selectionRotation = 0,
    this.handles,
    this.labelStyle,
  });

  final ui.Image src;
  final ImageEdits edits;
  final Rect box, clip;
  final Rect? cropRect;

  /// Kırpma kutusunun piksel ölçüsü — kutunun üst ortasında rozet.
  final String? cropLabel;

  /// Serbest açı sürüklenirken 6×6 ince ızgara (yatay çizgiyi hizalamak için).
  final bool fineGrid;

  /// Seçili işaretin çerçevesi + tutamakları (boyut, döndür).
  final Rect? selection;
  final double selectionRotation;
  final (Offset, Offset?)? handles;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(clip);
    paintEdits(canvas, src, edits, box);
    canvas.restore();
    final sel = selection;
    if (sel != null) {
      final line = Paint()
        ..color = AppColors.slideSelection
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.save();
      canvas.translate(sel.center.dx, sel.center.dy);
      canvas.rotate(selectionRotation);
      canvas.drawRect(sel.shift(-sel.center), line);
      canvas.restore();
      final (scale, rotate) = handles!;
      final fill = Paint()..color = AppColors.slideSelection;
      final ring = Paint()
        ..color = AppColors.onMedia
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      for (final h in [scale, if (rotate != null) rotate]) {
        canvas.drawCircle(h, 9, fill);
        canvas.drawCircle(h, 9, ring);
      }
    }
    final r = cropRect;
    if (r == null) return;
    // Kırpma dışını karart, çerçeve + üçte bir kılavuzu + köşe tutamaçları.
    canvas.drawPath(
      Path.combine(PathOperation.difference, Path()..addRect(clip),
          Path()..addRect(r)),
      Paint()..color = const Color(0x99000000),
    );
    final line = Paint()
      ..color = AppColors.onMedia
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawRect(r, line);
    line
      ..strokeWidth = 0.6
      ..color = AppColors.onMediaGuide;
    final steps = fineGrid ? 6 : 3;
    for (var i = 1; i < steps; i++) {
      final f = i / steps;
      canvas.drawLine(Offset(r.left + r.width * f, r.top),
          Offset(r.left + r.width * f, r.bottom), line);
      canvas.drawLine(Offset(r.left, r.top + r.height * f),
          Offset(r.right, r.top + r.height * f), line);
    }
    final handle = Paint()
      ..color = AppColors.onMedia
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    const l = 18.0;
    for (final (o, dx, dy) in [
      (r.topLeft, 1.0, 1.0),
      (r.topRight, -1.0, 1.0),
      (r.bottomRight, -1.0, -1.0),
      (r.bottomLeft, 1.0, -1.0),
    ]) {
      canvas.drawLine(o, o + Offset(l * dx, 0), handle);
      canvas.drawLine(o, o + Offset(0, l * dy), handle);
    }
    final label = cropLabel;
    if (label != null) {
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: (labelStyle ?? const TextStyle()).copyWith(
              color: AppColors.onMedia, fontWeight: FontWeight.w600),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = Rect.fromCenter(
        center: Offset(r.center.dx, r.top + 8 + tp.height / 2 + 4),
        width: tp.width + 16,
        height: tp.height + 8,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(pill, const Radius.circular(12)),
          Paint()..color = AppColors.mediaChrome);
      tp.paint(canvas, pill.center - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_EditPainter old) =>
      old.edits != edits ||
      old.src != src ||
      old.box != box ||
      old.clip != clip ||
      old.cropRect != cropRect ||
      old.cropLabel != cropLabel ||
      old.fineGrid != fineGrid ||
      old.selection != selection ||
      old.selectionRotation != selectionRotation;
}

/// Çizilmekte olan tek işaret (IM2): [tick] her noktada yalnız bunu boyar.
class _LivePainter extends CustomPainter {
  _LivePainter({
    required this.tick,
    required this.mark,
    required this.src,
    required this.edits,
    required this.box,
    required this.clip,
  }) : super(repaint: tick);

  final ValueNotifier<int> tick;
  final ImageMark? Function() mark;
  final ui.Image src;
  final ImageEdits edits;
  final Rect box, clip;

  @override
  void paint(Canvas canvas, Size size) {
    final m = mark();
    if (m == null) return;
    canvas.save();
    canvas.clipRect(clip);
    paintMarks(canvas, [m], box, src: src, edits: edits);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LivePainter old) =>
      old.src != src || old.edits != edits || old.box != box || old.clip != clip;
}

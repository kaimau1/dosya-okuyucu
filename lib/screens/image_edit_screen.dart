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

part 'image_edit_screen/crop.dart';
part 'image_edit_screen/parts.dart';

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

  /// Bölüm dosyası (extension) `setState`i doğrudan çağıramaz (korumalı üye).
  void _update(VoidCallback fn) => setState(fn);
}

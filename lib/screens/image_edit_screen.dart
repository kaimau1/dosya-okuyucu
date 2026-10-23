import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../core/app_colors.dart';
import '../core/app_icons.dart';
import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../core/theme.dart' show OverlayBar;
import '../core/user_error.dart';
import '../models/media_resize.dart' show aspectChoices, longEdgeChoices;
import '../services/image_edit.dart';
import '../widgets/app_dialog.dart';

/// **Temel görsel düzenleyici** (Faz 10, N7). Kırp (oran ön ayarlı) ·
/// döndür/çevir · parlaklık/kontrast/doygunluk · işaretle (kalem/ok/yazı) ·
/// boyut (Faz 14b: kırp → boyut → kaydet tek akış).
/// Kaydetme varsayılanı KOPYA; özgüne dokunmak ayrı ve açık bir seçim.
/// Çizim ve kayıt `services/image_edit.dart`taki tek yoldan geçer.
class ImageEditScreen extends StatefulWidget {
  const ImageEditScreen({super.key, required this.path});

  final String path;

  /// Kaydedilen dosyanın yolunu döndürür (iptalde null).
  static Future<String?> open(BuildContext context, String path) =>
      Navigator.of(context).push<String>(
        MaterialPageRoute(builder: (_) => ImageEditScreen(path: path)),
      );

  @override
  State<ImageEditScreen> createState() => _ImageEditScreenState();
}

enum _Tab { crop, adjust, markup, size }

enum _Drag { none, move, tl, tr, br, bl }

class _ImageEditScreenState extends State<ImageEditScreen> {
  ui.Image? _src;
  Object? _error;
  ImageEdits _e = const ImageEdits();
  final _undo = <ImageEdits>[];
  _Tab _tab = _Tab.crop;
  double? _ratio; // genişlik/yükseklik (piksel); null = serbest
  String _ratioKey = 'ied.free';

  /// Basılı tutulan "özgünü gör" düğmesi (Faz 14b): düzenlemesiz hâl.
  bool _showOriginal = false;
  final _widthCtl = TextEditingController();
  final _heightCtl = TextEditingController();
  MarkKind _tool = MarkKind.pen;
  Color _color = const Color(0xFFE53935);
  ImageMark? _drawing;
  _Drag _drag = _Drag.none;
  bool _saving = false;

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
      if (mounted) {
        setState(() => _src = im);
      } else {
        im.dispose();
      }
    }, onError: (Object e) {
      if (mounted) setState(() => _error = e);
    });
  }

  @override
  void dispose() {
    _src?.dispose();
    _widthCtl.dispose();
    _heightCtl.dispose();
    super.dispose();
  }

  void _push(ImageEdits next) {
    _undo.add(_e);
    if (_undo.length > 30) _undo.removeAt(0);
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
    return (box, visible);
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
    _undo.add(_e);
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
    if (_drag != _Drag.none) _undo.add(_e);
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

  void _markStart(Offset local) {
    if (_tool == MarkKind.text) return;
    final n = _norm(local);
    _drawing = ImageMark(
      kind: _tool,
      points: _tool == MarkKind.arrow ? [n, n] : [n],
      color: _color,
    );
    setState(() {});
  }

  void _markUpdate(Offset local) {
    final d = _drawing;
    if (d == null) return;
    setState(() => _drawing = d.withPoint(_norm(local)));
  }

  void _markEnd() {
    final d = _drawing;
    _drawing = null;
    if (d != null) _push(_e.copyWith(marks: [..._e.marks, d]));
  }

  Future<void> _addText(Offset local) async {
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: ctx.t('ied.text_hint')),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(ctx.t('common.add')),
          ),
        ],
      ),
    );
    controller.dispose();
    if (text == null || text.trim().isEmpty || !mounted) return;
    _push(_e.copyWith(marks: [
      ..._e.marks,
      ImageMark(
        kind: MarkKind.text,
        points: [_norm(local)],
        color: _color,
        text: text.trim(),
      ),
    ]));
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
      _undo.clear();
      _e = const ImageEdits();
      Navigator.of(context).pop(written);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showUserError(context, e);
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (_e.isIdentity) return true;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(ctx.t('ied.discard')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ctx.t('common.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(ctx.t('ied.leave')),
          ),
        ],
      ),
    );
    return leave ?? false;
  }

  // ── arayüz ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
              onPressed: _undo.isEmpty
                  ? null
                  : () => setState(() => _e = _undo.removeLast()),
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
                setState(() => _tab = _Tab.values[i]);
                if (_tab == _Tab.size) _syncSizeFields();
              },
              destinations: [
                NavigationDestination(
                    icon: const Icon(AppIcons.crop), label: context.t('ied.crop')),
                NavigationDestination(
                    icon: const Icon(AppIcons.tune), label: context.t('ied.adjust')),
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
    return LayoutBuilder(builder: (context, c) {
      final (box, visible) = _layout(c.biggest);
      _box = box;
      final edits = _showOriginal
          ? const ImageEdits()
          : _drawing == null
              ? _e
              : _e.copyWith(marks: [..._e.marks, _drawing!]);
      final crop = _tab == _Tab.crop && !_showOriginal;
      final markup = _tab == _Tab.markup;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: crop
            ? (d) => _cropStart(d.localPosition)
            : markup
                ? (d) => _markStart(d.localPosition)
                : null,
        onPanUpdate: crop
            ? (d) => _cropUpdate(d.localPosition, d.delta)
            : markup
                ? (d) => _markUpdate(d.localPosition)
                : null,
        onPanEnd: crop
            ? (_) => setState(() => _drag = _Drag.none)
            : markup
                ? (_) => _markEnd()
                : null,
        onTapUp: markup && _tool == MarkKind.text
            ? (d) => _addText(d.localPosition)
            : null,
        child: RepaintBoundary(
          child: CustomPaint(
            size: c.biggest,
            painter: _EditPainter(
              src: src,
              edits: edits,
              box: box,
              clip: visible,
              cropRect: crop ? _cropOnScreen() : null,
              cropLabel: crop ? _cropLabel() : null,
            ),
          ),
        ),
      );
    });
  }

  Widget _panel(ColorScheme scheme) {
    final chipTheme = ChipTheme.of(context);
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
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _toolButton(AppIcons.rotateRight, 'ied.rotate',
                    () => _push(_e.rotated())),
                _toolButton(AppIcons.selectInvert, 'ied.flip', () => _push(_e.flipped())),
                _toolButton(AppIcons.reset, 'ied.reset', () {
                  setState(() {
                    _ratio = null;
                    _ratioKey = 'ied.free';
                  });
                  _push(const ImageEdits());
                }),
              ]),
            ]),
          _Tab.adjust => Column(mainAxisSize: MainAxisSize.min, children: [
              _slider('ied.brightness', _e.brightness,
                  (v) => _e.copyWith(brightness: v)),
              _slider('ied.contrast', _e.contrast,
                  (v) => _e.copyWith(contrast: v)),
              _slider('ied.saturation', _e.saturation,
                  (v) => _e.copyWith(saturation: v)),
            ]),
          _Tab.size => _sizePanel(),
          _Tab.markup => Column(mainAxisSize: MainAxisSize.min, children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final (kind, icon, key) in const [
                  (MarkKind.pen, AppIcons.edit, 'ied.pen'),
                  (MarkKind.arrow, AppIcons.arrowTool, 'ied.arrow'),
                  (MarkKind.text, AppIcons.textFields, 'ied.text'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: ChoiceChip(
                      avatar: Icon(icon, size: 18),
                      label: Text(context.t(key)),
                      selected: _tool == kind,
                      onSelected: (_) => setState(() => _tool = kind),
                    ),
                  ),
              ]),
              const SizedBox(height: 4),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (final color in _colors)
                  Semantics(
                    button: true,
                    selected: color == _color,
                    child: InkResponse(
                      onTap: () => setState(() => _color = color),
                      radius: 24,
                      child: Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: color == _color
                                ? scheme.primary
                                : AppColors.onMediaFaint,
                            width: color == _color ? 3 : 1,
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
              if (_tool == MarkKind.text)
                Text(context.t('ied.tap_for_text'),
                    style: chipTheme.labelStyle
                        ?.copyWith(color: AppColors.onMediaSoft)),
            ]),
        },
      ),
    );
  }

  Widget _toolButton(IconData icon, String key, VoidCallback onTap) => TextButton.icon(
        style: TextButton.styleFrom(
            foregroundColor: AppColors.onMedia, minimumSize: const Size(48, 48)),
        onPressed: onTap,
        icon: Icon(icon),
        label: Text(context.t(key)),
      );

  Widget _slider(
      String key, double value, ImageEdits Function(double) apply) {
    return Row(children: [
      SizedBox(
        width: 96,
        child: Text(context.t(key),
            style: const TextStyle(color: AppColors.onMediaSoft)),
      ),
      Expanded(
        child: Slider(
          value: value,
          min: -1,
          max: 1,
          onChangeStart: (_) => _undo.add(_e),
          onChanged: (v) => setState(() => _e = apply(v)),
        ),
      ),
      SizedBox(
        width: 40,
        child: Text('${(value * 100).round()}',
            textAlign: TextAlign.end,
            style: const TextStyle(color: AppColors.onMediaSoft)),
      ),
    ]);
  }
}

class _EditPainter extends CustomPainter {
  _EditPainter({
    required this.src,
    required this.edits,
    required this.box,
    required this.clip,
    this.cropRect,
    this.cropLabel,
  });

  final ui.Image src;
  final ImageEdits edits;
  final Rect box, clip;
  final Rect? cropRect;

  /// Kırpma kutusunun piksel ölçüsü — kutunun üst ortasında rozet.
  final String? cropLabel;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(clip);
    paintEdits(canvas, src, edits, box);
    canvas.restore();
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
      ..color = Colors.white54;
    for (final f in [1 / 3, 2 / 3]) {
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
          style: const TextStyle(
              color: AppColors.onMedia,
              fontSize: 12,
              fontWeight: FontWeight.w600),
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
      old.cropLabel != cropLabel;
}

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/app_colors.dart';
import '../services/pptx_render.dart';
import 'slide_text_controller.dart';

/// Düzenlenen slayt kutusunun içindeki editör (Faz 28).
///
/// Kutunun bütün paragrafları TEK düzenlenebilir alandır (paragraflar arası
/// seçim, Enter = yeni paragraf, paragraf başında geri silme = birleştir).
/// Punto biriminde çizilir — kanvasın yakınlaşması yazıyı okunur boya taşır.
/// * **Canlı sığdırma** (`normAutofit`/yer tutucu): yazdıkça taşan yazı
///   küçülür, PowerPoint gibi; kutu sığdırmasızsa yazı kutudan taşar.
/// * **Madde işaretleri** metnin solundaki oluğa çizilir: imleç konumundan
///   ölçülür, böylece model metnine sahte karakter girmez.
class SlideBoxEditor extends StatefulWidget {
  final ShapeVM shape;
  final SlideTextController controller;
  final FocusNode focusNode;

  /// Düzenlemeyi açan dokunuşun kutu içindeki yeri (punto): ilk yerleşimden
  /// sonra imleç oraya konur (B11 m.4 — "imleç doğrudan metinde").
  final Offset? tapAt;

  const SlideBoxEditor({
    super.key,
    required this.shape,
    required this.controller,
    required this.focusNode,
    this.tapAt,
  });

  @override
  State<SlideBoxEditor> createState() => _SlideBoxEditorState();

  /// `spAutoFit` kutusunun yazıya göre olması gereken boyu (punto; iç boşluk
  /// dahil). Madde oluğu ve canlı punto ölçeği editördekiyle aynı.
  static double fittedHeight(
      BuildContext context, ShapeVM s, SlideTextController c) {
    final bullets = c.model.paras.any((p) => p.effBullet != 'none');
    final gutter = bullets ? c.baseStyle.fontSize! * 1.2 : 0.0;
    final tp = TextPainter(
      text: c.buildTextSpan(context: context, withComposing: false),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: math.max(1, s.w - s.inset.horizontal - gutter));
    final h = tp.height + s.inset.vertical;
    tp.dispose();
    return h;
  }
}

class _SlideBoxEditorState extends State<SlideBoxEditor> {
  final _fieldKey = GlobalKey();
  List<(double, String, TextStyle)> _bullets = const [];

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
    _caretToTapLater();
  }

  @override
  void didUpdateWidget(SlideBoxEditor old) {
    super.didUpdateWidget(old);
    if (!identical(old.controller, widget.controller)) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
      _caretToTapLater();
    }
  }

  void _caretToTapLater() {
    if (widget.tapAt == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _caretToTap());
  }

  /// Dokunulan noktayı metin konumuna çevirir. Kutu = editörü saran
  /// [OverflowBox] (slide_canvas `_editorBody`), dokunuş onun yerel noktası.
  // ponytail: döndürülmüş kutuda dokunuş döndürülmeden eşlenir (imleç yaklaşık).
  void _caretToTap() {
    if (!mounted) return;
    final at = widget.tapAt;
    final ed = _editable();
    final box =
        context.findAncestorRenderObjectOfType<RenderConstrainedOverflowBox>();
    if (at == null || ed == null || box == null || !box.attached) {
      return;
    }
    final pos = ed.getPositionForPoint(box.localToGlobal(at));
    widget.controller.selection = TextSelection.collapsed(offset: pos.offset);
  }

  RenderEditable? _editable() {
    final root = _fieldKey.currentContext?.findRenderObject();
    if (root == null) return null;
    RenderEditable? found;
    void find(RenderObject o) {
      if (found != null) return;
      if (o is RenderEditable) {
        found = o;
        return;
      }
      o.visitChildren(find);
    }

    find(root);
    final ed = found;
    return ed != null && ed.attached && ed.hasSize ? ed : null;
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  /// Taşan yazının sığması için ek küçültme (1 = gerekmez).
  double _liveFit(double availW, double availH) {
    final s = widget.shape;
    // spAutoFit kutusu küçültmez, büyür ([SlideBoxEditor.fittedHeight]).
    if (!(s.autofit || s.isPlaceholder) ||
        s.growFit ||
        availW <= 0 ||
        availH <= 0) {
      return 1;
    }
    final c = widget.controller;
    double measure(double scale) {
      c.fontScale = scale;
      final tp = TextPainter(
        text: c.buildTextSpan(context: context, withComposing: false),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: math.max(1, availW - _gutter));
      final h = tp.height;
      tp.dispose();
      return h;
    }

    final base = s.fontScale;
    final h = measure(base);
    if (h <= availH) return 1;
    var fit = availH / h;
    if (measure(base * math.max(0.35, fit)) > availH) fit *= 0.9;
    return math.max(0.35, fit);
  }

  bool get _hasBullets =>
      widget.controller.model.paras.any((p) => p.effBullet != 'none');

  double get _gutter =>
      _hasBullets ? widget.controller.baseStyle.fontSize! * 1.2 : 0;

  /// Madde işaretlerinin yerini imleç kutularından ölçer (yerleşimden sonra).
  void _measureBullets() {
    if (!mounted) return;
    final ed = _editable();
    final host = context.findRenderObject();
    if (ed == null || host is! RenderBox) return;
    final c = widget.controller;
    final model = c.model;
    final ranges = model.paragraphRanges();
    var num = 0;
    final next = <(double, String, TextStyle)>[];
    for (var i = 0; i < ranges.length && i < model.paras.length; i++) {
      final p = model.paras[i];
      final kind = p.effBullet;
      if (kind == 'none') {
        num = 0;
        continue;
      }
      final caret = ed.getLocalRectForCaret(TextPosition(offset: ranges[i].$1));
      final top = host
          .globalToLocal(ed.localToGlobal(caret.topLeft))
          .dy;
      final st = c.styleOf(model.typingStyleAt(ranges[i].$1), p);
      final glyph = kind == 'num' ? '${++num}.' : _glyph(p.look?.bullet);
      next.add((top, glyph, st));
    }
    if (!_same(next, _bullets)) setState(() => _bullets = next);
  }

  static String _glyph(String? b) =>
      b == null || b.isEmpty || RegExp(r'^\d+\.$').hasMatch(b) ? '•' : b;

  static bool _same(List<(double, String, TextStyle)> a,
      List<(double, String, TextStyle)> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if ((a[i].$1 - b[i].$1).abs() > 0.5 || a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.shape;
    final c = widget.controller;
    final availW = s.w - s.inset.horizontal;
    final availH = s.h - s.inset.vertical;
    final fit = _liveFit(availW, availH);
    c.fontScale = s.fontScale * fit;
    WidgetsBinding.instance.addPostFrameCallback((_) => _measureBullets());

    final model = c.model;
    final align = model.paras.isEmpty ? TextAlign.left : model.paras.first.effAlign;
    final gutter = _gutter;
    final field = TextField(
      key: _fieldKey,
      controller: c,
      focusNode: widget.focusNode,
      autofocus: true,
      maxLines: null,
      keyboardType: TextInputType.multiline,
      textInputAction: TextInputAction.newline,
      textAlign: align,
      cursorColor: AppColors.slideSelection,
      cursorWidth: 1.5,
      style: c.baseStyle,
      decoration: const InputDecoration(
        isCollapsed: true,
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        disabledBorder: InputBorder.none,
        filled: false,
        contentPadding: EdgeInsets.zero,
      ),
    );
    if (gutter == 0) return field;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: EdgeInsetsDirectional.only(start: gutter),
          child: field,
        ),
        for (final (top, glyph, st) in _bullets)
          PositionedDirectional(
            start: 0,
            top: top,
            child: IgnorePointer(child: Text(glyph, style: st)),
          ),
      ],
    );
  }
}

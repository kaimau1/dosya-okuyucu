/// Word Mobil görünüm editörünün çizimi (Faz 22).
///
/// * Tembel liste: yalnız görünen paragraflar kurulur (300 sayfada da ilk
///   ekran hızlı); tablo, hücre paragraflarını içeren tek blok.
/// * Paragraf `RichText`; atomlar (`U+FFFC`) `WidgetSpan` — modeldeki tek
///   karakter ekrandaki tek yer tutucuya denk, imleç hesabı kaymaz.
/// * İmleç / seçim / yazım hatası çizgisi paragrafın ön boyacısında;
///   tutamaklar ve bağlam menüsü listenin üstündeki katmanda.
/// * Dokun = imleç, çift dokun = kelime, üç dokun = paragraf, uzun bas +
///   sürükle = seçim (çift dokunuş tanıyıcısı YOK — tek dokunuş beklemesin).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart' show kDoubleTapTimeout;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_haptics.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/motion.dart';
import '../../services/docx/docx_document.dart';
import '../../services/docx/docx_styles.dart';
import 'docx_edit_controller.dart';

/// Bağlam menüsündeki ek işler (çeviri, AI) — ekran verir.
class DocxEditorActions {
  final void Function(String text)? translate;
  final void Function(String text)? aiFix;
  const DocxEditorActions({this.translate, this.aiFix});
}

class DocxEditorView extends StatefulWidget {
  final DocxEditController controller;

  /// Punto → dp çarpanı (Mobil görünüm: gövde yazısı telefonda okunur boy).
  final double scale;
  final DocxEditorActions actions;

  /// Yazım denetimi (Android yazım servisi; ayardan kapatılabilir).
  final bool spellcheck;

  const DocxEditorView({
    super.key,
    required this.controller,
    this.scale = 1.35,
    this.actions = const DocxEditorActions(),
    this.spellcheck = true,
  });

  @override
  State<DocxEditorView> createState() => DocxEditorViewState();
}

/// Blok: tek paragraf ya da tablo (hücrelerin paragraf aralığı).
class _Block {
  final int start, end; // [start, end)
  final Object? table;
  const _Block(this.start, this.end, this.table);
}

class DocxEditorViewState extends State<DocxEditorView> {
  final _keys = <int, GlobalKey>{};
  final _stackKey = GlobalKey();
  final _scroll = ScrollController();
  final _focus = FocusNode(debugLabel: 'docx-editor');

  List<_Block> _blocks = const [];
  int _blocksAt = -1;

  // Çoklu dokunuş sayacı.
  DateTime _lastTap = DateTime.fromMillisecondsSinceEpoch(0);
  Offset _lastTapAt = Offset.zero;
  int _taps = 0;

  // Tutamak/araç çubuğu yerleri (yerleşimden sonra ölçülür).
  Offset? _handleA, _handleB;
  double _handleH = 20;
  Rect? _selTop;

  // Yazım denetimi: paragraf nesnesi → yanlış yazılmış aralıklar.
  final _spell = Expando<List<SuggestionSpan>>('docxSpell');
  Timer? _spellTimer;

  DocxEditController get c => widget.controller;

  @override
  void initState() {
    super.initState();
    c.addListener(_changed);
  }

  @override
  void didUpdateWidget(DocxEditorView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.controller, c)) {
      oldWidget.controller.removeListener(_changed);
      c.addListener(_changed);
    }
  }

  @override
  void dispose() {
    c.removeListener(_changed);
    _spellTimer?.cancel();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureOverlay();
      _revealCaret();
    });
    _scheduleSpell();
  }

  // ── bloklar ──────────────────────────────────────────────────────────────

  List<_Block> get _blockList {
    if (_blocksAt != c.structure || _blocks.isEmpty) {
      final out = <_Block>[];
      final ps = c.paras;
      var i = 0;
      while (i < ps.length) {
        final t = ps[i].cell?.table;
        if (t == null) {
          out.add(_Block(i, i + 1, null));
          i++;
          continue;
        }
        var j = i + 1;
        while (j < ps.length && identical(ps[j].cell?.table, t)) {
          j++;
        }
        out.add(_Block(i, j, t));
        i = j;
      }
      _blocks = out;
      _blocksAt = c.structure;
    }
    return _blocks;
  }

  GlobalKey _key(int i) => _keys.putIfAbsent(i, GlobalKey.new);

  RenderParagraph? _render(int i) {
    final ro = _keys[i]?.currentContext?.findRenderObject();
    return ro is RenderParagraph && ro.attached && ro.hasSize ? ro : null;
  }

  /// Ekran noktası → belge konumu (kurulmuş paragraflar arasında en yakın).
  DocPos? hitTest(Offset global) {
    DocPos? best;
    var bestD = double.infinity;
    _keys.forEach((i, k) {
      if (i >= c.paras.length) return;
      final ro = _render(i);
      if (ro == null) return;
      final local = ro.globalToLocal(global);
      final dy = local.dy < 0
          ? -local.dy
          : (local.dy > ro.size.height ? local.dy - ro.size.height : 0.0);
      final dx = local.dx < 0
          ? -local.dx
          : (local.dx > ro.size.width ? local.dx - ro.size.width : 0.0);
      final d = dy * 4 + dx; // dikey uzaklık daha önemli
      if (d < bestD) {
        bestD = d;
        final pos = ro.getPositionForOffset(Offset(
            local.dx.clamp(0, ro.size.width).toDouble(),
            local.dy.clamp(0, math.max(0, ro.size.height - 1)).toDouble()));
        best = DocPos(i, pos.offset.clamp(0, c.paras[i].length));
      }
    });
    return best;
  }

  // ── dokunuşlar ───────────────────────────────────────────────────────────

  void _onTapUp(TapUpDetails d) {
    final now = DateTime.now();
    final near = (d.globalPosition - _lastTapAt).distance < 24;
    _taps = near && now.difference(_lastTap) < kDoubleTapTimeout
        ? _taps + 1
        : 1;
    _lastTap = now;
    _lastTapAt = d.globalPosition;
    final p = hitTest(d.globalPosition);
    if (p == null) return;
    if (c.paras[p.para].opaque) return;
    _focus.requestFocus();
    if (_taps == 2) {
      c.selectWord(p);
    } else if (_taps >= 3) {
      c.selectParagraph(p.para);
    } else {
      // Seçimin içine dokunuş menüyü açar/kapar; yoksa imleç.
      if (!c.collapsed &&
          p.compareTo(c.start) >= 0 &&
          p.compareTo(c.end) <= 0) {
        c.toolbar = !c.toolbar;
        setState(() {});
        return;
      }
      c.select(p, p);
      // Yanlış yazılmış kelimeye dokunuş: öneriler menüde.
      if (_spellAt(p) != null) {
        c.selectWord(p);
      }
    }
    c.attach(autocorrect: widget.spellcheck);
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final p = hitTest(d.globalPosition);
    if (p == null || c.paras[p.para].opaque) return;
    AppHaptics.selection();
    c.selectWord(p);
    c.attach(autocorrect: widget.spellcheck);
  }

  void _onLongPressMove(LongPressMoveUpdateDetails d) {
    final p = hitTest(d.globalPosition);
    if (p == null) return;
    c.select(c.base, p);
  }

  void _onLongPressEnd(LongPressEndDetails d) {
    c.toolbar = !c.collapsed;
    setState(() {});
  }

  // ── imleci görünür tut ──────────────────────────────────────────────────

  void _revealCaret() {
    final ro = _render(c.extent.para);
    if (ro == null) return;
    final off = c.extent.offset.clamp(0, c.paras[c.extent.para].length);
    final caret = ro.getOffsetForCaret(TextPosition(offset: off), Rect.zero);
    final h = ro.getFullHeightForCaret(TextPosition(offset: off));
    ro.showOnScreen(
      rect: Rect.fromLTWH(caret.dx, caret.dy - 24, 2, h + 48),
      duration: Motion.short,
    );
  }

  /// Seçim uçlarının ve araç çubuğunun yeri.
  void _measureOverlay() {
    final host = _stackKey.currentContext?.findRenderObject();
    if (host is! RenderBox || !host.attached) return;
    Offset? at(DocPos p, {bool bottom = true}) {
      final ro = _render(p.para);
      if (ro == null) return null;
      final off = p.offset.clamp(0, c.paras[p.para].length);
      final caret = ro.getOffsetForCaret(TextPosition(offset: off), Rect.zero);
      final h = ro.getFullHeightForCaret(TextPosition(offset: off));
      _handleH = h;
      return host.globalToLocal(ro.localToGlobal(caret + Offset(0, bottom ? h : 0)));
    }

    Offset? a, b;
    Rect? top;
    if (!c.collapsed) {
      a = at(c.start);
      b = at(c.end);
      final t = at(c.start, bottom: false);
      if (t != null) top = Rect.fromLTWH(t.dx, t.dy, 1, _handleH);
    }
    if (a != _handleA || b != _handleB || top != _selTop) {
      setState(() {
        _handleA = a;
        _handleB = b;
        _selTop = top;
      });
    }
  }

  // ── yazım denetimi ──────────────────────────────────────────────────────

  void _scheduleSpell() {
    if (!widget.spellcheck) return;
    _spellTimer?.cancel();
    _spellTimer = Timer(const Duration(seconds: 1), _runSpell);
  }

  Future<void> _runSpell() async {
    if (!mounted) return;
    final i = c.extent.para;
    if (i >= c.paras.length) return;
    final p = c.paras[i];
    if (p.opaque || p.text.trim().isEmpty || _spell[p] != null) return;
    final locale = Localizations.maybeLocaleOf(context) ?? const Locale('tr');
    List<SuggestionSpan>? spans;
    try {
      spans = await DefaultSpellCheckService()
          .fetchSpellCheckSuggestions(locale, p.text.replaceAll(kDocxAtom, ' '));
    } catch (_) {
      return; // servis yok (masaüstü/test) — sessizce
    }
    if (!mounted || spans == null) return;
    _spell[p] = spans;
    setState(() {});
  }

  SuggestionSpan? _spellAt(DocPos p) {
    final spans = _spell[c.paras[p.para]];
    if (spans == null) return null;
    for (final s in spans) {
      if (p.offset >= s.range.start && p.offset <= s.range.end) return s;
    }
    return null;
  }

  // ── çizim ────────────────────────────────────────────────────────────────

  TextStyle _style(DocxRunLook look, {bool? bold, bool? italic, bool? underline}) {
    final b = bold ?? look.bold, i = italic ?? look.italic;
    final u = underline ?? look.underline;
    final sup = look.vertAlign != null;
    return TextStyle(
      fontFamily: look.renderFamily,
      fontSize: look.sizePt * widget.scale * (sup ? 0.65 : 1),
      fontWeight: b ? FontWeight.w700 : FontWeight.w400,
      fontStyle: i ? FontStyle.italic : FontStyle.normal,
      decoration: TextDecoration.combine([
        if (u) TextDecoration.underline,
        if (look.strike) TextDecoration.lineThrough,
      ]),
      color: look.color == null ? AppColors.pageInk : Color(look.color!),
      backgroundColor: look.highlight == null ? null : Color(look.highlight!),
      height: 1.3,
    );
  }

  InlineSpan _atomSpan(DocxAtom a, TextStyle st, double maxW) {
    switch (a.kind) {
      case DocxAtomKind.image:
        final w = a.widthPt <= 0 ? maxW : math.min(maxW, a.widthPt * widget.scale);
        final h = a.widthPt <= 0 ? null : w * a.heightPt / math.max(1, a.widthPt);
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: a.image == null
              ? SizedBox(width: w, height: h ?? 40, child: const Placeholder())
              : Image.memory(a.image!, width: w, height: h, fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => SizedBox(width: w, height: h ?? 40)),
        );
      case DocxAtomKind.pageBreak:
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: SizedBox(
            width: maxW,
            child: Row(children: [
              const Expanded(child: Divider(color: AppColors.slidePromptFrame)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(context.t('word.page_break'),
                    style: st
                        .apply(fontSizeFactor: 0.75)
                        .copyWith(color: AppColors.slidePrompt)),
              ),
              const Expanded(child: Divider(color: AppColors.slidePromptFrame)),
            ]),
          ),
        );
      case DocxAtomKind.note:
        return WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: Text(a.display, style: st.apply(fontSizeFactor: 0.65)),
        );
      case DocxAtomKind.link:
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Text(a.display,
                style: st.copyWith(
                    color: AppHues.blue, decoration: TextDecoration.underline)),
          ),
        );
      case DocxAtomKind.field || DocxAtomKind.inline:
        return WidgetSpan(
          alignment: PlaceholderAlignment.baseline,
          baseline: TextBaseline.alphabetic,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxW),
            child: Text(a.display.isEmpty ? '·' : a.display, style: st),
          ),
        );
    }
  }

  TextSpan _span(DocxPara p, double maxW) {
    final kids = <InlineSpan>[];
    var k = 0;
    while (k < p.length) {
      final atom = p.atoms[k];
      if (atom != null) {
        kids.add(_atomSpan(atom, _style(p.styles[k].look), maxW));
        k++;
        continue;
      }
      final st = p.styles[k];
      var j = k + 1;
      while (j < p.length && p.atoms[j] == null && identical(p.styles[j], st)) {
        j++;
      }
      kids.add(TextSpan(
        text: p.text.substring(k, j),
        style: _style(st.look,
            bold: st.bold, italic: st.italic, underline: st.underline),
      ));
      k = j;
    }
    return TextSpan(style: _style(p.mark.look), children: kids);
  }

  Widget _para(int i, double maxW) {
    final p = c.paras[i];
    final look = p.look;
    final label = c.labels.length > i ? c.labels[i] : '';
    final s = widget.scale;
    final indent = math.min(maxW * 0.4, look.indentLeftPt * s * 0.6);
    final dir = look.bidi ? TextDirection.rtl : TextDirection.ltr;
    // Hiza okuma yönüne göre: Word'ün sol/sağ'ı paragrafın başı/sonu.
    final align = switch (look.align) {
      'center' => TextAlign.center,
      'right' => TextAlign.end,
      'both' => TextAlign.justify,
      _ => TextAlign.start,
    };
    final textW = math.max(40.0, maxW - indent - (label.isEmpty ? 0 : 28));
    Widget body = CustomPaint(
      foregroundPainter: _ParaPainter(c, i, _key(i), _spell[p]),
      child: RichText(
        key: _key(i),
        text: _span(p, textW),
        textAlign: align,
        textDirection: dir,
      ),
    );
    if (p.opaque) {
      body = Opacity(opacity: 0.7, child: body);
    }
    if (label.isNotEmpty) {
      body = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        textDirection: dir,
        children: [
          SizedBox(
            width: 28,
            child: Text(label,
                textDirection: dir,
                style: _style(p.mark.look)),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: look.bidi ? 0 : indent,
        end: look.bidi ? indent : 0,
        top: math.min(18, look.spaceBeforePt * s * 0.6),
        bottom: math.min(14, look.spaceAfterPt * s * 0.6),
      ),
      child: body,
    );
  }

  Widget _table(_Block b, double maxW) {
    // Satır → hücre → paragraflar.
    final rows = <int, Map<int, List<int>>>{};
    final spans = <int, Map<int, int>>{};
    var cols = 0;
    for (var i = b.start; i < b.end; i++) {
      final cell = c.paras[i].cell!;
      ((rows[cell.row] ??= {})[cell.col] ??= []).add(i);
      (spans[cell.row] ??= {})[cell.col] = cell.gridSpan;
      cols = math.max(cols, cell.col + cell.gridSpan);
    }
    final colW = math.max(110.0, (maxW - 2) / math.max(1, cols));
    final tableW = colW * cols;
    final line = BorderSide(color: AppColors.pageInk.withValues(alpha: 0.35));
    final table = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final r in (rows.keys.toList()..sort()))
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final col in (rows[r]!.keys.toList()..sort()))
                  Container(
                    width: colW * (spans[r]![col] ?? 1),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        border: Border(right: line, bottom: line, left: col == 0 ? line : BorderSide.none, top: r == 0 ? line : BorderSide.none)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final i in rows[r]![col]!)
                          _para(i, colW * (spans[r]![col] ?? 1) - 12),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: tableW <= maxW
          ? table
          : SingleChildScrollView(
              scrollDirection: Axis.horizontal, child: table),
    );
  }

  // ── bağlam menüsü ────────────────────────────────────────────────────────

  List<ContextMenuButtonItem> _menuItems() {
    final items = <ContextMenuButtonItem>[];
    final sp = c.collapsed ? null : _spellAt(c.start);
    if (sp != null) {
      for (final s in sp.suggestions.take(3)) {
        items.add(ContextMenuButtonItem(
            label: s, onPressed: () => c.replaceSelection(s)));
      }
    }
    items.addAll([
      ContextMenuButtonItem(
          type: ContextMenuButtonType.cut, onPressed: () => c.cut()),
      ContextMenuButtonItem(
          type: ContextMenuButtonType.copy, onPressed: () => c.copy()),
      ContextMenuButtonItem(
          type: ContextMenuButtonType.paste, onPressed: () => c.paste()),
      ContextMenuButtonItem(
          type: ContextMenuButtonType.selectAll, onPressed: c.selectAll),
    ]);
    final tr = widget.actions.translate;
    if (tr != null) {
      items.add(ContextMenuButtonItem(
          label: context.t('common.translate'),
          onPressed: () {
            c.toolbar = false;
            tr(c.selectedText());
          }));
    }
    final ai = widget.actions.aiFix;
    if (ai != null) {
      items.add(ContextMenuButtonItem(
          label: context.t('word.ai_fix'),
          onPressed: () {
            c.toolbar = false;
            ai(c.selectedText());
          }));
    }
    return items;
  }

  Widget _handle(Offset at, bool startHandle) {
    const size = 22.0;
    return Positioned.fromRect(
      rect: Rect.fromLTWH(at.dx - size / 2, at.dy, size, size),
      child: GestureDetector(
        key: ValueKey(startHandle ? 'docx-handle-a' : 'docx-handle-b'),
        behavior: HitTestBehavior.opaque,
        onPanUpdate: (d) {
          final p = hitTest(d.globalPosition - Offset(0, _handleH / 2 + 8));
          if (p == null) return;
          if (startHandle) {
            c.select(p, c.end);
          } else {
            c.select(c.start, p);
          }
        },
        onPanEnd: (_) {
          c.toolbar = !c.collapsed;
          setState(() {});
        },
        child: Container(
          width: size,
          height: size,
          decoration: const BoxDecoration(
            color: AppColors.slideSelection,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, box) {
      final maxW = math.max(120.0, box.maxWidth - 32);
      final bl = _blockList;
      final list = ListView.builder(
        controller: _scroll,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        itemCount: bl.length,
        itemBuilder: (context, k) {
          final b = bl[k];
          if (b.start >= c.paras.length) return const SizedBox.shrink();
          return b.table == null ? _para(b.start, maxW) : _table(b, maxW);
        },
      );
      final sel = _selTop;
      return Focus(
        focusNode: _focus,
        onKeyEvent: (_, e) =>
            c.handleKey(e) ? KeyEventResult.handled : KeyEventResult.ignored,
        child: Container(
          color: AppColors.page,
          child: Stack(
            key: _stackKey,
            children: [
              Positioned.fill(
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTapUp: _onTapUp,
                  onLongPressStart: _onLongPressStart,
                  onLongPressMoveUpdate: _onLongPressMove,
                  onLongPressEnd: _onLongPressEnd,
                  child: NotificationListener<ScrollNotification>(
                    onNotification: (_) {
                      WidgetsBinding.instance
                          .addPostFrameCallback((_) => _measureOverlay());
                      return false;
                    },
                    child: list,
                  ),
                ),
              ),
              if (!c.collapsed && _handleA != null) _handle(_handleA!, true),
              if (!c.collapsed && _handleB != null) _handle(_handleB!, false),
              if (c.toolbar && !c.collapsed && sel != null)
                _toolbar(sel, box.maxWidth),
            ],
          ),
        ),
      );
    });
  }

  /// Seçimin üstünde (yer yoksa altında) yüzen bağlam çubuğu.
  Widget _toolbar(Rect sel, double width) {
    final items = _menuItems();
    final scheme = Theme.of(context).colorScheme;
    const h = 44.0;
    final top = sel.top - h - 8 >= 0 ? sel.top - h - 8 : sel.bottom + _handleH + 28;
    return Positioned.fromRect(
      rect: Rect.fromLTWH(8, top, width - 16, h),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: Material(
          key: const ValueKey('docx-toolbar'),
          elevation: 3,
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final it in items)
                  TextButton(
                    onPressed: it.onPressed,
                    child: Text(
                        AdaptiveTextSelectionToolbar.getButtonLabel(context, it)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// İmleç, seçim ve yazım hatası çizgisi.
class _ParaPainter extends CustomPainter {
  final DocxEditController c;
  final int i;
  final GlobalKey key;
  final List<SuggestionSpan>? spell;
  _ParaPainter(this.c, this.i, this.key, this.spell);

  @override
  void paint(Canvas canvas, Size size) {
    final ro = key.currentContext?.findRenderObject();
    if (ro is! RenderParagraph || !ro.hasSize) return;
    if (i >= c.paras.length) return;
    final len = c.paras[i].length;
    final sp = spell;
    if (sp != null) {
      final red = Paint()
        ..color = AppHues.red
        ..strokeWidth = 1.2
        ..style = PaintingStyle.stroke;
      for (final s in sp) {
        if (s.range.end > len) continue;
        for (final b in ro.getBoxesForSelection(
            TextSelection(baseOffset: s.range.start, extentOffset: s.range.end))) {
          final r = b.toRect();
          final path = Path()..moveTo(r.left, r.bottom);
          for (var x = r.left; x < r.right; x += 4) {
            path.lineTo(x + 2, r.bottom + ((x - r.left) ~/ 2 % 2 == 0 ? 2 : -0.5));
          }
          canvas.drawPath(path, red);
        }
      }
    }
    final s = c.start, e = c.end;
    if (c.collapsed) {
      if (i != c.extent.para || !c.attached) return;
      final off = c.extent.offset.clamp(0, len);
      final at = ro.getOffsetForCaret(TextPosition(offset: off), Rect.zero);
      final h = ro.getFullHeightForCaret(TextPosition(offset: off));
      canvas.drawRect(Rect.fromLTWH(at.dx, at.dy, 2, h),
          Paint()..color = AppColors.slideSelection);
      return;
    }
    if (i < s.para || i > e.para) return;
    final from = i == s.para ? s.offset : 0;
    final to = i == e.para ? e.offset : len;
    final paint = Paint()
      ..color = AppColors.slideSelection.withValues(alpha: 0.22);
    for (final b in ro.getBoxesForSelection(
        TextSelection(baseOffset: from, extentOffset: to))) {
      canvas.drawRect(b.toRect(), paint);
    }
    // Boş paragraf seçimdeyse küçük bir işaret.
    if (from == to && len == 0) {
      canvas.drawRect(Rect.fromLTWH(0, 0, 6, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_ParaPainter old) => true;
}

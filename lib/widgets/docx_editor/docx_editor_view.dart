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
import '../../core/app_icons.dart';
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

  /// Dipnot / yorum işaretine dokunuş (kimlik ile).
  final void Function(String id)? openNote, openComment;
  const DocxEditorActions(
      {this.translate, this.aiFix, this.openNote, this.openComment});
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

  // İmleç yanıp sönmesi (EditableText gibi 500 ms); her değişiklikte görünür
  // başlar, yalnız klavye bağlıyken ve seçim yokken çalışır.
  final _caretOn = ValueNotifier<bool>(true);
  Timer? _blinkTimer;

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
    _blinkTimer?.cancel();
    _caretOn.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    setState(() {});
    _restartBlink();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureOverlay();
      _revealCaret();
    });
    _scheduleSpell();
  }

  void _restartBlink() {
    _blinkTimer?.cancel();
    _caretOn.value = true;
    if (!c.attached || !c.collapsed) return;
    _blinkTimer = Timer.periodic(Motion.caretBlink, (_) {
      if (!mounted || !c.attached) {
        _blinkTimer?.cancel();
        _caretOn.value = true;
        return;
      }
      _caretOn.value = !_caretOn.value;
    });
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
    if (c.painterActive && _taps == 1) {
      // Biçim boyacısı: dokunulan kelimeye uygula (Word gibi).
      c.selectWord(p);
      c.selectionFinished();
    } else if (_taps == 2) {
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
    _restartBlink(); // bağlantı select'ten sonra kuruldu
  }

  void _onLongPressStart(LongPressStartDetails d) {
    final p = hitTest(d.globalPosition);
    if (p == null || c.paras[p.para].opaque) return;
    AppHaptics.selection();
    _focus.requestFocus();
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
    c.selectionFinished();
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

  /// Gezinti: [i]. paragrafa atlar. Tembel listede paragraf kurulu
  /// olmayabilir — önce blok oranıyla tahmini konuma kaydırılır, kurulunca
  /// tam yerine (en çok birkaç kare).
  Future<void> revealParagraph(int i) async {
    final bl = _blockList;
    var k = bl.indexWhere((b) => i >= b.start && i < b.end);
    if (k < 0) k = 0;
    for (var tries = 0; tries < 6 && mounted; tries++) {
      final ro = _render(i);
      if (ro != null) {
        ro.showOnScreen(
            rect: Rect.fromLTWH(0, -8, ro.size.width, ro.size.height + 16),
            duration: Motion.short);
        return;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final target = (pos.maxScrollExtent * k / math.max(1, bl.length - 1))
          .clamp(0.0, pos.maxScrollExtent);
      _scroll.jumpTo(target);
      await WidgetsBinding.instance.endOfFrame;
    }
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

  TextStyle _style(DocxRunLook look) {
    final b = look.bold, i = look.italic, u = look.underline;
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

  InlineSpan _atomSpan(DocxAtom a, TextStyle st, double maxW, int i, int k) {
    switch (a.kind) {
      case DocxAtomKind.image:
        final sel = c.selectedImage;
        final selected = identical(sel, a) && c.start == DocPos(i, k);
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: _ImageAtom(
            key: ValueKey('docx-img-$i-$k'),
            atom: a,
            scale: widget.scale,
            maxW: maxW,
            selected: selected,
            onTap: () {
              _focus.requestFocus();
              c.detach();
              c.selectAtom(i, k);
            },
            onResize: (pt) => c.resizeImage(pt),
          ),
        );
      case DocxAtomKind.comment:
        final open = widget.actions.openComment;
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: GestureDetector(
            key: ValueKey('docx-comment-${a.display}'),
            onTap: open == null ? null : () => open(a.display),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(AppIcons.comment,
                  size: (st.fontSize ?? 14) * 0.9, color: AppHues.amber),
            ),
          ),
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
        final open = widget.actions.openNote;
        return WidgetSpan(
          alignment: PlaceholderAlignment.top,
          child: GestureDetector(
            key: ValueKey('docx-note-${a.display}'),
            onTap: open == null ? null : () => open(a.display),
            child: Text(a.display,
                style: st.apply(fontSizeFactor: 0.65).copyWith(
                    color: open == null ? null : AppHues.blue)),
          ),
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

  /// Yorum aralıklarının sınırları (paragraf içi): açık aralık [from, to).
  static List<(int, int)> _commentRanges(DocxPara p) {
    final starts = <String, int>{};
    final out = <(int, int)>[];
    final ends = <String>{};
    for (final (o, e) in p.anchors) {
      final id = e.getAttribute('w:id') ?? '';
      if (e.name.local == 'commentRangeStart') starts[id] = o;
      if (e.name.local == 'commentRangeEnd') {
        out.add((starts.remove(id) ?? 0, o));
        ends.add(id);
      }
    }
    for (final o in starts.values) {
      out.add((o, p.length));
    }
    return out;
  }

  TextSpan _span(DocxPara p, double maxW, int i) {
    final kids = <InlineSpan>[];
    final ranges = p.anchors.isEmpty ? const <(int, int)>[] : _commentRanges(p);
    bool inComment(int k) => ranges.any((r) => k >= r.$1 && k < r.$2);
    var k = 0;
    while (k < p.length) {
      final atom = p.atoms[k];
      if (atom != null) {
        kids.add(_atomSpan(atom, _style(p.styles[k].effective), maxW, i, k));
        k++;
        continue;
      }
      final st = p.styles[k];
      final mark = inComment(k);
      var j = k + 1;
      while (j < p.length &&
          p.atoms[j] == null &&
          identical(p.styles[j], st) &&
          inComment(j) == mark) {
        j++;
      }
      var style = _style(st.effective);
      if (mark && style.backgroundColor == null) {
        style = style.copyWith(
            backgroundColor: AppHues.amber.withValues(alpha: 0.18));
      }
      kids.add(TextSpan(text: p.text.substring(k, j), style: style));
      k = j;
    }
    return TextSpan(style: _style(p.mark.effective), children: kids);
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
      foregroundPainter: _ParaPainter(c, i, _key(i), _spell[p],
          i == c.extent.para ? _caretOn : null),
      child: RichText(
        key: _key(i),
        text: _span(p, textW, i),
        textAlign: align,
        textDirection: dir,
      ),
    );
    if (p.opaque) {
      body = Opacity(opacity: 0.7, child: body);
    }
    if (look.borderBottom) {
      body = DecoratedBox(
        decoration: BoxDecoration(
            border: Border(
                bottom: BorderSide(
                    color: AppColors.pageInk.withValues(alpha: 0.6), width: 1.2))),
        child: Padding(padding: const EdgeInsets.only(bottom: 4), child: body),
      );
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
                style: _style(p.mark.effective)),
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
          c.selectionFinished();
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
  final ValueNotifier<bool>? caretOn;
  _ParaPainter(this.c, this.i, this.key, this.spell, this.caretOn)
      : super(repaint: caretOn);

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
      if (caretOn != null && !caretOn!.value) return;
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


/// Resim atomu: seçiliyken çerçeve + sağ alt köşede oran kilitli
/// boyutlandırma tutamağı (sürüklerken canlı önizleme, bırakınca yazılır).
class _ImageAtom extends StatefulWidget {
  final DocxAtom atom;
  final double scale, maxW;
  final bool selected;
  final VoidCallback onTap;
  final ValueChanged<double> onResize;
  const _ImageAtom({
    super.key,
    required this.atom,
    required this.scale,
    required this.maxW,
    required this.selected,
    required this.onTap,
    required this.onResize,
  });

  @override
  State<_ImageAtom> createState() => _ImageAtomState();
}

class _ImageAtomState extends State<_ImageAtom> {
  double? _dragW; // sürüklenirken ekran genişliği

  @override
  Widget build(BuildContext context) {
    final a = widget.atom;
    final natural = a.widthPt <= 0 ? widget.maxW : a.widthPt * widget.scale;
    final w = math.min(widget.maxW, _dragW ?? natural);
    final ratio = a.widthPt <= 0 ? null : a.heightPt / math.max(1, a.widthPt);
    final h = ratio == null ? null : w * ratio;
    Widget img = a.image == null
        ? SizedBox(width: w, height: h ?? 40, child: const Placeholder())
        : Image.memory(a.image!,
            width: w,
            height: h,
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (_, __, ___) => SizedBox(width: w, height: h ?? 40));
    img = GestureDetector(onTap: widget.onTap, child: img);
    if (!widget.selected) return img;
    const hs = 22.0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
              border: Border.all(color: AppColors.slideSelection, width: 2)),
          child: img,
        ),
        // Tutamak resmin İÇİNDE (köşede): dışarı taşan parça WidgetSpan'in
        // vuruş alanı dışında kalır, dokunuş ulaşmaz.
        PositionedDirectional(
          end: 0,
          bottom: 0,
          child: GestureDetector(
            key: const ValueKey('docx-img-handle'),
            behavior: HitTestBehavior.opaque,
            onPanStart: (_) => setState(() => _dragW = w),
            onPanUpdate: (d) => setState(() => _dragW =
                ((_dragW ?? w) + d.delta.dx).clamp(24.0, widget.maxW)),
            onPanEnd: (_) {
              final px = _dragW;
              setState(() => _dragW = null);
              if (px != null) widget.onResize(px / widget.scale);
            },
            child: Container(
              width: hs,
              height: hs,
              decoration: BoxDecoration(
                color: AppColors.page,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.slideSelection, width: 2),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

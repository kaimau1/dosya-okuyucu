import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as p;
import 'package:pdfrx/pdfrx.dart';

import '../core/l10n/app_strings.dart';
import '../core/snack.dart';
import '../services/fm/entry_opener.dart';
import '../services/fm/save_to_downloads.dart';
import '../services/pdf/pdf_markup.dart';
import '../widgets/download_action.dart';
import '../widgets/pdf_save_dialog.dart';

/// Kalem ekranında seçili araç.
enum InkTool { pen, highlighter, eraser, text, hand }

/// **Kalemle düzenleme** — PDF'in üstüne elle çiz, fosforlu kalemle işaretle,
/// yazı ekle, sil; tek düğmeyle kaydet.
///
/// Kullanıcı 2026-09-22 (Chrome'un PDF görüntüleyicisindeki kalem düğmesinin
/// ekran görüntüsüyle): *"buradaki kalem işaretine basınca biz çıkmıyoruz,
/// Edge falan çıkıyor; biz çıkıp her türlü düzenleme kalem işlerini
/// yapabilmeliyiz ve kolayca kaydedebilmeliyiz."* O düğme Android'e
/// `android.intent.action.ANNOTATE` gönderir; manifest artık bu eylemi
/// karşılıyor ve dosya doğrudan bu ekranda açılıyor (bkz. `MainActivity`).
///
/// Hareketler: tek parmak çizer (ya da silgide siler), iki parmak
/// yakınlaştırır; yakınlaşmışken gezinmek için "Kaydır" aracı. Sayfalar
/// arası geçiş alt çubuktan — kaydırarak sayfa değiştirmek çizmeyle
/// çakışırdı.
///
/// İzler kaydedilince sayfa içeriğine vektör olarak işlenir
/// ([applyPdfMarks]). Dosya başka uygulamanın önbelleğinden geldiyse
/// (kullanıcının göremediği yer) sorulmadan **İndirilenler**'e yazılır;
/// depolamadaki dosyada her zamanki "üzerine yaz / kopya" seçimi çıkar.
class PdfInkScreen extends StatefulWidget {
  const PdfInkScreen({
    super.key,
    required this.path,
    this.initialPage = 1,
    this.testPageSizes,
  });

  final String path;

  /// Testler için: pdfium olmadan sayfa ölçüleri (sayfalar düz beyaz çizilir).
  @visibleForTesting
  final List<Size>? testPageSizes;

  /// 1 tabanlı.
  final int initialPage;

  /// Özgün dosyanın üzerine yazıldıysa `true` (açık görüntüleyici tazelensin).
  static Future<bool?> open(
    BuildContext context,
    String path, {
    int initialPage = 1,
  }) =>
      Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => PdfInkScreen(path: path, initialPage: initialPage),
      ));

  @override
  State<PdfInkScreen> createState() => _PdfInkScreenState();
}

class _PdfInkScreenState extends State<PdfInkScreen> {
  static const _penColors = [
    0xFF111111, // siyah
    0xFF1565C0, // mavi
    0xFFD32F2F, // kırmızı
    0xFF2E7D32, // yeşil
  ];
  static const _highlightColors = [
    0xFFFFEB3B, // sarı
    0xFF76FF03, // yeşil
    0xFFFF80AB, // pembe
    0xFF40C4FF, // mavi
  ];

  /// Kalem kalınlıkları (sayfa genişliğine oran): A4'te ≈ 1,2 / 2,4 / 4,8 pt.
  static const _penWidths = [0.002, 0.004, 0.008];

  /// Fosforlu kalınlıkları: A4'te ≈ 8 / 12 / 18 pt (bir satırı örter).
  static const _highlightWidths = [0.014, 0.02, 0.03];

  /// Yazı boyları: A4'te ≈ 10 / 14 / 20 pt.
  static const _textSizes = [0.017, 0.024, 0.034];

  List<PdfMark> _marks = const [];
  final List<List<PdfMark>> _undo = [];
  final List<List<PdfMark>> _redo = [];

  InkTool _tool = InkTool.pen;
  int _penColor = _penColors.first;
  int _highlightColor = _highlightColors.first;
  int _penWidth = 1;
  int _highlightWidth = 1;
  int _textSize = 0;

  late int _page = widget.initialPage - 1;
  final _tx = TransformationController();

  /// Çizilmekte olan darbe (parmak kalkınca [_marks]'a girer).
  InkMark? _live;

  /// Ekrandaki parmak sayısı: ikinci parmak gelirse çizim iptal
  /// (yakınlaştırma hareketi).
  int _pointers = 0;

  /// Silgi sürüklemesi başlamadan önceki durum — tek geri al adımı olsun.
  List<PdfMark>? _eraseStart;

  bool _busy = false;

  @override
  void dispose() {
    _tx.dispose();
    super.dispose();
  }

  // ── Geçmiş ───────────────────────────────────────────────────────────────

  void _commit(List<PdfMark> next, {List<PdfMark>? before}) {
    setState(() {
      _undo.add(before ?? _marks);
      _redo.clear();
      _marks = next;
    });
  }

  void _undoLast() {
    if (_undo.isEmpty) return;
    setState(() {
      _redo.add(_marks);
      _marks = _undo.removeLast();
    });
  }

  void _redoLast() {
    if (_redo.isEmpty) return;
    setState(() {
      _undo.add(_marks);
      _marks = _redo.removeLast();
    });
  }

  // ── Çizim ────────────────────────────────────────────────────────────────

  Offset _norm(Offset local, Size fitted) => Offset(
        (local.dx / fitted.width).clamp(0.0, 1.0),
        (local.dy / fitted.height).clamp(0.0, 1.0),
      );

  void _onDown(PointerDownEvent e, Size fitted) {
    _pointers++;
    if (_pointers > 1) {
      // İki parmak: yakınlaştırma. Yarım darbe bırakma.
      if (_live != null) setState(() => _live = null);
      _finishErase();
      return;
    }
    final point = _norm(e.localPosition, fitted);
    switch (_tool) {
      case InkTool.pen || InkTool.highlighter:
        final hl = _tool == InkTool.highlighter;
        setState(() => _live = InkMark(
              _page,
              points: [point],
              colorArgb: hl ? _highlightColor : _penColor,
              widthFraction: hl
                  ? _highlightWidths[_highlightWidth]
                  : _penWidths[_penWidth],
              highlighter: hl,
            ));
      case InkTool.eraser:
        _eraseStart = _marks;
        _eraseAt(point, fitted);
      case InkTool.text || InkTool.hand:
        break;
    }
  }

  void _onMove(PointerMoveEvent e, Size fitted) {
    if (_pointers != 1) return;
    final point = _norm(e.localPosition, fitted);
    final live = _live;
    if (live != null) {
      // Titreşim noktalarını at: ekranda ~1,5 pikselden kısa adımlar dosyayı
      // şişirir, çizgiye bir şey katmaz.
      final last = live.points.last;
      final dx = (point.dx - last.dx) * fitted.width;
      final dy = (point.dy - last.dy) * fitted.height;
      if (dx * dx + dy * dy < 2.25) return;
      setState(() => _live = live.withPoints([...live.points, point]));
    } else if (_tool == InkTool.eraser) {
      _eraseAt(point, fitted);
    }
  }

  void _onUp(Size fitted) {
    _pointers = math.max(0, _pointers - 1);
    final live = _live;
    if (live != null) {
      _live = null;
      _commit([..._marks, live]);
    }
    _finishErase();
  }

  void _eraseAt(Offset point, Size fitted) {
    final next = eraseMarksAt(
      _marks,
      page: _page,
      point: point,
      // Parmak ucu kadar: ekranda ~14 piksel.
      radius: 14 / fitted.width,
      aspect: fitted.width / fitted.height,
    );
    if (next.length != _marks.length) setState(() => _marks = next);
  }

  void _finishErase() {
    final start = _eraseStart;
    _eraseStart = null;
    if (start == null || identical(start, _marks)) return;
    if (start.length == _marks.length) return;
    setState(() {
      _undo.add(start);
      _redo.clear();
    });
  }

  // ── Yazı ─────────────────────────────────────────────────────────────────

  Future<void> _addTextAt(Offset normalized) async {
    final result = await _askText(initial: '', size: _textSize);
    if (result == null || result.text.trim().isEmpty || !mounted) return;
    _textSize = result.size;
    _commit([
      ..._marks,
      TextMark(
        _page,
        position: normalized,
        text: result.text,
        fontFraction: _textSizes[result.size],
        colorArgb: _penColor,
      ),
    ]);
  }

  Future<void> _editText(TextMark mark) async {
    final sizeIndex = _closestSize(mark.fontFraction);
    final result =
        await _askText(initial: mark.text, size: sizeIndex, allowDelete: true);
    if (result == null || !mounted) return;
    final i = _marks.indexOf(mark);
    if (i < 0) return;
    final next = [..._marks];
    if (result.delete || result.text.trim().isEmpty) {
      next.removeAt(i);
    } else {
      next[i] = mark.copyWith(
          text: result.text, fontFraction: _textSizes[result.size]);
    }
    _commit(next);
  }

  int _closestSize(double fraction) {
    var best = 0;
    for (var i = 1; i < _textSizes.length; i++) {
      if ((_textSizes[i] - fraction).abs() <
          (_textSizes[best] - fraction).abs()) {
        best = i;
      }
    }
    return best;
  }

  Future<({String text, int size, bool delete})?> _askText({
    required String initial,
    required int size,
    bool allowDelete = false,
  }) {
    return showDialog<({String text, int size, bool delete})>(
      context: context,
      builder: (_) => _TextMarkDialog(
          initial: initial, size: size, allowDelete: allowDelete),
    );
  }

  // ── Kaydetme ─────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (_busy) return;
    if (_marks.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final strings = AppStrings.of(context);
    try {
      final bytes = await File(widget.path).readAsBytes();
      final needsFont = _marks.any((m) => m is TextMark);
      final font = needsFont
          ? (await rootBundle.load('assets/fonts/Carlito-Regular.ttf'))
              .buffer
              .asUint8List()
          : null;
      final out = await applyPdfMarks(bytes, _marks, fontBytes: font);
      if (!mounted) return;

      if (showDownloadAction(widget.path)) {
        // Başka uygulamadan açılmış (özel önbellekteki) dosya: üzerine yazmak
        // kullanıcının göremeyeceği bir yere yazmak olurdu → İndirilenler.
        final saved =
            await SaveToDownloads.saveBytes(p.basename(widget.path), out);
        if (!mounted) return;
        showSnackOn(
          messenger,
          strings.t('dl.saved', {'name': p.basename(saved.path)}),
          action: SnackBarAction(
            label: strings.t('ps.open'),
            onPressed: () {
              // Bu ekran kapanmış olacak: gezgin kendi bağlamıyla açar.
              final ctx = navigator.context;
              if (ctx.mounted) EntryOpener.open(ctx, saved.path);
            },
          ),
        );
        _marks = const [];
        navigator.pop(false);
        return;
      }

      setState(() => _busy = false);
      final outcome = await savePdfWithChoice(
        context,
        originalPath: widget.path,
        bytes: out,
        note: strings.t('ink.save_note'),
      );
      if (outcome == null || !mounted) return;
      _marks = const [];
      Navigator.of(context).pop(outcome.overwritten);
    } catch (e) {
      showSnackOn(messenger, strings.t('ink.failed', {'error': '$e'}));
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Kaydedilmemiş iz varken geri tuşu: sor.
  Future<void> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.t('ink.unsaved_title')),
        content: Text(ctx.t('ink.unsaved_body')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, 'discard'),
              child: Text(ctx.t('vw.dont_save'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.t('common.cancel'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'save'),
              child: Text(ctx.t('common.save'))),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _save();
    } else if (choice == 'discard') {
      _marks = const [];
      Navigator.of(context).pop(false);
    }
  }

  // ── Arayüz ───────────────────────────────────────────────────────────────

  void _setPage(int page) {
    setState(() {
      _page = page;
      _live = null;
      _tx.value = Matrix4.identity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _marks.isEmpty && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _confirmLeave();
      },
      child: widget.testPageSizes != null
          ? _scaffold(context, widget.testPageSizes, (_) => const SizedBox())
          : PdfDocumentViewBuilder.file(
              widget.path,
              builder: (context, document) {
                final pages = document?.pages;
                return _scaffold(
                  context,
                  pages == null
                      ? null
                      : [for (final pg in pages) Size(pg.width, pg.height)],
                  (i) => PdfPageView(
                    document: document,
                    pageNumber: i + 1,
                    decoration: const BoxDecoration(color: Colors.white),
                  ),
                );
              },
            ),
    );
  }

  /// [pages] görünen sayfa ölçüleri (yüklenmediyse null); [pageView] sayfa
  /// görüntüsü.
  Widget _scaffold(
    BuildContext context,
    List<Size>? pages,
    Widget Function(int index) pageView,
  ) {
    if (pages != null && pages.isNotEmpty && _page >= pages.length) {
      _page = pages.length - 1;
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.t('ink.title')),
        actions: [
          IconButton(
            tooltip: context.t('common.undo'),
            icon: const Icon(Icons.undo),
            onPressed: _undo.isEmpty || _busy ? null : _undoLast,
          ),
          IconButton(
            tooltip: context.t('ink.redo'),
            icon: const Icon(Icons.redo),
            onPressed: _redo.isEmpty || _busy ? null : _redoLast,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _busy || pages == null ? null : _save,
              icon: const Icon(Icons.save_outlined, size: 18),
              label: Text(context.t('common.save')),
            ),
          ),
        ],
      ),
      body: pages == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_busy) const LinearProgressIndicator(minHeight: 3),
                Expanded(
                  child: ColoredBox(
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: _pageArea(pages[_page], pageView(_page)),
                  ),
                ),
                _toolbar(pages.length),
              ],
            ),
    );
  }

  Widget _pageArea(Size page, Widget pageView) {
    return LayoutBuilder(builder: (context, box) {
      const pad = 8.0;
      final scale = math.min(
        (box.maxWidth - pad * 2) / page.width,
        (box.maxHeight - pad * 2) / page.height,
      );
      final fitted = Size(page.width * scale, page.height * scale);
      final pageMarks = [
        for (final m in _marks)
          if (m.page == _page) m,
      ];
      final drawing = _tool == InkTool.pen ||
          _tool == InkTool.highlighter ||
          _tool == InkTool.eraser;

      return InteractiveViewer(
        transformationController: _tx,
        minScale: 1,
        maxScale: 6,
        // Tek parmak çizerken sayfa kaymasın; iki parmak her araçta
        // yakınlaştırır.
        panEnabled: _tool == InkTool.hand,
        child: Center(
          child: SizedBox(
            width: fitted.width,
            height: fitted.height,
            child: Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: Colors.white, child: pageView),
                ),
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: InkPainter([
                        for (final m in pageMarks)
                          if (m is InkMark) m,
                        if (_live != null) _live!,
                      ]),
                    ),
                  ),
                ),
                if (drawing)
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.opaque,
                      onPointerDown: (e) => _onDown(e, fitted),
                      onPointerMove: (e) => _onMove(e, fitted),
                      onPointerUp: (_) => _onUp(fitted),
                      onPointerCancel: (_) => _onUp(fitted),
                    ),
                  ),
                if (_tool == InkTool.text)
                  Positioned.fill(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapUp: (d) =>
                          _addTextAt(_norm(d.localPosition, fitted)),
                    ),
                  ),
                for (final m in pageMarks)
                  if (m is TextMark) _textItem(m, fitted),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _textItem(TextMark m, Size fitted) {
    final left = m.position.dx * fitted.width;
    final top = m.position.dy * fitted.height;
    final editable = _tool == InkTool.text || _tool == InkTool.eraser;
    final text = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: math.max(1, fitted.width - left)),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: editable
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary, width: 1)
              : null,
        ),
        child: Text(
          m.text,
          style: TextStyle(
            fontFamily: 'Carlito',
            fontSize: m.fontFraction * fitted.width,
            color: Color(m.colorArgb),
          ),
        ),
      ),
    );
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        ignoring: !editable,
        child: GestureDetector(
          onTap: () {
            if (_tool == InkTool.eraser) {
              _commit([
                for (final x in _marks)
                  if (!identical(x, m)) x,
              ]);
            } else {
              _editText(m);
            }
          },
          // Sürükleyerek taşı (yalnız Yazı aracında).
          onPanStart:
              _tool == InkTool.text ? (_) => _eraseStart = _marks : null,
          onPanUpdate: _tool == InkTool.text
              ? (d) {
                  final i = _marks.indexWhere((x) => identical(x, m));
                  if (i < 0) return;
                  final cur = _marks[i] as TextMark;
                  final moved = cur.copyWith(
                    position: Offset(
                      (cur.position.dx + d.delta.dx / fitted.width)
                          .clamp(0.0, 0.98),
                      (cur.position.dy + d.delta.dy / fitted.height)
                          .clamp(0.0, 0.98),
                    ),
                  );
                  setState(() => _marks = [..._marks]..[i] = moved);
                  m = moved;
                }
              : null,
          onPanEnd: _tool == InkTool.text
              ? (_) {
                  final start = _eraseStart;
                  _eraseStart = null;
                  if (start != null && !identical(start, _marks)) {
                    setState(() {
                      _undo.add(start);
                      _redo.clear();
                    });
                  }
                }
              : null,
          child: text,
        ),
      ),
    );
  }

  Widget _toolbar(int pageCount) {
    final scheme = Theme.of(context).colorScheme;
    Widget tool(InkTool t, IconData icon, String label) {
      final selected = _tool == t;
      return Expanded(
        child: InkWell(
          onTap: () => setState(() => _tool = t),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  decoration: BoxDecoration(
                    color: selected ? scheme.secondaryContainer : null,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(icon,
                      size: 22,
                      color: selected
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 2),
                Text(label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        ),
      );
    }

    final hl = _tool == InkTool.highlighter;
    final showColors = _tool == InkTool.pen || hl || _tool == InkTool.text;
    final colors = hl ? _highlightColors : _penColors;
    final selectedColor = hl ? _highlightColor : _penColor;
    final showWidths = _tool == InkTool.pen || hl;
    final widthIndex = hl ? _highlightWidth : _penWidth;

    return Material(
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 44,
              child: Row(
                children: [
                  IconButton(
                    tooltip: context.t('sg.prev_page'),
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _page == 0 ? null : () => _setPage(_page - 1),
                  ),
                  Text('${_page + 1} / $pageCount'),
                  IconButton(
                    tooltip: context.t('mp.next_page'),
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _page >= pageCount - 1
                        ? null
                        : () => _setPage(_page + 1),
                  ),
                  // Dar telefonda (360 dp) renk + kalınlık noktaları sayfa
                  // gezgininin yanına sığmıyordu → gerekirse küçülür.
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: showColors || showWidths
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showColors)
                                    for (final c in colors)
                                      _colorDot(c,
                                          selected: c == selectedColor,
                                          onTap: () {
                                        setState(() {
                                          if (hl) {
                                            _highlightColor = c;
                                          } else {
                                            _penColor = c;
                                          }
                                        });
                                      }),
                                  if (showWidths) ...[
                                    const SizedBox(width: 4),
                                    for (var i = 0; i < 3; i++)
                                      _widthDot(i,
                                          selected: i == widthIndex,
                                          onTap: () {
                                        setState(() {
                                          if (hl) {
                                            _highlightWidth = i;
                                          } else {
                                            _penWidth = i;
                                          }
                                        });
                                      }),
                                  ],
                                ],
                              ),
                            )
                          : Text(
                              context.t(_tool == InkTool.eraser
                                  ? 'ink.eraser_hint'
                                  : 'ink.hand_hint'),
                              textAlign: TextAlign.end,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
            ),
            Row(
              children: [
                tool(InkTool.pen, Icons.edit_outlined, context.t('ink.pen')),
                tool(InkTool.highlighter, Icons.border_color_outlined,
                    context.t('ink.highlighter')),
                tool(InkTool.text, Icons.text_fields, context.t('ink.text')),
                tool(InkTool.eraser, Icons.auto_fix_normal_outlined,
                    context.t('ink.eraser')),
                tool(InkTool.hand, Icons.pan_tool_outlined,
                    context.t('ink.hand')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _colorDot(int argb,
      {required bool selected, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: Color(argb),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 3 : 1,
            ),
          ),
        ),
      ),
    );
  }

  Widget _widthDot(int index,
      {required bool selected, required VoidCallback onTap}) {
    final scheme = Theme.of(context).colorScheme;
    final size = 6.0 + index * 4;
    return InkResponse(
      onTap: onTap,
      radius: 18,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Center(
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
              shape: BoxShape.circle,
            ),
          ),
        ),
      ),
    );
  }
}

/// Yazı ekleme/düzenleme penceresi.
///
/// Denetleyici pencerenin KENDİ ömrüne bağlı: `showDialog` döndükten hemen
/// sonra `dispose` etmek, kapanış animasyonu sürerken metin alanının
/// ölmüş denetleyiciye erişmesine yol açıyordu (test yakaladı).
class _TextMarkDialog extends StatefulWidget {
  const _TextMarkDialog({
    required this.initial,
    required this.size,
    required this.allowDelete,
  });

  final String initial;
  final int size;
  final bool allowDelete;

  @override
  State<_TextMarkDialog> createState() => _TextMarkDialogState();
}

class _TextMarkDialogState extends State<_TextMarkDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  late int _size = widget.size;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.t('ink.text_title')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            decoration: InputDecoration(hintText: context.t('ink.text_hint')),
          ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 0, label: Text(context.t('ink.size_s'))),
              ButtonSegment(value: 1, label: Text(context.t('ink.size_m'))),
              ButtonSegment(value: 2, label: Text(context.t('ink.size_l'))),
            ],
            selected: {_size},
            onSelectionChanged: (s) => setState(() => _size = s.first),
          ),
        ],
      ),
      actions: [
        if (widget.allowDelete)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, (text: '', size: _size, delete: true)),
            child: Text(context.t('common.delete')),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(context.t('common.cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(
              context, (text: _controller.text, size: _size, delete: false)),
          child: Text(context.t('common.ok')),
        ),
      ],
    );
  }
}

/// Kalem/fosforlu izlerini sayfanın üstüne çizer — PDF'e yazılanla aynı
/// kalınlık ve saydamlıkta (bkz. [applyPdfMarks]).
class InkPainter extends CustomPainter {
  InkPainter(this.marks);

  final List<InkMark> marks;

  @override
  void paint(Canvas canvas, Size size) {
    for (final m in marks) {
      if (m.points.isEmpty) continue;
      final color = Color(m.colorArgb);
      final paint = Paint()
        ..color =
            m.highlighter ? color.withValues(alpha: kHighlighterOpacity) : color
        ..blendMode = m.highlighter ? BlendMode.multiply : BlendMode.srcOver
        ..strokeWidth = math.max(0.5, m.widthFraction * size.width)
        ..style = PaintingStyle.stroke
        ..strokeCap = m.highlighter ? StrokeCap.square : StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      final pts = [
        for (final p in m.points) Offset(p.dx * size.width, p.dy * size.height),
      ];
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, paint.strokeWidth / 2,
            paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(InkPainter old) => true;
}

part of '../slides_editor_screen.dart';

/// Faz 29b — küçük resim şeridi ve slayt sıralayıcı (PowerPoint mobil).
///
/// Dikey telefonda şerit altta yatay; yatay ekranda (≥ 600 dp) solda dikey.
/// Uzun basıp sürükle = sırala (`sldIdLst`e yazılır, geri alınabilir). Başka
/// slayta dokunmak oraya gider; GÜNCEL slaytın küçük resmine dokunmak slayt
/// menüsünü açar (yeni / çoğalt / gizle / sil) — PowerPoint mobil de böyle:
/// uzun basış sürüklemeye ayrılmış.
extension _SlidesEditorScreenSorterPart on _SlidesEditorScreenState {
  /// Şerit solda dikey mi (yatay ve geniş ekran)?
  bool get _stripVertical {
    final size = MediaQuery.sizeOf(context);
    return size.width > size.height && size.width >= 600;
  }

  /// Destenin en-boy oranı (ilk slayttan; çizilmemişse 16:9).
  double _stripRatio(PptxEditor editor) {
    final view = editor.slides.isEmpty ? null : editor.slides.first.view;
    return view == null || view.heightPt <= 0 ? 16 / 9 : view.widthPt / view.heightPt;
  }

  /// Küçük resmin genişliği. 2026-11-04 önizleme turu: 100 → 140 (dikey
  /// şeritte 120 → 160) — eski boyda slayt yazısı hiç okunmuyordu. 4:3
  /// destede yatay şeridin yüksekliğine sığacak kadar daralır.
  double _stripThumbW(PptxEditor editor, bool vertical) => vertical
      ? 160.0
      : math.min(140.0, (_stripHeight - 12) * _stripRatio(editor));

  static const double _stripHeight = 100;

  /// Güncel slaytın küçük resmini şeridin ortasına getirir.
  void _followStrip(int index) {
    final editor = _editor;
    if (editor == null || !_stripCtrl.hasClients) return;
    final pos = _stripCtrl.position;
    final vertical = _stripVertical;
    final thumbW = _stripThumbW(editor, vertical);
    final extent =
        vertical ? thumbW / _stripRatio(editor) + 6 : thumbW + 6;
    final start = 6 + index * extent;
    final target = (start - (pos.viewportDimension - extent) / 2)
        .clamp(0.0, pos.maxScrollExtent);
    if ((target - pos.pixels).abs() < 1) return;
    unawaited(Motion.scrollTo(context, _stripCtrl, target));
  }

  Widget _thumbStrip(PptxEditor editor) {
    final vertical = _stripVertical;
    final scheme = Theme.of(context).colorScheme;
    final thumbW = _stripThumbW(editor, vertical);
    return Material(
      key: const ValueKey('sl-strip'),
      color: scheme.surfaceContainerLow,
      shape: vertical
          ? BorderDirectional(end: BorderSide(color: scheme.outlineVariant))
          : Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        width: vertical ? thumbW + 12 : null,
        height: vertical ? null : _stripHeight,
        child: ReorderableListView.builder(
          onReorderStart: (_) => AppHaptics.selection(),
          onReorderEnd: (_) => AppHaptics.step(),
          scrollController: _stripCtrl,
          scrollDirection: vertical ? Axis.vertical : Axis.horizontal,
          buildDefaultDragHandles: false,
          padding: const EdgeInsets.all(6),
          itemCount: editor.slides.length,
          // onReorderItem: [to] zaten çıkarılan öğeye göre düzeltilmiş gelir.
          onReorderItem: (from, to) {
            if (from == to || from >= editor.slides.length) return;
            final slide = editor.slides[from];
            if (_mutate('sl.reorder', () => editor.moveSlideTo(slide, to))) {
              _goToSlide(to + 1);
            }
          },
          itemBuilder: (context, i) {
            final slide = editor.slides[i];
            return ReorderableDelayedDragStartListener(
              key: ValueKey('thumb-${slide.fileName}'),
              index: i,
              enabled: editor.canEditStructure,
              child: Padding(
                padding: vertical
                    ? const EdgeInsets.only(bottom: 6)
                    : const EdgeInsetsDirectional.only(end: 6),
                child: InkWell(
                  borderRadius: BorderRadius.circular(6),
                  onTap: () => i + 1 == _currentSlide
                      ? _openSlideSheet(slide)
                      : _goToSlide(i + 1),
                  child: SizedBox(
                    width: thumbW,
                    child: _slideThumb(context, editor, slide,
                        current: i + 1 == _currentSlide),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Küçük resim / sıralayıcıdaki slayt menüsü.
  Future<void> _openSlideSheet(PptxSlide slide) async {
    final editor = _editor;
    if (editor == null) return;
    final hidden = editor.isHidden(slide);
    final structural = editor.canEditStructure;
    Widget item(String v, IconData icon, String label, {bool enabled = true}) =>
        ListTile(
          key: ValueKey('sl-sheet-$v'),
          enabled: enabled,
          leading: Icon(icon),
          title: Text(label),
          onTap: () => Navigator.pop(context, v),
        );
    final act = await showAppSheet<String>(
      context,
      title: context.t('sl.slide_of',
          {'n': slide.index, 'total': editor.slides.length}),
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          item('new', AppIcons.add, ctx.t('sl.new_slide'), enabled: structural),
          item('dup', AppIcons.copyAll, ctx.t('sl.duplicate'), enabled: structural),
          item('hide', hidden ? AppIcons.hidden : AppIcons.hiddenOff,
              ctx.t(hidden ? 'sl.unhide' : 'sl.hide'),
              enabled: structural),
          item('layout', AppIcons.spaceDashboard, ctx.t('sl.change_layout')),
          item('notes', AppIcons.notes, ctx.t('sl.notes_edit')),
          item('del', AppIcons.delete, ctx.t('sl.delete'),
              enabled: structural && editor.slides.length > 1),
        ],
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'new') {
      await _openLayoutGallery(slide);
    } else if (act == 'layout') {
      await _openLayoutGallery(slide, change: true);
    } else {
      _onSlideAction(slide, act);
    }
  }

  /// Slayt sıralayıcı (ızgara): uzun basıp başka bir slaytın üstüne bırak;
  /// dokun = o slayta git; köşedeki ⋮ = slayt menüsü.
  Future<void> _openSorter() async {
    final editor = _editor;
    if (editor == null) return;
    final open = await Navigator.of(context).push<int>(MaterialPageRoute(
      builder: (_) => _SlideSorterPage(
        editor: editor,
        current: _currentSlide,
        // Faz 38 / madde 7: bölüm adları arkada okunur (sıralayıcı beklemez).
        sections: _proOn ? _sectionStartsOf() : null,
        onMove: (slide, to) =>
            _mutate('sl.reorder', () => editor.moveSlideTo(slide, to)),
        onMenu: _openSlideSheet,
      ),
    ));
    if (open != null && mounted) {
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) await _goToSlide(open);
    }
  }
}

/// Küçük resim: slaytın kendisi (dokunuşsuz), numara, gizliyse soluk + simge.
Widget _slideThumb(BuildContext context, PptxEditor editor, PptxSlide slide,
    {required bool current}) {
  final scheme = Theme.of(context).colorScheme;
  final view = slide.view;
  final hidden = editor.isHidden(slide);
  final ratio = view == null ? 16 / 9 : view.widthPt / view.heightPt;
  return Stack(
    children: [
      AspectRatio(
        aspectRatio: ratio,
        child: Container(
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: AppColors.page,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: current ? scheme.primary : scheme.outlineVariant,
              width: current ? 2.5 : 1,
            ),
          ),
          foregroundDecoration: hidden
              ? BoxDecoration(color: scheme.surface.withValues(alpha: 0.5))
              : null,
          // RepaintBoundary: ana görünümde yazı yazarken / kaydırırken şeritteki
          // onlarca küçük slayt yeniden boyanmasın.
          child: view == null
              ? const SizedBox.expand()
              : RepaintBoundary(
                  child: IgnorePointer(child: SlideCanvas(slide: view))),
        ),
      ),
      PositionedDirectional(
        start: 3,
        bottom: 3,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: current ? scheme.primary : AppColors.mediaScrim,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (hidden) ...[
                Icon(AppIcons.hiddenOff,
                    size: 10,
                    color: current ? scheme.onPrimary : AppColors.onMedia),
                const SizedBox(width: 2),
              ],
              Text(
                '${slide.index}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: current ? scheme.onPrimary : AppColors.onMedia),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}

class _SlideSorterPage extends StatefulWidget {
  final PptxEditor editor;
  final int current;
  final bool Function(PptxSlide slide, int to) onMove;
  final Future<void> Function(PptxSlide slide) onMenu;

  /// Slayt sırası → o slaytta başlayan bölümün adı.
  final Future<Map<int, String>>? sections;

  const _SlideSorterPage({
    required this.editor,
    required this.current,
    required this.onMove,
    required this.onMenu,
    this.sections,
  });

  @override
  State<_SlideSorterPage> createState() => _SlideSorterPageState();
}

class _SlideSorterPageState extends State<_SlideSorterPage> {
  late int _current = widget.current;
  Map<int, String> _sections = const {};

  @override
  void initState() {
    super.initState();
    widget.sections?.then((v) {
      if (mounted) setState(() => _sections = v);
    }, onError: (_) {});
  }

  @override
  Widget build(BuildContext context) {
    final editor = widget.editor;
    final scheme = Theme.of(context).colorScheme;
    final canMove = editor.canEditStructure;
    return Scaffold(
      appBar: AppBar(title: Text(context.t('sl.sorter'))),
      body: LayoutBuilder(builder: (context, box) {
        final cols = math.max(2, (box.maxWidth / 170).floor());
        return GridView.builder(
          padding: withNavInset(context, const EdgeInsets.all(12)),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 16 / 10,
          ),
          itemCount: editor.slides.length,
          itemBuilder: (context, i) {
            final slide = editor.slides[i];
            final tile = InkWell(
              key: ValueKey('sorter-${slide.fileName}'),
              onTap: () => Navigator.pop(context, i + 1),
              child: Stack(
                children: [
                  Align(
                    alignment: Alignment.topCenter,
                    child: _slideThumb(context, editor, slide,
                        current: i + 1 == _current),
                  ),
                  if (_sections[i] case final name?)
                    PositionedDirectional(
                      top: 2,
                      start: 2,
                      end: 40,
                      child: Container(
                        key: ValueKey('sorter-section-$i'),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: scheme.primaryContainer,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('§ $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.type.caption
                                .copyWith(color: scheme.onPrimaryContainer)),
                      ),
                    ),
                  // Uzun basış sürüklemeye ayrıldı; menü köşedeki düğmede.
                  PositionedDirectional(
                    top: 0,
                    end: 0,
                    child: IconButton.filledTonal(
                      key: ValueKey('sorter-menu-${slide.fileName}'),
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      tooltip: context.t('sl.actions'),
                      icon: const Icon(AppIcons.more),
                      onPressed: () async {
                        setState(() => _current = i + 1);
                        await widget.onMenu(slide);
                        if (mounted) setState(() {});
                      },
                    ),
                  ),
                ],
              ),
            );
            if (!canMove) return tile;
            return DragTarget<int>(
              onWillAcceptWithDetails: (d) => d.data != i,
              onAcceptWithDetails: (d) {
                if (d.data >= editor.slides.length) return;
                if (widget.onMove(editor.slides[d.data], i)) {
                  AppHaptics.step();
                  setState(() => _current = i + 1);
                }
              },
              builder: (context, cand, _) => LongPressDraggable<int>(
                data: i,
                hapticFeedbackOnStart: false,
                onDragStarted: AppHaptics.selection,
                feedback: Material(
                  elevation: 6,
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: box.maxWidth / cols - 12,
                    child: _slideThumb(context, editor, slide, current: true),
                  ),
                ),
                childWhenDragging: Opacity(opacity: 0.3, child: tile),
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    border: cand.isEmpty
                        ? null
                        : BorderDirectional(
                            start: BorderSide(color: scheme.primary, width: 4)),
                  ),
                  child: tile,
                ),
              ),
            );
          },
        );
      }),
    );
  }
}

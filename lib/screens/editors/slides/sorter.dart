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

  Widget _thumbStrip(PptxEditor editor) {
    final vertical = _stripVertical;
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('sl-strip'),
      color: scheme.surfaceContainerLow,
      shape: vertical
          ? BorderDirectional(end: BorderSide(color: scheme.outlineVariant))
          : Border(top: BorderSide(color: scheme.outlineVariant)),
      child: SizedBox(
        width: vertical ? 132 : null,
        height: vertical ? null : 76,
        child: ReorderableListView.builder(
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
            final thumbW = vertical ? 120.0 : 100.0;
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
          item('notes', AppIcons.notes, ctx.t('sl.notes_edit')),
          item('del', AppIcons.delete, ctx.t('sl.delete'),
              enabled: structural && editor.slides.length > 1),
        ],
      ),
    );
    if (act == null || !mounted) return;
    if (act == 'new') {
      await _openLayoutGallery(slide);
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
          child: view == null
              ? const SizedBox.expand()
              : IgnorePointer(child: SlideCanvas(slide: view)),
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

  const _SlideSorterPage({
    required this.editor,
    required this.current,
    required this.onMove,
    required this.onMenu,
  });

  @override
  State<_SlideSorterPage> createState() => _SlideSorterPageState();
}

class _SlideSorterPageState extends State<_SlideSorterPage> {
  late int _current = widget.current;

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
                  setState(() => _current = i + 1);
                }
              },
              builder: (context, cand, _) => LongPressDraggable<int>(
                data: i,
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

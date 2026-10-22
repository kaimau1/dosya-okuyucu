part of '../pdf_ink_screen.dart';

extension _PdfInkScreenViewsPart on _PdfInkScreenState {
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
            icon: const Icon(AppIcons.undo),
            onPressed: _undo.isEmpty || _busy ? null : _undoLast,
          ),
          IconButton(
            tooltip: context.t('ink.redo'),
            icon: const Icon(AppIcons.redo),
            onPressed: _redo.isEmpty || _busy ? null : _redoLast,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _busy || pages == null ? null : _save,
              icon: const Icon(AppIcons.save, size: 18),
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
                    // Dış dinleyici arenaya girmez: iki parmak hareketini
                    // izler, tek parmak çizime kalır.
                    child: Listener(
                      onPointerDown: (e) => _gDown(e, pages.length),
                      onPointerMove: _gMove,
                      onPointerUp: (e) => _gUp(e, pages.length),
                      onPointerCancel: (e) => _gUp(e, pages.length),
                      child: _pageArea(pages[_page], pageView(_page)),
                    ),
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
        key: _viewportKey,
        transformationController: _tx,
        minScale: 1,
        maxScale: 6,
        // Çizim araçlarında InteractiveViewer'ın hareketleri KAPALI: tek
        // parmak çizer, iki parmağı yukarıdaki dinleyici işler (kaydır +
        // yakınlaştır). Öteki araçlarda (yazı, kaydır) olağan davranış.
        panEnabled: _tool == InkTool.hand || _tool == InkTool.text,
        scaleEnabled: !drawing,
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
                  _partSetState(() => _marks = [..._marks]..[i] = moved);
                  m = moved;
                }
              : null,
          onPanEnd: _tool == InkTool.text
              ? (_) {
                  final start = _eraseStart;
                  _eraseStart = null;
                  if (start != null && !identical(start, _marks)) {
                    _partSetState(() {
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
          onTap: () => _partSetState(() => _tool = t),
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
    final colors = hl ? _PdfInkScreenState._highlightColors : _PdfInkScreenState._penColors;
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
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _page == 0 ? null : () => _setPage(_page - 1),
                  ),
                  Text('${_page + 1} / $pageCount'),
                  IconButton(
                    tooltip: context.t('mp.next_page'),
                    icon: const Icon(AppIcons.chevron),
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
                                        _partSetState(() {
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
                                        _partSetState(() {
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
                tool(InkTool.pen, AppIcons.edit, context.t('ink.pen')),
                tool(InkTool.highlighter, Icons.border_color_rounded,
                    context.t('ink.highlighter')),
                tool(InkTool.text, AppIcons.textFields, context.t('ink.text')),
                tool(InkTool.eraser, Icons.auto_fix_normal_rounded,
                    context.t('ink.eraser')),
                tool(InkTool.hand, Icons.pan_tool_rounded,
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

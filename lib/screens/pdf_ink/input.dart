part of '../pdf_ink_screen.dart';

extension _PdfInkScreenInputPart on _PdfInkScreenState {
  void _onDown(PointerDownEvent e, Size fitted) {
    _pointers++;
    if (_pointers > 1) {
      // İki parmak: yakınlaştırma. Yarım darbe bırakma.
      if (_live != null) _partSetState(() => _live = null);
      _finishErase();
      return;
    }
    final point = _norm(e.localPosition, fitted);
    switch (_tool) {
      case InkTool.pen || InkTool.highlighter:
        final hl = _tool == InkTool.highlighter;
        _partSetState(() => _live = InkMark(
              _page,
              points: [point],
              colorArgb: hl ? _highlightColor : _penColor,
              widthFraction: hl
                  ? _PdfInkScreenState._highlightWidths[_highlightWidth]
                  : _PdfInkScreenState._penWidths[_penWidth],
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
      _partSetState(() => _live = live.withPoints([...live.points, point]));
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
    if (next.length != _marks.length) _partSetState(() => _marks = next);
  }

  void _finishErase() {
    final start = _eraseStart;
    _eraseStart = null;
    if (start == null || identical(start, _marks)) return;
    if (start.length == _marks.length) return;
    _partSetState(() {
      _undo.add(start);
      _redo.clear();
    });
  }

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
        fontFraction: _PdfInkScreenState._textSizes[result.size],
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
          text: result.text, fontFraction: _PdfInkScreenState._textSizes[result.size]);
    }
    _commit(next);
  }

  int _closestSize(double fraction) {
    var best = 0;
    for (var i = 1; i < _PdfInkScreenState._textSizes.length; i++) {
      if ((_PdfInkScreenState._textSizes[i] - fraction).abs() <
          (_PdfInkScreenState._textSizes[best] - fraction).abs()) {
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

  Future<void> _save() async {
    if (_busy) return;
    if (_marks.isEmpty) {
      Navigator.of(context).pop(false);
      return;
    }
    _partSetState(() => _busy = true);
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

      _partSetState(() => _busy = false);
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
      showSnackOn(messenger, strings.t('ink.failed', {'error': userErrorText(e)}));
      if (mounted) _partSetState(() => _busy = false);
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

  void _setPage(int page) {
    _partSetState(() {
      _page = page;
      _live = null;
      _tx.value = Matrix4.identity();
    });
  }

  Offset _toViewport(Offset global) {
    final box = _viewportKey.currentContext?.findRenderObject();
    return box is RenderBox ? box.globalToLocal(global) : global;
  }

  Size get _viewportSize {
    final box = _viewportKey.currentContext?.findRenderObject();
    return box is RenderBox && box.hasSize ? box.size : Size.zero;
  }

  bool get _drawingTool =>
      _tool == InkTool.pen ||
      _tool == InkTool.highlighter ||
      _tool == InkTool.eraser;

  void _gDown(PointerDownEvent e, int pageCount) {
    _touches[e.pointer] = e.position;
    if (_touches.length == 1 && _tool == InkTool.hand) {
      _handStart = e.position;
    }
    if (_touches.length == 2) {
      _handStart = null;
      final pts = _touches.values.toList();
      _g0Focal = _toViewport((pts[0] + pts[1]) / 2);
      _g0Dist = math.max(1, (pts[0] - pts[1]).distance);
      _g0Matrix = _tx.value.clone();
      _g0Scale = _g0Matrix!.getMaxScaleOnAxis();
      _flipDy = 0;
      _flipArmed = _g0Scale < 1.05;
    }
  }

  void _gMove(PointerMoveEvent e) {
    if (!_touches.containsKey(e.pointer)) return;
    _touches[e.pointer] = e.position;
    final start = _g0Matrix;
    // Çizim araçlarında iki parmak hareketini biz işleriz; öteki araçlarda
    // InteractiveViewer'ın kendisi (panEnabled/scaleEnabled açık).
    if (_touches.length != 2 || start == null || !_drawingTool) return;
    final pts = _touches.values.toList();
    final focal = _toViewport((pts[0] + pts[1]) / 2);
    final dist = (pts[0] - pts[1]).distance;
    final scale = (_g0Scale * dist / _g0Dist).clamp(1.0, 6.0);
    final ratio = scale / _g0Scale;
    final next = (Matrix4.identity()
          ..translateByDouble(focal.dx, focal.dy, 0, 1)
          ..scaleByDouble(ratio, ratio, 1, 1)
          ..translateByDouble(-_g0Focal.dx, -_g0Focal.dy, 0, 1)) *
        start;
    _tx.value = _clampToViewport(next);
    if (_flipArmed) {
      // Parmaklar açılıp kapanıyorsa bu yakınlaştırmadır, sayfa çevirme değil.
      if ((dist / _g0Dist - 1).abs() > 0.15) _flipArmed = false;
      _flipDy = focal.dy - _g0Focal.dy;
    }
  }

  void _gUp(PointerEvent e, int pageCount) {
    final pos = _touches.remove(e.pointer);
    if (_g0Matrix != null && _touches.length < 2) {
      if (_flipArmed && _tx.value.getMaxScaleOnAxis() < 1.05) {
        _maybeFlip(-_flipDy, pageCount);
      }
      _g0Matrix = null;
      _flipArmed = false;
    }
    final hand = _handStart;
    if (hand != null && _touches.isEmpty && pos != null) {
      _handStart = null;
      if (_tx.value.getMaxScaleOnAxis() < 1.05) {
        _maybeFlip(hand.dy - pos.dy, pageCount);
      }
    }
  }

  /// [up] parmakların yukarı yolu (pozitif = sonraki sayfa).
  void _maybeFlip(double up, int pageCount) {
    if (up.abs() < 90) return;
    if (up > 0 && _page < pageCount - 1) {
      _setPage(_page + 1);
    } else if (up < 0 && _page > 0) {
      _setPage(_page - 1);
    }
  }

  /// Yakınlaştırılmış sayfa görünümün dışına kaçmasın.
  Matrix4 _clampToViewport(Matrix4 m) {
    final size = _viewportSize;
    final s = m.getMaxScaleOnAxis();
    if (size.isEmpty || s <= 1.0001) return Matrix4.identity();
    final t = m.getTranslation();
    final tx = t.x.clamp(size.width * (1 - s), 0.0);
    final ty = t.y.clamp(size.height * (1 - s), 0.0);
    return m.clone()..setTranslationRaw(tx, ty, t.z);
  }
}

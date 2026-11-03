part of '../viewer_screen.dart';

extension _ViewerScreenPdfMarksPart on _ViewerScreenState {
  /// Açık sayfayı çeyrek tur döndürür ([quarterTurns] −1 sola, +1 sağa).
  ///
  /// Kayıpsız: sayfanın `/Rotate` girdisi değişir, içerik yeniden ÇİZİLMEZ.
  /// Değişiklik bekleyen düzenleme olarak durur; çıkarken bir kez sorulur —
  /// metin düzenleme ve vurgulama ile aynı akış.
  Future<void> _rotateCurrentPage(int quarterTurns) async {
    if (_pdfBusy || _pdfWriting > 0) return;
    // Bekleyen vurgular önce dosyaya: döndürme koordinatları değiştirir.
    if (!await _flushPendingMarks() || !mounted) return;
    final page = _livePdfPage() ?? _pdfPage;
    if (page < 1) return;
    _partSetState(() => _pdfBusy = true);
    try {
      final bytes = await _fileService.readBytes(widget.doc.path);
      final out = await PdfTools.rotatePagesInBackground(
        bytes,
        pageIndexes: [page - 1],
        quarterTurns: quarterTurns,
      );
      if (!mounted) return;
      await _writePending(out);
      if (mounted) {
        _snack(context.t(
            quarterTurns < 0 ? 'vw.rotated_left' : 'vw.rotated_right',
            {'n': page}));
      }
    } catch (e) {
      if (mounted) _snack(context.t('vw.rotate_failed', {'error': userErrorText(e)}));
    } finally {
      if (mounted) _partSetState(() => _pdfBusy = false);
    }
  }

  /// **Vurgula** — son kullanılan renkle, ANINDA, belgeyi yeniden
  /// yüklemeden (bkz. [_pendingMarks]). Seçim kapanmaz: çubuk vurgu kipine
  /// geçer, renk değiştirilebilir ya da tek dokunuşla geri alınabilir
  /// (kullanıcı: *"yanlışlıkla basarsan hemen vurgulama yapılıp düzenleme
  /// ekranı kapanıyor"*).
  void _highlightPdf() {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    if (rects.isEmpty || page < 1) return;
    AppHaptics.selection();
    _partSetState(() {
      final mark = _PendingMark(page, List.of(rects), _highlightColor);
      _pendingMarks.add(mark);
      _lastMark = mark;
    });
  }

  /// Vurgu kipinde renk: az önceki vurgunun rengi değişir ve sonrakiler için
  /// hatırlanır.
  void _recolorLastMark(int argb) {
    _partSetState(() {
      _highlightColor = argb;
      _lastHighlightColor = argb;
      _lastMark?.color = argb;
    });
  }

  /// Vurgu kipinde Geri al.
  void _undoLastMark() {
    final mark = _lastMark;
    if (mark == null) return;
    _partSetState(() {
      _pendingMarks.remove(mark);
      _lastMark = null;
    });
  }

  /// Seçimin **yerinde** çevirisi (kart; eski üç pencereli akış yerine).
  void _translateSelection() {
    final text = cleanPdfCopyText(_pdfSelection);
    if (text.isEmpty) return;
    QuickTranslateSheet.show(context, text,
        title: context.t('vw.selected_text'));
  }

  /// Seçim hakkında AI'ya sor (açıkla / basitleştir / özetle / terimler).
  Future<void> _askAiAboutSelection() async {
    final text = cleanPdfCopyText(_pdfSelection);
    if (text.isEmpty) return;
    await _ensurePdfText();
    if (!mounted) return;
    QuickAiSheet.show(
      context,
      selection: text,
      documentName: widget.doc.name,
      documentText: _documentText,
    );
  }

  /// Seçilen ifadeyi belgenin TAMAMINDA arar (arama çubuğunu açar).
  void _findSelection() {
    final text = cleanPdfCopyText(_pdfSelection).split('\n').first.trim();
    if (text.isEmpty) return;
    _clearPdfSelection();
    if (!_findOpen) _toggleFind();
    _findCtl.text = text;
    _runFind(text);
  }

  /// Seçimi kapatır (vurgular kalır).
  void _clearPdfSelection() {
    _partSetState(() {
      _pdfSelection = '';
      _pdfSelRects = const [];
      _lastMark = null;
    });
  }

  /// Bekleyen vurguları sayfanın üstüne çizer.
  ///
  /// Çarpımsal harman: yazının siyahı siyah kalır, yalnız kağıt boyanır —
  /// dosyaya yazılan vurgunun (pdfium'un çizdiği) görünümüyle aynı.
  void _paintPendingMarks(Canvas canvas, Rect pageRect, PdfPage page) {
    if (_pendingMarks.isEmpty) return;
    for (final m in _pendingMarks) {
      if (m.page != page.pageNumber) continue;
      final paint = Paint()
        ..color = Color(m.color)
            .withValues(alpha: PdfAnnotator.highlightOpacity)
        ..blendMode = BlendMode.multiply;
      for (final r in m.rects) {
        canvas.drawRect(
            r.toRectInPageRect(page: page, pageRect: pageRect), paint);
      }
    }
  }
}

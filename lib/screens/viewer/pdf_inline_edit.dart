part of '../viewer_screen.dart';

extension _ViewerScreenPdfInlineEditPart on _ViewerScreenState {
  /// Seçili metnin **tam üstünde** düzenleme kutusunu açar.
  ///
  /// Ayrı bir ekran açılmıyor: kullanıcı sayfayı görmeye devam ediyor, klavye
  /// geliyor ve yazdığı şey belgenin kendi metni oluyor (bkz. [PdfInlineEditor],
  /// `PdfContentEditor`). Sayfanın geri kalanına dokunulmaz — belgenin tamamını
  /// yeniden yazan "AI ile düzenle"den farkı budur.
  void _startInlineEdit() {
    final rects = _pdfSelRects;
    final page = _pdfSelPage;
    final text = _pdfSelection.trim();
    if (rects.isEmpty || page < 1 || text.isEmpty) return;
    _pdfEditCtl?.dispose();
    _pdfEditFocus?.dispose();
    _pdfEditFocus = FocusNode(debugLabel: 'pdf-inline-edit');
    // Kutu bir sonraki karede çiziliyor; odak ondan SONRA isteniyor.
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusInlineEdit());
    _partSetState(() {
      // Metin baştan seçili: kullanıcı doğrudan yazmaya başlayabilir
      // (Word'de bir kelimeye çift tıklamak gibi).
      _pdfEditCtl = TextEditingController(text: text)
        ..selection = TextSelection(baseOffset: 0, extentOffset: text.length);
      _pdfEdit = _InlineEdit(
        page: page,
        rects: rects,
        original: text,
        preceding: _pdfSelPreceding,
      );
      _pdfSelection = '';
      _pdfSelRects = const [];
    });
    // Düzenlenen satır düzenleme çubuğunun (ve birazdan klavyenin) üstünde
    // kalsın — klavye açılınca [_onPdfViewSizeChanged] yeniden hizalar.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _revealAboveBar(page, rects, barHeight: 170);
    });
    _pdfEditFont = null;
    unawaited(_probeEditFont(page, rects));
  }

  /// Düzenlenen satırın yazı tipini belgeden yoklar (arka planda). Çok büyük
  /// belgede (e-kitap) atlanır: yalnız önizleme için bütün dosyayı
  /// ayrıştırmaya değmez — kaydederken yedek yol zaten ölçüyor.
  Future<void> _probeEditFont(int page, List<PdfRect> rects) async {
    if (_docSize > 30 * 1024 * 1024 || rects.isEmpty) return;
    try {
      final bytes = await File(widget.doc.path).readAsBytes();
      final r = rects.first;
      final probe = await PdfPageEdit.textStyleAtInBackground(bytes, page - 1,
          (r.left + r.right) / 2, (r.top + r.bottom) / 2);
      if (!mounted || _pdfEdit == null || probe.font.isEmpty) return;
      _partSetState(() => _pdfEditFont = PdfFontClass.of(probe.font));
    } catch (_) {}
  }

  void _cancelInlineEdit() {
    FocusScope.of(context).unfocus();
    _pdfEditCtl?.dispose();
    _pdfEditFocus?.dispose();
    _partSetState(() {
      _pdfEdit = null;
      _pdfEditCtl = null;
      _pdfEditFocus = null;
    });
  }

  /// Görüntü küçüldü (klavye açıldı): düzenlenen satırı görünür alana getir.
  ///
  /// pdfrx görüntü boyu değişince sayfayı kendi başına hizalıyor
  /// (`_goToPage`); sayfanın alt yarısındaki bir satır bu hizalamayla
  /// klavyenin ve düzenleme çubuğunun ARKASINDA kalıyordu — kullanıcı ne
  /// yazdığını göremiyordu. Bu geri çağrı pdfrx'in hizalamasından SONRA gelir.
  void _onPdfViewSizeChanged(
      Size viewSize, Size? oldSize, PdfViewerController controller) {
    final edit = _pdfEdit;
    if (edit == null || oldSize == null || viewSize.height >= oldSize.height) {
      return;
    }
    try {
      Rect? area;
      for (final r in edit.rects) {
        final rect = controller.calcRectForRectInsidePage(
            pageNumber: edit.page, rect: r);
        area = area == null ? rect : area.expandToInclude(rect);
      }
      if (area == null) return;
      // Alt çubuk (~150 dp) satırın altına düşmesin diye pay; belge
      // koordinatında olduğu için yakınlaştırmaya bölünüyor.
      final zoom = controller.currentZoom <= 0 ? 1.0 : controller.currentZoom;
      controller.ensureVisible(
        Rect.fromLTRB(area.left, area.top - 24 / zoom, area.right,
            area.bottom + 170 / zoom),
      );
    } catch (_) {
      // Görüntüleyici henüz hazır değilse sessizce atla.
    }
  }

  /// Klavyeyi açar (ve düşen odağı geri alır).
  ///
  /// Odak zaten kutudaysa da klavyeyi GÖSTERİR: eskiden
  /// `if (!hasFocus) requestFocus()` idi ve klavye geri tuşuyla kapandıktan
  /// sonra ◀ ▶ / "tümünü seç" klavyeyi bir daha açmıyordu (2026-09-24).
  void _focusInlineEdit() {
    final node = _pdfEditFocus;
    if (node == null || !mounted || _pdfEdit == null) return;
    PdfInlineEditor.showKeyboard(_pdfEditFieldKey.currentContext, node);
  }

  /// Alt çubuktaki ✓ (ve klavyenin "bitti" tuşu).
  ///
  /// **Boş kutu = metni sil.** Eskiden boş metinde hiçbir şey olmuyordu:
  /// kullanıcı "tümünü seç" + sil yapıp Uygula'ya basıyor, çubuk tepki
  /// vermiyordu ("uygulaya basmak işlevsiz", 2026-09-24). İçerik düzenleyici
  /// boşla değiştirmeyi zaten destekliyor (`pdf_content_editor_test`).
  void _submitInlineEdit() {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    _applyInlineEdit(ctl.text);
  }

  /// Kutudaki metni AI'a yeniden yazdırır.
  Future<void> _rewriteInlineEdit() async {
    final ctl = _pdfEditCtl;
    if (ctl == null) return;
    final result = await showAiRewriteSheet(context, ctl.text);
    if (result != null && result.isNotEmpty && mounted) {
      _partSetState(() => ctl.text = result);
    }
    // AI sayfası kapanınca odak kutuya geri döner; yoksa kullanıcı yazmaya
    // devam etmek için kutuya bir kez daha dokunmak zorunda kalıyordu.
    if (mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusInlineEdit());
    }
  }

  /// Kutudaki metni belgeye işler.
  ///
  /// **Kaydetmez, sormaz:** sonuç çalışma kopyasına yazılır ve hemen ekranda
  /// görünür. Kullanıcı arka arkaya düzeltme yapabilsin diye
  /// (2026-07-26 isteği); nasıl kaydedileceği çıkarken bir kez sorulur.
  Future<void> _applyInlineEdit(String newText) async {
    final edit = _pdfEdit;
    if (edit == null || _pdfEditBusy) return;
    if (newText.trim() == edit.original.trim()) {
      _cancelInlineEdit();
      return;
    }
    FocusScope.of(context).unfocus();
    _partSetState(() => _pdfEditBusy = true);
    // Bekleyen vurgular önce dosyaya: düzenleme dosyanın baytlarıyla çalışır.
    if (!await _flushPendingMarks()) {
      if (mounted) _partSetState(() => _pdfEditBusy = false);
      return;
    }
    if (!mounted) return;
    try {
      final applied = await PdfEditFlow.apply(
        context,
        path: widget.doc.path,
        pageIndex: edit.page - 1,
        // PdfRect → düz sayı listesi: servis katmanı pdfrx'i tanımıyor ve bu
        // biçim isolate sınırından sorunsuz geçiyor.
        rawRects: [
          for (final r in edit.rects) [r.left, r.top, r.right, r.bottom],
        ],
        oldText: edit.original,
        newText: newText.trim(),
        precedingText: edit.preceding,
      );
      if (!mounted) return;
      if (applied != null) {
        _pdfEditCtl?.dispose();
        _pdfEditFocus?.dispose();
        _pdfEditCtl = null;
        _pdfEditFocus = null;
      }
      _partSetState(() {
        _pdfEditBusy = false;
        if (applied != null) _pdfEdit = null;
      });
      if (applied == null) return;
      await _writePending(applied.bytes);
      if (mounted) _snack(applied.note);
    } catch (e) {
      if (!mounted) return;
      _partSetState(() => _pdfEditBusy = false);
      _snack(context.t('vw.change_failed', {'error': e}));
    }
  }

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
      if (mounted) _snack(context.t('vw.rotate_failed', {'error': e}));
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
    HapticFeedback.selectionClick();
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
  void _askAiAboutSelection() {
    final text = cleanPdfCopyText(_pdfSelection);
    if (text.isEmpty) return;
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

  /// Seçim (ya da düzenlenen satır) alttaki çubuğun ARKASINDA kalmasın.
  ///
  /// Kullanıcı: *"alt alanda bir yazı seçtiğimde düzenleme alanı açılınca
  /// yazı altta kalıyor, ona göre sayfa odağı değişmeli."* Çubuk sayfanın
  /// üstünde yüzüyor; seçilen satır ekranın alt ~yarısındaysa çubuğun altında
  /// kalıyordu. [barHeight] kadar pay bırakılarak satır görünür alana
  /// kaydırılır (yakınlaştırma değişmez, en az kaydırma).
  void _revealAboveBar(int page, List<PdfRect> rects,
      {double barHeight = 190}) {
    if (rects.isEmpty || page < 1) return;
    try {
      Rect? area;
      for (final r in rects) {
        final rect =
            _pdfController.calcRectForRectInsidePage(pageNumber: page, rect: r);
        area = area == null ? rect : area.expandToInclude(rect);
      }
      if (area == null) return;
      final zoom =
          _pdfController.currentZoom <= 0 ? 1.0 : _pdfController.currentZoom;
      final visible = _pdfController.visibleRect;
      final want = Rect.fromLTRB(area.left, area.top - 24 / zoom, area.right,
          area.bottom + (barHeight + 24) / zoom);
      // Çok uzun seçim (ekrandan büyük) için kaydırma anlamsız; pdfrx o
      // durumda yakınlaştırmayı değiştirirdi.
      if (want.height >= visible.height) return;
      if (want.bottom <= visible.bottom && want.top >= visible.top) return;
      _pdfController.ensureVisible(want);
    } catch (_) {
      // Görüntüleyici henüz hazır değilse sessizce atla.
    }
  }
}

part of '../viewer_screen.dart';

/// **PDF okuma konforu** (Ferrari H3, 2026-11-14): çift dokunma, akıllı
/// yakınlaştırma, görsel kipi, kenar boşluğu kırpma, sayfa sayfa geçiş. Hesap saf serviste ([PdfReadingZoom]); sayfa nesneleri
/// PDF Pro'nun okumasından ([PdfEditBridge.content]) — yeniden yazılmadı.
/// Burada yalnız görüntüleyiciye bağlantı.
extension _ViewerScreenPdfComfortPart on _ViewerScreenState {
  /// pdfrx'in genel dokunuş kancası. pdfrx'in kendi çift dokunuş tanıyıcısı
  /// zaten kurulu (`onDoubleTapDown`) — ek jest arenası yok. true = işlendi.
  bool _onPdfGeneralTap(BuildContext _, PdfViewerController _,
      PdfViewerGeneralTapHandlerDetails d) {
    // Düzenleme kipinde blok katmanının kendi çift dokunuşu var; seçim
    // sürüklenirken yakınlık değişmesin.
    if (_pro != null || _pdfSelecting) return false;
    switch (d.type) {
      case PdfViewerGeneralTapType.tap:
        // Sayfa sayfa kipi: kenara dokunuş sayfa çevirir (H3.5).
        final dir = _pagedEdgeDirection(d.localPosition.dx);
        if (dir == 0) return false;
        _turnPdfPage(dir);
        return true;
      case PdfViewerGeneralTapType.doubleTap:
        unawaited(_pdfDoubleTapZoom(d.localPosition, d.documentPosition));
        return true;
      case PdfViewerGeneralTapType.longPress:
        // Seçim katmanı uzun basışı kendisi ölçer (metin seçimi); burada
        // yalnız görsel aranır — pdfrx'in varsayılanı değişmesin (false).
        unawaited(_offerImageZoom(d.documentPosition));
        return false;
      default:
        return false;
    }
  }

  /// Belgenin tamamını genişliğe sığdıran yakınlık (çok sütunda düzenin
  /// tamamı — [_fitPdfWidth] ile aynı ölçü).
  double? get _pdfFitWidthZoom {
    if (!_pdfController.isReady) return null;
    final doc = _pdfController.documentSize;
    final view = _pdfController.viewSize;
    if (doc.width <= 0 || view.width <= 0) return null;
    return view.width / doc.width;
  }

  /// **Çift dokunma** (H3.1): genişliğe sığmışken dokunulan noktaya ~2,5×
  /// yakınlaşır (nokta parmağın altında kalır); yakınken genişliğe sığar
  /// (dokunulan satır yerinde kalır). Animasyon [Motion.medium].
  ///
  /// **Akıllı yakınlaştırma** (H3.2): dokunulan yerde bir metin sütunu ya
  /// da görsel kutusu bulunursa o kutu ekran genişliğine oturur (iki sütunlu
  /// makalede tek sütun); bulunamazsa H3.1 davranışı.
  Future<void> _pdfDoubleTapZoom(Offset local, Offset docPos) async {
    final fit = _pdfFitWidthZoom;
    if (fit == null) return;
    final c = _pdfController;
    final current = c.currentZoom;
    AppHaptics.selection();
    try {
      // Sayfa sayfa kipinde "geri sığdır" = sayfanın tamamı (H3.5).
      if (_pagedActive && _pagedZoomed) {
        await _showPagedPage(_livePdfPage() ?? _pdfPage);
        return;
      }
      if (!_pagedActive && PdfReadingZoom.isZoomedIn(current, fit)) {
        await _zoomKeepingRow(fit, docPos, local,
            centerX: c.documentSize.width / 2);
        return;
      }
      final smart = await _smartZoomTarget(docPos, current);
      if (!mounted) return;
      if (!c.isReady) return;
      if (smart != null) {
        await _zoomKeepingRow(smart.zoom, docPos, local,
            centerX: smart.centerX);
        return;
      }
      await c.zoomOnLocalPosition(
          localPosition: local,
          newZoom: PdfReadingZoom.zoomInTarget(current, c.maxScale),
          duration: Motion.of(context, Motion.medium));
    } catch (_) {
      // Bilinçli: belge o an yeniden yükleniyor olabilir — yakınlık kritik değil.
    }
    if (mounted) _recordPdfZoom();
  }

  /// [zoom]'a geç: yatayda [centerX] ortalanır, dokunulan satır ([docPos],
  /// ekranda [local]) dikeyde yerinde kalır.
  Future<void> _zoomKeepingRow(double zoom, Offset docPos, Offset local,
      {required double centerX}) async {
    final c = _pdfController;
    final cy = docPos.dy + (c.viewSize.height / 2 - local.dy) / zoom;
    await c.goTo(c.calcMatrixFor(Offset(centerX, cy), zoom: zoom),
        duration: Motion.of(context, Motion.medium));
    if (mounted) _recordPdfZoom();
  }

  /// Dokunulan noktanın sütunu / görseli ekran genişliğine otursun diye
  /// yakınlık ve yatay merkez (belge biriminde). Bulunamazsa null.
  Future<({double zoom, double centerX})?> _smartZoomTarget(
      Offset docPos, double current) async {
    final doc = _pdfDoc;
    final c = _pdfController;
    if (doc == null || !c.isReady) return null;
    final hit =
        c.getPdfPageHitTestResult(docPos, useDocumentLayoutCoordinates: true);
    // Döndürülmüş sayfada sütun yönü belirsiz: düz yakınlaşma.
    if (hit == null || hit.page.rotation != PdfPageRotation.none) return null;
    final page = hit.page;
    final content = await _pdfPageContent(doc, page.pageNumber - 1);
    if (content == null || !mounted || !c.isReady) return null;
    final box = PdfReadingZoom.smartTarget(content, hit.offset.x, hit.offset.y);
    if (box == null) return null;
    final layouts = c.layout.pageLayouts;
    if (page.pageNumber > layouts.length) return null;
    final r = box.toRectInDocument(
        page: page, pageRect: layouts[page.pageNumber - 1]);
    final zoom = PdfReadingZoom.fitBoxZoom(
        viewWidth: c.viewSize.width,
        boxWidth: r.width,
        current: current,
        maxZoom: c.maxScale);
    if (zoom == null) return null;
    return (zoom: zoom, centerX: r.center.dx);
  }

  /// Sayfanın içerik nesneleri (PDF Pro köprüsü, işçide). Son birkaç sayfa
  /// bellekte; belge yeniden yüklenince boşalır. Okunamazsa null.
  Future<PdfPageContent?> _pdfPageContent(PdfDocument doc, int pageIndex) async {
    if (!identical(_comfortDoc, doc)) {
      _comfortDoc = doc;
      _comfortContent.clear();
    }
    final cached = _comfortContent[pageIndex];
    if (cached != null) return cached;
    try {
      final content = await PdfEditBridge.content(doc, pageIndex);
      if (identical(_comfortDoc, doc)) {
        _comfortContent[pageIndex] = content;
        while (_comfortContent.length > 6) {
          _comfortContent.remove(_comfortContent.keys.first);
        }
      }
      return content;
    } catch (_) {
      // Bilinçli: nesneler okunamadı (bozuk sayfa, belge kapandı) — düz yakınlık.
      return null;
    }
  }

  /// **Görsel kipi** (H3.3): uzun basılan yerde (sayfayı kaplamayan) bir
  /// görsel varsa "Görseli büyüt" önerilir; seçilirse görsel siyah zeminde
  /// tam ekran açılır ([PdfImageZoomScreen]). Görsel bulma PDF Pro'nun nesne
  /// okumasıyla ([_pdfPageContent]); uzun basış metin seçtiyse öneri yok.
  Future<void> _offerImageZoom(Offset docPos) async {
    final doc = _pdfDoc;
    final c = _pdfController;
    if (doc == null || !c.isReady || _pro != null) return;
    final hit =
        c.getPdfPageHitTestResult(docPos, useDocumentLayoutCoordinates: true);
    if (hit == null) return;
    final page = hit.page;
    final content = await _pdfPageContent(doc, page.pageNumber - 1);
    if (!mounted) return;
    if (content == null) return;
    final item = PdfReadingZoom.imageAt(content, hit.offset.x, hit.offset.y);
    if (item == null || _pdfSelection.trim().isNotEmpty) return;
    AppHaptics.step();
    final go = await showAppActionSheet<bool>(
      context,
      groups: [
        AppActionGroup(actions: [
          AppAction(
              value: true,
              icon: AppIcons.zoomIn,
              label: context.t('pp.image_zoom'),
              hint: context.t('pp.image_zoom_hint')),
        ]),
      ],
    );
    if (!mounted) return;
    if (go != true) return;
    final media = MediaQuery.of(context);
    final screenLong = media.size.longestSide * media.devicePixelRatio;
    final region = PdfRect(item.left, item.top, item.right, item.bottom);
    await Navigator.of(context).push(pdfImageZoomRoute(() => renderPdfRegion(
        page, region,
        screenLongPx: screenLong,
        nativePx: math.max(item.pixelWidth, item.pixelHeight))));
  }

  /// **Kenar boşluğu kırpma** (H3.4) aç/kapa. Açarken ilk sayfalar düşük
  /// çözünürlükte taranır ([PdfMarginCropper.estimate]); paylar belge başına
  /// saklanır. Düzen değişince belge genişliğe sığdırılır (metin ekranı
  /// doldursun). Kırpacak boşluk yoksa söylenir, kapalı kalır.
  Future<void> _setMarginCrop(bool on) async {
    final path = widget.doc.path;
    if (!on) {
      _partSetState(() => _pdfCrop = null);
      unawaited(PdfZoomMemory.recordCrop(path, null));
      _refitAfterLayout();
      return;
    }
    final doc = _pdfDoc;
    if (doc == null || _pdfCropBusy) return;
    _partSetState(() => _pdfCropBusy = true);
    PdfMarginCrop? crop;
    try {
      crop = await PdfMarginCropper.estimate(doc);
    } catch (_) {
      // Bilinçli: tarama çizilemedi (belge kapandı/yeniden yüklendi).
      crop = null;
    }
    if (!mounted) return;
    _partSetState(() {
      _pdfCropBusy = false;
      _pdfCrop = crop;
    });
    if (crop == null) {
      _snack(context.t('pp.crop_none'));
      return;
    }
    unawaited(PdfZoomMemory.recordCrop(path, crop.toList()));
    _refitAfterLayout();
  }

  /// Yeni düzen kurulduktan sonra genişliğe sığdır, yakınlığı sakla.
  void _refitAfterLayout() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_fitPdfWidth().then((_) {
        if (mounted) _recordPdfZoom();
      }));
    });
  }

  // ── Sayfa sayfa geçiş (H3.5) ───────────────────────────────────────────

  /// Kip etkin mi (yalnız tek sütun, düzenleme kipi dışında)?
  bool get _pagedActive => _pdfPaged && _pdfColumns == 1 && _pro == null;

  /// Parmak sayfayı kaydırmaz, çevirir (sayfa sığmış, yakın değil).
  bool get _pagedLocked => _pagedActive && !_pagedZoomed;

  /// Sayfa sayfa kipini aç/kapa. Açınca okunan sayfa ekrana sığar, çubuklar
  /// çekilir; kapatınca belge genişliğe sığar.
  void _setPdfPaged(bool on) {
    final page = _livePdfPage() ?? _pdfPage;
    _partSetState(() {
      _pdfPaged = on;
      _pagedZoomed = false;
    });
    _saveAid(_ViewerScreenPdfReadingAidsPart._kPaged, on);
    if (on) {
      _readingBars.hide();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_showPagedPage(page, animate: false));
      });
    } else {
      _refitAfterLayout();
    }
  }

  /// Görüntüleyici hazır olunca (ilk kare sonrası) okunan sayfayı sığdır.
  void _fitPagedSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _pagedActive && _pdfController.isReady) {
        unawaited(_showPagedPage(_livePdfPage() ?? _pdfPage, animate: false));
      }
    });
  }

  /// [page]'in tamamını ekrana sığdıran yakınlık (yoksa null).
  Rect? _pagedRect(int page) {
    final c = _pdfController;
    if (!c.isReady) return null;
    final layouts = c.layout.pageLayouts;
    if (page < 1 || page > layouts.length) return null;
    return layouts[page - 1];
  }

  double? _pagedFitZoom(int page) {
    final r = _pagedRect(page);
    if (r == null || r.width <= 0 || r.height <= 0) return null;
    final view = _pdfController.viewSize;
    return math.min((view.width - 2 * Gap.sm) / r.width,
        (view.height - 2 * Gap.sm) / r.height);
  }

  /// [page] sayfaya, sayfanın tamamı ekrana sığarak geç.
  Future<void> _showPagedPage(int page, {bool animate = true}) async {
    final r = _pagedRect(page);
    if (r == null) return;
    _pdfJumpTarget = page;
    final c = _pdfController;
    try {
      await c.goTo(c.calcMatrixForRect(r, margin: Gap.sm),
          duration: animate ? Motion.of(context, Motion.medium) : Duration.zero);
    } catch (_) {
      // Bilinçli: belge o an yeniden yükleniyor — sonraki dokunuş yine dener.
    }
    if (mounted && _pagedZoomed) _partSetState(() => _pagedZoomed = false);
  }

  /// Matris her değiştiğinde: sayfa sığdırmanın belirgin üstüne çıkıldı mı?
  /// (Yakınken parmak sayfayı gezdirir, çevirmez.)
  void _trackPagedZoom(double zoom) {
    if (!_pagedActive) return;
    final fit = _pagedFitZoom(_livePdfPage() ?? _pdfPage);
    if (fit == null) return;
    final zoomed = PdfReadingZoom.isZoomedIn(zoom, fit);
    if (zoomed != _pagedZoomed) _partSetState(() => _pagedZoomed = zoomed);
  }

  /// Kenar dokunuşunun yönü: sağ kenar sonraki (+1), sol önceki (-1), orta 0.
  /// Sağdan sola dilde tersi (kitap sağdan açılır).
  int _pagedEdgeDirection(double localX) {
    if (!_pagedLocked) return 0;
    final w = _pdfController.isReady
        ? _pdfController.viewSize.width
        : MediaQuery.sizeOf(context).width;
    final side = PdfPagedTurn.edgeSide(localX, w);
    if (side == 0) return 0;
    return Directionality.of(context) == TextDirection.rtl ? -side : side;
  }

  /// Kabuktan: bu tek dokunuş çekik çubukları getirsin mi? Sayfa sayfa
  /// kipinde kenar dokunuşu sayfa çevirir, çubuk getirmez.
  bool _tapShowsBars(Offset global) {
    if (!_pagedLocked) return true;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return true;
    final local = box.globalToLocal(global);
    return PdfPagedTurn.edgeSide(local.dx, box.size.width) == 0;
  }

  void _pagedPointerDown(PointerDownEvent e) {
    _pagedPointers++;
    if (_pagedPointers == 1) {
      _pagedMulti = false;
      _pagedDownAt = e.position;
      _pagedDownTime = DateTime.now();
    } else {
      _pagedMulti = true;
    }
  }

  void _pagedPointerUp(PointerUpEvent e) {
    _pagedPointers = math.max(0, _pagedPointers - 1);
    final at = _pagedDownAt, time = _pagedDownTime;
    if (_pagedPointers > 0) return;
    _pagedDownAt = null;
    if (!_pagedLocked || _pagedMulti || at == null || time == null) return;
    if (_pdfSelecting || _pdfSelection.trim().isNotEmpty) return;
    var dir = PdfPagedTurn.swipe(e.position - at, DateTime.now().difference(time));
    if (dir == 0) return;
    if (Directionality.of(context) == TextDirection.rtl) dir = -dir;
    _turnPdfPage(dir);
  }

  void _pagedPointerCancel() {
    _pagedPointers = 0;
    _pagedDownAt = null;
  }
}

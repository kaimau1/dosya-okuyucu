part of '../viewer_screen.dart';

/// **PDF okuma konforu** (Ferrari H3, 2026-11-14): çift dokunma ve akıllı
/// yakınlaştırma. Hesap saf serviste ([PdfReadingZoom]); sayfa nesneleri
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
      case PdfViewerGeneralTapType.doubleTap:
        unawaited(_pdfDoubleTapZoom(d.localPosition, d.documentPosition));
        return true;
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
      if (PdfReadingZoom.isZoomedIn(current, fit)) {
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
}

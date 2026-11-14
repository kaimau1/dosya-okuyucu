part of '../viewer_screen.dart';

/// **PDF okuma konforu** (Ferrari H3, 2026-11-14): çift dokunma
/// yakınlaştırması. Hesap saf serviste ([PdfReadingZoom]); burada yalnız
/// görüntüleyiciye bağlantı.
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
  Future<void> _pdfDoubleTapZoom(Offset local, Offset docPos) async {
    final fit = _pdfFitWidthZoom;
    if (fit == null) return;
    final c = _pdfController;
    final current = c.currentZoom;
    final duration = Motion.of(context, Motion.medium);
    AppHaptics.selection();
    try {
      if (PdfReadingZoom.isZoomedIn(current, fit)) {
        final view = c.viewSize;
        final cy = docPos.dy + (view.height / 2 - local.dy) / fit;
        await c.goTo(
            c.calcMatrixFor(Offset(c.documentSize.width / 2, cy), zoom: fit),
            duration: duration);
      } else {
        await c.zoomOnLocalPosition(
            localPosition: local,
            newZoom: PdfReadingZoom.zoomInTarget(current, c.maxScale),
            duration: duration);
      }
    } catch (_) {
      // Bilinçli: belge o an yeniden yükleniyor olabilir — yakınlık kritik değil.
    }
    if (mounted) _recordPdfZoom();
  }
}

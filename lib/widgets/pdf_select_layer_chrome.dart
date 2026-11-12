part of 'pdf_select_layer.dart';

extension _PdfSelectLayerChrome on _PdfSelectLayerState {
  /// Sürüklerken parmağın üstünde gezen büyüteç — Android'in yerel seçim
  /// büyüteciyle aynı his. Parmağın 66 px üstünde durur, altındaki içeriği
  /// (seçim vurgusu dahil) 1,6 kat büyütür. Sayfa kenarında yatayda kıstırılır
  /// ki mercek ekrandan taşmasın; odak parmakta kalır.
  Widget _buildMagnifier(ColorScheme scheme) {
    final p = _magnifier!;
    const size = Size(112, 56);
    const above = 66.0;
    final maxLeft = widget.pageSize.width - size.width + 8.0;
    final left =
        maxLeft < -8.0 ? -8.0 : (p.dx - size.width / 2).clamp(-8.0, maxLeft);
    final top = p.dy - size.height / 2 - above;
    return Positioned(
      left: left,
      top: top,
      child: IgnorePointer(
        child: RawMagnifier(
          size: size,
          focalPointOffset: Offset(p.dx - (left + size.width / 2), above),
          magnificationScale: 1.6,
          decoration: MagnifierDecoration(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
            ),
            shadows: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 3),
                blurStyle: BlurStyle.outer,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Taranmış sayfada OCR durum çipi: "Metin tanınıyor…" / "metin bulunamadı".
  /// Uzun basılan yerin değil sayfanın üstünde durur ki parmağın altında
  /// kaybolmasın.
  Widget _ocrChip(BuildContext context, ColorScheme scheme) {
    return Positioned(
      top: 10,
      left: 0,
      right: 0,
      child: Center(
        child: IgnorePointer(
          child: Material(
            color: scheme.inverseSurface.withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_ocrRunning)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.6,
                        color: scheme.onInverseSurface,
                      ),
                    )
                  else
                    Icon(AppIcons.searchOff,
                        size: 14, color: scheme.onInverseSurface),
                  const SizedBox(width: 7),
                  Text(
                    _ocrRunning
                        ? context.t('vw.select_ocr_running')
                        : context.t('vw.select_ocr_none'),
                    style: context.type.small.copyWith(
                      color: scheme.onInverseSurface,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Seçim ucundaki sürüklenebilir tutamaç (telefonun yerel seçim hissi).
  ///
  /// Dokunma alanı 48 px: Material'ın en küçük dokunma hedefi. Eskiden 40'tı ve
  /// nokta 18 px'di — kullanıcı "tutamacı yakalayamıyorum" diyordu.
  Widget _handle({required bool isStart, required Color color}) {
    final r = _charRect(isStart ? _selStart : _selEnd);
    if (r == null) return const SizedBox.shrink();
    final point =
        isStart ? Offset(r.left, r.bottom) : Offset(r.right, r.bottom);
    const touch = 48.0, dot = 20.0;
    return Positioned(
      left: point.dx - touch / 2,
      top: point.dy - touch / 2 + 10,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          final at = _globalToOverlay(d.globalPosition);
          if (at != null) _partSetState(() => _magnifier = at - const Offset(0, 14));
        },
        onPanUpdate: (d) {
          _dragHandle(isStart, d.globalPosition);
          _notifyDragAt(d.globalPosition);
        },
        onPanEnd: (_) {
          _notifyDragAt(null);
          _partSetState(() => _magnifier = null);
          _report();
        },
        onPanCancel: () {
          _notifyDragAt(null);
          _partSetState(() => _magnifier = null);
        },
        child: SizedBox(
          width: touch,
          height: touch,
          child: Center(
            child: Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.onMedia, width: 2),
                boxShadow: [
                  BoxShadow(
                      color: AppColors.shade.withValues(alpha: 0.3),
                      blurRadius: 3),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

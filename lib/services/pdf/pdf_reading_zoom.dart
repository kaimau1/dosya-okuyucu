/// **PDF okuma konforu — çift dokunma yakınlaştırması** (Ferrari H3.1).
///
/// Saf hesap (widget yok): görüntüleyici çift dokunuşta yakınlık hedefini
/// buradan alır.
library;

import 'dart:math' as math;

abstract final class PdfReadingZoom {
  /// Çift dokunuşta yakınlaşma katı (Samsung / Chrome ~2,5×).
  static const factor = 2.5;

  /// Genişliğe sığdırmanın bu katından büyükse belge "yakın" sayılır:
  /// çift dokunuş geri sığdırır.
  static const zoomedSlack = 1.05;

  /// [zoom] genişliğe sığdırmadan ([fitZoom]) belirgin büyük mü?
  static bool isZoomedIn(double zoom, double fitZoom) =>
      fitZoom > 0 && zoom > fitZoom * zoomedSlack;

  /// Yakınlaşma hedefi: [current] × [factor], [maxZoom] tavanı.
  static double zoomInTarget(double current, double maxZoom) =>
      math.min(current * factor, maxZoom);
}

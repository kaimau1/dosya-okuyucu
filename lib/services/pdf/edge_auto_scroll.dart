import 'dart:ui' show Offset, Size;

/// Seçim sürüklenirken işaretçi görüntü alanının kenarına yaklaştıysa
/// görüntünün O KARE kayması gereken miktar (görüntü pikseli).
///
/// Chrome'un seçim oto-kaydırması: kenara [margin] px kala başlar, kenara
/// yaklaştıkça hızlanır, en çok [maxStep] px/kare (60 Hz'de ~840 px/sn).
/// Pozitif değer "o yöndeki içeriği göster" demektir (alt kenar → +y);
/// uygulayan taraf görüntü matrisini TERS yönde öteler.
///
/// Saf fonksiyon — birim testli; görüntüleyiciye tek satır kaldı.
Offset edgeAutoScrollDelta(
  Offset pos,
  Size viewport, {
  double margin = 56,
  double maxStep = 14,
}) {
  double axis(double p, double extent) {
    // Kenar payı alanı görüntüyü kaplayacak kadar küçük ekranlarda (bölünmüş
    // ekran vb.) payı küçült ki orta bölge her zaman "ölü bölge" kalsın.
    final m = extent < margin * 3 ? extent / 3 : margin;
    if (m <= 0) return 0;
    if (p < m) return -((m - p) / m).clamp(0.0, 1.0) * maxStep;
    if (p > extent - m) {
      return ((p - (extent - m)) / m).clamp(0.0, 1.0) * maxStep;
    }
    return 0;
  }

  return Offset(axis(pos.dx, viewport.width), axis(pos.dy, viewport.height));
}

import 'dart:math' as math;
import 'dart:ui' show Rect;

/// Görüntülenen sayfa numarası — pdfrx'in tahmininin **eşitlik** düzeltmesi.
///
/// KÖK NEDEN (kullanıcı 2026-09-22: *"PDF'lerde görüntülenen sayfa numarası
/// yanlış oluyor, geri kalıyor, ekrana sığıyorsa"*): pdfrx güncel sayfayı
/// "görünen alanla kesişimi, sayfanın kendi alanına oranla en büyük olan
/// sayfa" diye seçiyor ve eşitlikte İLKİNİ tutuyor. Sayfalar ekrana tam
/// sığdığında (yatay slayt PDF'i, uzaklaştırılmış görünüm, çok sütun) birden
/// çok sayfanın oranı %100 olur → hep en üstteki kazanır. Belgenin sonuna
/// kadar kaydırıldığında bile rozet "8/10" der; son sayfalar hiç "güncel"
/// olamaz, çünkü hiçbir zaman ekranın tepesine çıkamazlar.
///
/// Kural (tek sayfa önde olduğunda pdfrx ile AYNI):
/// 1. En büyük orana sahip sayfa(lar) aday. Tek aday varsa o.
/// 2. Birden çok aday (eşit, ör. hepsi tam görünüyor):
///    - [preferred] (az önce "sayfaya git" ile gidilen sayfa) adaylar
///      arasındaysa o — "5'e git" deyip rozette 6 görmek olmasın.
///    - Yoksa **son ekranlık kaydırma** boyunca adaylar sırayla gezilir:
///      belgenin sonuna bir ekran kala ilk aday, en sonda son aday. Böylece
///      tepeye hiç çıkamayan son sayfalar da kaydırdıkça tek tek görünür.
///      Belgenin geri kalanında ilk aday (pdfrx'in ve alışılmış okuyucuların
///      davranışı: ekranın üstündeki sayfa).
///
/// Saf fonksiyon — birim testli (`test/pdf_current_page_test.dart`).
int? currentPdfPage({
  required Rect visibleRect,
  required List<Rect> pageRects,
  int? preferred,
}) {
  if (pageRects.isEmpty || visibleRect.isEmpty) return null;

  double ratioOf(Rect page) {
    if (page.width <= 0 || page.height <= 0) return 0;
    final overlap = page.intersect(visibleRect);
    // `intersect` kesişme yoksa NEGATİF kenarlı dikdörtgen döndürür.
    if (overlap.width <= 0 || overlap.height <= 0) return 0;
    return (overlap.width * overlap.height) / (page.width * page.height);
  }

  final ratios = [for (final r in pageRects) ratioOf(r)];
  final maxRatio = ratios.reduce(math.max);
  if (maxRatio <= 0) return null;

  // Kayan nokta payı: "tam görünen" iki sayfanın oranı 0.9999 / 1.0 olabilir.
  const tolerance = 0.01;
  final tied = <int>[
    for (var i = 0; i < ratios.length; i++)
      if (ratios[i] > 0 && ratios[i] >= maxRatio - tolerance) i + 1,
  ];
  if (tied.length == 1) return tied.single;
  if (preferred != null && tied.contains(preferred)) return preferred;

  // Son ekranlık kaydırmadaki ilerleme (0 → 1).
  final docTop = pageRects.map((r) => r.top).reduce(math.min);
  final docBottom = pageRects.map((r) => r.bottom).reduce(math.max);
  final maxTop = docBottom - visibleRect.height; // sona dayanınca üst kenar
  if (maxTop <= docTop) return tied.first; // belge tümüyle ekranda
  final startTop = math.max(docTop, maxTop - visibleRect.height);
  final span = maxTop - startTop;
  final progress =
      span <= 0 ? 1.0 : ((visibleRect.top - startTop) / span).clamp(0.0, 1.0);
  return tied[(progress * (tied.length - 1)).round()];
}

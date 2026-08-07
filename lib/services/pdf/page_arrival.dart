import 'dart:ui' show Rect;

/// "Sayfaya git" gerçekten **vardı mı?**
///
/// KÖK NEDEN (2026-08-07 kullanıcı bulgusu: *"sayfaya git bazen çalışmıyor;
/// ilk girdiğimde çalışıyor, biraz gezip işlem yapınca çalışmıyor"*):
/// varış, pdfrx'in kendi bildirdiği sayfa numarasına bakılarak ölçülüyordu.
/// O numara **görünen alanın en çok kesiştiği sayfa** olarak tahmin edilir;
/// yakınlaştırılmış ya da çok sütunlu görünümde hedef sayfa ekranda TAM
/// dururken bile komşusunun adı okunabiliyor. Ölçü tutmayınca atlayış
/// "başarısız" sayılıp tekrar tekrar deneniyor, kullanıcı da "gitmiyor"
/// diyordu — oysa belge doğru yerdeydi.
///
/// Doğru ölçü geometridir: hedef sayfanın dikdörtgeni ile görünen alan
/// kesişiyor mu?
///
/// İki kabul ölçütü var, çünkü tek başına hiçbiri yetmiyor:
/// - **Oran** ([minRatio]): sayfanın en az beşte biri ekranda. Uzaklaşmış
///   (birden çok sayfanın göründüğü) görünümün ölçüsü — pdfrx'in kendi eşiği
///   de budur.
/// - **Merkez**: görünen alanın ortası sayfanın üstünde. Yakınlaştırılmış
///   görünümün ölçüsü; %400 yakınlaştırmada sayfanın yalnız %5'i ekranda
///   olabilir ama kullanıcı tam olarak o sayfaya bakmaktadır.
///
/// Saf fonksiyon — birim testli.
bool arrivedAtPage({
  required Rect pageRect,
  required Rect visibleRect,
  double minRatio = 0.2,
}) {
  if (pageRect.width <= 0 || pageRect.height <= 0) return false;
  if (pageRect.contains(visibleRect.center)) return true;
  final overlap = pageRect.intersect(visibleRect);
  // `Rect.intersect` kesişme yoksa NEGATİF kenarlı bir dikdörtgen döndürür —
  // alan hesabı bunu "pozitif alan" sanırdı (eksi × eksi = artı).
  if (overlap.width <= 0 || overlap.height <= 0) return false;
  final ratio = (overlap.width * overlap.height) /
      (pageRect.width * pageRect.height);
  return ratio >= minRatio;
}

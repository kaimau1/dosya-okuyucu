import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart';

/// Seçim/vurgu GEOMETRİSİ — `PdfSelectLayer`'dan buraya taşındı (2026-08-05,
/// 4. tur): OCR destekli arama da aynı satır-birleştirme kurallarına muhtaç
/// (eşleşme vurgusu, seçim vurgusuyla birebir aynı görünmeli). Widget katmanı
/// `export` ile eski adresinden sunmayı sürdürüyor.
///
/// [text]'in [start]..[end] (dahil) aralığını kaplayan, **satır başına bir**
/// `PdfRect` (PDF koordinatı) listesi. Ekran seçim boyaması, kalıcı vurgu
/// annotation'ı (`PdfAnnotator`) ve OCR arama vurgusu AYNI geometriyi kullanır.
///
/// Aynı satırdaki parçalar BİRLEŞTİRİLİR. Niye (2026-07-26 kullanıcı bulgusu:
/// "kelime aralarında çıkan koyuluklar göz yoruyor"): PDF üreticileri bir
/// satırı kelime kelime (hatta harf harf) ayrı parçalara böler; her parça ayrı
/// yarı saydam dikdörtgen olarak boyanınca kelime aralarındaki örtüşmeler üst
/// üste binip koyu şeritler yapıyordu. Satır tek dikdörtgen olunca vurgu
/// telefonun yerel seçimi gibi düz ve tek tonlu görünür.
List<PdfRect> selectionPdfRects(PdfPageText text, int start, int end) {
  final out = <PdfRect>[];
  if (end < start) return out;
  for (final f in text.fragments) {
    final a = start - f.index;
    final b = end + 1 - f.index; // hariç
    final s = a < 0 ? 0 : a;
    final e = b > f.length ? f.length : b;
    if (s >= e) continue;
    PdfRect? bounds;
    try {
      bounds = f.getBoundsForRange(start: s, end: e);
    } catch (_) {
      bounds = f.bounds;
    }
    if (bounds != null) out.add(bounds);
  }
  return mergeSameLineRects(out);
}

/// Dikey olarak örtüşen (aynı satırdaki) dikdörtgenleri tek dikdörtgende
/// birleştirir. Sıra korunur: ilk satır listenin başında kalır.
///
/// **Yatay uzaklık koşulu (2026-08-06 kullanıcı bulgusu: "üst alanda seçim
/// yapmaya çalıştım ama tüm sayfa seçiliyor"):** akış şeması gibi çok sütunlu
/// sayfalarda sol ve sağ kutular aynı yüksekliğe düşer; yalnız dikeye bakan
/// birleştirme ikisini aradaki BOŞLUKLA birlikte tek banda çeviriyordu ve
/// vurgu sayfanın tüm genişliğini kaplamış görünüyordu. Aynı satır sayılmak
/// için dikdörtgenlerin yatayda da komşu olması gerekir: aradaki boşluk satır
/// yüksekliğinin 2 katını aşarsa (kelime aralığı değil sütun aralığıdır)
/// birleştirilmez, her kutu kendi metnini sarar.
List<PdfRect> mergeSameLineRects(List<PdfRect> rects) {
  final out = <PdfRect>[];
  for (final r in rects) {
    if (r.top <= r.bottom) continue; // bozuk/boş kutu
    var merged = false;
    for (var i = 0; i < out.length; i++) {
      final o = out[i];
      final overlap = math.min(o.top, r.top) - math.max(o.bottom, r.bottom);
      final minHeight = math.min(o.top - o.bottom, r.top - r.bottom);
      final hGap = math.max(o.left, r.left) - math.min(o.right, r.right);
      // Satır yüksekliğinin yarısından fazlası örtüşüyorsa VE yatayda
      // komşularsa aynı satırdır.
      if (minHeight > 0 && overlap > minHeight * 0.5 && hGap <= minHeight * 2) {
        out[i] = PdfRect(
          math.min(o.left, r.left),
          math.max(o.top, r.top),
          math.max(o.right, r.right),
          math.min(o.bottom, r.bottom),
        );
        merged = true;
        break;
      }
    }
    if (!merged) out.add(r);
  }
  return out;
}

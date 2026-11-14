/// **PDF okuma konforu — çift dokunma yakınlaştırması** (Ferrari H3.1–H3.2).
///
/// Saf hesap (widget yok): görüntüleyici çift dokunuşta yakınlık hedefini,
/// akıllı yakınlaştırmada dokunulan metin sütununu / görsel kutusunu, uzun
/// basışta görseli buradan bulur. Girdi PDF Pro'nun nesne okuması
/// ([PdfPageContent] — `PdfEditBridge.content`); koordinatlar PDF sayfa
/// uzayında (sol alt köşe başlangıç, y yukarı), [PdfPoint] ile aynı.
library;

import 'dart:math' as math;

import 'package:pdfrx/pdfrx.dart' show PdfRect;

import 'pro/pdf_text_blocks.dart' show PdfPageContent, PdfPageItem;

abstract final class PdfReadingZoom {
  /// Çift dokunuşta yakınlaşma katı (Samsung / Chrome ~2,5×).
  static const factor = 2.5;

  /// Genişliğe sığdırmanın bu katından büyükse belge "yakın" sayılır:
  /// çift dokunuş geri sığdırır.
  static const zoomedSlack = 1.05;

  /// Bu kadarlık alanı kaplayan görsel "sayfanın kendisi" (taranmış sayfa,
  /// antetli kâğıt) sayılır: görsel kipi / akıllı yakınlık onu seçmez.
  static const fullPageArea = 0.85;

  /// Akıllı yakınlığın sütun penceresi: dokunulan satırın altında ve
  /// üstünde sayfa boyunun bu kadarı taranır.
  static const columnWindow = 0.12;

  /// İki metin kutusu arasındaki boşluk sayfa genişliğinin bu kadarından
  /// büyükse ayrı sütundur (sütun arası boşluk ≈ %3–6; sözcük arası < %1).
  static const gutter = 0.02;

  /// Sütun bundan darsa (sayfa numarası, dipnot imi) akıllı yakınlık yok.
  static const minColumn = 0.12;

  /// [zoom] genişliğe sığdırmadan ([fitZoom]) belirgin büyük mü?
  static bool isZoomedIn(double zoom, double fitZoom) =>
      fitZoom > 0 && zoom > fitZoom * zoomedSlack;

  /// Yakınlaşma hedefi: [current] × [factor], [maxZoom] tavanı.
  static double zoomInTarget(double current, double maxZoom) =>
      math.min(current * factor, maxZoom);

  /// Akıllı hedef yakınlık: [boxWidth] (belge birimi) görünüm genişliğine
  /// otursun. Bulunan kutu zaten ekranı dolduruyorsa (fark < %10) ya da tavanı
  /// aşıyorsa null → düz [zoomInTarget].
  static double? fitBoxZoom(
      {required double viewWidth,
      required double boxWidth,
      required double current,
      required double maxZoom}) {
    if (boxWidth <= 0 || viewWidth <= 0) return null;
    final z = viewWidth / boxWidth;
    if (z < current * 1.1) return null;
    return math.min(z, maxZoom);
  }

  /// ([x], [y]) noktasındaki görsel nesnesi — üst üste binenlerde en küçüğü.
  /// Sayfanın neredeyse tamamını kaplayan görsel ([fullPageArea]) sayılmaz.
  static PdfPageItem? imageAt(PdfPageContent content, double x, double y,
      {double slop = 2}) {
    final pageArea = math.max(1.0, content.width * content.height);
    PdfPageItem? best;
    var bestArea = double.infinity;
    for (final it in content.items) {
      if (!it.isImage || it.width <= 0 || it.height <= 0) continue;
      final area = it.width * it.height;
      if (area >= pageArea * fullPageArea) continue;
      if (x < it.left - slop ||
          x > it.right + slop ||
          y < it.bottom - slop ||
          y > it.top + slop) {
        continue;
      }
      if (area < bestArea) {
        bestArea = area;
        best = it;
      }
    }
    return best;
  }

  /// Dokunulan yerin **metin sütunu**: noktanın çevresindeki satırların
  /// yatay aralıkları birleştirilir ([gutter]'dan dar boşluklar aynı sütun),
  /// noktayı içeren aralık döner (PDF uzayında; dikeyde pencere kadar).
  /// Bulunamazsa ya da çok darsa null.
  static PdfRect? columnAt(PdfPageContent content, double x, double y) {
    final w = content.width, h = content.height;
    if (w <= 0 || h <= 0) return null;
    final window = h * columnWindow;
    final spans = <(double, double)>[];
    var lo = double.infinity, hi = -double.infinity;
    for (final t in content.texts) {
      if (t.right <= t.left || t.top <= t.bottom) continue;
      if (t.text.trim().isEmpty) continue;
      if (t.top < y - window || t.bottom > y + window) continue;
      spans.add((t.left, t.right));
    }
    if (spans.isEmpty) return null;
    spans.sort((a, b) => a.$1.compareTo(b.$1));
    final gap = w * gutter;
    final merged = <(double, double)>[];
    for (final s in spans) {
      if (merged.isNotEmpty && s.$1 <= merged.last.$2 + gap) {
        final last = merged.removeLast();
        merged.add((last.$1, math.max(last.$2, s.$2)));
      } else {
        merged.add(s);
      }
    }
    (double, double)? hit;
    for (final m in merged) {
      if (x >= m.$1 - gap && x <= m.$2 + gap) {
        hit = m;
        break;
      }
    }
    if (hit == null || hit.$2 - hit.$1 < w * minColumn) return null;
    // Dikey sınır: penceredeki kutuların uçları (yalnız bilgi — yakınlık
    // genişliğe göre hesaplanır).
    for (final t in content.texts) {
      if (t.top < y - window || t.bottom > y + window) continue;
      if (t.right < hit.$1 || t.left > hit.$2) continue;
      lo = math.min(lo, t.bottom);
      hi = math.max(hi, t.top);
    }
    if (!lo.isFinite || !hi.isFinite || hi < lo) {
      lo = y;
      hi = y;
    }
    // Kenara yapışmasın: genişliğin %3'ü kadar pay (sayfa sınırında kesilir).
    final pad = (hit.$2 - hit.$1) * 0.03;
    final left = math.max(0.0, hit.$1 - pad);
    final right = math.min(w, hit.$2 + pad);
    if (right <= left) return null;
    return PdfRect(left, hi, right, lo);
  }

  /// Akıllı yakınlığın hedefi: noktadaki görsel kutusu, yoksa metin sütunu.
  static PdfRect? smartTarget(PdfPageContent content, double x, double y) {
    final img = imageAt(content, x, y);
    if (img != null) return PdfRect(img.left, img.top, img.right, img.bottom);
    return columnAt(content, x, y);
  }
}

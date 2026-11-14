/// **Kenar boşluğu kırpma** (Ferrari H3.4, 2026-11-14).
///
/// Sayfanın içerik sınırı ilk [PdfMarginCropper.samplePages] sayfanın düşük
/// çözünürlüklü çiziminden (uzun kenar [PdfMarginCropper.sampleLong] px)
/// kestirilir; piksel taraması izolatta. Sonuç bütün belgeye uygulanır:
/// tek sütun düzeninde sayfalar sol/sağ boşlukları belge sınırının DIŞINA
/// taşacak şekilde dizilir — genişliğe sığdırınca metin ekranı doldurur.
///
/// **Yalnız yatay** (karar): pdfrx sayfayı kırpmadan çizer; üst/alt payı
/// kaldırmak için sayfaları üst üste bindirmek gerekir, bu da bir sonraki
/// sayfanın beyaz kenarını öncekinin metninin üstüne çizer. Üst/alt oranlar
/// yine ölçülür ve saklanır (ileride kullanılabilsin).
library;

import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' show Rect, Size;

import 'package:pdfrx/pdfrx.dart';

/// Sayfanın kenarlarından kesilecek pay (sayfa boyunun oranı, 0–1).
class PdfMarginCrop {
  final double left, top, right, bottom;
  const PdfMarginCrop(this.left, this.top, this.right, this.bottom);

  List<double> toList() => [left, top, right, bottom];

  static PdfMarginCrop? fromList(List<double>? v) {
    if (v == null || v.length != 4) return null;
    if (v.any((e) => !e.isFinite || e < 0 || e >= 0.5)) return null;
    return PdfMarginCrop(v[0], v[1], v[2], v[3]);
  }

  @override
  bool operator ==(Object other) =>
      other is PdfMarginCrop &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);
}

abstract final class PdfMarginCropper {
  /// Taranan sayfa sayısı (belgenin başı).
  static const samplePages = 5;

  /// Tarama çiziminin uzun kenarı (px): 1 px ≈ 5 punto — boşluk ölçmeye yeter.
  static const sampleLong = 160.0;

  /// Kanallardan biri bunun altındaysa piksel "mürekkep".
  static const inkLevel = 235;

  /// Satır/sütunun içerik sayılması için en az mürekkep pikseli (lekeye
  /// karşı; satırın %1'i, en az 2).
  static const minInkShare = 0.01;

  /// İçeriğe kadar kırpılmaz: metin kenara yapışmasın (sayfa oranı).
  static const pad = 0.015;

  /// Bir kenardan en çok bu kadar kesilir.
  static const maxSide = 0.3;

  /// Sol + sağ bundan azsa kırpacak boşluk yok sayılır.
  static const minTotal = 0.04;

  /// Bir sayfa çiziminin (BGRA) içerik sınırı → kenar payları. Boş sayfa
  /// null.
  static PdfMarginCrop? marginsOf(Uint8List bgra, int width, int height) {
    if (width <= 0 || height <= 0 || bgra.length < width * height * 4) {
      return null;
    }
    final cols = List<int>.filled(width, 0);
    final rows = List<int>.filled(height, 0);
    for (var y = 0; y < height; y++) {
      final base = y * width * 4;
      for (var x = 0; x < width; x++) {
        final i = base + x * 4;
        if (bgra[i] < inkLevel ||
            bgra[i + 1] < inkLevel ||
            bgra[i + 2] < inkLevel) {
          cols[x]++;
          rows[y]++;
        }
      }
    }
    final colMin = math.max(2, (height * minInkShare).round());
    final rowMin = math.max(2, (width * minInkShare).round());
    final l = cols.indexWhere((c) => c >= colMin);
    final t = rows.indexWhere((c) => c >= rowMin);
    if (l < 0 || t < 0) return null;
    final r = cols.lastIndexWhere((c) => c >= colMin);
    final b = rows.lastIndexWhere((c) => c >= rowMin);
    return PdfMarginCrop(l / width, t / height, (width - 1 - r) / width,
        (height - 1 - b) / height);
  }

  /// Sayfaların paylarını birleştirir: her kenarda en küçüğü (hiçbir
  /// sayfanın içeriği kesilmesin) eksi [pad]. Kenarı kenara dolu (taşan
  /// kapak) sayfa sayılmaz. Kırpacak boşluk yoksa null.
  static PdfMarginCrop? combine(List<PdfMarginCrop> pages) {
    final used = [
      for (final p in pages)
        if (p.left > 0.01 || p.right > 0.01 || p.top > 0.01 || p.bottom > 0.01)
          p,
    ];
    if (used.isEmpty) return null;
    double side(double Function(PdfMarginCrop) f) =>
        math.min(maxSide, math.max(0.0, used.map(f).reduce(math.min) - pad));
    final crop = PdfMarginCrop(side((p) => p.left), side((p) => p.top),
        side((p) => p.right), side((p) => p.bottom));
    if (crop.left + crop.right < minTotal) return null;
    return crop;
  }

  /// Belgenin başındaki sayfaları düşük çözünürlükte çizip payları kestirir.
  /// Çizim pdfrx'in işçisinde, piksel taraması izolatta.
  static Future<PdfMarginCrop?> estimate(PdfDocument doc) async {
    final samples = <(Uint8List, int, int)>[];
    final n = math.min(samplePages, doc.pages.length);
    for (var i = 0; i < n; i++) {
      final page = doc.pages[i];
      final long = math.max(page.width, page.height);
      if (long <= 0) continue;
      final s = sampleLong / long;
      final img = await page.render(
        fullWidth: (page.width * s).roundToDouble(),
        fullHeight: (page.height * s).roundToDouble(),
        backgroundColor: 0xFFFFFFFF,
        annotationRenderingMode: PdfAnnotationRenderingMode.none,
      );
      if (img == null) continue;
      try {
        samples.add((Uint8List.fromList(img.pixels), img.width, img.height));
      } finally {
        img.dispose();
      }
    }
    if (samples.isEmpty) return null;
    return Isolate.run(() => combine([
          for (final s in samples) ?marginsOf(s.$1, s.$2, s.$3),
        ]));
  }

  /// Tek sütun düzeni, kırpılmış: belge genişliği en geniş İÇERİK + kenar
  /// payı; her sayfa içeriği ortada kalacak şekilde, sol/sağ boşluğu belge
  /// sınırının dışına taşarak dizilir (pdfrx sınırın dışına kaydırmaz).
  static PdfPageLayout layout(
      List<PdfPage> pages, double margin, PdfMarginCrop crop) {
    final keep = 1 - crop.left - crop.right;
    final contentW = pages.fold(0.0, (w, p) => math.max(w, p.width * keep));
    final width = contentW + margin * 2;
    final rects = <Rect>[];
    var y = margin;
    for (final page in pages) {
      final x = (width - page.width * keep) / 2 - page.width * crop.left;
      rects.add(Rect.fromLTWH(x, y, page.width, page.height));
      y += page.height + margin;
    }
    return PdfPageLayout(pageLayouts: rects, documentSize: Size(width, y));
  }
}

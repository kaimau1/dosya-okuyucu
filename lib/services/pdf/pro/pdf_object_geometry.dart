import 'dart:ui' show Offset, Rect, Size;

/// Nesne taşırken tutunma sonucu: düzeltilmiş kayma ve çizilecek kılavuzlar
/// (dikey kılavuzların x'leri, yatay kılavuzların y'leri; katman pikseli).
class PdfSnap {
  const PdfSnap(this.offset, this.xs, this.ys);
  final Offset offset;
  final List<double> xs, ys;
  static const none = PdfSnap(Offset.zero, [], []);
}

/// Tutunma hedefleri (taşıma başında bir kez kurulur): sayfa kenarı, ortası,
/// kenar boşluğu ve öteki nesnelerin kenar/orta çizgileri.
class PdfSnapTargets {
  PdfSnapTargets(Size page, Iterable<Rect> others, {required double margin})
      : xs = [
          0, page.width / 2, page.width, //
          if (margin * 2 < page.width) ...[margin, page.width - margin],
          for (final r in others) ...[r.left, r.center.dx, r.right],
        ],
        ys = [
          0, page.height / 2, page.height, //
          if (margin * 2 < page.height) ...[margin, page.height - margin],
          for (final r in others) ...[r.top, r.center.dy, r.bottom],
        ];

  final List<double> xs, ys;

  /// [moving] kutusu [delta] kadar kaydırılınca kenarı ya da ortası bir
  /// hedefe [threshold] pikselden yakınsa ona yapıştırılır (eksen başına en
  /// yakın tek hedef).
  PdfSnap snap(Rect moving, Offset delta, {double threshold = 8}) {
    final r = moving.shift(delta);
    final (dx, gx) = _axis([r.left, r.center.dx, r.right], xs, threshold);
    final (dy, gy) = _axis([r.top, r.center.dy, r.bottom], ys, threshold);
    return PdfSnap(delta + Offset(dx, dy), gx, gy);
  }

  static (double, List<double>) _axis(
      List<double> edges, List<double> targets, double threshold) {
    double? best;
    for (final t in targets) {
      for (final e in edges) {
        final d = t - e;
        if (d.abs() <= threshold && (best == null || d.abs() < best.abs())) {
          best = d;
        }
      }
    }
    if (best == null) return (0, const []);
    // Yapıştıktan sonra çakışan TÜM hedefler kılavuz olur (ör. sol kenar
    // hem kenar boşluğunda hem üstteki görselin solunda).
    final guides = <double>{
      for (final t in targets)
        for (final e in edges)
          if ((t - e - best).abs() < 0.5) t
    };
    return (best, guides.toList());
  }
}

/// Bir eksende hizalama/dağıtma kipi: başa, ortaya, sona, eşit aralık.
enum PdfAxisAlign { start, center, end, distribute }

/// [spans] (eksendeki [baş, son] aralıkları) için her nesnenin kayması.
/// Hizalama: seçimin dış kenarına/ortasına. Dağıtma (≥ 3 nesne): ilk ve son
/// yerinde kalır, aradaki boşluklar eşitlenir (sıra başlangıca göre).
List<double> pdfAlignAxis(List<(double, double)> spans, PdfAxisAlign mode) {
  if (spans.length < 2) return List.filled(spans.length, 0.0);
  final lo = spans.map((s) => s.$1).reduce((a, b) => a < b ? a : b);
  final hi = spans.map((s) => s.$2).reduce((a, b) => a > b ? a : b);
  switch (mode) {
    case PdfAxisAlign.start:
      return [for (final s in spans) lo - s.$1];
    case PdfAxisAlign.end:
      return [for (final s in spans) hi - s.$2];
    case PdfAxisAlign.center:
      final mid = (lo + hi) / 2;
      return [for (final s in spans) mid - (s.$1 + s.$2) / 2];
    case PdfAxisAlign.distribute:
      final out = List<double>.filled(spans.length, 0.0);
      if (spans.length < 3) return out;
      final order = List.generate(spans.length, (i) => i)
        ..sort((a, b) => spans[a].$1.compareTo(spans[b].$1));
      final total = spans.fold(0.0, (t, s) => t + (s.$2 - s.$1));
      final gap = (hi - lo - total) / (spans.length - 1);
      var at = lo;
      for (final i in order) {
        out[i] = at - spans[i].$1;
        at += spans[i].$2 - spans[i].$1 + gap;
      }
      return out;
  }
}

/// Kementle seçim: merkezi [lasso] içinde kalan kutuların sırası.
List<int> pdfInLasso(List<Rect> rects, Rect lasso) => [
      for (var i = 0; i < rects.length; i++)
        if (lasso.contains(rects[i].center)) i
    ];

import 'dart:math' as math;

import 'pdf_edit_bridge.dart';

/// **Akıllı Mürekkep (Smart Ink) analiz sonucu.**
sealed class SmartInkResult {
  const SmartInkResult();
}

/// Metin üzerine/altına yatay sürülen kalem/fosforlu → keskin vurgu/alt/üst çizgi.
class SmartInkTextMarkup extends SmartInkResult {
  final int type;
  final List<List<double>> quads;
  final List<double> rect;
  const SmartInkTextMarkup({
    required this.type,
    required this.quads,
    required this.rect,
  });
}

/// Paragraf/metin çevresine çizilen kapalı daire/döngü → metni ve dörtgenlerini seçer.
class SmartInkCircleText extends SmartInkResult {
  final String text;
  final List<List<double>> quads;
  final List<double> rect;
  const SmartInkCircleText({
    required this.text,
    required this.quads,
    required this.rect,
  });
}

/// Metinsiz alanda düz çizgi → düzgün doğru.
class SmartInkCleanLine extends SmartInkResult {
  final List<double> points;
  final List<double> rect;
  const SmartInkCleanLine({
    required this.points,
    required this.rect,
  });
}

/// Metinsiz alanda düzgün elips/daire → temiz geometrik elips.
class SmartInkCleanEllipse extends SmartInkResult {
  final List<double> rect;
  const SmartInkCleanEllipse({required this.rect});
}

/// Sayfa uzayı serbest vuruşunu analiz edip Akıllı Mürekkep niyetine çevirir.
/// Hiçbir akıllı kalıba uymuyorsa `null` döner ve vuruş normal serbest çizim kalır.
SmartInkResult? analyzeSmartInk({
  required List<({double x, double y})> points,
  required List<PdfTextBlock> blocks,
  required bool isHighlighter,
}) {
  if (points.length < 2) return null;

  var l = double.infinity, b = double.infinity;
  var r = -double.infinity, t = -double.infinity;
  var totalLen = 0.0;
  var sumY = 0.0;
  for (var i = 0; i < points.length; i++) {
    final pt = points[i];
    l = math.min(l, pt.x);
    r = math.max(r, pt.x);
    b = math.min(b, pt.y);
    t = math.max(t, pt.y);
    sumY += pt.y;
    if (i > 0) {
      final dx = pt.x - points[i - 1].x;
      final dy = pt.y - points[i - 1].y;
      totalLen += math.sqrt(dx * dx + dy * dy);
    }
  }
  final w = r - l;
  final h = t - b;
  final first = points.first;
  final last = points.last;
  final gap = math.sqrt(
      (last.x - first.x) * (last.x - first.x) +
          (last.y - first.y) * (last.y - first.y));

  // A. Kapalı döngü/daire: paragraf veya görsel çevreleme.
  final isClosedLoop = points.length >= 8 &&
      w >= 20 &&
      h >= 14 &&
      totalLen >= 1.8 * math.max(w, h) &&
      gap <= math.max(24.0, 0.45 * math.max(w, h));

  if (isClosedLoop) {
    final hit = _collectCircledText(points, blocks, l, b, r, t);
    if (hit != null) return hit;
    if (w >= 24 && h >= 24 && _looksLikeEllipse(points, l, b, r, t)) {
      return SmartInkCleanEllipse(rect: [l, b, r, t]);
    }
    return null;
  }

  // B. Yatay metin vuruşu: üstünü (fosforlu/üzerini çiz) veya altını çiz.
  final isHorizontal =
      w >= 14 && gap >= 0.40 * w && h <= math.max(24.0, w * 0.45);
  if (isHorizontal && blocks.isNotEmpty) {
    final markup = _matchHorizontalText(
      blocks: blocks,
      l: l,
      b: b,
      r: r,
      t: t,
      midY: _robustMidY(points, sumY / points.length),
      isHighlighter: isHighlighter,
      wavy: !isHighlighter && _isWavy(points, w),
    );
    if (markup != null) return markup;
  }

  // C. Metinsiz alanda düz doğru.
  if (totalLen >= 28 && gap >= 24 && gap >= 0.85 * totalLen) {
    var maxDist = 0.0;
    final vx = last.x - first.x;
    final vy = last.y - first.y;
    for (final pt in points) {
      final cross = ((pt.x - first.x) * vy - (pt.y - first.y) * vx).abs();
      final d = cross / gap;
      if (d > maxDist) maxDist = d;
    }
    if (maxDist <= math.max(5.0, gap * 0.075)) {
      return SmartInkCleanLine(
        points: [first.x, first.y, last.x, last.y],
        rect: [l, b, r, t],
      );
    }
  }

  return null;
}

SmartInkCircleText? _collectCircledText(
  List<({double x, double y})> poly,
  List<PdfTextBlock> blocks,
  double l,
  double b,
  double r,
  double t,
) {
  if (blocks.isEmpty) return null;
  final quads = <List<double>>[];
  final sb = StringBuffer();

  for (final blk in blocks) {
    if (blk.right < l - 4 ||
        blk.left > r + 4 ||
        blk.top < b - 4 ||
        blk.bottom > t + 4) {
      continue;
    }
    final map = blk.map;
    final ang = map.angle;
    final cs = math.cos(ang);
    final sn = math.sin(ang);
    int? minIdx;
    int? maxIdx;
    for (var i = 0; i < map.length; i++) {
      final li = map.line[i];
      if (li < 0 || li >= map.bases.length) continue;
      final fx = (map.xs[i] + map.xe[i]) * 0.5;
      final fy = map.bases[li] + map.sizes[li] * 0.35;
      final px = fx * cs - fy * sn;
      final py = fx * sn + fy * cs;
      if (px < l - 4 || px > r + 4 || py < b - 4 || py > t + 4) continue;
      if (_pointInPolygon(px, py, poly)) {
        minIdx ??= i;
        maxIdx = i;
      }
    }
    if (minIdx == null || maxIdx == null) continue;
    final raw = map.text.substring(minIdx, maxIdx + 1).trim();
    if (raw.isEmpty) continue;
    if (sb.isNotEmpty) sb.write('\n');
    sb.write(raw);
    for (final q in map.selection(minIdx, maxIdx + 1)) {
      quads.add([q[6], q[7], q[4], q[5], q[0], q[1], q[2], q[3]]);
    }
  }

  if (quads.isEmpty) return null;
  final text = sb.toString().trim();
  if (text.isEmpty) return null;
  return SmartInkCircleText(
    text: text,
    quads: quads,
    rect: _boundsOfQuads(quads),
  );
}

/// Vuruşun dikey ortası: baştaki/sondaki kanca (kalem iniş/kalkış kıvrımı)
/// sayılmasın diye uçlardan %15 atılır, kalanın ortancası alınır.
double _robustMidY(List<({double x, double y})> pts, double fallback) {
  if (pts.length < 5) return fallback;
  final cut = (pts.length * 0.15).floor();
  final ys = [for (var i = cut; i < pts.length - cut; i++) pts[i].y]..sort();
  if (ys.isEmpty) return fallback;
  return ys[ys.length ~/ 2];
}

/// Dalgalı mı: dikeyde en az 4 kez yön değiştiren (≥ 2,2 pt genlikli,
/// gürültü eşiği) yatay vuruş → "dalgalı alt çizgi".
bool _isWavy(List<({double x, double y})> pts, double w) {
  if (pts.length < 8 || w < 20) return false;
  const hyst = 2.2;
  var turns = 0;
  var dir = 0; // 1 yukarı, -1 aşağı
  var pivot = pts.first.y;
  for (final p in pts) {
    final d = p.y - pivot;
    if (dir >= 0 && d < -hyst) {
      if (dir == 1) turns++;
      dir = -1;
      pivot = p.y;
    } else if (dir <= 0 && d > hyst) {
      if (dir == -1) turns++;
      dir = 1;
      pivot = p.y;
    } else if ((dir == 1 && p.y > pivot) || (dir == -1 && p.y < pivot)) {
      pivot = p.y;
    }
  }
  return turns >= 4;
}

/// Bir metin satırının vuruşla eşleşen parçası.
class _LineHit {
  _LineHit(this.map, this.first, this.last, this.base, this.size, this.midPx,
      this.loY, this.hiY);
  final PdfBlockTextMap map;
  final int first, last;
  final double base, size, midPx, loY, hiY;
}

/// **Yatay vuruş → metin işareti** (2026-11-28 geliştirmesi, kullanıcı:
/// "akıllı mürekkep geliştirilmeli" — ekran görüntüsünde satır altına
/// biraz kaymış ve iki satır arasında kalan çizgiler ham mürekkep kalıyordu).
/// * Kalem: aday satırların her biri puanlanır, vuruşa EN YAKIN TEK satır
///   seçilir (eskiden pencereye giren her satır işaretleniyor, iki satır
///   arasındaki çizgi ya hiç ya ikisini birden tutuyordu). Alt çizgi penceresi
///   tabanın 1,25 punto altına dek (eski 0,95), üstü çizme harf gövdesinin
///   ortasında (0,2–0,65 punto); dalgalıysa dalgalı alt çizgi.
/// * Fosforlu: ince tek geçişte en yakın satır (satırın biraz altına/üstüne
///   kaymış olsa da); satırlardan uzun (zikzak/kalın) geçişte örtüştüğü
///   bütün satırlar.
SmartInkTextMarkup? _matchHorizontalText({
  required List<PdfTextBlock> blocks,
  required double l,
  required double b,
  required double r,
  required double t,
  required double midY,
  required bool isHighlighter,
  bool wavy = false,
}) {
  final hits = <_LineHit>[];
  for (final blk in blocks) {
    if (blk.right < l - 4 ||
        blk.left > r + 4 ||
        blk.top < b - 16 ||
        blk.bottom > t + 16) {
      continue;
    }
    final map = blk.map;
    final ang = map.angle;
    final cs = math.cos(ang);
    final sn = math.sin(ang);
    final fx = (blk.frameLeft + blk.frameRight) * 0.5;
    for (var li = 0; li < map.bases.length; li++) {
      final base = map.bases[li];
      final size = map.sizes[li];
      final midPx = _toPageY(fx, base, cs, sn);
      final topPx = _toPageY(fx, base + size * 0.9, cs, sn);
      final botPx = _toPageY(fx, base - size * 0.25, cs, sn);
      int? first;
      int? last;
      for (var i = 0; i < map.length; i++) {
        if (map.line[i] != li) continue;
        final cx = (map.xs[i] + map.xe[i]) * 0.5;
        final cy = base + size * 0.3;
        final px = cx * cs - cy * sn;
        if (px >= l - 4 && px <= r + 4) {
          first ??= i;
          last = i;
        }
      }
      if (first == null || last == null) continue;
      hits.add(_LineHit(map, first, last, base, size, midPx,
          math.min(botPx, topPx), math.max(botPx, topPx)));
    }
  }
  if (hits.isEmpty) return null;

  final chosen = <_LineHit>[];
  int? kind;
  if (isHighlighter) {
    final sizes = [for (final h in hits) h.size]..sort();
    final typical = sizes[sizes.length ~/ 2];
    final tall = (t - b) > 1.4 * typical;
    if (tall) {
      for (final h in hits) {
        final overlap = math.min(h.hiY, t + 2) - math.max(h.loY, b - 2);
        if (overlap >= 0.3 * (h.hiY - h.loY)) chosen.add(h);
      }
    } else {
      _LineHit? best;
      var bestD = double.infinity;
      for (final h in hits) {
        final center = (h.loY + h.hiY) * 0.5;
        final d = (midY - center).abs() / h.size;
        if (d < bestD) {
          bestD = d;
          best = h;
        }
      }
      // Satır kutusunun yarısı (~0,58 punto) + bir punto tolerans.
      if (best != null && bestD <= 1.6) chosen.add(best);
    }
    if (chosen.isNotEmpty) kind = PdfAnnotType.highlight;
  } else {
    _LineHit? best;
    int? bestKind;
    var bestD = double.infinity;
    for (final h in hits) {
      final rel = (midY - h.midPx) / h.size; // tabana göre, punto biriminde
      if (rel >= -1.25 && rel <= 0.2) {
        final d = (rel + 0.3).abs();
        if (d < bestD) {
          bestD = d;
          best = h;
          bestKind = PdfAnnotType.underline;
        }
      } else if (rel > 0.2 && rel <= 0.65) {
        // Üstü çizme harf gövdesinin ortasında, dar pencerede; harflerin
        // üst ucundan geçen çizgi üstteki satırın alt çizgisi sayılır.
        final d = (rel - 0.4).abs() * 1.2;
        if (d < bestD) {
          bestD = d;
          best = h;
          bestKind = PdfAnnotType.strikeout;
        }
      }
    }
    if (best != null) {
      chosen.add(best);
      kind = bestKind == PdfAnnotType.underline && wavy
          ? PdfAnnotType.squiggly
          : bestKind;
    }
  }
  if (chosen.isEmpty || kind == null) return null;

  final quads = <List<double>>[];
  for (final h in chosen) {
    final map = h.map;
    final (ws, _) = map.wordAt(h.first);
    final (_, we) = map.wordAt(h.last);
    final s = ws < h.first ? ws : h.first;
    final e = we > h.last + 1 ? we : h.last + 1;
    for (final q in map.selection(s, e)) {
      quads.add([q[6], q[7], q[4], q[5], q[0], q[1], q[2], q[3]]);
    }
  }
  if (quads.isEmpty) return null;
  return SmartInkTextMarkup(
    type: kind,
    quads: quads,
    rect: _boundsOfQuads(quads),
  );
}

double _toPageY(double fx, double fy, double cs, double sn) =>
    fx * sn + fy * cs;

bool _looksLikeEllipse(
  List<({double x, double y})> pts,
  double l,
  double b,
  double r,
  double t,
) {
  final cx = (l + r) * 0.5;
  final cy = (b + t) * 0.5;
  final rx = (r - l) * 0.5;
  final ry = (t - b) * 0.5;
  if (rx <= 0 || ry <= 0) return false;
  var err = 0.0;
  for (final pt in pts) {
    final dx = (pt.x - cx) / rx;
    final dy = (pt.y - cy) / ry;
    err += ((dx * dx + dy * dy) - 1.0).abs();
  }
  return (err / pts.length) <= 0.38;
}

bool _pointInPolygon(
  double x,
  double y,
  List<({double x, double y})> poly,
) {
  var inside = false;
  for (var i = 0, j = poly.length - 1; i < poly.length; j = i++) {
    final xi = poly[i].x, yi = poly[i].y;
    final xj = poly[j].x, yj = poly[j].y;
    final intersect = ((yi > y) != (yj > y)) &&
        (x < (xj - xi) * (y - yi) / ((yj - yi) == 0 ? 1e-9 : (yj - yi)) + xi);
    if (intersect) inside = !inside;
  }
  return inside;
}

List<double> _boundsOfQuads(List<List<double>> quads) {
  var l = double.infinity, b = double.infinity;
  var r = -double.infinity, t = -double.infinity;
  for (final q in quads) {
    for (var i = 0; i < 8; i += 2) {
      l = math.min(l, q[i]);
      r = math.max(r, q[i]);
      b = math.min(b, q[i + 1]);
      t = math.max(t, q[i + 1]);
    }
  }
  return [l, b, r, t];
}

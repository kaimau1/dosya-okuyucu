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
    final midY = sumY / points.length;
    final markup = _matchHorizontalText(
      blocks: blocks,
      l: l,
      b: b,
      r: r,
      t: t,
      midY: midY,
      isHighlighter: isHighlighter,
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

SmartInkTextMarkup? _matchHorizontalText({
  required List<PdfTextBlock> blocks,
  required double l,
  required double b,
  required double r,
  required double t,
  required double midY,
  required bool isHighlighter,
}) {
  final quads = <List<double>>[];
  int? kind;

  for (final blk in blocks) {
    if (blk.right < l - 4 ||
        blk.left > r + 4 ||
        blk.top < b - 10 ||
        blk.bottom > t + 10) {
      continue;
    }
    final map = blk.map;
    final ang = map.angle;
    final cs = math.cos(ang);
    final sn = math.sin(ang);

    for (var li = 0; li < map.bases.length; li++) {
      final base = map.bases[li];
      final size = map.sizes[li];
      final lineBottom = base - size * 0.25;
      final lineTop = base + size * 0.9;
      final lineMidPx = _toPageY(
          (blk.frameLeft + blk.frameRight) * 0.5, base, cs, sn);
      final lineTopPx = _toPageY(
          (blk.frameLeft + blk.frameRight) * 0.5, lineTop, cs, sn);
      final lineBotPx = _toPageY(
          (blk.frameLeft + blk.frameRight) * 0.5, lineBottom, cs, sn);
      final loY = math.min(lineBotPx, lineTopPx);
      final hiY = math.max(lineBotPx, lineTopPx);

      int? lineKind;
      if (isHighlighter) {
        if (hiY >= b - 4 && loY <= t + 4) {
          lineKind = PdfAnnotType.highlight;
        }
      } else {
        final dBase = midY - lineMidPx;
        if (dBase >= -size * 0.95 && dBase <= size * 0.25) {
          lineKind = PdfAnnotType.underline;
        } else if (dBase > size * 0.25 && dBase <= size * 0.85) {
          lineKind = PdfAnnotType.strikeout;
        }
      }
      if (lineKind == null) continue;

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
      final (ws, _) = map.wordAt(first);
      final (_, we) = map.wordAt(last);
      final s = ws < first ? ws : first;
      final e = we > last + 1 ? we : last + 1;
      final selQuads = map.selection(s, e);
      if (selQuads.isEmpty) continue;
      kind ??= lineKind;
      for (final q in selQuads) {
        quads.add([q[6], q[7], q[4], q[5], q[0], q[1], q[2], q[3]]);
      }
    }
  }

  if (quads.isEmpty || kind == null) return null;
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

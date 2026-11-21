import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/l10n/app_strings.dart';
import '../services/pptx_render.dart';
import '../core/app_colors.dart';

/// [ChartVM]'i çizer: sütun/çubuk (yan yana, yığılmış, %100), pasta/halka,
/// çizgi, alan, dağılım (XY), radar + lejant; Excel ve Slayt ORTAK çizici. Veri, seri renkleri ve
/// kategoriler PowerPoint'le aynıdır; eksen/lejant stili sadeleştirilmiştir
/// (3B, gradient, ızgara süsü yok) — okunur ve doğru oranlı bir grafik.
class ChartPainter extends CustomPainter {
  final ChartVM chart;
  const ChartPainter(this.chart);

  static const _axis = Color(0xFFD0D0D0);
  static const _label = Color(0xFF595959);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width < 8 || size.height < 8) return;
    final fs = (size.height * 0.04).clamp(6.0, 12.0);
    var plot = Offset.zero & size;
    if (chart.showLegend) plot = _legend(canvas, plot, fs);

    switch (chart.type) {
      case ChartType.pie:
        _pie(canvas, plot);
        break;
      case ChartType.line:
        _barsOrLine(canvas, plot, fs, line: true);
        break;
      case ChartType.bar:
        _bars(canvas, plot, fs, horizontal: true);
        break;
      case ChartType.column:
        _barsOrLine(canvas, plot, fs, line: false);
        break;
      case ChartType.area:
        _barsOrLine(canvas, plot, fs, line: true, fillArea: true);
        break;
      case ChartType.scatter:
        _scatter(canvas, plot, fs);
        break;
      case ChartType.radar:
        _radar(canvas, plot, fs);
        break;
    }
    if (chart.approx) _approxBadge(canvas, size, fs);
  }

  // -------------------------------------------------------------- yardımcı

  TextPainter _tp(String s, double fs, {double? maxW}) {
    final tp = TextPainter(
      text: TextSpan(text: s, style: TextStyle(fontSize: fs, color: _label)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxW ?? double.infinity);
    return tp;
  }

  String _fmt(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

  ({double min, double max}) _range([bool secondary = false]) {
    var mn = 0.0, mx = 0.0;
    for (final s in chart.series) {
      if (s.secondary != secondary) continue;
      for (final v in s.values) {
        mn = math.min(mn, v);
        mx = math.max(mx, v);
      }
    }
    if (mn == mx) mx = mn + 1;
    return (min: mn, max: mx);
  }

  /// Değer ekseni etiketi (%100 yığılmışta "%" ekli).
  String _vfmt(double v) =>
      chart.grouping == ChartGrouping.percent ? '${_fmt(v)}%' : _fmt(v);

  /// Yığılmış / %100: her serinin kategori başına (taban, uç) değeri; artılar
  /// yukarı, eksiler aşağı birikir (Excel gibi). Yan yana grafikte null.
  List<List<(double, double)>>? _stack(int n) {
    if (chart.grouping == ChartGrouping.standard) return null;
    final pct = chart.grouping == ChartGrouping.percent;
    double at(ChartSeries s, int c) => c < s.values.length ? s.values[c] : 0.0;
    final total = List.filled(n, 0.0);
    if (pct) {
      for (final s in chart.series) {
        for (var c = 0; c < n; c++) {
          total[c] += at(s, c).abs();
        }
      }
    }
    final pos = List.filled(n, 0.0), neg = List.filled(n, 0.0);
    final out = <List<(double, double)>>[];
    for (final s in chart.series) {
      final row = <(double, double)>[];
      for (var c = 0; c < n; c++) {
        var v = at(s, c);
        if (pct) v = total[c] == 0 ? 0 : v / total[c] * 100;
        final acc = v >= 0 ? pos : neg;
        final base = acc[c];
        acc[c] += v;
        row.add((base, acc[c]));
      }
      out.add(row);
    }
    return out;
  }

  ({double min, double max}) _stackRange(List<List<(double, double)>> st) {
    var mn = 0.0, mx = 0.0;
    for (final row in st) {
      for (final (_, e) in row) {
        mn = math.min(mn, e);
        mx = math.max(mx, e);
      }
    }
    if (mn == mx) mx = mn + 1;
    return (min: mn, max: mx);
  }

  int get _catCount => chart.categories.isNotEmpty
      ? chart.categories.length
      : chart.series.fold<int>(0, (m, s) => math.max(m, s.values.length));

  // -------------------------------------------------------------- lejant

  Rect _legend(Canvas canvas, Rect area, double fs) {
    final items = <(String, Color)>[];
    if (chart.type == ChartType.pie && chart.series.isNotEmpty) {
      final s = chart.series.first;
      for (var i = 0; i < s.values.length; i++) {
        final l = i < chart.categories.length ? chart.categories[i] :
            AppStrings.current.t('uix.item_n', {'n': i + 1});
        items.add((l, s.pointColors[i] ?? const Color(0xFF888888)));
      }
    } else {
      for (final s in chart.series) {
        items.add((s.name, s.color));
      }
    }
    if (items.isEmpty) return area;

    final h = (fs * 1.8).clamp(12.0, area.height * 0.28);
    final cy = area.bottom - h / 2;
    final box = fs, gap = fs * 0.7;
    final tps = [for (final it in items) _tp(it.$1, fs)];
    var total = 0.0;
    for (final tp in tps) {
      total += box + 3 + tp.width + gap;
    }
    var x = area.left + math.max(0.0, (area.width - total) / 2);
    for (var i = 0; i < items.length; i++) {
      canvas.drawRect(
          Rect.fromLTWH(x, cy - box / 2, box, box), Paint()..color = items[i].$2);
      x += box + 3;
      tps[i].paint(canvas, Offset(x, cy - tps[i].height / 2));
      x += tps[i].width + gap;
    }
    for (final tp in tps) {
      tp.dispose();
    }
    return Rect.fromLTRB(area.left, area.top, area.right, area.bottom - h);
  }

  // -------------------------------------------------------------- pasta

  void _pie(Canvas canvas, Rect area) {
    if (chart.series.isEmpty) return;
    final s = chart.series.first;
    var total = 0.0;
    for (final v in s.values) {
      total += v.abs();
    }
    if (total <= 0) return;

    final r = math.min(area.width, area.height) / 2 * 0.88;
    final c = area.center;
    final inner = chart.doughnut ? r * 0.55 : 0.0;
    final edge = Paint()
      ..color = AppColors.page
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    var start = -math.pi / 2;
    for (var i = 0; i < s.values.length; i++) {
      final sweep = s.values[i].abs() / total * 2 * math.pi;
      if (sweep <= 0) continue;
      final paint = Paint()
        ..color = s.pointColors[i] ?? const Color(0xFF888888)
        ..style = PaintingStyle.fill;
      final rect = Rect.fromCircle(center: c, radius: r);
      if (inner > 0) {
        final ir = Rect.fromCircle(center: c, radius: inner);
        final p = Path()
          ..moveTo(c.dx + inner * math.cos(start), c.dy + inner * math.sin(start))
          ..lineTo(c.dx + r * math.cos(start), c.dy + r * math.sin(start))
          ..arcTo(rect, start, sweep, false)
          ..lineTo(c.dx + inner * math.cos(start + sweep),
              c.dy + inner * math.sin(start + sweep))
          ..arcTo(ir, start + sweep, -sweep, false)
          ..close();
        canvas.drawPath(p, paint);
      } else {
        canvas.drawArc(rect, start, sweep, true, paint);
      }
      canvas.drawArc(rect, start, sweep, true, edge);
      start += sweep;
    }
  }

  // ------------------------------------------------ sütun / çizgi (dikey değer)

  void _barsOrLine(Canvas canvas, Rect area, double fs,
      {required bool line, bool fillArea = false}) {
    final n = _catCount;
    if (n == 0) return;
    final stack = _stack(n);
    final rng = stack == null ? _range() : _stackRange(stack);
    final span = rng.max - rng.min;
    // İkincil eksen (Faz 36): ayrı ölçek, etiketleri sağda.
    final hasSecondary = chart.series.any((x) => x.secondary);
    final rng2 = hasSecondary ? _range(true) : rng;
    final span2 = rng2.max - rng2.min;

    // Değer etiketleri için sol boşluk, kategori etiketleri için alt boşluk.
    final maxLbl = _tp(_vfmt(rng.max), fs);
    final leftPad = maxLbl.width + 6;
    maxLbl.dispose();
    var rightPad = fs * 0.5;
    if (hasSecondary) {
      final l2 = _tp(_fmt(rng2.max), fs);
      rightPad = l2.width + 6;
      l2.dispose();
    }
    final bottomPad = fs * 1.5;
    final plot = Rect.fromLTRB(
        area.left + leftPad, area.top + fs, area.right - rightPad, area.bottom - bottomPad);
    if (plot.width <= 0 || plot.height <= 0) return;

    double yFor(double v) => plot.bottom - (v - rng.min) / span * plot.height;
    double yOf(ChartSeries s, double v) => s.secondary
        ? plot.bottom - (v - rng2.min) / span2 * plot.height
        : yFor(v);
    if (hasSecondary) {
      for (final t in [rng2.min, rng2.min + span2 / 2, rng2.max]) {
        final tp = _tp(_fmt(t), fs);
        final y = plot.bottom - (t - rng2.min) / span2 * plot.height;
        tp.paint(canvas, Offset(plot.right + 3, y - tp.height / 2));
        tp.dispose();
      }
    }

    // Değer ızgarası (3 çizgi) + etiketleri.
    for (final t in [rng.min, rng.min + span / 2, rng.max]) {
      final y = yFor(t);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y),
          Paint()..color = _axis..strokeWidth = 0.7);
      final tp = _tp(_vfmt(t), fs);
      tp.paint(canvas, Offset(plot.left - tp.width - 3, y - tp.height / 2));
      tp.dispose();
    }

    final baseValue = rng.min < 0 ? 0.0 : rng.min;
    final baseline = yFor(baseValue);
    final groupW = plot.width / n;
    // Serinin c. noktası (taban, uç): yığılmışta birikmiş, değilse eksenden.
    (double, double) pt(ChartSeries s, int c) {
      if (stack != null) return stack[chart.series.indexOf(s)][c];
      return (baseValue, c < s.values.length ? s.values[c] : 0.0);
    }

    final barSeries = [
      if (!line)
        for (final s in chart.series)
          if (!s.asLine) s,
    ];
    final lineSeries = [
      for (final s in chart.series)
        if (line || s.asLine) s,
    ];
    if (lineSeries.isNotEmpty) {
      for (final s in lineSeries) {
        final path = Path();
        final dots = <Offset>[];
        for (var i = 0; i < n; i++) {
          final v = pt(s, i).$2;
          final x = plot.left + groupW * (i + 0.5);
          final o = Offset(x, yOf(s, v));
          if (i == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
          dots.add(o);
        }
        if (fillArea) {
          // Alan: uçlardan ileri, tabandan geri kapanan çokgen.
          final poly = Path()..addPolygon(dots, false);
          for (var i = n - 1; i >= 0; i--) {
            poly.lineTo(dots[i].dx, yOf(s, pt(s, i).$1));
          }
          poly.close();
          canvas.drawPath(poly, Paint()..color = s.color);
          dots.clear();
        }
        canvas.drawPath(
            path,
            Paint()
              ..color = s.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, area.height * 0.006)
              ..strokeJoin = StrokeJoin.round);
        for (final d in dots) {
          canvas.drawCircle(d, math.max(1.5, area.height * 0.008),
              Paint()..color = s.color);
        }
      }
    }
    if (barSeries.isNotEmpty) {
      // Yığılmışta tüm seriler aynı sütunda üst üste.
      final m = stack == null ? barSeries.length : 1;
      final gap = groupW * 0.15;
      final barW = (groupW - 2 * gap) / math.max(1, m);
      for (var c = 0; c < n; c++) {
        for (var si = 0; si < barSeries.length; si++) {
          final (b, v) = pt(barSeries[si], c);
          final x =
              plot.left + c * groupW + gap + (stack == null ? si : 0) * barW;
          final yv = yOf(barSeries[si], v);
          final yb = stack == null ? baseline : yFor(b);
          final top = math.min(yv, yb), bot = math.max(yv, yb);
          canvas.drawRect(Rect.fromLTWH(x, top, barW * 0.88, bot - top),
              // Nokta rengi (`c:dPt`, şelale artış/azalış) seri rengini ezer.
              Paint()
                ..color = barSeries[si].pointColors[c] ?? barSeries[si].color);
        }
      }
    }
    // Doğrusal eğilim çizgisi (en küçük kareler) — Faz 36.
    for (final s in chart.series) {
      if (!s.trend) continue;
      final fit = linearFit(s.values.take(n).toList());
      if (fit == null) continue;
      final (a, b) = fit;
      double xAt(int i) => plot.left + groupW * (i + 0.5);
      canvas.drawLine(
          Offset(xAt(0), yOf(s, a)),
          Offset(xAt(n - 1), yOf(s, a + b * (n - 1))),
          Paint()
            ..color = s.color.withValues(alpha: 0.8)
            ..strokeWidth = math.max(1.0, area.height * 0.004));
    }
    // Çizgiler çubukların ÜSTÜNDE kalsın diye yeniden (kombinasyon).
    if (barSeries.isNotEmpty && lineSeries.isNotEmpty) {
      for (final s in lineSeries) {
        final path = Path();
        for (var i = 0; i < n; i++) {
          final v = pt(s, i).$2;
          final o = Offset(plot.left + groupW * (i + 0.5), yOf(s, v));
          if (i == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
        }
        canvas.drawPath(
            path,
            Paint()
              ..color = s.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, area.height * 0.006));
      }
    }
    _catLabels(canvas, plot, fs, n, groupW);
  }

  void _catLabels(Canvas canvas, Rect plot, double fs, int n, double groupW) {
    for (var c = 0; c < n; c++) {
      if (c >= chart.categories.length) continue;
      final tp = _tp(chart.categories[c], fs, maxW: groupW);
      tp.paint(canvas,
          Offset(plot.left + groupW * c + (groupW - tp.width) / 2, plot.bottom + 3));
      tp.dispose();
    }
  }

  // ------------------------------------------------ çubuk (yatay değer)

  void _bars(Canvas canvas, Rect area, double fs, {required bool horizontal}) {
    final n = _catCount;
    if (n == 0) return;
    final stack = _stack(n);
    final rng = stack == null ? _range() : _stackRange(stack);
    final span = rng.max - rng.min;

    // En geniş kategori etiketi için sol boşluk.
    var catW = 0.0;
    for (final cat in chart.categories) {
      final tp = _tp(cat, fs);
      catW = math.max(catW, tp.width);
      tp.dispose();
    }
    final leftPad = math.min(catW + 6, area.width * 0.35);
    final plot = Rect.fromLTRB(area.left + leftPad, area.top + fs,
        area.right - fs, area.bottom - fs * 1.4);
    if (plot.width <= 0 || plot.height <= 0) return;

    double xFor(double v) => plot.left + (v - rng.min) / span * plot.width;

    for (final t in [rng.min, rng.min + span / 2, rng.max]) {
      final x = xFor(t);
      canvas.drawLine(Offset(x, plot.top), Offset(x, plot.bottom),
          Paint()..color = _axis..strokeWidth = 0.7);
      final tp = _tp(_vfmt(t), fs);
      tp.paint(canvas, Offset(x - tp.width / 2, plot.bottom + 3));
      tp.dispose();
    }

    final baseX = xFor(rng.min < 0 ? 0 : rng.min);
    final groupH = plot.height / n;
    final m = chart.series.length;
    final gap = groupH * 0.15;
    final barH = (groupH - 2 * gap) / math.max(1, stack == null ? m : 1);
    for (var c = 0; c < n; c++) {
      for (var si = 0; si < m; si++) {
        final vals = chart.series[si].values;
        final v = stack?[si][c].$2 ?? (c < vals.length ? vals[c] : 0.0);
        final y = plot.top + c * groupH + gap + (stack == null ? si : 0) * barH;
        final xv = xFor(v);
        final xb = stack == null ? baseX : xFor(stack[si][c].$1);
        final l = math.min(xv, xb), r = math.max(xv, xb);
        canvas.drawRect(Rect.fromLTWH(l, y, r - l, barH * 0.88),
            Paint()..color = chart.series[si].color);
      }
      if (c < chart.categories.length) {
        final tp = _tp(chart.categories[c], fs, maxW: leftPad - 4);
        tp.paint(canvas,
            Offset(plot.left - tp.width - 4, plot.top + groupH * (c + 0.5) - tp.height / 2));
        tp.dispose();
      }
    }
  }

  // ------------------------------------------------ dağılım (XY)

  void _scatter(Canvas canvas, Rect area, double fs) {
    List<double> xsOf(ChartSeries s) =>
        s.xValues ?? [for (var i = 0; i < s.values.length; i++) i + 1.0];
    var mnX = 0.0, mxX = 0.0;
    for (final s in chart.series) {
      for (final x in xsOf(s)) {
        mnX = math.min(mnX, x);
        mxX = math.max(mxX, x);
      }
    }
    if (mnX == mxX) mxX = mnX + 1;
    final rng = _range();
    final maxLbl = _tp(_fmt(rng.max), fs);
    final plot = Rect.fromLTRB(area.left + maxLbl.width + 6, area.top + fs,
        area.right - fs, area.bottom - fs * 1.5);
    maxLbl.dispose();
    if (plot.width <= 0 || plot.height <= 0) return;
    double xFor(double v) => plot.left + (v - mnX) / (mxX - mnX) * plot.width;
    double yFor(double v) =>
        plot.bottom - (v - rng.min) / (rng.max - rng.min) * plot.height;
    final grid = Paint()
      ..color = _axis
      ..strokeWidth = 0.7;
    for (var k = 0; k <= 2; k++) {
      final ty = rng.min + (rng.max - rng.min) * k / 2;
      final y = yFor(ty);
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final tp = _tp(_fmt(ty), fs);
      tp.paint(canvas, Offset(plot.left - tp.width - 3, y - tp.height / 2));
      tp.dispose();
      final tx = mnX + (mxX - mnX) * k / 2;
      final xl = _tp(_fmt(tx), fs);
      xl.paint(canvas, Offset(xFor(tx) - xl.width / 2, plot.bottom + 3));
      xl.dispose();
    }
    canvas.drawLine(plot.bottomLeft, plot.topLeft, grid);
    final r = math.max(2.0, area.height * 0.012);
    for (final s in chart.series) {
      final xs = xsOf(s);
      final pts = [
        for (var i = 0; i < math.min(xs.length, s.values.length); i++)
          Offset(xFor(xs[i]), yFor(s.values[i])),
      ];
      if (s.asLine && pts.length > 1) {
        canvas.drawPath(
            Path()..addPolygon(pts, false),
            Paint()
              ..color = s.color
              ..style = PaintingStyle.stroke
              ..strokeWidth = math.max(1.5, area.height * 0.006));
      }
      for (final o in pts) {
        canvas.drawCircle(o, r, Paint()..color = s.color);
      }
    }
  }

  // ------------------------------------------------ radar

  void _radar(Canvas canvas, Rect area, double fs) {
    final n = _catCount;
    if (n == 0) return;
    final rng = _range();
    final span = rng.max - rng.min;
    final c = area.center;
    final rad = math.min(area.width, area.height) / 2 - fs * 1.8;
    if (rad <= 4) return;
    Offset at(int i, double v) {
      final a = -math.pi / 2 + 2 * math.pi * i / n;
      final k = (v - rng.min) / span * rad;
      return c + Offset(math.cos(a) * k, math.sin(a) * k);
    }

    final grid = Paint()
      ..color = _axis
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.7;
    for (final lv in const [1 / 3, 2 / 3, 1.0]) {
      canvas.drawPath(
          Path()
            ..addPolygon(
                [for (var i = 0; i < n; i++) at(i, rng.min + span * lv)], true),
          grid);
    }
    for (var i = 0; i < n; i++) {
      final edge = at(i, rng.max);
      canvas.drawLine(c, edge, grid);
      if (i < chart.categories.length) {
        final tp = _tp(chart.categories[i], fs, maxW: rad);
        final dir = (edge - c) / rad;
        final o = edge + dir * (fs * 0.9);
        tp.paint(canvas, o - Offset(tp.width / 2, tp.height / 2));
        tp.dispose();
      }
    }
    final mx = _tp(_fmt(rng.max), fs);
    mx.paint(canvas, at(0, rng.max) + Offset(3, -mx.height / 2));
    mx.dispose();
    for (final s in chart.series) {
      final poly = Path()
        ..addPolygon([
          for (var i = 0; i < n; i++)
            at(i, i < s.values.length ? s.values[i] : 0.0),
        ], true);
      if (chart.filled) {
        canvas.drawPath(
            poly, Paint()..color = s.color.withValues(alpha: 0.45));
      }
      canvas.drawPath(
          poly,
          Paint()
            ..color = s.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = math.max(1.5, area.height * 0.006)
            ..strokeJoin = StrokeJoin.round);
    }
  }

  /// Dosyadaki tür en yakın türle çizildi: sağ üstte küçük "≈ yaklaşık".
  void _approxBadge(Canvas canvas, Size size, double fs) {
    final tp = _tp(AppStrings.current.t('chart.approx'), fs);
    final r = Rect.fromLTWH(
        size.width - tp.width - 10, 2, tp.width + 8, tp.height + 4);
    canvas.drawRRect(RRect.fromRectAndRadius(r, Radius.circular(fs * 0.4)),
        Paint()..color = AppColors.chartApproxBadge);
    tp.paint(canvas, r.topLeft + const Offset(4, 2));
    tp.dispose();
  }

  /// En küçük kareler doğrusu `y = a + b·i` (i = 0..n-1); 2 noktadan azsa null.
  static (double, double)? linearFit(List<double> ys) {
    final n = ys.length;
    if (n < 2) return null;
    var sx = 0.0, sy = 0.0, sxx = 0.0, sxy = 0.0;
    for (var i = 0; i < n; i++) {
      sx += i;
      sy += ys[i];
      sxx += i * i;
      sxy += i * ys[i];
    }
    final d = n * sxx - sx * sx;
    if (d == 0) return null;
    final b = (n * sxy - sx * sy) / d;
    return ((sy - b * sx) / n, b);
  }

  @override
  bool shouldRepaint(ChartPainter old) => old.chart != chart;
}

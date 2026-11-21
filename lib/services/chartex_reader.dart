import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:xml/xml.dart';

import 'pptx_render.dart';

/// B10 m.1 — Office 2016 "chartex" grafikleri (`cx:chartSpace`: şelale,
/// histogram, Pareto, kutu-bıyık; huni/ağaç haritası/güneş patlaması/harita
/// yaklaşık) → mevcut [ChartVM] + `ChartPainter`.
///
/// Çizim hilesi: şelale ve kutu, görünmez taban serisi + renkli üst seri
/// olan **yığılmış sütun** — çiziciye yeni tür eklemeden yüzen çubuk.
/// ponytail: tabanı eksiye inen şelale/kutu doğru çizilmez (yığın eksiyi
/// aşağı biriktirir) → `approx` rozeti; gerekirse çiziciye yüzen çubuk.
///
/// Değerler grafiğin kendi verisinden (`cx:chartData/cx:data` → `cx:lvl`).
abstract final class ChartExReader {
  static const namespace = 'http://schemas.microsoft.com/office/drawing/2014/chartex';

  static bool isChartEx(XmlDocument doc) =>
      doc.rootElement.name.namespaceUri == namespace ||
      (doc.rootElement.name.local == 'chartSpace' &&
          doc.rootElement.name.prefix == 'cx');

  // Excel'in varsayılan chartex renkleri (Office teması aksan 1–3).
  static const _increase = Color.fromARGB(255, 0x44, 0x72, 0xC4);
  static const _decrease = Color.fromARGB(255, 0xED, 0x7D, 0x31);
  static const _total = Color.fromARGB(255, 0xA5, 0xA5, 0xA5);
  static const _clear = Color.fromARGB(0, 0, 0, 0);
  static const _palette = [
    _increase,
    _decrease,
    _total,
    Color.fromARGB(255, 0xFF, 0xC0, 0x00),
    Color.fromARGB(255, 0x5B, 0x9B, 0xD5),
    Color.fromARGB(255, 0x70, 0xAD, 0x47),
  ];

  static ChartVM? parse(XmlDocument doc) {
    final root = doc.rootElement;
    // vals: boş nokta 0 (sıra korunur); given: yalnız dolu noktalar
    // (histogram/kutu boşu saymaz).
    final data = <String,
        ({List<String> cats, List<double> vals, List<double> given})>{};
    for (final d in _all(root, 'data')) {
      final id = d.getAttribute('id') ?? '';
      final str = _kids(d, 'strDim').firstOrNull;
      final numDim = _kids(d, 'numDim').firstOrNull;
      final raw = numDim == null
          ? const <double?>[]
          : [for (final s in _lvl(numDim)) double.tryParse(s.trim())];
      data[id] = (
        cats: str == null ? const [] : _lvl(str),
        vals: [for (final v in raw) v ?? 0],
        given: [for (final v in raw) ?v],
      );
    }
    final region = _all(root, 'plotAreaRegion').firstOrNull;
    if (region == null) return null;
    final sers = _kids(region, 'series').toList();
    if (sers.isEmpty) return null;
    final first = sers.first;
    final layout = first.getAttribute('layoutId') ?? '';
    final d = data[_kid(first, 'dataId')?.getAttribute('val') ?? '0'] ??
        data.values.firstOrNull;
    if (d == null || d.vals.isEmpty) return null;
    final name = _seriesName(first) ?? '';
    final legend = _all(root, 'legend').isNotEmpty;
    switch (layout) {
      case 'waterfall':
        return _waterfall(first, d.cats, d.vals, name);
      case 'clusteredColumn':
        final binning = _all(first, 'binning').firstOrNull;
        if (binning != null || d.cats.isEmpty) {
          return _histogram(d.given, binning, name);
        }
        return _pareto(d.cats, d.vals, name,
            withLine: sers.any((s) => s.getAttribute('layoutId') == 'paretoLine'));
      case 'boxWhisker':
        return _box([
          for (var i = 0; i < sers.length; i++)
            if (sers[i].getAttribute('layoutId') == 'boxWhisker')
              (
                name: _seriesName(sers[i]) ?? 'Seri ${i + 1}',
                vals: data[_kid(sers[i], 'dataId')?.getAttribute('val') ?? '']
                        ?.given ??
                    const <double>[],
                color: _palette[i % _palette.length],
              ),
        ], exclusive: _all(first, 'statistics').firstOrNull
                ?.getAttribute('quartileMethod') !=
            'inclusive');
      case 'funnel':
        return ChartVM(
          type: ChartType.bar,
          categories: d.cats,
          series: [ChartSeries(name: name, color: _increase, values: d.vals)],
          approx: true,
        );
      case 'treemap' || 'sunburst':
        return ChartVM(
          type: ChartType.pie,
          categories: d.cats,
          series: [
            ChartSeries(name: name, color: _increase, values: d.vals, pointColors: {
              for (var i = 0; i < d.vals.length; i++)
                i: _palette[i % _palette.length],
            }),
          ],
          showLegend: legend,
          approx: true,
        );
      default:
        return ChartVM(
          type: ChartType.column,
          categories: d.cats,
          series: [ChartSeries(name: name, color: _increase, values: d.vals)],
          approx: true,
        );
    }
  }

  // ── şelale ──────────────────────────────────────────────────────────────

  /// Ara toplam noktası (`cx:subtotals/cx:idx`) sıfırdan kendi değerine
  /// çizilir ve birikimi o değere kurar (Excel "toplam olarak ayarla").
  static ChartVM _waterfall(
      XmlElement ser, List<String> cats, List<double> vals, String name) {
    final totals = {
      for (final i in _all(ser, 'subtotals').expand((s) => _kids(s, 'idx')))
        ?int.tryParse(i.getAttribute('val') ?? ''),
    };
    final base = <double>[], bar = <double>[];
    final colors = <int, Color>{};
    var run = 0.0;
    var negative = false;
    for (var i = 0; i < vals.length; i++) {
      final v = vals[i];
      if (totals.contains(i)) {
        base.add(0);
        bar.add(v);
        colors[i] = _total;
        run = v;
      } else {
        final to = run + v;
        base.add(math.min(run, to));
        bar.add(v.abs());
        colors[i] = v >= 0 ? _increase : _decrease;
        run = to;
      }
      if (base.last < 0 || bar.last < 0) negative = true;
    }
    return ChartVM(
      type: ChartType.column,
      grouping: ChartGrouping.stacked,
      categories: cats,
      series: [
        ChartSeries(name: '', color: _clear, values: base),
        ChartSeries(name: name, color: _increase, values: bar, pointColors: colors),
      ],
      approx: negative,
    );
  }

  // ── histogram / Pareto ──────────────────────────────────────────────────

  /// Kutu sayısı: `binCount`, `binSize` ya da Excel'in otomatiği (Scott
  /// kuralı: genişlik = 3,5·σ / n^⅓). Aralıklar sağdan kapalı `(a, b]`, ilki
  /// `[min, b]` (Excel'in varsayılanı). ponytail: taşma/alt taşma kutusu
  /// (`overflow`/`underflow`) okunmaz.
  static ChartVM? _histogram(
      List<double> vals, XmlElement? binning, String name) {
    if (vals.isEmpty) return null;
    final sorted = [...vals]..sort();
    final mn = sorted.first, mx = sorted.last;
    final count = int.tryParse(
        _kid(binning, 'binCount')?.getAttribute('val') ?? '');
    final size = double.tryParse(
        _kid(binning, 'binSize')?.getAttribute('val') ?? '');
    double width;
    if (count != null && count > 0) {
      width = (mx - mn) / count;
    } else if (size != null && size > 0) {
      width = size;
    } else {
      final n = vals.length;
      final mean = vals.reduce((a, b) => a + b) / n;
      final sd = n < 2
          ? 0.0
          : math.sqrt(vals.fold(0.0, (s, v) => s + (v - mean) * (v - mean)) /
              (n - 1));
      width = 3.5 * sd / math.pow(n, 1 / 3);
    }
    var bins = width <= 0 ? 1 : ((mx - mn) / width).ceil();
    if (bins < 1) bins = 1;
    if (bins > 200) bins = 200;
    if (width <= 0) width = 1;
    final counts = List.filled(bins, 0.0);
    for (final v in vals) {
      // (a, b] — sınırdaki değer soldaki kutuya; min ilk kutuya.
      final k = ((v - mn) / width).ceil() - 1;
      counts[k.clamp(0, bins - 1)] += 1;
    }
    String f(double v) => v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '');
    return ChartVM(
      type: ChartType.column,
      categories: [
        for (var i = 0; i < bins; i++)
          '${i == 0 ? '[' : '('}${f(mn + i * width)}, ${f(mn + (i + 1) * width)}]',
      ],
      series: [ChartSeries(name: name, color: _increase, values: counts)],
    );
  }

  /// Pareto: değerler büyükten küçüğe, birikimli yüzde çizgisi ikincil
  /// eksende (`paretoLine`).
  static ChartVM _pareto(List<String> cats, List<double> vals, String name,
      {required bool withLine}) {
    final order = [for (var i = 0; i < vals.length; i++) i]
      ..sort((a, b) {
        final c = vals[b].compareTo(vals[a]);
        return c != 0 ? c : a.compareTo(b); // eşitte dosya sırası
      });
    final total = vals.fold(0.0, (s, v) => s + v);
    var acc = 0.0;
    return ChartVM(
      type: ChartType.column,
      categories: [for (final i in order) i < cats.length ? cats[i] : '${i + 1}'],
      series: [
        ChartSeries(
            name: name, color: _increase, values: [for (final i in order) vals[i]]),
        if (withLine)
          ChartSeries(
            name: '%',
            color: _decrease,
            asLine: true,
            secondary: true,
            values: [
              for (final i in order) total == 0 ? 0 : (acc += vals[i]) / total * 100,
            ],
          ),
      ],
    );
  }

  // ── kutu-bıyık ──────────────────────────────────────────────────────────

  /// Seri başına bir kutu: Ç1–ortanca–Ç3 (bıyıklar çizilmez → `approx`).
  static ChartVM? _box(
      List<({String name, List<double> vals, Color color})> sets,
      {required bool exclusive}) {
    final ok = [for (final s in sets) if (s.vals.isNotEmpty) s];
    if (ok.isEmpty) return null;
    final q = [for (final s in ok) quartiles(s.vals, exclusive: exclusive)];
    return ChartVM(
      type: ChartType.column,
      grouping: ChartGrouping.stacked,
      categories: [for (final s in ok) s.name],
      series: [
        ChartSeries(name: '', color: _clear, values: [for (final x in q) x.$1]),
        ChartSeries(
            name: '',
            color: _increase,
            values: [for (final x in q) x.$2 - x.$1],
            pointColors: {for (var i = 0; i < ok.length; i++) i: ok[i].color}),
        ChartSeries(
            name: '',
            color: _increase,
            values: [for (final x in q) x.$3 - x.$2],
            pointColors: {
              for (var i = 0; i < ok.length; i++)
                i: ok[i].color.withValues(alpha: 0.6),
            }),
      ],
      approx: true,
    );
  }

  /// (Ç1, ortanca, Ç3) — Excel QUARTILE.EXC (konum p·(n+1)) ya da
  /// QUARTILE.INC (konum p·(n−1)+1).
  static (double, double, double) quartiles(List<double> vals,
      {bool exclusive = true}) {
    final s = [...vals]..sort();
    final n = s.length;
    double at(double p) {
      var pos = exclusive ? p * (n + 1) : p * (n - 1) + 1;
      pos = pos.clamp(1.0, n.toDouble());
      final lo = pos.floor();
      final frac = pos - lo;
      final a = s[lo - 1];
      final b = lo < n ? s[lo] : a;
      return a + (b - a) * frac;
    }

    return (at(0.25), at(0.5), at(0.75));
  }

  // ── XML yardımcıları (önek bağımsız: yerel ad) ──────────────────────────

  static Iterable<XmlElement> _all(XmlElement e, String local) =>
      e.descendants.whereType<XmlElement>().where((x) => x.name.local == local);

  static Iterable<XmlElement> _kids(XmlElement e, String local) =>
      e.childElements.where((x) => x.name.local == local);

  static XmlElement? _kid(XmlElement? e, String local) =>
      e == null ? null : _kids(e, local).firstOrNull;

  /// `cx:lvl/cx:pt` idx sırasıyla (eksik = boş). Çok düzeyli boyutta ilk
  /// (yaprak) düzey.
  static List<String> _lvl(XmlElement dim) {
    final lvl = _kids(dim, 'lvl').firstOrNull;
    if (lvl == null) return const [];
    final map = <int, String>{};
    var maxIdx = -1;
    for (final pt in _kids(lvl, 'pt')) {
      final i = int.tryParse(pt.getAttribute('idx') ?? '') ?? 0;
      map[i] = pt.innerText;
      if (i > maxIdx) maxIdx = i;
    }
    final count = int.tryParse(lvl.getAttribute('ptCount') ?? '') ?? 0;
    final n = math.max(maxIdx + 1, count);
    return [for (var i = 0; i < n; i++) map[i] ?? ''];
  }

  static String? _seriesName(XmlElement ser) {
    final v = _all(ser, 'v').firstOrNull?.innerText.trim();
    return v == null || v.isEmpty ? null : v;
  }

  /// Başlık metni (`cx:title` → `a:t` ya da `cx:v`).
  static String title(XmlDocument doc) {
    final t = _all(doc.rootElement, 'title').firstOrNull;
    if (t == null) return '';
    final rich = _all(t, 't').map((e) => e.innerText).join().trim();
    if (rich.isNotEmpty) return rich;
    return _all(t, 'v').map((e) => e.innerText).join().trim();
  }
}

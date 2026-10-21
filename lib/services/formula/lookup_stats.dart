part of '../formula_engine.dart';

extension _ParserLookupStatsPart on _Parser {
  bool _matchCriteria(Object value, Object criteria) {
    if (criteria is num) {
      return value is num ? value == criteria : false;
    }
    final raw = FormulaEngine.toStr(criteria).trim();
    final m = RegExp(r'^(<=|>=|<>|<|>|=)?(.*)$').firstMatch(raw)!;
    final op = m.group(1) ?? '=';
    final operand = m.group(2)!.trim();
    final operandNum = double.tryParse(operand);
    if (operandNum != null) {
      if (value is! num) {
        final asNum = double.tryParse(FormulaEngine.toStr(value));
        if (asNum == null) return op == '<>';
        return _Parser._cmpNum(asNum, operandNum, op);
      }
      return _Parser._cmpNum(value.toDouble(), operandNum, op);
    }
    final text = FormulaEngine.toStr(value);
    if (op == '=' || op == '<>') {
      final hit = _Parser._wildcardMatch(text, operand);
      return op == '=' ? hit : !hit;
    }
    final cmp = _Parser._trLower(text).compareTo(_Parser._trLower(operand));
    return switch (op) {
      '<' => cmp < 0,
      '>' => cmp > 0,
      '<=' => cmp <= 0,
      '>=' => cmp >= 0,
      _ => false,
    };
  }

  List<Object> _rangeValues(Object a) {
    if (a is _RangeValue) {
      final out = <Object>[];
      for (var r = a.r1; r <= a.r2; r++) {
        for (var c = a.c1; c <= a.c2; c++) {
          out.add(eng.cellValue(r, c, visiting, a.sheet));
        }
      }
      return out;
    }
    return [a];
  }

  Object _sumIf(List<Object> args) {
    if (args.length < 2) return const FormulaError('#DEĞER!');
    final range = _rangeValues(args[0]);
    final sumRange = args.length > 2 ? _rangeValues(args[2]) : range;
    final criteria = _single(args[1]);
    var total = 0.0;
    for (var i = 0; i < range.length; i++) {
      if (!_matchCriteria(range[i], criteria)) continue;
      if (i >= sumRange.length) continue;
      final v = sumRange[i];
      if (v is num) total += v.toDouble();
      if (v is String) total += double.tryParse(v.trim()) ?? 0;
    }
    return total;
  }

  Object _countIf(List<Object> args) {
    if (args.length < 2) return const FormulaError('#DEĞER!');
    final range = _rangeValues(args[0]);
    final criteria = _single(args[1]);
    return range.where((v) => _matchCriteria(v, criteria)).length.toDouble();
  }

  Object _averageIf(List<Object> args) {
    if (args.length < 2) return const FormulaError('#DEĞER!');
    final range = _rangeValues(args[0]);
    final avgRange = args.length > 2 ? _rangeValues(args[2]) : range;
    final criteria = _single(args[1]);
    var total = 0.0;
    var count = 0;
    for (var i = 0; i < range.length; i++) {
      if (!_matchCriteria(range[i], criteria)) continue;
      if (i >= avgRange.length) continue;
      final v = avgRange[i];
      final d = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (d == null) continue;
      total += d;
      count++;
    }
    if (count == 0) return const FormulaError('#SAYI/0!');
    return total / count;
  }

  /// SUMIFS/COUNTIFS/AVERAGEIFS/MAXIFS/MINIFS ortak gövdesi.
  Object _multiIf(String name, List<Object> args) {
    final counting = name == 'COUNTIFS';
    final valueRange = counting ? null : _rangeValues(args.first);
    final start = counting ? 0 : 1;
    if (args.length < start + 2) return const FormulaError('#DEĞER!');

    List<Object>? first;
    final pairs = <(List<Object>, Object)>[];
    for (var i = start; i + 1 < args.length; i += 2) {
      final r = _rangeValues(args[i]);
      first ??= r;
      pairs.add((r, _single(args[i + 1])));
    }
    final length = first?.length ?? 0;
    final hits = <double>[];
    for (var i = 0; i < length; i++) {
      var ok = true;
      for (final (range, criteria) in pairs) {
        if (i >= range.length || !_matchCriteria(range[i], criteria)) {
          ok = false;
          break;
        }
      }
      if (!ok) continue;
      if (counting) {
        hits.add(1);
        continue;
      }
      if (valueRange != null && i < valueRange.length) {
        final v = valueRange[i];
        final d = v is num ? v.toDouble() : double.tryParse(v.toString());
        if (d != null) hits.add(d);
      }
    }
    switch (name) {
      case 'COUNTIFS':
        return hits.length.toDouble();
      case 'SUMIFS':
        return hits.fold<double>(0, (a, b) => a + b);
      case 'AVERAGEIFS':
        if (hits.isEmpty) return const FormulaError('#SAYI/0!');
        return hits.reduce((a, b) => a + b) / hits.length;
      case 'MAXIFS':
        return hits.isEmpty ? 0.0 : hits.reduce(math.max);
      default:
        return hits.isEmpty ? 0.0 : hits.reduce(math.min);
    }
  }

  Object _sumProduct(List<Object> args) {
    final lists = args.map(_rangeValues).toList();
    if (lists.isEmpty) return 0.0;
    final n = lists.map((l) => l.length).reduce(math.min);
    var total = 0.0;
    for (var i = 0; i < n; i++) {
      var product = 1.0;
      for (final list in lists) {
        final v = list[i];
        final d = v is num
            ? v.toDouble()
            : (v is bool ? (v ? 1.0 : 0.0) : double.tryParse(v.toString()) ?? 0);
        product *= d;
      }
      total += product;
    }
    return total;
  }

  Object _lookup(String name, List<Object> args) {
    if (args.length < 3 || args[1] is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final needle = _single(args[0]);
    final range = args[1] as _RangeValue;
    final index = _numArg(args, 2).round();
    final approx = args.length < 4 || FormulaEngine.toBool(_arg(args, 3));
    final vertical = name == 'VLOOKUP';
    final outer = vertical ? range.r2 - range.r1 : range.c2 - range.c1;

    int? bestExact;
    int? bestApprox;
    for (var i = 0; i <= outer; i++) {
      final r = vertical ? range.r1 + i : range.r1;
      final c = vertical ? range.c1 : range.c1 + i;
      final v = eng.cellValue(r, c, visiting, range.sheet);
      if (_compare('=', v, needle)) {
        bestExact = i;
        break;
      }
      if (approx) {
        try {
          if (_compare('<', v, needle)) bestApprox = i;
        } catch (_) {
          // karşılaştırılamayan değer atlanır
        }
      }
    }
    final hit = bestExact ?? (approx ? bestApprox : null);
    if (hit == null) return const FormulaError('#YOK');
    final rr = vertical ? range.r1 + hit : range.r1 + index - 1;
    final cc = vertical ? range.c1 + index - 1 : range.c1 + hit;
    if (rr > range.r2 || cc > range.c2 || index < 1) {
      return const FormulaError('#BAŞV!');
    }
    return eng.cellValue(rr, cc, visiting, range.sheet);
  }

  Object _index(List<Object> args) {
    if (args.isEmpty || args.first is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final range = args.first as _RangeValue;
    final rowArg = args.length > 1 ? _numArg(args, 1).round() : 1;
    final colArg = args.length > 2 ? _numArg(args, 2).round() : 1;
    // Tek satırlık aralıkta INDEX(range, n) sütunu seçer (Excel davranışı).
    final singleRow = range.r1 == range.r2;
    final r = singleRow ? range.r1 : range.r1 + rowArg - 1;
    final c = singleRow
        ? range.c1 + rowArg - 1
        : range.c1 + (args.length > 2 ? colArg - 1 : 0);
    if (r < range.r1 || r > range.r2 || c < range.c1 || c > range.c2) {
      return const FormulaError('#BAŞV!');
    }
    return eng.cellValue(r, c, visiting, range.sheet);
  }

  Object _matchFn(List<Object> args) {
    if (args.length < 2 || args[1] is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final needle = _single(args[0]);
    final range = args[1] as _RangeValue;
    final type = args.length > 2 ? _numArg(args, 2).round() : 1;
    final values = _rangeValues(range);
    if (type == 0) {
      for (var i = 0; i < values.length; i++) {
        if (values[i] is String && needle is String) {
          if (_Parser._wildcardMatch(values[i] as String, needle)) {
            return (i + 1).toDouble();
          }
        } else if (_compare('=', values[i], needle)) {
          return (i + 1).toDouble();
        }
      }
      return const FormulaError('#YOK');
    }
    int? best;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v is String && v.trim().isEmpty) continue;
      try {
        if (type > 0 && _compare('<=', v, needle)) best = i;
        if (type < 0 && _compare('>=', v, needle)) best = i;
      } catch (_) {
        continue;
      }
    }
    if (best == null) return const FormulaError('#YOK');
    return (best + 1).toDouble();
  }

  /// Argüman verilmiş mi? (`_parseArgs` atlanan argümanı boş dize yapar.)
  bool _given(List<Object> args, int i) =>
      i < args.length && !(args[i] is String && (args[i] as String).isEmpty);

  Object _offset(List<Object> args) {
    if (args.isEmpty || args.first is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final ref = args.first as _RangeValue;
    final dr = _numArg(args, 1).round();
    final dc = _numArg(args, 2).round();
    final h = _given(args, 3) ? _numArg(args, 3).round() : ref.r2 - ref.r1 + 1;
    final w = _given(args, 4) ? _numArg(args, 4).round() : ref.c2 - ref.c1 + 1;
    if (h <= 0 || w <= 0) return const FormulaError('#BAŞV!');
    final r1 = ref.r1 + dr;
    final c1 = ref.c1 + dc;
    if (r1 < 0 || c1 < 0) return const FormulaError('#BAŞV!');
    return _RangeValue(r1, c1, r1 + h - 1, c1 + w - 1, ref.sheet);
  }

  Object _indirect(List<Object> args) {
    var body = _strArg(args, 0).trim();
    if (body.isEmpty) return const FormulaError('#BAŞV!');
    String? sheet;
    final bang = body.lastIndexOf('!');
    if (bang > 0) {
      sheet = body.substring(0, bang).replaceAll("'", '');
      body = body.substring(bang + 1);
    }
    final parts = body.split(':');
    final a = _parseRef(parts.first.trim());
    if (a == null) return const FormulaError('#BAŞV!');
    if (parts.length == 1) {
      return _RangeValue(a.$1, a.$2, a.$1, a.$2, sheet);
    }
    final b = _parseRef(parts[1].trim());
    if (b == null) return const FormulaError('#BAŞV!');
    return _RangeValue(
      math.min(a.$1, b.$1),
      math.min(a.$2, b.$2),
      math.max(a.$1, b.$1),
      math.max(a.$2, b.$2),
      sheet,
    );
  }

  bool _compareSafe(String op, Object a, Object b) {
    try {
      return _compare(op, a, b);
    } catch (_) {
      return false;
    }
  }

  /// `ARA` (LOOKUP) — vektör ve dizi biçimi. Sıralı veride son "küçük eşit".
  Object _lookupVector(List<Object> args) {
    if (args.length < 2 || args[1] is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final needle = _single(args[0]);
    final v = args[1] as _RangeValue;
    final wide = (v.c2 - v.c1) >= (v.r2 - v.r1);
    final vector = v.r1 == v.r2 || v.c1 == v.c2;
    final n = wide ? v.c2 - v.c1 : v.r2 - v.r1;

    int? best;
    for (var i = 0; i <= n; i++) {
      final val = eng.cellValue(wide ? v.r1 : v.r1 + i,
          wide ? v.c1 + i : v.c1, visiting, v.sheet);
      if (val is String && val.trim().isEmpty) continue;
      if (_compareSafe('<=', val, needle)) best = i;
    }
    if (best == null) return const FormulaError('#YOK');

    if (_given(args, 2) && args[2] is _RangeValue) {
      final res = args[2] as _RangeValue;
      final rWide = (res.c2 - res.c1) >= (res.r2 - res.r1);
      final r = rWide ? res.r1 : res.r1 + best;
      final c = rWide ? res.c1 + best : res.c1;
      if (r > res.r2 || c > res.c2) return const FormulaError('#BAŞV!');
      return eng.cellValue(r, c, visiting, res.sheet);
    }
    // Dizi biçimi: son satır/sütundan döner.
    final r = vector ? (wide ? v.r1 : v.r1 + best) : (wide ? v.r2 : v.r1 + best);
    final c = vector ? (wide ? v.c1 + best : v.c1) : (wide ? v.c1 + best : v.c2);
    return eng.cellValue(r, c, visiting, v.sheet);
  }

  /// `ÇAPRAZARA` (XLOOKUP) — eşleşme kipleri: 0 tam, -1 sonraki küçük,
  /// 1 sonraki büyük, 2 joker.
  Object _xlookup(List<Object> args) {
    if (args.length < 3 || args[1] is! _RangeValue || args[2] is! _RangeValue) {
      return const FormulaError('#DEĞER!');
    }
    final needle = _single(args[0]);
    final lr = args[1] as _RangeValue;
    final rr = args[2] as _RangeValue;
    final mode = _given(args, 4) ? _numArg(args, 4).round() : 0;
    final wide = (lr.c2 - lr.c1) > (lr.r2 - lr.r1);
    final n = wide ? lr.c2 - lr.c1 : lr.r2 - lr.r1;

    int? hit;
    double? bestDelta;
    for (var i = 0; i <= n; i++) {
      final val = eng.cellValue(wide ? lr.r1 : lr.r1 + i,
          wide ? lr.c1 + i : lr.c1, visiting, lr.sheet);
      if (mode == 2) {
        if (_Parser._wildcardMatch(
            FormulaEngine.toStr(val), FormulaEngine.toStr(needle))) {
          hit = i;
          break;
        }
        continue;
      }
      if (_compareSafe('=', val, needle)) {
        hit = i;
        break;
      }
      if (mode == -1 || mode == 1) {
        final a = double.tryParse(FormulaEngine.toStr(val));
        final b = double.tryParse(FormulaEngine.toStr(needle));
        if (a == null || b == null) continue;
        final delta = mode == -1 ? b - a : a - b;
        if (delta > 0 && (bestDelta == null || delta < bestDelta)) {
          bestDelta = delta;
          hit = i;
        }
      }
    }
    if (hit == null) {
      return _given(args, 3) ? _arg(args, 3) : const FormulaError('#YOK');
    }
    final rWide = (rr.c2 - rr.c1) > (rr.r2 - rr.r1);
    final r = rWide ? rr.r1 : rr.r1 + hit;
    final c = rWide ? rr.c1 + hit : rr.c1;
    if (r > rr.r2 || c > rr.c2) return const FormulaError('#BAŞV!');
    return eng.cellValue(r, c, visiting, rr.sheet);
  }

  /// `*A` ailesi: metin 0, mantıksal 1/0 sayılır (boş hücre atlanır).
  List<double> _numbersA(List<Object> args) {
    final out = <double>[];
    for (final v in _flatten(args)) {
      if (v is FormulaError) throw v;
      if (v is num) {
        out.add(v.toDouble());
      } else if (v is bool) {
        out.add(v ? 1 : 0);
      } else if (v is String) {
        if (v.trim().isEmpty) continue;
        out.add(double.tryParse(v.trim()) ?? 0);
      }
    }
    return out;
  }
}

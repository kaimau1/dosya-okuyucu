part of '../formula_engine.dart';

/// `LAMBDA(x; y; gövde)` değeri — gövde METİN olarak saklanır ve her
/// çağrıda bağlanan parametrelerle yeniden değerlendirilir (motor
/// ayrıştırırken hesaplar; ertelenmiş değerlendirme başka türlü yok).
class _Lambda {
  final List<String> params;
  final String body;
  final Map<String, Object>? locals;
  final bool decimalComma;
  const _Lambda(this.params, this.body, this.locals, this.decimalComma);

  /// Hücreye düşen çağrılmamış LAMBDA Excel'de `#CALC!`.
  @override
  String toString() => '#HESAP!';
}

/// B10 m.2 (2026-11-19): dizi/metin işlevleri — TEXTSPLIT, VSTACK/HSTACK,
/// TAKE/DROP, CHOOSECOLS/CHOOSEROWS, XMATCH, LAMBDA/MAP/REDUCE/SCAN/BYROW/
/// BYCOL/MAKEARRAY, NETWORKDAYS.INTL/WORKDAY.INTL.
extension _ParserArraysPart on _Parser {
  static const _na = FormulaError('#YOK');
  static const _value = FormulaError('#DEĞER!');
  static const _calc = FormulaError('#HESAP!');

  Object? _callArrayFunc(String name, List<Object> args) {
    switch (name) {
      case 'VSTACK':
      case 'HSTACK':
        return _stack(args, vertical: name == 'VSTACK');
      case 'TAKE':
      case 'DROP':
        return _takeDrop(args, take: name == 'TAKE');
      case 'CHOOSECOLS':
      case 'CHOOSEROWS':
        return _chooseLines(args, cols: name == 'CHOOSECOLS');
      case 'TEXTSPLIT':
        return _textSplit(args);
      case 'XMATCH':
        return _xmatch(args);
      case 'MAP':
        return _mapFn(args);
      case 'REDUCE':
      case 'SCAN':
        return _reduceFn(args, scan: name == 'SCAN');
      case 'BYROW':
      case 'BYCOL':
        return _byLine(args, rows: name == 'BYROW');
      case 'MAKEARRAY':
        return _makeArray(args);
      case 'NETWORKDAYS.INTL':
        return _networkDaysIntl(args);
      case 'WORKDAY.INTL':
        return _workdayIntl(args);
    }
    return null;
  }

  // ── yardımcılar ───────────────────────────────────────────────────────

  static Object _result(List<List<Object>> rows) {
    if (rows.isEmpty || rows.first.isEmpty) return _calc;
    if (rows.length * rows.first.length > _ParserFunctionsPart._maxCells) {
      return const FormulaError('#SAYI!');
    }
    return FormulaArray(rows);
  }

  /// Argümandaki tamsayı listesi (dizi sabiti / aralık da olabilir).
  List<int> _intList(Object a) => [
        for (final row in _mat(a) ?? [
              [_single(a)],
            ])
          for (final v in row) FormulaEngine.toNum(v).truncate(),
      ];

  // ── VSTACK / HSTACK ───────────────────────────────────────────────────

  Object _stack(List<Object> args, {required bool vertical}) {
    if (args.isEmpty) return _value;
    final parts = [
      for (var i = 0; i < args.length; i++) _matArg(args, i),
    ];
    for (final p in parts) {
      if (p.isEmpty) return _value;
    }
    if (vertical) {
      final w = parts.map((p) => p.first.length).reduce(math.max);
      return _result([
        for (final p in parts)
          for (final row in p)
            [for (var c = 0; c < w; c++) c < row.length ? row[c] : _na],
      ]);
    }
    final h = parts.map((p) => p.length).reduce(math.max);
    return _result([
      for (var r = 0; r < h; r++)
        [
          for (final p in parts)
            for (var c = 0; c < p.first.length; c++)
              r < p.length ? p[r][c] : _na,
        ],
    ]);
  }

  // ── TAKE / DROP ───────────────────────────────────────────────────────

  Object _takeDrop(List<Object> args, {required bool take}) {
    if (args.length < 2) return _value;
    final m = _matArg(args, 0);
    if (m.isEmpty) return _value;
    final h = m.length, w = m.first.length;
    (int, int)? span(int i, int size) {
      if (!_given(args, i)) return (0, size);
      final n = _numArg(args, i).truncate();
      if (take) {
        if (n == 0) return null;
        final k = math.min(n.abs(), size);
        return n > 0 ? (0, k) : (size - k, size);
      }
      final k = math.min(n.abs(), size);
      return n >= 0 ? (k, size) : (0, size - k);
    }

    final rs = span(1, h), cs = span(2, w);
    if (rs == null || cs == null) return _calc;
    if (rs.$1 >= rs.$2 || cs.$1 >= cs.$2) return _calc;
    return _result([
      for (var r = rs.$1; r < rs.$2; r++) m[r].sublist(cs.$1, cs.$2),
    ]);
  }

  // ── CHOOSECOLS / CHOOSEROWS ───────────────────────────────────────────

  Object _chooseLines(List<Object> args, {required bool cols}) {
    if (args.length < 2) return _value;
    final m = _matArg(args, 0);
    if (m.isEmpty) return _value;
    final size = cols ? m.first.length : m.length;
    final picks = <int>[];
    for (final a in args.sublist(1)) {
      for (final n in _intList(a)) {
        if (n == 0 || n.abs() > size) return _value;
        picks.add(n > 0 ? n - 1 : size + n);
      }
    }
    if (cols) {
      return _result([
        for (final row in m) [for (final c in picks) row[c]],
      ]);
    }
    return _result([for (final r in picks) m[r]]);
  }

  // ── TEXTSPLIT ─────────────────────────────────────────────────────────

  Object _textSplit(List<Object> args) {
    if (args.length < 2) return _value;
    final text = _strArg(args, 0);
    List<String> delims(int i) {
      if (!_given(args, i)) return const [];
      return [
        for (final row in _matArg(args, i))
          for (final v in row)
            if (FormulaEngine.toStr(v).isNotEmpty) FormulaEngine.toStr(v),
      ];
    }

    final colD = delims(1), rowD = delims(2);
    if (colD.isEmpty && rowD.isEmpty) return _value;
    final ignoreEmpty =
        _given(args, 3) && FormulaEngine.toBool(_arg(args, 3));
    final caseless = _given(args, 4) && _numArg(args, 4) == 1;
    final Object pad = _given(args, 5) ? _arg(args, 5) : _na;

    RegExp? pattern(List<String> ds) {
      if (ds.isEmpty) return null;
      final sorted = [...ds]..sort((a, b) => b.length.compareTo(a.length));
      return RegExp(sorted.map(RegExp.escape).join('|'),
          caseSensitive: !caseless);
    }

    final rowRe = pattern(rowD), colRe = pattern(colD);
    var lines = rowRe == null ? [text] : text.split(rowRe);
    if (ignoreEmpty) lines = [for (final l in lines) if (l.isNotEmpty) l];
    final rows = <List<String>>[
      for (final l in lines)
        [
          for (final p in colRe == null ? [l] : l.split(colRe))
            if (!ignoreEmpty || p.isNotEmpty) p,
        ],
    ];
    rows.removeWhere((r) => r.isEmpty);
    if (rows.isEmpty) return _calc;
    final w = rows.map((r) => r.length).reduce(math.max);
    return _result([
      for (final r in rows)
        [for (var c = 0; c < w; c++) c < r.length ? r[c] : pad],
    ]);
  }

  // ── XMATCH ────────────────────────────────────────────────────────────

  Object _xmatch(List<Object> args) {
    if (args.length < 2) return _value;
    final needle = _single(args[0]);
    final m = _matArg(args, 1);
    if (m.isEmpty) return _value;
    if (m.length > 1 && m.first.length > 1) return _value;
    final values = [for (final row in m) ...row];
    final mode = _given(args, 2) ? _numArg(args, 2).round() : 0;
    final search = _given(args, 3) ? _numArg(args, 3).round() : 1;
    if (![0, -1, 1, 2].contains(mode) || ![1, -1, 2, -2].contains(search)) {
      return _value;
    }
    final order = search < 0
        ? [for (var i = values.length - 1; i >= 0; i--) i]
        : [for (var i = 0; i < values.length; i++) i];
    int? best;
    for (final i in order) {
      final v = values[i];
      if (v is FormulaError) continue;
      if (mode == 2) {
        if (_Parser._wildcardMatch(
            FormulaEngine.toStr(v), FormulaEngine.toStr(needle))) {
          return (i + 1).toDouble();
        }
        continue;
      }
      if (v is String && v.trim().isEmpty) continue;
      if (_compareSafe('=', v, needle)) return (i + 1).toDouble();
      if (mode == 0) continue;
      if (_Parser._rank(v) != _Parser._rank(needle) &&
          !(_Parser._asNumber(v) != null && _Parser._asNumber(needle) != null)) {
        continue;
      }
      final ok = mode == -1
          ? _compareSafe('<', v, needle)
          : _compareSafe('>', v, needle);
      if (!ok) continue;
      if (best == null ||
          (mode == -1
              ? _compareSafe('>', v, values[best])
              : _compareSafe('<', v, values[best]))) {
        best = i;
      }
    }
    return best == null ? _na : (best + 1).toDouble();
  }

  // ── LAMBDA ailesi ─────────────────────────────────────────────────────

  /// `LAMBDA(` sonrasında: parametreler ve gövde metni; hemen ardından
  /// `(…)` gelirse çağrılır (`=LAMBDA(x;x+1)(2)`).
  Object _parseLambda() {
    final params = <String>[];
    while (true) {
      _skip();
      final start = _i;
      while (_i < s.length &&
          (_Parser._isAlpha(s[_i]) ||
              _Parser._isDigit(s[_i]) ||
              s[_i] == '_' ||
              s[_i] == '.')) {
        _i++;
      }
      final name = s.substring(start, _i);
      _skip();
      final sep = _i < s.length && (s[_i] == ',' || s[_i] == ';');
      if (name.isNotEmpty && sep && _parseRef(name) == null &&
          !_Parser._isDigit(name[0])) {
        params.add(_Parser._canonical(name));
        _i++;
        continue;
      }
      _i = start;
      break;
    }
    final bodyStart = _i;
    var depth = 0;
    while (_i < s.length) {
      final ch = s[_i];
      if (ch == '"' || ch == "'") {
        _i = _FormulaLocalePart._quotedEnd(s, _i, ch);
        continue;
      }
      if (ch == '(' || ch == '[' || ch == '{') depth++;
      if (ch == ')' || ch == ']' || ch == '}') {
        if (depth == 0) break;
        depth--;
      }
      _i++;
    }
    final body = s.substring(bodyStart, _i).trim();
    if (body.isEmpty || !_match(')')) throw _value;
    if (params.toSet().length != params.length) throw _value;
    final fn = _Lambda(
        List.unmodifiable(params), body, _locals, _decimalComma);
    _skip();
    if (_i < s.length && s[_i] == '(') {
      _i++;
      final args = _parseArgs();
      if (!_match(')')) throw _value;
      return _invoke(fn, _Parser._isEmptyArgs(args) ? const [] : args);
    }
    return fn;
  }

  /// LAMBDA'yı verilen değerlerle değerlendirir (hata DEĞER olarak döner).
  Object _invoke(Object fn, List<Object> values) {
    if (fn is! _Lambda) return _value;
    if (values.length != fn.params.length) return _value;
    final p = _Parser(fn.body, eng, visiting,
        selfR: selfR, selfC: selfC, sheet: sheet,
        decimalComma: fn.decimalComma);
    p._locals = {
      ...?fn.locals,
      for (var i = 0; i < values.length; i++) fn.params[i]: values[i],
    };
    p._arrayDepth = 1;
    try {
      final v = p.parseExpr();
      p.expectEnd();
      return v;
    } on _CycleError {
      rethrow;
    } on FormulaError catch (e) {
      return e;
    }
  }

  /// Hücreye yazılacak tek değer (dizi dönen çağrı Excel'de `#HESAP!`).
  Object _cellOf(Object v) {
    if (v is _Lambda) return _calc;
    if (v is FormulaArray) {
      return v.height == 1 && v.width == 1 ? v.rows[0][0] : _calc;
    }
    if (v is _RangeValue) {
      return v.r1 == v.r2 && v.c1 == v.c2 ? _single(v) : _calc;
    }
    return v;
  }

  Object _mapFn(List<Object> args) {
    if (args.length < 2) return _value;
    final fn = args.last;
    final mats = [
      for (var i = 0; i < args.length - 1; i++) _matArg(args, i),
    ];
    for (final m in mats) {
      if (m.isEmpty) return _value;
    }
    final h = mats.map((m) => m.length).reduce(math.max);
    final w = mats.map((m) => m.first.length).reduce(math.max);
    if (h * w > _ParserFunctionsPart._maxCells) return const FormulaError('#SAYI!');
    Object at(List<List<Object>> m, int r, int c) {
      final rr = m.length == 1 ? 0 : r, cc = m.first.length == 1 ? 0 : c;
      if (rr >= m.length || cc >= m[rr].length) return _na;
      return m[rr][cc];
    }

    return _result([
      for (var r = 0; r < h; r++)
        [
          for (var c = 0; c < w; c++)
            _cellOf(_invoke(fn, [for (final m in mats) at(m, r, c)])),
        ],
    ]);
  }

  Object _reduceFn(List<Object> args, {required bool scan}) {
    if (args.length < 3) return _value;
    // Atlanan başlangıç boş değerdir: toplamda 0, birleştirmede "" gibi.
    var acc = _single(args[0]);
    final m = _matArg(args, 1);
    if (m.isEmpty) return _value;
    final fn = args[2];
    if (fn is! _Lambda || fn.params.length != 2) return _value;
    final trail = <List<Object>>[];
    for (final row in m) {
      final out = <Object>[];
      for (final v in row) {
        acc = _invoke(fn, [acc, v]);
        if (scan) out.add(_cellOf(acc));
      }
      if (scan) trail.add(out);
    }
    return scan ? _result(trail) : acc;
  }

  Object _byLine(List<Object> args, {required bool rows}) {
    if (args.length < 2) return _value;
    final m = _matArg(args, 0);
    if (m.isEmpty) return _value;
    final fn = args[1];
    if (fn is! _Lambda || fn.params.length != 1) return _value;
    if (rows) {
      return _result([
        for (final row in m)
          [
            _cellOf(_invoke(fn, [
              FormulaArray([row]),
            ])),
          ],
      ]);
    }
    return _result([
      [
        for (var c = 0; c < m.first.length; c++)
          _cellOf(_invoke(fn, [
            FormulaArray([
              for (final row in m) [row[c]],
            ]),
          ])),
      ],
    ]);
  }

  Object _makeArray(List<Object> args) {
    if (args.length < 3) return _value;
    final h = _numArg(args, 0).truncate(), w = _numArg(args, 1).truncate();
    if (h < 1 || w < 1) return _value;
    if (h * w > _ParserFunctionsPart._maxCells) return const FormulaError('#SAYI!');
    final fn = args[2];
    if (fn is! _Lambda || fn.params.length != 2) return _value;
    return _result([
      for (var r = 1; r <= h; r++)
        [
          for (var c = 1; c <= w; c++)
            _cellOf(_invoke(fn, [r.toDouble(), c.toDouble()])),
        ],
    ]);
  }

  // ── NETWORKDAYS.INTL / WORKDAY.INTL ───────────────────────────────────

  /// Hafta sonu günleri (DateTime.weekday: Pzt=1 … Paz=7). Kod: 1–7 iki gün
  /// (1 = Cmt+Paz), 11–17 tek gün (11 = Paz), ya da "0000011" (Pzt→Paz,
  /// 1 = tatil). Geçersizse hata.
  Object _weekendOf(List<Object> args, int i) {
    if (!_given(args, i)) return const {6, 7};
    final v = _arg(args, i);
    // "0010001" sayıya da çevrilir (10001) — dize kalıbı önce bakılır.
    final mask = v is String && RegExp(r'^[01]{7}$').hasMatch(v);
    if (v is String && (mask || _Parser._asNumber(v) == null)) {
      if (!mask || v == '1111111') return _value;
      return {
        for (var d = 0; d < 7; d++)
          if (v[d] == '1') d + 1,
      };
    }
    final k = FormulaEngine.toNum(v).truncate();
    if (k >= 1 && k <= 7) return {(k + 4) % 7 + 1, (k + 5) % 7 + 1};
    if (k >= 11 && k <= 17) return {(k - 5) % 7 + 1};
    return const FormulaError('#SAYI!');
  }

  Object _networkDaysIntl(List<Object> args) {
    if (args.length < 2) return _value;
    final weekend = _weekendOf(args, 2);
    if (weekend is FormulaError) return weekend;
    final off = weekend as Set<int>;
    final a = excelSerialToDate(_numArg(args, 0));
    final b = excelSerialToDate(_numArg(args, 1));
    final holidays = _holidaySet(args, 3);
    final forward = !b.isBefore(a);
    final from = forward ? a : b, to = forward ? b : a;
    var count = 0;
    for (var d = from; !d.isAfter(to); d = d.add(const Duration(days: 1))) {
      if (off.contains(d.weekday)) continue;
      if (holidays.contains(_Parser._dayKey(d))) continue;
      count++;
    }
    return (forward ? count : -count).toDouble();
  }

  Object _workdayIntl(List<Object> args) {
    if (args.length < 2) return _value;
    final weekend = _weekendOf(args, 2);
    if (weekend is FormulaError) return weekend;
    final off = weekend as Set<int>;
    var d = excelSerialToDate(_numArg(args, 0));
    var left = _numArg(args, 1).truncate();
    final holidays = _holidaySet(args, 3);
    final step = left >= 0 ? 1 : -1;
    left = left.abs();
    while (left > 0) {
      d = d.add(Duration(days: step));
      if (off.contains(d.weekday)) continue;
      if (holidays.contains(_Parser._dayKey(d))) continue;
      left--;
    }
    return dateToExcelSerial(d);
  }
}

import 'dart:math' as math;

/// Basit ama gerçek bir Excel formül motoru (saf Dart, cihaz-içi hesaplama).
///
/// Destekler: sayı/metin/mantık sabitleri, hücre referansı (A1, $A$1), aralık
/// (A1:B3), aritmetik (+ - * / ^ %), karşılaştırma (= <> < > <= >=), parantez ve
/// yaygın fonksiyonlar (SUM, AVERAGE, MIN, MAX, COUNT, COUNTA, IF, AND, OR, NOT,
/// ROUND, ABS, SQRT, POWER, MOD, INT, LEN, LEFT, RIGHT, MID, UPPER, LOWER, TRIM,
/// CONCAT/CONCATENATE). Döngüsel referans → #DÖNGÜ, diğer hatalar → #HATA.
///
/// Girdi: modelin ham hücre metinleri (formüller "=" ile başlar). Sonuç ekranda
/// gösterilecek metindir; orijinal formül düzenleme çubuğunda kalır.
class FormulaEngine {
  final List<List<String>> grid;
  FormulaEngine(this.grid);

  /// (r,c) hücresinin görüntülenecek değeri — formülse hesaplanır.
  String displayValue(int r, int c) {
    final raw = _rawAt(r, c);
    if (raw.length < 2 || !raw.startsWith('=')) return raw;
    try {
      final v = _eval(raw.substring(1), {_key(r, c)});
      return _fmt(v);
    } on _CycleError {
      return '#DÖNGÜ';
    } catch (_) {
      return '#HATA';
    }
  }

  /// Formül çubuğunda YAZILMAKTA olan bir formülün canlı önizleme sonucu
  /// (henüz hücreye uygulanmadan). [formula] `=` ile başlamalı; değilse boş
  /// döner. (selfR,selfC) kendine-referans döngüsünü engellemek için ziyaret
  /// kümesine konur. Izgaradaki diğer hücreler mevcut değerleriyle okunur.
  String preview(String formula, int selfR, int selfC) {
    if (formula.length < 2 || !formula.startsWith('=')) return '';
    try {
      return _fmt(_eval(formula.substring(1), {_key(selfR, selfC)}));
    } on _CycleError {
      return '#DÖNGÜ';
    } catch (_) {
      return '#HATA';
    }
  }

  // ── Değer çözümleme ───────────────────────────────────────────────────────

  String _rawAt(int r, int c) {
    if (r < 0 || r >= grid.length) return '';
    final row = grid[r];
    if (c < 0 || c >= row.length) return '';
    return row[c];
  }

  static String _key(int r, int c) => '$r:$c';

  /// Bir hücrenin değeri (referanslar için). Formülse ardışık hesaplanır.
  Object _cellValue(int r, int c, Set<String> visiting) {
    final raw = _rawAt(r, c);
    if (raw.isEmpty) return '';
    if (raw.startsWith('=') && raw.length >= 2) {
      final k = _key(r, c);
      if (visiting.contains(k)) throw const _CycleError();
      return _eval(raw.substring(1), {...visiting, k});
    }
    return raw; // ham metin; sayıya çevrim kullanım anında
  }

  // ── Ayrıştırıcı (recursive descent) ───────────────────────────────────────

  Object _eval(String src, Set<String> visiting) {
    final p = _Parser(src, this, visiting);
    final v = p.parseExpr();
    p.expectEnd();
    return v;
  }

  // ── Biçimleme ─────────────────────────────────────────────────────────────

  static String _fmt(Object v) {
    if (v is bool) return v ? 'DOĞRU' : 'YANLIŞ';
    if (v is num) {
      final d = v.toDouble();
      if (d.isNaN || d.isInfinite) return '#HATA';
      if (d == d.roundToDouble() && d.abs() < 1e15) {
        return d.toStringAsFixed(0);
      }
      // gereksiz uzun ondalıkları kısalt
      var s = d.toStringAsFixed(10);
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      return s;
    }
    return v.toString();
  }

  // ── Yardımcı: sayıya/aralığa çevirme (fonksiyonlar kullanır) ───────────────

  static double toNum(Object v) {
    if (v is num) return v.toDouble();
    if (v is bool) return v ? 1 : 0;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return 0;
      final d = double.tryParse(t);
      if (d == null) throw const _ValueError();
      return d;
    }
    throw const _ValueError();
  }

  static bool toBool(Object v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toUpperCase();
      if (t == 'DOĞRU' || t == 'TRUE' || t == 'DOGRU') return true;
      if (t == 'YANLIŞ' || t == 'FALSE' || t == 'YANLIS' || t.isEmpty) {
        return false;
      }
      return double.tryParse(t) != 0;
    }
    return false;
  }

  static String toStr(Object v) {
    if (v is bool) return v ? 'DOĞRU' : 'YANLIŞ';
    if (v is num) return _fmt(v);
    return v.toString();
  }
}

/// Aralık değeri (A1:B3) — fonksiyon argümanlarında listelenir.
class _RangeValue {
  final int r1, c1, r2, c2;
  const _RangeValue(this.r1, this.c1, this.r2, this.c2);
}

class _CycleError implements Exception {
  const _CycleError();
}

class _ValueError implements Exception {
  const _ValueError();
}

class _Parser {
  final String s;
  final FormulaEngine eng;
  final Set<String> visiting;
  int _i = 0;

  _Parser(this.s, this.eng, this.visiting);

  void expectEnd() {
    _skip();
    if (_i < s.length) throw const _ValueError();
  }

  void _skip() {
    while (_i < s.length && (s[_i] == ' ' || s[_i] == '\t')) {
      _i++;
    }
  }

  bool _match(String tok) {
    _skip();
    if (s.startsWith(tok, _i)) {
      _i += tok.length;
      return true;
    }
    return false;
  }

  String _peekOp2() {
    _skip();
    if (_i + 1 < s.length) {
      final two = s.substring(_i, _i + 2);
      if (two == '<>' || two == '<=' || two == '>=') return two;
    }
    return '';
  }

  Object parseExpr() => _parseCompare();

  Object _parseCompare() {
    var left = _parseAddSub();
    while (true) {
      _skip();
      final two = _peekOp2();
      String? op;
      if (two.isNotEmpty) {
        op = two;
        _i += 2;
      } else if (_i < s.length && (s[_i] == '<' || s[_i] == '>' || s[_i] == '=')) {
        op = s[_i];
        _i++;
      }
      if (op == null) break;
      final right = _parseAddSub();
      left = _compare(op, left, right);
    }
    return left;
  }

  bool _compare(String op, Object a, Object b) {
    // sayı ise sayısal, değilse metinsel karşılaştırma
    int cmp;
    if ((a is num || a is bool) && (b is num || b is bool)) {
      cmp = FormulaEngine.toNum(a).compareTo(FormulaEngine.toNum(b));
    } else {
      cmp = FormulaEngine.toStr(a)
          .toLowerCase()
          .compareTo(FormulaEngine.toStr(b).toLowerCase());
    }
    switch (op) {
      case '=':
        return cmp == 0;
      case '<>':
        return cmp != 0;
      case '<':
        return cmp < 0;
      case '>':
        return cmp > 0;
      case '<=':
        return cmp <= 0;
      case '>=':
        return cmp >= 0;
    }
    throw const _ValueError();
  }

  Object _parseAddSub() {
    var left = _parseMulDiv();
    while (true) {
      _skip();
      if (_i < s.length && (s[_i] == '+' || s[_i] == '-')) {
        final op = s[_i];
        _i++;
        final right = _parseMulDiv();
        final a = FormulaEngine.toNum(left), b = FormulaEngine.toNum(right);
        left = op == '+' ? a + b : a - b;
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseMulDiv() {
    var left = _parsePower();
    while (true) {
      _skip();
      if (_i < s.length && (s[_i] == '*' || s[_i] == '/')) {
        final op = s[_i];
        _i++;
        final right = _parsePower();
        final a = FormulaEngine.toNum(left), b = FormulaEngine.toNum(right);
        if (op == '/') {
          if (b == 0) throw const _ValueError();
          left = a / b;
        } else {
          left = a * b;
        }
      } else {
        break;
      }
    }
    return left;
  }

  Object _parsePower() {
    var left = _parseUnary();
    _skip();
    if (_i < s.length && s[_i] == '^') {
      _i++;
      final right = _parsePower(); // sağ ilişkisel
      return math.pow(FormulaEngine.toNum(left), FormulaEngine.toNum(right));
    }
    return left;
  }

  Object _parseUnary() {
    _skip();
    if (_i < s.length && (s[_i] == '-' || s[_i] == '+')) {
      final op = s[_i];
      _i++;
      final v = FormulaEngine.toNum(_parseUnary());
      return op == '-' ? -v : v;
    }
    return _parsePostfix();
  }

  Object _parsePostfix() {
    var v = _parsePrimary();
    _skip();
    if (_i < s.length && s[_i] == '%') {
      _i++;
      v = FormulaEngine.toNum(v) / 100.0;
    }
    return v;
  }

  Object _parsePrimary() {
    _skip();
    if (_i >= s.length) throw const _ValueError();
    final ch = s[_i];

    if (ch == '(') {
      _i++;
      final v = parseExpr();
      if (!_match(')')) throw const _ValueError();
      return v;
    }
    if (ch == '"') {
      return _parseString();
    }
    if (_isDigit(ch) || ch == '.') {
      return _parseNumber();
    }
    if (_isAlpha(ch) || ch == r'$') {
      return _parseIdent();
    }
    throw const _ValueError();
  }

  String _parseString() {
    _i++; // açılış "
    final sb = StringBuffer();
    while (_i < s.length) {
      final c = s[_i];
      if (c == '"') {
        // "" → tek " (Excel kaçışı)
        if (_i + 1 < s.length && s[_i + 1] == '"') {
          sb.write('"');
          _i += 2;
          continue;
        }
        _i++;
        return sb.toString();
      }
      sb.write(c);
      _i++;
    }
    throw const _ValueError(); // kapanmayan dize
  }

  Object _parseNumber() {
    final start = _i;
    while (_i < s.length && (_isDigit(s[_i]) || s[_i] == '.')) {
      _i++;
    }
    // bilimsel gösterim (1e5)
    if (_i < s.length && (s[_i] == 'e' || s[_i] == 'E')) {
      _i++;
      if (_i < s.length && (s[_i] == '+' || s[_i] == '-')) _i++;
      while (_i < s.length && _isDigit(s[_i])) {
        _i++;
      }
    }
    final d = double.tryParse(s.substring(start, _i));
    if (d == null) throw const _ValueError();
    return d;
  }

  /// Fonksiyon çağrısı, hücre referansı/aralığı veya TRUE/FALSE.
  Object _parseIdent() {
    final start = _i;
    while (_i < s.length &&
        (_isAlpha(s[_i]) || _isDigit(s[_i]) || s[_i] == r'$' || s[_i] == '_')) {
      _i++;
    }
    final word = s.substring(start, _i);
    _skip();

    // Fonksiyon?
    if (_i < s.length && s[_i] == '(') {
      _i++;
      final args = _parseArgs();
      if (!_match(')')) throw const _ValueError();
      return _callFunc(word.toUpperCase(), args);
    }

    // Sabitler
    final up = word.toUpperCase();
    if (up == 'TRUE' || up == 'DOĞRU' || up == 'DOGRU') return true;
    if (up == 'FALSE' || up == 'YANLIŞ' || up == 'YANLIS') return false;

    // Hücre referansı veya aralık
    final ref = _parseRef(word);
    if (ref == null) throw const _ValueError();
    _skip();
    if (_i < s.length && s[_i] == ':') {
      _i++;
      _skip();
      final start2 = _i;
      while (_i < s.length &&
          (_isAlpha(s[_i]) || _isDigit(s[_i]) || s[_i] == r'$')) {
        _i++;
      }
      final ref2 = _parseRef(s.substring(start2, _i));
      if (ref2 == null) throw const _ValueError();
      return _RangeValue(
        math.min(ref.$1, ref2.$1),
        math.min(ref.$2, ref2.$2),
        math.max(ref.$1, ref2.$1),
        math.max(ref.$2, ref2.$2),
      );
    }
    return eng._cellValue(ref.$1, ref.$2, visiting);
  }

  /// "A1"/"$A$1" → (satır, sütun) 0 tabanlı; değilse null.
  (int, int)? _parseRef(String w) {
    final m = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(w);
    if (m == null) return null;
    var col = 0;
    for (final u in m.group(1)!.toUpperCase().codeUnits) {
      col = col * 26 + (u - 64);
    }
    return (int.parse(m.group(2)!) - 1, col - 1);
  }

  List<Object> _parseArgs() {
    final args = <Object>[];
    _skip();
    if (_i < s.length && s[_i] == ')') return args; // argümansız
    while (true) {
      args.add(parseExpr());
      _skip();
      if (_i < s.length && s[_i] == ',') {
        _i++;
        continue;
      }
      break;
    }
    return args;
  }

  // ── Fonksiyonlar ──────────────────────────────────────────────────────────

  List<Object> _flatten(List<Object> args) {
    final out = <Object>[];
    for (final a in args) {
      if (a is _RangeValue) {
        for (var r = a.r1; r <= a.r2; r++) {
          for (var c = a.c1; c <= a.c2; c++) {
            out.add(eng._cellValue(r, c, visiting));
          }
        }
      } else {
        out.add(a);
      }
    }
    return out;
  }

  List<double> _numbers(List<Object> args) {
    final out = <double>[];
    for (final v in _flatten(args)) {
      if (v is num) {
        out.add(v.toDouble());
      } else if (v is bool) {
        out.add(v ? 1 : 0);
      } else if (v is String) {
        final t = v.trim();
        if (t.isEmpty) continue; // boş/metin atlanır (Excel gibi)
        final d = double.tryParse(t);
        if (d != null) out.add(d);
      }
    }
    return out;
  }

  Object _callFunc(String name, List<Object> args) {
    switch (name) {
      case 'SUM':
        return _numbers(args).fold<double>(0, (a, b) => a + b);
      case 'AVERAGE':
        final n = _numbers(args);
        if (n.isEmpty) throw const _ValueError();
        return n.reduce((a, b) => a + b) / n.length;
      case 'MIN':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce(math.min);
      case 'MAX':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce(math.max);
      case 'COUNT':
        return _numbers(args).length.toDouble();
      case 'COUNTA':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .length
            .toDouble();
      case 'PRODUCT':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce((a, b) => a * b);
      case 'IF':
        if (args.length < 2) throw const _ValueError();
        final cond = FormulaEngine.toBool(_single(args[0]));
        if (cond) return _single(args[1]);
        return args.length >= 3 ? _single(args[2]) : false;
      case 'AND':
        return _flatten(args).every(FormulaEngine.toBool);
      case 'OR':
        return _flatten(args).any(FormulaEngine.toBool);
      case 'NOT':
        return !FormulaEngine.toBool(_single(args[0]));
      case 'ROUND':
        final v = FormulaEngine.toNum(_single(args[0]));
        final d = args.length >= 2 ? FormulaEngine.toNum(_single(args[1])) : 0;
        final f = math.pow(10, d.round());
        return (v * f).roundToDouble() / f;
      case 'ABS':
        return FormulaEngine.toNum(_single(args[0])).abs();
      case 'SQRT':
        return math.sqrt(FormulaEngine.toNum(_single(args[0])));
      case 'POWER':
        return math.pow(FormulaEngine.toNum(_single(args[0])),
            FormulaEngine.toNum(_single(args[1])));
      case 'MOD':
        final a = FormulaEngine.toNum(_single(args[0]));
        final b = FormulaEngine.toNum(_single(args[1]));
        if (b == 0) throw const _ValueError();
        return a % b;
      case 'INT':
        return FormulaEngine.toNum(_single(args[0])).floorToDouble();
      case 'LEN':
        return FormulaEngine.toStr(_single(args[0])).length.toDouble();
      case 'UPPER':
        return FormulaEngine.toStr(_single(args[0])).toUpperCase();
      case 'LOWER':
        return FormulaEngine.toStr(_single(args[0])).toLowerCase();
      case 'TRIM':
        return FormulaEngine.toStr(_single(args[0])).trim();
      case 'LEFT':
        final t = FormulaEngine.toStr(_single(args[0]));
        final n = args.length >= 2
            ? FormulaEngine.toNum(_single(args[1])).round()
            : 1;
        return t.substring(0, n.clamp(0, t.length));
      case 'RIGHT':
        final t = FormulaEngine.toStr(_single(args[0]));
        final n = args.length >= 2
            ? FormulaEngine.toNum(_single(args[1])).round()
            : 1;
        return t.substring((t.length - n).clamp(0, t.length));
      case 'MID':
        final t = FormulaEngine.toStr(_single(args[0]));
        final start = FormulaEngine.toNum(_single(args[1])).round() - 1;
        final len = FormulaEngine.toNum(_single(args[2])).round();
        if (start < 0 || start >= t.length) return '';
        return t.substring(start, (start + len).clamp(0, t.length));
      case 'CONCAT':
      case 'CONCATENATE':
        return _flatten(args).map(FormulaEngine.toStr).join();
      default:
        throw const _ValueError(); // bilinmeyen fonksiyon
    }
  }

  /// Argümanı tek değere indirger (aralıksa ilk hücre).
  Object _single(Object a) {
    if (a is _RangeValue) {
      return eng._cellValue(a.r1, a.c1, visiting);
    }
    return a;
  }

  static bool _isDigit(String c) => c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;
  static bool _isAlpha(String c) {
    final u = c.codeUnitAt(0);
    return (u >= 65 && u <= 90) || (u >= 97 && u <= 122);
  }
}

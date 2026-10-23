part of '../formula_engine.dart';

extension _ParserParserPart on _Parser {
  bool _match(String tok) {
    _skip();
    if (s.startsWith(tok, _i)) {
      _i += tok.length;
      return true;
    }
    return false;
  }

  Object parseExpr() => _parseCompare();

  Object _parseCompare() {
    var left = _parseConcat();
    while (true) {
      _skip();
      String? op;
      if (_i + 1 < s.length) {
        final two = s.substring(_i, _i + 2);
        if (two == '<>' || two == '<=' || two == '>=') {
          op = two;
          _i += 2;
        }
      }
      if (op == null &&
          _i < s.length &&
          (s[_i] == '<' || s[_i] == '>' || s[_i] == '=')) {
        op = s[_i];
        _i++;
      }
      if (op == null) break;
      final right = _parseConcat();
      if (left is FormulaError) return left;
      if (right is FormulaError) return right;
      left = _compare(op, _single(left), _single(right));
    }
    return left;
  }

  bool _compare(String op, Object a, Object b) {
    int cmp;
    if ((a is num || a is bool) && (b is num || b is bool)) {
      cmp = FormulaEngine.toNum(a).compareTo(FormulaEngine.toNum(b));
    } else if (_Parser._asNumber(a) != null && _Parser._asNumber(b) != null) {
      // Hücre değerleri modelde HAM METİN tutulur ('1234.5'), bu yüzden
      // sayı taşıyan metinle sayı SAYISAL karşılaştırılır — yoksa
      // `DÜŞEYARA(20; A:B; 2; 0)` gibi sayı aramaları hiç eşleşmiyordu.
      cmp = _Parser._asNumber(a)!.compareTo(_Parser._asNumber(b)!);
    } else if (a is String && b is String) {
      // Excel metin karşılaştırması büyük/küçük harf duyarsızdır.
      cmp = a.toLowerCase().compareTo(b.toLowerCase());
    } else {
      // Excel sıralaması: sayı < metin < mantıksal
      cmp = _Parser._rank(a).compareTo(_Parser._rank(b));
      if (cmp == 0) {
        cmp = FormulaEngine.toStr(a)
            .toLowerCase()
            .compareTo(FormulaEngine.toStr(b).toLowerCase());
      }
    }
    return switch (op) {
      '=' => cmp == 0,
      '<>' => cmp != 0,
      '<' => cmp < 0,
      '>' => cmp > 0,
      '<=' => cmp <= 0,
      '>=' => cmp >= 0,
      _ => throw const FormulaError('#DEĞER!'),
    };
  }

  /// `&` metin birleştirme — Excel'de karşılaştırmadan sonra, +/-'ten önce.
  Object _parseConcat() {
    var left = _parseAddSub();
    while (true) {
      _skip();
      if (_i < s.length && s[_i] == '&') {
        _i++;
        final right = _parseAddSub();
        if (left is FormulaError) return left;
        if (right is FormulaError) return right;
        left = FormulaEngine.toStr(_single(left)) +
            FormulaEngine.toStr(_single(right));
      } else {
        break;
      }
    }
    return left;
  }

  Object _parseAddSub() {
    var left = _parseMulDiv();
    while (true) {
      _skip();
      if (_i < s.length && (s[_i] == '+' || s[_i] == '-')) {
        final op = s[_i];
        _i++;
        final right = _parseMulDiv();
        if (left is FormulaError) return left;
        if (right is FormulaError) return right;
        final a = FormulaEngine.toNum(_single(left));
        final b = FormulaEngine.toNum(_single(right));
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
        if (left is FormulaError) return left;
        if (right is FormulaError) return right;
        final a = FormulaEngine.toNum(_single(left));
        final b = FormulaEngine.toNum(_single(right));
        if (op == '/') {
          if (b == 0) return const FormulaError('#SAYI/0!');
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
      if (left is FormulaError) return left;
      if (right is FormulaError) return right;
      return math.pow(FormulaEngine.toNum(_single(left)),
          FormulaEngine.toNum(_single(right)));
    }
    return left;
  }

  Object _parseUnary() {
    _skip();
    if (_i < s.length && (s[_i] == '-' || s[_i] == '+')) {
      final op = s[_i];
      _i++;
      final inner = _parseUnary();
      if (inner is FormulaError) return inner;
      final v = FormulaEngine.toNum(_single(inner));
      return op == '-' ? -v : v;
    }
    return _parsePostfix();
  }

  Object _parsePostfix() {
    var v = _parsePrimary();
    _skip();
    while (_i < s.length && s[_i] == '%') {
      _i++;
      if (v is FormulaError) return v;
      v = FormulaEngine.toNum(_single(v)) / 100.0;
      _skip();
    }
    return v;
  }

  Object _parsePrimary() {
    _skip();
    if (_i >= s.length) throw const FormulaError('#DEĞER!');
    final ch = s[_i];

    if (ch == '(') {
      _i++;
      final v = parseExpr();
      if (!_match(')')) throw const FormulaError('#DEĞER!');
      return v;
    }
    if (ch == '"') return _parseString();
    if (ch == '{') return _parseArrayLiteral();
    if (ch == "'") return _parseQuotedSheetRef();
    if (ch == '#') return _parseErrorLiteral();
    if (_Parser._isDigit(ch) || ch == '.') return _parseNumber();
    if (_Parser._isAlpha(ch) || ch == r'$' || ch == '_') return _parseIdent();
    throw const FormulaError('#DEĞER!');
  }

  Object _parseErrorLiteral() {
    // Bilinen kodlardan en uzun ön ek (kodlar `/`, `?`, `!` içerir; işleçte
    // durmak için ayırıcı aramak `#REF!*2`'yi bozuyordu).
    const tr = {
      '#REF!': '#BAŞV!',
      '#DIV/0!': '#SAYI/0!',
      '#VALUE!': '#DEĞER!',
      '#NAME?': '#AD?',
      '#N/A': '#YOK',
      '#NUM!': '#SAYI!',
      '#NULL!': '#BOŞ!',
    };
    const codes = [
      '#SAYI/0!', '#DEĞER!', '#BAŞV!', '#AD?', '#YOK', '#SAYI!', '#BOŞ!',
      '#DIV/0!', '#VALUE!', '#REF!', '#NAME?', '#N/A', '#NUM!', '#NULL!',
    ];
    String? best;
    for (final c in codes) {
      if (s.length - _i >= c.length &&
          s.substring(_i, _i + c.length).toUpperCase() == c.toUpperCase() &&
          (best == null || c.length > best.length)) {
        best = c;
      }
    }
    if (best == null) throw const FormulaError('#AD?');
    _i += best.length;
    // Dosya biçimi (İngilizce): satır silinince formüle `#REF!` yazılır
    // (Faz 25 / X3) — ekranda Türkçe karşılığı.
    return FormulaError(tr[best] ?? best);
  }

  String _parseString() {
    _i++; // açılış "
    final sb = StringBuffer();
    while (_i < s.length) {
      final c = s[_i];
      if (c == '"') {
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
    throw const FormulaError('#DEĞER!'); // kapanmayan dize
  }

  /// `{1;2;3}` dizi sabiti — ilk değeri kullanılır (dizi formülü desteklenmez).
  Object _parseArrayLiteral() {
    _i++;
    final values = <Object>[];
    while (_i < s.length && s[_i] != '}') {
      values.add(parseExpr());
      _skip();
      if (_i < s.length && (s[_i] == ',' || s[_i] == ';' || s[_i] == '\\')) {
        _i++;
      }
      _skip();
    }
    if (_i < s.length) _i++; // kapanış }
    return values.isEmpty ? '' : _single(values.first);
  }

  /// `'Sayfa Adı'!A1` biçimindeki referans.
  Object _parseQuotedSheetRef() {
    _i++; // '
    final sb = StringBuffer();
    while (_i < s.length && s[_i] != "'") {
      sb.write(s[_i]);
      _i++;
    }
    if (_i < s.length) _i++; // kapanış '
    if (_i >= s.length || s[_i] != '!') throw const FormulaError('#AD?');
    _i++;
    return _parseRefOrRange(sheet: sb.toString());
  }

  Object _parseNumber() {
    final start = _i;
    while (_i < s.length && (_Parser._isDigit(s[_i]) || s[_i] == '.')) {
      _i++;
    }
    var text = s.substring(start, _i);
    if (_decimalComma &&
        !text.contains('.') &&
        _i + 1 < s.length &&
        s[_i] == ',' &&
        _Parser._isDigit(s[_i + 1])) {
      _i++;
      final fracStart = _i;
      while (_i < s.length && _Parser._isDigit(s[_i])) {
        _i++;
      }
      text = '$text.${s.substring(fracStart, _i)}';
    }
    final mantissaEnd = _i;
    if (_i < s.length && (s[_i] == 'e' || s[_i] == 'E')) {
      final save = _i;
      _i++;
      if (_i < s.length && (s[_i] == '+' || s[_i] == '-')) _i++;
      if (_i < s.length && _Parser._isDigit(s[_i])) {
        while (_i < s.length && _Parser._isDigit(s[_i])) {
          _i++;
        }
      } else {
        _i = save;
      }
    }
    final d = double.tryParse(text + s.substring(mantissaEnd, _i));
    if (d == null) throw const FormulaError('#DEĞER!');
    return d;
  }

  /// Fonksiyon çağrısı, hücre referansı/aralığı, sayfa referansı ya da sabit.
  Object _parseIdent() {
    final start = _i;
    while (_i < s.length &&
        (_Parser._isAlpha(s[_i]) ||
            _Parser._isDigit(s[_i]) ||
            s[_i] == r'$' ||
            s[_i] == '_' ||
            s[_i] == '.')) {
      _i++;
    }
    final word = s.substring(start, _i);

    // Fonksiyon? (boşluk bırakılmaz — Excel de bırakılmasına izin vermez)
    if (_i < s.length && s[_i] == '(') {
      _i++;
      final args = _parseArgs();
      if (!_match(')')) throw const FormulaError('#DEĞER!');
      return _callFunc(_Parser._canonical(word), args);
    }

    // Sayfa referansı: Sayfa1!A1
    if (_i < s.length && s[_i] == '!') {
      _i++;
      return _parseRefOrRange(sheet: word);
    }

    final up = _Parser._canonical(word);
    if (up == 'TRUE' || up == 'DOĞRU') return true;
    if (up == 'FALSE' || up == 'YANLIŞ') return false;

    _i = start;
    return _parseRefOrRange();
  }

  /// Konumdaki `A1` ya da `A1:B9` referansını okur.
  Object _parseRefOrRange({String? sheet}) {
    _skip();
    final start = _i;
    while (_i < s.length &&
        (_Parser._isAlpha(s[_i]) || _Parser._isDigit(s[_i]) || s[_i] == r'$')) {
      _i++;
    }
    final first = _parseRef(s.substring(start, _i));
    if (first == null) throw const FormulaError('#AD?');
    if (_i < s.length && s[_i] == ':') {
      _i++;
      final start2 = _i;
      while (_i < s.length &&
          (_Parser._isAlpha(s[_i]) || _Parser._isDigit(s[_i]) || s[_i] == r'$')) {
        _i++;
      }
      final second = _parseRef(s.substring(start2, _i));
      if (second == null) throw const FormulaError('#AD?');
      return eng._noted(_RangeValue(
        math.min(first.$1, second.$1),
        math.min(first.$2, second.$2),
        math.max(first.$1, second.$1),
        math.max(first.$2, second.$2),
        sheet ?? this.sheet,
      ));
    }
    // Tek hücre de REFERANS olarak taşınır; değere ihtiyaç duyan her yol
    // `_single` üzerinden geçiyor (bkz. FormulaEngine._eval).
    return eng._noted(
        _RangeValue(first.$1, first.$2, first.$1, first.$2, sheet ?? this.sheet));
  }

  /// "A1"/"$A$1" → (satır, sütun) 0 tabanlı; değilse null.
  (int, int)? _parseRef(String w) {
    final m = RegExp(r'^\$?([A-Za-z]+)\$?(\d+)$').firstMatch(w);
    if (m == null) return null;
    var col = 0;
    for (final u in m.group(1)!.toUpperCase().codeUnits) {
      if (u < 65 || u > 90) return null;
      col = col * 26 + (u - 64);
    }
    final row = int.tryParse(m.group(2)!);
    if (row == null || row < 1) return null;
    return (row - 1, col - 1);
  }

  /// Argümanlar `,` ya da `;` ile ayrılır (Türkçe Excel `;` kullanır).
  List<Object> _parseArgs() {
    final args = <Object>[];
    _skip();
    if (_i < s.length && s[_i] == ')') return args;
    while (true) {
      _skip();
      // Boş argüman: `IF(A1;;0)`
      if (_i < s.length && (s[_i] == ',' || s[_i] == ';')) {
        args.add('');
        _i++;
        continue;
      }
      if (_i < s.length && s[_i] == ')') {
        args.add('');
        break;
      }
      args.add(_safeParse());
      _skip();
      if (_i < s.length && (s[_i] == ',' || s[_i] == ';')) {
        _i++;
        continue;
      }
      break;
    }
    return args;
  }

  /// Argüman değerlendirmesinde oluşan Excel hatası, İSTİSNA değil DEĞER
  /// olarak döner — `EĞERHATA(1/0;0)` ancak böyle çalışabilir. Döngü hatası
  /// istisna olarak geçer (tüm formülü çöpe atmalı).
  Object _safeParse() {
    final save = _i;
    try {
      return parseExpr();
    } on _CycleError {
      rethrow;
    } on FormulaError catch (e) {
      if (_i == save) rethrow; // hiç ilerlemediyse ayrıştırma hatasıdır
      return e;
    }
  }

  List<Object> _flatten(List<Object> args) {
    final out = <Object>[];
    for (final a in args) {
      if (a is _RangeValue) {
        for (var r = a.r1; r <= a.r2; r++) {
          for (var c = a.c1; c <= a.c2; c++) {
            out.add(eng.cellValue(r, c, visiting, a.sheet));
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
      if (v is FormulaError) throw v;
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

  Object _single(Object a) {
    if (a is _RangeValue) {
      if (a.r1 == a.r2 && a.c1 == a.c2) {
        return eng.cellValue(a.r1, a.c1, visiting, a.sheet);
      }
      return eng.cellValue(a.r1, a.c1, visiting, a.sheet);
    }
    return a;
  }

  Object _arg(List<Object> args, int i) =>
      i < args.length ? _single(args[i]) : '';

  double _numArg(List<Object> args, int i, [double fallback = 0]) =>
      i < args.length ? FormulaEngine.toNum(_arg(args, i)) : fallback;

  String _strArg(List<Object> args, int i) =>
      FormulaEngine.toStr(_arg(args, i));
}

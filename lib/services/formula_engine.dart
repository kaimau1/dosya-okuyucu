import 'dart:math' as math;

import '../core/excel_format.dart';

/// Cihaz-içi Excel formül motoru (saf Dart).
///
/// Excel'in davranışını hedefler: operatör öncelikleri, `&` metin birleştirme,
/// mutlak/göreli referans, aralık, **çapraz sayfa referansı** (`Sayfa2!A1`),
/// Türkçe Excel'in `;` argüman ayıracı ve Türkçe fonksiyon adları
/// (`TOPLA`, `EĞER`, `DÜŞEYARA` …), gerçek Excel **hata değerleri**
/// (`#SAYI/0!`, `#DEĞER!`, `#AD?`, `#YOK`, `#BAŞV!`) ve bunları yakalayan
/// `EĞERHATA/IFERROR`.
///
/// Girdi: modelin ham hücre metinleri (formüller `=` ile başlar, sayılar
/// `1234.5` gibi ham). Sonuç ekranda gösterilecek ham metindir; hücrenin sayı
/// biçimi (para/yüzde/tarih) bunun ÜSTÜNE gösterim katmanında uygulanır.
class FormulaEngine {
  /// Formül otomatik tamamlamanın önerdiği işlev adları — çözümleyicinin
  /// KENDİ takma ad tablosundan (Türkçe adlar + İngilizce karşılıkları).
  /// Ayrı bir liste tutmak, motor yeni bir işlev öğrendiğinde onu eskitirdi.
  static List<String> get functionNames => _Parser.functionNames;

  /// [prefix] ile başlayan (yoksa içinde geçen) işlev adları.
  static List<String> completionsFor(String prefix, {int limit = 8}) =>
      _Parser.completionsFor(prefix, limit: limit);

  final List<List<String>> grid;

  /// Çapraz sayfa referansları için tüm sayfalar (ad → ızgara). Verilmezse
  /// yalnız etkin sayfa görünür.
  final Map<String, List<List<String>>>? sheets;

  /// Bu motorun temsil ettiği sayfanın adı (kendi sayfasına referansta
  /// döngü tespiti doğru çalışsın diye).
  final String sheetName;

  /// Hesaplanmış hücre önbelleği — aynı hücreye onlarca formül bakabilir.
  final Map<String, Object> _cache = {};

  FormulaEngine(this.grid, {this.sheets, this.sheetName = ''});

  /// (r,c) hücresinin görüntülenecek değeri — formülse hesaplanır.
  String displayValue(int r, int c) {
    final raw = _rawAt(grid, r, c);
    if (raw.length < 2 || !raw.startsWith('=')) return raw;
    return fmt(_evalGuarded(raw.substring(1), {_key(sheetName, r, c)},
        selfR: r, selfC: c));
  }

  /// Formül çubuğunda YAZILMAKTA olan formülün canlı önizlemesi.
  String preview(String formula, int selfR, int selfC) {
    if (formula.length < 2 || !formula.startsWith('=')) return '';
    return fmt(_evalGuarded(
        formula.substring(1), {_key(sheetName, selfR, selfC)},
        selfR: selfR, selfC: selfC));
  }

  /// Bir hücrenin HAM metni (formül dahil) — `EFORMÜLSE`/`FORMÜLMETNİ` için.
  String rawTextOf(int r, int c, [String? sheet]) {
    final g = _gridFor(sheet);
    if (g == null) return '';
    return _rawAt(g, r, c);
  }

  Object _evalGuarded(String src, Set<String> visiting,
      {int selfR = 0, int selfC = 0}) {
    try {
      return _eval(src, visiting, selfR: selfR, selfC: selfC);
    } on _CycleError {
      return const FormulaError('#DÖNGÜ');
    } on FormulaError catch (e) {
      return e;
    } catch (_) {
      return const FormulaError('#DEĞER!');
    }
  }

  // ── değer çözümleme ───────────────────────────────────────────────────────

  static String _rawAt(List<List<String>> g, int r, int c) {
    if (r < 0 || r >= g.length) return '';
    final row = g[r];
    if (c < 0 || c >= row.length) return '';
    return row[c];
  }

  static String _key(String sheet, int r, int c) => '$sheet!$r:$c';

  List<List<String>>? _gridFor(String? sheet) {
    if (sheet == null || sheet.isEmpty || sheet == sheetName) return grid;
    final all = sheets;
    if (all == null) return null;
    if (all.containsKey(sheet)) return all[sheet];
    // Sayfa adı büyük/küçük harf duyarsız aranır (Excel de öyle).
    for (final entry in all.entries) {
      if (entry.key.toLowerCase() == sheet.toLowerCase()) return entry.value;
    }
    return null;
  }

  /// Bir hücrenin değeri (referanslar için). Formülse ardışık hesaplanır.
  Object cellValue(int r, int c, Set<String> visiting, [String? sheet]) {
    final g = _gridFor(sheet);
    if (g == null) return const FormulaError('#BAŞV!');
    final name = (sheet == null || sheet.isEmpty) ? sheetName : sheet;
    final raw = _rawAt(g, r, c);
    if (raw.isEmpty) return '';
    if (raw.startsWith('#') && _isErrorCode(raw)) return FormulaError(raw);
    if (!raw.startsWith('=') || raw.length < 2) return raw;

    final k = _key(name, r, c);
    if (visiting.contains(k)) throw const _CycleError();
    final cached = _cache[k];
    if (cached != null) return cached;
    Object value;
    try {
      value = _eval(raw.substring(1), {...visiting, k}, selfR: r, selfC: c);
    } on _CycleError {
      rethrow;
    } on FormulaError catch (e) {
      value = e;
    } catch (_) {
      value = const FormulaError('#DEĞER!');
    }
    _cache[k] = value;
    return value;
  }

  static bool _isErrorCode(String s) => const [
        '#SAYI/0!',
        '#DEĞER!',
        '#BAŞV!',
        '#AD?',
        '#YOK',
        '#SAYI!',
        '#BOŞ!',
        '#DIV/0!',
        '#VALUE!',
        '#REF!',
        '#NAME?',
        '#N/A',
        '#NUM!',
        '#NULL!',
      ].contains(s.trim());

  Object _eval(String src, Set<String> visiting,
      {int selfR = 0, int selfC = 0}) {
    final p = _Parser(src, this, visiting, selfR: selfR, selfC: selfC);
    final v = p.parseExpr();
    p.expectEnd();
    // Tek hücre referansı da aralık olarak taşınır (SATIR/SÜTUN/KAYDIR gibi
    // fonksiyonlar referansın KENDİSİNİ ister) → burada değere indirilir.
    return p.resolve(v);
  }

  // ── biçimleme ─────────────────────────────────────────────────────────────

  /// Hesap sonucunu HAM metne çevirir (ondalık `.` — gösterim biçimi ayrı
  /// katmanda uygulanır).
  static String fmt(Object v) {
    if (v is FormulaError) return v.code;
    if (v is bool) return v ? 'DOĞRU' : 'YANLIŞ';
    if (v is num) {
      final d = v.toDouble();
      if (d.isNaN) return '#SAYI!';
      if (d.isInfinite) return '#SAYI!';
      if (d == d.roundToDouble() && d.abs() < 1e15) {
        return d.toStringAsFixed(0);
      }
      var s = d.toStringAsFixed(10);
      s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
      return s;
    }
    return v.toString();
  }

  static double toNum(Object v) {
    if (v is FormulaError) throw v;
    if (v is num) return v.toDouble();
    if (v is bool) return v ? 1 : 0;
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return 0;
      final d = double.tryParse(t.replaceAll(',', '.'));
      if (d == null) throw const FormulaError('#DEĞER!');
      return d;
    }
    throw const FormulaError('#DEĞER!');
  }

  static bool toBool(Object v) {
    if (v is FormulaError) throw v;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toUpperCase();
      if (t == 'DOĞRU' || t == 'TRUE' || t == 'DOGRU') return true;
      if (t == 'YANLIŞ' || t == 'FALSE' || t == 'YANLIS' || t.isEmpty) {
        return false;
      }
      final d = double.tryParse(t);
      if (d == null) throw const FormulaError('#DEĞER!');
      return d != 0;
    }
    return false;
  }

  static String toStr(Object v) {
    if (v is FormulaError) throw v;
    if (v is bool) return v ? 'DOĞRU' : 'YANLIŞ';
    if (v is num) return fmt(v);
    return v.toString();
  }
}

/// Excel hata değeri — istisna DEĞİL, birinci sınıf bir değerdir; böylece
/// `EĞERHATA(...)` / `EHATALIYSA(...)` bunları yakalayabilir. (Aynı zamanda
/// Exception olduğu için hesabın ortasından fırlatılabilir de.)
class FormulaError implements Exception {
  final String code;
  const FormulaError(this.code);

  @override
  String toString() => code;

  @override
  bool operator ==(Object other) =>
      other is FormulaError && other.code == code;

  @override
  int get hashCode => code.hashCode;
}

/// Aralık değeri (A1:B3) — fonksiyon argümanlarında listelenir.
class _RangeValue {
  final int r1, c1, r2, c2;
  final String? sheet;
  const _RangeValue(this.r1, this.c1, this.r2, this.c2, [this.sheet]);
}

class _CycleError implements Exception {
  const _CycleError();
}

class _Parser {
  final String s;
  final FormulaEngine eng;
  final Set<String> visiting;

  /// Formülün BULUNDUĞU hücre — `SATIR()`/`SÜTUN()` argümansız çağrıldığında
  /// Excel bunu döndürür.
  final int selfR;
  final int selfC;
  int _i = 0;

  _Parser(this.s, this.eng, this.visiting, {this.selfR = 0, this.selfC = 0});

  /// Aralık/referans değerini tek değere indirir (dosya dışına açılan API).
  Object resolve(Object v) => _single(v);

  void expectEnd() {
    _skip();
    if (_i < s.length) throw const FormulaError('#DEĞER!');
  }

  void _skip() {
    while (_i < s.length && (s[_i] == ' ' || s[_i] == '\t' || s[_i] == '\n')) {
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
    } else if (_asNumber(a) != null && _asNumber(b) != null) {
      // Hücre değerleri modelde HAM METİN tutulur ('1234.5'), bu yüzden
      // sayı taşıyan metinle sayı SAYISAL karşılaştırılır — yoksa
      // `DÜŞEYARA(20; A:B; 2; 0)` gibi sayı aramaları hiç eşleşmiyordu.
      cmp = _asNumber(a)!.compareTo(_asNumber(b)!);
    } else if (a is String && b is String) {
      // Excel metin karşılaştırması büyük/küçük harf duyarsızdır.
      cmp = a.toLowerCase().compareTo(b.toLowerCase());
    } else {
      // Excel sıralaması: sayı < metin < mantıksal
      cmp = _rank(a).compareTo(_rank(b));
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

  /// Sayıya çevrilebiliyorsa değeri, değilse null (boş metin sayı DEĞİLDİR).
  static double? _asNumber(Object v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      final t = v.trim();
      if (t.isEmpty) return null;
      return double.tryParse(t);
    }
    return null;
  }

  static int _rank(Object v) {
    if (v is num) return 0;
    if (v is String) return v.trim().isEmpty ? 0 : 1;
    if (v is bool) return 2;
    return 3;
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
    if (_isDigit(ch) || ch == '.') return _parseNumber();
    if (_isAlpha(ch) || ch == r'$' || ch == '_') return _parseIdent();
    throw const FormulaError('#DEĞER!');
  }

  Object _parseErrorLiteral() {
    final start = _i;
    while (_i < s.length && s[_i] != ',' && s[_i] != ';' && s[_i] != ')') {
      _i++;
    }
    final code = s.substring(start, _i).trim();
    if (FormulaEngine._isErrorCode(code)) return FormulaError(code);
    throw const FormulaError('#AD?');
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
    while (_i < s.length && (_isDigit(s[_i]) || s[_i] == '.')) {
      _i++;
    }
    if (_i < s.length && (s[_i] == 'e' || s[_i] == 'E')) {
      final save = _i;
      _i++;
      if (_i < s.length && (s[_i] == '+' || s[_i] == '-')) _i++;
      if (_i < s.length && _isDigit(s[_i])) {
        while (_i < s.length && _isDigit(s[_i])) {
          _i++;
        }
      } else {
        _i = save;
      }
    }
    final d = double.tryParse(s.substring(start, _i));
    if (d == null) throw const FormulaError('#DEĞER!');
    return d;
  }

  /// Fonksiyon çağrısı, hücre referansı/aralığı, sayfa referansı ya da sabit.
  Object _parseIdent() {
    final start = _i;
    while (_i < s.length &&
        (_isAlpha(s[_i]) ||
            _isDigit(s[_i]) ||
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
      return _callFunc(_canonical(word), args);
    }

    // Sayfa referansı: Sayfa1!A1
    if (_i < s.length && s[_i] == '!') {
      _i++;
      return _parseRefOrRange(sheet: word);
    }

    final up = _canonical(word);
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
        (_isAlpha(s[_i]) || _isDigit(s[_i]) || s[_i] == r'$')) {
      _i++;
    }
    final first = _parseRef(s.substring(start, _i));
    if (first == null) throw const FormulaError('#AD?');
    if (_i < s.length && s[_i] == ':') {
      _i++;
      final start2 = _i;
      while (_i < s.length &&
          (_isAlpha(s[_i]) || _isDigit(s[_i]) || s[_i] == r'$')) {
        _i++;
      }
      final second = _parseRef(s.substring(start2, _i));
      if (second == null) throw const FormulaError('#AD?');
      return _RangeValue(
        math.min(first.$1, second.$1),
        math.min(first.$2, second.$2),
        math.max(first.$1, second.$1),
        math.max(first.$2, second.$2),
        sheet,
      );
    }
    // Tek hücre de REFERANS olarak taşınır; değere ihtiyaç duyan her yol
    // `_single` üzerinden geçiyor (bkz. FormulaEngine._eval).
    return _RangeValue(first.$1, first.$2, first.$1, first.$2, sheet);
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

  // ── fonksiyonlar ──────────────────────────────────────────────────────────

  /// Türkçe/İngilizce fonksiyon adını tek biçime indirger.
  static String _canonical(String word) {
    final up = word.toUpperCase();
    return _aliases[up] ?? _aliases[_trUpper(word)] ?? up;
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

  Object _callFunc(String name, List<Object> args) {
    switch (name) {
      // ── toplama / sayma ────────────────────────────────────────────────
      case 'SUM':
        return _numbers(args).fold<double>(0, (a, b) => a + b);
      case 'SUMSQ':
        return _numbers(args).fold<double>(0, (a, b) => a + b * b);
      case 'AVERAGE':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#SAYI/0!');
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
      case 'COUNTBLANK':
        return _flatten(args)
            .where((v) => v is String && v.trim().isEmpty)
            .length
            .toDouble();
      case 'PRODUCT':
        final n = _numbers(args);
        return n.isEmpty ? 0 : n.reduce((a, b) => a * b);
      case 'MEDIAN':
        final n = _numbers(args)..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final mid = n.length ~/ 2;
        return n.length.isOdd ? n[mid] : (n[mid - 1] + n[mid]) / 2;
      case 'MODE':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#YOK');
        final counts = <double, int>{};
        for (final v in n) {
          counts[v] = (counts[v] ?? 0) + 1;
        }
        var best = n.first, bestCount = 0;
        counts.forEach((k, v) {
          if (v > bestCount) {
            best = k;
            bestCount = v;
          }
        });
        return bestCount < 2 ? const FormulaError('#YOK') : best;
      case 'STDEV':
      case 'STDEVP':
      case 'VAR':
      case 'VARP':
        final n = _numbers(args);
        final population = name.endsWith('P');
        if (n.length < (population ? 1 : 2)) {
          return const FormulaError('#SAYI/0!');
        }
        final mean = n.reduce((a, b) => a + b) / n.length;
        final ss = n.fold<double>(0, (a, b) => a + (b - mean) * (b - mean));
        final divisor = population ? n.length : n.length - 1;
        final variance = ss / divisor;
        return name.startsWith('VAR') ? variance : math.sqrt(variance);
      case 'LARGE':
      case 'SMALL':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        final k = _numArg(args, 1, 1).round();
        if (k < 1 || k > n.length) return const FormulaError('#SAYI!');
        return name == 'LARGE' ? n[n.length - k] : n[k - 1];
      case 'RANK':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final v = _numArg(args, 0);
        final n = _numbers([args[1]]);
        final asc = args.length > 2 && FormulaEngine.toNum(_arg(args, 2)) != 0;
        n.sort();
        final idx = asc ? n.indexOf(v) : n.lastIndexOf(v);
        if (idx < 0) return const FormulaError('#YOK');
        return (asc ? idx + 1 : n.length - idx).toDouble();
      case 'SUMPRODUCT':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        return _sumProduct(args);
      case 'SUBTOTAL':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        final code = _numArg(args, 0).round() % 100;
        final rest = args.sublist(1);
        return switch (code) {
          1 => _callFunc('AVERAGE', rest),
          2 => _callFunc('COUNT', rest),
          3 => _callFunc('COUNTA', rest),
          4 => _callFunc('MAX', rest),
          5 => _callFunc('MIN', rest),
          6 => _callFunc('PRODUCT', rest),
          _ => _callFunc('SUM', rest),
        };

      // ── koşullu toplama ────────────────────────────────────────────────
      case 'SUMIF':
        return _sumIf(args);
      case 'COUNTIF':
        return _countIf(args);
      case 'AVERAGEIF':
        return _averageIf(args);
      case 'SUMIFS':
      case 'COUNTIFS':
      case 'AVERAGEIFS':
      case 'MAXIFS':
      case 'MINIFS':
        return _multiIf(name, args);

      // ── mantık ─────────────────────────────────────────────────────────
      case 'IF':
        if (args.isEmpty) return const FormulaError('#DEĞER!');
        final cond = _arg(args, 0);
        if (cond is FormulaError) return cond;
        if (FormulaEngine.toBool(cond)) return _arg(args, 1);
        return args.length >= 3 ? _arg(args, 2) : false;
      case 'IFS':
        for (var i = 0; i + 1 < args.length; i += 2) {
          final c = _arg(args, i);
          if (c is FormulaError) return c;
          if (FormulaEngine.toBool(c)) return _arg(args, i + 1);
        }
        return const FormulaError('#YOK');
      case 'SWITCH':
        final subject = _arg(args, 0);
        for (var i = 1; i + 1 < args.length; i += 2) {
          if (_compare('=', subject, _arg(args, i))) return _arg(args, i + 1);
        }
        return args.length.isEven ? _arg(args, args.length - 1) : const FormulaError('#YOK');
      case 'CHOOSE':
        final idx = _numArg(args, 0).round();
        if (idx < 1 || idx >= args.length) return const FormulaError('#DEĞER!');
        return _arg(args, idx);
      case 'AND':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .every(FormulaEngine.toBool);
      case 'OR':
        return _flatten(args)
            .where((v) => !(v is String && v.trim().isEmpty))
            .any(FormulaEngine.toBool);
      case 'XOR':
        return _flatten(args).where(FormulaEngine.toBool).length.isOdd;
      case 'NOT':
        return !FormulaEngine.toBool(_arg(args, 0));
      case 'IFERROR':
        final v = _safe(() => _arg(args, 0));
        if (v is FormulaError) return _arg(args, 1);
        return v;
      case 'IFNA':
        final v = _safe(() => _arg(args, 0));
        if (v is FormulaError && v.code == '#YOK') return _arg(args, 1);
        return v;
      case 'NA':
        return const FormulaError('#YOK');

      // ── bilgi ──────────────────────────────────────────────────────────
      case 'ISBLANK':
        final v = args.isEmpty ? '' : _arg(args, 0);
        return v is String && v.isEmpty;
      case 'ISNUMBER':
        final v = _safe(() => _arg(args, 0));
        return v is num;
      case 'ISTEXT':
        final v = _safe(() => _arg(args, 0));
        return v is String && v.isNotEmpty && double.tryParse(v) == null;
      case 'ISLOGICAL':
        return _safe(() => _arg(args, 0)) is bool;
      case 'ISERROR':
        return _safe(() => _arg(args, 0)) is FormulaError;
      case 'ISERR':
        final v = _safe(() => _arg(args, 0));
        return v is FormulaError && v.code != '#YOK';
      case 'ISNA':
        final v = _safe(() => _arg(args, 0));
        return v is FormulaError && v.code == '#YOK';
      case 'N':
        final v = _arg(args, 0);
        if (v is num) return v;
        if (v is bool) return v ? 1.0 : 0.0;
        return 0.0;
      case 'T':
        final v = _arg(args, 0);
        return v is String ? v : '';
      case 'TYPE':
        final v = _safe(() => _arg(args, 0));
        if (v is num) return 1.0;
        if (v is String) return 2.0;
        if (v is bool) return 4.0;
        return 16.0;

      // ── matematik ──────────────────────────────────────────────────────
      case 'ROUND':
        return _round(_numArg(args, 0), _numArg(args, 1).round());
      case 'ROUNDUP':
        return _roundDir(_numArg(args, 0), _numArg(args, 1).round(), true);
      case 'ROUNDDOWN':
        return _roundDir(_numArg(args, 0), _numArg(args, 1).round(), false);
      case 'TRUNC':
        return _roundDir(_numArg(args, 0), _numArg(args, 1).round(), false);
      case 'CEILING':
        final sig = _numArg(args, 1, 1);
        if (sig == 0) return 0.0;
        return (_numArg(args, 0) / sig).ceilToDouble() * sig;
      case 'FLOOR':
        final sig = _numArg(args, 1, 1);
        if (sig == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) / sig).floorToDouble() * sig;
      case 'ABS':
        return _numArg(args, 0).abs();
      case 'SIGN':
        final v = _numArg(args, 0);
        return v > 0 ? 1.0 : (v < 0 ? -1.0 : 0.0);
      case 'SQRT':
        final v = _numArg(args, 0);
        if (v < 0) return const FormulaError('#SAYI!');
        return math.sqrt(v);
      case 'POWER':
        return math.pow(_numArg(args, 0), _numArg(args, 1));
      case 'EXP':
        return math.exp(_numArg(args, 0));
      case 'LN':
        final v = _numArg(args, 0);
        if (v <= 0) return const FormulaError('#SAYI!');
        return math.log(v);
      case 'LOG10':
        final v = _numArg(args, 0);
        if (v <= 0) return const FormulaError('#SAYI!');
        return math.log(v) / math.ln10;
      case 'LOG':
        final v = _numArg(args, 0);
        final base = _numArg(args, 1, 10);
        if (v <= 0 || base <= 0 || base == 1) {
          return const FormulaError('#SAYI!');
        }
        return math.log(v) / math.log(base);
      case 'MOD':
        final a = _numArg(args, 0);
        final b = _numArg(args, 1);
        if (b == 0) return const FormulaError('#SAYI/0!');
        // Excel'de sonuç bölenin işaretini alır.
        return a - b * (a / b).floorToDouble();
      case 'QUOTIENT':
        final b = _numArg(args, 1);
        if (b == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) / b).truncateToDouble();
      case 'INT':
        return _numArg(args, 0).floorToDouble();
      case 'EVEN':
        final v = _numArg(args, 0);
        final r = (v.abs() / 2).ceilToDouble() * 2;
        return v < 0 ? -r : r;
      case 'ODD':
        final v = _numArg(args, 0);
        var r = (v.abs() / 2).ceilToDouble() * 2 - 1;
        if (r < 1) r = 1;
        return v < 0 ? -r : r;
      case 'FACT':
        final n = _numArg(args, 0).floor();
        if (n < 0 || n > 170) return const FormulaError('#SAYI!');
        var f = 1.0;
        for (var i = 2; i <= n; i++) {
          f *= i;
        }
        return f;
      case 'GCD':
        final n = _numbers(args).map((e) => e.abs().round()).toList();
        return n.isEmpty ? 0.0 : n.reduce(_gcd).toDouble();
      case 'LCM':
        final n = _numbers(args).map((e) => e.abs().round()).toList();
        if (n.isEmpty) return 0.0;
        return n.reduce((a, b) => a ~/ _gcd(a, b) * b).toDouble();
      case 'PI':
        return math.pi;
      case 'DEGREES':
        return _numArg(args, 0) * 180 / math.pi;
      case 'RADIANS':
        return _numArg(args, 0) * math.pi / 180;
      case 'SIN':
        return math.sin(_numArg(args, 0));
      case 'COS':
        return math.cos(_numArg(args, 0));
      case 'TAN':
        return math.tan(_numArg(args, 0));
      case 'ASIN':
        return math.asin(_numArg(args, 0));
      case 'ACOS':
        return math.acos(_numArg(args, 0));
      case 'ATAN':
        return math.atan(_numArg(args, 0));
      case 'ATAN2':
        return math.atan2(_numArg(args, 1), _numArg(args, 0));

      // ── metin ──────────────────────────────────────────────────────────
      case 'LEN':
        return _strArg(args, 0).length.toDouble();
      case 'UPPER':
        return _trUpper(_strArg(args, 0));
      case 'LOWER':
        return _trLower(_strArg(args, 0));
      case 'PROPER':
        return _strArg(args, 0)
            .split(' ')
            .map((w) => w.isEmpty
                ? w
                : _trUpper(w.substring(0, 1)) + _trLower(w.substring(1)))
            .join(' ');
      case 'TRIM':
        return _strArg(args, 0).trim().replaceAll(RegExp(r'\s+'), ' ');
      case 'CLEAN':
        return _strArg(args, 0)
            .replaceAll(RegExp(r'[\x00-\x1F]'), '');
      case 'LEFT':
        final t = _strArg(args, 0);
        final n = args.length >= 2 ? _numArg(args, 1).round() : 1;
        return t.substring(0, n.clamp(0, t.length));
      case 'RIGHT':
        final t = _strArg(args, 0);
        final n = args.length >= 2 ? _numArg(args, 1).round() : 1;
        return t.substring((t.length - n).clamp(0, t.length));
      case 'MID':
        final t = _strArg(args, 0);
        final start = _numArg(args, 1).round() - 1;
        final len = _numArg(args, 2).round();
        if (start < 0 || len < 0) return const FormulaError('#DEĞER!');
        if (start >= t.length) return '';
        return t.substring(start, (start + len).clamp(0, t.length));
      case 'FIND':
        final needle = _strArg(args, 0);
        final hay = _strArg(args, 1);
        final from = (args.length > 2 ? _numArg(args, 2).round() : 1) - 1;
        final idx = hay.indexOf(needle, from.clamp(0, hay.length));
        return idx < 0 ? const FormulaError('#DEĞER!') : (idx + 1).toDouble();
      case 'SEARCH':
        final needle = _trLower(_strArg(args, 0));
        final hay = _trLower(_strArg(args, 1));
        final from = (args.length > 2 ? _numArg(args, 2).round() : 1) - 1;
        final idx = hay.indexOf(needle, from.clamp(0, hay.length));
        return idx < 0 ? const FormulaError('#DEĞER!') : (idx + 1).toDouble();
      case 'SUBSTITUTE':
        final t = _strArg(args, 0);
        final from = _strArg(args, 1);
        final to = _strArg(args, 2);
        if (from.isEmpty) return t;
        if (args.length > 3) {
          final nth = _numArg(args, 3).round();
          var count = 0;
          var idx = 0;
          while (true) {
            final at = t.indexOf(from, idx);
            if (at < 0) return t;
            count++;
            if (count == nth) {
              return t.substring(0, at) + to + t.substring(at + from.length);
            }
            idx = at + from.length;
          }
        }
        return t.replaceAll(from, to);
      case 'REPLACE':
        final t = _strArg(args, 0);
        final start = _numArg(args, 1).round() - 1;
        final len = _numArg(args, 2).round();
        final rep = _strArg(args, 3);
        if (start < 0) return const FormulaError('#DEĞER!');
        final head = t.substring(0, start.clamp(0, t.length));
        final tail = t.substring((start + len).clamp(0, t.length));
        return '$head$rep$tail';
      case 'REPT':
        final t = _strArg(args, 0);
        final n = _numArg(args, 1).round();
        if (n < 0 || n * t.length > 32767) {
          return const FormulaError('#DEĞER!');
        }
        return t * n;
      case 'CONCAT':
      case 'CONCATENATE':
        return _flatten(args).map(FormulaEngine.toStr).join();
      case 'TEXTJOIN':
        final sep = _strArg(args, 0);
        final skipEmpty = args.length > 1 &&
            FormulaEngine.toBool(_arg(args, 1));
        final items = _flatten(args.sublist(math.min(2, args.length)))
            .map(FormulaEngine.toStr)
            .where((s) => !skipEmpty || s.isNotEmpty);
        return items.join(sep);
      case 'EXACT':
        return _strArg(args, 0) == _strArg(args, 1);
      case 'CHAR':
        return String.fromCharCode(_numArg(args, 0).round().clamp(0, 0x10FFFF));
      case 'CODE':
        final t = _strArg(args, 0);
        return t.isEmpty
            ? const FormulaError('#DEĞER!')
            : t.codeUnitAt(0).toDouble();
      case 'VALUE':
        var t = _strArg(args, 0).trim().replaceAll('%', '');
        if (t.contains(',') && t.contains('.')) {
          // "1.234,56" → binlik nokta, ondalık virgül
          t = t.replaceAll('.', '').replaceAll(',', '.');
        } else if (t.contains(',')) {
          t = t.replaceAll(',', '.');
        }
        final d = double.tryParse(t);
        return d ?? const FormulaError('#DEĞER!');
      case 'TEXT':
        final v = _arg(args, 0);
        final code = _strArg(args, 1);
        final numValue =
            v is num ? v.toDouble() : double.tryParse(v.toString());
        if (numValue == null) return FormulaEngine.toStr(v);
        return ExcelNumberFormat.parse(code).format(numValue).text;

      // ── tarih / saat ───────────────────────────────────────────────────
      case 'TODAY':
        final now = DateTime.now();
        return dateToExcelSerial(DateTime(now.year, now.month, now.day));
      case 'NOW':
        return dateToExcelSerial(DateTime.now());
      case 'DATE':
        return dateToExcelSerial(DateTime(_numArg(args, 0).round(),
            _numArg(args, 1).round(), _numArg(args, 2).round()));
      case 'TIME':
        return (_numArg(args, 0) * 3600 +
                _numArg(args, 1) * 60 +
                _numArg(args, 2)) /
            86400.0;
      case 'YEAR':
        return excelSerialToDate(_numArg(args, 0)).year.toDouble();
      case 'MONTH':
        return excelSerialToDate(_numArg(args, 0)).month.toDouble();
      case 'DAY':
        return excelSerialToDate(_numArg(args, 0)).day.toDouble();
      case 'HOUR':
        return excelSerialToDate(_numArg(args, 0)).hour.toDouble();
      case 'MINUTE':
        return excelSerialToDate(_numArg(args, 0)).minute.toDouble();
      case 'SECOND':
        return excelSerialToDate(_numArg(args, 0)).second.toDouble();
      case 'WEEKDAY':
        final dt = excelSerialToDate(_numArg(args, 0));
        final type = args.length > 1 ? _numArg(args, 1).round() : 1;
        final sunday0 = dt.weekday % 7; // 0=Pazar
        return switch (type) {
          2 => (dt.weekday).toDouble(), // 1=Pazartesi
          3 => (dt.weekday - 1).toDouble(),
          _ => (sunday0 + 1).toDouble(), // 1=Pazar
        };
      case 'DAYS':
        return (_numArg(args, 0) - _numArg(args, 1)).floorToDouble();
      case 'EDATE':
      case 'EOMONTH':
        final dt = excelSerialToDate(_numArg(args, 0));
        final months = _numArg(args, 1).round();
        final target = DateTime.utc(dt.year, dt.month + months, 1);
        if (name == 'EOMONTH') {
          final last = DateTime.utc(target.year, target.month + 1, 0);
          return dateToExcelSerial(last);
        }
        final lastDay = DateTime.utc(target.year, target.month + 1, 0).day;
        return dateToExcelSerial(DateTime.utc(
            target.year, target.month, math.min(dt.day, lastDay)));
      case 'DATEDIF':
        final a = excelSerialToDate(_numArg(args, 0));
        final b = excelSerialToDate(_numArg(args, 1));
        final unit = _strArg(args, 2).toUpperCase();
        var years = b.year - a.year;
        var months = b.month - a.month;
        var days = b.day - a.day;
        if (days < 0) months--;
        if (months < 0) {
          years--;
          months += 12;
        }
        return switch (unit) {
          'Y' => years.toDouble(),
          'M' => (years * 12 + months).toDouble(),
          _ => b.difference(a).inDays.toDouble(),
        };

      // ── arama ──────────────────────────────────────────────────────────
      case 'VLOOKUP':
      case 'HLOOKUP':
        return _lookup(name, args);
      case 'INDEX':
        return _index(args);
      case 'MATCH':
        return _matchFn(args);
      case 'ROW':
        // Argümansız: formülün kendi satırı (Excel davranışı).
        if (_isEmptyArgs(args)) return (selfR + 1).toDouble();
        if (args.first is! _RangeValue) return const FormulaError('#DEĞER!');
        return ((args.first as _RangeValue).r1 + 1).toDouble();
      case 'COLUMN':
        if (_isEmptyArgs(args)) return (selfC + 1).toDouble();
        if (args.first is! _RangeValue) return const FormulaError('#DEĞER!');
        return ((args.first as _RangeValue).c1 + 1).toDouble();
      case 'ROWS':
        if (args.isEmpty || args.first is! _RangeValue) return 1.0;
        final r = args.first as _RangeValue;
        return (r.r2 - r.r1 + 1).toDouble();
      case 'COLUMNS':
        if (args.isEmpty || args.first is! _RangeValue) return 1.0;
        final r = args.first as _RangeValue;
        return (r.c2 - r.c1 + 1).toDouble();

      // ── başvuru (referans) fonksiyonları ───────────────────────────────
      case 'OFFSET':
        return _offset(args);
      case 'INDIRECT':
        return _indirect(args);
      case 'ADDRESS':
        final row = _numArg(args, 0).round();
        final col = _numArg(args, 1).round();
        if (row < 1 || col < 1) return const FormulaError('#DEĞER!');
        final abs = args.length > 2 ? _numArg(args, 2, 1).round() : 1;
        final letters = _colName(col - 1);
        final colPart = (abs == 1 || abs == 3) ? '\$$letters' : letters;
        final rowPart = (abs == 1 || abs == 2) ? '\$$row' : '$row';
        final sheetPart = args.length > 4 ? _strArg(args, 4) : '';
        final prefix = sheetPart.isEmpty ? '' : "'$sheetPart'!";
        return '$prefix$colPart$rowPart';
      case 'LOOKUP':
        return _lookupVector(args);
      case 'XLOOKUP':
        return _xlookup(args);
      case 'FORMULATEXT':
        if (args.isEmpty || args.first is! _RangeValue) {
          return const FormulaError('#DEĞER!');
        }
        final ref = args.first as _RangeValue;
        final raw = eng.rawTextOf(ref.r1, ref.c1, ref.sheet);
        return raw.startsWith('=') ? raw : const FormulaError('#YOK');
      case 'ISFORMULA':
        if (args.isEmpty || args.first is! _RangeValue) return false;
        final ref = args.first as _RangeValue;
        return eng.rawTextOf(ref.r1, ref.c1, ref.sheet).startsWith('=');
      case 'ISREF':
        return args.isNotEmpty && args.first is _RangeValue;
      case 'ISEVEN':
      case 'ISODD':
        final v = FormulaEngine.toNum(_arg(args, 0)).truncate();
        return name == 'ISEVEN' ? v.isEven : v.isOdd;
      case 'ERROR.TYPE':
        final v = _safe(() => _arg(args, 0));
        if (v is! FormulaError) return const FormulaError('#YOK');
        return switch (v.code) {
          '#BOŞ!' || '#NULL!' => 1.0,
          '#SAYI/0!' || '#DIV/0!' => 2.0,
          '#DEĞER!' || '#VALUE!' => 3.0,
          '#BAŞV!' || '#REF!' => 4.0,
          '#AD?' || '#NAME?' => 5.0,
          '#SAYI!' || '#NUM!' => 6.0,
          _ => 7.0,
        };

      // ── matematik (ek) ─────────────────────────────────────────────────
      case 'MROUND':
        final x = _numArg(args, 0);
        final m = _numArg(args, 1);
        if (m == 0) return 0.0;
        if (x != 0 && (x < 0) != (m < 0)) return const FormulaError('#SAYI!');
        final q = x / m;
        // Excel yarımı SIFIRDAN UZAĞA yuvarlar (Dart round() da öyle).
        return q.round() * m;
      case 'CEILING.MATH':
      case 'FLOOR.MATH':
        final x = _numArg(args, 0);
        var sig = args.length > 1 ? _numArg(args, 1, 1) : 1.0;
        if (sig == 0) return 0.0;
        sig = sig.abs();
        final awayFromZero = args.length > 2 && _numArg(args, 2) != 0;
        final up = name == 'CEILING.MATH';
        final q = x / sig;
        double r;
        if (x < 0 && awayFromZero) {
          r = up ? q.truncateToDouble() : q.floorToDouble();
          if (up && r != q) r = q.truncateToDouble();
        } else {
          r = up ? q.ceilToDouble() : q.floorToDouble();
        }
        return r * sig;
      case 'COMBIN':
      case 'PERMUT':
        final n = _numArg(args, 0).truncate();
        final k = _numArg(args, 1).truncate();
        if (n < 0 || k < 0 || k > n) return const FormulaError('#SAYI!');
        var p = 1.0;
        for (var i = 0; i < k; i++) {
          p *= n - i;
        }
        if (name == 'PERMUT') return p;
        var f = 1.0;
        for (var i = 2; i <= k; i++) {
          f *= i;
        }
        return (p / f).roundToDouble();
      case 'SINH':
        final x = _numArg(args, 0);
        return (math.exp(x) - math.exp(-x)) / 2;
      case 'COSH':
        final x = _numArg(args, 0);
        return (math.exp(x) + math.exp(-x)) / 2;
      case 'TANH':
        final x = _numArg(args, 0);
        final e2 = math.exp(2 * x);
        return (e2 - 1) / (e2 + 1);

      // ── istatistik (ek) ────────────────────────────────────────────────
      case 'AVERAGEA':
      case 'MAXA':
      case 'MINA':
        final n = _numbersA(args);
        if (n.isEmpty) {
          return name == 'AVERAGEA'
              ? const FormulaError('#SAYI/0!')
              : 0.0;
        }
        return switch (name) {
          'AVERAGEA' => n.reduce((a, b) => a + b) / n.length,
          'MAXA' => n.reduce(math.max),
          _ => n.reduce(math.min),
        };
      case 'GEOMEAN':
        final n = _numbers(args);
        if (n.isEmpty || n.any((v) => v <= 0)) {
          return const FormulaError('#SAYI!');
        }
        var logSum = 0.0;
        for (final v in n) {
          logSum += math.log(v);
        }
        return math.exp(logSum / n.length);
      case 'HARMEAN':
        final n = _numbers(args);
        if (n.isEmpty || n.any((v) => v <= 0)) {
          return const FormulaError('#SAYI!');
        }
        var inv = 0.0;
        for (final v in n) {
          inv += 1 / v;
        }
        return n.length / inv;
      case 'AVEDEV':
      case 'DEVSQ':
        final n = _numbers(args);
        if (n.isEmpty) return const FormulaError('#SAYI/0!');
        final mean = n.reduce((a, b) => a + b) / n.length;
        if (name == 'DEVSQ') {
          return n.fold<double>(0, (a, b) => a + (b - mean) * (b - mean));
        }
        return n.fold<double>(0, (a, b) => a + (b - mean).abs()) / n.length;
      case 'PERCENTILE':
      case 'QUARTILE':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final k = name == 'QUARTILE'
            ? _numArg(args, 1).round() / 4.0
            : _numArg(args, 1);
        if (k < 0 || k > 1) return const FormulaError('#SAYI!');
        return _percentile(n, k);
      case 'PERCENTRANK':
        if (args.length < 2) return const FormulaError('#DEĞER!');
        final n = _numbers([args.first])..sort();
        if (n.isEmpty) return const FormulaError('#SAYI!');
        final x = _numArg(args, 1);
        if (x < n.first || x > n.last) return const FormulaError('#SAYI!');
        var below = 0;
        for (final v in n) {
          if (v < x) below++;
        }
        var equal = 0;
        for (final v in n) {
          if (v == x) equal++;
        }
        final rank = equal > 0
            ? below / (n.length - 1)
            : _interpolatedRank(n, x);
        final digits = args.length > 2 ? _numArg(args, 2, 3).round() : 3;
        return _round(rank, digits);

      // ── metin (ek) ─────────────────────────────────────────────────────
      case 'TEXTBEFORE':
      case 'TEXTAFTER':
        final text = _strArg(args, 0);
        final delim = _strArg(args, 1);
        if (delim.isEmpty) return text;
        final instance = args.length > 2 ? _numArg(args, 2, 1).round() : 1;
        final idx = _nthIndex(text, delim, instance);
        if (idx < 0) return const FormulaError('#YOK');
        return name == 'TEXTBEFORE'
            ? text.substring(0, idx)
            : text.substring(idx + delim.length);
      case 'NUMBERVALUE':
        final text = _strArg(args, 0);
        final dec = args.length > 1 ? _strArg(args, 1) : ',';
        final group = args.length > 2 ? _strArg(args, 2) : '.';
        var t = text.trim();
        if (group.isNotEmpty) t = t.replaceAll(group, '');
        if (dec.isNotEmpty) t = t.replaceAll(dec, '.');
        // Yüzde işareti sonda (Excel) ya da başta (Türkçe yazım: %15).
        var percents = 0;
        final trailing = RegExp(r'%+$').firstMatch(t);
        if (trailing != null) {
          percents += trailing.group(0)!.length;
          t = t.substring(0, trailing.start);
        }
        final leading = RegExp(r'^%+').firstMatch(t);
        if (leading != null) {
          percents += leading.group(0)!.length;
          t = t.substring(leading.end);
        }
        final d = double.tryParse(t.trim());
        if (d == null) return const FormulaError('#DEĞER!');
        return percents == 0 ? d : d / math.pow(100, percents);
      case 'FIXED':
        final v = _numArg(args, 0);
        final digits = args.length > 1 ? _numArg(args, 1, 2).round() : 2;
        final noCommas = args.length > 2 && _numArg(args, 2) != 0;
        final code = noCommas
            ? (digits > 0 ? '0.${'0' * digits}' : '0')
            : (digits > 0 ? '#,##0.${'0' * digits}' : '#,##0');
        return ExcelNumberFormat.parse(code).format(v).text;
      case 'UNICHAR':
        final code = _numArg(args, 0).round();
        if (code < 1) return const FormulaError('#DEĞER!');
        return String.fromCharCode(code);
      case 'UNICODE':
        final t = _strArg(args, 0);
        if (t.isEmpty) return const FormulaError('#DEĞER!');
        return t.runes.first.toDouble();

      // ── tarih (ek) ─────────────────────────────────────────────────────
      case 'WEEKNUM':
        final dt = excelSerialToDate(_numArg(args, 0));
        final type = args.length > 1 ? _numArg(args, 1, 1).round() : 1;
        final startsMonday = type == 2 || type == 11 || type == 21;
        final jan1 = DateTime.utc(dt.year, 1, 1);
        // Yılın ilk gününün hafta içindeki sırası (0 = haftanın ilk günü).
        final offset = startsMonday
            ? (jan1.weekday - 1)
            : (jan1.weekday % 7);
        final dayOfYear = dt.difference(jan1).inDays;
        return ((dayOfYear + offset) / 7).floor() + 1.0;
      case 'ISOWEEKNUM':
        final dt = excelSerialToDate(_numArg(args, 0));
        final thursday = dt.add(Duration(days: 4 - dt.weekday));
        final jan1 = DateTime.utc(thursday.year, 1, 1);
        return (thursday.difference(jan1).inDays / 7).floor() + 1.0;
      case 'NETWORKDAYS':
        final a = excelSerialToDate(_numArg(args, 0));
        final b = excelSerialToDate(_numArg(args, 1));
        final holidays = _holidaySet(args, 2);
        final forward = !b.isBefore(a);
        final from = forward ? a : b;
        final to = forward ? b : a;
        var count = 0;
        for (var d = from;
            !d.isAfter(to);
            d = d.add(const Duration(days: 1))) {
          if (d.weekday == DateTime.saturday ||
              d.weekday == DateTime.sunday) {
            continue;
          }
          if (holidays.contains(_dayKey(d))) continue;
          count++;
        }
        return (forward ? count : -count).toDouble();
      case 'WORKDAY':
        var d = excelSerialToDate(_numArg(args, 0));
        var left = _numArg(args, 1).round();
        final holidays = _holidaySet(args, 2);
        final step = left >= 0 ? 1 : -1;
        left = left.abs();
        while (left > 0) {
          d = d.add(Duration(days: step));
          if (d.weekday == DateTime.saturday ||
              d.weekday == DateTime.sunday) {
            continue;
          }
          if (holidays.contains(_dayKey(d))) continue;
          left--;
        }
        return dateToExcelSerial(d);
      case 'DATEVALUE':
        final serial = _parseDateText(_strArg(args, 0));
        return serial ?? const FormulaError('#DEĞER!');
      case 'TIMEVALUE':
        final frac = _parseTimeText(_strArg(args, 0));
        return frac ?? const FormulaError('#DEĞER!');
      case 'YEARFRAC':
        return _yearFrac(
          excelSerialToDate(_numArg(args, 0)),
          excelSerialToDate(_numArg(args, 1)),
          args.length > 2 ? _numArg(args, 2).round() : 0,
        );

      // ── finans (kredi/taksit tabloları) ────────────────────────────────
      case 'PMT':
      case 'PV':
      case 'FV':
      case 'NPER':
      case 'RATE':
      case 'IPMT':
      case 'PPMT':
        return _financial(name, args);
      case 'NPV':
        final rate = _numArg(args, 0);
        final flows = _numbers(args.sublist(1));
        var npv = 0.0;
        for (var i = 0; i < flows.length; i++) {
          npv += flows[i] / math.pow(1 + rate, i + 1);
        }
        return npv;
      case 'IRR':
        final flows = _numbers([args.first]);
        if (flows.length < 2) return const FormulaError('#SAYI!');
        return _irr(flows, args.length > 1 ? _numArg(args, 1, 0.1) : 0.1);
      case 'SLN':
        final life = _numArg(args, 2);
        if (life == 0) return const FormulaError('#SAYI/0!');
        return (_numArg(args, 0) - _numArg(args, 1)) / life;

      default:
        return const FormulaError('#AD?'); // bilinmeyen fonksiyon
    }
  }

  static bool _isEmptyArgs(List<Object> args) =>
      args.isEmpty ||
      (args.length == 1 && args.first is String && (args.first as String).isEmpty);

  Object _safe(Object Function() body) {
    try {
      return body();
    } on _CycleError {
      return const FormulaError('#DÖNGÜ');
    } on FormulaError catch (e) {
      return e;
    } catch (_) {
      return const FormulaError('#DEĞER!');
    }
  }

  static int _gcd(int a, int b) => b == 0 ? a : _gcd(b, a % b);

  static double _round(double v, int digits) {
    final f = math.pow(10, digits).toDouble();
    return (v * f).roundToDouble() / f;
  }

  static double _roundDir(double v, int digits, bool up) {
    final f = math.pow(10, digits).toDouble();
    final scaled = v * f;
    final r = up
        ? (v < 0 ? scaled.floorToDouble() : scaled.ceilToDouble())
        : scaled.truncateToDouble();
    return r / f;
  }

  // ── koşul ölçütü (">5", "elma", "<>x", joker) ──────────────────────────

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
        return _cmpNum(asNum, operandNum, op);
      }
      return _cmpNum(value.toDouble(), operandNum, op);
    }
    final text = FormulaEngine.toStr(value);
    if (op == '=' || op == '<>') {
      final hit = _wildcardMatch(text, operand);
      return op == '=' ? hit : !hit;
    }
    final cmp = _trLower(text).compareTo(_trLower(operand));
    return switch (op) {
      '<' => cmp < 0,
      '>' => cmp > 0,
      '<=' => cmp <= 0,
      '>=' => cmp >= 0,
      _ => false,
    };
  }

  static bool _cmpNum(double a, double b, String op) => switch (op) {
        '<' => a < b,
        '>' => a > b,
        '<=' => a <= b,
        '>=' => a >= b,
        '<>' => a != b,
        _ => a == b,
      };

  /// Excel jokerleri: `*` (herhangi) ve `?` (tek karakter).
  static bool _wildcardMatch(String text, String pattern) {
    if (!pattern.contains('*') && !pattern.contains('?')) {
      return _trLower(text) == _trLower(pattern);
    }
    final escaped = RegExp.escape(pattern)
        .replaceAll(r'\*', '.*')
        .replaceAll(r'\?', '.');
    return RegExp('^$escaped\$', caseSensitive: false)
        .hasMatch(text);
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
          if (_wildcardMatch(values[i] as String, needle)) {
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

  // ── başvuru fonksiyonları ────────────────────────────────────────────────

  /// Argüman verilmiş mi? (`_parseArgs` atlanan argümanı boş dize yapar.)
  bool _given(List<Object> args, int i) =>
      i < args.length && !(args[i] is String && (args[i] as String).isEmpty);

  /// Sütun numarası → "A", "AB" (yalnız bu dosya için; ekran tarafındaki
  /// `XlsxRange.colName` ile aynı kural).
  static String _colName(int index) {
    var i = index;
    final sb = StringBuffer();
    while (i >= 0) {
      sb.write(String.fromCharCode(65 + (i % 26)));
      i = i ~/ 26 - 1;
    }
    return String.fromCharCodes(sb.toString().codeUnits.reversed);
  }

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
        if (_wildcardMatch(
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

  // ── istatistik / metin yardımcıları ──────────────────────────────────────

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

  static double _percentile(List<double> sorted, double k) {
    if (sorted.length == 1) return sorted.first;
    final pos = k * (sorted.length - 1);
    final lower = pos.floor();
    final frac = pos - lower;
    if (lower + 1 >= sorted.length) return sorted.last;
    return sorted[lower] + frac * (sorted[lower + 1] - sorted[lower]);
  }

  static double _interpolatedRank(List<double> sorted, double x) {
    for (var i = 0; i + 1 < sorted.length; i++) {
      if (x > sorted[i] && x < sorted[i + 1]) {
        final span = sorted[i + 1] - sorted[i];
        final frac = span == 0 ? 0.0 : (x - sorted[i]) / span;
        return (i + frac) / (sorted.length - 1);
      }
    }
    return 0;
  }

  /// [instance]. geçtiği yerin dizini; negatifse sondan sayar.
  static int _nthIndex(String text, String delim, int instance) {
    if (instance == 0) return -1;
    if (instance > 0) {
      var from = 0;
      for (var k = 0; k < instance; k++) {
        final idx = text.indexOf(delim, from);
        if (idx < 0) return -1;
        if (k == instance - 1) return idx;
        from = idx + delim.length;
      }
      return -1;
    }
    var from = text.length;
    for (var k = 0; k < -instance; k++) {
      final idx = text.lastIndexOf(delim, from - 1);
      if (idx < 0) return -1;
      if (k == -instance - 1) return idx;
      from = idx;
    }
    return -1;
  }

  // ── tarih yardımcıları ───────────────────────────────────────────────────

  static int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

  Set<int> _holidaySet(List<Object> args, int index) {
    if (!_given(args, index)) return const {};
    final out = <int>{};
    for (final v in _rangeValues(args[index])) {
      final d = v is num ? v.toDouble() : double.tryParse(v.toString());
      if (d == null) continue;
      out.add(_dayKey(excelSerialToDate(d)));
    }
    return out;
  }

  /// "12.03.2026", "2026-03-12", "12/03/2026" → Excel seri numarası.
  static double? _parseDateText(String text) {
    final t = text.trim();
    final iso = RegExp(r'^(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})$').firstMatch(t);
    if (iso != null) {
      return dateToExcelSerial(DateTime.utc(int.parse(iso.group(1)!),
          int.parse(iso.group(2)!), int.parse(iso.group(3)!)));
    }
    final dmy =
        RegExp(r'^(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})$').firstMatch(t);
    if (dmy != null) {
      var year = int.parse(dmy.group(3)!);
      if (year < 100) year += year < 30 ? 2000 : 1900;
      return dateToExcelSerial(DateTime.utc(
          year, int.parse(dmy.group(2)!), int.parse(dmy.group(1)!)));
    }
    return null;
  }

  /// "14:30", "14:30:05" → günün kesri.
  static double? _parseTimeText(String text) {
    final m = RegExp(r'^(\d{1,2}):(\d{1,2})(?::(\d{1,2}(?:[.,]\d+)?))?$')
        .firstMatch(text.trim());
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final min = int.parse(m.group(2)!);
    final sec = double.tryParse((m.group(3) ?? '0').replaceAll(',', '.')) ?? 0;
    return (h * 3600 + min * 60 + sec) / 86400.0;
  }

  /// YILORAN — 0/4: 30/360, 1: gerçek/gerçek, 2: gerçek/360, 3: gerçek/365.
  static Object _yearFrac(DateTime a, DateTime b, int basis) {
    final start = a.isAfter(b) ? b : a;
    final end = a.isAfter(b) ? a : b;
    switch (basis) {
      case 1:
        final days = end.difference(start).inDays;
        final years = end.year - start.year + 1;
        var totalDays = 0;
        for (var y = start.year; y <= end.year; y++) {
          totalDays += _isLeap(y) ? 366 : 365;
        }
        return days / (totalDays / years);
      case 2:
        return end.difference(start).inDays / 360.0;
      case 3:
        return end.difference(start).inDays / 365.0;
      case 4:
        final d1 = math.min(start.day, 30);
        final d2 = math.min(end.day, 30);
        return (360 * (end.year - start.year) +
                30 * (end.month - start.month) +
                (d2 - d1)) /
            360.0;
      default:
        // ABD 30/360: ayın son günleri 30'a çekilir.
        var d1 = start.day;
        var d2 = end.day;
        if (d1 == 31) d1 = 30;
        if (d2 == 31 && d1 >= 30) d2 = 30;
        return (360 * (end.year - start.year) +
                30 * (end.month - start.month) +
                (d2 - d1)) /
            360.0;
    }
  }

  static bool _isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  // ── finans ───────────────────────────────────────────────────────────────

  /// PMT/PV/FV/NPER/RATE/IPMT/PPMT — Excel'in para akışı işaret kuralıyla
  /// (ödeme negatif, alınan tutar pozitif).
  Object _financial(String name, List<Object> args) {
    switch (name) {
      case 'PMT':
        return _pmtRaw(_numArg(args, 0), _numArg(args, 1), _numArg(args, 2),
            _given(args, 3) ? _numArg(args, 3) : 0,
            _given(args, 4) ? _numArg(args, 4) : 0);
      case 'FV':
        return _fvRaw(_numArg(args, 0), _numArg(args, 1), _numArg(args, 2),
            _given(args, 3) ? _numArg(args, 3) : 0,
            _given(args, 4) ? _numArg(args, 4) : 0);
      case 'PV':
        final rate = _numArg(args, 0);
        final n = _numArg(args, 1);
        final pmt = _numArg(args, 2);
        final fv = _given(args, 3) ? _numArg(args, 3) : 0.0;
        final type = _given(args, 4) ? _numArg(args, 4) : 0.0;
        if (rate == 0) return -(fv + pmt * n);
        final p = math.pow(1 + rate, n).toDouble();
        return -(fv + pmt * (1 + rate * type) * (p - 1) / rate) / p;
      case 'NPER':
        final rate = _numArg(args, 0);
        final pmt = _numArg(args, 1);
        final pv = _numArg(args, 2);
        final fv = _given(args, 3) ? _numArg(args, 3) : 0.0;
        final type = _given(args, 4) ? _numArg(args, 4) : 0.0;
        if (rate == 0) {
          if (pmt == 0) return const FormulaError('#SAYI!');
          return -(pv + fv) / pmt;
        }
        final adj = pmt * (1 + rate * type);
        final num = adj - fv * rate;
        final den = pv * rate + adj;
        if (den == 0 || num / den <= 0) return const FormulaError('#SAYI!');
        return math.log(num / den) / math.log(1 + rate);
      case 'RATE':
        return _rateSolve(
          _numArg(args, 0),
          _numArg(args, 1),
          _numArg(args, 2),
          _given(args, 3) ? _numArg(args, 3) : 0,
          _given(args, 4) ? _numArg(args, 4) : 0,
          _given(args, 5) ? _numArg(args, 5) : 0.1,
        );
      default: // IPMT / PPMT
        final rate = _numArg(args, 0);
        final per = _numArg(args, 1);
        final nper = _numArg(args, 2);
        final pv = _numArg(args, 3);
        final fv = _given(args, 4) ? _numArg(args, 4) : 0.0;
        final type = _given(args, 5) ? _numArg(args, 5) : 0.0;
        if (per < 1 || per > nper) return const FormulaError('#SAYI!');
        final pmt = _pmtRaw(rate, nper, pv, fv, type);
        double ipmt;
        if (per == 1) {
          ipmt = type == 1 ? 0 : -pv * rate;
        } else if (type == 1) {
          ipmt = (_fvRaw(rate, per - 2, pmt, pv, 1) - pmt) * rate;
        } else {
          ipmt = _fvRaw(rate, per - 1, pmt, pv, 0) * rate;
        }
        return name == 'IPMT' ? ipmt : pmt - ipmt;
    }
  }

  static double _pmtRaw(
      double rate, double nper, double pv, double fv, double type) {
    if (nper == 0) return double.nan;
    if (rate == 0) return -(pv + fv) / nper;
    final p = math.pow(1 + rate, nper).toDouble();
    return -(pv * p + fv) * rate / ((1 + rate * type) * (p - 1));
  }

  static double _fvRaw(
      double rate, double nper, double pmt, double pv, double type) {
    if (rate == 0) return -(pv + pmt * nper);
    final p = math.pow(1 + rate, nper).toDouble();
    return -(pv * p + pmt * (1 + rate * type) * (p - 1) / rate);
  }

  /// FAİZ_ORANI — kapalı çözümü yok, Newton ile aranır.
  static Object _rateSolve(double nper, double pmt, double pv, double fv,
      double type, double guess) {
    double f(double r) {
      if (r == 0) return pv + pmt * nper + fv;
      final p = math.pow(1 + r, nper).toDouble();
      return pv * p + pmt * (1 + r * type) * (p - 1) / r + fv;
    }

    var r = guess == 0 ? 0.1 : guess;
    for (var i = 0; i < 128; i++) {
      final y = f(r);
      if (y.abs() < 1e-10) return r;
      final h = math.max(1e-7, r.abs() * 1e-6);
      final slope = (f(r + h) - f(r - h)) / (2 * h);
      if (slope == 0 || slope.isNaN) break;
      final next = r - y / slope;
      if (next.isNaN || next.isInfinite || next <= -1) break;
      if ((next - r).abs() < 1e-12) return next;
      r = next;
    }
    return const FormulaError('#SAYI!');
  }

  /// İÇ_VERİM_ORANI — Newton, tutmazsa ikili arama.
  static Object _irr(List<double> flows, double guess) {
    double npv(double r) {
      var total = 0.0;
      for (var i = 0; i < flows.length; i++) {
        total += flows[i] / math.pow(1 + r, i);
      }
      return total;
    }

    var r = guess <= -1 ? 0.1 : guess;
    for (var i = 0; i < 128; i++) {
      final y = npv(r);
      if (y.abs() < 1e-9) return r;
      const h = 1e-6;
      final slope = (npv(r + h) - npv(r - h)) / (2 * h);
      if (slope == 0 || slope.isNaN) break;
      final next = r - y / slope;
      if (next.isNaN || next.isInfinite || next <= -0.999999) break;
      r = next;
    }
    // İkili arama (işaret değişimi aranır).
    var lo = -0.9999, hi = 10.0;
    var flo = npv(lo), fhi = npv(hi);
    if (flo.isNaN || fhi.isNaN || flo * fhi > 0) {
      return const FormulaError('#SAYI!');
    }
    for (var i = 0; i < 256; i++) {
      final mid = (lo + hi) / 2;
      final fm = npv(mid);
      if (fm.abs() < 1e-9) return mid;
      if (flo * fm < 0) {
        hi = mid;
        fhi = fm;
      } else {
        lo = mid;
        flo = fm;
      }
    }
    return (lo + hi) / 2;
  }

  // ── karakter yardımcıları ────────────────────────────────────────────────

  /// Türkçe büyük harf: `i→İ`, `ı→I` (Dart'ın varsayılanı yanlış yapar).
  static String _trUpper(String s) => s
      .replaceAll('i', 'İ')
      .replaceAll('ı', 'I')
      .toUpperCase();

  static String _trLower(String s) => s
      .replaceAll('İ', 'i')
      .replaceAll('I', 'ı')
      .toLowerCase();

  static bool _isDigit(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  /// Harf: ASCII + Türkçe (fonksiyon adları `EĞERSAY` gibi olabilir).
  static bool _isAlpha(String c) {
    final u = c.codeUnitAt(0);
    if ((u >= 65 && u <= 90) || (u >= 97 && u <= 122)) return true;
    return u > 127;
  }

  /// Türkçe Excel fonksiyon adları → İngilizce karşılığı.
  static const Map<String, String> _aliases = {
    'TOPLA': 'SUM',
    'ÇARPIM': 'PRODUCT',
    'ORTALAMA': 'AVERAGE',
    'ENBÜYÜK': 'LARGE',
    'ENKÜÇÜK': 'SMALL',
    'MAK': 'MAX',
    'MİN': 'MIN',
    'BAĞ_DEĞ_SAY': 'COUNT',
    'BAĞ_DEĞ_DOLU_SAY': 'COUNTA',
    'BOŞLUKSAY': 'COUNTBLANK',
    'EĞERSAY': 'COUNTIF',
    'ÇOKEĞERSAY': 'COUNTIFS',
    'ETOPLA': 'SUMIF',
    'ÇOKETOPLA': 'SUMIFS',
    'ORTALAMAEĞER': 'AVERAGEIF',
    'ÇOKORTALAMA': 'AVERAGEIFS',
    'TOPLA.ÇARPIM': 'SUMPRODUCT',
    'ALTTOPLAM': 'SUBTOTAL',
    'ORTANCA': 'MEDIAN',
    'ENÇOK_OLAN': 'MODE',
    'STDSAPMA': 'STDEV',
    'VAR': 'VAR',
    'EĞER': 'IF',
    'ÇOKEĞER': 'IFS',
    'EĞERHATA': 'IFERROR',
    'EĞERYOKSA': 'IFNA',
    'VE': 'AND',
    'YADA': 'OR',
    'DEĞİL': 'NOT',
    'ELEMAN': 'CHOOSE',
    'YOKSAY': 'NA',
    'EBOŞSA': 'ISBLANK',
    'ESAYIYSA': 'ISNUMBER',
    'EMETİNSE': 'ISTEXT',
    'EHATALIYSA': 'ISERROR',
    'EYOKSA': 'ISNA',
    'YUVARLA': 'ROUND',
    'YUKARIYUVARLA': 'ROUNDUP',
    'AŞAĞIYUVARLA': 'ROUNDDOWN',
    // Türkçe Excel: TAVANAYUVARLA = CEILING, KYUVARLA = MROUND.
    'TAVANAYUVARLA': 'CEILING',
    'KYUVARLA': 'MROUND',
    'TABANAYUVARLA': 'FLOOR',
    'NSAT': 'TRUNC',
    'MUTLAK': 'ABS',
    'İŞARET': 'SIGN',
    'KAREKÖK': 'SQRT',
    'KUVVET': 'POWER',
    'ÜS': 'EXP',
    'LN': 'LN',
    'MODÜLO': 'MOD',
    'BÖLÜM': 'QUOTIENT',
    'TAMSAYI': 'INT',
    'ÇİFT': 'EVEN',
    'TEK': 'ODD',
    'ÇARPINIM': 'FACT',
    'OBEB': 'GCD',
    'OKEK': 'LCM',
    'PİSAYISI': 'PI',
    'DERECE': 'DEGREES',
    'RADYAN': 'RADIANS',
    'UZUNLUK': 'LEN',
    'BÜYÜKHARF': 'UPPER',
    'KÜÇÜKHARF': 'LOWER',
    'YAZIM.DÜZENİ': 'PROPER',
    'KIRP': 'TRIM',
    'TEMİZ': 'CLEAN',
    'SOLDAN': 'LEFT',
    'SAĞDAN': 'RIGHT',
    'PARÇAAL': 'MID',
    'BUL': 'FIND',
    'MBUL': 'SEARCH',
    'YERİNEKOY': 'SUBSTITUTE',
    'DEĞİŞTİR': 'REPLACE',
    'YİNELE': 'REPT',
    'BİRLEŞTİR': 'CONCATENATE',
    'METİNBİRLEŞTİR': 'TEXTJOIN',
    'ÖZDEŞ': 'EXACT',
    'DAMGA': 'CHAR',
    'KOD': 'CODE',
    'SAYIYAÇEVİR': 'VALUE',
    'METNEÇEVİR': 'TEXT',
    'BUGÜN': 'TODAY',
    'ŞİMDİ': 'NOW',
    'TARİH': 'DATE',
    'ZAMAN': 'TIME',
    'YIL': 'YEAR',
    'AY': 'MONTH',
    'GÜN': 'DAY',
    'SAAT': 'HOUR',
    'DAKİKA': 'MINUTE',
    'SANİYE': 'SECOND',
    'HAFTANINGÜNÜ': 'WEEKDAY',
    'GÜNSAY': 'DAYS',
    'SERİAY': 'EDATE',
    'SERİTARİH': 'EDATE',
    'AYSONU': 'EOMONTH',
    'ETARİHLİ': 'DATEDIF',
    'DÜŞEYARA': 'VLOOKUP',
    'YATAYARA': 'HLOOKUP',
    'İNDİS': 'INDEX',
    'KAÇINCI': 'MATCH',
    'SATIR': 'ROW',
    'SÜTUN': 'COLUMN',
    'SATIRSAY': 'ROWS',
    'SÜTUNSAY': 'COLUMNS',

    // ── Excel 2010+ noktalı adlar (dosyalarda BUNLAR yazılı olur) ──
    'STDEV.S': 'STDEV',
    'STDEV.P': 'STDEVP',
    'STDSAPMA.S': 'STDEV',
    'STDSAPMA.P': 'STDEVP',
    'VAR.S': 'VAR',
    'VAR.P': 'VARP',
    'MODE.SNGL': 'MODE',
    'ENÇOK_OLAN.TEK': 'MODE',
    'PERCENTILE.INC': 'PERCENTILE',
    'YÜZDEBİRLİK.DHL': 'PERCENTILE',
    'QUARTILE.INC': 'QUARTILE',
    'DÖRTTEBİRLİK.DHL': 'QUARTILE',
    'PERCENTRANK.INC': 'PERCENTRANK',
    'YÜZDERANK.DHL': 'PERCENTRANK',
    'RANK.EQ': 'RANK',
    'RANK.AVG': 'RANK',
    'KÜÇÜK': 'SMALL',
    'BÜYÜK': 'LARGE',
    'TAVANAYUVARLA.MATEMATİK': 'CEILING.MATH',
    'TABANAYUVARLA.MATEMATİK': 'FLOOR.MATH',

    // ── başvuru / bilgi ──
    'KAYDIR': 'OFFSET',
    'DOLAYLI': 'INDIRECT',
    'ADRES': 'ADDRESS',
    'ARA': 'LOOKUP',
    'ÇAPRAZARA': 'XLOOKUP',
    'FORMÜLMETNİ': 'FORMULATEXT',
    'EFORMÜLSE': 'ISFORMULA',
    'EREFSE': 'ISREF',
    'ÇİFTMİ': 'ISEVEN',
    'TEKMİ': 'ISODD',
    'EÇİFTSE': 'ISEVEN',
    'ETEKSE': 'ISODD',
    'HATA.TİPİ': 'ERROR.TYPE',
    'EMANTIKSALSA': 'ISLOGICAL',

    // ── istatistik ──
    'ORTALAMAA': 'AVERAGEA',
    'MAKA': 'MAXA',
    'MİNA': 'MINA',
    'GEOORT': 'GEOMEAN',
    'HARORT': 'HARMEAN',
    'ORTSAP': 'AVEDEV',
    'SAPKARETOPL': 'DEVSQ',
    'YÜZDEBİRLİK': 'PERCENTILE',
    'DÖRTTEBİRLİK': 'QUARTILE',
    'YÜZDERANK': 'PERCENTRANK',
    'KOMBİNASYON': 'COMBIN',
    'PERMÜTASYON': 'PERMUT',
    'SİNH': 'SINH',
    'TOPKARE': 'SUMSQ',

    // ── metin ──
    'METİNÖNCE': 'TEXTBEFORE',
    'METİNSONRA': 'TEXTAFTER',
    'SAYIDEĞERİ': 'NUMBERVALUE',
    'SAYIDÜZENLE': 'FIXED',
    'UNICODEKARAKTERİ': 'UNICHAR',

    // ── tarih ──
    'HAFTASAY': 'WEEKNUM',
    'ISOHAFTASAY': 'ISOWEEKNUM',
    'TAMİŞGÜNÜ': 'NETWORKDAYS',
    'İŞGÜNÜ': 'WORKDAY',
    'TARİHSAYISI': 'DATEVALUE',
    'ZAMANSAYISI': 'TIMEVALUE',
    'YILORAN': 'YEARFRAC',

    // ── finans (kredi/taksit) ──
    'DEVRESEL_ÖDEME': 'PMT',
    'BD': 'PV',
    'GD': 'FV',
    'TAKSİT_SAYISI': 'NPER',
    'FAİZ_ORANI': 'RATE',
    'NBD': 'NPV',
    'İÇ_VERİM_ORANI': 'IRR',
    'AİÇVERİMORANI': 'IRR',
    'FAİZTUTARI': 'IPMT',
    'ANA_PARA_ÖDEMESİ': 'PPMT',
    'DA': 'SLN',
  };

  /// Formül otomatik tamamlamanın önerdiği işlev adları.
  ///
  /// Kaynak, motorun KENDİ takma ad tablosu: Türkçe adlar (kullanıcının
  /// yazdığı) ve İngilizce karşılıkları (dosyada duran). Ayrı bir liste
  /// tutmak, motor yeni bir işlev öğrendiğinde listeyi eskitirdi.
  static List<String> get functionNames {
    final out = <String>{..._aliases.keys, ..._aliases.values}.toList()..sort();
    return List.unmodifiable(out);
  }

  /// [prefix] ile başlayan işlev adları (büyük/küçük harf duyarsız, Türkçe
  /// katlamalı — `i` yazan `İ`li adı da bulmalı).
  static List<String> completionsFor(String prefix, {int limit = 8}) {
    final p = _trUpper(prefix);
    if (p.isEmpty) return const [];
    final starts = <String>[];
    final contains = <String>[];
    for (final name in functionNames) {
      if (name.startsWith(p)) {
        starts.add(name);
      } else if (name.contains(p)) {
        contains.add(name);
      }
      if (starts.length >= limit) break;
    }
    // Önce baştan eşleşenler; yer kalırsa içinde geçenler ("ARA" → "DÜŞEYARA").
    return [...starts, ...contains].take(limit).toList(growable: false);
  }
}

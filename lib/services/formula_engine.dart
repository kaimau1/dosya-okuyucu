import 'dart:math' as math;

import '../core/excel_format.dart';

part 'formula/functions.dart';
part 'formula/lookup_stats.dart';
part 'formula/date_finance.dart';
part 'formula/parser.dart';

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

  // ── fonksiyonlar ──────────────────────────────────────────────────────────

  /// Türkçe/İngilizce fonksiyon adını tek biçime indirger.
  static String _canonical(String word) {
    final up = word.toUpperCase();
    return _aliases[up] ?? _aliases[_trUpper(word)] ?? up;
  }

  static bool _isEmptyArgs(List<Object> args) =>
      args.isEmpty ||
      (args.length == 1 && args.first is String && (args.first as String).isEmpty);

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

  // ── başvuru fonksiyonları ────────────────────────────────────────────────

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

  // ── istatistik / metin yardımcıları ──────────────────────────────────────

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

/// Excel sayı biçimi (numFmt) motoru — saf Dart, Flutter bağımsız.
///
/// Excel'in hücre biçim kodlarını (`#,##0.00`, `0%`, `"₺"#,##0.00;[Red]-0.00`,
/// `dd.mm.yyyy hh:mm`, `# ?/?`, `0.00E+00`, `[>=1000]0,"B";0`) ayrıştırır ve bir
/// değere uygular. Amaç: hücre ekranda **Excel'de göründüğü gibi** çıksın.
///
/// Desteklenen:
/// - Bölümler: `pozitif;negatif;sıfır;metin` + `[>=100]` gibi koşullu bölümler.
/// - Renk etiketi: `[Red]` / `[Kırmızı]` / `[Color 3]` → sonuçta ARGB.
/// - Rakam yer tutucuları `0 # ?`, binlik gruplama, `,` ile 1000'e bölme,
///   yüzde (`%` sayısı kadar 100 çarpanı), tırnaklı/kaçışlı düz metin,
///   `_x` (boşluk), `*x` (doldurma — tek boşluk olarak).
/// - Para etiketi `[$₺-41F]`, `[$-tr-TR]`.
/// - Tarih/saat: `yyyy yy mmmm mmm mm m dddd ddd dd d hh h ss s AM/PM .0`
///   ve geçen süre `[h] [mm] [ss]`. Ay adları **Türkçe**.
/// - Kesir (`# ?/?`, `#/8`) ve bilimsel gösterim (`0.00E+00`).
/// - `@` metin yer tutucusu.
///
/// Sayı gösterimi Türkçe: binlik `.`, ondalık `,`.
library;

/// Biçimlenmiş sonuç: metin + (biçimde renk etiketi varsa) ARGB renk.
class ExcelFormatResult {
  final String text;
  final int? colorArgb;
  const ExcelFormatResult(this.text, [this.colorArgb]);

  @override
  String toString() => text;
}

/// Ayrıştırılmış biçim kodu (önbelleklenir — aynı kod bin hücrede kullanılır).
class ExcelNumberFormat {
  final List<_Section> _sections;
  final String code;

  ExcelNumberFormat._(this.code, this._sections);

  static final Map<String, ExcelNumberFormat> _cache = {};

  static ExcelNumberFormat parse(String code) =>
      _cache.putIfAbsent(code, () => ExcelNumberFormat._(code, _split(code)));

  /// Bu biçim bir tarih/saat biçimi mi (ilk sayısal bölüme bakılır)?
  bool get isDate => _sections.any((s) => s.isDate);

  /// Biçim "biçimsiz" mi (General ya da boş kod) — sayıya dokunulmaz.
  /// DİKKAT: `0;-0;"—"` gibi kodlarda sıfır bölümü yalnız düz metinden oluşur;
  /// o bölüm General DEĞİLDİR, metnini yazar.
  bool get isGeneral =>
      _sections.isEmpty ||
      code.trim().isEmpty ||
      (_sections.length == 1 &&
          (_sections.first.isGeneral || _sections.first.tokens.isEmpty));

  /// [value] bir sayı (num) ya da metin (String) olabilir.
  ExcelFormatResult format(Object value, {bool date1904 = false}) {
    if (value is String) {
      final textSection = _textSection();
      if (textSection == null) return ExcelFormatResult(value);
      return ExcelFormatResult(
          textSection.renderText(value), textSection.colorArgb);
    }
    final v = (value as num).toDouble();
    final section = _sectionFor(v);
    if (section == null || section.isGeneral) {
      return ExcelFormatResult(generalNumber(v));
    }
    return ExcelFormatResult(
      section.render(v,
          negateHandled: _negativeSectionUsed(v), date1904: date1904),
      section.colorArgb,
    );
  }

  /// Kolaylık: yalnız metin döndürür.
  String text(Object value, {bool date1904 = false}) =>
      format(value, date1904: date1904).text;

  // ── bölüm seçimi ──────────────────────────────────────────────────────────

  /// Sayısal bölümler (metin bölümü hariç).
  List<_Section> get _numeric =>
      _sections.where((s) => !s.isTextPlaceholder).toList();

  _Section? _textSection() {
    for (final s in _sections) {
      if (s.isTextPlaceholder) return s;
    }
    return null;
  }

  bool _negativeSectionUsed(double v) {
    final n = _numeric;
    if (v >= 0) return false;
    if (n.any((s) => s.condition != null)) {
      // Koşullu bölümlerde işaret bölümün kendi metnindedir.
      return false;
    }
    return n.length >= 2; // ayrı negatif bölüm var → mutlak değer biçimlenir
  }

  _Section? _sectionFor(double v) {
    final n = _numeric;
    if (n.isEmpty) return null;
    final conditional = n.where((s) => s.condition != null).toList();
    if (conditional.isNotEmpty) {
      for (final s in conditional) {
        if (s.condition!.matches(v)) return s;
      }
      // Koşulsuz "diğer" bölümü
      for (final s in n) {
        if (s.condition == null) return s;
      }
      return n.last;
    }
    if (n.length == 1) return n.first;
    if (n.length == 2) return v < 0 ? n[1] : n[0];
    if (v > 0) return n[0];
    if (v < 0) return n[1];
    return n[2];
  }

  // ── kod → bölümler ────────────────────────────────────────────────────────

  /// `;` ile bölümlere ayırır — tırnak içindeki ve kaçışlı `;` bölmez.
  static List<_Section> _split(String code) {
    final parts = <String>[];
    final sb = StringBuffer();
    var inQuote = false;
    var inBracket = false;
    for (var i = 0; i < code.length; i++) {
      final ch = code[i];
      if (ch == '\\' && i + 1 < code.length) {
        sb.write(ch);
        sb.write(code[i + 1]);
        i++;
        continue;
      }
      if (ch == '"') {
        inQuote = !inQuote;
        sb.write(ch);
        continue;
      }
      if (!inQuote && ch == '[') inBracket = true;
      if (!inQuote && ch == ']') inBracket = false;
      if (ch == ';' && !inQuote && !inBracket) {
        parts.add(sb.toString());
        sb.clear();
        continue;
      }
      sb.write(ch);
    }
    parts.add(sb.toString());
    return [for (final p in parts) _Section.compile(p)];
  }
}

// ─────────────────────────────────────────────────────────── koşul

class _Cond {
  final String op;
  final double value;
  const _Cond(this.op, this.value);

  bool matches(double v) => switch (op) {
        '<' => v < value,
        '<=' => v <= value,
        '>' => v > value,
        '>=' => v >= value,
        '=' => v == value,
        '<>' => v != value,
        _ => false,
      };
}

// ─────────────────────────────────────────────────────────── token

enum _TokKind {
  literal,
  intDigit, // 0 # ?  (ondalık noktadan önce)
  decDigit, // 0 # ?  (ondalık noktadan sonra)
  decimalPoint,
  groupComma,
  percent,
  expDigit, // üs kısmı rakamı
  expMark, // E+ / E-
  fracSlash,
  numDigit, // kesir payı
  denDigit, // kesir paydası
  date,
  elapsed,
  at, // @
  general,
}

class _Tok {
  final _TokKind kind;
  final String text;
  const _Tok(this.kind, this.text);
}

// ─────────────────────────────────────────────────────────── bölüm

class _Section {
  final List<_Tok> tokens;
  final int? colorArgb;
  final _Cond? condition;
  final bool isDate;
  final bool isGeneral;
  final bool isTextPlaceholder;
  final int percentCount;
  final int scaleCommas; // sondaki her `,` → 1000'e böl
  final bool grouping;
  final bool hasFraction;
  final bool hasExponent;

  _Section({
    required this.tokens,
    required this.colorArgb,
    required this.condition,
    required this.isDate,
    required this.isGeneral,
    required this.isTextPlaceholder,
    required this.percentCount,
    required this.scaleCommas,
    required this.grouping,
    required this.hasFraction,
    required this.hasExponent,
  });

  // ── derleme ───────────────────────────────────────────────────────────────

  static _Section compile(String src) {
    final tokens = <_Tok>[];
    int? color;
    _Cond? cond;
    var percent = 0;
    var grouping = false;
    var scale = 0;
    var seenDecimal = false;
    var seenSlash = false;
    var seenExp = false;
    var sawDate = false;
    var sawAt = false;
    var sawGeneral = false;
    var sawDigit = false;

    var i = 0;
    while (i < src.length) {
      final ch = src[i];

      // kaçış
      if (ch == '\\' && i + 1 < src.length) {
        tokens.add(_Tok(_TokKind.literal, src[i + 1]));
        i += 2;
        continue;
      }
      // tırnaklı düz metin
      if (ch == '"') {
        final end = src.indexOf('"', i + 1);
        if (end == -1) {
          tokens.add(_Tok(_TokKind.literal, src.substring(i + 1)));
          break;
        }
        tokens.add(_Tok(_TokKind.literal, src.substring(i + 1, end)));
        i = end + 1;
        continue;
      }
      // _x → x genişliğinde boşluk (biz tek boşluk yazarız)
      if (ch == '_') {
        tokens.add(const _Tok(_TokKind.literal, ' '));
        i += 2;
        continue;
      }
      // *x → doldurma karakteri; hücre genişliği bilinmediği için tek boşluk
      if (ch == '*') {
        tokens.add(const _Tok(_TokKind.literal, ' '));
        i += 2;
        continue;
      }
      // köşeli parantez: renk / koşul / para / geçen süre
      if (ch == '[') {
        final end = src.indexOf(']', i + 1);
        if (end == -1) {
          i++;
          continue;
        }
        final inner = src.substring(i + 1, end);
        final handled = _bracket(inner, tokens);
        if (handled.color != null) color = handled.color;
        if (handled.cond != null) cond = handled.cond;
        if (handled.elapsed) sawDate = true;
        i = end + 1;
        continue;
      }
      // rakam yer tutucuları
      if (ch == '0' || ch == '#' || ch == '?') {
        sawDigit = true;
        if (seenExp) {
          tokens.add(_Tok(_TokKind.expDigit, ch));
        } else if (seenSlash) {
          tokens.add(_Tok(_TokKind.denDigit, ch));
        } else if (seenDecimal) {
          tokens.add(_Tok(_TokKind.decDigit, ch));
        } else {
          tokens.add(_Tok(_TokKind.intDigit, ch));
        }
        i++;
        continue;
      }
      if (ch == '.') {
        seenDecimal = true;
        tokens.add(const _Tok(_TokKind.decimalPoint, '.'));
        i++;
        continue;
      }
      if (ch == ',') {
        // Rakamlar arasındaysa gruplama; sonda/ondalıktan önce ise ölçekleme.
        final next = i + 1 < src.length ? src[i + 1] : '';
        final prevIsDigit = tokens.isNotEmpty &&
            (tokens.last.kind == _TokKind.intDigit ||
                tokens.last.kind == _TokKind.groupComma);
        final nextIsDigit = next == '0' || next == '#' || next == '?';
        if (prevIsDigit && nextIsDigit) {
          grouping = true;
          tokens.add(const _Tok(_TokKind.groupComma, ','));
        } else if (prevIsDigit) {
          scale++;
        } else {
          tokens.add(const _Tok(_TokKind.literal, ','));
        }
        i++;
        continue;
      }
      if (ch == '%') {
        percent++;
        tokens.add(const _Tok(_TokKind.percent, '%'));
        i++;
        continue;
      }
      if ((ch == 'E' || ch == 'e') &&
          i + 1 < src.length &&
          (src[i + 1] == '+' || src[i + 1] == '-')) {
        seenExp = true;
        tokens.add(_Tok(_TokKind.expMark, src.substring(i, i + 2)));
        i += 2;
        continue;
      }
      if (ch == '/' && sawDigit && !seenDecimal) {
        // kesir çizgisi: `# ?/?`
        seenSlash = true;
        // Şu ana dek yazılan int rakamlarını pay yap (boşluktan sonrakiler).
        _convertTrailingIntToNumerator(tokens);
        tokens.add(const _Tok(_TokKind.fracSlash, '/'));
        i++;
        continue;
      }
      if (ch == '@') {
        sawAt = true;
        tokens.add(const _Tok(_TokKind.at, '@'));
        i++;
        continue;
      }
      // General
      if (src.length - i >= 7 &&
          src.substring(i, i + 7).toLowerCase() == 'general') {
        sawGeneral = true;
        tokens.add(const _Tok(_TokKind.general, 'General'));
        i += 7;
        continue;
      }
      // tarih/saat harfleri
      final dateTok = _dateToken(src, i);
      if (dateTok != null) {
        sawDate = true;
        tokens.add(_Tok(_TokKind.date, dateTok));
        i += dateTok.length;
        continue;
      }
      tokens.add(_Tok(_TokKind.literal, ch));
      i++;
    }

    // Tarih biçimlerinde rakam yer tutucusu (0/#/?) BULUNMAZ — tek istisna
    // saniye kesridir (`mm:ss.0`, o da ondalık kısımdadır). Bu ayrım sayesinde
    // `#,##0 adet` gibi içinde tarih harfi geçen SAYI biçimleri tarih sanılmaz.
    final hasIntDigit = tokens.any((t) => t.kind == _TokKind.intDigit);
    return _Section(
      tokens: tokens,
      colorArgb: color,
      condition: cond,
      isDate: sawDate && !seenExp && !hasIntDigit,
      // Yalnız `General` yazan bölüm biçimsizdir; düz metin taşıyan bölüm
      // (ör. sıfır için `"—"`) o metni yazar.
      isGeneral: sawGeneral,
      isTextPlaceholder: sawAt && !sawDigit && !sawDate,
      percentCount: percent,
      scaleCommas: scale,
      grouping: grouping,
      hasFraction: seenSlash,
      hasExponent: seenExp,
    );
  }

  /// `# ?/?` derlenirken, `/`den önceki son rakam öbeği paydır.
  static void _convertTrailingIntToNumerator(List<_Tok> tokens) {
    for (var k = tokens.length - 1; k >= 0; k--) {
      if (tokens[k].kind == _TokKind.intDigit) {
        tokens[k] = _Tok(_TokKind.numDigit, tokens[k].text);
      } else {
        break;
      }
    }
  }

  static ({int? color, _Cond? cond, bool elapsed}) _bracket(
      String inner, List<_Tok> tokens) {
    final lower = inner.toLowerCase().trim();
    final color = _colorFor(lower);
    if (color != null) return (color: color, cond: null, elapsed: false);

    // Koşul: [>=100] [<0] [=5]
    final cm = RegExp(r'^(<=|>=|<>|<|>|=)\s*(-?[0-9.]+)$').firstMatch(lower);
    if (cm != null) {
      final v = double.tryParse(cm.group(2)!);
      if (v != null) {
        return (color: null, cond: _Cond(cm.group(1)!, v), elapsed: false);
      }
    }
    // Para/yerel: [$₺-41F], [$-41F], [$USD]
    if (inner.startsWith(r'$')) {
      final body = inner.substring(1);
      final dash = body.indexOf('-');
      final symbol = dash >= 0 ? body.substring(0, dash) : body;
      if (symbol.isNotEmpty) {
        tokens.add(_Tok(_TokKind.literal, symbol));
      }
      return (color: null, cond: null, elapsed: false);
    }
    // Geçen süre: [h] [mm] [ss]
    if (RegExp(r'^h+$|^m+$|^s+$').hasMatch(lower)) {
      tokens.add(_Tok(_TokKind.elapsed, lower));
      return (color: null, cond: null, elapsed: true);
    }
    return (color: null, cond: null, elapsed: false);
  }

  static int? _colorFor(String name) => switch (name) {
        'black' || 'siyah' => 0xFF000000,
        'red' || 'kırmızı' || 'kirmizi' => 0xFFFF0000,
        'blue' || 'mavi' => 0xFF0000FF,
        'green' || 'yeşil' || 'yesil' => 0xFF008000,
        'cyan' || 'camgöbeği' => 0xFF00FFFF,
        'magenta' || 'eflatun' => 0xFFFF00FF,
        'yellow' || 'sarı' || 'sari' => 0xFFFFFF00,
        'white' || 'beyaz' => 0xFFFFFFFF,
        _ => _indexedColor(name),
      };

  /// `[Color 3]` / `[Renk 3]` — Excel'in klasik 56 renkli paletinin ilk 8'i.
  static int? _indexedColor(String name) {
    final m = RegExp(r'^(?:color|renk)\s*(\d+)$').firstMatch(name);
    if (m == null) return null;
    const palette = [
      0xFF000000,
      0xFFFFFFFF,
      0xFFFF0000,
      0xFF00FF00,
      0xFF0000FF,
      0xFFFFFF00,
      0xFFFF00FF,
      0xFF00FFFF,
    ];
    final idx = int.tryParse(m.group(1)!) ?? 0;
    if (idx < 1 || idx > palette.length) return null;
    return palette[idx - 1];
  }

  /// Konumdaki tarih/saat belirtecini döndürür (yoksa null).
  static String? _dateToken(String src, int i) {
    final rest = src.substring(i);
    const patterns = [
      'yyyy', 'yyy', 'yy', 'y', //
      'mmmmm', 'mmmm', 'mmm', 'mm', 'm', //
      'dddd', 'ddd', 'dd', 'd', //
      'hh', 'h', 'ss', 's', //
      'AM/PM', 'am/pm', 'A/P', 'a/p', //
      '.000', '.00', '.0',
    ];
    for (final p in patterns) {
      if (rest.length >= p.length) {
        final head = rest.substring(0, p.length);
        if (p.startsWith('A') || p.startsWith('a')) {
          if (head.toUpperCase() == p.toUpperCase()) return head;
        } else if (head.toLowerCase() == p) {
          return head;
        }
      }
    }
    return null;
  }

  // ── uygulama ──────────────────────────────────────────────────────────────

  String renderText(String value) {
    final sb = StringBuffer();
    for (final t in tokens) {
      if (t.kind == _TokKind.at) {
        sb.write(value);
      } else if (t.kind == _TokKind.literal) {
        sb.write(t.text);
      }
    }
    return sb.toString();
  }

  String render(double value,
      {bool negateHandled = false, bool date1904 = false}) {
    if (isDate) return _renderDate(value, date1904);
    var v = value;
    if (negateHandled) v = v.abs();
    for (var i = 0; i < percentCount; i++) {
      v *= 100;
    }
    for (var i = 0; i < scaleCommas; i++) {
      v /= 1000;
    }
    if (hasExponent) return _renderScientific(v);
    if (hasFraction) return _renderFraction(v);
    return _renderNumber(v);
  }

  // ── sayı ──────────────────────────────────────────────────────────────────

  String _renderNumber(double v) {
    final intSlots = <int>[]; // token indeksleri
    final decSlots = <int>[];
    for (var i = 0; i < tokens.length; i++) {
      if (tokens[i].kind == _TokKind.intDigit) intSlots.add(i);
      if (tokens[i].kind == _TokKind.decDigit) decSlots.add(i);
    }
    final minInt = tokens
        .where((t) => t.kind == _TokKind.intDigit && t.text == '0')
        .length;
    final maxDec = decSlots.length;
    final minDec = decSlots
        .where((i) => tokens[i].text == '0')
        .length;

    final negative = v < 0;
    final abs = v.abs();
    var fixed = abs.toStringAsFixed(maxDec.clamp(0, 20));
    // toStringAsFixed yuvarlama sonrası taşma (9,99 → 10,0) doğal olarak gelir.
    var intPart = fixed;
    var decPart = '';
    final dot = fixed.indexOf('.');
    if (dot >= 0) {
      intPart = fixed.substring(0, dot);
      decPart = fixed.substring(dot + 1);
    }
    // Ondalıkta gereksiz sondaki sıfırları at (`#` yer tutucuları için).
    while (decPart.length > minDec && decPart.endsWith('0')) {
      decPart = decPart.substring(0, decPart.length - 1);
    }
    // Tam sayı kısmını en az minInt basamağa tamamla; minInt 0 ve değer 0 ise
    // Excel gibi tam sayı kısmı boş kalır (`#.##` → ",5").
    intPart = intPart.replaceFirst(RegExp(r'^0+(?=\d)'), '');
    if (intPart == '0' && minInt == 0 && intSlots.isNotEmpty) intPart = '';
    while (intPart.length < minInt) {
      intPart = '0$intPart';
    }
    if (grouping) intPart = _group(intPart);

    final out = StringBuffer();
    if (negative) out.write('-');
    final intText = _placeInt(intPart, intSlots);
    var decIndex = 0;
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t.kind) {
        case _TokKind.literal:
          out.write(t.text);
        case _TokKind.percent:
          out.write('%');
        case _TokKind.groupComma:
          break; // gruplama zaten intPart içinde
        case _TokKind.intDigit:
          out.write(intText[i] ?? '');
        case _TokKind.decimalPoint:
          if (decPart.isNotEmpty) out.write(',');
        case _TokKind.decDigit:
          if (decIndex < decPart.length) {
            out.write(decPart[decIndex]);
          } else if (t.text == '?') {
            out.write(' ');
          }
          decIndex++;
        case _TokKind.general:
          out.write(generalNumber(v));
        default:
          break;
      }
    }
    var s = out.toString();
    // Yüzde işareti Türkçe'de sayının ÖNÜNDE yazılır (%15) — Excel Türkçe de
    // böyle gösterir. Biçim sonunda `%` varsa başa alınır.
    if (percentCount > 0 && s.endsWith('%')) {
      s = '%${s.substring(0, s.length - 1)}';
      if (s.startsWith('%-')) s = '-%${s.substring(2)}';
    }
    return s;
  }

  /// Rakam dizesini yer tutucu yuvalarına SAĞDAN sola yerleştirir; en soldaki
  /// yuva artan kısmın tamamını alır (`000-0000` gibi araya metin giren
  /// biçimler doğru çıksın diye).
  static Map<int, String> _placeInt(String digits, List<int> slots) {
    final out = <int, String>{};
    if (slots.isEmpty) return out;
    if (digits.isEmpty) {
      for (final s in slots) {
        out[s] = '';
      }
      return out;
    }
    var d = digits.length - 1;
    for (var k = slots.length - 1; k >= 1; k--) {
      if (d >= 0) {
        out[slots[k]] = digits[d];
        d--;
      } else {
        out[slots[k]] = '';
      }
    }
    out[slots.first] = d >= 0 ? digits.substring(0, d + 1) : '';
    return out;
  }

  static String _group(String intDigits) {
    if (intDigits.length <= 3) return intDigits;
    final sb = StringBuffer();
    for (var i = 0; i < intDigits.length; i++) {
      if (i > 0 && (intDigits.length - i) % 3 == 0) sb.write('.');
      sb.write(intDigits[i]);
    }
    return sb.toString();
  }

  // ── bilimsel ──────────────────────────────────────────────────────────────

  String _renderScientific(double v) {
    final decSlots =
        tokens.where((t) => t.kind == _TokKind.decDigit).length;
    final expSlots =
        tokens.where((t) => t.kind == _TokKind.expDigit).length;
    final mark = tokens.firstWhere((t) => t.kind == _TokKind.expMark,
        orElse: () => const _Tok(_TokKind.expMark, 'E+'));
    if (v == 0) {
      final mant = (0.0).toStringAsFixed(decSlots).replaceAll('.', ',');
      return '${mant}E+${'0' * (expSlots == 0 ? 2 : expSlots)}';
    }
    var exp = 0;
    var m = v.abs();
    while (m >= 10) {
      m /= 10;
      exp++;
    }
    while (m < 1) {
      m *= 10;
      exp--;
    }
    var mant = m.toStringAsFixed(decSlots);
    if (double.parse(mant) >= 10) {
      mant = (double.parse(mant) / 10).toStringAsFixed(decSlots);
      exp++;
    }
    final sign = exp < 0 ? '-' : (mark.text.endsWith('+') ? '+' : '');
    final expText = exp.abs().toString().padLeft(expSlots == 0 ? 2 : expSlots, '0');
    return '${v < 0 ? '-' : ''}${mant.replaceAll('.', ',')}E$sign$expText';
  }

  // ── kesir ─────────────────────────────────────────────────────────────────

  String _renderFraction(double v) {
    final intSlots = tokens.where((t) => t.kind == _TokKind.intDigit).length;
    final denTokens =
        tokens.where((t) => t.kind == _TokKind.denDigit).toList();
    final fixedDen = _fixedDenominator();
    final maxDen = fixedDen ??
        (denTokens.isEmpty ? 9 : _pow10(denTokens.length) - 1);

    final negative = v < 0;
    var abs = v.abs();
    var whole = 0;
    if (intSlots > 0) {
      whole = abs.floor();
      abs -= whole;
    }
    var bestN = 0, bestD = 1;
    if (fixedDen != null) {
      bestD = fixedDen;
      bestN = (abs * fixedDen).round();
    } else {
      var bestErr = double.infinity;
      for (var d = 1; d <= maxDen; d++) {
        final n = (abs * d).round();
        final err = (abs - n / d).abs();
        if (err < bestErr - 1e-12) {
          bestErr = err;
          bestN = n;
          bestD = d;
          if (err < 1e-12) break;
        }
      }
    }
    if (bestN == bestD && bestD != 0) {
      whole += 1;
      bestN = 0;
    }
    final sb = StringBuffer();
    if (negative) sb.write('-');
    if (intSlots > 0) {
      sb.write(whole == 0 && bestN != 0 ? '' : '$whole');
      if (bestN != 0) sb.write(whole == 0 ? '' : ' ');
    }
    if (bestN != 0) {
      sb.write('$bestN/$bestD');
    } else if (intSlots == 0) {
      sb.write('0/$bestD');
    }
    final s = sb.toString();
    return s.isEmpty ? '0' : s;
  }

  /// `#/8` gibi sabit paydayı okur (paydası düz rakam literalleriyse).
  int? _fixedDenominator() {
    var after = false;
    final sb = StringBuffer();
    for (final t in tokens) {
      if (t.kind == _TokKind.fracSlash) {
        after = true;
        continue;
      }
      if (!after) continue;
      if (t.kind == _TokKind.literal &&
          t.text.length == 1 &&
          _isDigitChar(t.text)) {
        sb.write(t.text);
      }
    }
    return sb.isEmpty ? null : int.tryParse(sb.toString());
  }

  static int _pow10(int n) {
    var v = 1;
    for (var i = 0; i < n; i++) {
      v *= 10;
    }
    return v;
  }

  static bool _isDigitChar(String c) =>
      c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57;

  // ── tarih / saat ──────────────────────────────────────────────────────────

  String _renderDate(double serial, bool date1904) {
    final dt = excelSerialToDate(serial, date1904: date1904);
    final has12h = tokens.any((t) =>
        t.kind == _TokKind.date && t.text.toUpperCase().startsWith('A'));
    // `mm:ss.0` gibi biçimlerde noktadan sonraki rakamlar SANİYE KESRİdir;
    // `dd.mm.yyyy`de ise nokta düz ayıraçtır (ondalık virgülüne çevrilmemeli —
    // yoksa tarih "01,01,2024" çıkar).
    final fractionDigits =
        tokens.where((t) => t.kind == _TokKind.decDigit).length;
    var fracIndex = 0;
    final fracText = fractionDigits == 0
        ? ''
        : ((serial * 86400) - (serial * 86400).floorToDouble())
            .toStringAsFixed(fractionDigits)
            .substring(2);

    final out = StringBuffer();
    for (var i = 0; i < tokens.length; i++) {
      final t = tokens[i];
      switch (t.kind) {
        case _TokKind.literal:
          out.write(t.text);
        case _TokKind.elapsed:
          out.write(_elapsed(serial, t.text));
        case _TokKind.date:
          out.write(_dateField(dt, t.text, i, has12h, serial));
        case _TokKind.decimalPoint:
          out.write(fractionDigits > 0 ? ',' : '.');
        case _TokKind.decDigit:
          if (fracIndex < fracText.length) out.write(fracText[fracIndex]);
          fracIndex++;
        default:
          break;
      }
    }
    return out.toString();
  }

  String _elapsed(double serial, String tok) {
    final totalSeconds = (serial * 86400).round();
    if (tok.startsWith('h')) {
      return (totalSeconds ~/ 3600).toString().padLeft(tok.length, '0');
    }
    if (tok.startsWith('m')) {
      return (totalSeconds ~/ 60).toString().padLeft(tok.length, '0');
    }
    return totalSeconds.toString().padLeft(tok.length, '0');
  }

  /// `m` hem AY hem DAKİKA olabilir: saat belirtecinden hemen sonra ya da
  /// saniye belirtecinden hemen önce geliyorsa DAKİKA'dır (Excel kuralı).
  bool _isMinute(int index) {
    for (var k = index - 1; k >= 0; k--) {
      final t = tokens[k];
      if (t.kind == _TokKind.literal) continue;
      // `[h]:mm` — geçen süre saatinden sonra gelen m DAKİKA'dır.
      if (t.kind == _TokKind.elapsed) return true;
      if (t.kind == _TokKind.date) {
        final s = t.text.toLowerCase();
        if (s.startsWith('h')) return true;
        if (s.startsWith('s')) return true;
      }
      break;
    }
    for (var k = index + 1; k < tokens.length; k++) {
      final t = tokens[k];
      if (t.kind == _TokKind.literal) continue;
      if (t.kind == _TokKind.date && t.text.toLowerCase().startsWith('s')) {
        return true;
      }
      break;
    }
    return false;
  }

  String _dateField(
      DateTime dt, String tok, int index, bool has12h, double serial) {
    final lower = tok.toLowerCase();
    switch (lower) {
      case 'yyyy':
      case 'yyy':
        return dt.year.toString().padLeft(4, '0');
      case 'yy':
      case 'y':
        return (dt.year % 100).toString().padLeft(2, '0');
      case 'mmmmm':
        return trMonths[dt.month - 1].substring(0, 1);
      case 'mmmm':
        return trMonths[dt.month - 1];
      case 'mmm':
        return trMonthsShort[dt.month - 1];
      case 'mm':
        return _isMinute(index)
            ? dt.minute.toString().padLeft(2, '0')
            : dt.month.toString().padLeft(2, '0');
      case 'm':
        return _isMinute(index) ? '${dt.minute}' : '${dt.month}';
      case 'dddd':
        return trDays[dt.weekday % 7];
      case 'ddd':
        return trDaysShort[dt.weekday % 7];
      case 'dd':
        return dt.day.toString().padLeft(2, '0');
      case 'd':
        return '${dt.day}';
      case 'hh':
        return _hour(dt, has12h).toString().padLeft(2, '0');
      case 'h':
        return '${_hour(dt, has12h)}';
      case 'ss':
        return dt.second.toString().padLeft(2, '0');
      case 's':
        return '${dt.second}';
      case '.0':
      case '.00':
      case '.000':
        final frac = (serial * 86400) - (serial * 86400).floor();
        final digits = lower.length - 1;
        return ',${(frac * _pow10(digits)).round().toString().padLeft(digits, '0')}';
      default:
        if (lower == 'am/pm' || lower == 'a/p') {
          final pm = dt.hour >= 12;
          if (lower == 'a/p') return pm ? 'Ö' : 'Ö'; // ÖÖ/ÖS kısaltması
          return pm ? 'ÖS' : 'ÖÖ';
        }
        return tok;
    }
  }

  static int _hour(DateTime dt, bool has12h) {
    if (!has12h) return dt.hour;
    final h = dt.hour % 12;
    return h == 0 ? 12 : h;
  }
}

// ─────────────────────────────────────────────────────────── yardımcılar

const List<String> trMonths = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];

const List<String> trMonthsShort = [
  'Oca',
  'Şub',
  'Mar',
  'Nis',
  'May',
  'Haz',
  'Tem',
  'Ağu',
  'Eyl',
  'Eki',
  'Kas',
  'Ara',
];

/// 0 = Pazar (Excel/`weekday % 7` sırası).
const List<String> trDays = [
  'Pazar',
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
];

const List<String> trDaysShort = [
  'Paz',
  'Pzt',
  'Sal',
  'Çar',
  'Per',
  'Cum',
  'Cmt',
];

/// Excel seri numarasını tarihe çevirir.
///
/// Excel'in 1900 sistemi 1900'ü yanlışlıkla artık yıl sayar; 60'tan küçük
/// seriler bu yüzden bir gün kaydırılır (Excel'le birebir aynı gün çıksın).
DateTime excelSerialToDate(double serial, {bool date1904 = false}) {
  if (date1904) {
    return DateTime.utc(1904, 1, 1)
        .add(Duration(milliseconds: (serial * 86400000).round()));
  }
  var s = serial;
  if (s < 60) s += 1;
  return DateTime.utc(1899, 12, 30)
      .add(Duration(milliseconds: (s * 86400000).round()));
}

/// Tarihi Excel seri numarasına çevirir (formül motoru için).
double dateToExcelSerial(DateTime dt) {
  final base = DateTime.utc(1899, 12, 30);
  final utc = DateTime.utc(dt.year, dt.month, dt.day, dt.hour, dt.minute,
      dt.second, dt.millisecond);
  var days = utc.difference(base).inMilliseconds / 86400000.0;
  if (days < 61) days -= 1;
  return days;
}

/// Biçimsiz (`General`) sayı gösterimi — Excel gibi gereksiz sıfır yazmaz,
/// ondalık ayıracı Türkçe virgüldür.
String generalNumber(double v) {
  if (v.isNaN || v.isInfinite) return '#SAYI!';
  if (v == v.roundToDouble() && v.abs() < 1e15) {
    return v.toStringAsFixed(0);
  }
  // 11 anlamlı basamak (Excel varsayılan sütun genişliğinde gösterdiği kadar)
  var s = v.toStringAsPrecision(11);
  if (s.contains('e')) {
    s = v.toString();
  } else if (s.contains('.')) {
    s = s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
  }
  return s.replaceAll('.', ',');
}

/// Yerleşik Excel sayı biçimleri (numFmtId → kod). Tarih/saat dahil TAMAMI —
/// artık tarihleri de biz biçimliyoruz.
const Map<int, String> builtinNumberFormats = {
  0: 'General',
  1: '0',
  2: '0.00',
  3: '#,##0',
  4: '#,##0.00',
  5: r'"₺"#,##0_);("₺"#,##0)',
  6: r'"₺"#,##0_);[Red]("₺"#,##0)',
  7: r'"₺"#,##0.00_);("₺"#,##0.00)',
  8: r'"₺"#,##0.00_);[Red]("₺"#,##0.00)',
  9: '0%',
  10: '0.00%',
  11: '0.00E+00',
  12: '# ?/?',
  13: '# ??/??',
  14: 'dd.mm.yyyy',
  15: 'd-mmm-yy',
  16: 'd-mmm',
  17: 'mmm-yy',
  18: 'h:mm AM/PM',
  19: 'h:mm:ss AM/PM',
  20: 'h:mm',
  21: 'h:mm:ss',
  22: 'dd.mm.yyyy h:mm',
  37: '#,##0;(#,##0)',
  38: '#,##0;[Red](#,##0)',
  39: '#,##0.00;(#,##0.00)',
  40: '#,##0.00;[Red](#,##0.00)',
  44: r'_("₺"* #,##0.00_);_("₺"* \(#,##0.00\);_("₺"* "-"??_);_(@_)',
  45: 'mm:ss',
  46: '[h]:mm:ss',
  47: 'mm:ss.0',
  48: '##0.0E+0',
  49: '@',
};

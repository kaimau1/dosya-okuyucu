part of '../formula_engine.dart';

/// Formül metnini **dosya biçimine** çevirir (Faz 20 / X1, 2026-10-23).
///
/// KÖK NEDEN: motor `TOPLA(A1;A2)`'yi hesaplıyor, otomatik tamamlama Türkçe
/// adları öneriyordu; yazıcı ise formülü olduğu gibi `<f>` içine koyuyordu.
/// OOXML'de formül HER ZAMAN İngilizce ad + `,` ayırıcı + `.` ondalıkla
/// saklanır — masaüstü Excel / Google E-Tablolar Türkçe adı `#AD?` gösterir,
/// dosya bozulmuş gibi görünür.
///
/// Kurallar: yalnız `(` ile devam eden ad işlev adıdır (hücre başvurusu `A1`,
/// sayfa adı `Sayfa1!` dokunulmaz); çift tırnak içi metin, tek tırnaklı sayfa
/// adı ve `[...]` tablo başvurusu olduğu gibi kopyalanır; `;` → `,`; formülde
/// `;` varsa (Türkçe yazım) rakam arasındaki `,` ondalıktır → `.`.
/// Excel 2010+ işlevleri dosyada `_xlfn.` önekiyle durur.
extension _FormulaLocalePart on _Parser {
  /// [turkish]: formül Türkçe yazımla girildi (arayüz Türkçe) — o zaman
  /// tırnak dışındaki HER `,` ondalıktır (ayırıcı `;`).
  static String toFile(String formula, {bool turkish = false}) {
    final s = formula;
    final tr = turkish || _hasTopSemicolon(s);
    final params = _lambdaParams(s, tr ? ';' : ',');
    final out = StringBuffer();
    var i = 0;
    var inArray = false;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        final end = _quotedEnd(s, i, ch);
        out.write(s.substring(i, end));
        i = end;
        continue;
      }
      if (ch == '[') {
        final end = s.indexOf(']', i);
        final stop = end < 0 ? s.length : end + 1;
        out.write(s.substring(i, stop));
        i = stop;
        continue;
      }
      // Dizi sabitinde `;` satır ayırıcıdır, dosyada da `;` kalır; Türkçe
      // sütun ayırıcı `\` dosyada `,` olur (`{1\2;3\4}` → `{1,2;3,4}`).
      if (ch == '{') inArray = true;
      if (ch == '}') inArray = false;
      if (inArray && (ch == ';' || ch == r'\')) {
        out.write(ch == ';' ? ';' : ',');
        i++;
        continue;
      }
      if (ch == ';') {
        out.write(',');
        i++;
        continue;
      }
      if (ch == ',' &&
          tr &&
          (turkish ||
              (i > 0 &&
                  i + 1 < s.length &&
                  _Parser._isDigit(s[i - 1]) &&
                  _Parser._isDigit(s[i + 1])))) {
        out.write('.');
        i++;
        continue;
      }
      if (_Parser._isAlpha(ch) || ch == '_') {
        // Önceki karakter harf/rakam/$ ise bu bir adın ortasıdır (A1, $B$2).
        var j = i;
        while (j < s.length &&
            (_Parser._isAlpha(s[j]) ||
                _Parser._isDigit(s[j]) ||
                s[j] == '_' ||
                s[j] == '.' ||
                s[j] == r'$')) {
          j++;
        }
        final word = s.substring(i, j);
        final next = j < s.length ? s[j] : '';
        final bare = _stripPrefix(word);
        if (params.isNotEmpty &&
            next != '!' &&
            next != ':' &&
            (i == 0 || (s[i - 1] != ':' && s[i - 1] != '!')) &&
            params.contains(_Parser._trUpper(bare)) &&
            (next != '(' || !_isFunctionName(bare))) {
          // LAMBDA/LET parametresi: dosyada `_xlpm.` önekli (Excel öneksizi
          // tanımsız ad sayar, `#AD?`). Bildirimde ve kullanımda aynı.
          out.write('_xlpm.$bare');
        } else if (next == '(') {
          out.write(_fileName(word));
        } else if (next != '!' && !word.contains(r'$')) {
          final up = _Parser._trUpper(word);
          if (up == 'DOĞRU') {
            out.write('TRUE');
          } else if (up == 'YANLIŞ') {
            out.write('FALSE');
          } else {
            out.write(word);
          }
        } else {
          out.write(word);
        }
        i = j;
        continue;
      }
      out.write(ch);
      i++;
    }
    return out.toString();
  }

  /// Dosyadaki işlev adı: Türkçe → İngilizce, yeni işlevlere `_xlfn.`.
  static String _fileName(String word) {
    final bare = _stripPrefix(word);
    final up = bare.toUpperCase();
    final trUp = _Parser._trUpper(bare);
    String name;
    if (_englishNames.contains(up)) {
      name = up;
    } else if (_Parser._aliases.containsKey(trUp)) {
      name = _Parser._aliases[trUp]!;
    } else if (_Parser._aliases.containsKey(up)) {
      name = _Parser._aliases[up]!;
    } else if (_Parser._englishValues.contains(up)) {
      // Zaten İngilizce (kanonik) yazılmış ad: `_xlfn.` öneki yine eklenir.
      name = up;
    } else if (trUp == 'DOĞRU') {
      name = 'TRUE';
    } else if (trUp == 'YANLIŞ') {
      name = 'FALSE';
    } else {
      // Tanınmayan ad (kullanıcının özel işlevi / eklenti) olduğu gibi kalır.
      return word;
    }
    // FILTER/SORT Excel'de `_xlfn._xlws.` önekiyle saklanır.
    if (name == 'FILTER' || name == 'SORT') return '_xlfn._xlws.$name';
    return _xlfn.contains(name) ? '_xlfn.$name' : name;
  }

  /// Formüldeki LET/LAMBDA parametre adları (büyük harf): LET'te son
  /// bağımsız değişken dışındaki çift sıralılar (0, 2, 4…), LAMBDA'da sonuncu
  /// dışındakiler. İç içe çağrılar da taranır. Kapsam yaklaşık: ad formülün
  /// her yerinde parametre sayılır (Excel parametreyle aynı adlı tanımlı adı
  /// formül içinde zaten gölgeler).
  static Set<String> _lambdaParams(String s, String sep) {
    final up = s.toUpperCase();
    if (!up.contains('LAMBDA') && !up.contains('LET')) return const {};
    final out = <String>{};
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        i = _quotedEnd(s, i, ch);
        continue;
      }
      if (_Parser._isAlpha(ch) || ch == '_') {
        var j = i;
        while (j < s.length &&
            (_Parser._isAlpha(s[j]) ||
                _Parser._isDigit(s[j]) ||
                s[j] == '_' ||
                s[j] == '.' ||
                s[j] == r'$')) {
          j++;
        }
        if (j < s.length && s[j] == '(') {
          final name = _Parser._canonical(s.substring(i, j));
          if (name == 'LET' || name == 'LAMBDA') {
            final args = _topArgs(s, j, sep);
            final last = args.length - 1;
            for (var k = 0; k < last; k++) {
              if (name == 'LET' && k.isOdd) continue;
              final a = _stripPrefix(args[k].trim());
              if (_paramName.hasMatch(a) && !_cellLike.hasMatch(a)) {
                out.add(_Parser._trUpper(a));
              }
            }
          }
        }
        i = j;
        continue;
      }
      i++;
    }
    return out;
  }

  static final _paramName =
      RegExp(r'^[A-Za-z_\u00C0-\uFFFF][A-Za-z0-9_.\u00C0-\uFFFF]*$');

  static final _cellLike = RegExp(r'^\$?[A-Za-z]{1,3}\$?\d+$');

  /// Motorun bildiği işlev adı mı (parametreyle aynı adlı işlev çağrısı
  /// önek almaz).
  static bool _isFunctionName(String bare) {
    final up = bare.toUpperCase();
    return _englishNames.contains(up) ||
        _Parser._aliases.containsKey(_Parser._trUpper(bare)) ||
        _Parser._aliases.containsKey(up) ||
        _Parser._englishValues.contains(up);
  }

  /// `(` [open] konumundaki çağrının üst düzey bağımsız değişkenleri
  /// (ayırıcı [sep]; tırnak, `{…}` ve iç parantez atlanır).
  static List<String> _topArgs(String s, int open, String sep) {
    final args = <String>[];
    var depth = 0;
    var start = open + 1;
    var i = open;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        i = _quotedEnd(s, i, ch);
        continue;
      }
      if (ch == '(' || ch == '{') {
        depth++;
      } else if (ch == ')' || ch == '}') {
        depth--;
        if (depth == 0) {
          args.add(s.substring(start, i));
          return args;
        }
      } else if (depth == 1 && ch == sep) {
        args.add(s.substring(start, i));
        start = i + 1;
      }
      i++;
    }
    args.add(s.substring(start));
    return args;
  }

  static String _stripPrefix(String word) {
    final up = word.toUpperCase();
    // `_xlpm.` = dosyadaki LAMBDA/LET parametre adı öneki (`_xlpm.x`).
    for (final p in const ['_XLFN._XLWS.', '_XLFN.', '_XLWS.', '_XLPM.']) {
      if (up.startsWith(p)) return word.substring(p.length);
    }
    return word;
  }

  /// Formül Türkçe yazımla mı: tırnak ve `{…}` dizi sabiti dışında `;` ya
  /// da dizi sabitinde `\` var mı. Dizi sabitindeki `;` dosya biçiminde de
  /// satır ayırıcıdır (`{1,2;3,4}`) — sayılsaydı `1,2` ondalık okunurdu
  /// (B10 m.2).
  static bool _hasTopSemicolon(String s) {
    var i = 0;
    var inArray = false;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        i = _quotedEnd(s, i, ch);
        continue;
      }
      if (ch == '{') inArray = true;
      if (ch == '}') inArray = false;
      if (ch == ';' && !inArray) return true;
      // Türkçe dizi sabitinde sütun ayırıcı `\` (`{1\2;3\4}`).
      if (ch == r'\' && inArray) return true;
      i++;
    }
    return false;
  }

  /// [q] ile açılan tırnaklı bölümün bittiği indeks (kapanıştan sonrası);
  /// çift tırnak kaçışı (`""` / `''`) bölümün içinde sayılır.
  static int _quotedEnd(String s, int start, String q) {
    var i = start + 1;
    while (i < s.length) {
      if (s[i] == q) {
        if (i + 1 < s.length && s[i + 1] == q) {
          i += 2;
          continue;
        }
        return i + 1;
      }
      i++;
    }
    return s.length;
  }

  /// Takma ad tablosunda ANAHTAR olarak duran ama zaten İngilizce olan
  /// (dosyada böyle yazılması gereken) adlar — kanonik karşılıklarına
  /// indirgenmemeli (`STDEV.S` dosyada `STDEV.S` kalır).
  static const _englishNames = {
    'STDEV.S', 'STDEV.P', 'VAR.S', 'VAR.P', 'MODE.SNGL', 'PERCENTILE.INC',
    'QUARTILE.INC', 'PERCENTRANK.INC', 'RANK.EQ', 'RANK.AVG', 'VAR', 'LN',
  };

  /// Excel 2007 sonrası işlevler — OOXML'de `_xlfn.` önekiyle saklanır;
  /// öneksiz yazılırsa Excel açılışta `#AD?` gösterir.
  static const _xlfn = {
    'IFS', 'IFNA', 'SWITCH', 'XOR', 'XLOOKUP', 'XMATCH', 'TEXTJOIN',
    'CONCAT', 'MAXIFS', 'MINIFS', 'DAYS', 'STDEV.S', 'STDEV.P', 'VAR.S',
    'VAR.P', 'MODE.SNGL', 'PERCENTILE.INC', 'QUARTILE.INC',
    'PERCENTRANK.INC', 'RANK.EQ', 'RANK.AVG', 'CEILING.MATH', 'FLOOR.MATH',
    'TEXTBEFORE', 'TEXTAFTER', 'NUMBERVALUE', 'UNICHAR', 'UNICODE',
    'ISOWEEKNUM', 'ISFORMULA', 'FORMULATEXT', 'SHEET', 'SHEETS',
    'FILTER', 'SORT', 'UNIQUE', 'SEQUENCE', 'LET',
    // B10 m.2
    'TEXTSPLIT', 'VSTACK', 'HSTACK', 'TAKE', 'DROP', 'CHOOSECOLS',
    'CHOOSEROWS', 'LAMBDA', 'MAP', 'REDUCE', 'SCAN', 'BYROW', 'BYCOL',
    'MAKEARRAY', 'NETWORKDAYS.INTL', 'WORKDAY.INTL',
    'TOCOL', 'TOROW', 'WRAPROWS', 'WRAPCOLS',
  };
}

/// Dosya biçimindeki formülü **Türkçe gösterime** çevirir (Faz 25 / K22):
/// İngilizce ad → Türkçe Excel adı, `,` → `;` (dizi sabitinde `\`),
/// `.` ondalık → `,`,
/// `TRUE/FALSE` → `DOĞRU/YANLIŞ`, `_xlfn.` öneki kalkar. Tırnak içi metne,
/// sayfa adına ve tablo başvurusuna dokunulmaz.
extension _FormulaDisplayPart on _Parser {
  static String toTurkish(String formula) {
    final s = formula;
    final out = StringBuffer();
    var i = 0;
    var inArray = false;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        final end = _FormulaLocalePart._quotedEnd(s, i, ch);
        out.write(s.substring(i, end));
        i = end;
        continue;
      }
      if (ch == '[') {
        final end = s.indexOf(']', i);
        final stop = end < 0 ? s.length : end + 1;
        out.write(s.substring(i, stop));
        i = stop;
        continue;
      }
      // Dizi sabiti: sütun `,` → `\`, satır `;` kalır (toFile'ın tersi).
      if (ch == '{') inArray = true;
      if (ch == '}') inArray = false;
      if (ch == ',') {
        out.write(inArray ? r'\' : ';');
        i++;
        continue;
      }
      if (ch == '.' &&
          i > 0 &&
          i + 1 < s.length &&
          _Parser._isDigit(s[i - 1]) &&
          _Parser._isDigit(s[i + 1]) &&
          !_inName(s, i)) {
        out.write(',');
        i++;
        continue;
      }
      if (_Parser._isAlpha(ch) || ch == '_') {
        var j = i;
        while (j < s.length &&
            (_Parser._isAlpha(s[j]) ||
                _Parser._isDigit(s[j]) ||
                s[j] == '_' ||
                s[j] == '.' ||
                s[j] == r'$')) {
          j++;
        }
        final word = s.substring(i, j);
        final next = j < s.length ? s[j] : '';
        if (word.toUpperCase().startsWith('_XLPM.')) {
          // LAMBDA/LET parametresi: ekranda öneksiz (kayıtta geri eklenir).
          out.write(word.substring(6));
        } else if (next == '(') {
          out.write(_trName(word));
        } else if (next != '!' && !word.contains(r'$')) {
          final up = word.toUpperCase();
          out.write(up == 'TRUE'
              ? 'DOĞRU'
              : up == 'FALSE'
                  ? 'YANLIŞ'
                  : word);
        } else {
          out.write(word);
        }
        i = j;
        continue;
      }
      out.write(ch);
      i++;
    }
    return out.toString();
  }

  /// `.` bir adın içinde mi (`STDEV.S`, `A1.5` değil).
  static bool _inName(String s, int at) {
    var k = at - 1;
    while (k >= 0 && _Parser._isDigit(s[k])) {
      k--;
    }
    return k >= 0 && (_Parser._isAlpha(s[k]) || s[k] == '_');
  }

  static String _trName(String word) {
    final bare = _FormulaLocalePart._stripPrefix(word).toUpperCase();
    return _turkishOf[bare] ?? bare;
  }

  /// İngilizce → tercih edilen Türkçe ad (Türkçe Excel'in kendi adları).
  static final Map<String, String> _turkishOf = () {
    final out = <String, String>{};
    _Parser._aliases.forEach((tr, en) {
      if (_FormulaLocalePart._englishNames.contains(tr)) return;
      if (tr == en) return;
      out.putIfAbsent(en, () => tr);
    });
    // Birden çok Türkçe karşılığı olanlarda Türkçe Excel'in seçtiği.
    out.addAll(const {
      'SMALL': 'KÜÇÜK',
      'LARGE': 'BÜYÜK',
      'EDATE': 'SERİTARİH',
      'ISEVEN': 'ÇİFTMİ',
      'ISODD': 'TEKMİ',
      'IRR': 'İÇ_VERİM_ORANI',
      'STDEV': 'STDSAPMA',
      'PERCENTILE': 'YÜZDEBİRLİK',
      'QUARTILE': 'DÖRTTEBİRLİK',
      'PERCENTRANK': 'YÜZDERANK',
    });
    return out;
  }();
}

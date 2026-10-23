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
  static String toFile(String formula) {
    final s = formula;
    final tr = _hasTopSemicolon(s);
    final out = StringBuffer();
    var i = 0;
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
      if (ch == ';') {
        out.write(',');
        i++;
        continue;
      }
      if (ch == ',' &&
          tr &&
          i > 0 &&
          i + 1 < s.length &&
          _Parser._isDigit(s[i - 1]) &&
          _Parser._isDigit(s[i + 1])) {
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
        if (next == '(') {
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
    } else if (trUp == 'DOĞRU') {
      name = 'TRUE';
    } else if (trUp == 'YANLIŞ') {
      name = 'FALSE';
    } else {
      // Tanınmayan ad (kullanıcının özel işlevi / eklenti) olduğu gibi kalır.
      return word;
    }
    return _xlfn.contains(name) ? '_xlfn.$name' : name;
  }

  static String _stripPrefix(String word) {
    final up = word.toUpperCase();
    for (final p in const ['_XLFN._XLWS.', '_XLFN.', '_XLWS.']) {
      if (up.startsWith(p)) return word.substring(p.length);
    }
    return word;
  }

  /// Formülde tırnak dışında `;` var mı (Türkçe yazım işareti).
  static bool _hasTopSemicolon(String s) {
    var i = 0;
    while (i < s.length) {
      final ch = s[i];
      if (ch == '"' || ch == "'") {
        i = _quotedEnd(s, i, ch);
        continue;
      }
      if (ch == ';') return true;
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
  };
}

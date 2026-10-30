/// Kod / yapılandırma dosyaları için **hafif sözdizimi renklendirme**
/// (Faz 30). Saf Dart: tek geçişli, dile göre ayarlı bir tarayıcı — tam bir
/// ayrıştırıcı DEĞİL; amacı anahtar sözcük, dize, yorum ve sayıyı ayırt
/// ettirmek. Hata toleranslıdır: kapanmamış dize/yorum satır ya da belge
/// sonunda biter, hiçbir girdide atmaz.
library;

/// Renklendirme dili (uzantıdan seçilir).
enum CodeLang {
  plain,
  dart,
  cLike, // c, cpp, java, kotlin, swift, go, rust, c#, php
  js,
  python,
  json,
  markup, // xml, html, svg
  yaml,
  shell,
  sql,
  css,
  ini,
}

/// Belirteç türü.
enum CodeTokenKind { keyword, string, comment, number, type, tag }

/// Metindeki `[start, end)` aralığı.
class CodeToken {
  final int start;
  final int end;
  final CodeTokenKind kind;
  const CodeToken(this.start, this.end, this.kind);

  @override
  String toString() => 'CodeToken($start,$end,$kind)';
}

/// 1 MB'a kadar renklendirme her tuşta, UI izleğinde (tek geçiş, hızlı).
const int codeHighlightMaxChars = 1 << 20;

/// 1–4 MB arası: renklendirme **arka planda** (izolatta), yazma durunca
/// (Faz 30 kalanı). Üstünde kapalı — span ağacının kendisi ağırlaşıyor.
const int codeHighlightIsolateMaxChars = 4 << 20;

/// Uzantıdan dil. Bilinmeyen → [CodeLang.plain] (renklendirme yok).
CodeLang codeLangFor(String ext) {
  switch (ext.toLowerCase().replaceFirst('.', '')) {
    case 'dart':
      return CodeLang.dart;
    case 'c':
    case 'h':
    case 'cpp':
    case 'cc':
    case 'hpp':
    case 'java':
    case 'kt':
    case 'kts':
    case 'swift':
    case 'go':
    case 'rs':
    case 'cs':
    case 'php':
      return CodeLang.cLike;
    case 'js':
    case 'mjs':
    case 'ts':
    case 'jsx':
    case 'tsx':
      return CodeLang.js;
    case 'py':
      return CodeLang.python;
    case 'json':
      return CodeLang.json;
    case 'xml':
    case 'html':
    case 'htm':
    case 'svg':
    case 'xhtml':
      return CodeLang.markup;
    case 'yaml':
    case 'yml':
      return CodeLang.yaml;
    case 'sh':
    case 'bash':
    case 'bat':
    case 'cmd':
      return CodeLang.shell;
    case 'sql':
      return CodeLang.sql;
    case 'css':
    case 'scss':
      return CodeLang.css;
    case 'ini':
    case 'conf':
    case 'cfg':
    case 'properties':
    case 'toml':
      return CodeLang.ini;
  }
  return CodeLang.plain;
}

class _Cfg {
  final Set<String> keywords;
  final List<String> lineComments;
  final String? blockOpen;
  final String? blockClose;
  final String quotes;
  final bool tripleQuotes;
  final bool caseInsensitive;
  const _Cfg({
    this.keywords = const {},
    this.lineComments = const [],
    this.blockOpen,
    this.blockClose,
    this.quotes = '"\'',
    this.tripleQuotes = false,
    this.caseInsensitive = false,
  });
}

Set<String> _w(String s) => s.split(' ').toSet();

final Map<CodeLang, _Cfg> _cfgs = {
  CodeLang.dart: _Cfg(
    keywords: _w('abstract as assert async await break case catch class const '
        'continue covariant default deferred do dynamic else enum export '
        'extends extension external factory false final finally for get if '
        'implements import in interface is late library mixin new null on '
        'operator part required rethrow return sealed set show static super '
        'switch sync this throw true try typedef var void while with yield'),
    lineComments: ['//'],
    blockOpen: '/*',
    blockClose: '*/',
    tripleQuotes: true,
  ),
  CodeLang.cLike: _Cfg(
    keywords: _w('abstract auto bool boolean break byte case catch char class '
        'const continue data default defer delete do double else enum extends '
        'false fi final finally float fn for fun func function go if impl '
        'implements import in include int interface let long match mod mut '
        'namespace new nil null override package private protected pub public '
        'return self short signed static string struct super switch template '
        'this throw throws trait true try typedef union unsafe unsigned use '
        'using val var virtual void volatile while'),
    lineComments: ['//'],
    blockOpen: '/*',
    blockClose: '*/',
  ),
  CodeLang.js: _Cfg(
    keywords: _w('async await break case catch class const continue debugger '
        'default delete do else enum export extends false finally for from '
        'function if implements import in instanceof interface let new null '
        'of private protected public return static super switch this throw '
        'true try type typeof undefined var void while with yield'),
    lineComments: ['//'],
    blockOpen: '/*',
    blockClose: '*/',
    quotes: '"\'`',
  ),
  CodeLang.python: _Cfg(
    keywords: _w('and as assert async await break class continue def del elif '
        'else except False finally for from global if import in is lambda '
        'None nonlocal not or pass raise return True try while with yield'),
    lineComments: ['#'],
    tripleQuotes: true,
  ),
  CodeLang.json: _Cfg(keywords: _w('true false null')),
  CodeLang.yaml: _Cfg(
    keywords: _w('true false null yes no on off'),
    lineComments: ['#'],
  ),
  CodeLang.shell: _Cfg(
    keywords: _w('if then else elif fi for while do done case esac function '
        'in return exit echo export set unset local source cd rem'),
    lineComments: ['#'],
  ),
  CodeLang.sql: _Cfg(
    keywords: _w('select from where insert into values update set delete '
        'create table alter drop index view join inner left right outer on '
        'group by order having limit offset union all distinct as and or not '
        'null is in like between exists case when then else end primary key '
        'foreign references default'),
    lineComments: ['--'],
    blockOpen: '/*',
    blockClose: '*/',
    caseInsensitive: true,
  ),
  CodeLang.css: const _Cfg(
    blockOpen: '/*',
    blockClose: '*/',
  ),
  CodeLang.ini: _Cfg(
    keywords: _w('true false'),
    lineComments: [';', '#'],
  ),
};

bool _isWordStart(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A) || c == 0x5F;
bool _isWordPart(int c) => _isWordStart(c) || _isDigit(c);
bool _isDigit(int c) => c >= 0x30 && c <= 0x39;

/// [text]'i tarayıp renklenecek aralıkları döndürür (artan sırada,
/// çakışmasız). [CodeLang.plain] ya da çok büyük metinde boş.
List<CodeToken> tokenizeCode(String text, CodeLang lang) {
  if (lang == CodeLang.plain || text.length > codeHighlightIsolateMaxChars) {
    return const [];
  }
  if (lang == CodeLang.markup) return _tokenizeMarkup(text);
  final cfg = _cfgs[lang];
  if (cfg == null) return const [];
  final out = <CodeToken>[];
  final n = text.length;
  var i = 0;
  while (i < n) {
    final c = text.codeUnitAt(i);
    // Yorumlar
    var matched = false;
    for (final lc in cfg.lineComments) {
      if (text.startsWith(lc, i)) {
        // Python/YAML/kabuk '#': satır başı ya da boşluktan sonra (url#frag
        // ve renk kodu değil).
        if (lc == '#' && i > 0) {
          final prev = text.codeUnitAt(i - 1);
          if (prev != 0x20 && prev != 0x09 && prev != 0x0A) continue;
        }
        var e = text.indexOf('\n', i);
        if (e == -1) e = n;
        out.add(CodeToken(i, e, CodeTokenKind.comment));
        i = e;
        matched = true;
        break;
      }
    }
    if (matched) continue;
    if (cfg.blockOpen != null && text.startsWith(cfg.blockOpen!, i)) {
      var e = text.indexOf(cfg.blockClose!, i + cfg.blockOpen!.length);
      e = e == -1 ? n : e + cfg.blockClose!.length;
      out.add(CodeToken(i, e, CodeTokenKind.comment));
      i = e;
      continue;
    }
    // Dizeler
    if (cfg.quotes.codeUnits.contains(c)) {
      final q = String.fromCharCode(c);
      if (cfg.tripleQuotes && text.startsWith(q * 3, i)) {
        var e = text.indexOf(q * 3, i + 3);
        e = e == -1 ? n : e + 3;
        out.add(CodeToken(i, e, CodeTokenKind.string));
        i = e;
        continue;
      }
      var j = i + 1;
      while (j < n) {
        final d = text.codeUnitAt(j);
        if (d == 0x5C && q != '`') {
          j += 2;
          continue;
        }
        if (d == c) {
          j++;
          break;
        }
        // Tek satırlık dize: satır sonunda biter (kapanmamış tırnak
        // belgenin kalanını boyamasın). Kabuk için ' ve ` hariç.
        if (d == 0x0A && q != '`') break;
        j++;
      }
      if (j > n) j = n;
      out.add(CodeToken(i, j, CodeTokenKind.string));
      i = j;
      continue;
    }
    // Sayılar
    if (_isDigit(c) && (i == 0 || !_isWordPart(text.codeUnitAt(i - 1)))) {
      var j = i + 1;
      while (j < n) {
        final d = text.codeUnitAt(j);
        if (_isWordPart(d) || d == 0x2E) {
          j++;
        } else {
          break;
        }
      }
      out.add(CodeToken(i, j, CodeTokenKind.number));
      i = j;
      continue;
    }
    // Sözcükler
    if (_isWordStart(c)) {
      var j = i + 1;
      while (j < n && _isWordPart(text.codeUnitAt(j))) {
        j++;
      }
      var word = text.substring(i, j);
      if (cfg.caseInsensitive) word = word.toLowerCase();
      if (cfg.keywords.contains(word)) {
        out.add(CodeToken(i, j, CodeTokenKind.keyword));
      } else if (lang != CodeLang.json &&
          lang != CodeLang.yaml &&
          lang != CodeLang.ini &&
          lang != CodeLang.shell &&
          lang != CodeLang.css &&
          c >= 0x41 &&
          c <= 0x5A &&
          word.length > 1) {
        out.add(CodeToken(i, j, CodeTokenKind.type));
      }
      i = j;
      continue;
    }
    i++;
  }
  return out;
}

List<CodeToken> _tokenizeMarkup(String text) {
  final out = <CodeToken>[];
  final n = text.length;
  var i = 0;
  while (i < n) {
    if (text.codeUnitAt(i) != 0x3C) {
      i++;
      continue;
    }
    if (text.startsWith('<!--', i)) {
      var e = text.indexOf('-->', i + 4);
      e = e == -1 ? n : e + 3;
      out.add(CodeToken(i, e, CodeTokenKind.comment));
      i = e;
      continue;
    }
    // Etiket: `<` ... `>` (tırnak içindeki `>`a dikkat).
    var j = i + 1;
    // Etiket adı
    final nameStart = j;
    while (j < n) {
      final d = text.codeUnitAt(j);
      if (d == 0x20 || d == 0x3E || d == 0x0A || d == 0x09 || d == 0x0D) break;
      j++;
    }
    if (j == nameStart) {
      i++;
      continue;
    }
    out.add(CodeToken(i, j, CodeTokenKind.tag));
    while (j < n) {
      final d = text.codeUnitAt(j);
      if (d == 0x3E) {
        out.add(CodeToken(j, j + 1, CodeTokenKind.tag));
        j++;
        break;
      }
      if (d == 0x22 || d == 0x27) {
        var e = text.indexOf(String.fromCharCode(d), j + 1);
        e = e == -1 ? n : e + 1;
        out.add(CodeToken(j, e, CodeTokenKind.string));
        j = e;
        continue;
      }
      j++;
    }
    i = j;
  }
  return out;
}

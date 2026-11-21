/// Word "yazarken otomatik biçim" kuralları (B9 m.7) — saf metin işlevleri.
///
/// Denetleyici her tek harflik yazımdan sonra sorar; kural tutarsa paragrafın
/// [from, to) aralığı [text] olur (ayrı geri al adımı — Word gibi ilk geri al
/// düzeltmeyi kaldırır, yazılanı değil):
/// * cümle başı küçük harfle başlayan sözcük bitince büyür (Türkçe `i → İ`,
///   `ı → I`); sıra sayısı (`3. sınıf`), kısaltma (`vb.`), adres içinde dokunmaz;
/// * `--` → `—`;
/// * sözcükten sonra çift boşluk tek boşluk olur;
/// * paragraf başında `- ` / `* ` / `• ` madde, `1. ` / `1) ` numaralı liste
///   başlatır ([listTrigger]).
library;

typedef DocxAutoEdit = ({int from, int to, String text});

class DocxAutoFormat {
  DocxAutoFormat._();

  static final _letter = RegExp(r'\p{L}', unicode: true);
  static final _space = RegExp(r'\s');
  static final _digits = RegExp(r'^\d+$');
  static final _addressy = RegExp(r'[.@/:\\]');

  /// Sözcüğü bitiren harfler (büyük harf kuralı bunlarda bakar).
  static const _enders = ' .,;:!?';

  /// Noktadan sonra cümle başı SAYILMAYAN kısaltmalar (küçük harfle).
  static const _abbrev = {
    'vb', 'vs', 'örn', 'bkz', 'dr', 'prof', 'doç', 'av', 'sn', 'mr', 'mrs',
    'ms', 'st', 'etc', 'eg', 'ie', 'no', 'nr', 'yy', 'cad', 'sok', 'mah',
    'apt', 'tel', 'vd', 'krş', 'ss', 's', 'yrd', 'öğr', 'gör', 'müh',
  };

  static bool _isLetter(String ch) => _letter.hasMatch(ch);
  static bool _isSpace(String ch) => _space.hasMatch(ch);

  /// Dile göre büyük harf (Türkçe: `i → İ`, `ı → I`).
  static String upper(String ch, {required bool turkish}) {
    if (turkish) {
      if (ch == 'i') return 'İ';
      if (ch == 'ı') return 'I';
    }
    return ch.toUpperCase();
  }

  static String _lower(String s, bool turkish) => turkish
      ? s.replaceAll('I', 'ı').replaceAll('İ', 'i').toLowerCase()
      : s.toLowerCase();

  /// [caret]'e (yazılan harfin hemen sonrası) bakarak düzeltme; yoksa null.
  static DocxAutoEdit? afterInsert(String text, int caret,
      {required bool turkish}) {
    if (caret < 1 || caret > text.length) return null;
    final ins = text[caret - 1];
    // "--" → "—"
    if (ins == '-' && caret >= 2 && text[caret - 2] == '-') {
      return (from: caret - 2, to: caret, text: '—');
    }
    // Sözcükten sonra çift boşluk → tek.
    if (ins == ' ' &&
        caret >= 2 &&
        text[caret - 2] == ' ' &&
        (caret >= text.length || !_isSpace(text[caret])) &&
        _textBefore(text, caret - 2)) {
      return (from: caret - 1, to: caret, text: '');
    }
    if (_enders.contains(ins)) return _capitalize(text, caret - 1, ins, turkish);
    return null;
  }

  /// [at]'ten önce boşluk olmayan harf var mı (paragraf başı girintisi değil).
  static bool _textBefore(String text, int at) {
    for (var k = at - 1; k >= 0; k--) {
      if (!_isSpace(text[k])) return true;
    }
    return false;
  }

  /// [end]'de biten sözcük cümle başıysa ve küçük harfle başlıyorsa büyütür.
  static DocxAutoEdit? _capitalize(
      String text, int end, String ins, bool turkish) {
    var ws = end;
    while (ws > 0 && _isLetter(text[ws - 1])) {
      ws--;
    }
    if (ws == end) return null;
    if (ins == '.' && end - ws == 1) return null; // "a." harf sırası
    final word = text.substring(ws, end);
    // Yalnız tümü küçük harf (iPhone, eBay … dokunulmaz).
    if (word != _lower(word, turkish)) return null;
    final first = word[0];
    final up = upper(first, turkish: turkish);
    if (up == first || up.length != 1) return null;
    if (!_sentenceStart(text, ws, turkish)) return null;
    return (from: ws, to: ws + 1, text: up);
  }

  static bool _sentenceStart(String text, int ws, bool turkish) {
    var k = ws - 1;
    if (k < 0) return true;
    if (!_isSpace(text[k])) return false;
    while (k >= 0 && _isSpace(text[k])) {
      k--;
    }
    if (k < 0) return true;
    final ch = text[k];
    if (ch == '!' || ch == '?' || ch == '…') return true;
    if (ch != '.') return false;
    var t = k;
    while (t > 0 && !_isSpace(text[t - 1])) {
      t--;
    }
    final token = text.substring(t, k);
    if (token.isEmpty || _digits.hasMatch(token)) return false;
    if (token.contains(_addressy)) return false;
    return !_abbrev.contains(_lower(token, turkish));
  }

  /// Paragraf başında liste işareti + boşluk yazıldıysa: (tür, önek boyu).
  static (String kind, int length)? listTrigger(String text, int caret) {
    if (caret < 2 || caret > text.length || text[caret - 1] != ' ') return null;
    final prefix = text.substring(0, caret);
    if (prefix == '- ' || prefix == '* ' || prefix == '• ') {
      return ('bullet', caret);
    }
    if (prefix == '1. ' || prefix == '1) ') return ('number', caret);
    return null;
  }
}

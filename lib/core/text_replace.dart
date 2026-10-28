import 'text_search.dart';

/// **Bul ve Değiştir** — metin belgelerinin eksik yarısı.
///
/// ## Niye (2026-09-06 denetim turu)
/// Uygulama belge içinde **arayabiliyordu** ama bulduğunu değiştiremiyordu:
/// bir `.txt`/`.csv`/`.md` dosyasında geçen 200 tarihi düzeltmek isteyen
/// kullanıcı tek tek elle yazmak zorundaydı. Arama zaten Türkçe-duyarlı
/// ([findAll]); değiştirme onun doğal devamı.
///
/// Saf Dart: metni alır, metin döndürür. Arayüz (görüntüleyicideki çubuk)
/// bunun üstüne biniyor, mantık burada test ediliyor.
abstract final class TextReplace {
  /// [text] içinde [find] geçen yerleri bulur.
  ///
  /// [matchCase] kapalıyken arama Türkçe-duyarlı katlamayla yapılır
  /// (`IŞIK` ararken `ışık`ı da bulur — Dart'ın kendi `toLowerCase`i bunu
  /// beceremiyor, bkz. [turkishFold]).
  ///
  /// [wholeWord] açıkken eşleşmenin iki yanında harf/rakam olmamalı: "ev"
  /// aranırken "evet" eşleşmez.
  static List<int> matches(
    String text,
    String find, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    if (find.isEmpty) return const [];
    final hits = matchCase
        ? _caseSensitiveHits(text, find)
        : findAll(text, find);
    if (!wholeWord) return hits;
    return [
      for (final index in hits)
        if (_isWholeWord(text, index, find.length)) index,
    ];
  }

  /// [index]'teki eşleşmeyi [replacement] ile değiştirilmiş metni döner.
  ///
  /// Tek tek değiştirmenin ayrı bir yolu olmasının sebebi: kullanıcı bazen
  /// "şunu değiştir, şunu bırak" der. Toplu değiştirme bunu yapamaz.
  static String replaceAt(
      String text, int index, int length, String replacement) {
    if (index < 0 || index + length > text.length) return text;
    return text.replaceRange(index, index + length, replacement);
  }

  /// Tüm eşleşmeleri değiştirir ve **kaç tanesinin** değiştiğini de döner.
  ///
  /// Sayı kullanıcıya gösteriliyor ("12 değişiklik yapıldı"): sessizce
  /// dönen bir metin, hiçbir şeyin değişmediği durumu gizlerdi.
  ///
  /// Değiştirme **sondan başa** yapılıyor: baştan gidilseydi ilk değişiklik
  /// sonraki eşleşmelerin indekslerini kaydırırdı (uzunluklar farklıysa).
  static ({String text, int count}) replaceAll(
    String text,
    String find,
    String replacement, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    final hits =
        matches(text, find, matchCase: matchCase, wholeWord: wholeWord);
    if (hits.isEmpty) return (text: text, count: 0);
    var out = text;
    for (final index in hits.reversed) {
      out = out.replaceRange(index, index + find.length, replacement);
    }
    return (text: out, count: hits.length);
  }

  static List<int> _caseSensitiveHits(String text, String find) {
    final out = <int>[];
    var i = text.indexOf(find);
    while (i != -1 && out.length < 20000) {
      out.add(i);
      i = text.indexOf(find, i + find.length);
    }
    return out;
  }

  /// Eşleşmenin iki yanı sözcük sınırı mı?
  ///
  /// `RegExp`in `\b`si Türkçe harfleri sözcük karakteri saymıyor (`\w` yalnız
  /// `[A-Za-z0-9_]`): "ev" ararken "evı" bir sözcük sınırı sanılırdı. Kendi
  /// sınırımız Unicode harflerine bakıyor.
  static bool _isWholeWord(String text, int index, int length) {
    bool wordChar(int at) {
      if (at < 0 || at >= text.length) return false;
      final ch = text[at];
      return RegExp(r'[\p{L}\p{N}_]', unicode: true).hasMatch(ch);
    }

    return !wordChar(index - 1) && !wordChar(index + length);
  }

  /// **Düzenli ifade** araması (Faz 30). Eşleşme uzunlukları değişkendir →
  /// `(başlangıç, bitiş)` çiftleri. Geçersiz desen ya da boş eşleşme
  /// döngüsünde `null` / atlama: arayüz "geçersiz ifade" der, uygulama
  /// çökmez. [wholeWord] desenin etrafına `\b` DEĞİL Unicode sınırı koyar.
  static List<(int, int)>? regexMatches(
    String text,
    String pattern, {
    bool matchCase = false,
    bool wholeWord = false,
    int limit = 20000,
  }) {
    if (pattern.isEmpty) return const [];
    final RegExp re;
    try {
      re = RegExp(pattern, caseSensitive: matchCase, unicode: true);
    } on FormatException {
      return null;
    }
    final out = <(int, int)>[];
    for (final m in re.allMatches(text)) {
      if (m.end == m.start) continue; // boş eşleşme
      if (wholeWord && !_isWholeWord(text, m.start, m.end - m.start)) continue;
      out.add((m.start, m.end));
      if (out.length >= limit) break;
    }
    return out;
  }

  /// Tek geçişte tüm düzenli ifade eşleşmelerini değiştirir; değiştirme
  /// metninde `$1` … grup başvuruları çalışır.
  static ({String text, int count}) regexReplaceAll(
    String text,
    String pattern,
    String replacement, {
    bool matchCase = false,
    bool wholeWord = false,
  }) {
    final spans = regexMatches(text, pattern,
        matchCase: matchCase, wholeWord: wholeWord);
    if (spans == null || spans.isEmpty) return (text: text, count: 0);
    final re = RegExp(pattern, caseSensitive: matchCase, unicode: true);
    final sb = StringBuffer();
    var last = 0;
    for (final (a, b) in spans) {
      sb.write(text.substring(last, a));
      final m = re.matchAsPrefix(text, a)!;
      sb.write(expandGroups(replacement, m));
      last = b;
    }
    sb.write(text.substring(last));
    return (text: sb.toString(), count: spans.length);
  }

  /// `$1`..`$9` ve `$&` başvurularını [m]'nin gruplarıyla doldurur.
  static String expandGroups(String replacement, Match m) {
    return replacement.replaceAllMapped(RegExp(r'\$(\d|&)'), (g) {
      final k = g.group(1)!;
      if (k == '&') return m.group(0) ?? '';
      final i = int.parse(k);
      return i <= m.groupCount ? (m.group(i) ?? '') : g.group(0)!;
    });
  }
}

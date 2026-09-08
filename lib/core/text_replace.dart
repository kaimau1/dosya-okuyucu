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
}

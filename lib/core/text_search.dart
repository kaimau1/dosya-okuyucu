/// Belge içi arama ve metin istatistikleri (saf Dart, test edilebilir).
library;

/// Türkçe-duyarlı büyük/küçük harf katlama (arama için).
///
/// Dart'ın `toLowerCase`'i yerel-duyarsızdır: `'I'.toLowerCase()` → `'i'`
/// (Türkçe'de `'ı'` olmalı), `'İ'` → nokta+`i` (2 kod birimi, indeks kayması).
/// Bu fonksiyon `İ→i`, `I→ı` eşler ve her karakteri **tek** karaktere
/// indirger → kaynak metinle indeksler hizalı kalır (eşleşme konumu doğru).
String turkishFold(String s) {
  final sb = StringBuffer();
  for (final ch in s.split('')) {
    if (ch == 'İ') {
      sb.write('i');
    } else if (ch == 'I') {
      sb.write('ı');
    } else {
      final low = ch.toLowerCase();
      // 1:1 kalmalı; çok-karakterli nadir durumda orijinali koru.
      sb.write(low.length == 1 ? low : ch);
    }
  }
  return sb.toString();
}

/// [needle]'ın [haystack] içindeki tüm başlangıç indekslerini döndürür.
/// Büyük/küçük harf duyarsız (Türkçe katlamalı) ve çakışmasız. [limit] üstünde
/// durur (çok büyük belgede donmayı önler). İndeksler kaynak metne göredir.
List<int> findAll(String haystack, String needle, {int limit = 5000}) {
  final q = needle.trim();
  if (q.isEmpty) return const [];
  final hay = turkishFold(haystack);
  final nee = turkishFold(q);
  final out = <int>[];
  var i = hay.indexOf(nee);
  while (i != -1 && out.length < limit) {
    out.add(i);
    i = hay.indexOf(nee, i + nee.length);
  }
  return out;
}

/// Metin istatistikleri (kelime/karakter/satır/paragraf).
class TextStats {
  final int words;
  final int characters; // boşluklar dahil
  final int charactersNoSpaces;
  final int lines;
  final int paragraphs;

  const TextStats({
    required this.words,
    required this.characters,
    required this.charactersNoSpaces,
    required this.lines,
    required this.paragraphs,
  });

  static final _wsRun = RegExp(r'\s+');
  static final _blankLine = RegExp(r'\n[ \t]*\n');

  /// [text]'in istatistiklerini hesaplar.
  static TextStats of(String text) {
    final trimmed = text.trim();
    final words = trimmed.isEmpty
        ? 0
        : trimmed.split(_wsRun).where((w) => w.isNotEmpty).length;
    final chars = text.runes.length;
    final noSpaces =
        text.runes.where((r) => !_isWhitespaceRune(r)).length;
    final lines = text.isEmpty ? 0 : '\n'.allMatches(text).length + 1;
    final paragraphs = trimmed.isEmpty
        ? 0
        : trimmed
            .split(_blankLine)
            .where((p) => p.trim().isNotEmpty)
            .length;
    return TextStats(
      words: words,
      characters: chars,
      charactersNoSpaces: noSpaces,
      lines: lines,
      paragraphs: paragraphs,
    );
  }

  static bool _isWhitespaceRune(int r) =>
      r == 0x20 || r == 0x09 || r == 0x0A || r == 0x0D || r == 0x0C;
}

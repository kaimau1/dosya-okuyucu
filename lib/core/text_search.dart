/// Belge içi arama ve metin istatistikleri (saf Dart, test edilebilir).
library;

/// Türkçe-duyarlı büyük/küçük harf katlama (arama için).
///
/// Dart'ın `toLowerCase`'i yerel-duyarsızdır: `'I'.toLowerCase()` → `'i'`
/// (Türkçe'de `'ı'` olmalı), `'İ'` → nokta+`i` (2 kod birimi, indeks kayması).
/// Bu fonksiyon `İ→i`, `I→ı` eşler ve her karakteri **tek** karaktere
/// indirger → kaynak metinle indeksler hizalı kalır (eşleşme konumu doğru).
String turkishFold(String s) {
  final len = s.length;
  if (len == 0) return s;
  // Hızlı yol: zaten küçük ASCII/rakam/noktalama ise hiç bellek ayırmadan dön.
  var firstDiff = -1;
  for (var i = 0; i < len; i++) {
    final c = s.codeUnitAt(i);
    if ((c >= 0x41 && c <= 0x5A) || c >= 0x80) {
      firstDiff = i;
      break;
    }
  }
  if (firstDiff < 0) return s;

  final sb = StringBuffer();
  if (firstDiff > 0) sb.write(s.substring(0, firstDiff));
  for (var i = firstDiff; i < len; i++) {
    final c = s.codeUnitAt(i);
    if (c == 0x0049) {
      // 'I' → 'ı'
      sb.writeCharCode(0x0131);
    } else if (c == 0x0130) {
      // 'İ' → 'i'
      sb.writeCharCode(0x0069);
    } else if (c >= 0x41 && c <= 0x5A) {
      // ASCII A-Z (I hariç)
      sb.writeCharCode(c + 32);
    } else if (c < 0x80) {
      sb.writeCharCode(c);
    } else {
      switch (c) {
        case 0x00C7: // Ç → ç
          sb.writeCharCode(0x00E7);
        case 0x011E: // Ğ → ğ
          sb.writeCharCode(0x011F);
        case 0x00D6: // Ö → ö
          sb.writeCharCode(0x00F6);
        case 0x015E: // Ş → ş
          sb.writeCharCode(0x015F);
        case 0x00DC: // Ü → ü
          sb.writeCharCode(0x00FC);
        default:
          final ch = s[i];
          final low = ch.toLowerCase();
          // 1:1 kalmalı; çok-karakterli nadir durumda orijinali koru.
          sb.write(low.length == 1 ? low : ch);
      }
    }
  }
  return sb.toString();
}

/// Türkçe harfleri **ASCII** karşılığına indirger: `fotoğraf` → `fotograf`.
///
/// [turkishFold]dan farkı ve neden ayrı bir fonksiyon: `turkishFold` yalnız
/// büyük/küçük harf katlar ve her karakteri **tek** karakterde tutar, çünkü
/// belge içi aramanın eşleşme konumları kaynak metinle hizalı kalmak zorunda.
/// Bu fonksiyon karakterleri DEĞİŞTİRİR — hizayı bozar, o yüzden belge içi
/// aramada kullanılamaz. Kullanım yeri: **eşleşme/gruplama anahtarı** üretmek
/// (AI'nın verdiği "fotoğraf" ile "fotograf" türlerinin aynı kovaya düşmesi,
/// "sözleşme" yazan kullanıcının "sozlesme.pdf" dosyasını bulması).
String asciiFold(String s) {
  final len = s.length;
  if (len == 0) return s;
  // Hızlı yol: zaten küçük ASCII ise tek geçişte doğrudan dön.
  var firstDiff = -1;
  for (var i = 0; i < len; i++) {
    final c = s.codeUnitAt(i);
    if ((c >= 0x41 && c <= 0x5A) || c >= 0x80) {
      firstDiff = i;
      break;
    }
  }
  if (firstDiff < 0) return s;

  final sb = StringBuffer();
  if (firstDiff > 0) sb.write(s.substring(0, firstDiff));
  for (var i = firstDiff; i < len; i++) {
    final c = s.codeUnitAt(i);
    if (c >= 0x41 && c <= 0x5A) {
      // ASCII A-Z (I dahil → 'i', çünkü 'I' → 'ı' → 'i')
      sb.writeCharCode(c + 32);
    } else if (c < 0x80) {
      sb.writeCharCode(c);
    } else {
      switch (c) {
        case 0x0130 || 0x0131 || 0x00CE || 0x00EE: // İ, ı, Î, î → i
          sb.writeCharCode(0x0069);
        case 0x011E || 0x011F: // Ğ, ğ → g
          sb.writeCharCode(0x0067);
        case 0x00DC || 0x00FC || 0x00DB || 0x00FB: // Ü, ü, Û, û → u
          sb.writeCharCode(0x0075);
        case 0x015E || 0x015F: // Ş, ş → s
          sb.writeCharCode(0x0073);
        case 0x00D6 || 0x00F6: // Ö, ö → o
          sb.writeCharCode(0x006F);
        case 0x00C7 || 0x00E7: // Ç, ç → c
          sb.writeCharCode(0x0063);
        case 0x00C2 || 0x00E2 || 0x00C1 || 0x00E1: // Â, â, Á, á → a
          sb.writeCharCode(0x0061);
        case 0x00CA || 0x00EA || 0x00C9 || 0x00E9: // Ê, ê, É, é → e
          sb.writeCharCode(0x0065);
        default:
          final ch = s[i];
          final low = ch.toLowerCase();
          sb.write(low.length == 1 ? low : ch);
      }
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

/// Türkçe-duyarlı arama için **düzenli ifade**.
///
/// [findAll] metnin tamamı elimizdeyken çalışır; PDF'te ise arama pdfium'un
/// içinde, sayfa sayfa yapılıyor (`PdfTextSearcher`) ve bize yalnız bir
/// `Pattern` verme imkânı var. Paketin kendi `caseInsensitive` bayrağı
/// yerel-duyarsız — "İSTANBUL" ararken "istanbul"u, "IŞIK" ararken "ışık"ı
/// kaçırıyordu. Çözüm: her harfi Türkçe eş biçimlerini
/// kapsayan bir karakter sınıfına çevirmek, eşleştirmeyi büyük/küçük harf
/// DUYARLI koşturmak. Böylece kendi çizim geri çağırımımızı yazmadan,
/// paketin vurgulaması olduğu gibi kullanılabiliyor.
RegExp turkishSearchPattern(String query) =>
    RegExp(query.split('').map(_charClass).join());

/// Türkçe'de `toLowerCase`/`toUpperCase` yanlış eşleyen çiftler.
const _turkishCasePairs = <String, String>{
  'i': 'İ',
  'İ': 'i',
  'ı': 'I',
  'I': 'ı',
};

/// Bir karakterin büyük/küçük biçimlerini kapsayan düzenli ifade parçası.
String _charClass(String ch) {
  final variants = <String>{ch};
  final special = _turkishCasePairs[ch];
  if (special != null) {
    variants.add(special);
  } else {
    final up = ch.toUpperCase();
    final low = ch.toLowerCase();
    // Yalnız 1:1 dönüşümler; `ß`→`SS` gibi genişleyenler sınıfa konamaz.
    if (up.length == 1) variants.add(up);
    if (low.length == 1) variants.add(low);
  }
  if (variants.length == 1) return RegExp.escape(ch);
  // Karakter sınıfının kendi kaçış kuralları var (`RegExp.escape` sınıf içinde
  // `-` ve `^`ı bilmiyor); tehlikeli olanlar tek tek kaçırılır.
  final body = variants.map((c) {
    return const {'\\', ']', '^', '-'}.contains(c) ? '\\$c' : c;
  }).join();
  return '[$body]';
}

/// Bölümlere ayrılmış bir belgede (slayt, sayfa, sayfa sekmesi…) tek eşleşme.
class SectionHit {
  /// Eşleşmenin bulunduğu bölümün 0 tabanlı sırası.
  final int section;

  /// Eşleşmenin bölüm metnindeki başlangıç indeksi.
  final int offset;

  /// Listede gösterilecek kısa bağlam (eşleşme ortada kalacak şekilde).
  final String snippet;

  const SectionHit(this.section, this.offset, this.snippet);
}

/// Bölüm bölüm arama: [sections] içindeki her metinde [query]'yi arar.
///
/// Sonuç **belge sırasındadır** (önce 1. slayt, sonra 2.…), böylece ‹ ›
/// gezinmesi kullanıcının gördüğü sırayla ilerler. [limit] kasıtlı düşük:
/// tek harflik bir aramada binlerce eşleşme listelemek ekranı dondurur ve
/// gezinmeyi anlamsızlaştırır — sınıra dayanıldığı çağırana `hitLimit` ile
/// bildirilir (sessiz kırpma "başka eşleşme yok" sanılır).
({List<SectionHit> hits, bool hitLimit}) searchSections(
  List<String> sections,
  String query, {
  int limit = 200,
  int context = 30,
}) {
  final out = <SectionHit>[];
  if (query.trim().isEmpty) return (hits: out, hitLimit: false);
  for (var i = 0; i < sections.length; i++) {
    final text = sections[i];
    // Sınırdan BİR FAZLA istenir: "tam sınır kadar buldum" ile "daha var ama
    // kestim" ancak fazladan bir eşleşme görülerek ayrılabilir.
    for (final at in findAll(text, query, limit: limit - out.length + 1)) {
      if (out.length >= limit) return (hits: out, hitLimit: true);
      final from = (at - context).clamp(0, text.length);
      final to = (at + query.trim().length + context).clamp(0, text.length);
      final snippet = (from > 0 ? '…' : '') +
          text.substring(from, to).replaceAll('\n', ' ').trim() +
          (to < text.length ? '…' : '');
      out.add(SectionHit(i, at, snippet));
    }
  }
  return (hits: out, hitLimit: false);
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

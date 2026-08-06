/// PDF font sözlüğündeki `/Differences` dizisinde geçen **glif adları** →
/// Unicode kod noktası.
///
/// **Niye gerekli (2026-08-06, kullanıcı ekran görüntüsü):** resmî bir belgede
/// paragraf düzenleyici `T.C. ANKARA ÜNÝVERSÝTESÝ REKTÖRLÜÐÜ` gösteriyordu —
/// yani `İ` yerine `Ý`, `Ğ` yerine `Ð`. Belge ekranda DOĞRU çiziliyordu, çünkü
/// gömülü fontun kendi cmap'i 0xDD kodunu `İ` glifine bağlıyor; bizse o kodu
/// Latin-1 sanıp `Ý` okuyorduk. Fontun `/Encoding /Differences` dizisi bu
/// eşlemeyi ("221 /Idotaccent") zaten taşıyor — okumadığımız için kaçırıyorduk.
///
/// Tablo Adobe Glyph List'in (AGL) bu uygulamanın gördüğü bölümü: ASCII,
/// Latin-1, Windows tipografi karakterleri ve Türkçe harfler. Tanınmayan ad
/// için `null` dönülür (yarım anlayıp yanlış harf yazmaktansa bilmemek iyidir —
/// çağıran katman o kodu temel tablodan çözer).
library;

/// [name] glif adının Unicode kod noktası; bilinmiyorsa null.
///
/// Desteklenen biçimler:
/// * Tablodaki adlar (`Gbreve`, `quoteright`, `space`…)
/// * Tek harflik adlar (`A`, `z`) — harfin kendisi
/// * `uniXXXX` (ilk kod birimi) ve `uXXXX`…`uXXXXXX`
/// * Sonek taşıyan biçimler (`a.sc`, `one.oldstyle`) — nokta öncesi okunur
int? glyphNameToRune(String name) {
  if (name.isEmpty) return null;
  final dot = name.indexOf('.');
  final base = dot > 0 ? name.substring(0, dot) : name;
  if (base.isEmpty) return null;

  final mapped = _table[base];
  if (mapped != null) return mapped;

  if (base.length == 1) return base.codeUnitAt(0);

  if (base.startsWith('uni') && base.length >= 7) {
    final hex = base.substring(3, 7);
    final value = int.tryParse(hex, radix: 16);
    if (value != null) return value;
  }
  if (base.startsWith('u') && base.length >= 5 && base.length <= 7) {
    final value = int.tryParse(base.substring(1), radix: 16);
    if (value != null) return value;
  }
  // `g43`, `cid221`, `index12`: glif NUMARASI — hangi harf olduğu fontun
  // içinde, adında değil. Bilmiyoruz demek doğrusu.
  return null;
}

/// Ad → kod noktası. Tek harflik adlar (`A`…`z`) tabloda YOK, kod yolunda
/// çözülüyor; tablo yalnız türetilemeyen adları taşır.
const _table = <String, int>{
  // ── ASCII noktalama ve rakamlar ──────────────────────────────────────────
  'space': 0x20, 'exclam': 0x21, 'quotedbl': 0x22, 'numbersign': 0x23,
  'dollar': 0x24, 'percent': 0x25, 'ampersand': 0x26, 'quotesingle': 0x27,
  'parenleft': 0x28, 'parenright': 0x29, 'asterisk': 0x2A, 'plus': 0x2B,
  'comma': 0x2C, 'hyphen': 0x2D, 'period': 0x2E, 'slash': 0x2F,
  'zero': 0x30, 'one': 0x31, 'two': 0x32, 'three': 0x33, 'four': 0x34,
  'five': 0x35, 'six': 0x36, 'seven': 0x37, 'eight': 0x38, 'nine': 0x39,
  'colon': 0x3A, 'semicolon': 0x3B, 'less': 0x3C, 'equal': 0x3D,
  'greater': 0x3E, 'question': 0x3F, 'at': 0x40,
  'bracketleft': 0x5B, 'backslash': 0x5C, 'bracketright': 0x5D,
  'asciicircum': 0x5E, 'underscore': 0x5F, 'grave': 0x60,
  'braceleft': 0x7B, 'bar': 0x7C, 'braceright': 0x7D, 'asciitilde': 0x7E,

  // ── Windows/Adobe tipografi (WinAnsi 0x80–0x9F bölgesi) ──────────────────
  'Euro': 0x20AC, 'quotesinglbase': 0x201A, 'florin': 0x0192,
  'quotedblbase': 0x201E, 'ellipsis': 0x2026, 'dagger': 0x2020,
  'daggerdbl': 0x2021, 'circumflex': 0x02C6, 'perthousand': 0x2030,
  'Scaron': 0x0160, 'guilsinglleft': 0x2039, 'OE': 0x0152, 'Zcaron': 0x017D,
  'quoteleft': 0x2018, 'quoteright': 0x2019, 'quotedblleft': 0x201C,
  'quotedblright': 0x201D, 'bullet': 0x2022, 'endash': 0x2013,
  'emdash': 0x2014, 'tilde': 0x02DC, 'trademark': 0x2122, 'scaron': 0x0161,
  'guilsinglright': 0x203A, 'oe': 0x0153, 'zcaron': 0x017E,
  'Ydieresis': 0x0178, 'fi': 0xFB01, 'fl': 0xFB02, 'minus': 0x2212,

  // ── Latin-1 noktalama ────────────────────────────────────────────────────
  'exclamdown': 0xA1, 'cent': 0xA2, 'sterling': 0xA3, 'currency': 0xA4,
  'yen': 0xA5, 'brokenbar': 0xA6, 'section': 0xA7, 'dieresis': 0xA8,
  'copyright': 0xA9, 'ordfeminine': 0xAA, 'guillemotleft': 0xAB,
  'logicalnot': 0xAC, 'registered': 0xAE, 'macron': 0xAF, 'degree': 0xB0,
  'plusminus': 0xB1, 'twosuperior': 0xB2, 'threesuperior': 0xB3,
  'acute': 0xB4, 'mu': 0xB5, 'paragraph': 0xB6, 'periodcentered': 0xB7,
  'cedilla': 0xB8, 'onesuperior': 0xB9, 'ordmasculine': 0xBA,
  'guillemotright': 0xBB, 'onequarter': 0xBC, 'onehalf': 0xBD,
  'threequarters': 0xBE, 'questiondown': 0xBF, 'multiply': 0xD7,
  'divide': 0xF7, 'breve': 0x02D8, 'dotaccent': 0x02D9, 'ring': 0x02DA,
  'ogonek': 0x02DB, 'hungarumlaut': 0x02DD, 'caron': 0x02C7,

  // ── Latin-1 harfler ──────────────────────────────────────────────────────
  'Agrave': 0xC0, 'Aacute': 0xC1, 'Acircumflex': 0xC2, 'Atilde': 0xC3,
  'Adieresis': 0xC4, 'Aring': 0xC5, 'AE': 0xC6, 'Ccedilla': 0xC7,
  'Egrave': 0xC8, 'Eacute': 0xC9, 'Ecircumflex': 0xCA, 'Edieresis': 0xCB,
  'Igrave': 0xCC, 'Iacute': 0xCD, 'Icircumflex': 0xCE, 'Idieresis': 0xCF,
  'Eth': 0xD0, 'Ntilde': 0xD1, 'Ograve': 0xD2, 'Oacute': 0xD3,
  'Ocircumflex': 0xD4, 'Otilde': 0xD5, 'Odieresis': 0xD6, 'Oslash': 0xD8,
  'Ugrave': 0xD9, 'Uacute': 0xDA, 'Ucircumflex': 0xDB, 'Udieresis': 0xDC,
  'Yacute': 0xDD, 'Thorn': 0xDE, 'germandbls': 0xDF,
  'agrave': 0xE0, 'aacute': 0xE1, 'acircumflex': 0xE2, 'atilde': 0xE3,
  'adieresis': 0xE4, 'aring': 0xE5, 'ae': 0xE6, 'ccedilla': 0xE7,
  'egrave': 0xE8, 'eacute': 0xE9, 'ecircumflex': 0xEA, 'edieresis': 0xEB,
  'igrave': 0xEC, 'iacute': 0xED, 'icircumflex': 0xEE, 'idieresis': 0xEF,
  'eth': 0xF0, 'ntilde': 0xF1, 'ograve': 0xF2, 'oacute': 0xF3,
  'ocircumflex': 0xF4, 'otilde': 0xF5, 'odieresis': 0xF6, 'oslash': 0xF8,
  'ugrave': 0xF9, 'uacute': 0xFA, 'ucircumflex': 0xFB, 'udieresis': 0xFC,
  'yacute': 0xFD, 'thorn': 0xFE, 'ydieresis': 0xFF,

  // ── Türkçe (CP1254'ün Latin-1'den ayrıldığı altı konum + eş adlar) ───────
  'Gbreve': 0x011E, 'gbreve': 0x011F,
  'Idotaccent': 0x0130, 'Idot': 0x0130, 'Itilde': 0x0128,
  'dotlessi': 0x0131, 'idotless': 0x0131,
  'Scedilla': 0x015E, 'scedilla': 0x015F,
  'Scommaaccent': 0x0218, 'scommaaccent': 0x0219,
  'Tcommaaccent': 0x0162, 'tcommaaccent': 0x0163,
};

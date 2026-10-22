/// **Symbol / Wingdings karakterleri → Unicode** (2026-10-22).
///
/// KÖK NEDEN (kullanıcı, Word ekran görüntüsüyle: *"normalde nokta simgesi var
/// ama bizde görülmüyor"*): Office madde imlerini ve simgeleri Symbol /
/// Wingdings yazı tiplerinin kendi kodlamasıyla yazar — Word özel kod
/// noktasıyla (U+F0B7), PowerPoint çoğu zaman Latin-1 karakteriyle ("§" =
/// Wingdings'te ▪, "Ø" = ➢, "ü" = ✓). Android'de bu yazı tipleri yok: ya ▯
/// kutusu ya da yanlış harf ("§") çiziliyordu. Word görüntüleyicisindeki
/// karşılığı `assets/word/viewer.html` → `fixSymbolFonts` (aynı tablo).
library;

const Map<int, String> _symbol = {
  0xB7: '\u2022', 0xD7: '\u22C5', 0xA7: '\u2663', 0xA8: '\u2666',
  0xA9: '\u2665', 0xAA: '\u2660', 0xAB: '\u2194', 0xAC: '\u2190',
  0xAD: '\u2191', 0xAE: '\u2192', 0xAF: '\u2193', 0xB0: '\u00B0',
  0xB1: '\u00B1', 0xB3: '\u2265', 0xA3: '\u2264', 0xB4: '\u00D7',
  0xB8: '\u00F7', 0xB9: '\u2260', 0xBB: '\u2248', 0xA5: '\u221E',
  0xD6: '\u221A', 0xE0: '\u25CA', 0xDE: '\u21D2', 0xDB: '\u21D4',
  0x2D: '\u2212', 0x2A: '\u2217', 0x22: '\u2200', 0x24: '\u2203',
};

const Map<int, String> _wingdings = {
  0x6C: '\u25CF', 0x6E: '\u25A0', 0x6F: '\u25A1', 0x71: '\u2751',
  0x72: '\u2752', 0x73: '\u2B27', 0x74: '\u29EB', 0x75: '\u25C6',
  0x76: '\u2756', 0x77: '\u2B25', 0xA7: '\u25AA', 0xA8: '\u25FB',
  0x9F: '\u2022', 0xA1: '\u25CB', 0xA4: '\u25C9', 0xD8: '\u27A2',
  0xD7: '\u27A4', 0xE0: '\u2192', 0xE8: '\u2794', 0xF0: '\u21E8',
  0xFC: '\u2713', 0xFB: '\u2717', 0xFE: '\u2611', 0xFD: '\u2612',
  0x4A: '\u263A', 0x4B: '\u2610', 0x4C: '\u2639', 0x46: '\u261E',
  0xAB: '\u2605', 0xB2: '\u2727', 0xA2: '\u25CE', 0x70: '\u25FC',
  0xF6: '\u2B60', 0xF7: '\u2B62', 0xEF: '\u21E6', 0xE7: '\u2794',
};

/// [text]i [font] yazı tipinin kodlamasından Unicode'a çevirir. Yazı tipi
/// Symbol/Wingdings değilse yalnız özel kod noktaları (U+F0xx) ele alınır.
/// [bullet]: madde imi bağlamı — tanınmayan özel karakter "•" olur.
String mapSymbolFont(String text, String? font, {bool bullet = false}) {
  final f = (font ?? '').toLowerCase();
  final Map<int, String>? table;
  if (RegExp(r'wingdings\s*[23]|webdings').hasMatch(f)) {
    table = const {}; // başka tablo: yanlış simge çizmektense "•"
  } else if (f.contains('wingdings')) {
    table = _wingdings;
  } else if (f.contains('symbol')) {
    table = _symbol;
  } else {
    table = null;
  }
  final out = StringBuffer();
  for (final c in text.runes) {
    final pua = c >= 0xF000 && c <= 0xF0FF;
    final code = pua ? c - 0xF000 : c;
    String? rep;
    if (table != null) {
      rep = table[code];
    } else if (pua) {
      rep = (code >= 0xA0 ? _symbol[code] : null) ?? _wingdings[code];
    }
    if (rep == null && pua && bullet) rep = '\u2022';
    out.write(rep ?? String.fromCharCode(c));
  }
  return out.toString();
}

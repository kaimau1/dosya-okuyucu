import 'dart:convert';

/// Metin dosyalarını doğru kodlamayla çözer.
///
/// *Niye:* strict `utf8.decode` cp1254 (Windows Türkçe) baytlarında patlayıp
/// eskiden `latin1`e düşüyordu → `ğ/ş/İ/ı` bozuk (mojibake) görünüyordu.
/// Ayrıca uygulamanın kendi yazdığı BOM'lu CSV geri açılınca ilk hücreye
/// görünmez `U+FEFF` yapışıyordu (round-trip bozulması). Bu modül ikisini de
/// çözer: BOM temizlenir, UTF-8 başarısızsa Windows-1254'e düşülür.
class TextDecode {
  /// Ham baytları metne çevirir. Sıra: baştaki UTF-8 BOM (EF BB BF) atılır →
  /// strict UTF-8 → başarısızsa Windows-1254 (Türkçe). Kalan `U+FEFF` de silinir.
  static String decode(List<int> raw) {
    final bytes = _stripBomBytes(raw);
    String out;
    try {
      out = utf8.decode(bytes); // strict: cp1254'te FormatException atar
    } on FormatException {
      out = decodeCp1254(bytes);
    }
    return stripBom(out);
  }

  /// Baştaki görünmez BOM (`U+FEFF`) karakterini siler.
  static String stripBom(String s) =>
      s.isNotEmpty && s.codeUnitAt(0) == 0xFEFF ? s.substring(1) : s;

  static List<int> _stripBomBytes(List<int> b) =>
      (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF)
          ? b.sublist(3)
          : b;

  /// Windows-1254 (Türkçe) tek-bayt kod çözücü. ISO-8859-1 ile aynıdır; yalnız
  /// 0x80–0x9F noktalama bloğu ve altı Türkçe harf (Ğ/İ/Ş/ğ/ı/ş) farklıdır.
  static String decodeCp1254(List<int> bytes) {
    final sb = StringBuffer();
    for (final b in bytes) {
      if (b < 0x80) {
        sb.writeCharCode(b);
      } else if (b >= 0xA0) {
        sb.writeCharCode(_high[b] ?? b); // 0xA0–0xFF: latin1 + Türkçe farkları
      } else {
        sb.writeCharCode(_c1[b - 0x80]); // 0x80–0x9F Windows noktalama bloğu
      }
    }
    return sb.toString();
  }

  // 0x80–0x9F → Unicode (Windows-1254). Tanımsızlar aynı kod noktasına düşer.
  static const List<int> _c1 = [
    0x20AC, 0x81, 0x201A, 0x0192, 0x201E, 0x2026, 0x2020, 0x2021, //
    0x02C6, 0x2030, 0x0160, 0x2039, 0x0152, 0x8D, 0x8E, 0x8F, //
    0x90, 0x2018, 0x2019, 0x201C, 0x201D, 0x2022, 0x2013, 0x2014, //
    0x02DC, 0x2122, 0x0161, 0x203A, 0x0153, 0x9D, 0x9E, 0x0178, //
  ];

  // 0xA0–0xFF için latin1'den sapan Türkçe harfler (diğerleri byte==Unicode).
  static const Map<int, int> _high = {
    0xD0: 0x011E, // Ğ
    0xDD: 0x0130, // İ
    0xDE: 0x015E, // Ş
    0xF0: 0x011F, // ğ
    0xFD: 0x0131, // ı
    0xFE: 0x015F, // ş
  };
}

/// **Satır sonu biçimi** — CRLF mi, LF mi?
///
/// ## Kök neden (2026-09-06 denetim turu)
/// Metin düzenleyici dosyayı okurken satır sonlarını olduğu gibi alıyor ama
/// Flutter'ın `TextField`i her satır sonunu `\n`e indirger. Kaydederken de
/// `\n` yazılıyordu: **Windows'ta üretilmiş bir dosya (CRLF) tek bir harf
/// değiştirilse bile baştan sona değişmiş oluyordu.** Sonuçları gerçek:
/// - dosyayı Not Defteri'nde açan kullanıcı satırların birleştiğini görüyor
///   (eski sürümlerde) ya da git/diff bütün dosyayı değişmiş gösteriyor,
/// - `.bat`, `.csv`, `.ini` gibi Windows dünyasından gelen dosyalar bozuluyor.
///
/// Çözüm: dosyayı açarken biçimi ANLA, kaydederken geri uygula.
enum LineEnding {
  /// `\n` — Android/Linux/macOS.
  lf('\n'),

  /// `\r\n` — Windows.
  crlf('\r\n'),

  /// `\r` — klasik Mac OS (9 ve öncesi). Nadir ama var: eski dosyalar.
  cr('\r');

  final String sequence;
  const LineEnding(this.sequence);
}

abstract final class LineEndings {
  /// Metindeki baskın satır sonunu bulur.
  ///
  /// Karışık dosyalar var (bir kısmı CRLF, bir kısmı LF): **çoğunluk**
  /// kazanır, çünkü bir dosyayı iki biçimde birden kaydedemeyiz ve
  /// çoğunluğu korumak en az değişiklik demek. Hiç satır sonu yoksa
  /// platformun doğal biçimi ([lf]) kullanılır.
  static LineEnding detect(String text) {
    var crlf = 0;
    var lf = 0;
    var cr = 0;
    for (var i = 0; i < text.length; i++) {
      final ch = text.codeUnitAt(i);
      if (ch == 0x0D) {
        if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) {
          crlf++;
          i++;
        } else {
          cr++;
        }
      } else if (ch == 0x0A) {
        lf++;
      }
    }
    if (crlf == 0 && lf == 0 && cr == 0) return LineEnding.lf;
    if (crlf >= lf && crlf >= cr) return LineEnding.crlf;
    if (lf >= cr) return LineEnding.lf;
    return LineEnding.cr;
  }

  /// Her satır sonunu `\n`e indirger (düzenleyiciye verilecek biçim).
  static String toLf(String text) =>
      text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  /// `\n`leri [ending] biçimine çevirir (diske yazılacak biçim).
  static String apply(String text, LineEnding ending) {
    if (ending == LineEnding.lf) return text;
    return toLf(text).replaceAll('\n', ending.sequence);
  }
}

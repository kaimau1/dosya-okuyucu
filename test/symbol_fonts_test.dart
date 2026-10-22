import 'package:dosya_okuyucu/core/symbol_fonts.dart';
import 'package:flutter_test/flutter_test.dart';

/// Office'in Symbol/Wingdings madde imleri Android'de ▯ ya da yanlış harf
/// ("§") çiziliyordu (kullanıcı 2026-10-22, Word ekran görüntüsü).
void main() {
  test('Word: özel kod noktası + yazı tipi', () {
    expect(mapSymbolFont('\uF0B7', 'Symbol', bullet: true), '\u2022');
    expect(mapSymbolFont('\uF0A7', 'Wingdings', bullet: true), '\u25AA');
    expect(mapSymbolFont('\uF0D8', 'Wingdings', bullet: true), '\u27A2');
    expect(mapSymbolFont('\uF0FC', 'Wingdings', bullet: true), '\u2713');
  });

  test('PowerPoint: Latin-1 karakter + Wingdings/Symbol', () {
    expect(mapSymbolFont('\u00A7', 'Wingdings', bullet: true), '\u25AA');
    expect(mapSymbolFont('\u00D8', 'Wingdings', bullet: true), '\u27A2');
    expect(mapSymbolFont('\u00B7', 'Symbol', bullet: true), '\u2022');
    expect(mapSymbolFont('v', 'Wingdings', bullet: true), '\u2756');
  });

  test('yazı tipi bilinmiyorsa yalnız özel kod noktası çevrilir', () {
    expect(mapSymbolFont('\u2022', 'Arial', bullet: true), '\u2022');
    expect(mapSymbolFont('-', null, bullet: true), '-');
    expect(mapSymbolFont('\uF0B7', null, bullet: true), '\u2022');
    // Wingdings 2'nin tablosu başka: yanlış simge yerine "•".
    expect(mapSymbolFont('\uF097', 'Wingdings 2', bullet: true), '\u2022');
    // Madde imi değilse tanınmayan özel karakter olduğu gibi kalır.
    expect(mapSymbolFont('\uF001', null), '\uF001');
  });
}

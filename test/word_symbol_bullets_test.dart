import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Kullanıcı 2026-10-22 (ekran görüntüsüyle): *"Word'te normalde nokta simgesi
/// var ama bizde görülmüyor"*. Word madde imini Symbol yazı tipinin U+F0B7
/// özel kod noktasıyla yazar; Android'de Symbol yok \u2192 \u25AF. Görüntüleyici
/// çizimden SONRA bu karakterleri Unicode'a çevirir.
///
/// Gerçek tarayıcı denetimi (CI'da koşmaz): `tool/check_word_bridge.js`
/// (örnek belge `test/fixtures/office/madde_imleri.docx`).
void main() {
  final html = File('assets/word/viewer.html').readAsStringSync();

  test('çizimden sonra fixSymbolFonts çağrılır', () {
    final then = html.indexOf('}).then(function () {');
    expect(then, greaterThan(0));
    expect(html.indexOf('fixSymbolFonts();', then), greaterThan(then));
    expect(html, contains('function fixSymbolFonts()'));
  });

  test('sık madde imleri tabloda', () {
    // Symbol \u2022, Wingdings \u25AA \u27A2 \u2713 \u25A0 \u2756 \u25CF
    for (final pair in [
      ['0xB7', r'\u2022'],
      ['0xA7', r'\u25AA'],
      ['0xD8', r'\u27A2'],
      ['0xFC', r'\u2713'],
      ['0x6E', r'\u25A0'],
      ['0x76', r'\u2756'],
      ['0x6C', r'\u25CF'],
    ]) {
      expect(html, contains("${pair[0]}: '${pair[1]}'"), reason: pair[0]);
    }
  });

  test('düzenlemede özgün karakter korunur (data-fk-sym)', () {
    expect(html, contains("node.getAttribute('data-fk-sym')"));
    expect(File('test/fixtures/office/madde_imleri.docx').existsSync(), isTrue);
  });
}

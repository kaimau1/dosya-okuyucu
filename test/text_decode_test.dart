import 'dart:convert';

import 'package:dosya_okuyucu/services/text_decode.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TextDecode.decode', () {
    test('geçerli UTF-8 Türkçe aynen döner', () {
      final bytes = utf8.encode('şğıİÖÇ metni');
      expect(TextDecode.decode(bytes), 'şğıİÖÇ metni');
    });

    test('UTF-8 BOM (EF BB BF) atılır', () {
      final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('başlık')];
      expect(TextDecode.decode(bytes), 'başlık');
    });

    test('Windows-1254 Türkçe harfler doğru çözülür', () {
      // cp1254: ı=0xFD, ş=0xFE, ğ=0xF0 — bunlar geçersiz UTF-8 → cp1254'e düşer.
      final bytes = [0x49, 0xFD, 0xFE, 0xF0]; // I ı ş ğ
      expect(TextDecode.decode(bytes), 'Iışğ');
    });
  });

  group('TextDecode.stripBom', () {
    test('baştaki U+FEFF silinir', () {
      expect(TextDecode.stripBom('﻿merhaba'), 'merhaba');
    });

    test('BOM yoksa değişmez', () {
      expect(TextDecode.stripBom('merhaba'), 'merhaba');
    });
  });

  group('TextDecode.decodeCp1254', () {
    test('altı Türkçe harf', () {
      final bytes = [0xD0, 0xDD, 0xDE, 0xF0, 0xFD, 0xFE];
      expect(TextDecode.decodeCp1254(bytes), 'ĞİŞğış');
    });

    test('ASCII kısım aynen', () {
      expect(TextDecode.decodeCp1254(utf8.encode('abc123')), 'abc123');
    });
  });

  group('TextDecode.encodeCp1254', () {
    test('Türkçe harfler doğru bayta çevrilir', () {
      expect(TextDecode.encodeCp1254('ĞİŞğış'),
          [0xD0, 0xDD, 0xDE, 0xF0, 0xFD, 0xFE]);
    });

    test('ASCII aynen', () {
      expect(TextDecode.encodeCp1254('abc'), [0x61, 0x62, 0x63]);
    });

    test('round-trip: encode → decode aynı metni verir', () {
      const s = 'Işık çöl ĞİŞ ğış test 123';
      expect(TextDecode.decodeCp1254(TextDecode.encodeCp1254(s)), s);
    });

    test('cp1254 dışı karakter ? olur', () {
      // Kiril 'Д' cp1254'te yok.
      expect(TextDecode.encodeCp1254('Д'), [0x3F]);
    });
  });
}

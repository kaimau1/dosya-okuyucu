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

  group('UTF-16 (2026-09-06 denetim turu)', () {
    // Windows Not Defteri'nin "Unicode" seçeneği ve Excel'in "Unicode Metin"
    // dışa aktarması UTF-16 LE yazıyor. Eskiden strict UTF-8 patlıyor,
    // cp1254'e düşülüyor ve her harfin arasına görünmez bir NUL giriyordu.
    List<int> utf16le(String text) => [
          0xFF, 0xFE,
          for (final unit in text.codeUnits) ...[unit & 0xFF, unit >> 8],
        ];
    List<int> utf16be(String text) => [
          0xFE, 0xFF,
          for (final unit in text.codeUnits) ...[unit >> 8, unit & 0xFF],
        ];

    test('küçük-endian UTF-16 doğru çözülür', () {
      expect(TextDecode.decode(utf16le('Merhaba şğıİÖÇ')), 'Merhaba şğıİÖÇ');
    });

    test('büyük-endian UTF-16 doğru çözülür', () {
      expect(TextDecode.decode(utf16be('Satır1\nSatır2')), 'Satır1\nSatır2');
    });

    test('çözülen metinde NUL YOK (eski hatanın izi)', () {
      final out = TextDecode.decode(utf16le('abc'));
      expect(out.contains('\u0000'), isFalse);
      expect(out.length, 3);
    });

    test('BOM temizleniyor', () {
      expect(TextDecode.decode(utf16le('x')).codeUnitAt(0), 0x78);
    });

    test('yalnız BOM olan dosya boş metin verir', () {
      expect(TextDecode.decode([0xFF, 0xFE]), '');
    });

    test('kodlama adı ekranda gösterilebilir', () {
      expect(TextDecode.describeEncoding(utf16le('a')), 'UTF-16 LE');
      expect(TextDecode.describeEncoding(utf16be('a')), 'UTF-16 BE');
      expect(TextDecode.describeEncoding([0xEF, 0xBB, 0xBF, 0x61]),
          'UTF-8 (BOM)');
      expect(TextDecode.describeEncoding('düz'.codeUnits.isEmpty ? [] : [0x61]),
          'UTF-8');
      // 0xFE tek başına geçerli UTF-8 değil → cp1254 varsayılıyor.
      expect(TextDecode.describeEncoding([0x61, 0xFE]), 'Windows-1254');
    });

    test('UTF-16 SANILMAYAN düz metin bozulmaz', () {
      // 0xFF ile başlamayan her şey eski yoldan gider.
      expect(TextDecode.decode('merhaba'.codeUnits), 'merhaba');
    });
  });
}

import 'dart:typed_data';

import 'package:dosya_okuyucu/services/legacy_text.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _utf16le(String s) {
  final out = <int>[];
  for (final c in s.codeUnits) {
    out.add(c & 0xFF);
    out.add((c >> 8) & 0xFF);
  }
  return Uint8List.fromList(out);
}

void main() {
  group('LegacyText — ikili stream\'den en iyi çaba metin', () {
    test('gömülü UTF-16LE metni çıkarır (Türkçe dahil)', () {
      final text = _utf16le('Merhaba Dünya bu bir test belgesidir');
      final bytes = Uint8List.fromList([
        0, 0, 0, 0, // ikili gürültü (kabul edilmez)
        ...text,
        0, 0, 0, 0,
      ]);
      final out = LegacyText.extractFromStream(bytes);
      expect(out, isNotNull);
      expect(out, contains('Merhaba'));
      expect(out, contains('Dünya'));
      expect(out, contains('belgesidir'));
    });

    test('gömülü CP1252 (tek bayt) metni çıkarır', () {
      final ascii = 'Bu eski dosyada duz metin var'.codeUnits;
      final bytes = Uint8List.fromList([1, 2, 255, ...ascii, 0, 0]);
      final out = LegacyText.extractFromStream(bytes);
      expect(out, isNotNull);
      expect(out, contains('duz metin'));
    });

    test('metin yoksa null', () {
      final bytes = Uint8List.fromList(List.filled(64, 0));
      expect(LegacyText.extractFromStream(bytes), isNull);
    });
  });
}

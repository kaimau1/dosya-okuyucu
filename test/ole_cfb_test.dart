import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/ole_cfb.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OleFile — OLE2 Compound File okuma', () {
    late Uint8List bytes;

    setUpAll(() {
      bytes = File('test/fixtures/ole_sample.cfb').readAsBytesSync();
    });

    test('OLE imzası tanınır; zip tanınmaz', () {
      expect(OleFile.looksLikeOle(bytes), isTrue);
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(OleFile.looksLikeOle(zip), isFalse);
    });

    test('küçük stream (mini-FAT) doğru okunur', () {
      final ole = OleFile.tryParse(bytes);
      expect(ole, isNotNull);
      final small = ole!.stream('SmallStream');
      expect(small, isNotNull);
      expect(String.fromCharCodes(small!), 'HELLO-mini');
    });

    test('büyük stream (normal FAT zinciri) tam ve doğru okunur', () {
      final ole = OleFile.tryParse(bytes)!;
      final big = ole.stream('BigStream');
      expect(big, isNotNull);
      expect(big!.length, 5000); // zincir + boyuta kırpma
      // Üretim deseni: byte i = (i*7) % 251.
      for (final i in [0, 1, 4, 511, 512, 4999]) {
        expect(big[i], (i * 7) % 251, reason: 'byte $i');
      }
    });

    test('stream adı büyük/küçük harf duyarsız; firstOf çalışır', () {
      final ole = OleFile.tryParse(bytes)!;
      expect(ole.stream('bigstream'), isNotNull);
      expect(ole.firstOf(['Yok', 'SmallStream']), isNotNull);
      expect(ole.firstOf(['Yok1', 'Yok2']), isNull);
    });

    test('bozuk/OLE olmayan bayt → tryParse null', () {
      expect(OleFile.tryParse(Uint8List.fromList([1, 2, 3, 4])), isNull);
    });
  });
}

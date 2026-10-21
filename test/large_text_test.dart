import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/large_text.dart';
import 'package:dosya_okuyucu/services/text_decode.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 9 — büyük metin dosyasının parça parça okunması.
void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('large_text'));
  tearDown(() => dir.deleteSync(recursive: true));

  File write(String name, List<int> bytes) =>
      File('${dir.path}/$name')..writeAsBytesSync(bytes);

  test('UTF-8: satır sayısı ve rastgele satır okuma', () async {
    final text = [for (var i = 1; i <= 1000; i++) 'satır $i — ğüşıöç'].join('\n');
    final f = LargeTextFile.openSync(write('a.txt', utf8.encode(text)).path);
    expect(f.encoding, LargeTextEncoding.utf8);
    expect(f.lineCount, 1000);
    expect(await f.lines(0, 2), ['satır 1 — ğüşıöç', 'satır 2 — ğüşıöç']);
    expect(await f.lines(998, 10), ['satır 999 — ğüşıöç', 'satır 1000 — ğüşıöç']);
  });

  test('CRLF satır sonları ve sondaki satır sonu', () async {
    final f = LargeTextFile.openSync(
        write('b.txt', utf8.encode('bir\r\niki\r\nüç\r\n')).path);
    expect(f.lineCount, 3);
    expect(await f.lines(0, 5), ['bir', 'iki', 'üç']);
  });

  test('UTF-8 BOM satırın parçası değil', () async {
    final f = LargeTextFile.openSync(
        write('c.txt', [0xEF, 0xBB, 0xBF, ...utf8.encode('başlık\nx')]).path);
    expect(await f.lines(0, 1), ['başlık']);
  });

  test('Windows-1254 dosya Türkçe okunur', () async {
    final f = LargeTextFile.openSync(write('d.txt',
            TextDecode.encodeCp1254('Işık\nŞubat ğ'))
        .path);
    expect(f.encoding, LargeTextEncoding.cp1254);
    expect(await f.lines(0, 2), ['Işık', 'Şubat ğ']);
  });

  test('UTF-16 LE: iki baytlık satır sonu, parça sınırında da', () async {
    // 1 MB'lık okuma parçasının sınırına düşen satır sonları da sayılmalı.
    final lines = [for (var i = 0; i < 40000; i++) 'Satır $i ş'];
    final units = lines.join('\n').codeUnits;
    final bytes = <int>[0xFF, 0xFE];
    for (final u in units) {
      bytes..add(u & 0xFF)..add(u >> 8);
    }
    final f = LargeTextFile.openSync(write('e.txt', bytes).path);
    expect(f.encoding, LargeTextEncoding.utf16le);
    expect(f.lineCount, 40000);
    expect(await f.lines(0, 1), ['Satır 0 ş']);
    expect(await f.lines(39999, 1), ['Satır 39999 ş']);
    expect(await f.lines(25000, 1), ['Satır 25000 ş']);
  });

  test('boş dosya', () async {
    final f = LargeTextFile.openSync(write('f.txt', const []).path);
    expect(f.lineCount, 0);
    expect(await f.lines(0, 5), isEmpty);
  });

  test('eşik 5 MB', () {
    expect(LargeTextFile.threshold, 5 * 1024 * 1024);
  });
}

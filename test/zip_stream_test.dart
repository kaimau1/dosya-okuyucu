import 'dart:io';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/remote/zip_stream.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Tek akış ZIP paketi (2026-10-29): boyu önceden bilinir, standart bir
/// okuyucu açabilir ve istenen bayttan başlatılabilir (devam).
void main() {
  late Directory temp;
  setUp(() => temp = Directory.systemTemp.createTempSync('zips'));
  tearDown(() => temp.deleteSync(recursive: true));

  Future<List<int>> collect(Stream<List<int>> s) async =>
      [for (final c in await s.toList()) ...c];

  test('paket boyu doğru, ZIP okuyucusu açıyor, ad UTF-8', () async {
    final dir = Directory(p.join(temp.path, 'Klasör'))..createSync();
    File(p.join(dir.path, 'ğü.txt')).writeAsStringSync('merhaba');
    Directory(p.join(dir.path, 'alt')).createSync();
    File(p.join(dir.path, 'alt', 'b.bin'))
        .writeAsBytesSync(List.generate(100000, (i) => i * 7 % 256));
    final single = File(p.join(temp.path, 'tek.txt'))..writeAsStringSync('t');
    final zip = (await ZipStream.of([dir.path, single.path]))!;
    final bytes = await collect(zip.open());
    expect(bytes.length, zip.length);
    final archive = ZipDecoder().decodeBytes(bytes, verify: true);
    final names = archive.files.map((f) => f.name).toSet();
    expect(names, {'Klasör/ğü.txt', 'Klasör/alt/b.bin', 'tek.txt'});
    final b = archive.files.firstWhere((f) => f.name == 'Klasör/alt/b.bin');
    expect(b.content as List<int>,
        File(p.join(dir.path, 'alt', 'b.bin')).readAsBytesSync());
  });

  test('ortadan başlatılan akış = tam akışın kuyruğu', () async {
    final a = File(p.join(temp.path, 'a.bin'))
      ..writeAsBytesSync(List.generate(50000, (i) => i % 256));
    final b = File(p.join(temp.path, 'b.bin'))
      ..writeAsBytesSync(List.generate(30000, (i) => (i * 3) % 256));
    final zip = (await ZipStream.of([a.path, b.path]))!;
    final full = await collect(zip.open());
    for (final start in [0, 1, 29, 30, 5000, 50060, 80100, full.length - 3]) {
      final tail = await collect(zip.open(start: start));
      expect(tail, full.sublist(start), reason: 'başlangıç $start');
    }
  });
}

import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **G7.1 artığı** (2026-11-12): `.bz2` / `.xz` çıkarma eskiden sınırsızdı
/// ve tar olmayan tek dosya hiç açılmıyordu. Artık izolatta, bayt
/// bütçesiyle; tek dosya da tar da açılır.
void main() {
  late Directory tmp;

  setUpAll(() {
    tmp = Directory.systemTemp.createTempSync('archive_legacy');
  });

  tearDownAll(() => removeTempDir(tmp));

  String write(String name, List<int> bytes) {
    final f = File(p.join(tmp.path, name))..writeAsBytesSync(bytes);
    return f.path;
  }

  Directory dest(String name) =>
      Directory(p.join(tmp.path, name))..createSync();

  test('tek dosyalık .bz2 açılır', () async {
    final src = write('not.txt.bz2',
        BZip2Encoder().encodeBytes('merhaba dunya'.codeUnits));
    final target = await ArchiveOps.extract(src, destDir: dest('h1').path);
    expect(File(p.join(target, 'not.txt')).readAsStringSync(), 'merhaba dunya');
  });

  test('tek dosyalık .xz açılır', () async {
    final src = write('veri.bin.xz', XZEncoder().encodeBytes(List.filled(1000, 7)));
    final target = await ArchiveOps.extract(src, destDir: dest('h2').path);
    expect(File(p.join(target, 'veri.bin')).lengthSync(), 1000);
  });

  test('içi tar olan .bz2 klasör olarak açılır', () async {
    final tar = Archive()
      ..add(ArchiveFile.bytes('a.txt', 'A'.codeUnits))
      ..add(ArchiveFile.bytes('alt/b.txt', 'B'.codeUnits));
    final src = write('paket.tar.bz2',
        BZip2Encoder().encodeBytes(TarEncoder().encodeBytes(tar)));
    final target = await ArchiveOps.extract(src, destDir: dest('h3').path);
    expect(File(p.join(target, 'a.txt')).readAsStringSync(), 'A');
    expect(File(p.join(target, 'alt', 'b.txt')).readAsStringSync(), 'B');
  });

  test('.bz2 bombası sınırda durur, çıktı kalmaz', () async {
    final src = write('bomba.bin.bz2',
        BZip2Encoder().encodeBytes(Uint8List(8 * 1024 * 1024)));
    expect(File(src).lengthSync(), lessThan(64 * 1024));
    final out = dest('h4');
    await expectLater(
      ArchiveOps.extract(src, destDir: out.path, maxBytes: 1024 * 1024),
      throwsA(isA<ArchiveError>()
          .having((e) => e.failure, 'failure', ArchiveFailure.tooLarge)),
    );
    expect(out.listSync(), isEmpty, reason: 'yarım klasör silindi');
  });

  test('.xz bombası sınırda durur', () async {
    final src = write('bomba.bin.xz', XZEncoder().encodeBytes(Uint8List(8 * 1024 * 1024)));
    final out = dest('h5');
    await expectLater(
      ArchiveOps.extract(src, destDir: out.path, maxBytes: 1024 * 1024),
      throwsA(isA<ArchiveError>()
          .having((e) => e.failure, 'failure', ArchiveFailure.tooLarge)),
    );
    expect(out.listSync(), isEmpty);
  });

  test('bozuk .bz2 tiplenmiş hata verir', () async {
    final src = write('bozuk.txt.bz2', [0x42, 0x5A, 0x68, 0x39, 1, 2, 3, 4, 5]);
    await expectLater(
      ArchiveOps.extract(src, destDir: dest('h6').path),
      throwsA(isA<ArchiveError>()),
    );
  });
}

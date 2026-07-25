import 'dart:io';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:dosya_okuyucu/services/fm/storage_stats.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('df çözümleme', () {
    test('standart çıktı (toplam, boş) bayta çevrilir', () {
      const output = '''
Filesystem     1K-blocks      Used Available Use% Mounted on
/dev/fuse      120000000  80000000  40000000  67% /storage/emulated
''';
      final parsed = StorageStats.parseDf(output);
      expect(parsed, isNotNull);
      expect(parsed!.$1, 120000000 * 1024);
      expect(parsed.$2, 40000000 * 1024);
    });

    test('uzun aygıt adı satırı kaydırdığında da okunur', () {
      const output = '''
Filesystem                          1K-blocks    Used Available Use% Mounted on
/dev/block/dm-4-cok-uzun-bir-aygit-adi
                                      2000000 1500000    500000  75% /storage
''';
      final parsed = StorageStats.parseDf(output);
      expect(parsed!.$1, 2000000 * 1024);
      expect(parsed.$2, 500000 * 1024);
    });

    test('anlamsız çıktıda null döner (doluluk çubuğu gizlenir)', () {
      expect(StorageStats.parseDf(''), isNull);
      expect(StorageStats.parseDf('df: /yok: No such file'), isNull);
    });
  });

  group('arşiv', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_archive_test');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('canExtract: zip evet, rar hayır', () {
      expect(ArchiveOps.canExtract('/a/b.zip'), isTrue);
      expect(ArchiveOps.canExtract('/a/b.TGZ'), isTrue);
      expect(ArchiveOps.canExtract('/a/b.rar'), isFalse);
      expect(ArchiveOps.canExtract('/a/b.pdf'), isFalse);
    });

    test('zip → extract turu içeriği korur', () async {
      final dir = Directory(p.join(tmp.path, 'kaynak'))..createSync();
      File(p.join(dir.path, 'not.txt')).writeAsStringSync('merhaba');
      Directory(p.join(dir.path, 'ic')).createSync();
      File(p.join(dir.path, 'ic', 'derin.txt')).writeAsStringSync('derin');

      final zipPath = await ArchiveOps.zip([dir.path], tmp.path,
          archiveName: 'yedek');
      expect(p.basename(zipPath), 'yedek.zip');
      expect(File(zipPath).lengthSync(), greaterThan(0));

      final names = await ArchiveOps.peekZip(zipPath);
      expect(names.any((n) => n.endsWith('not.txt')), isTrue);

      final hedef = Directory(p.join(tmp.path, 'cikti'))..createSync();
      final target = await ArchiveOps.extract(zipPath, destDir: hedef.path);

      final extracted = Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(extracted, containsAll(<String>['not.txt', 'derin.txt']));
    });

    test('desteklenmeyen biçimde açıklayıcı hata', () async {
      final rar = File(p.join(tmp.path, 'a.rar'))..writeAsStringSync('x');
      await expectLater(
        ArchiveOps.extract(rar.path),
        throwsA(isA<FileSystemException>()),
      );
    });
  });
}

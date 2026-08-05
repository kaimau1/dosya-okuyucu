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
    });

    test('reklam kapasitesi: 464 GiB\'lık /data → 512 GB', () {
      // Kullanıcı bulgusu 2026-08-05: 512 GB'lık telefonda "464 GB" yazıyordu.
      // `df` yalnız /data'yı ölçüyor; Android'in kendisi (ve diğer dosya
      // yöneticileri) yuvarlanmış REKLAM kapasitesini gösteriyor.
      const fsTotal = 464 * 1024 * 1024 * 1024; // df'in verdiği ham boyut
      expect(StorageVolume.advertisedSize(fsTotal), 512 * 1000 * 1000 * 1000);

      // AOSP FileUtils.roundStorageSize dizisi: 1,2,4…512 × 1000ⁿ
      expect(StorageVolume.advertisedSize(1), 1);
      expect(StorageVolume.advertisedSize(3), 4);
      expect(StorageVolume.advertisedSize(60 * 1000 * 1000 * 1000),
          64 * 1000 * 1000 * 1000);
      expect(StorageVolume.advertisedSize(0), 0);
      // Tam sınırda yuvarlama YUKARI kaymaz.
      expect(StorageVolume.advertisedSize(128 * 1000 * 1000 * 1000),
          128 * 1000 * 1000 * 1000);
    });

    test('kullanılan = reklam kapasitesi − gerçek boş alan', () {
      const volume = StorageVolume(
        path: '/storage/emulated/0',
        label: 'Ana bellek',
        isPrimary: true,
        totalBytes: 464 * 1024 * 1024 * 1024,
        freeBytes: 182 * 1024 * 1024 * 1024,
      );
      expect(volume.capacityBytes, 512 * 1000 * 1000 * 1000);
      // Boş alan YUVARLANMAZ: kullanıcıya olmayan yer varmış gibi gösterilemez.
      expect(volume.freeBytes, 182 * 1024 * 1024 * 1024);
      expect(volume.usedBytes, volume.capacityBytes - volume.freeBytes);
      expect((volume.usedFraction * 100).round(), 62);
      expect(StorageStats.parseDf('df: /yok: No such file'), isNull);
    });
  });

  group('arşiv', () {
    late Directory tmp;

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('fm_archive_test');
    });
    tearDown(() => tmp.deleteSync(recursive: true));

    test('canExtract: arşiv biçimleri evet, belge hayır', () {
      expect(ArchiveOps.canExtract('/a/b.zip'), isTrue);
      expect(ArchiveOps.canExtract('/a/b.TGZ'), isTrue);
      expect(ArchiveOps.canExtract('/a/b.rar'), isTrue);
      expect(ArchiveOps.canExtract('/a/b.7z'), isTrue);
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

      final listing = await ArchiveOps.list(zipPath);
      expect(listing.files.any((f) => f.path.endsWith('not.txt')), isTrue);

      final hedef = Directory(p.join(tmp.path, 'cikti'))..createSync();
      final target = await ArchiveOps.extract(zipPath, destDir: hedef.path);

      final extracted = Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .map((f) => p.basename(f.path))
          .toList();
      expect(extracted, containsAll(<String>['not.txt', 'derin.txt']));
    });

    test('bozuk/sahte arşiv sessizce geçmez, tiplenmiş hata verir', () async {
      final fake = File(p.join(tmp.path, 'a.rar'))..writeAsStringSync('x');
      await expectLater(
        ArchiveOps.extract(fake.path),
        throwsA(isA<ArchiveError>()),
      );
    });
  });
}

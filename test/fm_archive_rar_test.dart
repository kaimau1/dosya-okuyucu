import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// RAR/7z okuma yolunun gerçek arşivlerle doğrulanması.
///
/// Fixture'lar koni_archive projesinden (MIT) alınmıştır — RAR sıkıştırıcısı
/// özel mülk olduğu için bu ortamda `.rar` ÜRETİLEMEZ; bkz.
/// `test/fixtures/archive/KAYNAK.md`.
void main() {
  const fixtures = 'test/fixtures/archive';
  late Directory tmp;

  setUp(() => tmp = Directory.systemTemp.createTempSync('fm_rar_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  /// Fixture'ı geçici klasöre kopyalar (çıkarma arşivin yanına yazar).
  String copy(String name) {
    final target = p.join(tmp.path, name);
    File(p.join(fixtures, name)).copySync(target);
    return target;
  }

  group('biçim tanıma', () {
    test('rar/7z/cbr artık çıkarılabilir sayılıyor', () {
      expect(ArchiveOps.canExtract('/a/film.rar'), isTrue);
      expect(ArchiveOps.canExtract('/a/cizgi.CBR'), isTrue);
      expect(ArchiveOps.canExtract('/a/yedek.7z'), isTrue);
      expect(ArchiveOps.canExtract('/a/paket.zip'), isTrue);
      expect(ArchiveOps.canExtract('/a/belge.pdf'), isFalse);
    });

    test('çok parçalı devam ciltleri de arşiv sayılır', () {
      expect(ArchiveOps.canExtract('/a/film.r00'), isTrue);
      expect(ArchiveOps.canExtract('/a/yedek.7z.002'), isTrue);
      expect(ArchiveOps.canExtract('/a/paket.z01'), isTrue);
    });

    test('volumePath: RAR/7z/ZIP cilt adlandırma şemaları', () {
      // ad.part1.rar → part2 (basamak genişliği korunur)
      expect(ArchiveOps.volumePath('/a/film.part1.rar', 2), '/a/film.part2.rar');
      expect(
          ArchiveOps.volumePath('/a/film.part01.rar', 12), '/a/film.part12.rar');
      // ad.rar → cilt 2 = .r00, cilt 3 = .r01
      expect(ArchiveOps.volumePath('/a/film.rar', 2), '/a/film.r00');
      expect(ArchiveOps.volumePath('/a/film.rar', 4), '/a/film.r02');
      // 7z sayılı ciltler
      expect(ArchiveOps.volumePath('/a/yedek.7z.001', 3), '/a/yedek.7z.003');
      // zip
      expect(ArchiveOps.volumePath('/a/paket.zip', 2), '/a/paket.z01');
      // 1. cilt daima kaynağın kendisi
      expect(ArchiveOps.volumePath('/a/film.rar', 1), '/a/film.rar');
      // tanınmayan şema
      expect(ArchiveOps.volumePath('/a/belge.pdf', 2), isNull);
    });
  });

  group('RAR5 (normal.rar)', () {
    test('içerik listelenir: unicode ad, iç içe klasör, boş dosya', () async {
      final listing = await ArchiveOps.list(copy('normal.rar'));

      expect(listing.formatName.toLowerCase(), contains('rar'));
      expect(
        listing.files.map((f) => f.path).toSet(),
        {
          'hello.txt',
          'empty.txt',
          'nested/deep/data.bin',
          '日本語/ページ001.txt',
        },
      );
      final hello = listing.files.firstWhere((f) => f.path == 'hello.txt');
      expect(hello.size, 12);
      expect(listing.totalBytes, greaterThan(100000));
    });

    test('çıkarma: dosyalar birebir doğru içerikle diske yazılır', () async {
      final archive = copy('normal.rar');
      final target = await ArchiveOps.extract(archive, destDir: tmp.path);

      expect(p.basename(target), 'normal');
      expect(File(p.join(target, 'hello.txt')).readAsStringSync(),
          'hello, rar!\n');
      expect(File(p.join(target, 'empty.txt')).lengthSync(), 0);
      expect(File(p.join(target, 'nested', 'deep', 'data.bin')).lengthSync(),
          100000);
      expect(
        File(p.join(target, '日本語', 'ページ001.txt')).readAsStringSync(),
        'unicode page\n',
      );
    });

    test('ilerleme bildirimi dosya sayısına ulaşır', () async {
      final archive = copy('normal.rar');
      var last = 0;
      var total = 0;
      await ArchiveOps.extract(archive, destDir: tmp.path,
          onProgress: (progress) {
        last = progress.done;
        total = progress.total;
      });
      expect(total, 4);
      expect(last, 4);
    });

    test('tek dosya çıkarma (önizleme yolu)', () async {
      final archive = copy('normal.rar');
      final out = await ArchiveOps.extractOne(
          archive, 'hello.txt', p.join(tmp.path, 'onizleme'));
      expect(File(out).readAsStringSync(), 'hello, rar!\n');
    });
  });

  group('RAR4 solid (solid_rar4.rar)', () {
    test('eski RAR4 katı arşivi de çözülür', () async {
      final archive = copy('solid_rar4.rar');
      final listing = await ArchiveOps.list(archive);
      expect(listing.files, isNotEmpty);

      final target = await ArchiveOps.extract(archive, destDir: tmp.path);
      for (final item in listing.files) {
        final out = File(p.join(target, item.path));
        expect(out.existsSync(), isTrue, reason: '${item.path} çıkarılmalı');
        expect(out.lengthSync(), item.size,
            reason: '${item.path} boyutu arşivdekiyle aynı olmalı');
      }
    });
  });

  group('7z (lzma2_solid.7z)', () {
    test('listelenir ve çözülür', () async {
      final archive = copy('lzma2_solid.7z');
      final listing = await ArchiveOps.list(archive);
      expect(listing.files.map((f) => f.path), contains('hello.txt'));

      final target = await ArchiveOps.extract(archive, destDir: tmp.path);
      expect(File(p.join(target, 'hello.txt')).readAsStringSync(),
          'hello, 7z!\n');
      expect(File(p.join(target, 'nested', 'deep', 'data.bin')).lengthSync(),
          100000);
    });
  });

  group('şifreli arşiv (encrypted.rar, parola: secret)', () {
    test('parolasız listelenir ama şifreli işaretlenir', () async {
      final listing = await ArchiveOps.list(copy('encrypted.rar'));
      expect(listing.hasEncryptedEntries, isTrue);
    });

    test('parolasız çıkarma "parola gerekli" hatası verir', () async {
      final archive = copy('encrypted.rar');
      await expectLater(
        ArchiveOps.extract(archive, destDir: tmp.path),
        throwsA(isA<ArchiveError>().having((e) => e.failure, 'failure',
            ArchiveFailure.passwordRequired)),
      );
    });

    test('doğru parolayla çıkar', () async {
      final archive = copy('encrypted.rar');
      final target = await ArchiveOps.extract(archive,
          destDir: tmp.path, password: 'secret');
      final files = Directory(target)
          .listSync(recursive: true)
          .whereType<File>()
          .toList();
      expect(files, isNotEmpty);
      expect(utf8.decode(files.first.readAsBytesSync()), isNotEmpty);
    });

    test('yanlış parola sessizce bozuk dosya yazmaz, hata verir', () async {
      final archive = copy('encrypted.rar');
      await expectLater(
        ArchiveOps.extract(archive, destDir: tmp.path, password: 'yanlis'),
        throwsA(isA<ArchiveError>()),
      );
    });
  });
}

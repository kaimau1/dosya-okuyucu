import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'support/temp_dir.dart';

/// **G7.1 arşiv bombası** (2026-11-12): çıkarmada toplam açılmış boyut ve
/// giriş sayısı sınırlı; sınır aşılınca hiçbir şey kalmaz (yarım klasör
/// silinir). Sınırlar testte küçültülür — gerçek 20 GB / 200 bin.
void main() {
  late Directory tmp;
  late String zeros;
  late String many;

  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('archive_bomb');
    // 16 MB sıfır → zip'te birkaç on KB (yüksek oranlı küçük bomba).
    final big = File(p.join(tmp.path, 'sifir.bin'))
      ..writeAsBytesSync(Uint8List(16 * 1024 * 1024));
    zeros = await ArchiveOps.zip([big.path], tmp.path, archiveName: 'bomba');
    final dir = Directory(p.join(tmp.path, 'cok'))..createSync();
    for (var i = 0; i < 6; i++) {
      File(p.join(dir.path, 'd$i.txt')).writeAsStringSync('içerik $i');
    }
    many = await ArchiveOps.zip([dir.path], tmp.path, archiveName: 'cok');
  });

  tearDownAll(() => removeTempDir(tmp));

  test('zip gerçekten yüksek oranlı (test girdisi anlamlı)', () {
    expect(File(zeros).lengthSync(), lessThan(1024 * 1024));
  });

  test('toplam boyut sınırı aşılınca tooLarge, çıktı kalmaz', () async {
    final out = Directory(p.join(tmp.path, 'hedef1'))..createSync();
    await expectLater(
      ArchiveOps.extract(zeros, destDir: out.path, maxBytes: 4 * 1024 * 1024),
      throwsA(isA<ArchiveError>()
          .having((e) => e.failure, 'failure', ArchiveFailure.tooLarge)),
    );
    expect(out.listSync(), isEmpty, reason: 'yarım klasör silindi');
  });

  test('durdurulabilir yolda da sınır geçerli', () async {
    final out = Directory(p.join(tmp.path, 'hedef2'))..createSync();
    await expectLater(
      ArchiveOps.extract(zeros,
          destDir: out.path,
          maxBytes: 4 * 1024 * 1024,
          isCancelled: () => false),
      throwsA(isA<ArchiveError>()
          .having((e) => e.failure, 'failure', ArchiveFailure.tooLarge)),
    );
    expect(out.listSync(), isEmpty);
  });

  test('giriş sayısı sınırı', () async {
    final out = Directory(p.join(tmp.path, 'hedef3'))..createSync();
    await expectLater(
      ArchiveOps.extract(many, destDir: out.path, maxEntries: 3),
      throwsA(isA<ArchiveError>()
          .having((e) => e.failure, 'failure', ArchiveFailure.tooLarge)),
    );
    expect(out.listSync(), isEmpty);
  });

  test('sınır içinde olağan çıkarma bozulmaz', () async {
    final out = Directory(p.join(tmp.path, 'hedef4'))..createSync();
    final target = await ArchiveOps.extract(zeros,
        destDir: out.path, maxBytes: 64 * 1024 * 1024);
    final f = File(p.join(target, 'sifir.bin'));
    expect(f.lengthSync(), 16 * 1024 * 1024);
  });

  test('kullanıcı iletisi anlaşılır', () {
    const e = ArchiveError(ArchiveFailure.tooLarge, 'x');
    expect(e.userMessage, contains('sıkıştırma bombası'));
  });
}

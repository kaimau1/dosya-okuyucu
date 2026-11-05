import 'dart:io';
import 'dart:math';

import 'package:dosya_okuyucu/services/fm/archive_ops.dart';
import 'package:dosya_okuyucu/services/fm/file_split.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 7: bölünmüş arşiv üretimi (7-Zip cilt düzeni).
void main() {
  test('zip ciltlere bölünür, birleşince geçerli arşiv; küçükse bölünmez',
      () async {
    final dir = Directory.systemTemp.createTempSync('split');
    addTearDown(() => dir.deleteSync(recursive: true));
    final src = Directory('${dir.path}/kaynak')..createSync();
    final r = Random(7);
    // Sıkışmayan içerik: rastgele baytlar (~300 KB).
    for (var i = 0; i < 3; i++) {
      File('${src.path}/f$i.bin')
          .writeAsBytesSync(List.generate(100 * 1024, (_) => r.nextInt(256)));
    }
    final out = Directory('${dir.path}/out')..createSync();
    final parts = await ArchiveOps.compressSplit([src.path], out.path,
        volumeBytes: 128 * 1024, archiveName: 'yedek');
    expect(parts.length, greaterThanOrEqualTo(2));
    expect(parts.first, endsWith('yedek.zip.001'));
    expect(parts[1], endsWith('yedek.zip.002'));
    expect(File('${out.path}/yedek.zip').existsSync(), isFalse);
    expect(ArchiveOps.volumePath(parts.first, 2), parts[1]);

    final joined = await FileSplit.join(parts.first,
        destPath: '${dir.path}/birlesik.zip');
    final listing = await ArchiveOps.list(joined);
    expect(listing.items.where((e) => !e.isDir).length, 3);

    final small = await ArchiveOps.compressSplit(
        ['${src.path}/f0.bin'], out.path,
        volumeBytes: 10 << 20, archiveName: 'tek');
    expect(small.single, endsWith('tek.zip'));
  });
}

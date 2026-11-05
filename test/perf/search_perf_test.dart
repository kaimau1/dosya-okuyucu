@Tags(['perf'])
library;

import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/content_index.dart';
import 'package:dosya_okuyucu/services/fm/fs_scan.dart';
import 'package:dosya_okuyucu/services/fm/search_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Faz 41 ölçütü:** 50 bin dosyada arama < 1 sn (dizinli). CI makinesi
/// telefondan hızlı ama tavan geniş; gerileme (dizinsiz tarama, satır başına
/// yeniden katlama …) bu tavanı rahatça aşar.
void main() {
  test('ad dizini: 50 bin satırda sorgu < 1 sn', () {
    final dir = Directory.systemTemp.createTempSync('srch_perf');
    addTearDown(() => dir.deleteSync(recursive: true));
    final f = File('${dir.path}/search_index.tsv');
    final sink = StringBuffer();
    for (var i = 0; i < 50000; i++) {
      final name = 'Belge ${i % 977} fotoğraf_$i.${i % 3 == 0 ? 'pdf' : 'jpg'}';
      sink.writeln(encodeIndexRow(FsEntry(
          path: '/storage/emulated/0/Klasör${i % 200}/$name',
          name: name,
          isDir: false,
          sizeBytes: 1000 + i,
          modifiedMs: 1700000000000 + i)));
    }
    f.writeAsStringSync(sink.toString());
    final sw = Stopwatch()..start();
    final hits = SearchIndex.querySyncForTest(f.path, 'FOTOĞRAF_4999');
    sw.stop();
    expect(hits, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(1000),
        reason: '50 bin satır: ${sw.elapsedMilliseconds} ms');
  });

  test('içerik dizini: 50 bin belgede sorgu < 1 sn', () {
    final docs = [
      for (var i = 0; i < 50000; i++)
        ('/d/$i.txt', 'kira sözleşmesi madde $i ödeme tarihi ${i % 31}',
            'Kira sözleşmesi madde $i ödeme tarihi ${i % 31}'),
    ];
    final sw = Stopwatch()..start();
    final hits = ContentIndex.runQuery((docs, ['madde', '4999'], 200));
    sw.stop();
    expect(hits, isNotEmpty);
    expect(sw.elapsedMilliseconds, lessThan(1000),
        reason: '50 bin belge: ${sw.elapsedMilliseconds} ms');
  });
}

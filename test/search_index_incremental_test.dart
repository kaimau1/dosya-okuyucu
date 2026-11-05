import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fs_events.dart';
import 'package:dosya_okuyucu/services/fm/search_index.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 41 / 8 (perf): arama dizini kopyala/taşıda ARTIMLI güncellenir.
void main() {
  test('taşıma: eski yol düşer, yeni yol (klasör içi dahil) eklenir', () {
    final dir = Directory.systemTemp.createTempSync('sidx');
    addTearDown(() => dir.deleteSync(recursive: true));
    final index = File('${dir.path}/search_index.tsv')..writeAsStringSync('');
    final a = Directory('${dir.path}/A')..createSync();
    File('${a.path}/rapor.pdf').writeAsStringSync('x');
    expect(SearchIndex.appendSyncForTest(index.path, [a.path]), 2);
    expect(SearchIndex.querySyncForTest(index.path, 'rapor'), hasLength(1));

    // Taşı: A → B
    final b = Directory('${dir.path}/B');
    a.renameSync(b.path);
    expect(SearchIndex.forgetSyncForTest(index.path, [a.path]), 0);
    expect(SearchIndex.appendSyncForTest(index.path, [b.path]), 2);
    final hits = SearchIndex.querySyncForTest(index.path, 'rapor');
    expect(hits.single.path, '${b.path}/rapor.pdf');
  });

  test('dizinlenmiş değişiklik işaretlenir', () {
    FsEvents.changed(const [], true);
    expect(FsEvents.indexedVersion, FsEvents.version.value);
    FsEvents.changed();
    expect(FsEvents.indexedVersion, isNot(FsEvents.version.value));
  });
}

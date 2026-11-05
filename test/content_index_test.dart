import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/content_index.dart';
import 'package:dosya_okuyucu/services/fm/saved_searches.dart';
import 'package:flutter_test/flutter_test.dart';

FsEntry _e(String path, int m) => FsEntry(
    path: path, name: path.split('/').last, isDir: false, sizeBytes: 10, modifiedMs: m);

/// Faz 41 / 3: içerik dizini (artımlı, durdurulabilir) + kayıtlı aramalar.
void main() {
  late Directory dir;
  setUp(() => dir = Directory.systemTemp.createTempSync('cidx'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('artımlı: değişmeyen yeniden okunmaz, silinen düşer, diskten geri gelir',
      () async {
    final idx = ContentIndex(File('${dir.path}/c.jsonl'));
    final reads = <String>[];
    Future<String?> textOf(FsEntry e) async {
      reads.add(e.path);
      return e.path.endsWith('a.txt')
          ? 'İstanbul KİRA sözleşmesi\nikinci satır ödeme'
          : 'fatura elektrik';
    }

    var n = await idx.update([_e('/r/a.txt', 1), _e('/r/b.pdf', 1)],
        textOf: textOf, maxCharsPerFile: 1000, maxTotalChars: 1 << 20);
    expect(n, 2);
    n = await idx.update([_e('/r/a.txt', 1), _e('/r/b.pdf', 2)],
        textOf: textOf, maxCharsPerFile: 1000, maxTotalChars: 1 << 20);
    expect(n, 1);
    expect(reads, ['/r/a.txt', '/r/b.pdf', '/r/b.pdf']);

    final hits = await idx.query('kira ÖDEME');
    expect(hits.single.path, '/r/a.txt');
    expect(hits.single.line, 1);
    expect(await idx.query('istanbul'), hasLength(1)); // İ → i katlama

    await idx.update([_e('/r/b.pdf', 2)],
        textOf: textOf, maxCharsPerFile: 1000, maxTotalChars: 1 << 20);
    final again = ContentIndex(File('${dir.path}/c.jsonl'));
    await again.load();
    expect(again.length, 1);
    expect((await again.query('elektrik')).single.path, '/r/b.pdf');
  });

  test('pil tasarrufunda durur; null metin sonraki tura kalır', () async {
    final idx = ContentIndex(File('${dir.path}/c.jsonl'));
    var calls = 0;
    final n = await idx.update(
        [for (var i = 0; i < 5; i++) _e('/r/$i.txt', i)],
        textOf: (e) async => 'x',
        shouldPause: () async => ++calls > 2,
        maxCharsPerFile: 100,
        maxTotalChars: 1000);
    expect(n, 2);
    final skip = await idx.update([_e('/r/z.jpg', 1)],
        textOf: (e) async => null, maxCharsPerFile: 100, maxTotalChars: 1000);
    expect(skip, 0);
  });

  test('kayıtlı aramalar: aynı sorgu+kip tekleşir, kip ayrı tutulur', () {
    var l = <SavedSearch>[];
    l = SavedSearches.add(l, const SavedSearch('Fatura', 'fatura'));
    l = SavedSearches.add(
        l, const SavedSearch('Fatura içi', 'fatura', inContent: true));
    l = SavedSearches.add(l, const SavedSearch('Faturalar', 'fatura'));
    expect(l.map((s) => s.name), ['Faturalar', 'Fatura içi']);
    expect(SavedSearch.fromJson(l.first.toJson())!.query, 'fatura');
    expect(SavedSearches.remove(l, l.last), hasLength(1));
  });
}

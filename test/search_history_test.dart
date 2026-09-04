import 'dart:io';

import 'package:dosya_okuyucu/services/fm/fm_env.dart';
import 'package:dosya_okuyucu/services/fm/search_history.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/temp_dir.dart';

/// **Arama geçmişi** — aynı sorguyu her seferinde baştan yazmak aramanın en
/// yorucu kısmıydı (2026-09-04 denetimi).
void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('search_history');
    FmEnv.appSupportDir = dir.path;
    SearchHistory.debugReset();
  });

  tearDown(() {
    FmEnv.appSupportDir = '';
    removeTempDir(dir);
  });

  test('en yeni sorgu başta', () async {
    await SearchHistory.record('fatura');
    await SearchHistory.record('bordro 2026');
    expect(SearchHistory.queries, ['bordro 2026', 'fatura']);
  });

  test('aynı sorgu iki kez listelenmez, yukarı taşınır', () async {
    await SearchHistory.record('fatura');
    await SearchHistory.record('rapor');
    await SearchHistory.record('FATURA');
    expect(SearchHistory.queries, ['FATURA', 'rapor']);
  });

  test('iki karakterden kısa sorgu alınmaz (arama da çalışmıyor)', () async {
    await SearchHistory.record('a');
    await SearchHistory.record('  ');
    expect(SearchHistory.queries, isEmpty);
  });

  test('sınır aşılmıyor, en eski düşer', () async {
    for (var i = 0; i < SearchHistory.maxEntries + 5; i++) {
      await SearchHistory.record('sorgu $i');
    }
    expect(SearchHistory.queries.length, SearchHistory.maxEntries);
    expect(SearchHistory.queries.first, 'sorgu 24');
    expect(SearchHistory.queries.contains('sorgu 0'), isFalse);
  });

  test('tek tek ve toplu silme', () async {
    await SearchHistory.record('bir');
    await SearchHistory.record('iki');
    await SearchHistory.remove('BİR'.toLowerCase() == 'bir' ? 'bir' : 'bir');
    expect(SearchHistory.queries, ['iki']);
    await SearchHistory.clear();
    expect(SearchHistory.queries, isEmpty);
  });

  test('diske yazılıp geri okunuyor', () async {
    await SearchHistory.record('kalıcı sorgu');
    expect(File('${dir.path}/search_history.json').existsSync(), isTrue);
    SearchHistory.debugReset();
    await SearchHistory.ensureLoaded();
    expect(SearchHistory.queries, ['kalıcı sorgu']);
  });
}

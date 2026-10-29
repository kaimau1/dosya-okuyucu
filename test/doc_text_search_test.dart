import 'dart:io';

import 'package:dosya_okuyucu/models/fs_entry.dart';
import 'package:dosya_okuyucu/services/fm/ai_meaning_search.dart';
import 'package:dosya_okuyucu/services/fm/doc_text_search.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Süzgeç içi arama (2026-10-29): içerik araması YALNIZ verilen listede
/// (ekrandaki süzgeç) arar; Türkçe/ASCII katlamalı eşleşir; AI terimleri
/// kullanıcının kendi teriminden sonra gelir.
void main() {
  late Directory temp;
  setUp(() {
    temp = Directory.systemTemp.createTempSync('dts');
    DocTextSearch.clearCache();
  });
  tearDown(() => temp.deleteSync(recursive: true));

  FsEntry entry(String name, String body) {
    final f = File(p.join(temp.path, name))..writeAsStringSync(body);
    final st = f.statSync();
    return FsEntry(
        path: f.path,
        name: name,
        isDir: false,
        sizeBytes: st.size,
        modifiedMs: st.modified.millisecondsSinceEpoch);
  }

  test('yalnız verilen listede, katlamalı arar; alıntı döner', () async {
    final a = entry('kira.txt', 'Bu bir KİRA Sözleşmesidir ve 2026 yılında imzalandı.');
    final b = entry('not.md', 'alışveriş listesi: elma, armut');
    final outside = entry('dis.txt', 'sozlesme burada da var');
    final hits = await DocTextSearch.search([a, b], ['sozlesme']);
    expect(hits.map((h) => h.entry.name), ['kira.txt']);
    expect(hits.single.snippet, contains('Sözleşmesidir'));
    expect(hits.any((h) => h.entry.path == outside.path), isFalse);
  });

  test('AI terimleri: herhangi biri bulunan dosya gelir, kullanıcı terimi önde',
      () async {
    final a = entry('a.txt', 'elektrik faturası ödendi, fatura no 12');
    final b = entry('b.txt', 'makbuz ektedir');
    final c = entry('c.txt', 'tatil fotoğrafları');
    final hits =
        await DocTextSearch.search([a, b, c], ['fatura', 'makbuz', 'dekont']);
    expect(hits.map((h) => h.entry.name), ['a.txt', 'b.txt']);
    expect(hits.last.terms, ['makbuz']);
  });

  test('anlamla sıralama verilen adaylarla sınırlı', () async {
    const pdf = FsEntry(
        path: '/x/Elektrik_faturasi.pdf',
        name: 'Elektrik_faturasi.pdf',
        isDir: false,
        sizeBytes: 1,
        modifiedMs: 1);
    const docx = FsEntry(
        path: '/x/fatura.docx',
        name: 'fatura.docx',
        isDir: false,
        sizeBytes: 1,
        modifiedMs: 1);
    const plan = MeaningPlan(terms: ['fatura', 'elektrik'], extensions: ['pdf']);
    final hits = await AiMeaningSearch.rankIn(plan, [pdf]);
    expect(hits.map((h) => h.entry.name), ['Elektrik_faturasi.pdf']);
    expect(hits.any((h) => h.entry.path == docx.path), isFalse);
    expect(hits.single.matched, ['fatura', 'elektrik']);
  });
}

@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_export_formats.dart';
import 'package:dosya_okuyucu/services/docx/pro/docx_paginator.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_auto_format.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/rebuild_probe.dart';

/// Faz 22 — Word Mobil görünüm: §7 bütçeleri (debug/JIT, ×3 gevşek).
/// * 1000 paragrafta bir tuşun model + yeniden çizim maliyeti;
/// * ~300 sayfalık (3000 paragraf) belgede ayrıştırma + ilk ekran;
/// * değişmeyen paragrafa dokunmayan kaydetme.
Uint8List _docx(int paras) {
  final body = StringBuffer();
  for (var i = 0; i < paras; i++) {
    body.write('<w:p><w:r><w:t xml:space="preserve">Paragraf ${i + 1}: '
        'Bu bir deneme cümlesidir; telefonda yazmanın akıcılığını ölçmek için '
        'yeterince uzun tutuldu, Türkçe karakterlerle: ğüşıöçİ.</w:t></w:r>'
        '<w:r><w:rPr><w:b/></w:rPr><w:t xml:space="preserve"> Kalın son.</w:t>'
        '</w:r></w:p>');
  }
  final out = Archive();
  for (final f in ZipDecoder().decodeBytes(BlankDocs.blankDocx()).files) {
    var data = f.content as List<int>;
    if (f.name == 'word/document.xml') {
      data = utf8.encode(utf8
          .decode(data)
          .replaceFirst(RegExp(r'<w:p>.*?</w:p>|<w:p/>'), body.toString()));
    }
    out.addFile(ArchiveFile(f.name, data.length, data));
  }
  return Uint8List.fromList(ZipEncoder().encode(out));
}

void main() {
  // B9 m.7 — yazarken otomatik biçim her tuşta koşar: kural yalnız imlecin
  // gerisindeki sözcüğe bakar, paragraf boyuyla büyümez (mandal, yalnız düşer).
  test('B9 m.7: otomatik biçim kuralı tuş başına ≤ 0,2 ms (4000 harf)', () {
    final text = List.filled(400, 'bu bir cümle. ve  a-- ').join();
    final sw = Stopwatch()..start();
    var hits = 0;
    for (var at = 1; at <= text.length; at++) {
      if (DocxAutoFormat.afterInsert(text, at, turkish: true) != null) hits++;
    }
    sw.stop();
    final perKey = sw.elapsedMicroseconds / text.length / 1000;
    // ignore: avoid_print
    print('PERF word_autoformat_key_ms=${perKey.toStringAsFixed(4)}');
    expect(hits, greaterThan(0));
    expect(perKey, lessThan(0.2));
  });

  test('3000 paragraf (~300 sayfa): ayrıştır ≤ 4,5 sn', () {
    final bytes = _docx(3000);
    final sw = Stopwatch()..start();
    final d = DocxDocument.parse(bytes);
    sw.stop();
    // ignore: avoid_print
    print('PERF word_parse_3000_ms=${sw.elapsedMilliseconds}');
    expect(d.paras, hasLength(3000));
    expect(sw.elapsedMilliseconds, lessThan(4500));
  });

  test('tek paragraf değişince kaydetme yalnız onu yazar (≤ 600 ms)', () {
    final d = DocxDocument.parse(_docx(1000));
    final p = d.paras[500];
    d.paras[500] = p.replace(0, 0, 'X', p.typingStyleAt(0));
    final sw = Stopwatch()..start();
    d.commit();
    final commitMs = sw.elapsedMilliseconds;
    d.save();
    sw.stop();
    // ignore: avoid_print
    print('PERF word_commit_1000_ms=$commitMs save_ms=${sw.elapsedMilliseconds}');
    expect(commitMs, lessThan(100));
    expect(sw.elapsedMilliseconds, lessThan(600));
  });

  testWidgets('1000 paragraf: ilk ekran + tuş başına model+çizim', (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final d = DocxDocument.parse(_docx(1000));
    final c = DocxEditController(d);
    final first = Stopwatch()..start();
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: DocxEditorView(controller: c, spellcheck: false))));
    first.stop();
    c.select(const DocPos(3, 10), const DocPos(3, 10));
    await t.pump();
    final sw = Stopwatch()..start();
    for (final ch in 'merhabadünya'.split('')) {
      c.insertText(ch);
      await t.pump();
    }
    sw.stop();
    final perKey = sw.elapsedMicroseconds / 12 / 1000;
    // ignore: avoid_print
    print('PERF word_first_frame_1000_ms=${first.elapsedMilliseconds} '
        'key_ms=${perKey.toStringAsFixed(2)}');
    expect(c.paras[3].text, contains('merhabadünya'));
    // §7: tuş ≤ 1 kare (cihaz). Debug gerileme bekçisi: ≤ 100 ms.
    expect(perKey, lessThan(100));
    c.dispose();
  });

  // B12 m.3 — yeniden kurulum bütçesi (mandal, YALNIZ DÜŞER): bir harf
  // yalnız yazılan paragrafın metnini (RichText) yeniden kurar; eskiden
  // görünür paragrafların hepsi (≈ ekrandaki paragraf sayısı) kuruluyordu.
  testWidgets('B12 m.3: bir harf yalnız o paragrafın metnini yeniden kurar',
      (t) async {
    t.view.physicalSize = const Size(1080, 2340);
    t.view.devicePixelRatio = 2.75;
    addTearDown(t.view.reset);
    final c = DocxEditController(DocxDocument.parse(_docx(1000)));
    await t.pumpWidget(MaterialApp(
        home: Scaffold(body: DocxEditorView(controller: c, spellcheck: false))));
    c.select(const DocPos(3, 10), const DocPos(3, 10));
    await t.pump();
    c.insertText('a'); // ısınma
    await t.pump();
    final texts = t.widgetList(find.byType(RichText)).length;
    final r = await countRebuilds(t, () async {
      c.insertText('b');
      await t.pump();
    });
    // ignore: avoid_print
    print('PERF word_key_rebuilds=${r.total} rich_text=${r.of(RichText)} '
        'visible_texts=$texts top=${r.top()}');
    expect(c.paras[3].text, contains('ab'));
    expect(texts, greaterThan(3), reason: 'senaryo birden çok paragraf görmeli');
    expect(r.of(RichText), lessThanOrEqualTo(1));
    // Toplam tavan (liste sarmalayıcıları + kabuk): ilk CI ölçümü 106
    // (2026-11-18) + ~%30 pay; yalnız düşer.
    expect(r.total, lessThanOrEqualTo(140));
    c.dispose();
  });

  // ── Faz 37 perf kapısı: 500 sayfa eşiği ──────────────────────────────────
  test('Faz 37: ~500 sayfa (5000 paragraf) sayfa tahmini ≤ 600 ms, '
      'tek değişiklikte artımlı ≤ 60 ms', () {
    final d = DocxDocument.parse(_docx(5000));
    final pg = DocxPaginator();
    final sw = Stopwatch()..start();
    pg.layout(d.paras);
    final full = sw.elapsedMilliseconds;
    expect(pg.pageCount, greaterThan(200));
    final p = d.paras[4000];
    d.paras[4000] = p.replace(0, 0, 'X', p.typingStyleAt(0));
    sw
      ..reset()
      ..start();
    pg.layout(d.paras);
    final inc = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print('PERF word_paginate_5000_ms=$full incremental_ms=$inc '
        'pages=${pg.pageCount} measured=${pg.measured}');
    expect(pg.measured, 1);
    expect(full, lessThan(600));
    expect(inc, lessThan(60));
  });

  // B9 m.8 — büyük belge açılışı, "ilk sayfa önce" (mandal, YALNIZ DÜŞER):
  // ilk kare için çözümlenen paragraf sayısı belgenin boyundan bağımsız.
  test('B9 m.8: 5000 paragrafta ilk kare ≤ 60 paragraf çözümler, ≤ 400 ms',
      () {
    final bytes = _docx(5000);
    final sw = Stopwatch()..start();
    final head = DocxDocument.parseHead(bytes);
    sw.stop();
    // ignore: avoid_print
    print('PERF word_head_5000_ms=${sw.elapsedMilliseconds} '
        'paras=${head.paras.length}');
    expect(head.headOnly, isTrue);
    expect(head.paras.length, lessThanOrEqualTo(60));
    expect(head.paras.length, greaterThanOrEqualTo(30),
        reason: 'ilk ekran dolmalı');
    expect(head.paras.first.text, startsWith('Paragraf 1:'));
    expect(sw.elapsedMilliseconds, lessThan(400));
    expect(head.save, throwsStateError, reason: 'baş modeli kaydedilmez');
  });

  test('Faz 37: 5000 paragraf Markdown + ODT dışa aktarım ≤ 3 sn', () {
    final d = DocxDocument.parse(_docx(5000));
    final sw = Stopwatch()..start();
    final md = DocxExportFormats.toMarkdown(d);
    final odt = DocxExportFormats.toOdt(d);
    sw.stop();
    // ignore: avoid_print
    print('PERF word_export_md_odt_5000_ms=${sw.elapsedMilliseconds}');
    expect(md, contains('**Kalın son.**'));
    expect(odt.length, greaterThan(1000));
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}

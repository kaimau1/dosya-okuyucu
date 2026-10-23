@Tags(['perf'])
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/blank_docs.dart';
import 'package:dosya_okuyucu/services/docx/docx_document.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_edit_controller.dart';
import 'package:dosya_okuyucu/widgets/docx_editor/docx_editor_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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
  return Uint8List.fromList(ZipEncoder().encode(out)!);
}

void main() {
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
}

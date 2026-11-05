@Tags(['perf'])
library;

import 'package:dosya_okuyucu/services/pptx/pro/pptx_package.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_show_info.dart';
import 'package:dosya_okuyucu/services/pptx/pro/pptx_templates.dart';
import 'package:dosya_okuyucu/services/pptx_editor.dart';
import 'package:dosya_okuyucu/services/pptx_rich_text.dart';
import 'package:dosya_okuyucu/services/pptx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 28 — 50 slaytlık deste: açılış (ayrıştırma + çizim modeli; ekranda
/// izolatta), metin onayı ve geri al anlık görüntüsünün maliyeti. Eşikler
/// debug/JIT için gevşek (×3); sayılar günlüğe düşer.
void main() {
  final deck = PptxWriter.build([
    for (var i = 1; i <= 50; i++)
      SlideDraft('Slayt $i başlığı', [
        for (var k = 1; k <= 6; k++) 'Madde $k — slayt $i için açıklama metni',
      ], notes: i.isEven ? 'Not $i' : ''),
  ]);

  test('50 slayt: aç ≤ 3 sn', () {
    final sw = Stopwatch()..start();
    final e = PptxEditor.parse(deck);
    sw.stop();
    // ignore: avoid_print
    print('PERF slides_open_50_ms=${sw.elapsedMilliseconds}');
    expect(e.slides, hasLength(50));
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });

  test('metin onayı + geri al anlık görüntüsü ≤ 150 ms', () {
    final e = PptxEditor.parse(deck);
    final slide = e.slides[24];
    final shape = slide.view!.shapes
        .firstWhere((s) => s.paragraphs.any((p) => p.plainText.startsWith('Madde 1')));
    final sw = Stopwatch()..start();
    final before = e.snapshot();
    final rich = SlideRichText.fromParagraphs(shape.paragraphs);
    rich.applyText(rich.text.replaceFirst('Madde 1', 'Madde bir'));
    e.writeRichText(slide, shape, rich);
    final after = e.snapshot();
    sw.stop();
    // ignore: avoid_print
    print('PERF slides_commit_with_snapshots_ms=${sw.elapsedMilliseconds}');
    expect(sw.elapsedMilliseconds, lessThan(150));

    final undo = Stopwatch()..start();
    e.restore(before);
    undo.stop();
    // ignore: avoid_print
    print('PERF slides_undo_restore_ms=${undo.elapsedMilliseconds}');
    expect(e.slides[24].paragraphs.map((p) => p.text),
        contains(startsWith('Madde 1 ')));
    e.restore(after);
    expect(e.slides[24].paragraphs.map((p) => p.text),
        contains(startsWith('Madde bir')));
  });

  // Faz 38 perf kapısı: 300 slaytlık deste — açılış, sunum bilgisi (izolatta
  // okunan medya/bağlantı/sayaç taraması) ve bir pro işlem gidiş-dönüşü.
  group('300 slayt (Faz 38)', () {
    final big = PptxWriter.build([
      for (var i = 1; i <= 300; i++)
        SlideDraft('Slayt $i', [for (var k = 1; k <= 4; k++) 'Madde $k / $i']),
    ]);

    test('aç ≤ 15 sn (debug)', () {
      final sw = Stopwatch()..start();
      final e = PptxEditor.parse(big);
      sw.stop();
      // ignore: avoid_print
      print('PERF slides_open_300_ms=${sw.elapsedMilliseconds}');
      expect(e.slides, hasLength(300));
      expect(sw.elapsedMilliseconds, lessThan(15000));
    });

    test('sunum bilgisi ≤ 3 sn, tema işlemi ≤ 8 sn', () async {
      PptxPro.inIsolate = false;
      final sw = Stopwatch()..start();
      final info = PptxShowInfo.read(PptxPackage.open(big));
      sw.stop();
      // ignore: avoid_print
      print('PERF slides_show_info_300_ms=${sw.elapsedMilliseconds}');
      expect(info, hasLength(300));
      expect(sw.elapsedMilliseconds, lessThan(3000));
      final op = Stopwatch()..start();
      final out = await PptxPro.run(big, PptxTemplates.apply('mint'));
      op.stop();
      // ignore: avoid_print
      print('PERF slides_template_300_ms=${op.elapsedMilliseconds}');
      expect(out.length, greaterThan(0));
      expect(op.elapsedMilliseconds, lessThan(8000));
    });
  });
}

@Tags(['perf'])
library;

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
}

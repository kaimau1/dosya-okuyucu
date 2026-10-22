import 'dart:ui' as ui;

import 'package:dosya_okuyucu/services/image_edit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Faz 10 görsel düzenleyici: önizleme ve kayıt aynı çizimden çıkar; burada
// çıktının piksel yönü ve kırpması sabitlenir.
const red = Color(0xFFFF0000), blue = Color(0xFF0000FF);

Future<ui.Image> twoPixels() {
  // 2×1: sol kırmızı, sağ mavi.
  final rec = ui.PictureRecorder();
  Canvas(rec)
    ..drawRect(const Rect.fromLTWH(0, 0, 1, 1), Paint()..color = red)
    ..drawRect(const Rect.fromLTWH(1, 0, 1, 1), Paint()..color = blue);
  return rec.endRecording().toImage(2, 1);
}

Future<List<int>> pixels(ui.Image im) async {
  final d = (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!;
  return [
    for (var i = 0; i < d.lengthInBytes; i += 4)
      (d.getUint8(i) << 16) | (d.getUint8(i + 1) << 8) | d.getUint8(i + 2),
  ];
}

void main() {
  testWidgets('döndür / çevir / kırp piksel yönü', (tester) async {
    await tester.runAsync(() async {
      final src = await twoPixels();
      Future<String> run(ImageEdits e) async {
        final out = await renderEdits(src, e);
        return '${out.width}x${out.height} ${await pixels(out)}';
      }

      expect(await run(const ImageEdits()), '2x1 [16711680, 255]');
      // Saat yönü: sol sütun üste gelir.
      expect(await run(const ImageEdits().rotated()), '1x2 [16711680, 255]');
      expect(await run(const ImageEdits().flipped()), '2x1 [255, 16711680]');
      // Önce çevir sonra döndür: ekranda [mavi, kırmızı] → üstte mavi.
      expect(await run(const ImageEdits().flipped().rotated()), '1x2 [255, 16711680]');
      // Dört döndürme başa döner.
      var e = const ImageEdits();
      for (var i = 0; i < 4; i++) {
        e = e.rotated();
      }
      expect(await run(e), '2x1 [16711680, 255]');
      // Sağ yarıyı kırp.
      expect(
        await run(const ImageEdits(crop: Rect.fromLTWH(0.5, 0, 0.5, 1))),
        '1x1 [255]',
      );
    });
  });

  test('renk matrisi: sıfır ayar birim matris', () {
    expect(colorMatrix(0, 0, 0), [
      1, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ]);
    // Doygunluk −1: üç kanal aynı parlaklık ağırlıklarını alır (gri).
    final g = colorMatrix(0, 0, -1);
    expect(g.sublist(0, 3), g.sublist(5, 8));
  });

  test('döndürünce kırpma ve işaret fotoğrafla birlikte döner', () {
    final e = const ImageEdits(
      crop: Rect.fromLTWH(0, 0, 0.5, 1),
      marks: [
        ImageMark(kind: MarkKind.pen, points: [Offset(0, 0)], color: red),
      ],
    ).rotated();
    // Sol yarı → saat yönünde üst yarı; sol-üst köşe → sağ-üst.
    expect(e.crop, const Rect.fromLTWH(0, 0, 1, 0.5));
    expect(e.marks.single.points.single, const Offset(1, 0));
  });
}

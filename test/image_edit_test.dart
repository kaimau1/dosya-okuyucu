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

  testWidgets('Boyut (14b): ölçek kırpılmış bölgeye uygulanır, döndürmede kalır',
      (tester) async {
    await tester.runAsync(() async {
      // 40×20 düz görsel: sol yarı kırmızı, sağ yarı mavi.
      final rec = ui.PictureRecorder();
      Canvas(rec)
        ..drawRect(const Rect.fromLTWH(0, 0, 20, 20), Paint()..color = red)
        ..drawRect(const Rect.fromLTWH(20, 0, 20, 20), Paint()..color = blue);
      final src = await rec.endRecording().toImage(40, 20);
      const half = ImageEdits(scale: 0.5);
      expect(half.isIdentity, isFalse);
      expect(outputSize(src, half), const Size(20, 10));
      final out = await renderEdits(src, half);
      expect((out.width, out.height), (20, 10));
      final px = await pixels(out);
      expect(px.first, 16711680); // sol üst hâlâ kırmızı
      expect(px[19], 255); // sağ üst mavi
      // Kırp (sağ yarı) + ölçek: 20×20 → 10×10.
      const cropped = ImageEdits(crop: Rect.fromLTWH(0.5, 0, 0.5, 1), scale: 0.5);
      expect(croppedSize(src, cropped), const Size(20, 20));
      expect(outputSize(src, cropped), const Size(10, 10));
      expect((await pixels(await renderEdits(src, cropped))).toSet(), {255});
      expect(half.rotated().scale, 0.5);
      expect(outputSize(src, half.rotated()), const Size(10, 20));
    });
  });

  // ── Faz 32 ────────────────────────────────────────────────────────────────

  /// Renk geçişli + ayrıntılı (dama) desen: bulanıklaştırma ve vekil testi.
  Future<ui.Image> pattern(int w, int h) {
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawRect(
        Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()),
        Paint()
          ..shader = ui.Gradient.linear(Offset.zero, Offset(w.toDouble(), 0),
              const [Color(0xFFFF8000), Color(0xFF0040C0)]));
    final cell = Paint()..color = const Color(0xFFFFFFFF);
    for (var y = 0; y < h; y += 8) {
      for (var x = (y ~/ 8).isEven ? 0 : 8; x < w; x += 16) {
        c.drawRect(Rect.fromLTWH(x.toDouble(), y.toDouble(), 8, 8), cell);
      }
    }
    return rec.endRecording().toImage(w, h);
  }

  Future<List<int>> rgba(ui.Image im) async =>
      (await im.toByteData(format: ui.ImageByteFormat.rawRgba))!
          .buffer
          .asUint8List();

  test('Faz 32: ayarsız/filtresiz hâl birim matris, şiddet 0 = filtresiz', () {
    const ident = [
      1.0, 0, 0, 0, 0, //
      0, 1, 0, 0, 0,
      0, 0, 1, 0, 0,
      0, 0, 0, 1, 0,
    ];
    expect(editMatrix(const ImageEdits()), ident);
    expect(const ImageEdits(filter: 'sepia', filterStrength: 0).hasColor, isFalse);
    expect(editMatrix(const ImageEdits(filter: 'sepia', filterStrength: 0)), ident);
    expect(imageFilters.length, 10);
    // Belge ve Siyah-Beyaz griye çevirir: üç satır aynı.
    for (final f in ['document', 'mono']) {
      final m = editMatrix(ImageEdits(filter: f));
      for (var j = 0; j < 5; j++) {
        expect(m[5 + j], closeTo(m[j], 1e-9));
        expect(m[10 + j], closeTo(m[j], 1e-9));
      }
    }
    // Sıcaklık + : kırmızı kazancı > mavi kazancı.
    final w = adjustMatrix(temperature: 0.5);
    expect(w[0], greaterThan(w[12]));
    expect(const ImageEdits(vignette: 0.3).isIdentity, isFalse);
  });

  test('Faz 32: dikey çevir = yatay çevir + 180°, açı aynada ters', () {
    const e = ImageEdits(
      angle: 10,
      crop: Rect.fromLTWH(0, 0, 1, 0.5),
      marks: [
        ImageMark(kind: MarkKind.text, points: [Offset(0.2, 0.1)], color: red),
      ],
    );
    final v = e.flippedV();
    expect(v.crop.top, closeTo(0.5, 1e-9));
    expect(v.marks.single.points.single.dx, closeTo(0.2, 1e-9));
    expect(v.marks.single.points.single.dy, closeTo(0.9, 1e-9));
    expect(e.flipped().angle, -10);
    expect(coverScale(400, 300, 0), 1);
    expect(coverScale(400, 300, 10), greaterThan(1));
  });

  testWidgets('Faz 32: vekil ve tam çözünürlük aynı düzenlemeyi aynı oranda uygular',
      (tester) async {
    await tester.runAsync(() async {
      final full = await pattern(400, 300);
      final proxy = (await previewProxy(full, maxSide: 200))!;
      expect((proxy.width, proxy.height), (200, 150));
      const e = ImageEdits(
        angle: 7,
        crop: Rect.fromLTWH(0.1, 0.1, 0.8, 0.8),
        exposure: 0.2,
        temperature: 0.4,
        shadows: 0.3,
        vignette: 0.6,
        filter: 'drama',
        filterStrength: 0.7,
        marks: [
          ImageMark(
              kind: MarkKind.rect,
              points: [Offset(0.3, 0.3), Offset(0.6, 0.7)],
              color: Color(0xFF00FF00),
              size: 0.03),
        ],
      );
      // Tam çıktıyı vekil ölçeğine indir, vekilin çıktısıyla karşılaştır.
      final a = await renderEdits(full, e.copyWith(scale: 0.5));
      final b = await renderEdits(proxy, e);
      expect((a.width, a.height), (b.width, b.height));
      final pa = await rgba(a), pb = await rgba(b);
      var diff = 0;
      for (var i = 0; i < pa.length; i++) {
        if (i % 4 != 3) diff += (pa[i] - pb[i]).abs();
      }
      final mean = diff / (pa.length / 4 * 3);
      expect(mean, lessThan(6), reason: 'ortalama kanal farkı $mean');
    });
  });

  testWidgets('Faz 32: bulanıklaştır/pikselleştir bölgesi çıktıda geri döndürülemez',
      (tester) async {
    await tester.runAsync(() async {
      final src = await pattern(200, 200);
      ImageEdits brush(MarkKind k) => ImageEdits(marks: [
            ImageMark(
                kind: k,
                points: const [Offset(0.1, 0.5), Offset(0.9, 0.5)],
                color: red,
                size: 0.3),
          ]);
      final orig = await rgba(await renderEdits(src, const ImageEdits()));
      // Bölgedeki ayrıntı (komşu piksel farkı) ve dışarıdaki dokunulmazlık.
      double detail(List<int> px, int y0, int y1) {
        var d = 0, n = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = 40; x < 159; x++) {
            final i = (y * 200 + x) * 4;
            d += (px[i] - px[i + 4]).abs();
            n++;
          }
        }
        return d / n;
      }

      // Pikselleştirmede blok içi komşular eşit (5 px blok → ~4/5 çift).
      double flat(List<int> px, int y0, int y1) {
        var eq = 0, n = 0;
        for (var y = y0; y < y1; y++) {
          for (var x = 40; x < 159; x++) {
            final i = (y * 200 + x) * 4;
            if ((px[i] - px[i + 4]).abs() <= 1 &&
                (px[i + 2] - px[i + 6]).abs() <= 1) {
              eq++;
            }
            n++;
          }
        }
        return eq / n;
      }

      final before = detail(orig, 90, 110);
      for (final k in [MarkKind.blur, MarkKind.pixelate]) {
        final out = await rgba(await renderEdits(src, brush(k)));
        if (k == MarkKind.blur) {
          expect(detail(out, 90, 110), lessThan(before * 0.35), reason: '$k');
        } else {
          expect(flat(out, 90, 110), greaterThan(0.7), reason: '$k');
          expect(flat(out, 90, 110), greaterThan(flat(orig, 90, 110) + 0.1));
        }
        // Fırça dışı (üst kenar) özgünle aynı.
        expect(out.sublist(0, 200 * 4 * 10), orig.sublist(0, 200 * 4 * 10),
            reason: '$k dışı');
      }
    });
  });

  test('Faz 32: dönmüş yazıda dokunma, sınır kutusu ve taşıma', () {
    const box = Rect.fromLTWH(0, 0, 400, 400);
    const m = ImageMark(
        kind: MarkKind.text,
        points: [Offset(0.5, 0.5)],
        color: red,
        size: 0.02,
        text: 'Merhaba dünya');
    final r = markBounds(m, box);
    expect(r.center, const Offset(200, 200));
    expect(r.width, greaterThan(r.height));
    // Yatayda uçta bir nokta: düzken isabet, 90° dönünce ıska.
    final tip = Offset(r.right - 4, 200);
    expect(hitMark([m], box, tip, slop: 0), 0);
    expect(
        hitMark([m.copyWith(rotation: 1.5707963)], box, tip, slop: 0), isNull);
    expect(m.shifted(const Offset(0.1, 0)).points.single, const Offset(0.6, 0.5));
  });

  testWidgets('Faz 32: keskinlik kenar kontrastını artırır', (tester) async {
    await tester.runAsync(() async {
      final src = await pattern(64, 64);
      final a = await rgba(src);
      final b = await rgba(await sharpened(src, 1));
      var da = 0, db = 0;
      for (var x = 4; x < 60; x++) {
        final i = (20 * 64 + x) * 4;
        da += (a[i] - a[i + 4]).abs();
        db += (b[i] - b[i + 4]).abs();
      }
      expect(db, greaterThan(da));
    });
  });
}

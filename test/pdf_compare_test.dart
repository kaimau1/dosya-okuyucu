import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf_compare.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 4 — iki PDF karşılaştırma (metin + görsel).
Future<List<int>> _doc(List<String> lines) async {
  final doc = PdfDocument();
  final g = doc.pages.add().graphics;
  final f = PdfStandardFont(PdfFontFamily.helvetica, 12);
  for (var i = 0; i < lines.length; i++) {
    g.drawString(lines[i], f, bounds: Rect.fromLTWH(40, 40.0 + i * 30, 500, 18));
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

void main() {
  test('sözcük farkı: değişen sözcük silinen+eklenen', () {
    final d = PdfCompare.diffWords('toplam tutar 100 TL', 'toplam tutar 120 TL');
    expect(d.map((p) => p.toString()), [
      'same:toplam tutar',
      'removed:100',
      'added:120',
      'same:TL',
    ]);
  });

  test('satır farkı: eklenen satır ayrı, aynı satırlar aynı', () {
    final d = PdfCompare.diffLines(['a b', 'c d'], ['a b', 'yeni satir', 'c d']);
    expect(d, hasLength(3));
    expect(d[1].single.kind, DiffKind.added);
    expect(d[0].single.kind, DiffKind.same);
  });

  test('iki belge: değişen sayfa işaretlenir, sayılar doğru', () async {
    final a = await _doc(['Madde 1 kira bedeli 100', 'Madde 2 sure bir yil']);
    final b = await _doc(['Madde 1 kira bedeli 150', 'Madde 2 sure bir yil']);
    final diff = PdfCompare.compareText(a, b);
    expect(diff, hasLength(1));
    expect(diff.single.changed, isTrue);
    expect(diff.single.addedWords, 1);
    expect(diff.single.removedWords, 1);
    expect(PdfCompare.compareText(a, a).single.changed, isFalse);
  });

  test('görsel fark: aynı sayfa 0, farklı piksel oranı doğru', () {
    final white = Uint8List(100)..fillRange(0, 100, 255);
    final half = Uint8List(100)
      ..fillRange(0, 100, 255)
      ..fillRange(0, 50, 0);
    expect(
        PdfCompare.visualDiff(1, (w: 10, h: 10, luma: white),
                (w: 10, h: 10, luma: white))
            .ratio,
        0);
    expect(
        PdfCompare.visualDiff(1, (w: 10, h: 10, luma: white),
                (w: 10, h: 10, luma: half))
            .ratio,
        closeTo(0.5, 1e-9));
  });
}

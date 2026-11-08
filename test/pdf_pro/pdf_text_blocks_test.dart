import 'package:dosya_okuyucu/services/pdf/pro/pdf_text_blocks.dart';
import 'package:flutter_test/flutter_test.dart';

PdfTextObjectInfo o(int i, String t, double x, double y, {double w = 80, double size = 10, bool rot = false}) =>
    PdfTextObjectInfo(
      index: i, text: t, left: x, bottom: y - 2, right: x + w, top: y + size * 0.8,
      tfSize: size, fontName: 'Carlito',
      matrix: rot ? [0, 1, -1, 0, x, y] : [1, 0, 0, 1, x, y], renderMode: 0);

void main() {
  test('satırlar bloklanır, iki sütun karışmaz, döndürülmüş metin ayrı', () {
    final blocks = groupTextBlocks([
      o(0, 'Sol bir', 50, 700), o(1, 'Sol iki', 50, 688),
      o(2, 'Sağ bir', 320, 700), o(3, 'Sağ iki', 320, 688),
      o(4, 'Başlık', 50, 740, size: 16),
      o(5, 'Kenar notu', 560, 300, rot: true),
    ]);
    final texts = blocks.map((b) => b.text).toList();
    expect(texts, containsAll(['Sol bir Sol iki', 'Sağ bir Sağ iki', 'Başlık', 'Kenar notu']));
    expect(blocks.length, 4);
  });

  test('aynı satırdaki parçalar birleşir, aradaki boşluk korunur', () {
    final b = groupTextBlocks([o(0, 'Merhaba', 50, 700, w: 40), o(1, 'dünya', 95, 700, w: 30)]);
    expect(b.single.text, 'Merhaba dünya');
    expect(b.single.objectIndexes, [0, 1]);
  });
}

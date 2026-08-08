import 'package:flutter_test/flutter_test.dart';
import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:dosya_okuyucu/services/slides_pdf.dart';

ShapeVM _shape({
  required double x,
  required double y,
  required double w,
  required double h,
  required List<String> paragraphs,
  int id = 1,
}) =>
    ShapeVM(
      id: id,
      x: x,
      y: y,
      w: w,
      h: h,
      paragraphs: [
        for (final p in paragraphs)
          ParaVM(runs: [RunVM(text: p)]),
      ],
    );

void main() {
  group('slayt → PDF görünmez metin katmanı', () {
    test('her paragraf KENDİ kutusunu alır (şeklin tamamını değil)', () {
      // Üç maddelik bir metin kutusu tek kutuya sıkıştırılırsa kopyalanan
      // metin tek satıra iner ve arama ikinci maddeyi kutunun en üstünde
      // gösterir — o yüzden şekil paragraf sayısına bölünüyor.
      final slide = SlideVM(
        widthPt: 720,
        heightPt: 405,
        shapes: [
          _shape(x: 10, y: 100, w: 200, h: 90, paragraphs: ['bir', 'iki', 'üç']),
        ],
      );

      final lines = SlidesPdf.textLines(slide);
      expect(lines.map((l) => l.text), ['bir', 'iki', 'üç']);
      expect(lines[0].box.top, 100);
      expect(lines[1].box.top, 130); // 90 / 3 = 30 punto dilim
      expect(lines[2].box.top, 160);
      expect(lines.every((l) => l.box.width == 200), isTrue);
      expect(lines.every((l) => l.box.height == 30), isTrue);
    });

    test('BOŞ paragraf yer kaplamaz', () {
      // Satır arası boşluk için konmuş `<a:p/>` dilimden pay alsaydı dolu
      // maddeler kutunun üst yarısına sıkışır ve seçim yazıdan kayardı.
      final slide = SlideVM(
        widthPt: 720,
        heightPt: 405,
        shapes: [
          _shape(x: 0, y: 0, w: 100, h: 100, paragraphs: ['bir', '   ', 'iki']),
        ],
      );

      final lines = SlidesPdf.textLines(slide);
      expect(lines.map((l) => l.text), ['bir', 'iki']);
      expect(lines[0].box.height, 50); // 3'e değil 2'ye bölünmüş
      expect(lines[1].box.top, 50);
    });

    test('kutular PİKSEL uzayına ölçeklenir (punto değil)', () {
      // `imagesToPdf` kutuları görüntü boyutundan hesapladığı ölçekle
      // çarpıyor; punto bırakılırsa metin katmanı görselin köşesine büzülür.
      final slide = SlideVM(
        widthPt: 720,
        heightPt: 405,
        shapes: [_shape(x: 10, y: 20, w: 30, h: 40, paragraphs: ['bir'])],
      );

      final lines = SlidesPdf.textLines(slide, pixelRatio: 2);
      expect(lines.single.box.left, 20);
      expect(lines.single.box.top, 40);
      expect(lines.single.box.width, 60);
      expect(lines.single.box.height, 80);
    });

    test('metinsiz şekil satır üretmez', () {
      final slide = SlideVM(
        widthPt: 720,
        heightPt: 405,
        shapes: [
          _shape(x: 0, y: 0, w: 10, h: 10, paragraphs: []),
          _shape(x: 0, y: 0, w: 10, h: 10, paragraphs: ['', '  ']),
        ],
      );
      expect(SlidesPdf.textLines(slide), isEmpty);
    });

    test('düz metin şekil sırasını korur', () {
      final slide = SlideVM(
        widthPt: 720,
        heightPt: 405,
        shapes: [
          _shape(id: 1, x: 0, y: 0, w: 10, h: 10, paragraphs: ['başlık']),
          _shape(id: 2, x: 0, y: 20, w: 10, h: 10, paragraphs: ['gövde', 'son']),
        ],
      );
      expect(SlidesPdf.plainText(slide), 'başlık\ngövde\nson');
    });
  });
}

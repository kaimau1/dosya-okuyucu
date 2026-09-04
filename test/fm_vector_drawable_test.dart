import 'package:dosya_okuyucu/services/fm/apk_resources.dart';
import 'package:dosya_okuyucu/services/fm/vector_drawable.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/apk_binaries.dart';

/// **Vektör simge çizici** — kullanıcı 2026-09-03: *"hâlâ eski apklarda
/// simgeler görülmüyor"*.
///
/// Kök neden: uyarlanabilir simgenin ön planı vektörse birleştirme
/// vazgeçiyordu. Buradaki ölçüt "piksel doğru": çizilen kare gerçekten
/// dolduruldu mu, deliği delik kaldı mı, grup dönüşümü uygulandı mı.
void main() {
  group('yol verisi', () {
    test('kapalı kare beş noktayla düzleşir (Z başa döner)', () {
      final polys = PathData.flatten('M0,0 L10,0 L10,10 L0,10 Z');
      expect(polys.length, 1);
      expect(polys.first.length, 5);
      expect(polys.first.last.x, 0);
      expect(polys.first.last.y, 0);
    });

    test('bağıl komutlar (küçük harf) imleci taşır', () {
      final polys = PathData.flatten('m5,5 l5,0 l0,5 z');
      expect(polys.first[1].x, 10);
      expect(polys.first[2].y, 10);
    });

    test('ayraçsız ve eksi işaretiyle bitişik sayılar ayrışır', () {
      final polys = PathData.flatten('M0 0L10-5L20 0');
      expect(polys.first.length, 3);
      expect(polys.first[1].y, -5);
    });

    test('bir "L" komutu birden çok küme taşıyabilir', () {
      final polys = PathData.flatten('M0,0 L1,1 2,2 3,3');
      expect(polys.first.length, 4);
      expect(polys.first.last.x, 3);
    });

    test('yay (A) düz çizgiye düşmez — ara noktalar üretir', () {
      final polys = PathData.flatten('M0,10 A10,10 0 0 1 20,10');
      expect(polys.first.length, greaterThan(8));
      // Yayın tepesi başlangıç/bitişin üstünde olmalı (y küçülür).
      final minY = polys.first.map((p) => p.y).reduce((a, b) => a < b ? a : b);
      expect(minY, lessThan(9.9));
    });

    test('eğri (C) düzleştirilir ve uç noktada biter', () {
      final polys = PathData.flatten('M0,0 C0,10 10,10 10,0');
      expect(polys.first.length, 17);
      expect(polys.first.last.x, closeTo(10, 0.001));
      expect(polys.first.last.y, closeTo(0, 0.001));
    });
  });

  group('çizim', () {
    /// Basit bir ağaç kurmanın kısayolu (ikili XML üretmeden).
    AxmlNode node(String name, Map<String, String> attributes,
        [List<AxmlNode> children = const []]) {
      final byName = {
        for (final e in attributes.entries)
          e.key: AxmlAttribute(AxmlAttribute.typeString, 0, e.value),
      };
      final n = AxmlNode(AxmlElement(name, const {}, byName));
      n.children.addAll(children);
      return n;
    }

    test('dolu kare gerçekten doluyor, dışı saydam kalıyor', () {
      final tree = [
        node('vector', {'viewportWidth': '10', 'viewportHeight': '10'}, [
          node('path', {
            'pathData': 'M2,2 L8,2 L8,8 L2,8 Z',
            'fillColor': '#FF3050FF',
          }),
        ]),
      ];
      final image = VectorDrawable.parse(tree);
      expect(image, isNotNull);
      final raster = VectorDrawable.rasterize(image!, size: 40);
      final center = raster.getPixel(20, 20);
      expect(center.a, 255);
      expect(center.r, 0x30);
      expect(center.b, 0xFF);
      // Köşe (0,0) yolun dışında: dokunulmamış olmalı.
      expect(raster.getPixel(0, 0).a, 0);
    });

    test('evenOdd deliği delik bırakır', () {
      final tree = [
        node('vector', {'viewportWidth': '10', 'viewportHeight': '10'}, [
          node('path', {
            // Dış kare + iç kare: evenOdd ile ortası boşalır.
            'pathData': 'M0,0 L10,0 L10,10 L0,10 Z M3,3 L7,3 L7,7 L3,7 Z',
            'fillColor': '#FF000000',
            'fillType': 'evenOdd',
          }),
        ]),
      ];
      final raster =
          VectorDrawable.rasterize(VectorDrawable.parse(tree)!, size: 40);
      expect(raster.getPixel(20, 20).a, 0, reason: 'ortası delik olmalı');
      expect(raster.getPixel(4, 20).a, 255, reason: 'çerçeve dolu olmalı');
    });

    test('grup ötelemesi şekli taşır', () {
      final path = node('path', {
        'pathData': 'M0,0 L4,0 L4,4 L0,4 Z',
        'fillColor': '#FF000000',
      });
      final moved = [
        node('vector', {'viewportWidth': '10', 'viewportHeight': '10'}, [
          node('group', {'translateX': '6'}, [path]),
        ]),
      ];
      final raster =
          VectorDrawable.rasterize(VectorDrawable.parse(moved)!, size: 40);
      // Kare artık sağda: sol üst boş, sağ üst dolu.
      expect(raster.getPixel(8, 8).a, 0);
      expect(raster.getPixel(32, 8).a, 255);
    });

    test('saydamlık (fillAlpha) renge işliyor', () {
      final tree = [
        node('vector', {'viewportWidth': '10', 'viewportHeight': '10'}, [
          node('path', {
            'pathData': 'M0,0 L10,0 L10,10 L0,10 Z',
            'fillColor': '#FF000000',
            'fillAlpha': '0.5',
          }),
        ]),
      ];
      final raster =
          VectorDrawable.rasterize(VectorDrawable.parse(tree)!, size: 20);
      expect(raster.getPixel(10, 10).a, closeTo(128, 2));
    });

    test('yolu olmayan vektör null döner (yanlış boş kare çizilmesin)', () {
      final tree = [
        node('vector', {'viewportWidth': '10', 'viewportHeight': '10'}),
      ];
      expect(VectorDrawable.parse(tree), isNull);
    });
  });

  group('ikili XML ağacı', () {
    test('üretilen vektör XML\'i ağaç olarak okunuyor ve çiziliyor', () {
      final bytes = ApkBinaries.vectorDrawable(
        pathData: 'M2,2 L8,2 L8,8 L2,8 Z',
        fillColor: 0xFF00FF00,
      );
      final tree = AndroidBinaryXml.parseTree(bytes);
      expect(VectorDrawable.isVector(tree), isTrue);
      final png = VectorDrawable.toPng(tree, size: 32);
      expect(png, isNotNull);
      expect(png!.length, greaterThan(50));
    });

    test('grup iç içe okunuyor (bitiş düğümleri yığını doğru boşaltıyor)', () {
      final bytes = ApkBinaries.vectorDrawable(
        pathData: 'M0,0 L4,0 L4,4 L0,4 Z',
        groupTranslate: '6',
      );
      final tree = AndroidBinaryXml.parseTree(bytes);
      expect(tree.length, 1);
      expect(tree.first.name, 'vector');
      expect(tree.first.children.single.name, 'group');
      expect(tree.first.children.single.children.single.name, 'path');
    });
  });
}

import 'package:dosya_okuyucu/services/pptx_render.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const _ns =
    'xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main"';

void main() {
  group('PptxRender gradient (a:gradFill) ayrıştırma', () {
    test('doğrusal gradient: iki durak, dikey açı', () {
      final g = PptxRender.debugParseGradient('''
<sp $_ns>
  <a:gradFill>
    <a:gsLst>
      <a:gs pos="0"><a:srgbClr val="FF0000"/></a:gs>
      <a:gs pos="100000"><a:srgbClr val="0000FF"/></a:gs>
    </a:gsLst>
    <a:lin ang="5400000"/>
  </a:gradFill>
</sp>''');
      expect(g, isA<LinearGradient>());
      final lin = g as LinearGradient;
      expect(lin.colors, [const Color(0xFFFF0000), const Color(0xFF0000FF)]);
      expect(lin.stops, [0.0, 1.0]);
      // 90° → yukarıdan aşağı: begin üstte (y≈-1), end altta (y≈1).
      final begin = lin.begin as Alignment;
      final end = lin.end as Alignment;
      expect(begin.y, closeTo(-1, 0.01));
      expect(end.y, closeTo(1, 0.01));
      expect(begin.x, closeTo(0, 0.01));
    });

    test('duraklar konuma göre sıralanır', () {
      final g = PptxRender.debugParseGradient('''
<sp $_ns>
  <a:gradFill>
    <a:gsLst>
      <a:gs pos="100000"><a:srgbClr val="0000FF"/></a:gs>
      <a:gs pos="0"><a:srgbClr val="FF0000"/></a:gs>
    </a:gsLst>
    <a:lin ang="0"/>
  </a:gradFill>
</sp>''') as LinearGradient;
      expect(g.stops, [0.0, 1.0]);
      expect(g.colors.first, const Color(0xFFFF0000)); // pos 0 = kırmızı
    });

    test('radyal gradient (a:path) → RadialGradient', () {
      final g = PptxRender.debugParseGradient('''
<sp $_ns>
  <a:gradFill>
    <a:gsLst>
      <a:gs pos="0"><a:srgbClr val="FFFFFF"/></a:gs>
      <a:gs pos="100000"><a:srgbClr val="000000"/></a:gs>
    </a:gsLst>
    <a:path path="circle"/>
  </a:gradFill>
</sp>''');
      expect(g, isA<RadialGradient>());
    });

    test('tek duraklı veya gradient olmayan → null', () {
      final single = PptxRender.debugParseGradient('''
<sp $_ns><a:gradFill><a:gsLst>
  <a:gs pos="0"><a:srgbClr val="FF0000"/></a:gs>
</a:gsLst></a:gradFill></sp>''');
      expect(single, isNull);

      final solid = PptxRender.debugParseGradient(
          '<sp $_ns><a:solidFill><a:srgbClr val="FF0000"/></a:solidFill></sp>');
      expect(solid, isNull);
    });
  });
}

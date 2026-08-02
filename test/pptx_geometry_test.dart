import 'dart:math' as math;
import 'dart:ui';

import 'package:dosya_okuyucu/services/pptx_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yolun GERÇEK dış hattının sınırı.
///
/// `Path.getBounds` kullanılamaz: Skia sınırı **denetim noktalarına** göre
/// hesaplar, yay içeren şekillerde (elips dilimi vb.) çizilen hattın epey
/// dışında bir kutu döner — ör. 200x100'lük bir `chord` için sol kenarı -41.
/// Burada yol örneklenip gerçekten geçtiği noktalar ölçülür.
Rect _outlineBounds(Path p, {int steps = 240}) {
  var l = double.infinity, t = double.infinity;
  var r = -double.infinity, b = -double.infinity;
  for (final m in p.computeMetrics()) {
    for (var i = 0; i <= steps; i++) {
      final pos = m.getTangentForOffset(m.length * i / steps)?.position;
      if (pos == null) continue;
      l = math.min(l, pos.dx);
      t = math.min(t, pos.dy);
      r = math.max(r, pos.dx);
      b = math.max(b, pos.dy);
    }
  }
  return Rect.fromLTRB(l, t, r, b);
}

/// Yol kutunun içinde mi kalıyor (şekil komşusunun üstüne taşmamalı)?
void _fitsIn(Path p, Size box, {double slack = 0.5}) {
  final b = _outlineBounds(p);
  expect(b.left, greaterThanOrEqualTo(-slack), reason: 'sol taşma');
  expect(b.top, greaterThanOrEqualTo(-slack), reason: 'üst taşma');
  expect(b.right, lessThanOrEqualTo(box.width + slack), reason: 'sağ taşma');
  expect(b.bottom, lessThanOrEqualTo(box.height + slack), reason: 'alt taşma');
}

void main() {
  const box = Size(200, 100); // bilerek KARE DEĞİL: elips/daire ayrımını yakalar

  group('PptxPresetShape.rectRadius', () {
    test('dikdörtgen ailesi yarıçap döner, diğerleri null', () {
      expect(PptxPresetShape.rectRadius('rect', box), 0);
      expect(PptxPresetShape.rectRadius('flowChartProcess', box), 0);
      // roundRect varsayılanı kısa kenarın 16667/100000'i.
      expect(PptxPresetShape.rectRadius('roundRect', box),
          closeTo(100 * 0.16667, 0.01));
      // Stadyum (terminator) = yüksekliğin yarısı.
      expect(PptxPresetShape.rectRadius('flowChartTerminator', box), 50);
      expect(PptxPresetShape.rectRadius('triangle', box), isNull);
      expect(PptxPresetShape.rectRadius('ellipse', box), isNull);
    });

    test('roundRect köşe yarıçapı avLst ayarını dinler', () {
      // Sarı tutamak sonuna çekilmiş: adj=50000 → kısa kenarın yarısı.
      expect(PptxPresetShape.rectRadius('roundRect', box, {'adj': 50000}), 50);
      // Sınırın üstü kırpılır (şema tavanı 50000).
      expect(PptxPresetShape.rectRadius('roundRect', box, {'adj': 90000}), 50);
      expect(PptxPresetShape.rectRadius('roundRect', box, {'adj': 0}), 0);
    });
  });

  group('PptxPresetShape.build', () {
    test('tanınmayan geometri null döner (çağıran dikdörtgene düşer)', () {
      expect(PptxPresetShape.build('funkyShapeXyz', box), isNull);
      expect(PptxPresetShape.isSupported('funkyShapeXyz'), isFalse);
      // Dikdörtgen ailesi "desteklenir" ama yol değil kutu olarak.
      expect(PptxPresetShape.isSupported('rect'), isTrue);
      expect(PptxPresetShape.isSupported('flowChartDecision'), isTrue);
    });

    test('sıfır/negatif kutuda null (çizilecek bir şey yok)', () {
      expect(PptxPresetShape.build('triangle', const Size(0, 50)), isNull);
      expect(PptxPresetShape.build('triangle', const Size(50, -1)), isNull);
    });

    test('elips kutunun TAMAMINI kaplar — daire değil', () {
      // Kök neden: eski çizim `BoxShape.circle` kullanıyordu; Flutter orada
      // kısa kenara göre DAİRE çizer, yani 200x100 bir elips 100x100 daire
      // olarak görünüyordu. Yol tabanlı çizimde sınır kutunun kendisidir.
      final p = PptxPresetShape.build('ellipse', box)!;
      final b = p.getBounds();
      expect(b.width, closeTo(200, 0.01));
      expect(b.height, closeTo(100, 0.01));
      // Yatay uçlar içeride, dikey uçlar dışarıda.
      expect(p.contains(const Offset(4, 50)), isTrue);
      expect(p.contains(const Offset(100, 4)), isTrue);
      expect(p.contains(const Offset(4, 4)), isFalse); // köşe boşta
    });

    test('üçgen: tepe ortada, taban altta', () {
      final p = PptxPresetShape.build('triangle', box)!;
      _fitsIn(p, box);
      expect(p.contains(const Offset(100, 90)), isTrue); // taban ortası dolu
      expect(p.contains(const Offset(5, 5)), isFalse); // sol üst köşe boş
      expect(p.contains(const Offset(195, 5)), isFalse); // sağ üst köşe boş
      expect(p.contains(const Offset(100, 10)), isTrue); // tepeye yakın dolu
    });

    test('üçgen tepe noktası adj ile kayar', () {
      final sol = PptxPresetShape.build('triangle', box, {'adj': 0})!;
      // Tepe sola alındığında sağ üst bölge boş, sol üst dolu kalır.
      expect(sol.contains(const Offset(3, 3)), isTrue);
      expect(sol.contains(const Offset(197, 3)), isFalse);
    });

    test('elmas: köşeler boş, merkez dolu', () {
      final p = PptxPresetShape.build('diamond', box)!;
      _fitsIn(p, box);
      expect(p.contains(const Offset(100, 50)), isTrue);
      for (final corner in const [
        Offset(2, 2),
        Offset(198, 2),
        Offset(2, 98),
        Offset(198, 98),
      ]) {
        expect(p.contains(corner), isFalse, reason: 'köşe dolu: $corner');
      }
      // Akış şeması kararı da elmastır.
      expect(PptxPresetShape.build('flowChartDecision', box)!.getBounds(),
          p.getBounds());
    });

    test('sağ ok: uç sağda, gövde ince, baş üstte/altta taşar', () {
      final p = PptxPresetShape.build('rightArrow', box)!;
      _fitsIn(p, box);
      expect(p.contains(const Offset(10, 50)), isTrue); // gövde
      expect(p.contains(const Offset(10, 5)), isFalse); // gövde dışı üst şerit
      expect(p.contains(const Offset(190, 50)), isTrue); // ok ucu
      expect(p.contains(const Offset(190, 5)), isFalse); // baş köşesi boş
    });

    test('sol ok sağ okun aynasıdır', () {
      final right = PptxPresetShape.build('rightArrow', box)!;
      final left = PptxPresetShape.build('leftArrow', box)!;
      expect(left.contains(const Offset(10, 50)), isTrue);
      expect(right.contains(const Offset(190, 50)), isTrue);
      // Sağ okta dolu olan uç bölgesi, sol okta boş kalan bölgenin aynası.
      expect(left.contains(const Offset(190, 10)), isFalse);
      expect(right.contains(const Offset(10, 10)), isFalse);
    });

    test('okun gövde kalınlığı ve baş uzunluğu adj1/adj2 ile değişir', () {
      // adj1=100000 → gövde kutu yüksekliği kadar; üst şerit de dolar.
      final kalin =
          PptxPresetShape.build('rightArrow', box, {'adj1': 100000})!;
      expect(kalin.contains(const Offset(10, 5)), isTrue);
      // adj2=0 → ok başı yok, saf dikdörtgen gövde: sağ uçta üst köşe dolu.
      final bassiz = PptxPresetShape.build('rightArrow', box, {'adj2': 0})!;
      expect(bassiz.contains(const Offset(199, 50)), isTrue);
    });

    test('yıldız: uç sayısı kadar dış tepe, merkez dolu', () {
      final p = PptxPresetShape.build('star5', box)!;
      _fitsIn(p, box);
      expect(p.contains(const Offset(100, 50)), isTrue); // gövde
      expect(p.contains(const Offset(100, 2)), isTrue); // tepe uç (yukarı)
      expect(p.contains(const Offset(3, 3)), isFalse); // köşe boş
      // İç yarıçap 0 verilirse yıldız iğne uçlara döner: merkez çevresi boşalır.
      final ince = PptxPresetShape.build('star5', box, {'adj': 0})!;
      expect(ince.contains(const Offset(140, 30)), isFalse);
    });

    test('halka (donut) ortası BOŞ', () {
      final p = PptxPresetShape.build('donut', const Size(100, 100))!;
      expect(p.fillType, PathFillType.evenOdd);
      expect(p.contains(const Offset(50, 3)), isTrue); // halka üstü dolu
      expect(p.contains(const Offset(50, 50)), isFalse); // orta delik
    });

    test('dilim (pie) varsayılan 0°→270°: SAĞ ÜST çeyrek boş', () {
      // OOXML açısı saat 3 yönünden saat yönünde ölçülür; 0°→270° dilimi
      // sağ alt + sol alt + sol üst çeyreği kaplar, sağ üstü boş bırakır
      // (PowerPoint'in varsayılan "pac-man" dilimi).
      final p = PptxPresetShape.build('pie', const Size(100, 100))!;
      expect(p.contains(const Offset(70, 70)), isTrue); // sağ alt
      expect(p.contains(const Offset(30, 30)), isTrue); // sol üst
      expect(p.contains(const Offset(70, 30)), isFalse); // sağ üst boş
    });

    test('altıgen/sekizgen köşeleri kırpar', () {
      for (final name in ['hexagon', 'octagon']) {
        final p = PptxPresetShape.build(name, box)!;
        _fitsIn(p, box);
        expect(p.contains(const Offset(100, 50)), isTrue, reason: name);
        expect(p.contains(const Offset(1, 1)), isFalse, reason: '$name köşe');
      }
    });

    test('artı işareti: kollar dolu, köşeler boş', () {
      final p = PptxPresetShape.build('plus', const Size(100, 100))!;
      _fitsIn(p, const Size(100, 100));
      expect(p.contains(const Offset(50, 5)), isTrue); // üst kol
      expect(p.contains(const Offset(5, 50)), isTrue); // sol kol
      expect(p.contains(const Offset(5, 5)), isFalse); // köşe
    });

    test('chevron sol kenarından içeri girer', () {
      final p = PptxPresetShape.build('chevron', box)!;
      _fitsIn(p, box);
      expect(p.contains(const Offset(30, 5)), isTrue); // üst şerit dolu
      expect(p.contains(const Offset(2, 50)), isFalse); // sol ortadaki oyuk
      expect(p.contains(const Offset(195, 50)), isTrue); // sağdaki uç
    });

    test('desteklenen tüm şekiller kapalı ve kutuda kalan yol üretir', () {
      const names = [
        'triangle', 'rtTriangle', 'diamond', 'parallelogram', 'trapezoid',
        'hexagon', 'octagon', 'pentagon', 'heptagon', 'decagon', 'dodecagon',
        'homePlate', 'chevron', 'plus', 'mathPlus', 'corner', 'rightArrow',
        'leftArrow', 'upArrow', 'downArrow', 'leftRightArrow', 'upDownArrow',
        'notchedRightArrow', 'star4', 'star5', 'star6', 'star7', 'star8',
        'star10', 'star12', 'star16', 'star24', 'star32', 'ellipse', 'donut',
        'pie', 'chord', 'blockArc', 'can', 'cube', 'teardrop', 'cloud',
        'flowChartDecision', 'flowChartInputOutput', 'flowChartPreparation',
        'flowChartManualInput', 'flowChartManualOperation', 'flowChartExtract',
        'flowChartMerge', 'flowChartSort', 'flowChartConnector',
        'flowChartOffpageConnector', 'flowChartDocument', 'flowChartDelay',
        'flowChartMagneticDisk', 'flowChartMagneticDrum',
      ];
      for (final name in names) {
        final p = PptxPresetShape.build(name, box);
        expect(p, isNotNull, reason: '$name yol üretmedi');
        _fitsIn(p!, box, slack: 1.0);
        // Alanı olmayan (dejenere) yol çizilse de görünmezdi.
        final b = p.getBounds();
        expect(b.width, greaterThan(box.width * 0.4), reason: '$name dar');
        expect(b.height, greaterThan(box.height * 0.4), reason: '$name basık');
      }
    });

    test('balon kuyruğu gövdenin DIŞINA uzanır', () {
      // PowerPoint'te konuşma balonunun kuyruğu şekil kutusunu aşar; yol da
      // aşmalı, yoksa balon sıradan bir dikdörtgene döner.
      final p = PptxPresetShape.build('wedgeRectCallout', box)!;
      expect(p.getBounds().bottom, greaterThan(box.height));
      expect(p.contains(const Offset(100, 50)), isTrue); // gövde dolu
    });
  });
}

import 'package:dosya_okuyucu/core/sheet_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

/// Izgaranın eksen matematiği. *Niye ayrı test:* dondurulmuş bölmenin ekrana
/// sığması ve yatay sanallaştırma penceresi yalnız cihazda görünen hatalar
/// üretiyordu ("sağ tarafı göremiyorum").
void main() {
  group('fitFrozen', () {
    test('bütçeye sığan sütun sayısını verir', () {
      // Her sütun 100 px, bütçe 250 px → 2 sütun sığar.
      expect(fitFrozen(count: 5, sizeOf: (_) => 100, budget: 250), 2);
    });

    test('ilk sütun bile sığmazsa bölme tamamen kalkar', () {
      expect(fitFrozen(count: 3, sizeOf: (_) => 400, budget: 300), 0);
    });

    test('hepsi sığarsa dosyadaki sayı korunur', () {
      expect(fitFrozen(count: 3, sizeOf: (_) => 50, budget: 300), 3);
    });

    test('gizli (0 ölçülü) sütun bütçe yemez ama bölmeye dahildir', () {
      // 0: gizli, 1: 100, 2: 100 → bütçe 150'de 0 ve 1 sığar.
      expect(
        fitFrozen(count: 3, sizeOf: (i) => i == 0 ? 0 : 100, budget: 150),
        2,
      );
    });

    test('bütçe yoksa bölme yok', () {
      expect(fitFrozen(count: 4, sizeOf: (_) => 10, budget: 0), 0);
      expect(fitFrozen(count: 0, sizeOf: (_) => 10, budget: 100), 0);
    });
  });

  group('SheetAxisMetrics', () {
    final m = SheetAxisMetrics.build(
      from: 0,
      to: 6,
      sizeOf: (i) => (i + 1) * 10, // 10,20,30,40,50,60
      hidden: (i) => i == 2, // 30 px'lik sütun gizli
    );

    test('gizli dizinler atlanır, toplam doğru', () {
      expect(m.indices, [0, 1, 3, 4, 5]);
      expect(m.total, 10 + 20 + 40 + 50 + 60);
      expect(m.length, 5);
    });

    test('başlangıç ve ölçüler birikimli', () {
      expect(m.startAt(0), 0);
      expect(m.startAt(2), 30); // 10+20
      expect(m.sizeAt(2), 40); // 3. sütun
    });

    test('firstAt kaydırma konumundaki ilk sütunu bulur', () {
      expect(m.firstAt(0), 0);
      expect(m.firstAt(10), 1);
      expect(m.firstAt(29), 1);
      expect(m.firstAt(30), 2);
      expect(m.firstAt(1000), 4); // sonun ötesi son sütuna sabitlenir
    });

    test('lastAt bir sütun payanda bırakır', () {
      // 0..40 px penceresi: 0,1 görünür; payanda ile 2 de çizilir.
      expect(m.lastAt(40), 3);
      expect(m.lastAt(1e6), 4);
    });

    test('positionOf ham dizini eksendeki yerine çevirir', () {
      expect(m.positionOf(0), 0);
      expect(m.positionOf(3), 2);
      expect(m.positionOf(2), -1); // gizli
      expect(m.positionOf(99), -1);
    });

    test('boş eksen çökmez', () {
      const e = SheetAxisMetrics.empty;
      expect(e.isEmpty, isTrue);
      expect(e.total, 0);
      expect(e.firstAt(500), 0);
      expect(e.lastAt(500), 0);
      expect(e.positionOf(0), -1);
    });

    test('dondurulmuş bölümden sonrası için kurulur', () {
      final scroll = SheetAxisMetrics.build(
        from: 2,
        to: 5,
        sizeOf: (_) => 100,
      );
      expect(scroll.indices, [2, 3, 4]);
      expect(scroll.total, 300);
    });
  });
}

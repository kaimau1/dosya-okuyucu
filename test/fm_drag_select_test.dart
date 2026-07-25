import 'package:dosya_okuyucu/widgets/fm/drag_select.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sürükleyerek çoklu seçimin aralık matematiği (saf fonksiyon).
/// Parmak ileri gidince yeni öğeler seçilir; GERİ gelince fazladan seçilenler
/// geri alınır — bu geri alma olmadan "kaydırıp geri çekince seçim kalıyor"
/// hatası olurdu.
void main() {
  group('dragSelectDelta', () {
    test('aralık aşağı doğru büyüyünce yeni öğeler seçilir', () {
      expect(dragSelectDelta(3, 3, 3, 6, true),
          [const DragSelectStep(4, 6, true)]);
    });

    test('aralık yukarı doğru büyüyünce yeni öğeler seçilir', () {
      expect(dragSelectDelta(5, 5, 2, 5, true),
          [const DragSelectStep(2, 4, true)]);
    });

    test('aralık küçülünce dışarıda kalanlar geri alınır', () {
      expect(dragSelectDelta(3, 8, 3, 5, true),
          [const DragSelectStep(6, 8, false)]);
    });

    test('seçimden çıkarma kipinde geri alma = yeniden seçme', () {
      expect(dragSelectDelta(2, 7, 2, 4, false),
          [const DragSelectStep(5, 7, true)]);
    });

    test('çapayı geçip diğer yöne kayınca hem geri alma hem seçme olur', () {
      // Çapa 5'te; eskiden 5..8 seçiliydi, şimdi 2..5.
      expect(dragSelectDelta(5, 8, 2, 5, true), [
        const DragSelectStep(2, 4, true),
        const DragSelectStep(6, 8, false),
      ]);
    });

    test('değişiklik yoksa adım üretilmez', () {
      expect(dragSelectDelta(1, 4, 1, 4, true), isEmpty);
    });
  });

  _gestureTests();
}

/// Jest tarafı: basılı tut + kaydır gerçekten aralık seçiyor mu?
/// (Öğelerin kendi `onLongPress`i olsaydı jest arenasını çocuk kazanır ve
/// sürükleme hiç başlamazdı — bu test o regresyonu yakalar.)
void _gestureTests() {
  testWidgets('basılı tutup kaydırınca aradaki tüm öğeler seçilir',
      (tester) async {
    final selected = <int>{};
    final scroll = ScrollController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DragSelectArea(
            scrollController: scroll,
            isSelected: selected.contains,
            onSelectRange: (a, b, sel) => setState(() {
              for (var i = a; i <= b; i++) {
                if (sel) {
                  selected.add(i);
                } else {
                  selected.remove(i);
                }
              }
            }),
            child: ListView.builder(
              controller: scroll,
              itemCount: 20,
              itemExtent: 40,
              itemBuilder: (_, i) => DragSelectItem(
                index: i,
                child: SizedBox(height: 40, child: Text('öğe $i')),
              ),
            ),
          ),
        ),
      ),
    ));

    Offset centerOf(int i) => tester.getCenter(find.text('öğe $i'));

    final gesture = await tester.startGesture(centerOf(1));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    expect(selected, {1}, reason: 'uzun basış çapayı seçer');

    await gesture.moveTo(centerOf(4));
    await tester.pump();
    expect(selected, {1, 2, 3, 4}, reason: 'aradaki tüm öğeler seçilir');

    // Geri çekilince fazladan seçilenler bırakılır.
    await gesture.moveTo(centerOf(2));
    await tester.pump();
    expect(selected, {1, 2});

    await gesture.up();
    await tester.pump();
    expect(selected, {1, 2});
  });

  testWidgets('seçili öğeden başlayan sürükleme seçimi KALDIRIR',
      (tester) async {
    final selected = <int>{0, 1, 2, 3};
    final scroll = ScrollController();

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => DragSelectArea(
            scrollController: scroll,
            isSelected: selected.contains,
            onSelectRange: (a, b, sel) => setState(() {
              for (var i = a; i <= b; i++) {
                if (sel) {
                  selected.add(i);
                } else {
                  selected.remove(i);
                }
              }
            }),
            child: ListView.builder(
              controller: scroll,
              itemCount: 10,
              itemExtent: 40,
              itemBuilder: (_, i) => DragSelectItem(
                index: i,
                child: SizedBox(height: 40, child: Text('öğe $i')),
              ),
            ),
          ),
        ),
      ),
    ));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text('öğe 0')));
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 60));
    await gesture.moveTo(tester.getCenter(find.text('öğe 2')));
    await tester.pump();
    await gesture.up();
    await tester.pump();
    expect(selected, {3});
  });
}

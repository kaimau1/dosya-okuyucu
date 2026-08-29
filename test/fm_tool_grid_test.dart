import 'package:dosya_okuyucu/core/theme.dart';
import 'package:dosya_okuyucu/services/fm/tool_usage.dart';
import 'package:dosya_okuyucu/widgets/fm/fm_category_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// **Niye bu test var (2026-08-29):**
/// - Araç ızgarası "kullanıma göre" sıralanıyor; sıra kuralı saf bir
///   fonksiyonda ([rankByUsage]) ve burada tek tek doğrulanıyor. Yanlış
///   sıralama telefonda "araçlarım karışıyor" olarak görünürdü.
/// - Etiketler artık iki satıra sarıyor ve hücre yüksekliği ÖLÇÜLÜYOR. Sabit
///   en-boy oranı + sabit punto büyütülmüş yazı ölçeğinde `RenderFlex
///   overflowed` demekti (aynı ders `fm_grid_tile_test`te).
void main() {
  group('rankByUsage', () {
    test('kayıt yokken sıra HİÇ değişmez', () {
      final ids = ['a', 'b', 'c'];
      expect(rankByUsage(ids, const {}), [0, 1, 2]);
    });

    test('çok kullanılan öne gelir', () {
      final ids = ['a', 'b', 'c'];
      expect(rankByUsage(ids, const {'c': 5, 'a': 2}), [2, 0, 1]);
    });

    test('eşitlikte yazılış sırası korunur (kararlı)', () {
      final ids = ['a', 'b', 'c', 'd'];
      // b ve d aynı sayıda: aralarındaki sıra listedeki gibi kalmalı.
      expect(rankByUsage(ids, const {'b': 3, 'd': 3}), [1, 3, 0, 2]);
    });

    test('bilinmeyen kimlik sayacı sıfır sayılır, listeden düşmez', () {
      final ids = ['a', 'b'];
      final order = rankByUsage(ids, const {'yok': 9});
      expect(order, [0, 1]);
    });
  });

  group('FmToolGrid', () {
    List<FmTileData> tools({bool subtitle = false}) => [
          for (var i = 0; i < 11; i++)
            FmTileData(
              icon: Icons.folder,
              color: Colors.blue,
              // Kırpılan gerçek etiketlerden: "Yeni belge oluştur",
              // "Sohbet medyası temizliği".
              label: 'Yeni belge oluştur $i',
              subtitle: subtitle && i == 0 ? '3 biten' : '',
              id: 'tool$i',
              onTap: () {},
            ),
        ];

    Widget harness(List<FmTileData> data, {double textScale = 1.0}) =>
        MaterialApp(
          theme: AppTheme.light(),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: Scaffold(
              body: SingleChildScrollView(child: FmToolGrid(tools: data)),
            ),
          ),
        );

    for (final scale in const [1.0, 1.3, 1.6]) {
      testWidgets('$scale yazı ölçeğinde taşmadan çizilir', (tester) async {
        await tester.pumpWidget(harness(tools(), textScale: scale));
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('alt yazılı ızgara da taşmaz', (tester) async {
      await tester.pumpWidget(harness(tools(subtitle: true), textScale: 1.6));
      expect(tester.takeException(), isNull);
      expect(find.text('3 biten'), findsOneWidget);
    });

    testWidgets('etiket İKİ satıra sarabilir (tek satırda kırpılmaz)',
        (tester) async {
      await tester.pumpWidget(harness(tools()));
      final text = tester.widget<Text>(find.text('Yeni belge oluştur 0'));
      expect(text.maxLines, 2);
    });

    testWidgets('araç ızgarası içerik ızgarasıyla AYNI sütun sayısını kullanır',
        (tester) async {
      // 411 dp: yaygın telefon genişliği. İki ızgaranın sütunları pano
      // boyunca hizalı kalmalı — ayrı formüller zikzak yapıyordu.
      expect(FmCategoryGrid.columnsFor(411), 4);
      expect(FmCategoryGrid.columnsFor(500), 4);
      expect(FmCategoryGrid.columnsFor(900), 8);
    });
  });

  test('ToolUsage.counts salt okunur bir görünümdür', () {
    ToolUsage.resetForTest();
    expect(ToolUsage.counts, isEmpty);
    expect(() => ToolUsage.counts['x'] = 1, throwsUnsupportedError);
  });
}

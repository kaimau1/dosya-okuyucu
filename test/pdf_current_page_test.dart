import 'dart:ui' show Rect;

import 'package:dosya_okuyucu/services/pdf/current_page.dart';
import 'package:flutter_test/flutter_test.dart';

/// 10 yatay sayfa, her biri 100 yüksek, aralarında 8 boşluk (pdfrx düzeni).
List<Rect> _pages(int n, {double h = 100, double gap = 8}) => [
      for (var i = 0; i < n; i++)
        Rect.fromLTWH(0, gap + i * (h + gap), 200, h),
    ];

void main() {
  group('currentPdfPage', () {
    final pages = _pages(10);
    final docBottom = pages.last.bottom + 8;

    test('tek sayfa önde olduğunda pdfrx ile aynı: en çok görünen', () {
      // Ekran 150 yüksek: sayfa 3 tam, sayfa 4'ün yarısı.
      final view = Rect.fromLTWH(0, pages[2].top, 200, 150);
      expect(currentPdfPage(visibleRect: view, pageRects: pages), 3);
    });

    test('belgenin ortasında birden çok tam sayfa → üstteki', () {
      // Ekran 330 yüksek: sayfa 3, 4, 5 tam.
      final view = Rect.fromLTWH(0, pages[2].top - 4, 200, 330);
      expect(currentPdfPage(visibleRect: view, pageRects: pages), 3);
    });

    test('KÖK HATA: sona kadar kaydırınca son sayfa gösterilir', () {
      // Eskiden (pdfrx) burada 8 çıkıyordu: 8, 9, 10 üçü de %100.
      final view = Rect.fromLTWH(0, docBottom - 330, 200, 330);
      expect(currentPdfPage(visibleRect: view, pageRects: pages), 10);
    });

    test('son ekranlık kaydırmada sayfalar sırayla gezilir', () {
      const h = 330.0;
      final maxTop = pages.last.bottom - h;
      final seen = <int>[];
      // Adımlar sona tam oturmayabilir (748 → 750): son konum ayrıca.
      final tops = [for (var t = maxTop - h; t < maxTop; t += 4) t, maxTop];
      for (final top in tops) {
        final page = currentPdfPage(
            visibleRect: Rect.fromLTWH(0, top, 200, h), pageRects: pages)!;
        if (seen.isEmpty || seen.last != page) seen.add(page);
      }
      // Hiç geri gitmez, sonunda 10'a varır.
      for (var i = 1; i < seen.length; i++) {
        expect(seen[i], greaterThan(seen[i - 1]));
      }
      expect(seen.last, 10);
      expect(seen, containsAll([8, 9, 10]));
    });

    test('"sayfaya git" ile gidilen sayfa eşitlikte korunur', () {
      final view = Rect.fromLTWH(0, docBottom - 330, 200, 330);
      expect(
          currentPdfPage(visibleRect: view, pageRects: pages, preferred: 8),
          8);
      // Aday değilse (ekranda değil) tercih yok sayılır.
      expect(
          currentPdfPage(visibleRect: view, pageRects: pages, preferred: 2),
          10);
    });

    test('tercih edilen sayfa tek önde olanı ezmez', () {
      final view = Rect.fromLTWH(0, pages[2].top, 200, 150);
      expect(
          currentPdfPage(visibleRect: view, pageRects: pages, preferred: 4),
          3);
    });

    test('belge tümüyle ekrandaysa ilk sayfa', () {
      final small = _pages(3);
      const view = Rect.fromLTWH(0, 0, 200, 1000);
      expect(currentPdfPage(visibleRect: view, pageRects: small), 1);
    });

    test('hiçbir sayfa görünmüyorsa / düzen boşsa null', () {
      expect(
          currentPdfPage(
              visibleRect: const Rect.fromLTWH(0, 5000, 200, 100),
              pageRects: pages),
          isNull);
      expect(
          currentPdfPage(
              visibleRect: const Rect.fromLTWH(0, 0, 200, 100),
              pageRects: const []),
          isNull);
    });

    test('iki sütun: sonda son satırın sağındaki sayfa', () {
      // 6 sayfa, 2 sütun: (1,2) (3,4) (5,6); her satır 100 yüksek.
      final grid = <Rect>[
        for (var i = 0; i < 6; i++)
          Rect.fromLTWH(8 + (i % 2) * 108, 8 + (i ~/ 2) * 108, 100, 100),
      ];
      final view = Rect.fromLTWH(0, grid.last.bottom - 220, 224, 220);
      expect(currentPdfPage(visibleRect: view, pageRects: grid), 6);
    });
  });
}

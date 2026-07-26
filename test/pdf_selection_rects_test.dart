import 'package:flutter_test/flutter_test.dart';
import 'package:pdfrx/pdfrx.dart';

import 'package:dosya_okuyucu/widgets/pdf_select_layer.dart';

/// Seçim vurgusunun "kelime aralarında koyu şeritler" bulgusunun testi:
/// aynı satırdaki parçalar tek dikdörtgende birleşmeli, ayrı satırlar ayrı
/// kalmalı. (PdfRect y-yukarı: top > bottom.)
void main() {
  group('mergeSameLineRects', () {
    test('aynı satırdaki kelimeler tek dikdörtgen olur', () {
      final merged = mergeSameLineRects(const [
        PdfRect(10, 100, 40, 90), // "Sigorta"
        PdfRect(44, 100, 70, 90), // "şirketi"
        PdfRect(74, 101, 96, 91), // "bir" — birkaç birim kaymış, hâlâ aynı satır
      ]);

      expect(merged, hasLength(1));
      expect(merged.first.left, 10);
      expect(merged.first.right, 96);
      expect(merged.first.top, 101);
      expect(merged.first.bottom, 90);
    });

    test('ayrı satırlar ayrı kalır ve sıra korunur', () {
      final merged = mergeSameLineRects(const [
        PdfRect(10, 100, 60, 90), // 1. satır
        PdfRect(10, 88, 55, 78), // 2. satır
        PdfRect(60, 100, 90, 90), // yine 1. satır
      ]);

      expect(merged, hasLength(2));
      expect(merged[0].top, 100);
      expect(merged[0].right, 90, reason: '1. satırın iki parçası birleşmeli');
      expect(merged[1].top, 88);
    });

    test('bozuk (yüksekliği olmayan) kutular atılır', () {
      final merged = mergeSameLineRects(const [
        PdfRect(10, 90, 40, 90),
        PdfRect(10, 100, 40, 90),
      ]);

      expect(merged, hasLength(1));
      expect(merged.first.top, 100);
    });

    test('boş liste boş kalır', () {
      expect(mergeSameLineRects(const []), isEmpty);
    });
  });
}

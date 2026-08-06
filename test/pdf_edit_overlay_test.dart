import 'package:dosya_okuyucu/widgets/pdf_edit_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// PDF düzenleyicide **isabet** (2026-08-07 kullanıcı turu: *"daha çok müsade
/// ve isabet"*): ince satırlar parmakla vurulabilmeli ve iç içe kutularda
/// küçük olan kazanmalı.
void main() {
  group('PdfEditOverlay dokunma geometrisi', () {
    test('küçük kutu Stack\'te SONA gider (hit-test önce onu görür)', () {
      final rects = <Rect>[
        const Rect.fromLTWH(0, 0, 200, 400), // büyük paragraf bloğu
        const Rect.fromLTWH(10, 10, 100, 14), // içindeki tek satır
        const Rect.fromLTWH(0, 300, 200, 40), // orta boy
      ];
      // Sıra alan büyüklüğüne göre AZALAN: en küçük en sonda çizilir.
      expect(PdfEditOverlay.orderByAreaDesc(rects), [0, 2, 1]);
    });

    test('ince kutu en az 30dp dokunma hedefine büyür, kalını büyümez', () {
      // 12dp'lik bir satır: ortadan simetrik büyür (görünen kutu yerinde kalır).
      final thin = PdfEditOverlay.touchRect(const Rect.fromLTWH(20, 100, 80, 12));
      expect(thin.height, PdfEditOverlay.minTouch);
      expect(thin.center.dy, closeTo(106, 0.001));

      // Zaten geniş kutu yalnız 2dp pay alır (eski davranış).
      final thick =
          PdfEditOverlay.touchRect(const Rect.fromLTWH(0, 0, 200, 120));
      expect(thick.height, 124);
      expect(thick.width, 204);
    });

    test('dar sütun hücresi yatayda da hedef büyütür', () {
      final narrow = PdfEditOverlay.touchRect(const Rect.fromLTWH(0, 0, 8, 8));
      expect(narrow.width, PdfEditOverlay.minTouch);
      expect(narrow.height, PdfEditOverlay.minTouch);
    });

    test('boş liste sıralamayı kırmaz', () {
      expect(PdfEditOverlay.orderByAreaDesc(const []), isEmpty);
    });
  });
}

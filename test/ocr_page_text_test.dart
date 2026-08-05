import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';

import 'package:dosya_okuyucu/services/pdf/ocr_page_text.dart';

/// Taranmış sayfa seçiminin temeli: ML Kit sözcük kutuları (görüntü pikseli,
/// y-aşağı) → sahte `PdfPageText` (PDF puntosu, y-YUKARI). Koordinat çevirisi
/// yanlış olursa seçim vurgusu sayfada dikey aynalanmış çizilir — bu yüzden
/// eksen çevirisi ayrı ayrı kilitleniyor.
void main() {
  group('buildOcrPageText', () {
    test('tek kelime: metin, y-çevirisi ve karakter dilimleri doğru', () {
      // Sayfa 100x200 punto, görüntü 2x (200x400 px). "Ab" kelimesi
      // px (20,40)-(60,60) → punto (10,20)-(30,30); PDF'te top = 200-20 = 180.
      final t = buildOcrPageText(
        pageNumber: 3,
        pageHeight: 200,
        imageScale: 2,
        lines: [
          [OcrWordBox('Ab', const Rect.fromLTRB(20, 40, 60, 60))],
        ],
      )!;

      expect(t.pageNumber, 3);
      expect(t.fullText, 'Ab\n');
      expect(t.fragments, hasLength(1));
      final f = t.fragments.single;
      expect(f.index, 0);
      expect(f.text, 'Ab\n');
      expect(f.charRects, hasLength(3)); // 'A', 'b', '\n'

      final a = f.charRects[0];
      expect(a.left, 10);
      expect(a.right, 20); // kelime kutusunun yarısı
      expect(a.top, 180); // y çevrildi: 200 - 40/2
      expect(a.bottom, 170);
      expect(a.top > a.bottom, isTrue, reason: 'PdfRect y-yukarı olmalı');

      final b = f.charRects[1];
      expect(b.left, 20);
      expect(b.right, 30);

      final nl = f.charRects[2];
      expect(nl.left, nl.right, reason: 'satır sonu sıfır genişlik');
    });

    test('kelime arası boşluk iki kutu ARASINI kaplar (kesintisiz vurgu)', () {
      final t = buildOcrPageText(
        pageNumber: 1,
        pageHeight: 100,
        imageScale: 1,
        lines: [
          [
            OcrWordBox('ev', const Rect.fromLTRB(0, 10, 20, 20)),
            OcrWordBox('is', const Rect.fromLTRB(30, 10, 50, 20)),
          ],
        ],
      )!;

      expect(t.fullText, 'ev is\n');
      final f = t.fragments.single;
      expect(f.charRects, hasLength(6));
      final space = f.charRects[2];
      expect(space.left, 20, reason: 'önceki kelimenin sağından başlar');
      expect(space.right, 30, reason: 'sonraki kelimenin soluna dek');
    });

    test('iki satır: indeksler ardışık, fullText fragment metinlerinin toplamı',
        () {
      final t = buildOcrPageText(
        pageNumber: 1,
        pageHeight: 100,
        imageScale: 1,
        lines: [
          [OcrWordBox('bir', const Rect.fromLTRB(0, 0, 30, 10))],
          [OcrWordBox('iki', const Rect.fromLTRB(0, 20, 30, 30))],
        ],
      )!;

      expect(t.fullText, 'bir\niki\n');
      expect(t.fragments, hasLength(2));
      expect(t.fragments[0].index, 0);
      expect(t.fragments[1].index, 4);
      for (final f in t.fragments) {
        expect(f.charRects.length, f.text.length,
            reason: 'her karakterin kutusu olmalı (pdfrx sözleşmesi)');
        expect(t.fullText.substring(f.index, f.index + f.length), f.text);
      }
    });

    test('boş sözcükler/satırlar elenir; hiç sözcük yoksa null', () {
      expect(
        buildOcrPageText(
            pageNumber: 1, pageHeight: 100, imageScale: 1, lines: []),
        isNull,
      );
      expect(
        buildOcrPageText(
          pageNumber: 1,
          pageHeight: 100,
          imageScale: 1,
          lines: [
            [OcrWordBox('', const Rect.fromLTRB(0, 0, 10, 10))],
            [],
          ],
        ),
        isNull,
      );
    });

    test('üst üste binen kutular (OCR gürültüsü) boşluğu negatif yapmaz', () {
      final t = buildOcrPageText(
        pageNumber: 1,
        pageHeight: 100,
        imageScale: 1,
        lines: [
          [
            OcrWordBox('ab', const Rect.fromLTRB(0, 10, 22, 20)),
            // Sol kenarı önceki kutunun sağının SOLUNDA (örtüşme).
            OcrWordBox('cd', const Rect.fromLTRB(20, 10, 40, 20)),
          ],
        ],
      )!;
      final space = t.fragments.single.charRects[2];
      expect(space.right >= space.left, isTrue,
          reason: 'boşluk kutusu ters dönmemeli');
    });
  });
}

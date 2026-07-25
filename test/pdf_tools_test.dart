import 'dart:math' as math;
import 'dart:ui' show Offset, Rect, Size;

import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 1 PDF araçları. Syncfusion PDF I/O cihazsız koşuyor (bkz.
/// `syncfusion_pdf_smoke_test.dart`), o yüzden burada gerçek belgeler üretilip
/// yeniden açılarak doğrulanır — sonuç PDF'in kendisi kanıt.
///
/// Sayfa SIRASI, her sayfaya farklı GENİŞLİK verilerek kontrol edilir: metin
/// çıkarmaya güvenmeden sıra/eksik sayfa yakalanır.
void main() {
  group('composedPageTransform — /Rotate dönüşümü (saf matematik)', () {
    const src = Size(300, 400);

    test('döndürülmemiş sayfa aynen geçer', () {
      final t = composedPageTransform(src, 0);
      expect(t.size, src);
      expect(t.angle, 0);
      expect(t.translate.dx, 0);
      expect(t.translate.dy, 0);
    });

    test('90° ve 270°de en/boy yer değiştirir', () {
      expect(composedPageTransform(src, 1).size, const Size(400, 300));
      expect(composedPageTransform(src, 3).size, const Size(400, 300));
    });

    test('180°de boyut korunur, sağ-alt köşeden döner', () {
      final t = composedPageTransform(src, 2);
      expect(t.size, src);
      expect(t.angle, 180);
      expect(t.translate.dx, 300);
      expect(t.translate.dy, 400);
    });

    test('90°: sağ-üst köşeye taşı, sonra döndür', () {
      final t = composedPageTransform(src, 1);
      expect(t.angle, 90);
      expect(t.translate.dx, 400); // hedef sayfanın genişliği
      expect(t.translate.dy, 0);
    });

    test('270°: sol-alt köşeye taşı, sonra döndür', () {
      final t = composedPageTransform(src, 3);
      expect(t.angle, 270);
      expect(t.translate.dx, 0);
      expect(t.translate.dy, 300); // hedef sayfanın yüksekliği
    });

    test('4 tur başa döner', () {
      expect(composedPageTransform(src, 4).angle, 0);
    });
  });

  group('stampTransform — görünen sayfa → ham sayfa (imza)', () {
    const page = Size(300, 400); // ham ölçü

    /// İmza için kullanılan dönüşüm, sayfa kopyalarken kullanılanın TERSİ
    /// olmalı: ileri (ham→görünen) sonra geri (görünen→ham) = başlangıç noktası.
    /// Yanlışsa imza sayfada bambaşka bir köşeye, yan yatık basılır.
    test('composedPageTransform ile gidiş-dönüş kimlik verir', () {
      const probes = [Offset(0, 0), Offset(300, 0), Offset(37, 219),
        Offset(300, 400)];
      for (var turns = 0; turns < 4; turns++) {
        final forward = composedPageTransform(page, turns);
        final back = stampTransform(page, turns);
        for (final p in probes) {
          final shown = _applyTransform(
              (translate: forward.translate, angle: forward.angle), p);
          final again = _applyTransform(back, shown);
          expect(again.dx, closeTo(p.dx, 0.001), reason: 'turns=$turns p=$p');
          expect(again.dy, closeTo(p.dy, 0.001), reason: 'turns=$turns p=$p');
        }
      }
    });

    test('döndürülmemiş sayfada dönüşüm yok', () {
      final t = stampTransform(page, 0);
      expect(t.angle, 0);
      expect(t.translate, Offset.zero);
    });
  });

  group('PdfTools.stampStrokes — imza basma', () {
    test('imza belgeye çizilir, sayfa sayısı değişmez', () async {
      final src = await _makePdf([300, 300]);

      final out = await PdfTools.stampStrokes(
        src,
        pageIndex: 1,
        strokes: const [
          [Offset(0, 0.5), Offset(0.3, 0), Offset(0.6, 1), Offset(1, 0.4)],
        ],
        rect: const Rect.fromLTWH(50, 300, 150, 60),
      );

      expect(out.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]);
      expect(await PdfTools.pageCount(out), 2);
      expect(out.length, greaterThan(src.length)); // çizim eklendi
    });

    test('döndürülmüş sayfaya da basılabilir (koordinat çevirisi)', () async {
      final rotated = await PdfTools.rotatePages(await _makePdf([300]),
          pageIndexes: [0], quarterTurns: 1);

      final out = await PdfTools.stampStrokes(
        rotated,
        pageIndex: 0,
        strokes: const [
          [Offset(0, 0), Offset(1, 1)],
        ],
        // Görünen sayfa 400x300 → sağ alt bölge.
        rect: const Rect.fromLTWH(250, 200, 100, 40),
      );

      expect(await PdfTools.pageCount(out), 1);
      // /Rotate korunmalı: imza basmak sayfayı düzleştirmemeli.
      expect(await _rotation(out), PdfPageRotateAngle.rotateAngle90);
    });

    test('boş imza reddedilir', () async {
      final src = await _makePdf([300]);
      expect(
        () => PdfTools.stampStrokes(src,
            pageIndex: 0,
            strokes: const [
              [Offset(0, 0)]
            ],
            rect: const Rect.fromLTWH(0, 0, 10, 10)),
        throwsArgumentError,
      );
    });
  });

  group('movePageOrder — sayfa taşıma sırası', () {
    test('bir sayfa arkaya (aşağı) taşınır', () {
      expect(movePageOrder(4, 1, 2), [0, 2, 1, 3]);
    });

    test('bir sayfa öne (yukarı) taşınır', () {
      expect(movePageOrder(4, 2, 1), [0, 2, 1, 3]);
    });

    test('ilk sayfa en sona taşınır', () {
      expect(movePageOrder(3, 0, 2), [1, 2, 0]);
    });
  });

  group('PdfTools — sayfa işlemleri', () {
    test('merge: sayfalar sırayla eklenir', () async {
      final a = await _makePdf([100, 110]);
      final b = await _makePdf([200]);

      final out = await PdfTools.merge([a, b]);

      expect(await _widths(out), [100, 110, 200]);
    });

    test('selectPages: sayfa çıkarma ve yeniden sıralama', () async {
      final src = await _makePdf([100, 110, 120, 130]);

      expect(await _widths(await PdfTools.selectPages(src, [2])), [120]);
      // Sıralama: verilen sıra korunur.
      expect(await _widths(await PdfTools.selectPages(src, [3, 0, 1])),
          [130, 100, 110]);
      // Silme = kalanları seçme.
      expect(await _widths(await PdfTools.selectPages(src, [0, 2, 3])),
          [100, 120, 130]);
    });

    test('selectPages: olmayan sayfa ve boş seçim hata verir', () async {
      final src = await _makePdf([100, 110]);
      expect(() => PdfTools.selectPages(src, [5]), throwsRangeError);
      expect(() => PdfTools.selectPages(src, []), throwsArgumentError);
    });

    test('rotatePages: açı mevcut açıya eklenir, 4 turda başa döner', () async {
      final src = await _makePdf([300]);

      final once = await PdfTools.rotatePages(src,
          pageIndexes: [0], quarterTurns: 1);
      expect(await _rotation(once), PdfPageRotateAngle.rotateAngle90);

      final twice = await PdfTools.rotatePages(once,
          pageIndexes: [0], quarterTurns: 1);
      expect(await _rotation(twice), PdfPageRotateAngle.rotateAngle180);

      final back = await PdfTools.rotatePages(twice,
          pageIndexes: [0], quarterTurns: 2);
      expect(await _rotation(back), PdfPageRotateAngle.rotateAngle0);
    });

    test('döndürülmüş sayfa kopyalanırken en/boy yer değiştirir', () async {
      // 300x400 sayfayı 90° döndür → yeni belgede 400x300 olmalı (yan yatmasın).
      final src = await _makePdf([300]);
      final rotated =
          await PdfTools.rotatePages(src, pageIndexes: [0], quarterTurns: 1);

      final out = await PdfTools.selectPages(rotated, [0]);

      final doc = PdfDocument(inputBytes: out);
      expect(doc.pages[0].size.width, 400);
      expect(doc.pages[0].size.height, 300);
      doc.dispose();
    });

    /// Boyutun takas olması yetmez: İÇERİK de dönmeli. Sol-ÜSTteki yazı, 90°
    /// saat yönü döndürmeden sonra sağ-ÜSTe gelmeli (yan yatık kalmamalı).
    test('döndürülmüş sayfada içerik de döner: sol-üst → sağ-üst', () async {
      final src = await _makePdf([300]); // 300x400, yazı (10,10) civarında
      final rotated =
          await PdfTools.rotatePages(src, pageIndexes: [0], quarterTurns: 1);

      final out = await PdfTools.selectPages(rotated, [0]);

      final doc = PdfDocument(inputBytes: out);
      final line = PdfTextExtractor(doc).extractTextLines().first;
      doc.dispose();
      // Hedef sayfa 400x300. Döndürülmüş metnin bounds'u kendi (dönmüş)
      // çerçevesinde raporlanıyor — kenar konumu anlamlı, kutu şekli değil.
      // Yazı SAĞ kenarda (x≈373) ve sayfanın ÜST yarısında olmalı.
      expect(line.bounds.left, greaterThan(350));
      expect(line.bounds.top, lessThan(150));
    });

    test('deletePages sayfayı siler ve vurguları KORUR', () async {
      final src = _withHighlightOnSecondPage(await _makePdf([100, 110, 120]));

      final out = await PdfTools.deletePages(await src, [0]);

      expect(await _widths(out), [110, 120]);
      expect(await PdfTools.annotationCount(out), 1);
    });

    /// Ölçülmüş sınır: sayfa KOPYALAYAN yol annotation taşımaz. Kullanıcı
    /// uyarısı (pdf_tools_screen) bu gerçeğe dayanıyor — sessizce değişirse
    /// bu test kırmızıya döner.
    test('selectPages sayfa kopyalar → vurgular gelmez (bilinen sınır)',
        () async {
      final src = await _withHighlightOnSecondPage(await _makePdf([100, 110]));

      expect(await PdfTools.annotationCount(src), 1);
      expect(await PdfTools.annotationCount(await PdfTools.selectPages(src, [0, 1])), 0);
    });

    test('deletePages: tüm sayfalar silinemez', () async {
      final src = await _makePdf([100, 110]);
      expect(() => PdfTools.deletePages(src, [0, 1]), throwsArgumentError);
    });

    test('pageCount', () async {
      expect(await PdfTools.pageCount(await _makePdf([100, 110, 120])), 3);
    });
  });

  group('PdfTools — parola', () {
    test('parola koy: parolasız açılmaz, parolayla açılır', () async {
      final src = await _makePdf([100, 110]);

      final locked = await PdfTools.setPassword(src, password: 'gizli123');

      expect(() => PdfDocument(inputBytes: locked), throwsA(anything));
      expect(await PdfTools.pageCount(locked, password: 'gizli123'), 2);
    });

    test('parola kaldır: sonrasında parolasız açılır', () async {
      final locked = await PdfTools.setPassword(await _makePdf([100]),
          password: 'gizli123');

      final open =
          await PdfTools.removePassword(locked, currentPassword: 'gizli123');

      expect(await PdfTools.pageCount(open), 1);
    });

    test('boş parola reddedilir', () async {
      final src = await _makePdf([100]);
      expect(() => PdfTools.setPassword(src, password: ''), throwsArgumentError);
    });
  });

  test('compress: geçerli PDF üretir, sayfaları korur', () async {
    final src = await _makePdf([100, 110, 120]);

    final out = await PdfTools.compress(src);

    expect(out.sublist(0, 4), [0x25, 0x50, 0x44, 0x46]); // %PDF
    expect(await PdfTools.pageCount(out), 3);
  });
}

/// PDF grafik dönüşümü: önce döndür, sonra taşı (Syncfusion'daki çağrı sırası).
Offset _applyTransform(({Offset translate, double angle}) t, Offset p) {
  final rad = t.angle * math.pi / 180;
  final c = math.cos(rad), s = math.sin(rad);
  return Offset(
    p.dx * c - p.dy * s + t.translate.dx,
    p.dx * s + p.dy * c + t.translate.dy,
  );
}

/// Her genişlik bir sayfa: sayfa kimliği boyutundan okunur (bkz. dosya başı).
Future<List<int>> _makePdf(List<int> pageWidths) async {
  final doc = PdfDocument();
  doc.pageSettings.margins.all = 0;
  final font = PdfStandardFont(PdfFontFamily.helvetica, 18);
  for (final w in pageWidths) {
    final section = doc.sections!.add()
      ..pageSettings = (PdfPageSettings(Size(w.toDouble(), 400))
        ..margins.all = 0);
    section.pages.add().graphics.drawString(
          'Sayfa $w',
          font,
          bounds: const Rect.fromLTWH(10, 10, 200, 30),
        );
  }
  final bytes = await doc.save();
  doc.dispose();
  return bytes;
}

/// 2. sayfaya bir vurgu (highlight) annotation'ı ekler — kayıp/koruma testleri.
Future<List<int>> _withHighlightOnSecondPage(List<int> bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    doc.pages[1].annotations.add(
      PdfTextMarkupAnnotation(
        const Rect.fromLTWH(10, 10, 80, 20),
        'not',
        PdfColor(255, 255, 0),
      )..textMarkupAnnotationType = PdfTextMarkupAnnotationType.highlight,
    );
    return await doc.save();
  } finally {
    doc.dispose();
  }
}

Future<List<int>> _widths(List<int> bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return [
      for (var i = 0; i < doc.pages.count; i++) doc.pages[i].size.width.round(),
    ];
  } finally {
    doc.dispose();
  }
}

Future<PdfPageRotateAngle> _rotation(List<int> bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return doc.pages[0].rotation;
  } finally {
    doc.dispose();
  }
}

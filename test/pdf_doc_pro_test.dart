import 'dart:convert' show latin1;
import 'dart:ui' show Offset, Rect;

import 'package:dosya_okuyucu/services/pdf/pdf_objects.dart';
import 'package:dosya_okuyucu/services/pdf_doc_pro.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// Faz 39 madde 5 — yer imi düzenleme, izinler, damga, numaralandırma.
Future<List<int>> _doc(int pages) async {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    doc.pages.add().graphics.drawString(
        'Bolum ${i + 1}', PdfStandardFont(PdfFontFamily.helvetica, 14),
        bounds: const Rect.fromLTWH(40, 300, 300, 20));
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

String _text(List<int> bytes, {String? password}) {
  final doc = PdfDocument(inputBytes: bytes, password: password);
  try {
    return PdfTextExtractor(doc).extractText();
  } finally {
    doc.dispose();
  }
}

/// Sayfaları FARKLI içerikli belge: metin + dikdörtgen + çizgi, sayfa başına
/// değişen konum/sayı (veri güvenliği testleri için).
Future<List<int>> _rich(int pages) async {
  final doc = PdfDocument();
  for (var i = 0; i < pages; i++) {
    final g = doc.pages.add().graphics;
    g.drawString('Bolum ${i + 1}', PdfStandardFont(PdfFontFamily.helvetica, 14),
        bounds: Rect.fromLTWH(40, 100.0 + 40 * i, 300, 20));
    for (var k = 0; k <= i; k++) {
      g.drawString('Satir ${i + 1}.$k EMC BDC (x)',
          PdfStandardFont(PdfFontFamily.timesRoman, 11),
          bounds: Rect.fromLTWH(40, 400.0 + 20 * k, 400, 16));
    }
    g.drawRectangle(
        pen: PdfPen(PdfColor(200, 0, 0)),
        bounds: Rect.fromLTWH(30.0 + 10 * i, 60, 100, 30));
  }
  final out = await doc.save();
  doc.dispose();
  return out;
}

String _pageText(List<int> bytes, int page) {
  final doc = PdfDocument(inputBytes: bytes);
  try {
    return PdfTextExtractor(doc)
        .extractText(startPageIndex: page, endPageIndex: page);
  } finally {
    doc.dispose();
  }
}

/// Sayfa başına q/Q/boş OLMAYAN çözülmüş içerik akışları.
List<List<String>> _body(List<int> bytes) {
  final f = PdfFile.parse(bytes);
  return [
    for (final page in f.pages)
      [
        for (final s in f.contentsOf(page))
          if (!const {'', 'q', 'Q'}
              .contains(latin1.decode(f.decodeStream(s)).trim()))
            latin1.decode(f.decodeStream(s)),
      ],
  ];
}

void _sameBody(List<int> original, List<int> after) {
  final o = _body(original), n = _body(after);
  expect(n.length, o.length);
  for (var i = 0; i < o.length; i++) {
    expect(n[i], o[i], reason: 'sayfa ${i + 1} içerik akışı değişti');
    expect(_pageText(after, i), _pageText(original, i),
        reason: 'sayfa ${i + 1} metni değişti');
  }
}

void main() {
  test('yer imi ağacı yazılır ve aynen okunur', () async {
    const items = [
      PdfOutlineItem('Giriş', 0, 0),
      PdfOutlineItem('Amaç', 1, 1),
      PdfOutlineItem('Kapsam', 1, 1),
      PdfOutlineItem('Sonuç', 2, 0),
    ];
    final out = await PdfDocPro.writeOutline(await _doc(3), items);
    expect(PdfDocPro.readOutline(out), items);
    // Silme = listeden çıkarıp yeniden yazmak.
    final fewer = await PdfDocPro.writeOutline(out, [items.first]);
    expect(PdfDocPro.readOutline(fewer), [items.first]);
  });

  test('aşırı düzey bir öncekinin bir altına kenetlenir', () async {
    final out = await PdfDocPro.writeOutline(await _doc(1),
        const [PdfOutlineItem('A', 0, 0), PdfOutlineItem('B', 0, 5)]);
    expect(PdfDocPro.readOutline(out).last.level, 1);
  });

  test('izinler: sahip parolası + yalnız yazdırma', () async {
    final out = await PdfDocPro.setPermissions(await _doc(1),
        ownerPassword: 'sahip123', allow: {PdfAllow.print});
    // Kullanıcı parolası boş: parolasız açılır.
    expect(_text(out), contains('Bolum 1'));
    final allowed = PdfDocPro.readPermissions(out, password: 'sahip123');
    expect(allowed, contains(PdfAllow.print));
    expect(allowed, isNot(contains(PdfAllow.copy)));
  });

  test('damga yalnız seçili sayfalara basılır', () async {
    final out = await PdfDocPro.addStamp(await _doc(2),
        text: 'APPROVED', colorArgb: 0xFF2E7D32, pages: [1], subline: '05.11.2026');
    final doc = PdfDocument(inputBytes: out);
    final ex = PdfTextExtractor(doc);
    expect(ex.extractText(startPageIndex: 0, endPageIndex: 0),
        isNot(contains('APPROVED')));
    expect(ex.extractText(startPageIndex: 1, endPageIndex: 1), contains('APPROVED'));
    doc.dispose();
  });

  test('numara etiketleri', () {
    expect(PdfDocPro.roman(14), 'XIV');
    expect(PdfDocPro.roman(1999), 'MCMXCIX');
    expect(
        PdfDocPro.numberLabel(PageNumberStyle.bates,
            number: 7, total: 9, prefix: 'DAVA-', digits: 5),
        'DAVA-00007');
    expect(
        PdfDocPro.numberLabel(PageNumberStyle.pageOfTotal,
            number: 2, total: 9, pageWord: 'Page'),
        'Page 2 / 9');
    expect(PdfDocPro.numberLabel(PageNumberStyle.roman, number: 4, total: 9), 'iv');
  });

  test('Bates numarası her sayfaya, kapak atlanır', () async {
    final out = await PdfDocPro.addNumbering(await _doc(3),
        style: PageNumberStyle.bates,
        prefix: 'EK',
        digits: 3,
        skipFirstPage: true,
        place: PdfNumberPlace.topRight);
    final doc = PdfDocument(inputBytes: out);
    final ex = PdfTextExtractor(doc);
    expect(ex.extractText(startPageIndex: 0, endPageIndex: 0), isNot(contains('EK0')));
    expect(ex.extractText(startPageIndex: 1, endPageIndex: 1), contains('EK001'));
    expect(ex.extractText(startPageIndex: 2, endPageIndex: 2), contains('EK002'));
    doc.dispose();
  });

  test('üst/alt bilgi yuvaları: çakışan yuva birleşir (B4/P20)', () {
    expect(
        PdfDocPro.headerFooterSlots(PdfNumberPlace.bottomCenter,
            number: '3', header: 'Rapor', footer: 'Gizli'),
        {PdfNumberPlace.topCenter: 'Rapor', PdfNumberPlace.bottomCenter: 'Gizli · 3'});
    expect(
        PdfDocPro.headerFooterSlots(PdfNumberPlace.topRight, header: '  '),
        isEmpty);
  });

  // VERİ GÜVENLİĞİ (B4/P20): önceki katman yolu 2. sayfanın tüm içeriğini
  // siliyordu. Farklı içerikli 4 sayfada ekle → (düzenle) → kaldır sonrası
  // her sayfanın metni ve q/Q dışı içerik akışları özgünüyle BİREBİR aynı.
  test('üst/alt bilgi ekle → kaldır: her sayfa birebir kalır (B4/P20)',
      () async {
    final src = await _rich(4);
    final a = await PdfDocPro.addNumbering(src,
        header: 'BASLIKA', footer: 'ALTA', style: PageNumberStyle.bates,
        prefix: 'NO');
    expect(PdfDocPro.hasHeaderFooter(src), isFalse);
    expect(PdfDocPro.hasHeaderFooter(a), isTrue);
    for (var i = 0; i < 4; i++) {
      expect(_pageText(a, i),
          allOf(contains('BASLIKA'), contains('ALTA'), contains('Bolum ${i + 1}')));
    }
    final c = await PdfDocPro.removeHeaderFooter(a);
    expect(PdfDocPro.hasHeaderFooter(c), isFalse);
    _sameBody(src, c);
    await expectLater(PdfDocPro.removeHeaderFooter(src), throwsStateError);
  });

  test('üst/alt bilgiyi yeniden eklemek eskisinin yerine geçer (B4/P20)',
      () async {
    final src = await _rich(3);
    final a = await PdfDocPro.addNumbering(src,
        header: 'BASLIKA', footer: 'ALTA', skipFirstPage: true);
    expect(_pageText(a, 0), isNot(contains('BASLIKA')));
    final b = await PdfDocPro.addNumbering(a, numbers: false, header: 'BASLIKB');
    for (var i = 0; i < 3; i++) {
      expect(_pageText(b, i), allOf(contains('BASLIKB'),
          isNot(contains('BASLIKA')), isNot(contains('ALTA')),
          contains('Bolum ${i + 1}')));
    }
    _sameBody(src, await PdfDocPro.removeHeaderFooter(b));
  });

  test('her sayfaya paraf + tarih, seçili sayfa sınırı', () async {
    final out = await PdfDocPro.initialPages(await _doc(3),
        strokes: const [
          [Offset(0, 0), Offset(1, 1)],
          [Offset(0, 1), Offset(1, 0)],
        ],
        aspect: 2,
        dateText: '05.11.2026',
        pages: [0, 2]);
    final doc = PdfDocument(inputBytes: out);
    final ex = PdfTextExtractor(doc);
    expect(doc.pages.count, 3);
    expect(ex.extractText(startPageIndex: 0, endPageIndex: 0), contains('05.11.2026'));
    expect(ex.extractText(startPageIndex: 1, endPageIndex: 1),
        isNot(contains('05.11.2026')));
    expect(ex.extractText(startPageIndex: 2, endPageIndex: 2), contains('05.11.2026'));
    doc.dispose();
  });

  test('boş paraf reddedilir', () async {
    expect(
        () async => PdfDocPro.initialPages(await _doc(1),
            strokes: const [[Offset(0, 0)]], aspect: 1),
        throwsArgumentError);
  });

  test('B4/P21: belge bilgisi yazılır ve okunur, parola korunur', () async {
    const meta = (
      title: 'Kira sözleşmesi',
      author: 'Şükrü Öztürk',
      subject: 'Ğ ı İ ç',
      keywords: 'kira, 2026',
    );
    final out = await PdfDocPro.writeMeta(await _doc(1), meta);
    expect(PdfDocPro.readMeta(out), meta);
    // Parolalı belgede bilgi değişir, parola kalır.
    final locked = await PdfDocPro.setPermissions(await _doc(1),
        ownerPassword: 'sahip', userPassword: 'ac', allow: {PdfAllow.print});
    final out2 = await PdfDocPro.writeMeta(locked, meta, password: 'ac');
    expect(() => PdfDocument(inputBytes: out2).dispose(), throwsA(anything));
    expect(PdfDocPro.readMeta(out2, password: 'ac').title, meta.title);
  });

  test('B4/P21: meta temizle eski sürümler dahil iz bırakmaz', () async {
    const meta = (
      title: 'GizliBaslik',
      author: 'GizliYazar',
      subject: 'GizliKonu',
      keywords: 'GizliAnahtar',
    );
    // writeMeta artımlı yazar: eski bilgi sözlüğü de dosyada kalır.
    final src = await PdfDocPro.writeMeta(
        await PdfDocPro.writeMeta(await _doc(2), meta),
        (title: 'Yeni', author: 'GizliYazar', subject: '', keywords: ''));
    expect(latin1.decode(src).contains('GizliBaslik'), isTrue); // ön koşul
    final out = await PdfDocPro.stripMetaInBackground(src);
    final raw = latin1.decode(out);
    for (final s in ['GizliBaslik', 'GizliYazar', 'GizliKonu', 'GizliAnahtar']) {
      expect(raw.contains(s), isFalse, reason: s);
    }
    expect(PdfDocPro.readMeta(out),
        (title: '', author: '', subject: '', keywords: ''));
    expect(_text(out), contains('Bolum 2'));
    // Parolalı belgede parola kalır.
    final locked = await PdfDocPro.setPermissions(await _doc(1),
        ownerPassword: 'sahip', userPassword: 'ac', allow: {PdfAllow.print});
    final out2 = await PdfDocPro.stripMeta(locked, password: 'ac');
    expect(() => PdfDocument(inputBytes: out2).dispose(), throwsA(anything));
    expect(PdfDocPro.readMeta(out2, password: 'ac').author, '');
  });

  test('B4/P17: XFDF dışa/içe aktarma açıklamayı taşır', () async {
    final src = PdfDocument(inputBytes: await _doc(2));
    src.pages[1].annotations
        .add(PdfRectangleAnnotation(const Rect.fromLTWH(50, 50, 80, 40), 'Not'));
    final annotated = await src.save();
    src.dispose();
    expect(PdfDocPro.exportXfdf(await _doc(1)), isNull);
    final xfdf = PdfDocPro.exportXfdf(annotated)!;
    final out = await PdfDocPro.importXfdf(await _doc(2), xfdf);
    final doc = PdfDocument(inputBytes: out);
    try {
      expect(doc.pages[0].annotations.count, 0);
      expect(doc.pages[1].annotations.count, 1);
    } finally {
      doc.dispose();
    }
  });

  test('B4/P17 m.6: katmanlar (OCG) okunur, gizlenir, yeniden açılır', () async {
    final src = PdfDocument();
    final page = src.pages.add();
    src.layers.add(name: 'Arka plan').createGraphics(page).drawRectangle(
        brush: PdfBrushes.red, bounds: const Rect.fromLTWH(10, 10, 50, 50));
    src.layers.add(name: 'Notlar').createGraphics(page).drawString(
        'gizli', PdfStandardFont(PdfFontFamily.helvetica, 12),
        bounds: const Rect.fromLTWH(10, 100, 100, 20));
    final bytes = await src.save();
    src.dispose();

    expect(PdfDocPro.readLayers(await _doc(1)), isEmpty);
    expect(PdfDocPro.readLayers(bytes),
        [(name: 'Arka plan', visible: true), (name: 'Notlar', visible: true)]);
    final hidden = await PdfDocPro.writeLayers(bytes, [true, false]);
    expect(PdfDocPro.readLayers(hidden).map((l) => l.visible), [true, false]);
    expect(latin1.decode(hidden), contains('/OFF'),
        reason: 'görüntüleyici (PDFium) varsayılan görünümün /OFF dizisine bakar');
    final shown = await PdfDocPro.writeLayers(hidden, [true, true]);
    expect(PdfDocPro.readLayers(shown).map((l) => l.visible), [true, true]);
  });
}

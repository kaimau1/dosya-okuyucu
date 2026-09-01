import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/pdf_tools.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

/// **Yerinde metin değiştirme** — sayfa düzenini koruyan düzenleme yolu.
///
/// Kritik davranış: yalnız hedef satırlar değişmeli, sayfadaki DİĞER içerik
/// olduğu gibi kalmalı. Yanlış olsaydı kullanıcı bir cümleyi düzeltmek isterken
/// sayfanın kalanını kaybederdi — bu yüzden testler metni gerçekten geri okuyor.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<int> carlito;

  setUpAll(() async {
    carlito = await File('assets/fonts/Carlito-Regular.ttf').readAsBytes();
  });

  /// 400x600 sayfada iki ayrı metin: üstte [top], altta [bottom].
  Future<List<int>> makePage(String top, String bottom) async {
    final doc = PdfDocument();
    final section = doc.sections!.add()
      ..pageSettings = (PdfPageSettings(const Size(400, 600))..margins.all = 0);
    final g = section.pages.add().graphics;
    final font = PdfStandardFont(PdfFontFamily.helvetica, 14);
    g.drawString(top, font, bounds: const Rect.fromLTWH(50, 20, 300, 20));
    g.drawString(bottom, font, bounds: const Rect.fromLTWH(50, 500, 300, 20));
    final bytes = await doc.save();
    doc.dispose();
    return bytes;
  }

  /// PDF'in TÜM içerik akışlarının çözülmüş metni.
  ///
  /// **Niye `PdfTextExtractor` kullanılmıyor:** Syncfusion'ın çıkarıcısı yüklü
  /// bir sayfaya SONRADAN eklenen içerik akışını okumuyor (ölçüldü) — yani
  /// "yazı eklendi mi?" sorusuna yanlış "hayır" cevabı veriyor. Doğrudan
  /// akışları açıp bakmak hem gerçeği söylüyor hem de çizim operatörlerini
  /// (metin yerleşimi `Tm`, dolgu `re/f`) görmemizi sağlıyor.
  String streamOps(List<int> pdf) {
    final raw = latin1.decode(pdf, allowInvalid: true);
    final out = StringBuffer(raw);
    for (final m in RegExp(r'stream\r?\n').allMatches(raw)) {
      final start = m.end;
      final end = raw.indexOf('endstream', start);
      if (end < 0) continue;
      try {
        final data = pdf.sublist(start, end);
        out.writeln(latin1.decode(
            const ZLibDecoder().decodeBytes(data),
            allowInvalid: true));
      } catch (_) {
        // Sıkıştırılmamış ya da font/resim akışı — atla.
      }
    }
    return out.toString();
  }

  /// Akışlardaki metin yerleştirme (`Tm`) operatörü sayısı = çizilen satır.
  int drawnLines(List<int> pdf) =>
      RegExp(r'1 0 0 1 [\d.\-]+ [\d.\-]+ Tm').allMatches(streamOps(pdf)).length;

  /// Sayfa üstündeki satırın ham (Y-yukarı) dikdörtgeni: y=20..40 üstten →
  /// PDF uzayında top=580, bottom=560.
  const topLineRect = <double>[50, 580, 350, 560];

  test('yeni metin gerçekten çizilir ve eski satırın üstü kapatılır', () async {
    final src = await makePage('ESKI SATIR', 'DOKUNULMAZ');

    final out = await PdfTools.replaceText(
      src,
      pageIndex: 0,
      rawRects: const [topLineRect],
      newText: 'YENI SATIR',
      fontBytes: carlito,
    );

    final ops = streamOps(out);
    // Gömülü font = yazı gerçekten çizildi (çizilmezse font hiç gömülmez).
    expect(ops, contains('/FontFile2'), reason: 'yeni yazı çizilmemiş');
    expect(drawnLines(out), greaterThanOrEqualTo(1));
    // Eski satırı kapatan dolgu dikdörtgeni.
    expect(ops, matches(RegExp(r'[\d.\-]+ [\d.\-]+ [\d.\-]+ [\d.\-]+ re')));
    // Sayfa yapısı bozulmamış.
    final doc = PdfDocument(inputBytes: out);
    expect(doc.pages.count, 1);
    doc.dispose();
  });

  /// **Bu testin varlık sebebi:** kutu yüksekliği yeni metne tam yetmediğinde
  /// Syncfusion hiçbir şey çizmiyor ve hata da atmıyordu — kullanıcı için
  /// "düzenledim, yazı kayboldu" demek. Artık yükseklik sınırsız veriliyor.
  test('kutuya zor sığan uzun metinde yazı KAYBOLMAZ', () async {
    final src = await makePage('kısa', 'alt');

    final out = await PdfTools.replaceText(
      src,
      pageIndex: 0,
      rawRects: const [topLineRect],
      newText: 'Bu cümle özgün satırdan çok daha uzun olduğu için dar kutuya '
          'zor sığar ve birkaç satıra sarmak zorunda kalır.',
      fontBytes: carlito,
    );

    expect(drawnLines(out), greaterThanOrEqualTo(1),
        reason: 'uzun metinde yazı hiç çizilmemiş (sessiz kayıp)');
  });

  test('Türkçe karakterler için font gömülür', () async {
    final src = await makePage('eski', 'alt');

    final out = await PdfTools.replaceText(
      src,
      pageIndex: 0,
      rawRects: const [topLineRect],
      newText: 'Şişli çöğürcüğü ĞÜŞİÖÇ',
      fontBytes: carlito,
    );

    // Alt küme gömülü TrueType: standart Helvetica'ya düşülseydi ğ/ş/ı bozuktu.
    expect(streamOps(out), contains('/FontFile2'));
    expect(streamOps(out), contains('Carlito'));
  });

  test('arka plan sürümü aynı sonucu verir (isolate yolu gerçekten koşar)',
      () async {
    final src = await makePage('eski', 'alt');

    final out = await PdfTools.replaceTextInBackground(
      src,
      pageIndex: 0,
      rawRects: const [topLineRect],
      newText: 'ARKA PLAN',
      fontBytes: carlito,
    );

    expect(streamOps(out), contains('/FontFile2'));
    expect(drawnLines(out), greaterThanOrEqualTo(1));
  });

  test('boş alan listesi reddedilir', () async {
    final src = await makePage('a', 'b');

    expect(
      () => PdfTools.replaceText(src,
          pageIndex: 0,
          rawRects: const [],
          newText: 'x',
          fontBytes: carlito),
      throwsArgumentError,
    );
  });

  group('fitFontSize — kutuya sığdırma', () {
    // Sahte ölçüm: satır yüksekliği = punto, satır sayısı = metin uzunluğu /
    // (genişlik / punto). Gerçek sarma davranışını kabaca taklit eder.
    double measure(String text, double size, double width) {
      final perLine = (width / (size * 0.5)).floor().clamp(1, 1 << 20);
      final lines = (text.length / perLine).ceil();
      return lines * size * 1.2;
    }

    test('sığan metin başlangıç puntosunu korur', () {
      final size = fitFontSize(
        'kısa',
        boxSize: const Size(300, 200),
        startSize: 12,
        measure: measure,
      );
      expect(size, 12);
    });

    test('uzun metinde punto küçülür ama tabanın altına inmez', () {
      final size = fitFontSize(
        'çok uzun bir metin ' * 60,
        boxSize: const Size(200, 20),
        startSize: 12,
        measure: measure,
      );
      expect(size, lessThan(12));
      expect(size, greaterThanOrEqualTo(4));
    });

    test('hiç sığmayan metinde taban punto döner (taşırmak yerine kırp)', () {
      final size = fitFontSize(
        'x' * 100000,
        boxSize: const Size(50, 10),
        startSize: 12,
        measure: measure,
      );
      expect(size, 4);
    });

    // **2026-09-01 kullanıcı bulgusu: "ufacık yazdı".** Seçim kutusu yalnız
    // gliflerin kapladığı yerdir (10 puntoluk bir rakam satırında ~7 birim);
    // ölçüm ise satır yüksekliğini (punto × 1.2) verir. İkisini doğrudan
    // karşılaştıran eski kod, sığan tek satırlık bir metni bile küçültüyordu.
    test('tek satır özgün puntoda kalır (kutu glif yüksekliğinde olsa bile)',
        () {
      final size = fitFontSize(
        '17',
        boxSize: const Size(40, 7), // 10 puntoluk rakamların kapladığı kutu
        startSize: 10,
        measure: measure,
      );
      expect(size, 10);
    });

    test('gerçekten sarmalanan metin yine küçülür', () {
      final size = fitFontSize(
        'çok uzun bir metin ' * 20,
        boxSize: const Size(60, 8),
        startSize: 10,
        measure: measure,
      );
      expect(size, lessThan(10));
    });

    test('taban punto verilirse onun altına inilmez', () {
      final size = fitFontSize(
        'x' * 100000,
        boxSize: const Size(50, 10),
        startSize: 10,
        minSize: 8, // "gerçek punto biliniyor, %20'den fazla küçülme"
        measure: measure,
      );
      expect(size, 8);
    });

    test('boş metin ölçüme hiç gitmez', () {
      var called = false;
      final size = fitFontSize(
        '   ',
        boxSize: const Size(100, 10),
        startSize: 9,
        measure: (t, s, w) {
          called = true;
          return 0;
        },
      );
      expect(size, 9);
      expect(called, isFalse);
    });
  });

  group('fittedStartSize', () {
    test('satır yüksekliğinden punto tahmin eder', () {
      expect(fittedStartSize([const Rect.fromLTWH(0, 0, 100, 10)]),
          closeTo(11.8, 0.001));
    });

    test('farklı yükseklikte satırlarda EN KÜÇÜĞÜ esas alır', () {
      final size = fittedStartSize([
        const Rect.fromLTWH(0, 0, 100, 20), // başlık
        const Rect.fromLTWH(0, 30, 100, 8), // gövde
      ]);
      expect(size, closeTo(8 * 1.18, 0.001));
    });

    test('anlamsız (sıfır yükseklikli) kutularda makul varsayılana düşer', () {
      expect(fittedStartSize([const Rect.fromLTWH(0, 0, 100, 0)]), 11);
    });
  });
}

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:dosya_okuyucu/services/conversion_service.dart';
import 'package:dosya_okuyucu/services/document_scanner.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// Geçerli 1x1 piksel PNG.
const _png1x1 =
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==';

/// Sayfa **içerik akışları** (çizim komutları), açılmış hâlde.
///
/// Yalnız metin çizen akışlar süzülüyor (`BT` = begin text): gömülü yazı tipi
/// programı da sıkıştırılmış bir akış ve ikili içeriğinde tesadüfen "0 Tr"
/// gibi diziler geçebiliyor — çizim kipini orada aramak yanlış sonuç verir.
List<String> _textContentStreams(List<int> pdf) =>
    _inflatedStreams(pdf).where((s) => s.contains('BT ')).toList();

/// PDF içindeki sıkıştırılmış akışları açıp metin olarak döndürür.
///
/// İçerik akışı `/FlateDecode` ile sıkıştırılıyor; çizim komutlarını (ör.
/// metin çizim kipi `3 Tr`) doğrulamanın tek yolu açmak.
List<String> _inflatedStreams(List<int> pdf) {
  final raw = latin1.decode(pdf, allowInvalid: true);
  final out = <String>[];
  var i = 0;
  while (true) {
    final start = raw.indexOf('stream', i);
    if (start < 0) break;
    var dataStart = start + 'stream'.length;
    if (raw.startsWith('\r\n', dataStart)) {
      dataStart += 2;
    } else if (raw.startsWith('\n', dataStart)) {
      dataStart += 1;
    }
    final end = raw.indexOf('endstream', dataStart);
    if (end < 0) break;
    try {
      out.add(latin1.decode(zlib.decode(pdf.sublist(dataStart, end)),
          allowInvalid: true));
    } catch (_) {
      // Sıkıştırılmamış ya da resim akışı — bu testin ilgi alanı değil.
    }
    i = end + 'endstream'.length;
  }
  return out;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late File image;

  setUp(() async {
    image = File('${Directory.systemTemp.path}/scan_ocr_test_'
        '${DateTime.now().microsecondsSinceEpoch}.png');
    await image.writeAsBytes(base64Decode(_png1x1));
  });

  tearDown(() {
    if (image.existsSync()) image.deleteSync();
  });

  /// Kullanıcı hatası 2026-07-31: "metinleri de tanı" ile taranan sayfada OCR
  /// metni KOYU SİYAH ve dev punto olarak basılıyor, belge okunamaz hâle
  /// geliyordu. Görünmezlik saydam renkle (`PdfColor(0,0,0,0)`) deneniyordu ama
  /// `pdf` paketi metin renginde alfa kanalını PDF'e yazmıyor.
  group('aranabilir PDF görünmez metin katmanı', () {
    test('OCR satırları "3 Tr" (görünmez) kipiyle çizilir', () async {
      final pdf = await ConversionService().imagesToPdf(
        [image.path],
        ocrLinesPerPage: [
          [
            const OcrLine('Sour Cream & Chive', ui.Rect.fromLTWH(0, 0, 80, 12)),
            const OcrLine('İçindekiler: Buğday Unu',
                ui.Rect.fromLTWH(0, 14, 90, 12)),
          ],
        ],
      );

      final content = _textContentStreams(pdf);
      expect(content, isNotEmpty, reason: 'metin hiç çizilmemiş');
      final drawn = content.join('\n');
      expect(drawn, contains('3 Tr'),
          reason: 'metin katmanı görünmez kiple çizilmeli');
      // Her yazı tipi kurulumu görünmez kiple gelmeli: bir tanesi bile
      // varsayılan doldurma kipinde kalırsa o satır sayfaya SİYAH basılır —
      // kullanıcının gördüğü hata tam olarak buydu.
      final fonts = ' Tf '.allMatches(drawn).length;
      final invisible = '3 Tr'.allMatches(drawn).length;
      expect(invisible, fonts,
          reason: '$fonts yazı tipi kurulumu, $invisible görünmez kip');
    });

    test('OCR yoksa hiç metin çizilmez', () async {
      final pdf = await ConversionService().imagesToPdf([image.path]);
      expect(_textContentStreams(pdf), isEmpty);
    });
  });

  group('DocumentScanner.textPages', () {
    test('satırlar sayfa sayfa düz metne dönüşür', () {
      final pages = DocumentScanner.textPages([
        [
          const OcrLine('birinci satır', ui.Rect.fromLTWH(0, 0, 10, 10)),
          const OcrLine('ikinci satır', ui.Rect.fromLTWH(0, 10, 10, 10)),
        ],
        [const OcrLine('ikinci sayfa', ui.Rect.fromLTWH(0, 0, 10, 10))],
      ]);

      expect(pages, hasLength(2));
      expect(pages.first.number, 1);
      expect(pages.first.text, 'birinci satır\nikinci satır');
      expect(pages.last.number, 2);
    });

    /// Metni çıkmayan sayfa listeye GİRMEMELİ: "Metin" sekmesinde boş bir
    /// "— Sayfa 2 —" başlığı, tanıma başarısız oldu bilgisini gizlerdi.
    test('boş sayfa atlanır, numaralar kayar değil', () {
      final pages = DocumentScanner.textPages([
        [const OcrLine('var', ui.Rect.fromLTWH(0, 0, 10, 10))],
        const <OcrLine>[],
        [const OcrLine('üçüncüde var', ui.Rect.fromLTWH(0, 0, 10, 10))],
      ]);

      expect(pages.map((p) => p.number), [1, 3]);
    });

    test('yalnız boşluk içeren satırlar düşer', () {
      final pages = DocumentScanner.textPages([
        [
          const OcrLine('  ', ui.Rect.fromLTWH(0, 0, 10, 10)),
          const OcrLine(' gerçek ', ui.Rect.fromLTWH(0, 10, 10, 10)),
        ],
      ]);

      expect(pages.single.text, 'gerçek');
    });
  });

  group('OcrService.joinPages', () {
    test('tek sayfada başlık yazılmaz', () {
      final text = OcrService.joinPages(
          [const OcrPage(1, 'tek sayfa')], (n) => '— Sayfa $n —');
      expect(text, 'tek sayfa');
    });

    test('çok sayfada her sayfa kendi başlığıyla', () {
      final text = OcrService.joinPages(
        [const OcrPage(1, 'bir'), const OcrPage(4, 'dört')],
        (n) => '— Sayfa $n —',
      );
      expect(text, '— Sayfa 1 —\nbir\n\n— Sayfa 4 —\ndört');
    });

    test('boş liste boş dize', () {
      expect(OcrService.joinPages(const [], (n) => '$n'), '');
    });
  });
}

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/ocr_service.dart';
import 'package:dosya_okuyucu/services/scan_export.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Faz 35 / madde 3 — akıllı çıktı: tablo algılama, sayı ayrıştırma, xlsx/
/// txt baytları, kalite sıkıştırma, OCR kutusu ölçekleme.
void main() {
  OcrLine at(String t, double x, double y, {double w = 60, double h = 20}) =>
      OcrLine(t, Rect.fromLTWH(x, y, w, h));

  group('tablo algılama', () {
    test('3 sütunlu fatura kalemleri satır/sütuna ayrılır', () {
      final lines = [
        at('Ürün', 10, 10), at('Adet', 200, 12), at('Tutar', 400, 9),
        at('Kalem', 10, 50), at('2', 205, 51), at('1.250,00', 398, 49),
        at('Vida', 12, 90), at('10', 202, 92), at('35,50', 401, 88),
        at('Teşekkür ederiz', 10, 140, w: 200),
      ];
      final table = ScanExport.detectTable(lines);
      expect(table, hasLength(4));
      expect(table[0], ['Ürün', 'Adet', 'Tutar']);
      expect(table[1], ['Kalem', '2', '1.250,00']);
      expect(table[2], ['Vida', '10', '35,50']);
      expect(table[3], ['Teşekkür ederiz'], reason: 'tek kutulu satır tek hücre');
    });

    test('düz metin: her satır tek hücre, sıra korunur', () {
      final table = ScanExport.detectTable([
        at('ikinci', 10, 60),
        at('birinci', 10, 10),
      ]);
      expect(table, [
        ['birinci'],
        ['ikinci'],
      ]);
    });

    test('boş girdi', () {
      expect(ScanExport.detectTable(const []), isEmpty);
    });
  });

  group('sayı ayrıştırma', () {
    test('TR/EN ayraçları ve para birimleri', () {
      expect(ScanExport.parseNumber('1.250,00'), 1250.0);
      expect(ScanExport.parseNumber('1,250.50'), 1250.5);
      expect(ScanExport.parseNumber('35,50'), 35.5);
      expect(ScanExport.parseNumber('₺ 250'), 250.0);
      expect(ScanExport.parseNumber('%18'), 18.0);
      expect(ScanExport.parseNumber('12.5'), 12.5);
      expect(ScanExport.parseNumber('1.000'), 1000.0);
    });

    test('metin ve baştaki sıfırlı numara sayı sayılmaz', () {
      expect(ScanExport.parseNumber('Vida'), isNull);
      expect(ScanExport.parseNumber('0532 123 45 67'), isNull);
      expect(ScanExport.parseNumber(''), isNull);
    });
  });

  group('çıktı baytları', () {
    final pages = [
      [at('Ürün', 10, 10), at('Tutar', 300, 10), at('Kalem', 10, 50), at('12,50', 300, 50)],
      [at('İkinci sayfa', 10, 10, w: 200)],
    ];

    test('xlsx: geçerli zip, sayfa başına çalışma sayfası, sayı hücresi', () {
      final bytes = ScanExport.toXlsx(pages);
      final zip = ZipDecoder().decodeBytes(bytes);
      final names = zip.files.map((f) => f.name).toSet();
      expect(names, containsAll(['xl/worksheets/sheet1.xml', 'xl/worksheets/sheet2.xml']));
      final sheet1 = utf8.decode(zip.findFile('xl/worksheets/sheet1.xml')!.content as List<int>);
      expect(sheet1, contains('<v>12.5</v>'));
    });

    test('txt: UTF-8 BOM + sayfalar boş satırla ayrık', () {
      final bytes = ScanExport.toTxt(pages);
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final text = utf8.decode(bytes.sublist(3));
      expect(text, 'Ürün\nTutar\nKalem\n12,50\n\nİkinci sayfa');
    });
  });

  group('kalite', () {
    Uint8List jpeg(int w, int h) {
      final i = img.Image(width: w, height: h, numChannels: 3);
      for (var y = 0; y < h; y++) {
        for (var x = 0; x < w; x++) {
          i.setPixelRgb(x, y, (x * 7) % 256, (y * 5) % 256, 128);
        }
      }
      return img.encodeJpg(i, quality: 95);
    }

    test('uzun kenar sınıra iner, oran döner; küçük görsel büyütülmez', () {
      final big = ScanExport.compressBytesWithRatio(jpeg(2000, 1000), 1000, 70);
      expect(big.ratio, closeTo(0.5, 1e-9));
      final decoded = img.decodeJpg(big.bytes)!;
      expect(decoded.width, 1000);
      expect(decoded.height, 500);
      final small = ScanExport.compressBytesWithRatio(jpeg(300, 200), 1000, 70);
      expect(small.ratio, 1.0);
    });

    test('düşük kalite daha küçük dosya', () {
      final src = jpeg(1600, 1200);
      final lo = ScanExport.compressBytes(src, ScanQuality.small.maxEdge,
          ScanQuality.small.jpegQuality);
      final hi = ScanExport.compressBytes(src, ScanQuality.high.maxEdge,
          ScanQuality.high.jpegQuality);
      expect(lo.length, lessThan(hi.length));
    });

    test('OCR kutuları oranla ölçeklenir', () {
      final scaled = ScanExport.scaleLines([at('a', 100, 40, w: 50, h: 10)], 0.5);
      expect(scaled.single.box, const Rect.fromLTWH(50, 20, 25, 5));
      final same = [at('b', 1, 1)];
      expect(identical(ScanExport.scaleLines(same, 1), same), isTrue);
    });

    test('boyut tahmini sayfa sayısıyla doğrusal', () {
      final one = ScanExport.estimateFromSample(100000, 1);
      final ten = ScanExport.estimateFromSample(100000, 10);
      expect(ten - one, 9 * (100000 + 1536));
    });
  });
}

import 'dart:convert';
import 'dart:io';

import 'package:dosya_okuyucu/services/scan_actions.dart';
import 'package:dosya_okuyucu/services/scan_enhance.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

/// Faz 35 / ek 6 — fiş → gider satırı; madde 2 — yeni filtreler.
void main() {
  group('fiş ayrıştırma', () {
    const receipt = 'MİGROS TİCARET\n'
        'TARİH: 04.11.2026 SAAT 18:22\n'
        'EKMEK          12,50\n'
        'SÜT            34,90\n'
        'TOPLAM        *47,40\n'
        'NAKİT         100,00\n';

    test('tarih, toplam (TOPLAM satırı), satıcı', () {
      final info = ReceiptInfo.parse(receipt);
      expect(info.date, DateTime(2026, 11, 4));
      expect(info.total, 47.40);
      expect(info.merchant, 'MİGROS TİCARET');
    });

    test('binlik ayraçlı tutar', () {
      final info = ReceiptInfo.parse('GENEL TOPLAM 1.234,56');
      expect(info.total, 1234.56);
    });

    test('CSV satırı ; ayraçlı, virgüllü tutar', () {
      final row = ReceiptInfo(
              date: DateTime(2026, 1, 5), total: 47.4, merchant: 'A "B"')
          .toCsvRow('fis.pdf');
      expect(row, '"05.01.2026";"A ""B""";"47,40";"fis.pdf"');
    });

    test('boş metin → boş', () {
      expect(ReceiptInfo.parse('merhaba').isEmpty, isTrue);
    });

    test('Giderler.csv: başlık bir kez, satırlar eklenir', () async {
      final dir = await Directory.systemTemp.createTemp('gider');
      addTearDown(() => dir.delete(recursive: true));
      final info = ReceiptInfo.parse(receipt);
      await ScanActions.appendExpense(dir.path, info, 'a.pdf');
      final path = await ScanActions.appendExpense(dir.path, info, 'b.pdf');
      final bytes = await File(path).readAsBytes();
      expect(bytes.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      final lines = utf8.decode(bytes.sublist(3)).trim().split('\r\n');
      expect(lines, hasLength(3));
      expect(lines.first, ScanActions.expenseHeader);
      expect(lines[2], endsWith('"b.pdf"'));
    });
  });

  group('yeni filtreler', () {
    img.Image tinted() {
      // Sarımsı kâğıt + mavi yazı şeridi + kırmızı alan.
      final i = img.Image(width: 80, height: 60, numChannels: 3);
      img.fill(i, color: img.ColorRgb8(236, 226, 196));
      for (var x = 10; x < 70; x++) {
        for (var y = 28; y < 32; y++) {
          i.setPixelRgb(x, y, 30, 40, 160);
        }
      }
      return i;
    }

    test('gölge sil: kâğıt saf beyaz, mürekkep koyu kalır', () {
      final out = ScanEnhance.applyToImage(tinted(), ScanFilter.shadowless);
      final paper = out.getPixel(4, 4);
      expect([paper.r, paper.g, paper.b], [255, 255, 255]);
      final ink = out.getPixel(40, 30);
      expect(ink.r, lessThan(120));
    });

    test('renkli-canlı otomatikten daha doygun', () {
      double chroma(img.Image o) {
        final px = o.getPixel(40, 30);
        final m = [px.r, px.g, px.b];
        return (m.reduce((a, b) => a > b ? a : b) -
                m.reduce((a, b) => a < b ? a : b))
            .toDouble();
      }

      final auto = ScanEnhance.applyToImage(tinted(), ScanFilter.auto);
      final vivid = ScanEnhance.applyToImage(tinted(), ScanFilter.vivid);
      expect(chroma(vivid), greaterThanOrEqualTo(chroma(auto)));
    });
  });
}

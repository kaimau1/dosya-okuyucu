import 'dart:io';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xls_legacy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('XlsLegacy — eski .xls (BIFF8) okuma', () {
    late Uint8List bytes;
    setUpAll(() {
      bytes = File('test/fixtures/legacy_sample.xls').readAsBytesSync();
    });

    test('sayfa adı ve hücre değerleri (metin + sayı) okunur', () {
      final xls = XlsLegacy.tryParse(bytes);
      expect(xls, isNotNull);
      expect(xls!.sheets.length, 1);
      final s = xls.sheets.first;
      expect(s.name, 'Sayfa1');
      expect(s.rows.length, 2);
      expect(s.rows[0], ['Alfa', 'Beta']); // LABELSST → SST
      expect(s.rows[1], ['42.5', '100']); // NUMBER + RK(int)
    });

    test('plainText satır/sütunları düz metne çevirir', () {
      final xls = XlsLegacy.tryParse(bytes)!;
      expect(xls.plainText, 'Alfa\tBeta\n42.5\t100');
    });

    test('OLE olmayan / bozuk bayt → null', () {
      expect(XlsLegacy.tryParse(Uint8List.fromList([1, 2, 3, 4])), isNull);
      // Geçerli OOXML zip (yeni .xlsx) de bu yol için null olmalı.
      final zip = Uint8List.fromList([0x50, 0x4B, 0x03, 0x04, 0, 0, 0, 0]);
      expect(XlsLegacy.tryParse(zip), isNull);
    });
  });
}

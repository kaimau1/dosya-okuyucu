import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_reader.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 26b / plan madde 6 — okuma sınırı dürüst: sınır ötesindeki hücre
/// sessizce atılıp kaydette dosyadan SİLİNMEZ.
void main() {
  XlsxEditor open(Map<int, Map<int, XlsxWriteCell>> cells) => XlsxEditor.parse(
      XlsxWriter.build([XlsxWriteSheet(name: 'S', cells: cells)]));

  test('sınır içindeki kitap kesik sayılmaz, kaydedilir', () {
    final e = open({
      0: {0: const XlsxWriteCell(number: 1)},
    });
    expect(e.truncated, isFalse);
    expect(e.save(), isNotEmpty);
  });

  test('satır sınırı ötesinde hücre → kesik, kaydetme reddedilir', () async {
    final e = open({
      0: {0: const XlsxWriteCell(number: 1)},
      XlsxReader.maxRows: {0: const XlsxWriteCell(text: 'uzak')},
    });
    expect(e.truncated, isTrue);
    expect(e.sheets.first.layout.maxRow, 0);
    expect(() => e.save(), throwsA(isA<XlsxTruncatedException>()));
    await expectLater(e.saveAsync(), throwsA(isA<XlsxTruncatedException>()));
  });

  test('sütun sınırı ötesinde hücre → kesik', () {
    final e = open({
      0: {
        0: const XlsxWriteCell(number: 1),
        XlsxReader.maxColumns: const XlsxWriteCell(number: 2),
      },
    });
    expect(e.truncated, isTrue);
  });
}

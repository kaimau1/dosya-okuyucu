import 'dart:typed_data';

import 'package:dosya_okuyucu/services/office_crypto.dart';
import 'package:dosya_okuyucu/services/ole_cfb.dart';
import 'package:dosya_okuyucu/services/ole_cfb_writer.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 6 — parolalı xlsx (ECMA-376 Agile): şifrele → aç, yanlış
/// parola, CFB kabı (mini akış, çok FAT sektörü, DIFAT).
void main() {
  final book = XlsxWriter.build([
    XlsxWriteSheet(name: 'Gizli', cells: {
      0: {0: const XlsxWriteCell(text: 'maaş'), 1: const XlsxWriteCell(number: 1234)},
    }),
  ]);

  test('şifrele → çöz gidiş-dönüşü, kitap aynen açılır', () {
    final enc = OfficeCrypto.encrypt(book, 'Gizli*123', spinCount: 1000);
    expect(OleFile.looksLikeOle(enc), isTrue);
    expect(OfficeCrypto.isEncrypted(enc), isTrue);
    expect(OfficeCrypto.isEncrypted(book), isFalse);
    final dec = OfficeCrypto.decrypt(enc, 'Gizli*123');
    expect(dec, book);
    final sheet = XlsxEditor.parse(dec).sheets.single;
    expect(sheet.rawAt(0, 0), 'maaş');
  });

  test('yanlış parola reddedilir', () {
    final enc = OfficeCrypto.encrypt(book, 'doğru', spinCount: 500);
    expect(
      () => OfficeCrypto.decrypt(enc, 'yanlış'),
      throwsA(isA<OfficeCryptoException>()
          .having((e) => e.code, 'code', 'wrong_password')),
    );
  });

  test('DataSpaces akışları kapta', () {
    final enc = OfficeCrypto.encrypt(book, 'x', spinCount: 10);
    final ole = OleFile.tryParse(enc)!;
    for (final name in [
      'EncryptionInfo',
      'EncryptedPackage',
      'Version',
      'DataSpaceMap',
      'StrongEncryptionDataSpace',
      '\u0006Primary',
    ]) {
      expect(ole.stream(name), isNotNull, reason: name);
    }
  });

  test('CFB: küçük + büyük akış, DIFAT gerektiren boy', () {
    final small = Uint8List.fromList(List<int>.generate(300, (i) => i % 251));
    final big = Uint8List.fromList(List<int>.generate(8 << 20, (i) => (i * 7) % 256));
    final cfb = CfbWriter.write([
      CfbNode.stream('A', small),
      CfbNode.storage('Depo', [CfbNode.stream('B', big)]),
    ]);
    final ole = OleFile.tryParse(cfb)!;
    expect(ole.stream('A'), small);
    expect(ole.stream('B'), big);
  });
}

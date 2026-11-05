import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/office_crypto.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_save_patch.dart';
import 'package:dosya_okuyucu/services/xlsx_writer.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 36 madde 12 — sayfa koruması, düzenlenebilir aralık, yazdırma alanı.
void main() {
  XlsxEditor book() => XlsxEditor.parse(XlsxWriter.build([
        XlsxWriteSheet(name: 'Bütçe', cells: {
          0: {0: const XlsxWriteCell(text: 'Gelir'), 1: const XlsxWriteCell(number: 10)},
        }),
        XlsxWriteSheet(name: 'Diğer', cells: {
          0: {0: const XlsxWriteCell(number: 1)},
        }),
      ]));

  String part(List<int> bytes, String name) => utf8.decode(ZipDecoder()
      .decodeBytes(bytes)
      .files
      .firstWhere((f) => f.name == name)
      .content as List<int>);

  test('Excel 16 bit parola özeti bilinen değerler', () {
    expect(XlsxProtectionWrite.legacyHash('password'), '83AF');
    expect(XlsxProtectionWrite.legacyHash('test'), 'CBEB');
  });

  test('parolalı koruma + düzenlenebilir aralık yazılır, geri okunur', () {
    final ed = book();
    final s = ed.sheets.first;
    s.protect(password: 'gizli');
    s.setAllowEdit(const XlsxRange(1, 1, 4, 2), true);
    final bytes = ed.save();
    final xml = part(bytes, 'xl/worksheets/sheet1.xml');
    expect(xml, contains('sheetProtection'));
    expect(xml, contains(XlsxProtectionWrite.legacyHash('gizli')));
    expect(xml, contains('sqref="B2:C5"'));
    // Şema sırası: sheetProtection sheetData'dan SONRA.
    expect(xml.indexOf('sheetProtection'), greaterThan(xml.indexOf('sheetData')));

    final back = XlsxEditor.parse(bytes).sheets.first;
    expect(back.isProtected, isTrue);
    expect(back.protectionNeedsPassword, isTrue);
    expect(back.layout.canEdit(0, 0), isFalse);
    expect(back.layout.canEdit(2, 1), isTrue);
    expect(back.unprotect('yanlış'), isFalse);
    expect(back.unprotect('gizli'), isTrue);
    expect(back.isProtected, isFalse);
  });

  test('koruma kaldırılınca dosyadan da silinir', () {
    final ed = book();
    ed.sheets.first.protect();
    final once = XlsxEditor.parse(ed.save());
    expect(once.sheets.first.isProtected, isTrue);
    expect(once.sheets.first.unprotect(), isTrue);
    final xml = part(once.save(), 'xl/worksheets/sheet1.xml');
    expect(xml, isNot(contains('sheetProtection')));
  });

  test('yazdırma alanı workbook.xml definedNames altına, yerel sayfa kimliğiyle', () {
    final ed = book();
    ed.sheets[1].setPrintArea(const XlsxRange(0, 0, 9, 3));
    final bytes = ed.save();
    final wb = part(bytes, 'xl/workbook.xml');
    expect(wb, contains('_xlnm.Print_Area'));
    expect(wb, contains('localSheetId="1"'));
    expect(wb, contains(r"'Diğer'!$A$1:$D$10"));
    expect(wb.indexOf('definedNames'), greaterThan(wb.indexOf('<sheets')));
    final back = XlsxEditor.parse(bytes);
    expect(back.sheets[1].layout.printArea, 'A1:D10');
    expect(back.sheets.first.layout.printArea, isNull);

    back.sheets[1].setPrintArea(null);
    final cleared = part(back.save(), 'xl/workbook.xml');
    expect(cleared, isNot(contains('_xlnm.Print_Area')));
  });

  test('güçlü (SHA-512) sayfa özeti doğrulanır', () {
    // ISO 29500: H0 = SHA-512(tuz + UTF-16LE), Hn = SHA-512(H + LE32(n)).
    const salt = 'AAECAwQFBgcICQoLDA0ODw==';
    const hash = 'MYsPwG8iHhjscMqOrkB9u5dWynpFF5TXAxOPKb5nbrS38ZJt05PlxRwjmTZxBwGTR9y3m0G/dPV02ewsT0kQvA==';
    bool check(String pw) => OfficeCrypto.verifySheetHash(pw,
        algorithm: 'SHA-512', saltB64: salt, hashB64: hash, spin: 1000);
    expect(check('Gizli1'), isTrue);
    expect(check('gizli1'), isFalse);
    expect(
        OfficeCrypto.verifySheetHash('x',
            algorithm: 'MD5', saltB64: salt, hashB64: hash, spin: 1),
        isFalse);
  });
}

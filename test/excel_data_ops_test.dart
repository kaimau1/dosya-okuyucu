import 'dart:io';

import 'package:dosya_okuyucu/services/sheet_data_ops.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_save_patch.dart';
import 'package:flutter_test/flutter_test.dart';

/// Faz 27 — Veri araçları (yinelenenler, metni sütunlara böl) ve bölme
/// dondurma: saf mantık + kaydet/yeniden aç gidiş-dönüşü.
void main() {
  group('yinelenenler', () {
    test('ilk geçen kalır; büyük/küçük harf ve Türkçe katlama duyarsız', () {
      final rows = [
        ['Ad', 'Şehir'],
        ['Ayşe', 'IZMİR'],
        ['ayşe', 'ızmir'],
        ['Ali', 'Ankara'],
        ['Ali', 'Ankara'],
        ['', ''],
        ['', ''],
      ];
      expect(duplicateRowIndexes(rows, hasHeader: true), [2, 4]);
      // Üst bilgi yoksa ilk satır da değerlendirilir (hepsi benzersiz bu kez).
      expect(duplicateRowIndexes(rows).contains(0), isFalse);
    });
    test('yalnız seçili sütunlara göre', () {
      final rows = [
        ['a', '1'],
        ['a', '2'],
      ];
      expect(duplicateRowIndexes(rows, cols: [0]), [1]);
      expect(duplicateRowIndexes(rows), isEmpty);
    });
  });

  group('metni sütunlara böl', () {
    test('virgül, noktalı virgül, özel ayraç', () {
      expect(splitText('a,b;c', const SplitSpec(comma: true)), ['a', 'b;c']);
      expect(splitText('a,b;c', const SplitSpec(comma: true, semicolon: true)),
          ['a', 'b', 'c']);
      expect(splitText('a|b', const SplitSpec(custom: '|')), ['a', 'b']);
    });
    test('tırnak içindeki ayraç bölmez; "" tırnak olur', () {
      expect(splitText('x,"a,b",y', const SplitSpec(comma: true)),
          ['x', 'a,b', 'y']);
      expect(splitText('"he said ""hi""",z', const SplitSpec(comma: true)),
          ['he said "hi"', 'z']);
    });
    test('art arda ayraçlar tek sayılabilir', () {
      expect(splitText('a  b', const SplitSpec(space: true)), ['a', '', 'b']);
      expect(splitText('a  b', const SplitSpec(space: true, merge: true)),
          ['a', 'b']);
    });
    test('ayraç yoksa olduğu gibi', () {
      expect(splitText('abc', const SplitSpec()), ['abc']);
      expect(splitText('abc', const SplitSpec(comma: true)), ['abc']);
    });
  });

  group('bölme dondurma', () {
    test('oluştur → kaydet → yeniden aç: bölme var', () {
      final ed = XlsxEditor.blank();
      final sheet = ed.sheets.first;
      ed.setCell(sheet.name, 0, 0, 'Ad');
      sheet.setFreeze(1, 1);
      final again = XlsxEditor.parse(ed.save());
      expect(again.sheets.first.frozenRows, 1);
      expect(again.sheets.first.frozenCols, 1);
    });

    test('var olan bölmeyi ÇÖZ → kaydet: bölme kalkar (boş yama atlanmaz)', () {
      final bytes = File('test/fixtures/rich_sheet.xlsx').readAsBytesSync();
      final ed = XlsxEditor.parse(bytes);
      final sheet = ed.sheets.firstWhere((s) => s.frozenRows > 0 || s.frozenCols > 0);
      sheet.setFreeze(0, 0);
      final again = XlsxEditor.parse(ed.save());
      final s2 = again.sheets.firstWhere((s) => s.name == sheet.name);
      expect(s2.frozenRows, 0);
      expect(s2.frozenCols, 0);
    });

    test('yama: freezeEdited tek başına yamayı boş saymaz', () {
      expect(const XlsxSheetPatch(name: 'x').isEmpty, isTrue);
      expect(const XlsxSheetPatch(name: 'x', freezeEdited: true).isEmpty,
          isFalse);
    });
  });

  test('satır gizle / göster kaydedilir', () {
    final ed = XlsxEditor.blank();
    final sheet = ed.sheets.first;
    for (var r = 0; r < 4; r++) {
      ed.setCell(sheet.name, r, 0, 'v$r');
    }
    sheet.setRowHidden(2, true);
    final again = XlsxEditor.parse(ed.save());
    expect(again.sheets.first.layout.hiddenRows, contains(2));
    sheet.setRowHidden(2, false);
    final shown = XlsxEditor.parse(ed.save());
    expect(shown.sheets.first.layout.hiddenRows, isEmpty);
  });
}

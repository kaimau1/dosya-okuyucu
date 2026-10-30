import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// Faz 27 kalanı: "Tablo olarak biçimlendir" gerçek Excel tablosu da yazar
/// (`xl/tables/tableN.xml` + ilişki + `<tableParts>` + içerik türü).
void main() {
  String part(List<int> zip, String name) => utf8.decode(
      ZipDecoder().decodeBytes(zip).findFile(name)!.content as List<int>);

  XlsxEditor book() {
    final e = XlsxEditor.blank();
    final s = e.sheets.first.name;
    e.setCell(s, 0, 0, 'Ürün');
    e.setCell(s, 0, 1, 'Adet');
    e.setCell(s, 1, 0, 'Elma');
    e.setCell(s, 1, 1, '3');
    e.setCell(s, 2, 0, 'Armut');
    e.setCell(s, 2, 1, '5');
    return e;
  }

  test('tablo parçası, ilişki, tableParts ve içerik türü yazılır', () {
    final e = book();
    final name = e.sheets.first.name;
    e.setAutoFilter(name, 'A1:B3');
    e.tables.add(XlsxTableSpec(
        sheetName: name, top: 0, left: 0, bottom: 2, right: 1));
    final out = e.save();
    final names =
        ZipDecoder().decodeBytes(out).files.map((f) => f.name).toList();
    expect(names, contains('xl/tables/table1.xml'));
    final table = part(out, 'xl/tables/table1.xml');
    expect(table, contains('ref="A1:B3"'));
    expect(table, contains('name="Ürün"'));
    expect(table, contains('name="Adet"'));
    expect(part(out, '[Content_Types].xml'), contains('/xl/tables/table1.xml'));
    final sheet = part(out, 'xl/worksheets/sheet1.xml');
    expect(sheet, contains('<tableParts count="1">'));
    // İyi biçimli XML (Excel bozuk XML'de dosyayı "onarır").
    XmlDocument.parse(sheet);
    XmlDocument.parse(table);
    expect(sheet, isNot(contains('<autoFilter')),
        reason: 'tablonun kendi süzgeci var; sayfa süzgeci çakışırdı');
    expect(part(out, 'xl/worksheets/_rels/sheet1.xml.rels'),
        contains('relationships/table'));
    // Yeniden açılabilir, değerler yerinde.
    final again = XlsxEditor.parse(out);
    expect(again.sheets.first.rawAt(2, 0), 'Armut');
  });

  test('sayı başlıklı / yinelenen başlıklı aralıkta tablo yazılmaz', () {
    final e = book();
    final name = e.sheets.first.name;
    e.setCell(name, 0, 1, '2026');
    e.tables.add(XlsxTableSpec(
        sheetName: name, top: 0, left: 0, bottom: 2, right: 1));
    final out = e.save();
    expect(ZipDecoder().decodeBytes(out).findFile('xl/tables/table1.xml'),
        isNull);
  });
}

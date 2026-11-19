import 'dart:convert';
import 'dart:typed_data';

import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/xlsx_synth.dart';

/// B10 m.6 — **sadakat bekçisi**: bizim anlamadığımız ama Excel'in
/// kullandığı parçalar (özet tablo + önbellek, dilimleyici, koşullu biçim
/// `x14` uzantısı, tanımlı adlar, dış bağlantı, makro) kaydetmede KAYBOLMAZ.
/// Dokunmadan kaydet ve tek hücre düzenle → kaydet, iki yol da sınanır.
XmlElement _xml(Map<String, List<int>> parts, String name) =>
    XmlDocument.parse(utf8.decode(parts[name]!)).rootElement;

List<XmlElement> _all(XmlElement root, String local) => root.descendants
    .whereType<XmlElement>()
    .where((e) => e.name.local == local)
    .toList();

void _expectPreserved(Uint8List source, Uint8List out) {
  final before = zipParts(source);
  final after = zipParts(out);

  // 1) Hiçbir yazıcının dokunmadığı parçalar bayt bayt aynı.
  for (final name in synthOpaqueParts) {
    expect(after[name], isNotNull, reason: '$name kayboldu');
    expect(after[name], before[name], reason: '$name değişti');
  }

  // 2) Paket bağları: ilişkiler ve içerik türleri yerinde.
  final rels = {
    for (final r in _all(_xml(after, 'xl/_rels/workbook.xml.rels'), 'Relationship'))
      r.getAttribute('Id'): r.getAttribute('Target'),
  };
  expect(rels['rId4'], 'vbaProject.bin');
  expect(rels['rId5'], 'pivotCache/pivotCacheDefinition1.xml');
  expect(rels['rId6'], 'externalLinks/externalLink1.xml');
  expect(rels['rId7'], 'slicerCaches/slicerCache1.xml');
  expect(rels.values, isNot(contains('calcChain.xml')));
  final sheetRels = {
    for (final r in _all(
        _xml(after, 'xl/worksheets/_rels/sheet1.xml.rels'), 'Relationship'))
      r.getAttribute('Id'): r.getAttribute('Target'),
  };
  expect(sheetRels['rId1'], '../pivotTables/pivotTable1.xml');
  expect(sheetRels['rId2'], '../slicers/slicer1.xml');

  final types = _xml(after, '[Content_Types].xml');
  String? typeOf(String part) => _all(types, 'Override')
      .where((o) => o.getAttribute('PartName') == part)
      .firstOrNull
      ?.getAttribute('ContentType');
  expect(typeOf('/xl/workbook.xml'),
      'application/vnd.ms-excel.sheet.macroEnabled.main+xml',
      reason: '.xlsm makro kitabı olarak kalmalı');
  expect(
      _all(types, 'Default')
          .any((d) => d.getAttribute('Extension') == 'bin'),
      isTrue);
  for (final part in [
    '/xl/pivotTables/pivotTable1.xml',
    '/xl/pivotCache/pivotCacheDefinition1.xml',
    '/xl/pivotCache/pivotCacheRecords1.xml',
    '/xl/slicers/slicer1.xml',
    '/xl/slicerCaches/slicerCache1.xml',
    '/xl/externalLinks/externalLink1.xml',
  ]) {
    expect(typeOf(part), isNotNull, reason: '$part içerik türü');
  }

  // 3) workbook.xml: tanımlı adlar, özet önbelleği, dış başvuru, dilimleyici.
  final wb = _xml(after, 'xl/workbook.xml');
  final names = {
    for (final d in _all(wb, 'definedName'))
      d.getAttribute('name'): (d.getAttribute('localSheetId'), d.innerText),
  };
  expect(names['Oran'], (null, r'Sheet1!$B$1'));
  expect(names['Yerel'], ('0', r'Sheet1!$A$2:$A$4'));
  expect(names['Slicer_Bolge'], (null, '#N/A'));
  final cache = _all(wb, 'pivotCache').single;
  expect(cache.getAttribute('cacheId'), '7');
  expect(cache.getAttribute('r:id'), 'rId5');
  expect(_all(wb, 'externalReference').single.getAttribute('r:id'), 'rId6');
  expect(_all(wb, 'slicerCache').single.getAttribute('r:id'), 'rId7');
  expect(_all(wb, 'workbookPr').single.getAttribute('codeName'),
      'BuCalismaKitabi', reason: 'makro kod adı');
  expect(wb.childElements.last.name.local, 'extLst',
      reason: 'extLst kitabın son çocuğu');

  // 4) Sayfa: x14 koşullu biçim + dilimleyici listesi + klasik koşullu biçim.
  final ws = _xml(after, 'xl/worksheets/sheet1.xml');
  expect(ws.childElements.last.name.local, 'extLst',
      reason: 'extLst sayfanın son çocuğu');
  final x14Rule = _all(ws, 'cfRule')
      .where((e) => e.name.prefix == 'x14')
      .single;
  expect(x14Rule.getAttribute('type'), 'dataBar');
  expect(_all(ws, 'sqref').single.innerText, 'B2:B4');
  expect(_all(ws, 'slicer').single.getAttribute('r:id'), 'rId2');
  final cf = _all(ws, 'conditionalFormatting')
      .where((e) => e.name.prefix == null)
      .single;
  expect(cf.getAttribute('sqref'), 'B2:B4');
}

void main() {
  test('dokunmadan kaydet: zengin parçaların hepsi korunur', () {
    final src = synthXlsm();
    final e = XlsxEditor.parse(src);
    expect(e.sheets.single.rawAt(0, 0), 'Bölge');
    final out = e.save();
    _expectPreserved(src, out);
    final back = XlsxEditor.parse(out).sheets.single;
    expect(back.rawAt(1, 0), 'Ege');
    expect(back.rawAt(3, 1), '9');
  });

  test('tek hücre düzenle → kaydet: değişiklik yazılır, gerisi korunur', () {
    final src = synthXlsm();
    final e = XlsxEditor.parse(src)..setCell('Sheet1', 5, 0, 'yeni satır');
    final out = e.save();
    _expectPreserved(src, out);
    final back = XlsxEditor.parse(out).sheets.single;
    expect(back.rawAt(5, 0), 'yeni satır');
    expect(back.rawAt(2, 0), 'Marmara');
    expect(back.rawAt(0, 1), '0.18');
  });

  test('iki kez kaydet: ikinci kayıt ilkini bozmaz', () {
    final once = XlsxEditor.parse(synthXlsm()).save();
    final twice = XlsxEditor.parse(once).save();
    _expectPreserved(synthXlsm(), twice);
  });
}

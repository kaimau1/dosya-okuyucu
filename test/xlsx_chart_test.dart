import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'support/xlsx_fixture.dart';

/// Faz 9 / Y2 — Excel'e grafik ekleme: parça zinciri (sayfa → çizim →
/// grafik), içerik türleri, başvurular ve önbellek; dosya yeniden açılıyor.
void main() {
  Uint8List sales() => xlsxFrom({
        'A1': 'Ay', 'B1': 'Satış', 'C1': 'Gider',
        'A2': 'Ocak', 'B2': 120, 'C2': 80,
        'A3': 'Şubat', 'B3': 150, 'C3': 95,
        'A4': 'Mart', 'B4': 90, 'C4': 70,
      }, sheet: 'Özet');

  Map<String, String> unzip(Uint8List bytes) => {
        for (final f in ZipDecoder().decodeBytes(bytes).files)
          if (f.isFile) f.name: utf8.decode(f.content as List<int>, allowMalformed: true),
      };

  XlsxChartSpec spec(XlsxEditor e, XlsxChartKind kind) {
    final sheet = e.sheets.first;
    return XlsxChartSpec.fromRange(
      sheetName: sheet.name,
      kind: kind,
      top: 0,
      left: 0,
      bottom: 3,
      right: 2,
      display: sheet.rawAt,
      title: 'Aylık',
    )!;
  }

  test('aralıktan seri ve kategori çıkarılır', () {
    final e = XlsxEditor.parse(sales());
    final s = spec(e, XlsxChartKind.column);
    expect(s.hasCategoryColumn, isTrue);
    expect(s.categories, ['Ocak', 'Şubat', 'Mart']);
    expect(s.series.map((x) => x.name), ['Satış', 'Gider']);
    expect(s.series.first.values, [120, 150, 90]);
    // Pastada tek seri.
    expect(spec(e, XlsxChartKind.pie).series, hasLength(1));
  });

  test('sayısal veri yoksa grafik kurulmaz', () {
    final e = XlsxEditor.parse(xlsxFrom({'A1': 'a', 'A2': 'b', 'B1': 'c', 'B2': 'd'}));
    expect(
      XlsxChartSpec.fromRange(
          sheetName: e.sheets.first.name,
          kind: XlsxChartKind.column,
          top: 0, left: 0, bottom: 1, right: 1,
          display: e.sheets.first.rawAt),
      isNull,
    );
  });

  for (final kind in XlsxChartKind.values) {
    test('${kind.name}: parça zinciri ve geçerli XML', () {
      final e = XlsxEditor.parse(sales())..addChart(spec(e0(sales()), kind));
      final out = e.save();
      final parts = unzip(out);

      expect(parts.keys, contains('xl/charts/chart1.xml'));
      expect(parts.keys, contains('xl/drawings/drawing1.xml'));
      final ct = parts['[Content_Types].xml']!;
      expect(ct, contains('/xl/charts/chart1.xml'));
      expect(ct, contains('/xl/drawings/drawing1.xml'));

      final sheetXml = parts['xl/worksheets/sheet1.xml']!;
      final rid = RegExp(r'<drawing r:id="([^"]+)"').firstMatch(sheetXml)![1];
      final sheetRels = parts['xl/worksheets/_rels/sheet1.xml.rels']!;
      expect(sheetRels, contains('Id="$rid"'));
      expect(sheetRels, contains('../drawings/drawing1.xml'));
      expect(parts['xl/drawings/_rels/drawing1.xml.rels'],
          contains('../charts/chart1.xml'));

      // Hepsi iyi biçimli XML.
      for (final name in [
        'xl/charts/chart1.xml',
        'xl/drawings/drawing1.xml',
        'xl/worksheets/sheet1.xml',
        '[Content_Types].xml',
      ]) {
        expect(() => XmlDocument.parse(parts[name]!), returnsNormally, reason: name);
      }
      final chart = parts['xl/charts/chart1.xml']!;
      expect(chart, contains("'Özet'!\$B\$2:\$B\$4"));
      expect(chart, contains('<c:v>Şubat</c:v>'));
      // Veri yeniden açılınca bozulmamış.
      final again = XlsxEditor.parse(out);
      expect(again.sheets.first.rawAt(2, 1), '150');
    });
  }

  test('ikinci grafik AYNI çizime eklenir (sayfanın tek <drawing>i olur)', () {
    final e = XlsxEditor.parse(sales());
    e
      ..addChart(spec(e, XlsxChartKind.column))
      ..addChart(spec(e, XlsxChartKind.line));
    final parts = unzip(e.save());
    expect(parts.keys, contains('xl/charts/chart2.xml'));
    expect(parts.keys.where((k) => k.startsWith('xl/drawings/drawing')),
        hasLength(1));
    expect(RegExp('<drawing ').allMatches(parts['xl/worksheets/sheet1.xml']!),
        hasLength(1));
    expect(RegExp('twoCellAnchor>').allMatches(parts['xl/drawings/drawing1.xml']!).length,
        4); // iki çerçeve (açılış + kapanış)
  });

  test('iki kez kaydetmek grafiği iki kez eklemez; sayfa adı değişince izler', () {
    final e = XlsxEditor.parse(sales());
    e.addChart(spec(e, XlsxChartKind.column));
    e.save();
    expect(e.renameSheet('Özet', 'Rapor'), isTrue);
    final parts = unzip(e.save());
    expect(parts.keys.where((k) => k.startsWith('xl/charts/')), hasLength(1));
    expect(parts['xl/charts/chart1.xml'], contains("'Rapor'!"));
  });

  test('başvuru biçimi: tırnak ve sütun harfleri', () {
    expect(XlsxChartWriter.ref("Ali'nin", 0, 27, 9, 27), "'Ali''nin'!\$AB\$1:\$AB\$10");
  });
}

XlsxEditor e0(Uint8List b) => XlsxEditor.parse(b);

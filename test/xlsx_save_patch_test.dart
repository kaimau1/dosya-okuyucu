import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:dosya_okuyucu/services/xlsx_save_patch.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

/// `excel` paketiyle küçük bir çalışma kitabı üretir (A1, C3 dolu; A ve B
/// sütunlarının genişliği, 1. satırın yüksekliği ayarlı).
Uint8List _sampleBook() {
  final excel = Excel.createExcel();
  final s = excel['Sheet1'];
  s.updateCell(CellIndex.indexByString('A1'), TextCellValue('a'));
  s.updateCell(CellIndex.indexByString('C3'), TextCellValue('c'));
  s.setColumnWidth(0, 20);
  s.setColumnWidth(1, 12);
  s.setRowHeight(0, 30);
  return Uint8List.fromList(excel.encode()!);
}

XmlElement _sheetXml(Uint8List bytes, [String path = 'xl/worksheets/sheet1.xml']) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final file = archive.files.firstWhere((f) => f.name == path);
  return XmlDocument.parse(
    utf8.decode(file.content as List<int>, allowMalformed: true),
  ).rootElement;
}

XmlElement? _first(XmlElement parent, String local) {
  for (final e in parent.children.whereType<XmlElement>()) {
    if (e.name.local == local) return e;
  }
  return null;
}

List<XmlElement> _all(XmlElement root, String local) =>
    root.descendants.whereType<XmlElement>().where((e) => e.name.local == local).toList();

void main() {
  group('XlsxSavePatch', () {
    test('yama YOKSA baytlar birebir aynı kalır', () {
      final bytes = _sampleBook();
      final out = XlsxSavePatch.apply(bytes, const [
        XlsxSheetPatch(name: 'Sheet1'),
      ]);
      expect(identical(out, bytes), isTrue,
          reason: 'boş yamada zip yeniden kurulmamalı');
    });

    test('sayfa yönü sağdan sola yazılır', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', rightToLeft: true),
      ]);
      final view = _all(_sheetXml(out), 'sheetView').single;
      expect(view.getAttribute('rightToLeft'), '1');
      // workbookViewId korunmalı (paketin yazdığı nitelik silinmemeli).
      expect(view.getAttribute('workbookViewId'), '0');
    });

    test('gizli sütun: kendi <col> aralığı varsa hidden eklenir', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', hiddenCols: {1}), // B sütunu
      ]);
      final cols = _all(_sheetXml(out), 'col');
      final b = cols.firstWhere((c) => c.getAttribute('min') == '2');
      expect(b.getAttribute('hidden'), '1');
      expect(b.getAttribute('width'), '12.00', reason: 'genişlik korunmalı');
      // A sütununa dokunulmamalı.
      final a = cols.firstWhere((c) => c.getAttribute('min') == '1');
      expect(a.getAttribute('hidden'), isNull);
    });

    test('gizli sütunun <col> kaydı yoksa yenisi eklenir', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', hiddenCols: {5}), // F sütunu
      ]);
      final f = _all(_sheetXml(out), 'col')
          .firstWhere((c) => c.getAttribute('min') == '6');
      expect(f.getAttribute('max'), '6');
      expect(f.getAttribute('hidden'), '1');
    });

    test('aralıklı <col min=1 max=10> gizlemede ÜÇE bölünür', () {
      // Gerçek dosyalarda tek <col> onlarca sütunu kapsar; bölmeden hidden
      // eklemek 10 sütunu birden gizlerdi (veri "kayboldu" hatası).
      final excel = Excel.createExcel();
      excel['Sheet1']
          .updateCell(CellIndex.indexByString('A1'), TextCellValue('a'));
      var xml = utf8.decode(
        ZipDecoder()
            .decodeBytes(Uint8List.fromList(excel.encode()!))
            .files
            .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
            .content as List<int>,
      );
      xml = xml.replaceFirst('<sheetData>',
          '<cols><col min="1" max="10" width="20.00" customWidth="1"/></cols><sheetData>');
      final rebuilt = _rebuild(Uint8List.fromList(excel.encode()!), xml);

      final out = XlsxSavePatch.apply(rebuilt, const [
        XlsxSheetPatch(name: 'Sheet1', hiddenCols: {4}), // E sütunu
      ]);
      final cols = _all(_sheetXml(out), 'col');
      expect(cols.map((c) => '${c.getAttribute('min')}-${c.getAttribute('max')}'),
          ['1-4', '5-5', '6-10']);
      expect(cols[0].getAttribute('hidden'), isNull);
      expect(cols[1].getAttribute('hidden'), '1');
      expect(cols[2].getAttribute('hidden'), isNull);
      // Genişlik üç parçada da korunur.
      expect(cols.every((c) => c.getAttribute('width') == '20.00'), isTrue);
    });

    test('gizli satır: var olan <row>a hidden eklenir', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', hiddenRows: {0}),
      ]);
      final row = _all(_sheetXml(out), 'row')
          .firstWhere((r) => r.getAttribute('r') == '1');
      expect(row.getAttribute('hidden'), '1');
      expect(row.getAttribute('ht'), '30.00', reason: 'yükseklik korunmalı');
    });

    test('hücresiz satırın yüksekliği ve gizliliği <row> ÜRETİLEREK yazılır', () {
      // `excel` paketi hücresi olmayan satır için <row> yazmıyor; ayırıcı
      // olarak kullanılan boş satırların özel yüksekliği böyle kayboluyordu.
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(
          name: 'Sheet1',
          hiddenRows: {3},
          rowHeightsPt: {1: 42.0, 3: 8.0},
        ),
      ]);
      final rows = _all(_sheetXml(out), 'row');
      final r2 = rows.firstWhere((r) => r.getAttribute('r') == '2');
      expect(r2.getAttribute('ht'), '42.00');
      expect(r2.getAttribute('customHeight'), '1');
      expect(r2.getAttribute('hidden'), isNull);

      final r4 = rows.firstWhere((r) => r.getAttribute('r') == '4');
      expect(r4.getAttribute('ht'), '8.00');
      expect(r4.getAttribute('hidden'), '1');

      // Satırlar `r` sırasında kalmalı — Excel sırasız sheetData'yı onarım
      // uyarısıyla açar.
      final order = rows.map((r) => int.parse(r.getAttribute('r')!)).toList();
      final sorted = [...order]..sort();
      expect(order, sorted);
    });

    test('<cols> hiç yoksa şema sırasına göre <sheetData> ÖNÜNE eklenir', () {
      final excel = Excel.createExcel();
      excel['Sheet1']
          .updateCell(CellIndex.indexByString('A1'), TextCellValue('a'));
      final out = XlsxSavePatch.apply(
        Uint8List.fromList(excel.encode()!),
        const [XlsxSheetPatch(name: 'Sheet1', hiddenCols: {0})],
      );
      final root = _sheetXml(out);
      final names = root.children
          .whereType<XmlElement>()
          .map((e) => e.name.local)
          .toList();
      expect(names.contains('cols'), isTrue);
      expect(names.indexOf('cols'), lessThan(names.indexOf('sheetData')));
      expect(_first(root, 'cols')!.children.length, 1);
    });

    test('bozuk girdi kaydetmeyi KIRMAZ, baytlar olduğu gibi döner', () {
      final junk = Uint8List.fromList(List<int>.filled(64, 7));
      final out = XlsxSavePatch.apply(junk, const [
        XlsxSheetPatch(name: 'Sheet1', rightToLeft: true),
      ]);
      expect(out, junk);
    });

    test('sayfa adı → dosya eşlemesi r:id üzerinden çözülür', () {
      // sheet1.xml'in birinci sayfa olduğu garanti değil; eşleme ilişki
      // kimliğinden gelmeli. Adı olmayan bir sayfa yamayı düşürmemeli.
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'BöyleBirSayfaYok', rightToLeft: true),
      ]);
      expect(_all(_sheetXml(out), 'sheetView').single.getAttribute('rightToLeft'),
          isNull);
    });
  });

  group('XlsxEditor.save', () {
    test('gizlenen sütun ve sayfa yönü kaydetmeden SAĞ ÇIKAR', () {
      // Kırmızı→yeşil: yama olmadan `excel` paketi ikisini de düşürüyordu.
      final editor = XlsxEditor.parse(_sampleBook());
      final sheet = editor.sheets.first;
      sheet.setColWidthChars(1, 0); // B sütununu gizle
      sheet.setRightToLeft(true);

      final saved = editor.save();
      final root = _sheetXml(saved);
      expect(_all(root, 'sheetView').single.getAttribute('rightToLeft'), '1');
      expect(
        _all(root, 'col')
            .firstWhere((c) => c.getAttribute('min') == '2')
            .getAttribute('hidden'),
        '1',
      );

      // Tekrar okununca model aynı durumu görmeli (gidiş-dönüş).
      final reopened = XlsxEditor.parse(saved);
      expect(reopened.sheets.first.rightToLeft, isTrue);
      expect(reopened.sheets.first.isColHidden(1), isTrue);
    });

    test('gizlenen satır gidiş-dönüşte korunur', () {
      final editor = XlsxEditor.parse(_sampleBook());
      editor.sheets.first.setRowHeightPt(0, 0); // 1. satırı gizle
      final reopened = XlsxEditor.parse(editor.save());
      expect(reopened.sheets.first.isRowHidden(0), isTrue);
    });
  });
}

/// `sheet1.xml`i verilen metinle değiştirip zip'i yeniden kurar (testte
/// elle hazırlanmış XML'i kullanabilmek için).
Uint8List _rebuild(Uint8List bytes, String sheetXml) {
  final archive = ZipDecoder().decodeBytes(bytes);
  final data = utf8.encode(sheetXml);
  final rebuilt = Archive();
  for (final f in archive.files) {
    rebuilt.addFile(f.name == 'xl/worksheets/sheet1.xml'
        ? ArchiveFile(f.name, data.length, data)
        : f);
  }
  return Uint8List.fromList(ZipEncoder().encode(rebuilt)!);
}

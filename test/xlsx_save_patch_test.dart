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

    test('dondurulmuş bölme <pane> olarak yazılır ve sheetView\'ın İLK çocuğu olur',
        () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', frozenRows: 1, frozenCols: 2),
      ]);
      final view = _all(_sheetXml(out), 'sheetView').single;
      final pane = _first(view, 'pane')!;
      expect(pane.getAttribute('state'), 'frozen');
      expect(pane.getAttribute('ySplit'), '1');
      expect(pane.getAttribute('xSplit'), '2');
      expect(pane.getAttribute('topLeftCell'), 'C2');
      expect(pane.getAttribute('activePane'), 'bottomRight');
      // CT_SheetView sırası: pane her şeyden önce gelmeli.
      expect(view.children.whereType<XmlElement>().first, same(pane));
    });

    test('yalnız satır donmuşsa xSplit yazılmaz, etkin bölme bottomLeft olur', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', frozenRows: 2),
      ]);
      final pane = _first(_all(_sheetXml(out), 'sheetView').single, 'pane')!;
      expect(pane.getAttribute('xSplit'), isNull);
      expect(pane.getAttribute('ySplit'), '2');
      expect(pane.getAttribute('topLeftCell'), 'A3');
      expect(pane.getAttribute('activePane'), 'bottomLeft');
    });

    test('ızgara çizgisi yalnız KAPALIYKEN yazılır', () {
      final off = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', showGridLines: false),
      ]);
      expect(
          _all(_sheetXml(off), 'sheetView').single.getAttribute('showGridLines'),
          '0');

      // Açık = Excel varsayılanı; nitelik eklenmemeli (dosya değişmemeli).
      final on = _sampleBook();
      expect(
        identical(
          XlsxSavePatch.apply(on, const [XlsxSheetPatch(name: 'Sheet1')]),
          on,
        ),
        isTrue,
      );
    });

    test('otomatik süzgeç sheetData\'dan SONRA eklenir', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', autoFilterRef: 'A1:C3'),
      ]);
      final root = _sheetXml(out);
      expect(_first(root, 'autoFilter')!.getAttribute('ref'), 'A1:C3');
      final names =
          root.children.whereType<XmlElement>().map((e) => e.name.local).toList();
      expect(names.indexOf('autoFilter'),
          greaterThan(names.indexOf('sheetData')));
    });

    test('dolgu rengi styles.xml\'e solid patternFill olarak yazılır', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(fillArgb: 0xFFFF0000),
        }),
      ]);
      final styles = _sheetXml(out, 'xl/styles.xml');
      final fills = _first(styles, 'fills')!;
      final added = _all(fills, 'fgColor')
          .where((e) => e.getAttribute('rgb') == 'FFFF0000');
      expect(added, hasLength(1), reason: 'renk bir kez tahsis edilmeli');
      expect(_all(fills, 'patternFill').last.getAttribute('patternType'),
          'solid');

      // Hücre yeni `<xf>`e işaret etmeli ve o `<xf>` yeni dolguyu göstermeli.
      final cell = _all(_sheetXml(out), 'c')
          .firstWhere((e) => e.getAttribute('r') == 'A1');
      final xfs = _all(_first(styles, 'cellXfs')!, 'xf');
      final xf = xfs[int.parse(cell.getAttribute('s')!)];
      expect(xf.getAttribute('applyFill'), '1');
      final fillId = int.parse(xf.getAttribute('fillId')!);
      expect(_all(_all(fills, 'fill')[fillId], 'fgColor').single
          .getAttribute('rgb'), 'FFFF0000');
    });

    test('yazı puntosu ve yazı tipi adı fonts tablosuna yazılır', () {
      // 2026-08-07: Excel şeridine yazı tipi/punto geldi; kaydetmede de
      // durmalı. `scheme` SİLİNİR — kalırsa Excel tema fontunu kullanır ve
      // kullanıcının seçtiği ad görünmezdi.
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(fontSize: 18, fontName: 'Arial'),
        }),
      ]);
      final styles = _sheetXml(out, 'xl/styles.xml');
      final cell = _all(_sheetXml(out), 'c')
          .firstWhere((e) => e.getAttribute('r') == 'A1');
      final xf = _all(_first(styles, 'cellXfs')!, 'xf')[
          int.parse(cell.getAttribute('s')!)];
      expect(xf.getAttribute('applyFont'), '1');
      final font = _all(_first(styles, 'fonts')!, 'font')[
          int.parse(xf.getAttribute('fontId')!)];
      expect(_all(font, 'sz').single.getAttribute('val'), '18');
      expect(_all(font, 'name').single.getAttribute('val'), 'Arial');
      expect(_all(font, 'scheme'), isEmpty);
    });

    test('aynı biçim iki hücreye verilince TEK <xf> üretilir', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(fontArgb: 0xFF0070C0, bold: true),
          (2, 2): XlsxStyleEdit(fontArgb: 0xFF0070C0, bold: true),
        }),
      ]);
      final root = _sheetXml(out);
      final a1 = _all(root, 'c').firstWhere((e) => e.getAttribute('r') == 'A1');
      final c3 = _all(root, 'c').firstWhere((e) => e.getAttribute('r') == 'C3');
      expect(a1.getAttribute('s'), c3.getAttribute('s'),
          reason: 'aynı görünüm aynı stil indeksini paylaşmalı');

      final styles = _sheetXml(out, 'xl/styles.xml');
      final fonts = _all(_first(styles, 'fonts')!, 'font');
      final withColor = fonts.where((f) =>
          _all(f, 'color').any((c) => c.getAttribute('rgb') == 'FF0070C0'));
      expect(withColor, hasLength(1), reason: 'yazı tipi de bir kez eklenmeli');
      expect(_all(withColor.single, 'b'), hasLength(1));
    });

    test('kenarlık verilen kenarı yazar, verilmeyeni tabandan taşır', () {
      // İki tur: önce sol kenar, sonra alt kenar. İkincisi birincinin
      // kenarlığını TABAN alır — Excel'de kenar eklemek diğerlerini silmez.
      final withLeft = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(borders: {'left': 'thin'}),
        }),
      ]);
      final out = XlsxSavePatch.apply(withLeft, const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(borders: {'bottom': 'medium'}),
        }),
      ]);
      final styles = _sheetXml(out, 'xl/styles.xml');
      final cell = _all(_sheetXml(out), 'c')
          .firstWhere((e) => e.getAttribute('r') == 'A1');
      final xf = _all(_first(styles, 'cellXfs')!, 'xf')[
          int.parse(cell.getAttribute('s')!)];
      final border = _all(_first(styles, 'borders')!, 'border')[
          int.parse(xf.getAttribute('borderId')!)];
      expect(_first(border, 'bottom')!.getAttribute('style'), 'medium');
      expect(_first(border, 'left')!.getAttribute('style'), 'thin',
          reason: 'önceki tur yazdığı kenar korunmalı');
      // ECMA `CT_Border` sırası: left … top, bottom.
      final order =
          border.children.whereType<XmlElement>().map((e) => e.name.local);
      expect(order.toList(), containsAllInOrder(['left', 'bottom']));
    });

    test('kenarlık SİLME boş etiket yazar (tabandaki çizgiyi bastırır)', () {
      final withAll = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(borders: {'left': 'thin', 'bottom': 'thin'}),
        }),
      ]);
      final out = XlsxSavePatch.apply(withAll, const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(borders: {'left': null, 'bottom': null}),
        }),
      ]);
      final styles = _sheetXml(out, 'xl/styles.xml');
      final cell = _all(_sheetXml(out), 'c')
          .firstWhere((e) => e.getAttribute('r') == 'A1');
      final xf = _all(_first(styles, 'cellXfs')!, 'xf')[
          int.parse(cell.getAttribute('s')!)];
      final border = _all(_first(styles, 'borders')!, 'border')[
          int.parse(xf.getAttribute('borderId')!)];
      expect(_first(border, 'left')!.getAttribute('style'), isNull);
      expect(_first(border, 'bottom')!.getAttribute('style'), isNull);
    });

    test('metin kaydırma <alignment wrapText> olarak yazılır', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(wrap: true),
        }),
      ]);
      final styles = _sheetXml(out, 'xl/styles.xml');
      final cell = _all(_sheetXml(out), 'c')
          .firstWhere((e) => e.getAttribute('r') == 'A1');
      final xf = _all(_first(styles, 'cellXfs')!, 'xf')[
          int.parse(cell.getAttribute('s')!)];
      expect(xf.getAttribute('applyAlignment'), '1');
      expect(_first(xf, 'alignment')!.getAttribute('wrapText'), '1');
    });

    test('biçim yapıştırma kaynağın stil indeksini hedefe kopyalar', () {
      // Önce A1'e bir biçim ver, sonra onu C3'e "yapıştır".
      final colored = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', styleEdits: {
          (0, 0): XlsxStyleEdit(fillArgb: 0xFF92D050),
        }),
      ]);
      final out = XlsxSavePatch.apply(colored, const [
        XlsxSheetPatch(name: 'Sheet1', styleCopies: {(2, 2): (0, 0)}),
      ]);
      final root = _sheetXml(out);
      final a1 = _all(root, 'c').firstWhere((e) => e.getAttribute('r') == 'A1');
      final c3 = _all(root, 'c').firstWhere((e) => e.getAttribute('r') == 'C3');
      expect(c3.getAttribute('s'), a1.getAttribute('s'));
      // Değer taşınmamalı — yapıştırılan yalnız biçim.
      expect(_first(c3, 'v')?.innerText ?? _first(c3, 'is')?.innerText,
          isNot('a'));
    });

    test('koşullu biçimlendirme kuralı ve dxf birlikte yazılır', () {
      final out = XlsxSavePatch.apply(_sampleBook(), const [
        XlsxSheetPatch(name: 'Sheet1', condRules: [
          XlsxCondRuleWrite(
            sqref: 'A1:C3',
            type: 'cellIs',
            operator: 'greaterThan',
            formulas: ['100'],
            fillArgb: 0xFFFFC7CE,
          ),
        ]),
      ]);
      final root = _sheetXml(out);
      final cf = _first(root, 'conditionalFormatting')!;
      expect(cf.getAttribute('sqref'), 'A1:C3');
      final rule = _first(cf, 'cfRule')!;
      expect(rule.getAttribute('type'), 'cellIs');
      expect(rule.getAttribute('operator'), 'greaterThan');
      // Öncelik POZİTİF olmak zorunda (Excel 0/negatifi kabul etmiyor).
      expect(int.parse(rule.getAttribute('priority')!), greaterThan(0));
      expect(_first(rule, 'formula')!.innerText, '100');

      // Görünüm stil tablosunda; sayfa yalnız indeksle işaret ediyor.
      final styles = _sheetXml(out, 'xl/styles.xml');
      final dxfs = _all(_first(styles, 'dxfs')!, 'dxf');
      final dxf = dxfs[int.parse(rule.getAttribute('dxfId')!)];
      // `<dxf>` dolgusunda renk bgColor'a yazılır (hücre stilinin aksine).
      expect(_all(dxf, 'bgColor').single.getAttribute('rgb'), 'FFFFC7CE');

      // Şema sırası: conditionalFormatting sheetData'dan SONRA gelmeli.
      final names =
          root.children.whereType<XmlElement>().map((e) => e.name.local).toList();
      expect(names.indexOf('conditionalFormatting'),
          greaterThan(names.indexOf('sheetData')));
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

    test('dondurulmuş bölme, kapalı ızgara ve süzgeç gidiş-dönüşte korunur', () {
      // Kullanıcının başlık satırı donmuş tablosunda tek hücre düzenleyip
      // kaydetmek bölmeyi çözüyordu (2026-08-01 sadakat turu).
      final editor = XlsxEditor.parse(_bookWithView());
      final sheet = editor.sheets.first;
      expect(sheet.frozenRows, 1, reason: 'fixture okunamadıysa test anlamsız');
      expect(sheet.frozenCols, 1);
      expect(sheet.showGridLines, isFalse);

      editor.setCell(sheet.name, 1, 1, 'yeni'); // sıradan bir düzenleme
      final reopened = XlsxEditor.parse(editor.save()).sheets.first;
      expect(reopened.frozenRows, 1);
      expect(reopened.frozenCols, 1);
      expect(reopened.showGridLines, isFalse);
      expect(reopened.layout.autoFilterRef, 'A1:C3');
    });
  });
}

/// Dondurulmuş bölme + kapalı ızgara + otomatik süzgeç içeren bir çalışma
/// kitabı (Excel'in gerçek dosyalarındaki `sheetView` yapısı).
Uint8List _bookWithView() {
  final book = _sampleBook();
  var xml = utf8.decode(
    ZipDecoder()
        .decodeBytes(book)
        .files
        .firstWhere((f) => f.name == 'xl/worksheets/sheet1.xml')
        .content as List<int>,
  );
  xml = xml.replaceFirst(
    RegExp(r'<sheetView[^>]*/>|<sheetView[^>]*>.*?</sheetView>', dotAll: true),
    '<sheetView showGridLines="0" workbookViewId="0">'
        '<pane xSplit="1" ySplit="1" topLeftCell="B2" activePane="bottomRight" '
        'state="frozen"/>'
        '</sheetView>',
  );
  xml = xml.replaceFirst(
      '</worksheet>', '<autoFilter ref="A1:C3"/></worksheet>');
  return _rebuild(book, xml);
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

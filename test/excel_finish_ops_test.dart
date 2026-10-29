import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:dosya_okuyucu/services/csv_document.dart';
import 'package:dosya_okuyucu/services/sheet_data_ops.dart';
import 'package:dosya_okuyucu/services/xlsx_editor.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_test/flutter_test.dart';

/// Faz 27 kalanı — biçim alanları (üstü çizili, dikey hiza, girinti,
/// döndürme, renkli kenarlık), veri doğrulama oluşturma, süzgeç, sekme rengi /
/// gizleme / çoğaltma, notlar (yorum + VML), çok düzeyli sıralama, CSV
/// gidiş-dönüşü. Her kayıt yeniden açılır; LibreOffice varsa onarımsız açılır.
const _fixture = 'test/fixtures/office/satis.xlsx';

XlsxEditor _open([Uint8List? b]) =>
    XlsxEditor.parse(b ?? File(_fixture).readAsBytesSync());

String? _part(Uint8List bytes, String name) {
  for (final f in ZipDecoder().decodeBytes(bytes).files) {
    if (f.name == name) return utf8.decode(f.content as List<int>);
  }
  return null;
}

List<String> _names(Uint8List bytes) =>
    [for (final f in ZipDecoder().decodeBytes(bytes).files) f.name];

void _opensInLibreOffice(Uint8List bytes, {String? text}) {
  if (Process.runSync('which', ['soffice']).exitCode != 0) return;
  final dir = Directory.systemTemp.createTempSync('xl_finish');
  try {
    final f = File('${dir.path}/t.xlsx')..writeAsBytesSync(bytes);
    final r = Process.runSync('soffice',
        ['--headless', '--convert-to', 'csv', '--outdir', dir.path, f.path]);
    expect(r.exitCode, 0, reason: '${r.stderr}');
    final out = File('${dir.path}/t.csv');
    expect(out.existsSync(), isTrue);
    if (text != null) expect(out.readAsStringSync(), contains(text));
  } finally {
    dir.deleteSync(recursive: true);
  }
}

void main() {
  test('biçim alanları: üstü çizili, dikey hiza, girinti, döndürme, kenarlık rengi',
      () {
    final ed = _open();
    final s = ed.sheets.first;
    ed.setCellFormat(s.name, 1, 1,
        strike: true,
        vAlign: XlsxVAlign.top,
        indent: 2,
        rotation: 45,
        hAlign: XlsxHAlign.center);
    ed.setCellBorderColored(s.name, 1, 1, {'bottom': 'double'},
        const Color(0xFFC00000));
    final st = s.styleAt(1, 1)!;
    expect(st.strike, isTrue);
    expect(st.vAlign, XlsxVAlign.top);
    expect(st.indent, 2);
    expect(st.rotation, 45);
    final out = ed.save();
    final again = _open(out).sheets.first.styleAt(1, 1)!;
    expect(again.strike, isTrue);
    expect(again.vAlign, XlsxVAlign.top);
    expect(again.hAlign, XlsxHAlign.center);
    expect(again.indent, 2);
    expect(again.rotation, 45);
    expect(again.border.bottom.style, 'double');
    expect(again.border.bottom.colorArgb, 0xFFC00000);
    _opensInLibreOffice(out);
  });

  test('veri doğrulama: liste + sayı aralığı yazılır, okunur, denetlenir', () {
    final ed = _open();
    final s = ed.sheets.first;
    ed.addValidation(
        s.name,
        const XlsxRange(1, 5, 10, 5),
        const XlsxDataValidation(
            type: 'list',
            ranges: [XlsxRange(1, 5, 10, 5)],
            options: ['Evet', 'Hayır']));
    ed.addValidation(
        s.name,
        const XlsxRange(1, 6, 10, 6),
        const XlsxDataValidation(
            type: 'whole',
            ranges: [XlsxRange(1, 6, 10, 6)],
            formula1: '1',
            formula2: '100',
            error: '1–100 arası'));
    final out = ed.save();
    final xml = _part(out, 'xl/worksheets/sheet1.xml')!;
    expect(xml, contains('<dataValidations'));
    expect(xml, contains('"Evet,Hayır"'));
    final again = _open(out).sheets.first;
    final list = again.validationAt(3, 5)!;
    expect(list.options, ['Evet', 'Hayır']);
    expect(list.accepts('evet'), isTrue);
    expect(list.accepts('Belki'), isFalse);
    final num = again.validationAt(3, 6)!;
    expect(num.accepts('50'), isTrue);
    expect(num.accepts('150'), isFalse);
    expect(num.accepts('2.5'), isFalse, reason: 'tam sayı');
    expect(num.error, '1–100 arası');
    _opensInLibreOffice(out);

    // Temizle → kayıtta kalmaz.
    final ed2 = _open(out);
    ed2.clearValidations(ed2.sheets.first.name, const XlsxRange(0, 5, 20, 6));
    final out2 = ed2.save();
    expect(_part(out2, 'xl/worksheets/sheet1.xml')!,
        isNot(contains('<dataValidation ')));
  });

  test('tarih doğrulaması gg.aa.yyyy kabul eder', () {
    const v = XlsxDataValidation(
        type: 'date',
        ranges: [XlsxRange(0, 0, 0, 0)],
        operator: 'greaterThanOrEqual',
        formula1: '46023'); // 2026-01-01
    expect(v.accepts('15.03.2026'), isTrue);
    expect(v.accepts('15.03.2025'), isFalse);
    expect(v.accepts('dün'), isFalse);
  });

  test('süzgeç oluştur / kaldır', () {
    final ed = _open();
    final s = ed.sheets.first;
    ed.setAutoFilter(s.name, 'A1:D5');
    var out = ed.save();
    expect(_part(out, 'xl/worksheets/sheet1.xml')!, contains('<autoFilter ref="A1:D5"'));
    final ed2 = _open(out);
    expect(ed2.sheets.first.layout.autoFilterRef, 'A1:D5');
    ed2.setAutoFilter(ed2.sheets.first.name, null);
    out = ed2.save();
    expect(_part(out, 'xl/worksheets/sheet1.xml')!, isNot(contains('<autoFilter')));
  });

  test('sekme rengi, gizle, çoğalt', () {
    final ed = _open();
    final s = ed.sheets.first;
    ed.setCell(s.name, 0, 0, 'Başlık');
    ed.setTabColor(s.name, 0xFF00B050);
    final copy = ed.duplicateSheet(s.name)!;
    expect(copy.name, '${s.name} (2)');
    expect(copy.rawAt(0, 0), 'Başlık');
    expect(ed.setSheetHidden(copy.name, true), isTrue);
    final out = ed.save();
    final again = _open(out);
    expect(again.sheets.map((x) => x.name), contains(copy.name));
    final c2 = again.sheets.firstWhere((x) => x.name == copy.name);
    expect(c2.layout.hidden, isTrue);
    expect(c2.rawAt(0, 0), 'Başlık');
    expect(again.sheets.first.layout.tabColorArgb, 0xFF00B050);
    _opensInLibreOffice(out);
  });

  test('görünür son sayfa gizlenemez', () {
    final ed = XlsxEditor.blank();
    expect(ed.setSheetHidden(ed.sheets.first.name, true), isFalse);
  });

  test('notlar: yaz → comments + VML + legacyDrawing; yeniden açınca okunur; sil',
      () {
    final ed = _open();
    final s = ed.sheets.first;
    ed.setNote(s.name, 2, 1, 'Kontrol edilecek', author: 'Ayşe');
    var out = ed.save();
    final names = _names(out);
    expect(names.any((n) => RegExp(r'^xl/comments\d+\.xml$').hasMatch(n)), isTrue);
    expect(names.any((n) => n.endsWith('.vml')), isTrue);
    expect(_part(out, 'xl/worksheets/sheet1.xml')!, contains('legacyDrawing'));
    expect(_part(out, '[Content_Types].xml')!, contains('Extension="vml"'));
    final again = _open(out);
    expect(again.noteAt(again.sheets.first.name, 2, 1)?.text, 'Kontrol edilecek');
    _opensInLibreOffice(out);
    again.setNote(again.sheets.first.name, 2, 1, null);
    out = again.save();
    expect(_open(out).noteAt(again.sheets.first.name, 2, 1), isNull);
  });

  test('çok düzeyli sıralama kararlı', () {
    final data = {
      1: ['İzmir', '3'],
      2: ['Ankara', '5'],
      3: ['İzmir', '1'],
      4: ['Ankara', '2'],
    };
    final order = multiSortOrder(1, 4, [
      SortLevel((r) => data[r]![0]),
      SortLevel((r) => data[r]![1], ascending: false),
    ]);
    expect(order, [2, 4, 1, 3]);
  });

  group('CSV', () {
    test('noktalı virgül + cp1254: düzenle → aynı ayraç ve kodlama', () {
      final src = File('test/fixtures/office/noktali_virgul.csv').readAsBytesSync();
      final ed = XlsxEditor.fromCsv(src, sheetName: 'noktali_virgul');
      final f = ed.csv!;
      expect(f.delimiter, ';');
      final s = ed.sheets.first;
      ed.setCell(s.name, 1, 0, 'Değişti; tırnaklı');
      final out = ed.save();
      final back = CsvDocument.parse(out);
      expect(back.format.delimiter, ';');
      expect(back.format.encoding, f.encoding);
      expect(back.format.eol, f.eol);
      expect(back.rows[1][0], 'Değişti; tırnaklı');
      // Dokunulmayan satırlar aynen.
      final orig = CsvDocument.parse(src);
      expect(back.rows.first, orig.rows.first);
      expect(back.rows.length, orig.rows.length);
    });

    test('UTF-8 BOM + LF + son satır sonu korunur', () {
      const text = 'a,b\n1,2\n';
      final bytes = Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(text)]);
      final ed = XlsxEditor.fromCsv(bytes, sheetName: 't');
      final out = ed.save();
      expect(out.sublist(0, 3), [0xEF, 0xBB, 0xBF]);
      expect(utf8.decode(out.sublist(3)), text);
    });

    test('her alan tırnaklı düzen korunur', () {
      final bytes = Uint8List.fromList(utf8.encode('"a","b"\r\n"1","2"'));
      final ed = XlsxEditor.fromCsv(bytes, sheetName: 't');
      ed.setCell('t', 1, 1, '3');
      expect(utf8.decode(ed.save()), '"a","b"\r\n"1","3"');
    });

    test('TSV sekmeyle yazılır', () {
      final bytes = Uint8List.fromList(utf8.encode('a\tb\n1\t2'));
      final ed = XlsxEditor.fromCsv(bytes, sheetName: 't', tsv: true);
      expect(utf8.decode(ed.save()), 'a\tb\n1\t2');
    });
  });
}
